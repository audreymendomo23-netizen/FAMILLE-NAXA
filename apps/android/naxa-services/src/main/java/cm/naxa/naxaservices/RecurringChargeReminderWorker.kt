package cm.naxa.naxaservices

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import java.util.Calendar
import cm.naxa.naxaservices.data.SecureLocalDatabase
import cm.naxa.naxaservices.auth.SessionVault
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class RecurringChargeReminderWorker(
    context: Context,
    parameters: WorkerParameters
) : CoroutineWorker(context, parameters) {

    override suspend fun doWork(): Result {
        val orgId = inputData.getString(KEY_ORGANIZATION_ID)?.takeIf { it.isNotBlank() } ?: return Result.failure()
        val permitted = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        if (!permitted || !NotificationManagerCompat.from(applicationContext).areNotificationsEnabled()) return Result.success()

        val vault = SessionVault(applicationContext)
        val binding = vault.binding() ?: return Result.success()
        if (!vault.matchesOrganization(binding, orgId)) return Result.success()
        val database = try { withContext(Dispatchers.IO) { SecureLocalDatabase.open(applicationContext) } }
        catch (c: CancellationException) { throw c }
        catch (_: Exception) { return Result.retry() }

        return try {
            ensureChannel()
            val now = System.currentTimeMillis()
            val startOfToday = Calendar.getInstance().apply {
                timeInMillis = now
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val charges = database.naxaServicesDao().findActiveRecurringCharges(orgId)
            charges.forEach { charge ->
                if (!vault.matchesOrganization(binding, orgId)) return Result.success()
                val paid = database.naxaServicesDao().sumChargePaymentsForCycle(charge.id, charge.nextDueAtMillis)
                val balance = (charge.amountXaf - paid).coerceAtLeast(0L)
                val reminderStartsAt = charge.nextDueAtMillis - charge.reminderDays * DAY_MILLIS
                val alreadyNotifiedToday = (charge.lastReminderAtMillis ?: 0L) >= startOfToday
                if (balance > 0L && now >= reminderStartsAt && !alreadyNotifiedToday) {
                    val dueDate = java.text.SimpleDateFormat("dd/MM/yyyy", java.util.Locale.getDefault())
                        .format(java.util.Date(charge.nextDueAtMillis))
                    val days = ((charge.nextDueAtMillis - now) / DAY_MILLIS).toInt()
                    val timing = when {
                        charge.nextDueAtMillis < startOfToday -> "En retard"
                        days <= 0 -> "À payer aujourd'hui"
                        days == 1 -> "Échéance demain"
                        else -> "Échéance dans " + days + " jours"
                    }
                    val open = PendingIntent.getActivity(
                        applicationContext,
                        charge.id.hashCode(),
                        Intent(applicationContext, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
                        .setSmallIcon(android.R.drawable.ic_dialog_info)
                        .setContentTitle("NAXA SERVICES")
                        .setContentText("Une échéance nécessite votre attention.")
                        .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                        .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                        .setAutoCancel(true)
                        .setContentIntent(open)
                        .build()
                    NotificationManagerCompat.from(applicationContext).notify(charge.id.hashCode(), notification)
                    database.naxaServicesDao().updateRecurringCharge(
                        charge.copy(lastReminderAtMillis = now, updatedAtMillis = now)
                    )
                }
            }
            Result.success()
        } catch (c: CancellationException) { throw c
        } catch (failure: Exception) {
            Result.retry()
        } finally {
            database.close()
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Échéances et charges", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
    }

    companion object {
        const val KEY_ORGANIZATION_ID = "organization_id"
        const val CHANNEL_ID = "naxa_services_charge_due"
        private const val DAY_MILLIS = 86_400_000L
    }
}
