import test from "node:test";import assert from "node:assert/strict";import {normalizeInventoryItemDraft} from "../../../../apps/web/zipple/src/business/inventory-validation.ts";import {verifierEcritureEquilibree,calculerIndicateurs} from "../../../../apps/web/zipple/src/business/accounting/calculs.ts";
test("NAXA Services inventory validation is reused",()=>{assert.deepEqual(normalizeInventoryItemDraft({name:" Farine ",sku:"far",unit:"kg",reorderLevel:1.25,supplierWhatsApp:"+237 699 000 000"}),{name:"Farine",sku:"FAR",unit:"kg",reorderLevel:1.25,supplierWhatsApp:"237699000000"});assert.throws(()=>normalizeInventoryItemDraft({name:"Farine",unit:"kg",reorderLevel:0.0001}))});
test("NAXA accounting balance and unknown cost",()=>{const entry={id:"fixture",etablissementId:"fixture",dateEcriture:"2026-11-26",journalCode:"TEST",libelle:"Fixture only",lignes:[{compteId:"test1",libelle:"débit",debitFcfa:2500,creditFcfa:0},{compteId:"test2",libelle:"crédit",debitFcfa:0,creditFcfa:2500}]};assert.equal(verifierEcritureEquilibree(entry).valide,true);assert.equal(verifierEcritureEquilibree({...entry,lignes:[entry.lignes[0],{...entry.lignes[1],creditFcfa:1}]}).valide,false);assert.equal(calculerIndicateurs({chiffreAffairesFcfa:2500}).margeBruteFcfa,null)});

import {resolveInventoryScan} from "../../../../apps/web/zipple/src/business/inventory-scan.ts";
test("ZIPPLE scan resolves only one scoped lot; unknown and ambiguous codes fail closed",()=>{
 const ingredients=[{id:"i1",sku:"00123"},{id:"i2",sku:"BAR"}];
 const lots=[{id:"l1",lot_label:"LOT-A",ingredient_id:"i1"},{id:"l2",lot_label:"LOT-B",ingredient_id:"i1"},{id:"l3",lot_label:"LOT-C",ingredient_id:"i2"}];
 assert.equal(resolveInventoryScan(" lot-a ",lots,ingredients),"l1");
 assert.equal(resolveInventoryScan("BAR",lots,ingredients),"l3");
 assert.equal(resolveInventoryScan("00123",lots,ingredients),null);
 assert.equal(resolveInventoryScan("123",lots,ingredients),null);
 assert.equal(resolveInventoryScan("l2",lots,ingredients),"l2");
 assert.equal(resolveInventoryScan("OTHER",lots,ingredients),null);
 assert.equal(resolveInventoryScan("",lots,ingredients),null);
 assert.equal(resolveInventoryScan("BAR",[...lots,{id:"l4",lot_label:"BAR",ingredient_id:"i1"}],ingredients),null);
});
