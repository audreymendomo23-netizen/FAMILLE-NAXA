import { describe, expect, it } from "vitest";
import { normalizeInventoryItemDraft } from "./inventory";

describe("Web inventory item draft", () => {
  it("normalizes item metadata before a server submission", () => {
    expect(normalizeInventoryItemDraft({ name: " Savon ", sku: " sku-1 ", unit: " pièce ", reorderLevel: 2.5, supplierWhatsApp: "+237 690 00 00 00" })).toEqual({
      name: "Savon", sku: "SKU-1", unit: "pièce", reorderLevel: 2.5, supplierWhatsApp: "237690000000",
    });
  });
  it("rejects negative thresholds and excessive precision", () => {
    expect(() => normalizeInventoryItemDraft({ name: "Savon", unit: "pièce", reorderLevel: -1 })).toThrow();
    expect(() => normalizeInventoryItemDraft({ name: "Savon", unit: "pièce", reorderLevel: 0.0001 })).toThrow();
  });
  it("rejects malformed supplier contacts", () => {
    expect(() => normalizeInventoryItemDraft({ name: "Savon", unit: "pièce", reorderLevel: 0, supplierWhatsApp: "12-34" })).toThrow();
  });
});
