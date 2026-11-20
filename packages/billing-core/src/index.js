export function validateMonthlyPrice(v){if(!Number.isSafeInteger(v)||v<0)throw new RangeError("invalid_fcfa_amount");return v}
export function roundDownToHundred(v){if(!Number.isSafeInteger(v)||v<0)throw new RangeError("invalid_fcfa_amount");return Math.floor(v/100)*100}
export function packagePrice(monthly,months){validateMonthlyPrice(monthly);if(months===3)return roundDownToHundred(Math.floor(monthly*27/10));if(months===6)return monthly*5;if(months===12)return monthly*10;throw new RangeError("unsupported_package")}
export function upgradeProrata(oldPrice,newPrice,days){validateMonthlyPrice(oldPrice);validateMonthlyPrice(newPrice);if(!Number.isInteger(days)||days<0||days>30)throw new RangeError("invalid_remaining_days");if(newPrice<=oldPrice||days===0)return 0;return Math.max(100,Math.round((newPrice-oldPrice)*days/30))}
export function giftMonthsAllowed(used,requested){for(const n of [used,requested])if(!Number.isSafeInteger(n)||n<0)throw new RangeError("invalid_gift_months");return Math.max(0,Math.min(requested,3-used))}
export function provisionalAccessUntil(now,alreadyGranted){if(!(now instanceof Date)||Number.isNaN(now.getTime()))throw new TypeError("invalid_date");return alreadyGranted?null:new Date(now.getTime()+86400000)}

/**
 * Effective-dated NAXA FAMILY tariff catalogue.
 * The change is evaluated against the subscription period start / renewal date
 * in Africa/Douala local calendar terms (YYYY-MM-DD, no UTC conversion).
 */
export const MATURITY_EFFECTIVE_DATE = "2027-05-01";
export const MATURITY_TIME_ZONE = "Africa/Douala";

