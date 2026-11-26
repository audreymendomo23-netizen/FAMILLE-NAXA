// Reused from NAXA Services src/erp/inventory.ts; no changes to original module.
export interface InventoryItemDraft {
  name: string;
  sku: string;
  unit: string;
  reorderLevel: number;
  supplierWhatsApp: string;
}

export function normalizeInventoryItemDraft(value: Partial<InventoryItemDraft>): InventoryItemDraft {
  const name = typeof value.name === "string" ? value.name.trim() : "";
  const sku = typeof value.sku === "string" ? value.sku.trim().toUpperCase() : "";
  const unit = typeof value.unit === "string" ? value.unit.trim() : "";
  const reorderLevel = value.reorderLevel;
  const supplierWhatsApp = typeof value.supplierWhatsApp === "string" ? value.supplierWhatsApp.replace(/\D/g, "") : "";
  if (!name || name.length > 160) throw new Error("Le nom de l’article doit contenir entre 1 et 160 caractères.");
  if (sku.length > 80) throw new Error("Le SKU est limité à 80 caractères.");
  if (!unit || unit.length > 40) throw new Error("L’unité doit contenir entre 1 et 40 caractères.");
  if (typeof reorderLevel !== "number" || !Number.isFinite(reorderLevel) || reorderLevel < 0 || reorderLevel > 99999999999.999 || Math.abs(reorderLevel * 1000 - Math.round(reorderLevel * 1000)) > 0.000001) {
    throw new Error("Le seuil doit être positif, fini et limité à trois décimales.");
  }
  if (supplierWhatsApp && !/^\d{9,15}$/.test(supplierWhatsApp)) throw new Error("Le WhatsApp fournisseur doit contenir 9 à 15 chiffres avec indicatif.");
  return { name, sku, unit, reorderLevel, supplierWhatsApp };
}
