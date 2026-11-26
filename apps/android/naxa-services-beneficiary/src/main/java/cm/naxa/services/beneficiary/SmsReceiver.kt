package cm.naxa.services.beneficiary

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Telephony
import java.util.concurrent.Executors

class SmsReceiver:BroadcastReceiver() {
    companion object { private val executor=Executors.newSingleThreadExecutor() }
    override fun onReceive(context:Context,intent:Intent?) {
        if(intent?.action!=Telephony.Sms.Intents.SMS_RECEIVED_ACTION)return
        val app=context.applicationContext
        val device=SecureVault.get(app,"device")?:return
        val channel=SecureVault.get(app,"channel")?:return
        fun allowed(origin:String?):Boolean = SecureVault.get(app,"device")==device &&
            SecureVault.get(app,"channel")==channel &&
            CapturePolicy.allowed(channel,SecureVault.get(app,"consent")=="true",
                app.checkSelfPermission(Manifest.permission.RECEIVE_SMS)==PackageManager.PERMISSION_GRANTED,origin)
        val parts=runCatching { Telephony.Sms.Intents.getMessagesFromIntent(intent) }.getOrNull()?:return
        val origin=parts.firstOrNull()?.originatingAddress?:return
        if(!allowed(origin)||parts.any { it.originatingAddress!=origin })return
        val message=parts.joinToString("") { it.messageBody.orEmpty() }
        if(!CapturePolicy.creditCandidate(channel,message))return
        val received=System.currentTimeMillis()
        // Persist only an unresolved counter, before handing work to the process.
        // A crash or failed request must never be hidden by a later successful capture.
        if (!CaptureIncidents.begin(app,device)) {
            runCatching { SecureVault.put(app,"last_status","Journal de capture indisponible : contrôle administrateur requis.") }
            return
        }
        val pending=goAsync()
        executor.execute {
            try {
                if(allowed(origin)) {
                    BeneficiaryApi.capture(app,device,origin,message,received)
                    check(CaptureIncidents.confirm(app,device)) { "Journal de capture indisponible." }
                    SecureVault.put(app,"last_status","Crédit transmis au rapprochement.")
                }
            }catch(_:Exception){
                runCatching { SecureVault.put(app,"last_status","Transmission non confirmée : contrôle administrateur requis.") }
            }finally{pending.finish()}
        }
    }
}


/** Counts transmissions without positive server acknowledgment, scoped to the enrolled
 * device. No message, sender, amount, reference, credentials or raw SMS are persisted.
 * A later success removes only its own pending count. */
internal object CaptureIncidents {
    private fun prefs(context:Context)=context.applicationContext.getSharedPreferences("ns_beneficiary_incident_counts_v1",Context.MODE_PRIVATE)
    @Synchronized fun outstanding(context:Context,device:String):Int = prefs(context).getInt(device,0).coerceAtLeast(0)
    @Synchronized fun begin(context:Context,device:String):Boolean {
        val next=CapturePolicy.nextOutstanding(outstanding(context,device),false) ?: return false
        return prefs(context).edit().putInt(device,next).commit()
    }
    @Synchronized fun confirm(context:Context,device:String):Boolean {
        val next=CapturePolicy.nextOutstanding(outstanding(context,device),true) ?: return false
        return prefs(context).edit().putInt(device,next).commit()
    }
}
