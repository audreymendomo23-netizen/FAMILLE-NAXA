package cm.naxa.zipple
import android.content.Context

/** Device biometrics are optional convenience after a successful member PIN. */
object ZippleBiometricPolicy {
 fun allowed(pinConfigured:Boolean, optedIn:Boolean, available:Boolean, sameSession:Boolean, expiresAt:Long, now:Long):Boolean =
  pinConfigured && optedIn && available && sameSession && expiresAt>now
}
class ZippleBiometricPreferences(context:Context){
 private val prefs=context.getSharedPreferences("zipple_biometric_opt_in",Context.MODE_PRIVATE)
 fun enabled(member:String)=prefs.getBoolean(member,false)
 fun set(member:String,enabled:Boolean){check(prefs.edit().putBoolean(member,enabled).commit())}
}
