import {describe,it,expect} from "vitest";
import {validateBriefing,briefingNarration,briefingDateBounds,briefingDayAllowed} from "./daily-briefing";
const day="2026-11-26";
const valid={day,generated_at:"2026-11-26T10:00:00Z",coverage:"partial_confirmed_server_facts",scope:"site",appointments:{scheduled_count:2,completed_count:1},finance:{revenue_xaf:5000,confirmed_sales_count:2,uncosted_sales_count:1},personal_clock_events:{event_count:2}};
describe("briefing integrity",()=>{
 it("accepts scoped facts, including real zero and explicitly unavailable data",()=>{expect(validateBriefing(valid,day)).toEqual(valid);const personal={...valid,scope:"personal",finance:null,personal_clock_events:null,appointments:{scheduled_count:0,completed_count:0}};expect(validateBriefing(personal,day)).toEqual(personal);expect(briefingNarration(validateBriefing(personal,day),"fr")).not.toContain("Chiffre d’affaires en francs CFA:");});
 it("rejects missing, malformed, untrusted or internally inconsistent indicators",()=>{for(const bad of [null,{}, {...valid,day:"2026-11-25"},{...valid,generated_at:"bad"},{...valid,scope:"personal"},{...valid,finance:undefined},{...valid,appointments:{scheduled_count:1,completed_count:2}},{...valid,appointments:{scheduled_count:"2",completed_count:1}},{...valid,finance:{...valid.finance,revenue_xaf:NaN}},{...valid,finance:{...valid.finance,uncosted_sales_count:3}},{...valid,personal_clock_events:{event_count:-1}}])expect(()=>validateBriefing(bad,day)).toThrow("INVALID_BRIEFING");});
});

describe("historical briefing dates in Douala",()=>{
 it("uses Douala midnight and the same 366-day window as the RPC",()=>{
  const now=Date.parse("2026-11-26T23:30:00Z");
  expect(briefingDateBounds(now)).toEqual({today:"2026-11-27",earliest:"2025-11-26"});
  for(const d of ["2025-11-26","2026-11-26","2026-11-27"])expect(briefingDayAllowed(d,now)).toBe(true);
  for(const d of ["2025-11-25","2026-11-28","2026-02-30","2026-1-1",""])expect(briefingDayAllowed(d,now)).toBe(false);
 });
});
