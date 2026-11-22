package cm.naxa.naxaservices

import android.content.Context
import androidx.room.Room
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
import cm.naxa.naxaservices.auth.SessionVault
import cm.naxa.naxaservices.data.NS_SERVICES_MIGRATION_1_2
import cm.naxa.naxaservices.data.NS_SERVICES_MIGRATION_2_3
import cm.naxa.naxaservices.data.NS_SERVICES_MIGRATION_3_4
import cm.naxa.naxaservices.data.NS_SERVICES_MIGRATION_4_5
import cm.naxa.naxaservices.data.NS_SERVICES_MIGRATION_5_6
import cm.naxa.naxaservices.data.NS_SERVICES_MIGRATION_6_7
import cm.naxa.naxaservices.data.NS_SERVICES_MIGRATION_7_8
import cm.naxa.naxaservices.data.NS_SERVICES_MIGRATION_8_9
import cm.naxa.naxaservices.data.NS_SERVICES_MIGRATION_9_10
import cm.naxa.naxaservices.data.NS_SERVICES_MIGRATION_10_11
import cm.naxa.naxaservices.data.NS_SERVICES_MIGRATION_11_12
import cm.naxa.naxaservices.data.NS_SERVICES_MIGRATION_12_13
import cm.naxa.naxaservices.data.NS_SERVICES_MIGRATION_13_14
import cm.naxa.naxaservices.data.NaxaServicesLocalRepository
import cm.naxa.naxaservices.data.NsServicesDatabase
import java.util.concurrent.TimeUnit

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

class NaxaServicesSyncWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val vault = SessionVault(applicationContext)
        val refreshToken = vault.loadRefreshToken()?.takeIf { it.isNotBlank() } ?: return Result.success()
        if (!SupplierSyncCoordinator.isConfigured()) return Result.success()

        val api = AuthApi(applicationContext)
        val session = try {
            api.refresh(refreshToken, rememberDevice = true)
        } catch (failure: AuthApiException) {
            if (failure.statusCode == 401 || failure.statusCode == 403) {
                vault.clear()
                NaxaServicesSyncScheduler.cancel(applicationContext)
                return Result.success()
            }
            return Result.retry()
        } catch (_: Exception) {
            return Result.retry()
        }

        if (session.deviceId.isBlank()) return Result.retry()
        vault.save(session)

        val database = Room.databaseBuilder(
            applicationContext,
            NsServicesDatabase::class.java,
            "naxa-services-local.db"
        ).addMigrations(
            NS_SERVICES_MIGRATION_1_2,
            NS_SERVICES_MIGRATION_2_3,
            NS_SERVICES_MIGRATION_3_4,
            NS_SERVICES_MIGRATION_4_5,
            NS_SERVICES_MIGRATION_5_6,
            NS_SERVICES_MIGRATION_6_7,
            NS_SERVICES_MIGRATION_7_8,
            NS_SERVICES_MIGRATION_8_9,
            NS_SERVICES_MIGRATION_9_10,
            NS_SERVICES_MIGRATION_10_11,
            NS_SERVICES_MIGRATION_11_12,
            NS_SERVICES_MIGRATION_12_13,
            NS_SERVICES_MIGRATION_13_14
        ).build()

        return try {
            val repository = NaxaServicesLocalRepository(database)
            val summary = SupplierSyncCoordinator.syncPending(repository, api, session)
            if (summary.retried > 0 && summary.applied == 0) Result.retry() else Result.success()
        } catch (_: Exception) {
            Result.retry()
        } finally {
            database.close()
        }
    }
}
