package cm.naxa.grillad
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.Image
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.unit.dp
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable internal fun GrilladReferral(enabled:Boolean,request:suspend(JSONObject)->Any){
 val scope=rememberCoroutineScope();val ctx=LocalContext.current
 var data by remember{mutableStateOf<JSONObject?>(null)};var code by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
 fun act(op:String){if(busy||!enabled)return;busy=true;message="";scope.launch{try{val body=obj("action" to "referral","operation" to op);if(op=="attach")body.put("code",GrilladReferralCode.normalize(code)?:error("Code invalide"));data=request(body) as JSONObject;if(op=="attach")code=""}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Opération non confirmée. Actualisez avant de réessayer."}finally{busy=false}}}
 Text("Parrainage GRILLAD",style=MaterialTheme.typography.titleMedium);OutlinedButton({act("list")},enabled=enabled&&!busy){Text("Actualiser")}
 data?.let{d->val own=d.optString("code","");if(own.isBlank()||d.isNull("code"))Button({act("generate")},enabled=enabled&&!busy){Text("Générer mon code")}else{Text(own);val qr=remember(own){runCatching{val matrix=GrilladReferralCode.qr(own);val pixels=IntArray(matrix.width*matrix.height){i->if(matrix[i%matrix.width,i/matrix.width])android.graphics.Color.BLACK else android.graphics.Color.WHITE};android.graphics.Bitmap.createBitmap(pixels,matrix.width,matrix.height,android.graphics.Bitmap.Config.ARGB_8888).asImageBitmap()}.getOrNull()};qr?.let{Image(it,"QR de parrainage GRILLAD",Modifier.size(240.dp))};OutlinedButton({val clipboard=ctx.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager;clipboard.setPrimaryClip(android.content.ClipData.newPlainText("GRILLAD",own));message="Code copié"},enabled=enabled&&!busy){Text("Copier le code")}}
 Text("Filleuls rattachés : "+d.optInt("referrals"));Text("Filleuls avec abonnement rapproché : "+d.optInt("paid_referrals"));if(own.isNotBlank()&&!d.isNull("code"))OutlinedButton({val intent=android.content.Intent(android.content.Intent.ACTION_SEND).setType("text/plain").putExtra(android.content.Intent.EXTRA_TEXT,"Mon code GRILLAD : "+own);ctx.startActivity(android.content.Intent.createChooser(intent,"Partager mon code"))},enabled=enabled&&!busy){Text("Partager mon code")};if(!d.optBoolean("linked")){OutlinedTextField(code,{if(it.length<=2048)code=GrilladReferralCode.normalize(it)?:it},label={Text("Code ou lien du parrain")});Button({act("attach")},enabled=enabled&&!busy&&GrilladReferralCode.normalize(code)!=null){Text("Rattacher le parrain")}};Text("Récompenses non activées : conditions à valider.")}
 if(message.isNotBlank())Text(message)
}
