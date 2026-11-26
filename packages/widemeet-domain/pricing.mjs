// WideMeet N0 — devis pur, aucun paiement, aucun droit conféré. Capacity = demande commerciale, pas preuve de présence.
export function quoteWideMeet({kind,capacity,period="monthly",plan}={}){
 if(!Number.isSafeInteger(capacity)||capacity<1) throw new RangeError("invalid_capacity");
 if(kind==="individual"){
  if(period!=="pass") throw new RangeError("invalid_pass_period");
  if(capacity>100)return {status:"enterprise_required",amountFcfa:null};
  return {status:"quoted",plan:"premium_pass",capacityLimit:capacity<=20?20:capacity<=50?50:100,amountFcfa:capacity<=20?1000:capacity<=50?3000:5000,validityMaxHours:24};
 }
 if(kind!=="enterprise"||!["monthly","annual"].includes(period)||!["access","premium"].includes(plan))throw new RangeError("invalid_enterprise_plan");
 if(plan==="access"&&capacity>20)return {status:"upgrade_required",amountFcfa:null};
 if(plan==="premium"&&capacity>50)return {status:"manual_quote_required",amountFcfa:null,monthlyCeilingFcfa:20000};
 const monthly=plan==="access"?5000:10000;
 return {status:"quoted",plan,capacityLimit:plan==="access"?20:50,amountFcfa:monthly*(period==="annual"?10:1),period};
}
