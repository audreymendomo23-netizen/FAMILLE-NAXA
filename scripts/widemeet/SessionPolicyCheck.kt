package cm.naxa.widemeet.auth
fun main(){
 val member="00000000-0000-4000-8000-000000000001";val device="00000000-0000-4000-8000-000000000002";val org="00000000-0000-4000-8000-000000000003"
 val w=Workspace(org,"enterprise","Fixture","promoteur",true)
 val s=Session("WIDEMEET","test-only-token-1234567890",member,device,200000,100000,100000,100,false,org,listOf(w))
 var n=0;fun verify(v:Boolean){check(v);n++}
 verify(validSession(s));verify(mayPay(s,100000,100));verify(!mayPay(s.copy(workspaces=listOf(w.copy(role="staff"))),100000,100));verify(!mayPay(s.copy(workspaces=listOf(w.copy(role="manager"))),100000,100));verify(mayPay(s.copy(workspaces=listOf(w.copy(kind="individual",role="owner"))),100000,100));verify(!validSession(s.copy(appId="BOOTIK")));verify(!validSession(s.copy(workspaces=listOf(w,w))));verify(!validSession(s.copy(activeWorkspaceId="foreign")));verify(!validSession(s.copy(workspaces=listOf(w.copy(enabled=false)))));verify(!validLease(s,200000,100100));verify(!validLease(s,94000,100));verify(!validLease(s,100000,99));verify(activeWorkspace(s.copy(requirePasswordChange=true),100000,100)==null);verify(!validSession(s.copy(accessToken="short")));verify(!validSession(s.copy(workspaces=listOf(w.copy(kind="individual")))));println("WIDEMEET_NATIVE_SESSION_POLICY_PASS $n")
}
