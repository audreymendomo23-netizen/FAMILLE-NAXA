package cm.naxa.widemeet.auth

data class Workspace(val id:String,val kind:String,val name:String,val role:String,val enabled:Boolean)
data class Session(val appId:String,val accessToken:String,val memberId:String,val deviceId:String,val expiresAt:Long,val serverNow:Long,val observedWall:Long,val observedMono:Long,val requirePasswordChange:Boolean,val activeWorkspaceId:String,val workspaces:List<Workspace>)
private val uuid=Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
fun validSession(s:Session):Boolean=s.appId=="WIDEMEET" && s.accessToken.length in 20..4096 && s.accessToken.none(Char::isWhitespace) && uuid.matches(s.memberId) && uuid.matches(s.deviceId) && s.serverNow>=0 && s.expiresAt>s.serverNow && s.expiresAt>s.observedWall && s.observedMono>=0 && s.workspaces.isNotEmpty() && s.workspaces.map{it.id}.distinct().size==s.workspaces.size && s.workspaces.any{it.id==s.activeWorkspaceId} && s.workspaces.all{uuid.matches(it.id)&&it.enabled&&it.name.isNotBlank()&&when(it.kind){"individual"->it.role=="owner";"enterprise"->it.role in setOf("promoteur","manager","staff");else->false}}
fun validLease(s:Session,now:Long,mono:Long):Boolean{
 if(!validSession(s)||mono<s.observedMono||now<0)return false
 val elapsed=mono-s.observedMono
 if(elapsed>=s.expiresAt-s.serverNow||now>=s.expiresAt)return false
 return now>=s.observedWall-5000 && elapsed<=now-s.observedWall+5000
}
fun activeWorkspace(s:Session,now:Long,mono:Long):Workspace?=if(validLease(s,now,mono)&&!s.requirePasswordChange)s.workspaces.firstOrNull{it.id==s.activeWorkspaceId}else null
fun mayPay(s:Session,now:Long,mono:Long):Boolean=activeWorkspace(s,now,mono)?.let{if(it.kind=="individual")it.role=="owner" else it.role=="promoteur"}?:false
