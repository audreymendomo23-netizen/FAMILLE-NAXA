export function trustedMediaGrant(row:Record<string,unknown>,scope:{organization:string;site:string;user:string;device:string;media:string},origin:string,now:number):{url:string;expiresAt:number;media:string};
export function paymentMatch(request:Record<string,unknown>,receipts:Record<string,unknown>[]):string;
export function riskSummary(rows:Record<string,unknown>[],now:number):{fresh:number;unknown:number;reasons:string[];requiresHumanDecision:boolean;status:string};
export function snapshotSummary(scope:{organization:string;site:string},counts:{total:number;open:number;closed:number},now?:number):Promise<{payload:Record<string,unknown>;digest:string}>;
export function verifySnapshot(text:string,scope:{organization:string;site:string}):Promise<{total:number;open:number;closed:number}>;
