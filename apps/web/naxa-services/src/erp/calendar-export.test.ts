import {expect,it} from "vitest";
import {calendarEvent} from "./calendar-export";
const v={id:"70000000-0000-4000-8000-000000000241",title:"Réunion, privée;\nATTENDEE:evil",start:"2026-11-27T10:00:00+01:00",end:"2026-11-27T11:00:00+01:00",revision:2,status:"CONFIRMED" as const};
it("exports exact UTC interval and prevents property injection",()=>{const s=calendarEvent(v,Date.parse(v.start));expect(s).toContain("DTSTART:20261127T090000Z");expect(s).toContain("DTEND:20261127T100000Z");expect(s).toContain("SEQUENCE:2");expect(s).not.toContain("\r\nATTENDEE:");expect(s).toContain("CLASS:PRIVATE");expect(()=>calendarEvent({...v,end:v.start})).toThrow();});
it("folds long UTF-8 lines and keeps cancellation revision",()=>{const s=calendarEvent({...v,title:"é".repeat(100),status:"CANCELLED"});expect(s).toContain("STATUS:CANCELLED");expect(s.split("\r\n").every(l=>new TextEncoder().encode(l).length<=75)).toBe(true);});
