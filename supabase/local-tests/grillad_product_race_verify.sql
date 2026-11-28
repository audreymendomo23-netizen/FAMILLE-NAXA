\set ON_ERROR_STOP on
do $test$ declare a uuid:='93000000-0000-0000-0000-000000000001';b uuid:='93000000-0000-0000-0000-000000000002';i uuid:='94000000-0000-0000-0000-000000000099';
begin
 if (select count(distinct family) from grillad_private.items where site=a)<>5 then raise exception 'REC-01 five families';end if;
 if (select count(distinct actor) from grillad_private.sales where item=i and qty=1)<>3 then raise exception 'REC-23 three sellers';end if;
 if (select count(*) from grillad_private.sales where item=i and qty=2)<>2 then raise exception 'REC-26 race winners';end if;
 if (select sold from grillad_private.items where id=i)<>7 then raise exception 'REC-26 stock';end if;
 if (select count(*) from grillad_private.sales where item=i)<>5 or (select sum(total) from grillad_private.sales where item=i)<>7000 then raise exception 'REC-14/21 no duplicate';end if;
 if (select sum(amount) from grillad_private.cash_receipts where site=a)<>12000 or (select sum(amount) from grillad_private.cash_receipts where site=b)<>500 then raise exception 'REC-20/24 cash separation';end if;
 if (select count(*) from grillad_private.sales where site=a)<>10 or (select count(*) from grillad_private.sales where site=b)<>1 then raise exception 'REC-24 sales separation';end if;
end $test$;
