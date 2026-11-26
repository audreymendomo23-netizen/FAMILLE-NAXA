-- Candidate only; existing signature and ACL retained. Roll back by default.
begin;
create or replace function public.ns_activity_workflow_fields_valid(p text,f jsonb) returns boolean
language sql immutable set search_path='' as $function$
with definitions(profile,key,required,kind,max_length,min_value,max_value,choices) as (values
 ('coiffure','style',true,'select',500,null::numeric,null::numeric,array['coupe','tresses','locks','coloration','brushing','soin','autre']::text[]),
 ('coiffure','technique',true,'textarea',1000,null::numeric,null::numeric,array[]::text[]),
 ('coiffure','provider',false,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('coiffure','workstation',false,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('coiffure','products',false,'textarea',700,null::numeric,null::numeric,array[]::text[]),
 ('couture','garment',true,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('couture','measurements',true,'textarea',1200,null::numeric,null::numeric,array[]::text[]),
 ('couture','fabric',false,'textarea',700,null::numeric,null::numeric,array[]::text[]),
 ('couture','fitting',false,'date',500,null::numeric,null::numeric,array[]::text[]),
 ('couture','delivery',false,'date',500,null::numeric,null::numeric,array[]::text[]),
 ('beaute','treatment',true,'select',500,null::numeric,null::numeric,array['soin_visage','soin_corps','manucure','pedicure','maquillage','epilation','massage_bien_etre','autre']::text[]),
 ('beaute','protocol',true,'textarea',1000,null::numeric,null::numeric,array[]::text[]),
 ('beaute','provider',false,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('beaute','room',false,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('beaute','products',false,'textarea',700,null::numeric,null::numeric,array[]::text[]),
 ('parfumerie','product',true,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('parfumerie','format',true,'select',500,null::numeric,null::numeric,array['30ml','50ml','75ml','100ml','coffret','testeur','autre']::text[]),
 ('parfumerie','family',false,'select',500,null::numeric,null::numeric,array['floral','boisee','orientale','fraiche','gourmande','aquatique','autre']::text[]),
 ('parfumerie','batch',false,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('parfumerie','special_order',false,'textarea',700,null::numeric,null::numeric,array[]::text[]),
 ('reparation','device',true,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('reparation','fault',true,'textarea',1000,null::numeric,null::numeric,array[]::text[]),
 ('reparation','diagnosis',false,'textarea',1200,null::numeric,null::numeric,array[]::text[]),
 ('reparation','parts',false,'textarea',1000,null::numeric,null::numeric,array[]::text[]),
 ('reparation','warranty',false,'textarea',700,null::numeric,null::numeric,array[]::text[]),
 ('menuiserie','piece',true,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('menuiserie','dimensions',true,'textarea',1200,null::numeric,null::numeric,array[]::text[]),
 ('menuiserie','materials',false,'textarea',700,null::numeric,null::numeric,array[]::text[]),
 ('menuiserie','finish',false,'textarea',700,null::numeric,null::numeric,array[]::text[]),
 ('menuiserie','installation',false,'text',700,null::numeric,null::numeric,array[]::text[]),
 ('garage','vehicle',true,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('garage','odometer',false,'number',500,0::numeric,5000000::numeric,array[]::text[]),
 ('garage','fault',true,'textarea',1000,null::numeric,null::numeric,array[]::text[]),
 ('garage','diagnosis',false,'textarea',1200,null::numeric,null::numeric,array[]::text[]),
 ('garage','parts',false,'textarea',1000,null::numeric,null::numeric,array[]::text[]),
 ('garage','handover',false,'textarea',800,null::numeric,null::numeric,array[]::text[]),
 ('nettoyage','site',true,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('nettoyage','tasks',true,'textarea',1000,null::numeric,null::numeric,array[]::text[]),
 ('nettoyage','team',false,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('nettoyage','equipment',false,'textarea',800,null::numeric,null::numeric,array[]::text[]),
 ('nettoyage','checklist',false,'textarea',1200,null::numeric,null::numeric,array[]::text[]),
 ('domicile','address',true,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('domicile','service',true,'textarea',1000,null::numeric,null::numeric,array[]::text[]),
 ('domicile','provider',false,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('domicile','materials',false,'textarea',800,null::numeric,null::numeric,array[]::text[]),
 ('domicile','visit',false,'date',500,null::numeric,null::numeric,array[]::text[]),
 ('impression','format',true,'select',500,null::numeric,null::numeric,array['A6','A5','A4','A3','A2','carte_visite','flyer','affiche','grand_format','autre']::text[]),
 ('impression','quantity',true,'number',500,1::numeric,1000000::numeric,array[]::text[]),
 ('impression','colors',false,'select',500,null::numeric,null::numeric,array['mono','cmyk','spot','other']::text[]),
 ('impression','proof',false,'textarea',800,null::numeric,null::numeric,array[]::text[]),
 ('impression','finishing',false,'textarea',800,null::numeric,null::numeric,array[]::text[]),
 ('photo_evenementiel','event',true,'text',700,null::numeric,null::numeric,array[]::text[]),
 ('photo_evenementiel','date',true,'date',500,null::numeric,null::numeric,array[]::text[]),
 ('photo_evenementiel','deliverables',true,'textarea',1200,null::numeric,null::numeric,array[]::text[]),
 ('photo_evenementiel','crew',false,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('photo_evenementiel','equipment',false,'textarea',900,null::numeric,null::numeric,array[]::text[]),
 ('autre','service',true,'text',500,null::numeric,null::numeric,array[]::text[]),
 ('autre','specifications',true,'textarea',1200,null::numeric,null::numeric,array[]::text[]),
 ('autre','resources',false,'textarea',800,null::numeric,null::numeric,array[]::text[]),
 ('autre','instructions',false,'textarea',800,null::numeric,null::numeric,array[]::text[]),
 ('autre','delivery',false,'date',500,null::numeric,null::numeric,array[]::text[])
), input_fields as (
 select x.key, x.value, regexp_replace(x.value #>> '{}','^[[:space:]]+|[[:space:]]+$','','g') as normalized
 from jsonb_each(case when jsonb_typeof(f)='object' then f else '{}'::jsonb end) x
), scoped as (
 select d.*,coalesce(i.normalized,'') as v from definitions d left join input_fields i on i.key=d.key where d.profile=p
)
select coalesce(jsonb_typeof(f)='object' and exists(select 1 from scoped)
 and not exists(select 1 from input_fields i where jsonb_typeof(i.value)<>'string' or char_length(i.value #>> '{}')>1200)
 and not exists(select 1 from scoped d where
  case when d.v='' then d.required
       when char_length(d.v)>d.max_length then true
       when d.kind='select' then not(d.v=any(d.choices))
       when d.kind='date' then not(case when d.v ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then pg_input_is_valid(d.v,'date') else false end)
       when d.kind='number' then not(case when d.v ~ '^[0-9]+$' and char_length(d.v)<=16 then (d.min_value is null or d.v::numeric>=d.min_value) and (d.max_value is null or d.v::numeric<=d.max_value) else false end)
       else false end
 ),false)
$function$;
rollback;
