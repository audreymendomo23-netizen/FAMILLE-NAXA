import {describe,it,expect} from "vitest";
import {commissionPolicyPayload,validateCommissionCatalog} from "./commission-settings";
const org="20000000-0000-4000-8000-000000000001",id="70000000-0000-4000-8000-000000000001";
const valid={code:"QA",version:"1",method:"percent_bps" as const,amount:"12,50",site:"",member:"",service:"",activity:false,from:"2026-11-27",until:"",reference:"Approved terms",approved:true};
describe("commission settings candidate",()=>{
 it("translates explicit percentage without default rate",()=>expect(commissionPolicyPayload(valid,org,"coiffure",id)).toMatchObject({p_rate:1250,p_fixed:null,p_site:null,p_member:null,p_service:null,p_activity:null,p_id:id}));
 it("supports explicit fixed amount and activity",()=>expect(commissionPolicyPayload({...valid,method:"fixed_xaf",amount:"500",activity:true},org,"coiffure",id)).toMatchObject({p_rate:null,p_fixed:500,p_activity:"coiffure"}));
 it("fails closed for absent amount, invalid dates, and missing approval",()=>{for(const patch of [{amount:""},{amount:"101"},{from:"2026-02-30"},{approved:false},{until:"2026-11-26"}])expect(()=>commissionPolicyPayload({...valid,...patch},org,"coiffure",id)).toThrow();});
 it("requires confirmed settings and rejects malformed catalog",()=>{const c={settings:{enabled:false,revision:0},sites:[],members:[],services:[],policies:[]};expect(validateCommissionCatalog(c)).toEqual(c);expect(()=>validateCommissionCatalog({...c,settings:{enabled:"false",revision:0}})).toThrow();expect(()=>validateCommissionCatalog({...c,sites:[{id:"bad",name:"QA"}]})).toThrow();});
});

it("rejects a persisted policy with an implicit or invalid rate",()=>{const p={id,code:"QA",version:1,status:"approved",method:"percent_bps",rate_bps:1000,fixed_amount_xaf:null,effective_from:"2026-11-27",effective_until:null,site_id:null,member_id:null,service_id:null,activity_profile:null,reference:"Approved terms"};const c={settings:{enabled:true,revision:1},sites:[],members:[],services:[],policies:[p]};expect(validateCommissionCatalog(c)).toEqual(c);for(const patch of [{rate_bps:null},{rate_bps:10001},{fixed_amount_xaf:500},{effective_from:"2026-02-30"}])expect(()=>validateCommissionCatalog({...c,policies:[{...p,...patch}]})).toThrow();});

it("rejects ambiguous duplicate catalog IDs and malformed choice scopes",()=>{const c={settings:{enabled:false,revision:0},sites:[],members:[],services:[],policies:[]};const choice={id,name:"QA"};expect(()=>validateCommissionCatalog({...c,sites:[choice,{...choice,id:id.toUpperCase()}]})).toThrow();expect(()=>validateCommissionCatalog({...c,services:[{...choice,site_id:"foreign"}]})).toThrow();});

it("never silently widens an explicitly selected activity scope",()=>{for(const activity of ["","unknown","  "])expect(()=>commissionPolicyPayload({...valid,activity:true},org,activity,id)).toThrow();expect(commissionPolicyPayload({...valid,activity:true,site:org,member:id,service:id},org,"coiffure",id)).toMatchObject({p_site:org,p_member:id,p_service:id,p_activity:"coiffure"});});
