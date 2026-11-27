package cm.naxa.naxaservices

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import cm.naxa.naxaservices.auth.AuthApi
import cm.naxa.naxaservices.auth.AuthApiException
import cm.naxa.naxaservices.auth.AuthSession
import cm.naxa.naxaservices.auth.SessionVault
import cm.naxa.naxaservices.auth.RememberedSessionChanged
import cm.naxa.naxaservices.auth.discardRememberedSession
import cm.naxa.naxaservices.data.NaxaServicesLocalRepository
import cm.naxa.naxaservices.data.SecureLocalDatabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.CancellationException
import java.util.concurrent.TimeUnit
import org.json.JSONObject

object NaxaServicesSyncScheduler {
    private const val PERIODIC_WORK = "naxa-services-erp-sync-periodic"
    private const val IMMEDIATE_WORK = "naxa-services-erp-sync-immediate"

    private fun constraints() = Constraints.Builder()
        .setRequiredNetworkType(NetworkType.CONNECTED)
        .build()

    fun schedule(context: Context) {
        val appContext = context.applicationContext
        if (
            SessionVault(appContext).loadRefreshToken().isNullOrBlank() ||
            !SupplierSyncCoordinator.isConfigured()
        ) {
            cancel(appContext)
            return
        }
        val request = PeriodicWorkRequestBuilder<NaxaServicesSyncWorker>(15, TimeUnit.MINUTES)
            .setConstraints(constraints())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .build()
        WorkManager.getInstance(appContext).enqueueUniquePeriodicWork(
            PERIODIC_WORK,
            ExistingPeriodicWorkPolicy.UPDATE,
            request
        )
    }

    fun enqueueNow(context: Context) {
        val request = OneTimeWorkRequestBuilder<NaxaServicesSyncWorker>()
            .setConstraints(constraints())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .build()
        WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
            IMMEDIATE_WORK,
            ExistingWorkPolicy.KEEP,
            request
        )
    }

    fun cancel(context: Context) {
        val manager = WorkManager.getInstance(context.applicationContext)
        manager.cancelUniqueWork(PERIODIC_WORK)
        manager.cancelUniqueWork(IMMEDIATE_WORK)
    }
}

internal fun shouldRetrySyncWorker(retriedCount: Int, hasMoreChanges: Boolean = false): Boolean = retriedCount > 0 || hasMoreChanges

private const val SYNC_PULL_PAGE_SIZE = 100
private const val MAX_PULL_PAGES_PER_RUN = 10

data class NaxaServicesSyncCycleSummary(
    val outgoing: SupplierSyncSummary,
    val incomingApplied: Int,
    val cursor: Long,
    val hasMore: Boolean
)

internal suspend fun runNaxaServicesSyncCycle(
    repository: NaxaServicesLocalRepository,
    api: AuthApi,
    session: AuthSession,
    isCurrent: () -> Boolean = { true }
): NaxaServicesSyncCycleSummary {
    if(!isCurrent())throw RememberedSessionChanged()
    val outgoing = SupplierSyncCoordinator.syncPending(repository, api, session, isCurrent)
    var cursor = repository.dao.findSyncCheckpoint(
        session.account.organizationId, session.deviceId
    )?.cursor ?: 0L
    var hasMore = true
    var pageCount = 0
    var incomingApplied = 0
    while (hasMore && pageCount < MAX_PULL_PAGES_PER_RUN) {
        if(!isCurrent())throw RememberedSessionChanged()
        val response = api.accountingRequest(
            session.accessToken,
            JSONObject()
                .put("action", "pull_sync_changes")
                .put("app_code", "naxa-services")
                .put("org_id", session.account.organizationId)
                .put("device_id", session.deviceId)
                .put("after_cursor", cursor)
                .put("limit", SYNC_PULL_PAGE_SIZE)
        )
        if (!response.optBoolean("ok", false)) throw IllegalStateException("SYNC_PULL_NOT_CONFIRMED")
        val page = response.optJSONObject("result")
            ?: throw IllegalStateException("SYNC_PULL_PAGE_MISSING")
        val nextCursor = page.optLong("next_cursor", -1L)
        if (nextCursor < cursor) throw IllegalStateException("SYNC_PULL_CURSOR_REGRESSION")
        if(!isCurrent())throw RememberedSessionChanged()
        incomingApplied += repository.persistRemoteSyncPage(
            session.account.organizationId, session.deviceId, page
        )
        val changes = page.optJSONArray("changes") ?: throw IllegalStateException("SYNC_PULL_CHANGES_MISSING")
        hasMore = page.optBoolean("has_more", false)
        if (hasMore && nextCursor == cursor && changes.length() == 0) {
            throw IllegalStateException("SYNC_PULL_CURSOR_STALLED")
        }
        cursor = nextCursor
        pageCount++
    }
    return NaxaServicesSyncCycleSummary(outgoing, incomingApplied, cursor, hasMore)
}

class NaxaServicesSyncWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val vault = SessionVault(applicationContext)
        val binding = vault.binding() ?: return Result.success()
        if (!SupplierSyncCoordinator.isConfigured()) return Result.success()

        val api = AuthApi(applicationContext)
        val session = try {
            vault.refreshRemembered(binding){api.refresh(it,rememberDevice=true)}
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: RememberedSessionChanged) {
            return Result.success()
        } catch (failure: AuthApiException) {
            if (discardRememberedSession(failure.statusCode)) {
                return Result.success()
            }
            return Result.retry()
        } catch (_: Exception) {
            return Result.retry()
        }

        if (session.deviceId.isBlank()) return Result.retry()
        if(vault.binding()!=binding||session.requirePasswordChange)return Result.success()
        // A worker rotation invalidates the old snapshot; renew only with fresh paid rights.
        if (LocalAccessPinManager(applicationContext).isConfigured(session.account.memberId)) {
            try { vault.saveOfflineSnapshot(session, api.subscriptionAccess(session.accessToken), binding) }
            catch (c: CancellationException) { throw c }
            catch (_: Exception) { /* No new offline authorization on an unconfirmed response. */ }
        }

        val database = try { withContext(Dispatchers.IO) { SecureLocalDatabase.open(applicationContext) } }
        catch (c: CancellationException) { throw c }
        catch (_: Exception) { return Result.retry() }

        return try {
            if(vault.binding()!=binding)return Result.success()
            val repository = NaxaServicesLocalRepository(database)
            val summary = runNaxaServicesSyncCycle(repository, api, session){vault.binding()==binding}
            if (shouldRetrySyncWorker(summary.outgoing.retried, summary.hasMore)) Result.retry() else Result.success()
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: RememberedSessionChanged) {
            Result.success()
        } catch (_: Exception) {
            Result.retry()
        } finally {
            database.close()
        }
    }
}