export const NAXA_FAMILY_CATALOG = Object.freeze({
  KIOSKO: Object.freeze({
    unit: "organization",
    launch: Object.freeze({ ACCESS: 2000, PREMIUM: 5000 }),
    mature: Object.freeze({ ACCESS: 2000, PREMIUM: 7500 }),
  }),
  BOOTIK: Object.freeze({
    unit: "organization",
    launch: Object.freeze({ ACCESS: 4000, PREMIUM: 10000 }),
    mature: Object.freeze({ ACCESS: 6000, PREMIUM: 15000 }),
  }),
  ZIPPLE: Object.freeze({
    unit: "organization",
    launch: Object.freeze({ ACCESS: 5000, PREMIUM: 15000 }),
    mature: Object.freeze({ ACCESS: 6000, PREMIUM: 18000 }),
  }),
  NAXA_SERVICES: Object.freeze({
    unit: "organization",
    launch: Object.freeze({ ACCESS: 3000, PREMIUM: 10000 }),
    mature: Object.freeze({ ACCESS: 5000, PREMIUM: 15000 }),
  }),
  COTIZ: Object.freeze({
    unit: "active_member_per_cotisation",
    launch: Object.freeze({ tiers: Object.freeze([
      Object.freeze({ min: 1, max: 30, price: 150 }),
      Object.freeze({ min: 31, max: 100, price: 120 }),
      Object.freeze({ min: 101, max: 300, price: 90 }),
      Object.freeze({ min: 301, max: null, price: 75 }),
    ]) }),
    mature: Object.freeze({ tiers: Object.freeze([
      Object.freeze({ min: 1, max: 30, price: 150 }),
      Object.freeze({ min: 31, max: 100, price: 120 }),
      Object.freeze({ min: 101, max: 300, price: 90 }),
      Object.freeze({ min: 301, max: null, price: 75 }),
    ]) }),
  }),
  LOYABLE: Object.freeze({
    unit: "active_rental_unit_progressive",
    launch: Object.freeze({ tiers: Object.freeze([
      Object.freeze({ min: 1, max: 20, price: 1000 }),
      Object.freeze({ min: 21, max: 80, price: 650 }),
      Object.freeze({ min: 81, max: null, price: 500 }),
    ]) }),
    mature: Object.freeze({ tiers: Object.freeze([
      Object.freeze({ min: 1, max: 20, price: 1000 }),
      Object.freeze({ min: 21, max: 80, price: 650 }),
      Object.freeze({ min: 81, max: null, price: 500 }),
    ]) }),
  }),
  NAXA_HOTEL: Object.freeze({
    unit: "active_room",
    launch: Object.freeze({ pricePerUnit: 2000 }),
    mature: Object.freeze({ pricePerUnit: 2000 }),
  }),
  NAXA_SECURITY: Object.freeze({
    unit: "organization_capacity",
    launch: Object.freeze({ ACCESS: 5000, PREMIUM: 15000 }),
    mature: Object.freeze({ ACCESS: 7500, PREMIUM: 20000 }),
  }),
  GRILLAD: Object.freeze({
    unit: "active_outlet_network_tier",
    launch: Object.freeze({ tiers: Object.freeze([
      Object.freeze({ min: 1, max: 1, plan: "ACCESS", amount: 1500 }),
      Object.freeze({ min: 2, max: 5, plan: "PREMIUM", amount: 3000 }),
      Object.freeze({ min: 6, max: 10, plan: "PRO", amount: 5000 }),
      Object.freeze({ min: 11, max: 25, plan: "PRO", amount: 10000 }),
      Object.freeze({ min: 26, max: 50, plan: "PRO", amount: 15000 }),
      Object.freeze({ min: 51, max: 100, plan: "PRO", amount: 25000 }),
      Object.freeze({ min: 101, max: null, plan: "QUOTE", amount: null }),
    ]) }),
    mature: Object.freeze({ tiers: Object.freeze([
      Object.freeze({ min: 1, max: 1, plan: "ACCESS", amount: 1500 }),
      Object.freeze({ min: 2, max: 5, plan: "PREMIUM", amount: 3000 }),
      Object.freeze({ min: 6, max: 10, plan: "PRO", amount: 5000 }),
      Object.freeze({ min: 11, max: 25, plan: "PRO", amount: 10000 }),
      Object.freeze({ min: 26, max: 50, plan: "PRO", amount: 15000 }),
      Object.freeze({ min: 51, max: 100, plan: "PRO", amount: 25000 }),
      Object.freeze({ min: 101, max: null, plan: "QUOTE", amount: null }),
    ]) }),
  }),
  CAMPUS237: Object.freeze({
    unit: "institution_student_or_parent_pack",
    launch: Object.freeze({
      SCHOOL: Object.freeze([
        Object.freeze({ min: 1, max: 200, monthly: 3000 }),
        Object.freeze({ min: 201, max: 500, monthly: 5000 }),
        Object.freeze({ min: 501, max: 1000, monthly: 10000 }),
        Object.freeze({ min: 1001, max: 1500, monthly: 15000 }),
        Object.freeze({ min: 1501, max: null, monthly: null }),
      ]),
      PARENT_ESSENTIAL: 0,
      PARENT_INDIVIDUAL_PLUS: 500,
      PARENT_FAMILY: 1500,
    }),
    mature: Object.freeze({
      SCHOOL: Object.freeze([
        Object.freeze({ min: 1, max: 200, monthly: 3000 }),
        Object.freeze({ min: 201, max: 500, monthly: 5000 }),
        Object.freeze({ min: 501, max: 1000, monthly: 10000 }),
        Object.freeze({ min: 1001, max: 1500, monthly: 15000 }),
        Object.freeze({ min: 1501, max: null, monthly: null }),
      ]),
      PARENT_ESSENTIAL: 0,
      PARENT_INDIVIDUAL_PLUS: 500,
      PARENT_FAMILY: 1500,
    }),
  }),
});

function validLocalDate(date) {
  if (typeof date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new TypeError("invalid_local_date_expected_YYYY_MM_DD");
  }
  const [year, month, day] = date.split("-").map(Number);
  const value = new Date(Date.UTC(year, month - 1, day));
  if (value.getUTCFullYear() !== year || value.getUTCMonth() !== month - 1 || value.getUTCDate() !== day) {
    throw new RangeError("invalid_local_date");
  }
  return date;
}

export function catalogVersionAt(localPeriodStartDate) {
  const date = validLocalDate(localPeriodStartDate);
  return date >= MATURITY_EFFECTIVE_DATE ? "mature" : "launch";
}

/**
 * Calculate the recurring price for an app from its effective-dated catalogue.
 * Counts must represent billable active units (inactive/draft/archived units excluded).
 * billingPeriod is "monthly" or "annual"; annual = ten monthly payments for 12 months.
 */
