// Reuse NAXA Services SKU normalization; the selected lot still goes through
// ZIPPLE's server-side optimistic quantity, scope and idempotence checks.
type ScanLot={id:string;lot_label:string;ingredient_id:string};
type ScanIngredient={id:string;sku?:string};
export function resolveInventoryScan(raw:string,lots:ScanLot[],ingredients:ScanIngredient[]):string|null {
 const code=raw.trim().toUpperCase();
 if(!code||code.length>100)return null;
 const sku=new Set(ingredients.filter(i=>i.sku?.trim().toUpperCase()===code).map(i=>i.id));
 const matches=new Set(lots.filter(l=>l.id.toUpperCase()===code||l.lot_label.trim().toUpperCase()===code||sku.has(l.ingredient_id)).map(l=>l.id));
 return matches.size===1?[...matches][0]:null;
}
