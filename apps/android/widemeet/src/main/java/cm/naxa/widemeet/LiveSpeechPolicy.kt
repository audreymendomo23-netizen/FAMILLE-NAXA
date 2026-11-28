package cm.naxa.widemeet
internal data class LiveSpeechWindow(val key:String,val text:String,val ttl:Long)
internal fun liveSpeechWindow(status:String,fallback:Boolean,uncertain:Boolean,language:String,source:String,target:String,text:String,recording:String,start:Long,end:Long,remaining:Long):LiveSpeechWindow? {
 if(status!="ready"||fallback||uncertain||target!="en"||language!=target||source!="fr"||text.isBlank()||text.length>4000||remaining<=0||start<0||end<=start||!Regex("^[a-f0-9-]{36}$").matches(recording))return null
 return LiveSpeechWindow("$recording:$start:$end:$target",text,minOf(remaining,5000))
}
internal fun liveListeningRate(value:String?):Float=value?.toFloatOrNull()?.takeIf{it in setOf(0.75f,1f,1.25f,1.5f)}?:1f
