import test from "node:test";
import assert from "node:assert/strict";
import {
  packagePrice, upgradeProrata, giftMonthsAllowed, provisionalAccessUntil,
  MATURITY_EFFECTIVE_DATE, NAXA_FAMILY_CATALOG, catalogVersionAt,
  resolveNaxaFamilySubscriptionPrice, resolveRenewalPrice,
  localCalendarDateInZone, resolveRenewalPriceAtInstant, trialDurationForNaxaFamily,
  NAXA_FAMILY_MATURITY_SCHEDULE, getNaxaFamilyMaturitySchedule
} from "../src/index.js";

test("3-month offer discounted 10%, rounded down to 100 FCFA",()=>assert.equal(packagePrice(1150,3),3100));
test("6 and 12 months charge 5 and 10 months",()=>{assert.equal(packagePrice(1000,6),5000);assert.equal(packagePrice(1000,12),10000)});
test("upgrade example 1000 to 3000 with 15 days left",()=>assert.equal(upgradeProrata(1000,3000,15),1000));
test("upgrade minimum is 100 FCFA",()=>assert.equal(upgradeProrata(1000,1001,1),100));
test("gift ceiling is 3 months per year",()=>{assert.equal(giftMonthsAllowed(0,2),2);assert.equal(giftMonthsAllowed(2,2),1);assert.equal(giftMonthsAllowed(3,1),0)});
test("24-hour provisional access can be issued only once",()=>{const d=new Date("2026-11-14T10:00:00Z");assert.equal(provisionalAccessUntil(d,true),null);assert.equal(provisionalAccessUntil(d,false).toISOString(),"2026-11-15T10:00:00.000Z")});

test("all ten apps have a launch and maturity catalog and effective date is 1 May 2027", () => {
  assert.equal(MATURITY_EFFECTIVE_DATE, "2027-05-01");
  assert.deepEqual(Object.keys(NAXA_FAMILY_CATALOG).sort(), [
    "BOOTIK","CAMPUS237","COTIZ","GRILLAD","KIOSKO","LOYABLE","NAXA_HOTEL","NAXA_SECURITY","NAXA_SERVICES","ZIPPLE"
  ].sort());
  for (const app of Object.values(NAXA_FAMILY_CATALOG)) {
    assert.ok(app.launch);
    assert.ok(app.mature);
  }
});
test("catalog selection uses Douala local calendar date, with exact boundary", () => {
  assert.equal(catalogVersionAt("2027-04-30"), "launch");
  assert.equal(catalogVersionAt("2027-05-01"), "mature");
  assert.throws(() => catalogVersionAt("2027-02-30"));
});
test("launch and maturity prices for tiered organization apps", () => {
  assert.equal(resolveNaxaFamilySubscriptionPrice({appId:"KIOSKO",planCode:"PREMIUM",periodStartDate:"2027-04-30"}).amountDue,5000);
  assert.equal(resolveNaxaFamilySubscriptionPrice({appId:"KIOSKO",planCode:"PREMIUM",periodStartDate:"2027-05-01"}).amountDue,7500);
  assert.equal(resolveNaxaFamilySubscriptionPrice({appId:"BOOTIK",planCode:"ACCESS",periodStartDate:"2027-05-01"}).amountDue,6000);
  assert.equal(resolveNaxaFamilySubscriptionPrice({appId:"ZIPPLE",planCode:"PREMIUM",periodStartDate:"2027-05-01"}).amountDue,18000);
  assert.equal(resolveNaxaFamilySubscriptionPrice({appId:"NAXA_SERVICES",planCode:"ACCESS",periodStartDate:"2027-05-01"}).amountDue,5000);
  assert.equal(resolveNaxaFamilySubscriptionPrice({appId:"NAXA_SECURITY",planCode:"PREMIUM",periodStartDate:"2027-05-01"}).amountDue,20000);
});
test("annual subscriptions pay 10 monthly amounts for 12 months", () => {
  const x=resolveNaxaFamilySubscriptionPrice({appId:"NAXA_SERVICES",planCode:"PREMIUM",periodStartDate:"2027-05-01",billingPeriod:"annual"});
  assert.equal(x.amountDue,150000);
  assert.equal(x.annualFactor,10);
});
test("COTIZ uses one tier price per active cotisation and waives eligible president", () => {
  const x=resolveNaxaFamilySubscriptionPrice({appId:"COTIZ",planCode:"MEMBER",periodStartDate:"2027-05-01",activeMemberCount:100,presidentFree:true});
  assert.equal(x.detail.unitPrice,120);
  assert.equal(x.detail.billedCount,99);
  assert.equal(x.amountDue,11880);
});
test("LOYABLE applies progressive unit pricing, not retroactive tier pricing", () => {
  const x=resolveNaxaFamilySubscriptionPrice({appId:"LOYABLE",planCode:"PROMOTER",periodStartDate:"2027-05-01",activeRentalUnitCount:100});
  assert.equal(x.amountDue,69000);
  assert.deepEqual(x.detail.breakdown.map(i=>i.amount),[20000,39000,10000]);
});
test("NAXA HOTEL price multiplies active rooms", () => {
  assert.equal(resolveNaxaFamilySubscriptionPrice({appId:"NAXA_HOTEL",planCode:"FULL",periodStartDate:"2027-05-01",activeRoomCount:12}).amountDue,24000);
});
test("GRILLAD network tiers use total active outlet count", () => {
  assert.equal(resolveNaxaFamilySubscriptionPrice({appId:"GRILLAD",planCode:"PRO",periodStartDate:"2027-05-01",activeOutletCount:6}).amountDue,5000);
  assert.equal(resolveNaxaFamilySubscriptionPrice({appId:"GRILLAD",planCode:"PRO",periodStartDate:"2027-05-01",activeOutletCount:26}).amountDue,15000);
  assert.equal(resolveNaxaFamilySubscriptionPrice({appId:"GRILLAD",planCode:"PRO",periodStartDate:"2027-05-01",activeOutletCount:101}).quoteRequired,true);
});
test("CAMPUS237 protects essential parent access and institution thresholds", () => {
  assert.equal(resolveNaxaFamilySubscriptionPrice({appId:"CAMPUS237",planCode:"PARENT_ESSENTIAL",periodStartDate:"2027-05-01"}).amountDue,0);
  assert.equal(resolveNaxaFamilySubscriptionPrice({appId:"CAMPUS237",planCode:"PARENT_FAMILY",periodStartDate:"2027-05-01",billingPeriod:"annual"}).amountDue,15000);
  assert.equal(resolveNaxaFamilySubscriptionPrice({appId:"CAMPUS237",planCode:"SCHOOL",periodStartDate:"2027-05-01",activeStudentCount:500}).amountDue,5000);
  const emptySchool=resolveNaxaFamilySubscriptionPrice({appId:"CAMPUS237",planCode:"SCHOOL",periodStartDate:"2027-05-01",activeStudentCount:0});
  assert.equal(emptySchool.amountDue,0);
  assert.deepEqual(emptySchool.detail,{tierMin:0,tierMax:0});
  assert.equal(resolveNaxaFamilySubscriptionPrice({appId:"CAMPUS237",planCode:"SCHOOL",periodStartDate:"2027-05-01",activeStudentCount:1600}).quoteRequired,true);
});
test("existing paid period is not repriced; new renewal after maturity uses mature price", () => {
  const subscription={appId:"NAXA_SERVICES",planCode:"PREMIUM",billingPeriod:"monthly"};
  const old=resolveRenewalPrice(subscription,"2027-04-30");
  const next=resolveRenewalPrice(subscription,"2027-05-01");
  assert.equal(old.amountDue,10000);
  assert.equal(next.amountDue,15000);
  assert.equal(next.previousPeriodUnchanged,true);
});

