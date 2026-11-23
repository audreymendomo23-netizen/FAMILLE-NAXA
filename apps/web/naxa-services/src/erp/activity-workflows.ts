export type ActivityProfile =
  | "pressing" | "coiffure" | "couture" | "beaute" | "parfumerie"
  | "reparation" | "menuiserie" | "garage" | "nettoyage" | "domicile"
  | "impression" | "photo_evenementiel" | "autre";

export type ManagementRecordType = "work_order" | "repair_order" | "service_order" | "pressing_order" | "retail";

export interface ActivityField {
  key: string;
  label: string;
  required: boolean;
  help?: string;
}

export interface ActivityStage {
  code: string;
  label: string;
  next: readonly string[];
}

export interface ActivityWorkflow {
  profile: ActivityProfile;
  label: string;
  recordType: ManagementRecordType;
  journey: "deposit" | "service" | "production" | "repair" | "retail" | "configurable";
  purpose: string;
  fields: readonly ActivityField[];
  stages: readonly ActivityStage[];
  sharedModules: readonly string[];
  notes: readonly string[];
}

const stage = (code: string, label: string, ...next: string[]): ActivityStage => ({ code, label, next });

export const ACTIVITY_WORKFLOWS: Readonly<Record<ActivityProfile, ActivityWorkflow>> = {
  pressing: {
    profile: "pressing", label: "Pressing & blanchisserie", recordType: "pressing_order", journey: "deposit",
    purpose: "Dépôt textile individualisé, ticket, traitement, contrôle, retrait et suivi des pièces non retirées.",
    fields: [
      { key: "garments", label: "Pièces déposées et quantités", required: true },
      { key: "care", label: "Traitement, textiles et précautions", required: true },
      { key: "stains", label: "Taches, défauts constatés et réserves", required: false },
      { key: "promised_at", label: "Date promise de retrait", required: true },
      { key: "deposit", label: "Acompte demandé (FCFA)", required: false },
    ],
    stages: [
      stage("received", "Reçu", "in_progress"),
      stage("in_progress", "En traitement", "ready"),
      stage("ready", "Prêt", "picked_up"),
      stage("picked_up", "Retiré"),
    ],
    sharedModules: ["customers", "agenda", "cash", "stock", "team", "reports"],
    notes: ["Ticket par dépôt, pièces et anomalies visibles", "Acompte et retrait suivent les règles de caisse et de preuve de paiement", "Conservation et relances doivent être paramétrées par le commerçant"],
  },
  coiffure: {
    profile: "coiffure", label: "Coiffure & salon", recordType: "service_order", journey: "service",
    purpose: "Prestation planifiée par coiffeur et fauteuil, avec style, consignes, consommables et clôture.",
    fields: [
      { key: "style", label: "Style, coupe ou coiffure", required: true },
      { key: "technique", label: "Technique, longueur et consignes client", required: true },
      { key: "provider", label: "Coiffeur / prestataire affecté", required: false },
      { key: "workstation", label: "Fauteuil ou poste", required: false },
      { key: "products", label: "Produits et accessoires consommés", required: false },
    ],
    stages: [
      stage("received", "Accueil", "approved", "cancelled"),
      stage("approved", "Prestation confirmée", "in_progress"),
      stage("in_progress", "Prestation en cours", "quality_check"),
      stage("quality_check", "Vérification finale", "ready"),
      stage("ready", "Prête", "delivered"),
      stage("delivered", "Remise au client", "closed"),
      stage("closed", "Clôturée"),
    ],
    sharedModules: ["customers", "agenda", "services", "workstations", "cash", "stock", "team", "loyalty", "reports"],
    notes: ["Rendez-vous, durée, fauteuil et prestataire sont gérés dans l'agenda partagé", "Commissions calculées uniquement selon une règle de rémunération validée"],
  },
  couture: {
    profile: "couture", label: "Couture & retouche", recordType: "work_order", journey: "production",
    purpose: "Commande textile avec mensurations, tissu, essayage, retouches, contrôle et livraison.",
    fields: [
      { key: "garment", label: "Vêtement, modèle ou retouche", required: true },
      { key: "measurements", label: "Mensurations et consignes de coupe", required: true },
      { key: "fabric", label: "Tissu, fournitures et accessoires", required: false },
      { key: "fitting", label: "Date / note d'essayage", required: false },
      { key: "delivery", label: "Date de livraison souhaitée", required: false },
    ],
    stages: [
      stage("received", "Commande reçue", "diagnostic", "cancelled"),
      stage("diagnostic", "Prise des mesures / étude", "quote_pending", "cancelled"),
      stage("quote_pending", "Devis à établir", "waiting_customer", "approved", "cancelled"),
      stage("waiting_customer", "Accord client attendu", "approved", "cancelled"),
      stage("approved", "Commande validée", "waiting_parts", "in_progress"),
      stage("waiting_parts", "Tissu / fournitures attendus", "in_progress"),
      stage("in_progress", "Confection / retouche", "quality_check"),
      stage("quality_check", "Contrôle / essayage", "fitting", "ready"),
      stage("fitting", "Essayage / ajustement", "in_progress", "ready"),
      stage("ready", "Prête", "delivered"),
      stage("delivered", "Livrée", "closed"),
      stage("closed", "Clôturée"),
    ],
    sharedModules: ["customers", "services", "agenda", "stock", "purchases", "cash", "team", "reports"],
    notes: ["Les mensurations sont limitées au dossier de commande et soumises à des droits adaptés", "L'essayage peut entraîner un retour en retouche avant validation"],
  },
  beaute: {
    profile: "beaute", label: "Beauté & esthétique", recordType: "service_order", journey: "service",
    purpose: "Soin esthétique planifié par cabine et prestataire, avec protocole commercial et produits utilisés.",
    fields: [
      { key: "treatment", label: "Soin, formule ou prestation", required: true },
      { key: "protocol", label: "Protocole et consignes non médicales", required: true },
      { key: "provider", label: "Esthéticienne / prestataire", required: false },
      { key: "room", label: "Cabine ou poste requis", required: false },
      { key: "products", label: "Produits et consommables utilisés", required: false },
    ],
    stages: [
      stage("received", "Accueil", "approved", "cancelled"),
      stage("approved", "Soin confirmé", "in_progress"),
      stage("in_progress", "Soin en cours", "quality_check"),
      stage("quality_check", "Vérification finale", "ready"),
      stage("ready", "Terminé", "delivered"),
      stage("delivered", "Remis au client", "closed"),
      stage("closed", "Clôturé"),
    ],
    sharedModules: ["customers", "agenda", "services", "workstations", "cash", "stock", "team", "loyalty", "reports"],
    notes: ["Ne pas collecter de diagnostic, antécédent ou donnée médicale dans ce dossier métier", "Les consignes de confort restent factuelles et limitées au besoin de prestation"],
  },
  parfumerie: {
    profile: "parfumerie", label: "Parfumerie & commerce spécialisé", recordType: "retail", journey: "retail",
    purpose: "Commerce produit : variantes, références, conditionnements, stock, fournisseurs, commandes spéciales et ventes.",
    fields: [
      { key: "product", label: "Produit, marque ou référence", required: true },
      { key: "format", label: "Contenance, format ou coffret", required: true },
      { key: "family", label: "Famille olfactive / gamme", required: false },
      { key: "batch", label: "Lot / référence fournisseur (si disponible)", required: false },
      { key: "special_order", label: "Commande spéciale ou réservation client", required: false },
    ],
    stages: [
      stage("received", "Demande / réservation reçue", "quote_pending", "cancelled"),
      stage("quote_pending", "Disponibilité / prix à confirmer", "waiting_customer", "approved", "cancelled"),
      stage("waiting_customer", "Confirmation client attendue", "approved", "cancelled"),
      stage("approved", "Réservation confirmée", "waiting_parts", "ready"),
      stage("waiting_parts", "Réapprovisionnement attendu", "in_progress"),
      stage("in_progress", "Réception et préparation de la commande", "quality_check"),
      stage("quality_check", "Disponibilité vérifiée", "ready"),
      stage("ready", "Disponible au retrait", "delivered"),
      stage("delivered", "Remis au client", "closed"),
      stage("closed", "Clôturée"),
    ],
    sharedModules: ["services", "stock", "purchases", "suppliers", "customers", "cash", "loyalty", "reports"],
    notes: ["Le parcours principal reste catalogue produit, stock, approvisionnement et vente comptoir", "Ce dossier ne remplace ni une ligne de stock ni un encaissement confirmé"],
  },
  reparation: {
    profile: "reparation", label: "Réparation & dépannage", recordType: "repair_order", journey: "repair",
    purpose: "Prise en charge d'un équipement, diagnostic, devis, accord, pièces, intervention, test et restitution.",
    fields: [
      { key: "device", label: "Appareil, marque, modèle et numéro de série", required: true },
      { key: "fault", label: "Panne déclarée par le client", required: true },
      { key: "diagnosis", label: "Diagnostic / constat technique", required: false },
      { key: "parts", label: "Pièces et composants nécessaires", required: false },
      { key: "warranty", label: "Garantie / conditions de restitution", required: false },
    ],
    stages: [
      stage("received", "Appareil reçu", "diagnostic", "cancelled"),
      stage("diagnostic", "Diagnostic", "quote_pending", "cancelled"),
      stage("quote_pending", "Devis à établir", "awaiting_approval", "approved", "cancelled"),
      stage("awaiting_approval", "Accord client attendu", "approved", "cancelled"),
      stage("approved", "Réparation autorisée", "waiting_parts", "in_progress"),
      stage("waiting_parts", "Pièces attendues", "in_progress"),
      stage("in_progress", "Réparation en cours", "quality_check"),
      stage("quality_check", "Tests et contrôle", "in_progress", "ready"),
      stage("ready", "Prêt à restituer", "delivered"),
      stage("delivered", "Restitué", "closed"),
      stage("closed", "Clôturé"),
    ],
    sharedModules: ["customers", "services", "stock", "purchases", "cash", "team", "reports"],
    notes: ["État de l'appareil et accessoires déposés à consigner", "La garantie commerciale est définie par l'entreprise, pas par un défaut"],
  },
  menuiserie: {
    profile: "menuiserie", label: "Menuiserie & fabrication", recordType: "work_order", journey: "production",
    purpose: "Ouvrage sur mesure, dimensions, plans, matières, fabrication, finition, installation et réception.",
    fields: [
      { key: "piece", label: "Meuble, ouvrage ou chantier", required: true },
      { key: "dimensions", label: "Dimensions, plan et spécifications", required: true },
      { key: "materials", label: "Bois, panneaux et quincaillerie", required: false },
      { key: "finish", label: "Finition / couleur / traitement", required: false },
      { key: "installation", label: "Lieu et date de pose / livraison", required: false },
    ],
    stages: [
      stage("received", "Demande reçue", "diagnostic", "cancelled"),
      stage("diagnostic", "Étude technique / métrés", "quote_pending", "cancelled"),
      stage("quote_pending", "Devis à établir", "waiting_customer", "approved", "cancelled"),
      stage("waiting_customer", "Accord client attendu", "approved", "cancelled"),
      stage("approved", "Ouvrage validé", "waiting_parts", "fabrication"),
      stage("waiting_parts", "Matières attendues", "fabrication"),
      stage("fabrication", "Fabrication", "quality_check"),
      stage("quality_check", "Contrôle de finition", "fabrication", "installation", "ready"),
      stage("installation", "Pose / installation", "ready"),
      stage("ready", "Prêt", "delivered"),
      stage("delivered", "Réception client", "closed"),
      stage("closed", "Clôturé"),
    ],
    sharedModules: ["customers", "services", "stock", "purchases", "agenda", "team", "cash", "reports"],
    notes: ["Les dimensions et plans sont des données de commande versionnées", "Les besoins de pose se planifient avec les ressources et adresses du client"],
  },
  garage: {
    profile: "garage", label: "Garage & mécanique automobile", recordType: "repair_order", journey: "repair",
    purpose: "Entrée véhicule, kilométrage, panne, diagnostic, devis, pièces, main-d'œuvre, essai et remise.",
    fields: [
      { key: "vehicle", label: "Véhicule, marque, modèle et immatriculation", required: true },
      { key: "odometer", label: "Kilométrage au dépôt", required: false },
      { key: "fault", label: "Panne / intervention demandée", required: true },
      { key: "diagnosis", label: "Diagnostic technique", required: false },
      { key: "parts", label: "Pièces, lubrifiants et consommables", required: false },
      { key: "handover", label: "Essai, contrôle et date de restitution", required: false },
    ],
    stages: [
      stage("received", "Véhicule reçu", "diagnostic", "cancelled"),
      stage("diagnostic", "Diagnostic mécanique", "quote_pending", "cancelled"),
      stage("quote_pending", "Devis à établir", "awaiting_approval", "approved", "cancelled"),
      stage("awaiting_approval", "Accord client attendu", "approved", "cancelled"),
      stage("approved", "Travaux autorisés", "waiting_parts", "in_progress"),
      stage("waiting_parts", "Pièces attendues", "in_progress"),
      stage("in_progress", "Travaux en cours", "quality_check"),
      stage("quality_check", "Essai et contrôle qualité", "in_progress", "ready"),
      stage("ready", "Prêt à restituer", "delivered"),
      stage("delivered", "Véhicule remis", "closed"),
      stage("closed", "Clôturé"),
    ],
    sharedModules: ["customers", "services", "stock", "purchases", "agenda", "team", "cash", "reports"],
    notes: ["Kilométrage et état au dépôt doivent être figés à la réception", "Pièces et main-d'œuvre ne sont jamais assimilées à un encaissement"],
  },
  nettoyage: {
    profile: "nettoyage", label: "Nettoyage & entretien de locaux", recordType: "service_order", journey: "service",
    purpose: "Contrat/site, zones, fréquence, checklist, équipe, matériel, intervention et contrôle qualité.",
    fields: [
      { key: "site", label: "Site client, adresse et zones", required: true },
      { key: "tasks", label: "Tâches, fréquence et niveau de service", required: true },
      { key: "team", label: "Équipe affectée", required: false },
      { key: "equipment", label: "Produits et matériel", required: false },
      { key: "checklist", label: "Checklist / critères de contrôle", required: false },
    ],
    stages: [
      stage("received", "Demande reçue", "quote_pending", "approved", "cancelled"),
      stage("quote_pending", "Devis / contrat à confirmer", "waiting_customer", "approved", "cancelled"),
      stage("waiting_customer", "Accord client attendu", "approved", "cancelled"),
      stage("approved", "Contrat / intervention validé", "planning"),
      stage("planning", "Intervention planifiée", "on_site", "cancelled"),
      stage("on_site", "Équipe sur site", "in_progress"),
      stage("in_progress", "Travaux en cours", "quality_check"),
      stage("quality_check", "Contrôle / checklist", "in_progress", "ready"),
      stage("ready", "Intervention terminée", "delivered"),
      stage("delivered", "Service réceptionné", "closed"),
      stage("closed", "Clôturé"),
    ],
    sharedModules: ["customers", "services", "agenda", "team", "stock", "purchases", "cash", "reports"],
    notes: ["Contrats récurrents, sites multiples et fréquences sont à paramétrer sans inventer de cadence", "Les contrôles qualité et preuves de passage doivent être horodatés"],
  },
  domicile: {
    profile: "domicile", label: "Services à domicile", recordType: "service_order", journey: "service",
    purpose: "Demande d'intervention à une adresse, accès, créneau, technicien, matériel, exécution et acceptation.",
    fields: [
      { key: "address", label: "Adresse, quartier et repère d'intervention", required: true },
      { key: "service", label: "Prestation demandée et consignes d'accès", required: true },
      { key: "provider", label: "Technicien / intervenant affecté", required: false },
      { key: "materials", label: "Matériel et consommables nécessaires", required: false },
      { key: "visit", label: "Créneau / date de visite souhaité", required: false },
    ],
    stages: [
      stage("received", "Demande reçue", "quote_pending", "approved", "cancelled"),
      stage("quote_pending", "Devis à confirmer", "waiting_customer", "approved", "cancelled"),
      stage("waiting_customer", "Accord client attendu", "approved", "cancelled"),
      stage("approved", "Intervention validée", "planning"),
      stage("planning", "Intervention planifiée", "on_site", "cancelled"),
      stage("on_site", "Intervenant arrivé", "in_progress"),
      stage("in_progress", "Intervention en cours", "quality_check"),
      stage("quality_check", "Contrôle / validation client", "in_progress", "ready"),
      stage("ready", "Terminé", "delivered"),
      stage("delivered", "Réception client", "closed"),
      stage("closed", "Clôturé"),
    ],
    sharedModules: ["customers", "services", "agenda", "team", "stock", "cash", "reports"],
    notes: ["Adresse et localisation sont soumises au consentement et au besoin de service", "Les frais de déplacement sont des lignes de devis, pas une hypothèse automatique"],
  },
  impression: {
    profile: "impression", label: "Imprimerie & reprographie", recordType: "work_order", journey: "production",
    purpose: "Commande d'impression, support, format, quantité, épreuve, validation, production, finition et retrait.",
    fields: [
      { key: "format", label: "Format, support et dimensions", required: true },
      { key: "quantity", label: "Quantité commandée", required: true },
      { key: "colors", label: "Couleurs, recto/verso et résolution", required: false },
      { key: "proof", label: "Épreuve et validation client", required: false },
      { key: "finishing", label: "Finition, façonnage et reliure", required: false },
    ],
    stages: [
      stage("received", "Commande reçue", "quote_pending", "proof_ready", "cancelled"),
      stage("quote_pending", "Devis à établir", "waiting_customer", "proof_ready", "cancelled"),
      stage("waiting_customer", "Validation client attendue", "approved", "cancelled"),
      stage("proof_ready", "Épreuve prête", "approved", "production", "cancelled"),
      stage("approved", "Commande validée", "production"),
      stage("production", "Production", "quality_check"),
      stage("quality_check", "Contrôle qualité", "production", "ready"),
      stage("ready", "Prête au retrait", "delivered"),
      stage("delivered", "Remise client", "closed"),
      stage("closed", "Clôturée"),
    ],
    sharedModules: ["customers", "services", "stock", "purchases", "agenda", "cash", "team", "reports"],
    notes: ["Quantité, format et épreuve validée sont figés avant lancement de production", "Fichiers sources soumis à des droits d'accès et à une politique de conservation"],
  },
  photo_evenementiel: {
    profile: "photo_evenementiel", label: "Photographie & événementiel", recordType: "work_order", journey: "production",
    purpose: "Événement, lieu, date, forfait, liste de prises de vue, équipe, captation, post-production et livraison.",
    fields: [
      { key: "event", label: "Événement, organisateur et lieu", required: true },
      { key: "date", label: "Date et horaires de l'événement", required: true },
      { key: "deliverables", label: "Forfait, livrables et quantité", required: true },
      { key: "crew", label: "Équipe / prestataires affectés", required: false },
      { key: "equipment", label: "Matériel et besoins logistiques", required: false },
    ],
    stages: [
      stage("received", "Demande reçue", "quote_pending", "planning", "cancelled"),
      stage("quote_pending", "Devis à établir", "waiting_customer", "approved", "cancelled"),
      stage("waiting_customer", "Accord client attendu", "approved", "cancelled"),
      stage("approved", "Événement confirmé", "planning"),
      stage("planning", "Préparation", "shooting", "cancelled"),
      stage("shooting", "Captation", "post_production"),
      stage("post_production", "Tri / post-production", "quality_check"),
      stage("quality_check", "Contrôle des livrables", "post_production", "ready"),
      stage("ready", "Livrables prêts", "delivered"),
      stage("delivered", "Livraison effectuée", "closed"),
      stage("closed", "Clôturé"),
    ],
    sharedModules: ["customers", "services", "agenda", "team", "stock", "cash", "reports"],
    notes: ["Droits à l'image, autorisations et durée de conservation restent à documenter avant production", "La livraison des fichiers n'est pas assimilée au transfert automatique de propriété intellectuelle"],
  },
  autre: {
    profile: "autre", label: "Autre activité configurable", recordType: "work_order", journey: "configurable",
    purpose: "Parcours paramétrable par l'organisation, sans imposer des étapes ou champs métier non validés.",
    fields: [
      { key: "service", label: "Prestation ou commande", required: true },
      { key: "specifications", label: "Description / spécifications", required: true },
      { key: "resources", label: "Ressources et consommables", required: false },
      { key: "instructions", label: "Consignes complémentaires", required: false },
      { key: "delivery", label: "Échéance souhaitée", required: false },
    ],
    stages: [
      stage("received", "Reçu", "quote_pending", "approved", "cancelled"),
      stage("quote_pending", "Devis à confirmer", "waiting_customer", "approved", "cancelled"),
      stage("waiting_customer", "Accord client attendu", "approved", "cancelled"),
      stage("approved", "Validé", "in_progress"),
      stage("in_progress", "En cours", "quality_check"),
      stage("quality_check", "Contrôle", "ready"),
      stage("ready", "Prêt", "delivered"),
      stage("delivered", "Livré", "closed"),
      stage("closed", "Clôturé"),
    ],
    sharedModules: ["customers", "services", "agenda", "team", "stock", "cash", "reports"],
    notes: ["L'organisation doit configurer et valider ses propres champs et transitions avant usage réel"],
  },
};

export const ACTIVITY_PROFILE_OPTIONS = Object.values(ACTIVITY_WORKFLOWS).map(({ profile, label }) => ({ value: profile, label }));

export function isActivityProfile(value: unknown): value is ActivityProfile {
  return typeof value === "string" && Object.prototype.hasOwnProperty.call(ACTIVITY_WORKFLOWS, value);
}

export function normalizeActivityProfile(value: unknown): ActivityProfile {
  return isActivityProfile(value) ? value : "autre";
}

export function getActivityWorkflow(profile: unknown): ActivityWorkflow {
  return ACTIVITY_WORKFLOWS[normalizeActivityProfile(profile)];
}

export function getActivityStage(profile: unknown, code: string): ActivityStage | undefined {
  return getActivityWorkflow(profile).stages.find((item) => item.code === code);
}

export function canTransitionActivity(profile: unknown, from: string, to: string): boolean {
  return getActivityStage(profile, from)?.next.includes(to) ?? false;
}

export function validateActivityFields(profile: unknown, values: Record<string, unknown>): string[] {
  return getActivityWorkflow(profile).fields
    .filter((field) => field.required && (typeof values[field.key] !== "string" || !(values[field.key] as string).trim()))
    .map((field) => field.key);
}
