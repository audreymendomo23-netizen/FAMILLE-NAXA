export type Module={id:string;bulk:string;title:string;screen:string;kind:string;fields:string[];example:string[];note:string};
export const modules:Module[];
export const persistentKinds:string[];
export function evaluate(id:string,input:Record<string,string>):{module:string;kind:string;payload:Record<string,unknown>;result:string;persist:boolean};
export function summarizeIncidents(rows:Record<string,unknown>[]):{total:number;closed:number;open:number;priorities:Record<string,number>};
export function csv(rows:unknown[][]):string;
export function matchesReceipt(row:Record<string,unknown>,body:Record<string,unknown>):boolean;
export function evidenceHash(bytes:ArrayBuffer):Promise<string>;