test("maturity boundary follows Africa/Douala midnight, not UTC midnight", () => {
  assert.equal(localCalendarDateInZone("2027-04-30T22:59:59.000Z"), "2027-04-30");
  assert.equal(localCalendarDateInZone("2027-04-30T23:00:00.000Z"), "2027-05-01");
  const sub={appId:"NAXA_SERVICES",planCode:"PREMIUM",billingPeriod:"monthly"};
  assert.equal(resolveRenewalPriceAtInstant(sub,"2027-04-30T22:59:59.000Z").amountDue,10000);
  assert.equal(resolveRenewalPriceAtInstant(sub,"2027-04-30T23:00:00.000Z").amountDue,15000);
});

test("NAXA SECURITY applies +20% per capacity extension in launch and maturity catalogs", () => {
  const launch=resolveNaxaFamilySubscriptionPrice({
    appId:"NAXA_SECURITY",planCode:"PREMIUM",periodStartDate:"2027-04-30",capacityExtensionCount:3
  });
  const mature=resolveNaxaFamilySubscriptionPrice({
    appId:"NAXA_SECURITY",planCode:"PREMIUM",periodStartDate:"2027-05-01",capacityExtensionCount:3
  });
  assert.equal(launch.monthlyAmount,24000);
  assert.equal(mature.monthlyAmount,32000);
  assert.equal(mature.detail.extensionAmount,12000);
  assert.throws(() => resolveNaxaFamilySubscriptionPrice({
    appId:"NAXA_SECURITY",planCode:"ACCESS",periodStartDate:"2027-05-01",capacityExtensionCount:-1
  }));
});
test("Campus237 school trial is 30 days, parent essential remains free, other trials are 72 hours", () => {
  assert.equal(trialDurationForNaxaFamily({appId:"CAMPUS237",planCode:"SCHOOL"}).trialHours,720);
  assert.equal(trialDurationForNaxaFamily({appId:"CAMPUS237",planCode:"PARENT_ESSENTIAL"}).trialApplicable,false);
  assert.equal(trialDurationForNaxaFamily({appId:"CAMPUS237",planCode:"PARENT_FAMILY"}).trialHours,72);
  assert.equal(trialDurationForNaxaFamily({appId:"NAXA_SERVICES",planCode:"PREMIUM"}).trialHours,72);
});

test("all ten application subscriptions have an explicit 1 May 2027 maturity schedule", () => {
  const expected = [
    "BOOTIK","CAMPUS237","COTIZ","GRILLAD","KIOSKO","LOYABLE",
    "NAXA_HOTEL","NAXA_SECURITY","NAXA_SERVICES","ZIPPLE"
  ];
  assert.deepEqual(Object.keys(NAXA_FAMILY_MATURITY_SCHEDULE).sort(), expected);
  for (const appId of expected) {
    const schedule = getNaxaFamilyMaturitySchedule(appId);
    assert.equal(schedule.launchCatalog, "launch");
    assert.equal(schedule.matureCatalog, "mature");
    assert.equal(schedule.effectiveDate, "2027-05-01");
    assert.equal(schedule.timeZone, "Africa/Douala");
    assert.equal(schedule.applyWhen, "new_subscription_or_renewal_period_starts_on_or_after");
  }
  assert.throws(() => getNaxaFamilyMaturitySchedule("UNKNOWN"));
});
