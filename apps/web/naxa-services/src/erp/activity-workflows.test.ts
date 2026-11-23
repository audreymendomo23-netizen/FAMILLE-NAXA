import { describe, expect, it } from "vitest";
import {
  ACTIVITY_PROFILE_OPTIONS, ACTIVITY_WORKFLOWS, canTransitionActivity,
  getActivityWorkflow, isActivityProfile, normalizeActivityProfile, validateActivityFields,
} from "./activity-workflows";

describe("NAXA Services sector workflows", () => {
  it("defines each server-supported activity profile exactly once", () => {
    expect(ACTIVITY_PROFILE_OPTIONS.map((item) => item.value)).toEqual([
      "pressing", "coiffure", "couture", "beaute", "parfumerie", "reparation",
      "menuiserie", "garage", "nettoyage", "domicile", "impression",
      "photo_evenementiel", "autre",
    ]);
    expect(Object.keys(ACTIVITY_WORKFLOWS)).toHaveLength(13);
    expect(new Set(ACTIVITY_PROFILE_OPTIONS.map((item) => item.value)).size).toBe(13);
  });

  it("has a sector purpose, specific required fields and a lifecycle for every non-retail profile", () => {
    for (const workflow of Object.values(ACTIVITY_WORKFLOWS)) {
      expect(workflow.purpose.length, workflow.profile).toBeGreaterThan(30);
      expect(workflow.fields.filter((field) => field.required).length, workflow.profile).toBeGreaterThan(0);
      expect(workflow.stages[0]?.code, workflow.profile).toBe("received");
      expect(workflow.stages.length, workflow.profile).toBeGreaterThanOrEqual(4);
      expect(workflow.notes.length, workflow.profile).toBeGreaterThan(0);
    }
  });

  it("keeps retail parfumerie distinct from service and repair work orders", () => {
    expect(getActivityWorkflow("parfumerie").journey).toBe("retail");
    expect(getActivityWorkflow("parfumerie").recordType).toBe("retail");
    expect(getActivityWorkflow("garage").recordType).toBe("repair_order");
    expect(getActivityWorkflow("coiffure").recordType).toBe("service_order");
    expect(getActivityWorkflow("couture").recordType).toBe("work_order");
    expect(getActivityWorkflow("pressing").recordType).toBe("pressing_order");
  });

  it("does not silently treat unknown profiles as pressing", () => {
    expect(isActivityProfile("not-a-sector")).toBe(false);
    expect(normalizeActivityProfile("not-a-sector")).toBe("autre");
    expect(getActivityWorkflow(undefined).profile).toBe("autre");
  });

  it("validates profile-specific required fields", () => {
    expect(validateActivityFields("garage", { vehicle: "Toyota Yaris" })).toEqual(["fault"]);
    expect(validateActivityFields("couture", { garment: "Robe" })).toEqual(["measurements"]);
    expect(validateActivityFields("coiffure", { style: "Tresses", technique: "Nattes" })).toEqual([]);
    expect(validateActivityFields("parfumerie", { product: "Eau de parfum" })).toEqual(["format"]);
  });

  it("enforces sector-specific lifecycle transitions rather than one generic path", () => {
    expect(canTransitionActivity("couture", "diagnostic", "quote_pending")).toBe(true);
    expect(canTransitionActivity("impression", "proof_ready", "approved")).toBe(true);
    expect(canTransitionActivity("photo_evenementiel", "shooting", "post_production")).toBe(true);
    expect(canTransitionActivity("nettoyage", "planning", "on_site")).toBe(true);
    expect(canTransitionActivity("garage", "diagnostic", "awaiting_approval")).toBe(false);
    expect(canTransitionActivity("garage", "diagnostic", "quote_pending")).toBe(true);
    expect(canTransitionActivity("coiffure", "in_progress", "post_production")).toBe(false);
  });

  it("keeps every métier lifecycle compatible with the server management-record transition contract", () => {
    const allowed: Array<[string, string, string]> = [
      ["coiffure", "approved", "in_progress"],
      ["beaute", "in_progress", "quality_check"],
      ["couture", "measurement", "quote_pending"],
      ["parfumerie", "waiting_parts", "in_progress"],
      ["parfumerie", "in_progress", "quality_check"],
      ["reparation", "diagnostic", "quote_pending"],
      ["garage", "diagnostic", "awaiting_approval"],
      ["menuiserie", "fabrication", "quality_check"],
      ["menuiserie", "quality_check", "installation"],
      ["nettoyage", "planning", "on_site"],
      ["domicile", "planning", "on_site"],
      ["impression", "proof_ready", "production"],
      ["photo_evenementiel", "shooting", "post_production"],
      ["autre", "approved", "in_progress"],
    ];
    for (const [profile, from, to] of allowed) {
      expect(canTransitionActivity(profile, from, to), profile + ": " + from + " -> " + to).toBe(true);
    }
    expect(canTransitionActivity("parfumerie", "approved", "ready")).toBe(false);
  });

});