export function resolveNaxaFamilySubscriptionPrice({
  appId,
  planCode,
  periodStartDate,
  billingPeriod = "monthly",
  activeMemberCount,
  presidentFree = false,
  capacityExtensionCount = 0,
  activeRentalUnitCount,
  activeRoomCount,
  activeOutletCount,
  activeStudentCount,
}) {
  const id = String(appId ?? "").toUpperCase();
  const catalog = NAXA_FAMILY_CATALOG[id];
  if (!catalog) throw new RangeError("unknown_family_app");
  const version = catalogVersionAt(periodStartDate);
  const schedule = catalog[version];
  if (!["monthly", "annual"].includes(billingPeriod)) throw new RangeError("unsupported_billing_period");
  const annualFactor = billingPeriod === "annual" ? 10 : 1;

  let monthlyAmount = null;
  let effectivePlan = String(planCode ?? "").toUpperCase();
  let quantity = 1;
  let detail = {};

  if (["KIOSKO", "BOOTIK", "ZIPPLE", "NAXA_SERVICES", "NAXA_SECURITY"].includes(id)) {
    const baseMonthlyAmount = schedule[effectivePlan];
    if (baseMonthlyAmount === undefined) throw new RangeError("unknown_plan_for_app");
    if (id === "NAXA_SECURITY") {
      if (!Number.isSafeInteger(capacityExtensionCount) || capacityExtensionCount < 0) {
        throw new RangeError("invalid_capacity_extension_count");
      }
      const perExtensionAmount = baseMonthlyAmount * 0.20;
      const extensionAmount = perExtensionAmount * capacityExtensionCount;
      monthlyAmount = baseMonthlyAmount + extensionAmount;
      detail = { baseMonthlyAmount, extensionCount: capacityExtensionCount, perExtensionAmount, extensionAmount };
    } else {
      monthlyAmount = baseMonthlyAmount;
    }
  } else if (id === "COTIZ") {
    const count = activeMemberCount;
    if (!Number.isSafeInteger(count) || count < 0) throw new RangeError("invalid_active_member_count");
    quantity = count;
    const tier = schedule.tiers.find((x) => count >= x.min && (x.max === null || count <= x.max));
    const unitPrice = count === 0 ? 0 : tier.price;
    const billedCount = Math.max(0, count - (presidentFree && count <= 100 ? 1 : 0));
    monthlyAmount = billedCount * unitPrice;
    detail = { tierMin: tier?.min ?? 0, tierMax: tier?.max ?? null, unitPrice, billedCount, presidentFreeApplied: billedCount !== count };
  } else if (id === "LOYABLE") {
    const count = activeRentalUnitCount;
    if (!Number.isSafeInteger(count) || count < 0) throw new RangeError("invalid_active_rental_unit_count");
    quantity = count;
    let remaining = count;
    monthlyAmount = 0;
    const breakdown = [];
    for (const tier of schedule.tiers) {
      if (remaining <= 0) break;
      const width = tier.max === null ? remaining : Math.min(remaining, tier.max - tier.min + 1);
      monthlyAmount += width * tier.price;
      breakdown.push({ units: width, unitPrice: tier.price, amount: width * tier.price });
      remaining -= width;
    }
    detail = { breakdown };
  } else if (id === "NAXA_HOTEL") {
    const count = activeRoomCount;
    if (!Number.isSafeInteger(count) || count < 0) throw new RangeError("invalid_active_room_count");
    quantity = count;
    monthlyAmount = count * schedule.pricePerUnit;
    detail = { unitPrice: schedule.pricePerUnit };
  } else if (id === "GRILLAD") {
    const count = activeOutletCount;
    if (!Number.isSafeInteger(count) || count < 0) throw new RangeError("invalid_active_outlet_count");
    quantity = count;
    const tier = schedule.tiers.find((x) => count >= x.min && (x.max === null || count <= x.max));
    if (!tier && count === 0) {
      monthlyAmount = 0;
      effectivePlan = "NO_ACTIVE_OUTLET";
    } else if (tier) {
      effectivePlan = tier.plan;
      monthlyAmount = tier.amount;
      detail = { tierMin: tier.min, tierMax: tier.max };
      if (monthlyAmount === null) {
        return {
          appId: id,
          catalogVersion: version,
          effectiveFrom: version === "mature" ? MATURITY_EFFECTIVE_DATE : null,
          planCode: effectivePlan,
          quantity,
          unit: catalog.unit,
          monthlyAmount: null,
          amountDue: null,
          billingPeriod,
          quoteRequired: true,
          detail: { ...detail, quoteRequiredFromOutlets: 101 },
        };
      }
    }
  } else if (id === "CAMPUS237") {
    const pack = effectivePlan;
    if (pack === "SCHOOL") {
      const count = activeStudentCount;
      if (!Number.isSafeInteger(count) || count < 0) throw new RangeError("invalid_active_student_count");
      quantity = count;
      const tier = schedule.SCHOOL.find((x) => count >= x.min && (x.max === null || count <= x.max));
      monthlyAmount = tier ? tier.monthly : 0;
      if (monthlyAmount === null) {
        return { appId: id, catalogVersion: version, effectiveFrom: version === "mature" ? MATURITY_EFFECTIVE_DATE : null, planCode: pack, quantity, unit: catalog.unit, monthlyAmount: null, amountDue: null, billingPeriod, quoteRequired: true, detail: { quoteRequiredFromStudents: 1501 } };
      }
      detail = { tierMin: tier.min, tierMax: tier.max };
    } else {
      monthlyAmount = schedule[pack];
      if (monthlyAmount === undefined) throw new RangeError("unknown_campus_parent_pack");
      quantity = 1;
    }
  }

  if (!Number.isSafeInteger(monthlyAmount) || monthlyAmount < 0) {
    throw new RangeError("quote_or_invalid_catalog_amount");
  }
  return {
    appId: id,
    catalogVersion: version,
    effectiveFrom: version === "mature" ? MATURITY_EFFECTIVE_DATE : null,
    planCode: effectivePlan,
    unit: catalog.unit,
    quantity,
    monthlyAmount,
    billingPeriod,
    amountDue: monthlyAmount * annualFactor,
    annualFactor,
    quoteRequired: false,
    detail,
  };
}

