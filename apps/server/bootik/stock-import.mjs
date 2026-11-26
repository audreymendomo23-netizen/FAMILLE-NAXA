// BOOTIK adaptation of NAXA importStock.ts header normalization.
// Strict CSV: no fuzzy SKU matching, no locale-dependent thousands inference, preserve barcode zeros.
export const profileColumns={
 boutique:['categorie','marque','conditionnement'],superette:['categorie','marque','rayon','conditionnement'],
 poissonnerie:['espece','origine','condition_conservation','presentation'],boulangerie:['famille_stock','recette_reference','conditionnement'],
 shopping:['marque','taille','couleur','collection','matiere'],alimentation:['categorie','conditionnement','marque'],
 cave:['marque','contenance','type_contenant','conditionnement'],quincaillerie:['reference_technique','dimension','matiere','conditionnement'],
 parfumerie:['marque','contenance','gamme','type_produit'],boucherie:['espece','morceau','origine','condition_conservation'],
 ferme:['production','date_collecte','origine','conditionnement'],depot_gaz:['marque','capacite','etat_bouteille','proprietaire'],
 supermarche:['departement','rayon','marque','conditionnement'],brocante:['numero_inventaire','etat','provenance','article_unique'],
 boissons_brasseries:['marque','contenance','type_contenant','conditionnement'],gaz_energie:['marque','capacite','etat_bouteille','proprietaire'],
 alimentaire_fmcg:['marque','conditionnement','origine','palette'],frais_surgeles:['origine','condition_conservation','temperature','conditionnement'],
 hygiene_entretien:['marque','format','gamme','conditionnement'],beaute_soins:['marque','format','gamme','conditionnement'],
 importateur_marques:['marque','origine','reference_import','conditionnement'],agro_intrants:['origine','famille','condition_conservation','fiche_technique']
};
const common=['nom','sku','unite','prix_fcfa','code_barres','lot','peremption','emplacement','minimum','cible','quantite_initiale'];
export function template(profile){const cols=profileColumns[profile];if(!cols)throw Error('UNKNOWN_PROFILE');return '\uFEFF'+[...common,...cols].join(';')+'\r\n'}
export function parseCsv(source){
 if(typeof source!=='string'||source.length>10000||source.includes('\u0000'))throw Error('INVALID_CSV');
 const s=source.replace(/^\uFEFF/,'');let row=[],rows=[],field='',quoted=false,closed=false;
 const pushField=()=>{row.push(field);field='';closed=false};const pushRow=()=>{pushField();if(row.some(x=>x.trim()!==''))rows.push(row);row=[]};
 for(let i=0;i<s.length;i++){const ch=s[i];
  if(quoted){if(ch==='"'){if(s[i+1]==='"'){field+='"';i++}else{quoted=false;closed=true}}else field+=ch;continue}
  if(ch==='"'){if(field||closed)throw Error('INVALID_CSV_QUOTE');quoted=true}
  else if(ch===';')pushField();else if(ch==='\n'||ch==='\r'){if(ch==='\r'&&s[i+1]==='\n')i++;pushRow()}
  else{if(closed)throw Error('INVALID_CSV_QUOTE');field+=ch}
 }
 if(quoted)throw Error('INVALID_CSV_QUOTE');if(field||row.length||closed)pushRow();return rows;
}
const norm=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim().replace(/[^a-z0-9]+/g,'_');
const decimal=(s,integer=false)=>{const v=String(s??'').trim();if(!v)return 0;if(!/^[0-9]+(?:[.,][0-9]{1,6})?$/.test(v))throw Error('NOMBRE_INVALIDE');const n=Number(v.replace(',','.'));if(!Number.isFinite(n)||n<0||n>1000000000||(integer&&!Number.isSafeInteger(n)))throw Error('NOMBRE_INVALIDE');return n};
export function previewCsv(profile,source,normalizeMaster){
 const rows=parseCsv(source),fields=[...common,...(profileColumns[profile]??[])];if(!profileColumns[profile]||rows.length<2||rows.length>31)throw Error('CSV_1_A_30_LIGNES');
 const header=rows.shift().map(norm);if(new Set(header).size!==header.length||header.some(x=>!fields.includes(x))||!['nom','sku','unite','prix_fcfa'].every(x=>header.includes(x)))throw Error('ENTETES_INVALIDES');
 const seenSku=new Set(),seenBar=new Set();
 return rows.map((row,i)=>{try{
  if(row.length!==header.length)throw Error('COLONNES_INVALIDES');const p=Object.fromEntries(header.map((k,j)=>[k,row[j].trim()]));
  if(!p.prix_fcfa)throw Error('PRIX_REQUIS');
  const attributes={};for(const field of profileColumns[profile]){const val=p[field]??'';if(val.length>160)throw Error('ATTRIBUT_TROP_LONG');if(val)attributes[field]=val}
  if(profile==='brocante'&&attributes.article_unique&&!['oui','non'].includes(norm(attributes.article_unique)))throw Error('ARTICLE_UNIQUE_OUI_NON');
  const serialized=profile==='brocante'&&norm(attributes.article_unique)==='oui';const quantity=decimal(p.quantite_initiale);
  if(serialized&&quantity>0)throw Error('ARTICLE_UNIQUE_STOCK_DEDIE_REQUIS');
  if(['unit','unite','piece','bouteille','carton','pack','sac','casier','palette'].includes(norm(p.unite))&&!Number.isInteger(quantity))throw Error('UNITE_INDIVISIBLE');
  const expiry=p.peremption??'';if(expiry){const t=new Date(expiry+'T00:00:00Z');if(!Number.isFinite(t.getTime())||t.toISOString().slice(0,10)!==expiry||expiry<new Date().toISOString().slice(0,10))throw Error('PEREMPTION_INVALIDE')}
  const data=normalizeMaster('item',{name:p.nom,sku:p.sku,unit:p.unite,price_fcfa:decimal(p.prix_fcfa,true),barcode:p.code_barres,lot_code:p.lot,expiry,location:p.emplacement,minimum_quantity:decimal(p.minimum),target_quantity:decimal(p.cible)});
  if(seenSku.has(data.sku)||(data.barcode&&seenBar.has(data.barcode)))throw Error('DOUBLON_FICHIER');
  seenSku.add(data.sku);if(data.barcode)seenBar.add(data.barcode);
  return {row:i+2,status:'create',data:{...data,attributes,is_serialized:serialized},quantity};
 }catch(e){return {row:i+2,status:'reject',reason:e.message||'LIGNE_INVALIDE'}}});
}
