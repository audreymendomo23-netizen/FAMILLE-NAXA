package cm.naxa.grillad
internal object OfflineCatalogPolicy{
 const val MAX_AGE_MS=8L*60*60*1000
 fun valid(cachedUser:String,user:String,cachedDay:String,day:String,savedAt:Long,now:Long):Boolean=
  cachedUser.isNotBlank()&&cachedUser==user&&cachedDay==day&&savedAt>0&&now>=savedAt&&now-savedAt<=MAX_AGE_MS
}
