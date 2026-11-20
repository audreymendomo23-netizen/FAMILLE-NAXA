package cm.naxa.naxaservices
import android.content.Context
import java.util.Calendar

data class NaxaActivityProfile(val key:String,val titleFr:String,val titleEn:String,val descriptionFr:String,val descriptionEn:String,val icon:String)
object NaxaActivityCatalog {
 val profiles = listOf(
  NaxaActivityProfile("pressing","Pressing / Blanchisserie","Laundry / Dry cleaning","Dépôts, tickets, pièces, statuts et retraits","Drop-offs, tickets, items, status and pickup","🧺"),
  NaxaActivityProfile("coiffure","Salon de coiffure / Barber","Hair salon / Barber shop","Rendez-vous, fauteuils, prestations et commissions","Appointments, chairs, services and commissions","💈"),
  NaxaActivityProfile("couture","Couture / Retouche","Tailoring / Alterations","Devis, mensurations, matières et étapes atelier","Quotes, measurements, materials and workshop stages","🧵"),
  NaxaActivityProfile("beaute","Beauté / Esthétique / Onglerie","Beauty / Aesthetics / Nails","Cabines, rendez-vous, forfaits et prestataires","Rooms, appointments, packages and providers","💅"),
  NaxaActivityProfile("parfumerie","Parfumerie","Perfume shop","Produits, formats, fournisseurs, stocks et marges","Products, sizes, suppliers, stock and margins","🌸"),
  NaxaActivityProfile("reparation","Réparation / Électronique","Repair / Electronics","Diagnostic, devis, pièces et ordres de réparation","Diagnostics, quotes, parts and repair orders","🛠️"),
  NaxaActivityProfile("menuiserie","Menuiserie / Atelier","Carpentry / Workshop","Matières, fabrication, coûts et livraison","Materials, production, costs and delivery","🪚"),
  NaxaActivityProfile("garage","Garage / Lavage automobile","Garage / Car wash","Véhicules, interventions, pièces et main-d’œuvre","Vehicles, jobs, parts and labor","🚗"),
  NaxaActivityProfile("nettoyage","Nettoyage / Entretien","Cleaning / Facility services","Contrats, équipes, sites et interventions","Contracts, teams, sites and work orders","🧽"),
  NaxaActivityProfile("domicile","Services à domicile","Home services","Demandes, déplacements, devis et techniciens","Requests, travel, quotes and technicians","🏠"),
  NaxaActivityProfile("impression","Imprimerie / Photocopie","Printing / Copy shop","Fichiers, quantités, supports et commandes","Files, quantities, media and jobs","🖨️"),
  NaxaActivityProfile("photo_evenementiel","Photographie / Événementiel","Photography / Events","Réservations, forfaits, matériel et livrables","Bookings, packages, equipment and deliverables","📸"),
  NaxaActivityProfile("autre","Autre activité de services","Other service activity","Modèle configurable par le Promoteur","Configurable model managed by the owner","🧰")
 )
 fun find(key:String?):NaxaActivityProfile? = profiles.firstOrNull { it.key == key }
}
class NaxaServicesPreferences(context:Context) {
 private val prefs=context.getSharedPreferences("naxa_services_preferences_v2",Context.MODE_PRIVATE)
 fun saveActivity(orgId:String,profile:String){ if(orgId.isNotBlank() && NaxaActivityCatalog.find(profile)!=null) prefs.edit().putString("activity:"+orgId,profile).apply() }
 fun cachedActivity(orgId:String):String?=prefs.getString("activity:"+orgId,null)
 fun locale():String=prefs.getString("locale","fr")?.takeIf { it in setOf("fr","en") } ?: "fr"
 fun saveLocale(value:String){if(value in setOf("fr","en")) prefs.edit().putString("locale",value).apply()}
 fun saveTheme(mode:String,startMinute:Int,endMinute:Int,flashlight:Boolean){ prefs.edit().putString("theme_mode",mode).putInt("night_start",startMinute.coerceIn(0,1439)).putInt("night_end",endMinute.coerceIn(0,1439)).putBoolean("flashlight_enabled",flashlight).apply() }
 fun themeMode():String=prefs.getString("theme_mode","dark")?:"dark"
 fun nightStart():Int=prefs.getInt("night_start",20*60)
 fun nightEnd():Int=prefs.getInt("night_end",7*60)
 fun flashlightEnabled():Boolean=prefs.getBoolean("flashlight_enabled",true)
 fun isLightNow():Boolean = when(themeMode()) {
  "light" -> true
  "scheduled" -> {
   val c=Calendar.getInstance(); val now=c.get(Calendar.HOUR_OF_DAY)*60+c.get(Calendar.MINUTE)
   val start=nightStart(); val end=nightEnd()
   val isNight=if(start==end) true else if(start<end) now>=start && now<end else now>=start || now<end
   !isNight
  }
  else -> false
 }
}
