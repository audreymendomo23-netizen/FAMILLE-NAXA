import {isAdult,normalizePhone,safeAppCode} from "./index.ts";
Deno.test("accepts normalized Cameroon E.164 numbers",()=>{if(normalizePhone("+237 681 97 22 37")!=="+237681972237") throw new Error("phone normalization failed");});
Deno.test("rejects non-E.164 phone identifiers",()=>{let threw=false;try{normalizePhone("681972237")}catch{threw=true}if(!threw)throw new Error("invalid phone accepted");});
Deno.test("accepts only the ten explicit app codes",()=>{if(safeAppCode("campus237")!=="campus237")throw new Error("app code rejected");});
Deno.test("rejects unknown app codes",()=>{let threw=false;try{safeAppCode("other-app")}catch{threw=true}if(!threw)throw new Error("unknown app accepted");});
Deno.test("rejects under-age or malformed identity dates",()=>{if(isAdult("2012-01-01")||isAdult("not-a-date"))throw new Error("underage or malformed DOB accepted");});
Deno.test("accepts an adult identity date",()=>{if(!isAdult("1990-05-15"))throw new Error("adult DOB rejected");});