/**
 * Use the price in force when the paid service period starts.
 * This leaves an already-paid period unchanged and applies the mature catalogue
 * automatically only when a new period starts on/after 2027-05-01.
 */
export function resolveRenewalPrice(subscription, renewalLocalDate) {
  if (!subscription || typeof subscription !== "object") throw new TypeError("invalid_subscription");
  const price = resolveNaxaFamilySubscriptionPrice({
    appId: subscription.appId,
    planCode: subscription.planCode,
    periodStartDate: renewalLocalDate,
    billingPeriod: subscription.billingPeriod ?? "monthly",
    activeMemberCount: subscription.activeMemberCount,
    presidentFree: subscription.presidentFree,
    capacityExtensionCount: subscription.capacityExtensionCount ?? 0,
    activeRentalUnitCount: subscription.activeRentalUnitCount,
    activeRoomCount: subscription.activeRoomCount,
    activeOutletCount: subscription.activeOutletCount,
    activeStudentCount: subscription.activeStudentCount,
  });
  return {
    ...price,
    renewalLocalDate: validLocalDate(renewalLocalDate),
    previousPeriodUnchanged: true,
  };
}

/** Convert a server instant to the Cameroon local calendar date. */
export function localCalendarDateInZone(instant, timeZone = MATURITY_TIME_ZONE) {
  const date = instant instanceof Date ? instant : new Date(instant);
  if (Number.isNaN(date.getTime())) throw new TypeError("invalid_renewal_instant");
  if (typeof timeZone !== "string" || !timeZone.trim()) throw new TypeError("invalid_time_zone");
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return values.year + "-" + values.month + "-" + values.day;
}

/** Resolve a renewal using the server instant converted to Africa/Douala date. */
export function resolveRenewalPriceAtInstant(subscription, renewalInstant = new Date()) {
  const localDate = localCalendarDateInZone(renewalInstant, MATURITY_TIME_ZONE);
  return resolveRenewalPrice(subscription, localDate);
}

/**
 * Trial durations in app-specific billing units. The lifecycle service must
 * enforce one trial per billable organization/application.
 */
export function trialDurationForNaxaFamily({ appId, planCode }) {
  const id = String(appId ?? "").toUpperCase();
  if (!NAXA_FAMILY_CATALOG[id]) throw new RangeError("unknown_family_app");
  const plan = String(planCode ?? "").toUpperCase();
  if (id === "CAMPUS237" && plan === "PARENT_ESSENTIAL") {
    return { trialApplicable: false, trialHours: 0, trialDays: 0, reason: "free_essential_parent_access" };
  }
  if (id === "CAMPUS237" && plan === "SCHOOL") {
    return { trialApplicable: true, trialHours: 720, trialDays: 30, reason: "campus_institutional_trial" };
  }
  return { trialApplicable: true, trialHours: 72, trialDays: 3, reason: "standard_family_trial" };
}
