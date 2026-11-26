package cm.naxa.services.beneficiary

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.pm.PackageManager
import android.os.Bundle
import android.text.InputType
import android.widget.*
import java.util.concurrent.Executors

class MainActivity:Activity() {
    private val executor=Executors.newSingleThreadExecutor()
    private lateinit var column:LinearLayout
    private lateinit var status:TextView
    private lateinit var device:EditText
    private lateinit var consent:CheckBox
    private lateinit var reviewRows:LinearLayout
    private var busy=false
    private val reasons=arrayOf("wrong_amount","wrong_payer","wrong_destination","ambiguous_reference","outside_window","other")
    override fun onCreate(savedInstanceState:Bundle?) {
        super.onCreate(savedInstanceState)
        column=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setPadding(24,32,24,24)}
        setContentView(ScrollView(this).apply{addView(column)})
        label("NAXA SERVICES — bénéficiaire central")
        label("Application administrative privée. Aucun PIN, OTP ou SMS du payeur. Une réception seule ne valide aucun abonnement.")
        val login=field("Identifiant du compte central")
        val password=field("Mot de passe").apply{inputType=InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD}
        status=TextView(this)
        button("Connexion du compte central"){
            val id=login.text.toString().trim();val secret=password.text.toString();password.text.clear()
            work {
                BeneficiaryApi.login(this,id,secret)
                val ref=BeneficiaryApi.sessionReference(this)
                runOnUiThread { consent.isChecked=false;device.text.clear();reviewRows.removeAllViews();status.text="Session à enrôler hors application : "+ref }
            }
        }
        device=field("Identifiant UUID de l’appareil enrôlé").apply{setText(SecureVault.get(this@MainActivity,"device").orEmpty())}
        button("Vérifier l’enrôlement"){
            val id=device.text.toString().trim()
            consent.isChecked=false
            work {
                SecureVault.remove(this,"consent");SecureVault.remove(this,"device");SecureVault.remove(this,"channel")
                val channel=BeneficiaryApi.verify(this,id)
                SecureVault.put(this,"device",id);SecureVault.put(this,"channel",channel)
                runOnUiThread { status.text="Appareil autorisé : "+channel+" ; consentement séparé requis." }
            }
        }
        consent=CheckBox(this).apply{text="J’autorise la réception des seuls SMS de crédit du canal enrôlé sur ce téléphone bénéficiaire."}
        column.addView(consent)
        consent.isChecked=SecureVault.get(this,"consent")=="true" && checkSelfPermission(Manifest.permission.RECEIVE_SMS)==PackageManager.PERMISSION_GRANTED
        consent.setOnCheckedChangeListener{_,checked->
            if(!checked){SecureVault.remove(this,"consent")}
            else if(SecureVault.get(this,"device")==null||SecureVault.get(this,"channel")==null){consent.isChecked=false;status.text="Enrôlement obligatoire."}
            else if(checkSelfPermission(Manifest.permission.RECEIVE_SMS)!=PackageManager.PERMISSION_GRANTED){
                requestPermissions(arrayOf(Manifest.permission.RECEIVE_SMS),100)
            }else SecureVault.put(this,"consent","true")
        }
        column.addView(status)
        button("Actualiser le dernier état de capture"){
            val id=SecureVault.get(this,"device")
            val last=SecureVault.get(this,"last_status")?:"Aucune capture signalée."
            val count=id?.let{CaptureIncidents.outstanding(this,it)}
            status.text=last+"\n"+(count?.let{"Captures sans accusé serveur : "+it+
                if(it>0) " — rapprochement administratif requis, ne pas demander un second paiement." else ""} ?: "Appareil non enrôlé.")
        }
        button("Charger les anomalies"){loadReview()}
        reviewRows=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL};column.addView(reviewRows)
        button("Désactiver et déconnecter"){
            if(!busy){consent.isChecked=false;BeneficiaryApi.clear(this);device.text.clear();reviewRows.removeAllViews();status.text="Capture désactivée ; session locale effacée."}
        }
    }
    private fun field(hintText:String)=EditText(this).apply{hint=hintText;setSingleLine(true);column.addView(this)}
    private fun label(value:String){column.addView(TextView(this).apply{text=value;textSize=16f})}
    private fun button(value:String,action:()->Unit){column.addView(Button(this).apply{text=value;setOnClickListener{action()}})}
    private fun work(action:()->Unit){
        if(busy)return
        busy=true
        executor.execute{
            try{action()}catch(_:Exception){runOnUiThread{status.text="Opération non confirmée. Vérifier l’enrôlement, le réseau et le service central."}}
            finally{runOnUiThread{busy=false}}
        }
    }
    private fun loadReview(){
        val id=SecureVault.get(this,"device")?:return
        work {
            val rows=BeneficiaryApi.review(this,id)
            runOnUiThread {
                reviewRows.removeAllViews()
                status.text="Candidats : "+rows.length()
                for(i in 0 until rows.length()){
                    val row=rows.optJSONObject(i)?:continue
                    reviewRows.addView(TextView(this).apply{text=row.optString("status")+" · "+row.optLong("amount_xaf")+" FCFA · "+row.optString("transaction_reference")+" · payeur …"+row.optString("payer_tail")})
                    if(row.optString("status")=="review"){
                        reviewRows.addView(Button(this).apply{text="Rejeter avec motif";setOnClickListener{
                            AlertDialog.Builder(this@MainActivity).setTitle("Motif du rejet").setItems(reasons){_,index->
                                AlertDialog.Builder(this@MainActivity).setMessage("Confirmer le rejet de ce candidat ? Aucun droit ne sera activé.")
                                    .setNegativeButton("Annuler",null).setPositiveButton("Confirmer"){_,_->
                                        work { BeneficiaryApi.reject(this@MainActivity,id,row.optString("id"),reasons[index]);runOnUiThread{reviewRows.removeAllViews();status.text="Rejet confirmé. Actualisez la file."} }
                                    }.show()
                            }.show()
                        }})
                    }
                }
            }
        }
    }
    override fun onRequestPermissionsResult(requestCode:Int,permissions:Array<out String>,grantResults:IntArray){
        super.onRequestPermissionsResult(requestCode,permissions,grantResults)
        if(requestCode==100){
            if(consent.isChecked&&grantResults.firstOrNull()==PackageManager.PERMISSION_GRANTED&&SecureVault.get(this,"device")!=null)
                SecureVault.put(this,"consent","true")
            else consent.isChecked=false
        }
    }
}
