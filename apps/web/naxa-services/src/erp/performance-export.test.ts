import {describe,it,expect} from "vitest";
import {financialRows,financialXlsx} from "./performance-export";
describe("private financial exports",()=>{
 it("keeps numeric values and distinguishes absent amounts",()=>{
  const r=financialRows({daily:[{performance_day:"2026-11-26",revenue_xaf:0,known_cost_of_goods_xaf:250,confirmed_sales_count:2}],monthly:[],annual:[]},["Day","Month","Year"],["Type","Period","Revenue","Cost","Margin","Sales","Missing"]);
  expect(r[1]).toEqual(["Day","2026-11-26",0,250,null,2,null]);
 });
 it("writes an OOXML ZIP and prevents formula execution",()=>{
  const data=financialXlsx([["A & B","=2+2",3,null]]);
  const view=new DataView(data.buffer);expect(view.getUint32(0,true)).toBe(0x04034b50);expect(view.getUint32(data.length-22,true)).toBe(0x06054b50);
  const all=new TextDecoder().decode(data);expect(all).toContain("xl/worksheets/sheet1.xml");expect(all).toContain("A &amp; B");expect(all).toContain('t="inlineStr"');expect(all).toContain("=2+2");expect(all).not.toContain("<f>");expect(all).toContain('<c r="C1"><v>3</v></c>');expect(all).toContain('<c r="D1"/>');
 });
});
