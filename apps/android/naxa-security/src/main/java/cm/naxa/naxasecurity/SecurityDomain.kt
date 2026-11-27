package cm.naxa.naxasecurity
internal object SecurityDomain {
 fun quote(plan:String,annual:Boolean):Int=when(plan){"Essentiel"->if(annual)60000 else 5000;"Business"->if(annual)200000 else 20000;"Professional"->if(annual)500000 else 50000;else->error("INVALID_PLAN")}
 fun fresh(observed:Long?,now:Long):Boolean=observed!=null&&observed>=0&&observed<=now&&now-observed<=120000
 fun alarm(source:String,signal:String):String=when{source in listOf("fire_panel","smoke_detector")&&signal=="alarm"->"P1";signal in listOf("fault","prealarm")->"review";else->"unknown"}
 fun position(lat:Double,lon:Double,accuracy:Double,mock:Boolean,observed:Long,now:Long):Boolean=lat.isFinite()&&lon.isFinite()&&accuracy.isFinite()&&lat in -90.0..90.0&&lon in -180.0..180.0&&accuracy>0&&accuracy<=100&&!mock&&fresh(observed,now)
 fun patrol(required:List<String>,confirmed:List<String>):Boolean=required.isNotEmpty()&&required.distinct().size==required.size&&required.all{it in confirmed}
 fun validDraft(subject:String,option:String,incident:Boolean):Boolean=subject.trim().length in 1..500&&option in (if(incident)listOf("P2","P3","P4") else listOf("preventive","corrective","inspection"))
 fun delegated(active:Boolean,expires:Long,now:Long,grant:List<String>,request:List<String>):Boolean=active&&now<expires&&grant.size==5&&grant.all{it.isNotBlank()}&&grant==request&&grant.last()=="read"
}
