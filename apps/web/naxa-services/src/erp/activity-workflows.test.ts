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
    expect(validateActivityFields("coiffure", { style: "tresses", technique: "Nattes" })).toEqual([]);
    expect(validateActivityFields("parfumerie", { product: "Eau de parfum" })).toEqual(["format"]);
  });

  it("enforces sector-specific lifecycle transitions rather than one generic path", () => {
    expect(canTransitionActivity("couture", "diagnostic", "quote_pending")).toBe(true);
    expect(canTransitionActivity("impression", "proof_ready", "approved")).toBe(true);
    expect(canTransitionActivity("photo_evenementiel", "shooting", "post_production")).toBe(true);
    expect(canTransitionActivity("nettoyage", "planning", "on_site")).toBe(true);
    expect(canTransitionActivity("garage", "diagnostic", "awaiting_approval")).toBe(true);
    expect(canTransitionActivity("garage", "diagnostic", "quote_pending")).toBe(true);
    expect(canTransitionActivity("coiffure", "in_progress", "post_production")).toBe(false);
  });

  it("keeps every métier lifecycle compatible with the server management-record transition contract", () => {
    const allowed: Array<[string, string, string]> = [
      ["coiffure", "approved", "in_progress"],
      ["beaute", "in_progress", "quality_check"],
      ["couture", "measurement", "quote_pending"],
      ["parfumerie", "approved", "in_progress"],
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


  it("enforces typed controls, choices, numeric bounds, dates and length limits", () => {
    expect(validateActivityFields("garage", {
      vehicle: "Toyota Yaris", fault: "Bruit moteur", odometer: "-4",
    })).toEqual(["odometer"]);
    expect(validateActivityFields("impression", {
      format: "A4", quantity: "0",
    })).toEqual(["quantity"]);
    expect(validateActivityFields("impression", {
      format: "custom-unknown", quantity: "100",
    })).toEqual(["format"]);
    expect(validateActivityFields("photo_evenementiel", {
      event: "Mariage", date: "2026-02-31", deliverables: "Album + 200 photos",
    })).toEqual(["date"]);
    expect(validateActivityFields("coiffure", {
      style: "non-listed-style", technique: "Tresses",
    })).toEqual(["style"]);
    const longProtocol = "x".repeat(1001);
    expect(validateActivityFields("beaute", {
      treatment: "soin_visage", protocol: longProtocol,
    })).toEqual(["protocol"]);
  });

  it("uses distinct métier controls where business risk requires them", () => {
    expect(getActivityWorkflow("coiffure").fields.find((field) => field.key === "style")?.kind).toBe("select");
    expect(getActivityWorkflow("couture").fields.find((field) => field.key === "measurements")?.kind).toBe("textarea");
    expect(getActivityWorkflow("garage").fields.find((field) => field.key === "odometer")?.kind).toBe("number");
    expect(getActivityWorkflow("impression").fields.find((field) => field.key === "quantity")?.min).toBe(1);
    expect(getActivityWorkflow("photo_evenementiel").fields.find((field) => field.key === "date")?.kind).toBe("date");
  });


  it("keeps every activity lifecycle complete, reachable and free of dangling transitions", () => {
    for (const workflow of Object.values(ACTIVITY_WORKFLOWS)) {
      const stageCodes = workflow.stages.map((stage) => stage.code);
      expect(new Set(stageCodes).size, workflow.profile + " duplicate stage").toBe(stageCodes.length);
      for (const stage of workflow.stages) {
        expect(new Set(stage.next).size, workflow.profile + " duplicate next stage in " + stage.code).toBe(stage.next.length);
        for (const next of stage.next) {
          expect(stageCodes, workflow.profile + " dangling transition " + stage.code + " -> " + next).toContain(next);
        }
      }

      const reachable = new Set<string>(["received"]);
      const queue = ["received"];
      while (queue.length) {
        const code = queue.shift()!;
        const stage = workflow.stages.find((item) => item.code === code);
        for (const next of stage?.next ?? []) {
          if (!reachable.has(next)) {
            reachable.add(next);
            queue.push(next);
          }
        }
      }
      expect([...reachable].sort(), workflow.profile + " reachable lifecycle").toEqual([...stageCodes].sort());

      const terminal = workflow.profile === "pressing" ? "picked_up" : "closed";
      const terminalStage = workflow.stages.find((stage) => stage.code === terminal);
      expect(terminalStage, workflow.profile + " terminal stage missing").toBeTruthy();
      expect(terminalStage!.next, workflow.profile + " terminal stage must not transition further").toEqual([]);
      expect(reachable.has(terminal), workflow.profile + " completion must be reachable").toBe(true);

      const fieldKeys = workflow.fields.map((field) => field.key);
      expect(new Set(fieldKeys).size, workflow.profile + " duplicate field key").toBe(fieldKeys.length);
      for (const field of workflow.fields) {
        if (field.kind === "select") {
          const values = (field.options ?? []).map((option) => option.value);
          expect(new Set(values).size, workflow.profile + " duplicate option in " + field.key).toBe(values.length);
        }
      }
      expect(validateActivityFields(workflow.profile, {}), workflow.profile + " required field coverage")
        .toEqual(workflow.fields.filter((field) => field.required).map((field) => field.key));
    }
  });

});
describe("All sector transition pairs and field boundaries",()=>{
 for(const workflow of Object.values(ACTIVITY_WORKFLOWS)){
  it(workflow.profile+" accepts exactly its declared transitions and refuses all other pairs",()=>{
   for(const from of workflow.stages)for(const to of workflow.stages)expect(canTransitionActivity(workflow.profile,from.code,to.code),from.code+" -> "+to.code).toBe(from.next.includes(to.code));
   for(const stage of workflow.stages){expect(canTransitionActivity(workflow.profile,stage.code,"unknown_state")).toBe(false);expect(canTransitionActivity(workflow.profile,"unknown_state",stage.code)).toBe(false);}
  });
  it(workflow.profile+" validates each field at its boundaries",()=>{
   const sample:Record<string,string>={};
   for(const f of workflow.fields){sample[f.key]=f.kind==="select"?f.options![0].value:f.kind==="date"?"2028-02-29":f.kind==="number"?String(f.min??0):"Recette";}
   expect(validateActivityFields(workflow.profile,sample)).toEqual([]);
   for(const f of workflow.fields){
    if(f.required)expect(validateActivityFields(workflow.profile,{...sample,[f.key]:"  "})).toContain(f.key);
    if(f.kind==="select")for(const choice of f.options??[])expect(validateActivityFields(workflow.profile,{...sample,[f.key]:choice.value})).not.toContain(f.key);
    if(f.kind==="select")expect(validateActivityFields(workflow.profile,{...sample,[f.key]:"__unknown__"})).toContain(f.key);
    if(f.kind==="date")for(const v of ["2027-02-29","2026-13-01","not-a-date"])expect(validateActivityFields(workflow.profile,{...sample,[f.key]:v})).toContain(f.key);
    if(f.kind==="number"){
     for(const v of ["1.5","1e2","0x10","NaN","9007199254740992"])expect(validateActivityFields(workflow.profile,{...sample,[f.key]:v})).toContain(f.key);
     if(f.min!==undefined)expect(validateActivityFields(workflow.profile,{...sample,[f.key]:String(f.min-1)})).toContain(f.key);
     if(f.max!==undefined)expect(validateActivityFields(workflow.profile,{...sample,[f.key]:String(f.max+1)})).toContain(f.key);
    }
    if(f.maxLength!==undefined&&f.kind!=="number"&&f.kind!=="date"&&f.kind!=="select")expect(validateActivityFields(workflow.profile,{...sample,[f.key]:"x".repeat(f.maxLength+1)})).toContain(f.key);
   }
  });
 }
});
