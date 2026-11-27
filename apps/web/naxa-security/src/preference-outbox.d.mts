export type Scope={organization:string;site:string;user:string};
export type PreferenceEvent=Scope&{key:string;id:string;kind:string;payload:Record<string,string>};
export function preferenceEvent(scope:Scope,key:string,value:string,id:string):PreferenceEvent;
export function eventScope(e:PreferenceEvent,s:Scope):boolean;
export function eventBody(e:PreferenceEvent):Record<string,unknown>;
export function validPreferenceReceipt(e:PreferenceEvent,r:Record<string,unknown>):boolean;
export function samePending(a:PreferenceEvent,b:PreferenceEvent):boolean;
