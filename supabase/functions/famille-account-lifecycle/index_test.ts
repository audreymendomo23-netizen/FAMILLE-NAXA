import {assertEquals,assertThrows} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {isAdult,normalizePhone,safeAppCode} from "./index.ts";
Deno.test("accepts normalized Cameroon E.164 numbers",()=>assertEquals(normalizePhone("+237 681 97 22 37"),"+237681972237"));
Deno.test("rejects non-E.164 phone identifiers",()=>assertThrows(()=>normalizePhone("681972237")));
Deno.test("accepts only the ten explicit app codes",()=>assertEquals(safeAppCode("campus237"),"campus237"));
Deno.test("rejects unknown app codes",()=>assertThrows(()=>safeAppCode("other-app")));
Deno.test("rejects under-age or malformed identity dates",()=>{assertEquals(isAdult("2012-01-01"),false);assertEquals(isAdult("not-a-date"),false);});
Deno.test("accepts an adult identity date",()=>assertEquals(isAdult("1990-05-15"),true));
