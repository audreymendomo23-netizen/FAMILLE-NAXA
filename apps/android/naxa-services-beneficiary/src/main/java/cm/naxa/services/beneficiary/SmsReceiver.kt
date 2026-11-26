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
        val pending=goAsync()
        executor.execute {
            try {
                if(allowed(origin)) {
                    BeneficiaryApi.capture(app,device,origin,message,received)
                    SecureVault.put(app,"last_status","Crédit transmis au rapprochement.")
                }
            }catch(_:Exception){
                runCatching { SecureVault.put(app,"last_status","Transmission non confirmée : contrôle administrateur requis.") }
            }finally{pending.finish()}
        }
    }
}
