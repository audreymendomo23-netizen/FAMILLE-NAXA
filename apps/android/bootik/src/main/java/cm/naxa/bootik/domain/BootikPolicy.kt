package cm.naxa.bootik.domain
object BootikPolicy {
 fun quote(universe:String,plan:String,months:Int):Long {
  require(months==1 || months==12)
  val monthly=when(universe to plan){
   "retailer" to "access" -> 4000L
   "retailer" to "premium" -> 10000L
   "distributor" to "access" -> 10000L
   "distributor" to "premium" -> 25000L
   else -> throw IllegalArgumentException("unsupported_offer")
  };return monthly * (if(months==12) 10 else 1)
 }
 fun trialEnd(activatedAt:Long):Long {require(activatedAt>=0);return Math.addExact(activatedAt,259200000L)}
 val modules=setOf("dashboard","catalog","stock","pos","purchases","crm","finance","staff","b2b","delivery","ai","security","support","billing")
 fun validScope(app:String,org:String,member:String,site:String,expiry:Long,now:Long)=app=="BOOTIK"&&org.isNotBlank()&&member.isNotBlank()&&site.isNotBlank()&&expiry>now
}
