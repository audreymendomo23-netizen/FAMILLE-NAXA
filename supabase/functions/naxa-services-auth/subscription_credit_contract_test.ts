import {parseSubscriptionCredit} from "./subscription_credit_contract.ts";
function assert(value:unknown,message:string){if(!value)throw new Error(message);}
Deno.test("central capture recognizes complete MTN credit, not debit or short notification",()=>{
 const good="You have received 3,000 XAF from Fixture (237690000071) to your Mobile Money account at 2026-11-25 10:00:00. Financial transaction ID: TX-FIXTURE-123";
 const p=parseSubscriptionCredit(good,"mtn_momo","237690000072","2026-11-25T09:00:01Z");
 assert(p?.amount===3000&&p.ref==="TXFIXTURE123"&&p.payer==="690000071"&&p.occurredAt==="2026-11-25T09:00:00.000Z","MTN credit parsing failed");
 assert(parseSubscriptionCredit("Your payment of 3000 XAF was successful","mtn_momo","237690000072","2026-11-25T09:00:01Z")===null,"Debit accepted as credit");
});
Deno.test("Orange credit must target the enrolled merchant",()=>{
 const good="Payment de 237690000072 NAXA par 237690000071 Fixture reussi. Informations detaillees: ID transaction: AB.CD1234, montant transaction: 3000 FCFA";
 const p=parseSubscriptionCredit(good,"orange_money","237690000072","2026-11-25T09:00:01Z");
 assert(p?.ref==="ABCD1234"&&p.amount===3000,"Orange credit parsing failed");
 assert(parseSubscriptionCredit(good,"orange_money","237690000099","2026-11-25T09:00:01Z")===null,"Wrong beneficiary accepted");
});
