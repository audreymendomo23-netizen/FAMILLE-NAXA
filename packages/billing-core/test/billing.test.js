import test from "node:test";import assert from "node:assert/strict";import {packagePrice,upgradeProrata,giftMonthsAllowed,provisionalAccessUntil} from "../src/index.js";
test("3-month offer discounted 10%, rounded down to 100 FCFA",()=>assert.equal(packagePrice(1150,3),3100));
test("6 and 12 months charge 5 and 10 months",()=>{assert.equal(packagePrice(1000,6),5000);assert.equal(packagePrice(1000,12),10000)});
test("upgrade example 1000 to 3000 with 15 days left",()=>assert.equal(upgradeProrata(1000,3000,15),1000));
test("upgrade minimum is 100 FCFA",()=>assert.equal(upgradeProrata(1000,1001,1),100));
test("gift ceiling is 3 months per year",()=>{assert.equal(giftMonthsAllowed(0,2),2);assert.equal(giftMonthsAllowed(2,2),1);assert.equal(giftMonthsAllowed(3,1),0)});
test("24-hour provisional access can be issued only once",()=>{const d=new Date("2026-11-14T10:00:00Z");assert.equal(provisionalAccessUntil(d,true),null);assert.equal(provisionalAccessUntil(d,false).toISOString(),"2026-11-15T10:00:00.000Z")});
