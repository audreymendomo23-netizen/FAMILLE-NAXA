import {describe,it,expect} from "vitest";
import {validateBriefing,briefingNarration,briefingDateBounds,briefingDayAllowed,briefingPeriodDays,summarizeBriefingPeriod} from "./daily-briefing";
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

it("requires timezone-bearing ISO generation time",()=>{for(const generated_at of ["2026-11-26","2026-11-26T10:00:00","11/26/2026"])expect(()=>validateBriefing({...valid,generated_at},day)).toThrow("INVALID_BRIEFING");expect(validateBriefing({...valid,generated_at:"2026-11-26T10:00:00.123456+00:00"},day).day).toBe(day);});

it("projects only authorized report fields and discards unexpected private values",()=>{const result=validateBriefing({...valid,private_notes:"not for the client",appointments:{...valid.appointments,customer_names:["private"]},finance:{...valid.finance,raw_ledger:["private"]}},day);expect(result).toEqual(valid);});

it("discloses uncosted sales only inside the authorized finance report",()=>{expect(briefingNarration(validateBriefing(valid,day),"fr")).toContain("Ventes sans coût renseigné: 1");const personal={...valid,scope:"personal",finance:null};expect(briefingNarration(validateBriefing(personal,day),"fr")).not.toContain("Ventes sans coût renseigné");});

it("aggregates only complete scoped daily periods and never turns missing finance into zero",()=>{const dates=briefingPeriodDays(day,2,Date.parse("2026-11-26T10:00:00Z"));expect(dates).toEqual(["2026-11-25",day]);const previous={...valid,day:dates[0]};expect(summarizeBriefingPeriod(dates,[previous,valid])).toMatchObject({appointments:4,completed:2,revenue:10000,financeDays:2,clocks:4});expect(summarizeBriefingPeriod(dates,[{...previous,finance:null},valid]).revenue).toBeNull();expect(()=>summarizeBriefingPeriod(dates,[previous])).toThrow("INCOMPLETE_BRIEFING_PERIOD");expect(()=>summarizeBriefingPeriod(dates,[{...previous,scope:"personal",finance:null},valid])).toThrow("BRIEFING_SCOPE_CHANGED");expect(()=>briefingPeriodDays(day,31)).toThrow("INVALID_BRIEFING_PERIOD");});
