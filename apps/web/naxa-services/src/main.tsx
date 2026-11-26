import React, { useEffect, useMemo, useRef, useState } from "react";
import { SubscriptionPage } from "./erp/subscription";
import { enqueue as enqueueOfflineEvent, acquireDueBatch, applyServerReceipt, scheduleRetry, listQueued, listAppEvents, applySyncPage, getSyncCursor, listSyncChanges, type WebSyncChange } from "@famille/offline-web";
import { normalizeInventoryItemDraft } from "./erp/inventory";
import { financialRows,downloadFinancialXlsx,printFinancialReport } from "./erp/performance-export";
import {
  AgendaOperationsPage, CashOperationsPage, StockOperationsPage,
  TeamOperationsPage, CustomerFollowupsPage,
} from "./erp/shared-operations";
import {
  canTransitionActivity, getActivityStage, getActivityWorkflow,
  validateActivityFields, type ActivityProfile,
} from "./erp/activity-workflows";
import { parseWebSession, type WebAuthSession } from "./auth/session";
import { ProfilePhoto } from "./auth/profile-photo";
import { StaffRoster, rosterModeEnabled } from "./erp/staff-roster";
import { DailyBriefing } from "./erp/daily-briefing";
import { InternalMeetings } from "./erp/internal-meetings";
import { AttendanceProofPanel, type AttendanceAction } from "./erp/attendance-proof";
import { BusinessBackdrop, NightTorch } from "./business-visuals";
import { localeOf, translate, LocaleContext, useTranslation, type Locale } from "./locale";
import { createRoot } from "react-dom/client";
import "@famille/design-system/tokens.css";
import "./naxa-services.css";

type ModuleId =
  | "overview" | "agenda" | "pressing" | "workOrders" | "cash" | "services" | "customers"
  | "team" | "stock" | "reports" | "organization" | "network" | "sites"
  | "workstations" | "security" | "settings" | "help";

type BusinessMode = "solo" | "single_site_multi_workstation" | "multi_site_network";
const OFFLINE_APP_ID = "naxa-services-web";
type Entry = {
  id: string; title: string; detail: string; state: string; createdAt: string;
  recordType?: "work_order" | "repair_order" | "service_order" | "pressing_order";
  aggregateType?: string; actionCode?: string; data?: Record<string, unknown>;
  status?: string; revision?: number; siteId?: string; activityProfile?: ActivityProfile;
  metadata?: Record<string, string>;
};
function confirmedActivityRevision(entry:Entry):boolean {
  return Number.isSafeInteger(entry.revision)&&(entry.revision??0)>0&&(entry.state==="Confirmé"||entry.state==="Confirmé · autre appareil");
}
type WebDevice = {id:string;installation_id:string;platform:string;label:string|null;last_seen_at:string;revoked_at:string|null;current:boolean};
type WebWorkstation = { id: string; site_id: string; code: string; name: string; kind: string; capacity: number; status: string };

const modules: { id: ModuleId; title: string; description: string; group: string; action: string }[] = [
  { id: "overview", title: "Vue d'ensemble", description: "Activité, alertes et briefings de l'établissement.", group: "Pilotage", action: "Actualiser la vue" },
  { id: "agenda", title: "Agenda & rendez-vous", description: "Créneaux par prestataire, poste, date et point de vente.", group: "Opérations", action: "Nouveau rendez-vous" },
  { id: "pressing", title: "Pressing", description: "Tickets, pièces, étapes de traitement et retraits.", group: "Opérations", action: "Créer un ticket" },
  { id: "workOrders", title: "Dossiers métier", description: "Coiffure, beauté, couture, réparation, production, interventions et commandes spéciales.", group: "Opérations", action: "Créer un dossier métier" },
  { id: "cash", title: "Caisse & ventes", description: "Ventes, paiements, reçus, dépenses et clôtures.", group: "Finance", action: "Nouvelle dépense" },
  { id: "services", title: "Catalogue de prestations", description: "Tarifs, durées, habilitations, forfaits et produits comptoir.", group: "Référentiels", action: "Ajouter une prestation" },
  { id: "customers", title: "Clients & fidélité", description: "Fiches, historique, préférences, points et consentements.", group: "Relation client", action: "Créer une fiche client" },
  { id: "team", title: "Équipe & commissions", description: "Comptes individuels, affectations, présence et commissions.", group: "Ressources", action: "Ajouter un membre" },
  { id: "stock", title: "Consommables", description: "Lessive, produits de coiffure, seuils et mouvements.", group: "Ressources", action: "Ajouter un article" },
  { id: "reports", title: "Rapports & comptabilité", description: "Caisse, activité, commissions, analytique et exports.", group: "Pilotage", action: "Préparer un rapport" },
  { id: "organization", title: "PME & organisation", description: "Profil, mode d'exploitation, contrat et droits fonctionnels.", group: "Organisation", action: "Modifier le profil" },
  { id: "network", title: "Réseau multi-sites", description: "Consolidation du Promoteur, sites et délégations.", group: "Organisation", action: "Ajouter un point de vente" },
  { id: "sites", title: "Points de vente", description: "Autonomie opérationnelle, équipe, caisse et stock par site.", group: "Organisation", action: "Créer un site" },
  { id: "workstations", title: "Emplacements & postes", description: "Fauteuils, ateliers, comptoirs et ressources d'un même site.", group: "Organisation", action: "Ajouter un emplacement" },
  { id: "security", title: "Sécurité & appareils", description: "Accès, sessions, récupération et audit des opérations.", group: "Sécurité", action: "Ouvrir le journal" },
  { id: "settings", title: "Paramètres", description: "Langue, thème, synchronisation et périphériques.", group: "Système", action: "Gérer les paramètres" },
  { id: "help", title: "Assistance & briefings", description: "Aide, demandes support et synthèses du matin et du soir.", group: "Système", action: "Créer une demande" },
];

const moduleCopy: Record<ModuleId, { eyebrow: string; headline: string; helper: string; empty: string; features: string[] }> = {
  overview: { eyebrow: "PILOTAGE", headline: "Votre activité, au même endroit.", helper: "Retrouvez vos chiffres et vos objectifs.", empty: "Aucune opération pour le moment.", features: ["Rendez-vous du jour", "Tickets pressing à rendre", "Situation de caisse", "Briefing du matin / soir"] },
  agenda: { eyebrow: "PLANNING", headline: "Un planning lisible par poste et prestataire.", helper: "Organisez les horaires de vos rendez-vous.", empty: "Aucun rendez-vous dans cette vue.", features: ["Vues jour et semaine", "Disponibilité du prestataire", "Disponibilité du fauteuil / poste", "Acompte, annulation et liste d'attente"] },
  pressing: { eyebrow: "ATELIER", headline: "Chaque dépôt possède son ticket et son historique.", helper: "Les transitions de statut sont chronologiques et contrôlées.", empty: "Aucun ticket pressing pour le moment.", features: ["Pièces et prix par catégorie", "Date promise et acompte", "Reçu → En cours → Prêt → Retiré", "Relance des vêtements non retirés"] },
  workOrders: { eyebrow: "PARCOURS MÉTIERS", headline: "Un dossier adapté au métier de votre organisation.", helper: "Gérez les prestations propres à votre activité.", empty: "Aucun dossier métier à afficher.", features: ["Formulaire spécialisé par activité", "Devis, échéance et ressources", "Suivi des étapes de traitement", "Historique et synchronisation multi-appareils"] },
  cash: { eyebrow: "ENCAISSEMENTS", headline: "Une caisse traçable, par point de vente.", helper: "Suivez vos ventes, paiements et dépenses.", empty: "Aucune vente enregistrée.", features: ["Espèces et Mobile Money confirmé", "Paiement mixte et reçu", "Ouverture et clôture de caisse", "Dépenses, écarts et justificatifs"] },
  services: { eyebrow: "CATALOGUE", headline: "Des prestations adaptées à chaque activité.", helper: "Adaptez vos tarifs à votre établissement.", empty: "Aucune prestation dans votre catalogue pour le moment.", features: ["Pressing et coiffure distincts", "Durée et prix par prestation", "Habilitations par employé et poste", "Forfaits et produits comptoir"] },
  customers: { eyebrow: "RELATION CLIENT", headline: "Connaître l'historique, respecter les préférences.", helper: "Les coordonnées et notes client sont confidentielles.", empty: "Aucune fiche client disponible.", features: ["Historique des prestations", "Préférences et dernières visites", "Consentement de contact", "Fidélité, QR et anniversaires"] },
  team: { eyebrow: "ÉQUIPE", headline: "Des comptes individuels et des droits précis.", helper: "Chaque membre possède son propre accès ; les comptes partagés sont exclus.", empty: "Aucun membre opérationnel chargé.", features: ["Rôles et permissions", "Affectation site / emplacement", "Présence, avances et primes", "Commissions calculées selon une règle datée"] },
  stock: { eyebrow: "CONSOMMABLES", headline: "Un stock léger centré sur l'exploitation.", helper: "Consultez l'historique de vos mouvements de stock.", empty: "Aucun consommable suivi pour le moment.", features: ["Lessive et produits coiffure", "Entrées et consommation", "Pertes et ajustements motivés", "Alertes de seuil"] },
  reports: { eyebrow: "ANALYTIQUE", headline: "Piloter les résultats, pas seulement les ventes.", helper: "Consultez les résultats de vos établissements autorisés.", empty: "Vos rapports apparaîtront dès que des opérations seront disponibles.", features: ["Recettes et dépenses", "Écarts de caisse", "Rentabilité des prestations", "Remplissage agenda et commissions"] },
  organization: { eyebrow: "STRUCTURE", headline: "Organisez les accès à votre établissement.", helper: "Organisez votre établissement ou votre réseau.", empty: "Le profil juridique et commercial n'est pas encore paramétré.", features: ["PME autonome", "Responsable multi-emplacements dans un site", "Promoteur multi-sites autonomes", "Rôles et droits d'accès distincts"] },
  network: { eyebrow: "RÉSEAU", headline: "Consolider sans mélanger les opérations.", helper: "Chaque point de vente garde ses propres caisses, stocks, équipes et tickets.", empty: "Aucun autre établissement.", features: ["Vue consolidée du réseau", "Accès détaillé selon délégation", "Comparaison des sites", "Transferts inter-sites avec validation et audit"] },
  sites: { eyebrow: "POINTS DE VENTE", headline: "Chaque site fonctionne de façon autonome.", helper: "Les opérations d'un point ne sont jamais réaffectées implicitement à un autre.", empty: "Aucun point de vente supplémentaire.", features: ["Responsable et équipe du site", "Caisse et sessions propres", "Stock et consommables propres", "Catalogue et paramètres du point de vente"] },
  workstations: { eyebrow: "EMPLACEMENTS", headline: "Organiser plusieurs postes dans le même lieu.", helper: "Les emplacements sont des unités de planning et de ressources à l'intérieur d'un point de vente.", empty: "Aucun emplacement configuré.", features: ["Fauteuils de coiffure", "Atelier / comptoir pressing", "Planning et capacité", "Affectation des prestataires"] },
  security: { eyebrow: "PROTECTION", headline: "Maîtriser les sessions et les appareils.", helper: "Contactez votre responsable pour récupérer votre accès.", empty: "Aucune opération disponible.", features: ["Sessions et appareils enrôlés", "Révocation à distance", "Demandes de récupération", "Audit des opérations privilégiées"] },
  settings: { eyebrow: "CONFIGURATION", headline: "Un environnement adapté à l'équipe.", helper: "Personnalisez votre espace de travail.", empty: "Personnalisez votre espace.", features: ["Français, English et Fulfulde", "Thème sombre / clair", "Travail sans Internet et mise à jour au retour du réseau", "Imprimantes et notifications"] },
  help: { eyebrow: "ASSISTANCE", headline: "Obtenez de l’aide quand vous en avez besoin.", helper: "Ne communiquez jamais vos codes confidentiels.", empty: "Aucune demande d’assistance pour le moment.", features: ["FAQ et guides", "Demande d'assistance", "Briefing du matin", "Briefing du soir"] },
};

function customerMessage(value:string):string {
  const message=value.trim();
  if(/^(?:[A-Z][A-Z0-9_]{3,})(?:\s*[:|].*)?$/.test(message)||/\b(?:JWT|RLS|RPC|PostgREST|stack trace|service_role|SUPABASE_URL|outbox|idempotence|backend|API key)\b/i.test(message))return "Cette opération est momentanément indisponible. Réessayez ou contactez l’assistance.";
  return message;
}

function App() {
  const [authenticated, setAuthenticated] = useState(false);
  const [locale,setLocale]=useState<Locale>(()=>{try{return localeOf(localStorage.getItem("ns-display-locale"));}catch{return "fr";}});
  const t=(value:string)=>translate(locale,value);
  useEffect(()=>{document.documentElement.lang=locale;try{localStorage.setItem("ns-display-locale",locale);}catch{}},[locale]);
  const [authSession, setAuthSession] = useState<WebAuthSession | null>(null);
  // A generation belongs to a login, not just an organization or a device.
  // Late responses may persist in their own tenant partition but must never repaint a new login.
  const sessionFence = useRef<{generation:number; scope:string}>({generation:0,scope:""});
  function scopeOf(session:WebAuthSession) {
    return [session.account.organization_id,session.account.member_id,session.deviceId].join(":");
  }
  function captureSession(session:WebAuthSession) {
    const {generation,scope}=sessionFence.current;
    if(!scope || scope!==scopeOf(session)) throw new Error("WEB_SESSION_CHANGED");
    return () => sessionFence.current.generation===generation && sessionFence.current.scope===scope;
  }
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [installationId] = useState(() => {
    try {
      const existing = localStorage.getItem("naxa-services-installation-id");
      if (existing) return existing;
      const generated = crypto.randomUUID();
      localStorage.setItem("naxa-services-installation-id", generated);
      return generated;
    } catch {
      return crypto.randomUUID();
    }
  });
  const [preview, setPreview] = useState(false);
  const [active, setActive] = useState<ModuleId>("overview");
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [showRecovery, setShowRecovery] = useState(false);
  const [recoveryNote, setRecoveryNote] = useState("");
  const [authMessage, setAuthMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const [mode, setMode] = useState<BusinessMode>("solo");
  const [theme, setTheme] = useState<"dark" | "light">(()=>{try{return localStorage.getItem("ns-display-theme")==="light"?"light":"dark";}catch{return "dark";}});
  const [nightPulse,setNightPulse]=useState(false);
  const [mobileMenu,setMobileMenu]=useState(false);
  const previousTheme=useRef(theme);
  useEffect(()=>{
    try{localStorage.setItem("ns-display-theme",theme);}catch{}
    const changed=previousTheme.current!==theme;previousTheme.current=theme;
    if(theme==="dark"&&changed&&!window.matchMedia("(prefers-reduced-motion: reduce)").matches){
      setNightPulse(true);const timer=window.setTimeout(()=>setNightPulse(false),1700);return()=>window.clearTimeout(timer);
    }
    setNightPulse(false);
  },[theme]);
  useEffect(()=>{setMobileMenu(false);},[active,authenticated,preview]);
  useEffect(()=>{if(!mobileMenu)return;const close=(e:KeyboardEvent)=>{if(e.key==="Escape")setMobileMenu(false);};window.addEventListener("keydown",close);return()=>window.removeEventListener("keydown",close);},[mobileMenu]);
  const toggleTheme=()=>setTheme(value=>value==="dark"?"light":"dark");
  const [siteName, setSiteName] = useState("Point de vente principal");
  const [entries, setEntries] = useState<Record<ModuleId, Entry[]>>({} as Record<ModuleId, Entry[]>);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [draftTitle, setDraftTitle] = useState("");
  const [draftDetail, setDraftDetail] = useState("");
  const [draftSku, setDraftSku] = useState("");
  const [draftUnit, setDraftUnit] = useState("pièce");
  const [draftReorderLevel, setDraftReorderLevel] = useState("0");
  const [draftSupplierWhatsApp, setDraftSupplierWhatsApp] = useState("");
  const [draftPhone, setDraftPhone] = useState("");
  const [draftAmount, setDraftAmount] = useState("0");
  const [draftDate, setDraftDate] = useState("");
  const [draftEndDate, setDraftEndDate] = useState("");
  const [draftActivity, setDraftActivity] = useState("general");
  const [draftPriority, setDraftPriority] = useState("normal");
  const [draftContactConsent, setDraftContactConsent] = useState(false);
  const [activeSiteId, setActiveSiteId] = useState("");
  const [pendingSyncCount, setPendingSyncCount] = useState(0);
  const [remoteChanges, setRemoteChanges] = useState<WebSyncChange[]>([]);
  const [search, setSearch] = useState("");
  const [workstations, setWorkstations] = useState<WebWorkstation[]>([]);
  const [workstationSiteId, setWorkstationSiteId] = useState("");
  const [performanceData, setPerformanceData] = useState<{daily: Record<string,unknown>[];monthly:Record<string,unknown>[];annual:Record<string,unknown>[]} | null>(null);
  const [attendanceRequest,setAttendanceRequest]=useState<{scope:string;site:string;action:AttendanceAction}|null>(null);
  const [performanceFromDate, setPerformanceFromDate] = useState(new Intl.DateTimeFormat("en-CA",{timeZone:"Africa/Douala",year:"numeric",month:"2-digit",day:"2-digit"}).format(new Date()));
  const performanceRequest=useRef(0);
  function changePerformanceDate(value:string){performanceRequest.current++;setPerformanceData(null);setPerformanceError("");setPerformanceBusy(false);setPerformanceFromDate(value);}
  const [performanceBusy, setPerformanceBusy] = useState(false);
  const [performanceError, setPerformanceError] = useState("");

  const selected = modules.find((m) => m.id === active)!;
  const grouped = useMemo(() => {
    const groups = new Map<string, typeof modules>();
    modules.forEach((m) => groups.set(m.group, [...(groups.get(m.group) ?? []), m]));
    return Array.from(groups.entries());
  }, []);

  const env = (import.meta as unknown as {
    env?: {
      PROD?: boolean;
      VITE_NAXA_SERVICES_AUTH_URL?: string;
      VITE_NAXA_SERVICES_ACCOUNTING_URL?: string;
      VITE_SUPABASE_ANON_KEY?: string;
      VITE_NAXA_SERVICES_ROSTER_ENABLED?: string;
      VITE_NAXA_SERVICES_BRIEFING_ENABLED?: string;
      VITE_NAXA_SERVICES_MEETINGS_ENABLED?: string;
      VITE_NAXA_SERVICES_ATTENDANCE_ENABLED?: string;
    };
  }).env ?? {};
  const authEndpoint = env.VITE_NAXA_SERVICES_AUTH_URL ?? "";
  const accountingEndpoint = env.VITE_NAXA_SERVICES_ACCOUNTING_URL ?? authEndpoint.replace(/naxa-services-auth(?=\/?$)/, "naxa-services-accounting");
  const anonKey = env.VITE_SUPABASE_ANON_KEY ?? "";

  useEffect(() => {
    if (!env.PROD || !("serviceWorker" in navigator)) return;
    void navigator.serviceWorker.register("/sw.js", { scope: "/" }).catch(() => undefined);
  }, []);

  function webDevicePayload() {
    return {
      installation_id: installationId,
      platform: "web",
      label: navigator.userAgent.slice(0, 90),
    };
  }

  async function authRequest(body: Record<string, unknown>, bearer?: string) {
    if (!authEndpoint || !anonKey) throw new Error("Le service d'authentification web n'est pas configuré.");
    const response = await fetch(authEndpoint, {
      method: "POST",
      credentials: "omit",
      headers: {
        "Content-Type": "application/json",
        apikey: anonKey,
        Authorization: "Bearer " + (bearer ?? authSession?.accessToken ?? anonKey),
      },
      body: JSON.stringify({ app_code: "naxa-services", ...body }),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data.message ?? "Service indisponible. Réessaie plus tard.");
    return data;
  }

  async function changeLocale(value:Locale) {
    if(!authSession){setLocale(value);return;}
    const current=captureSession(authSession);
    try {
      const fresh=await ensureFreshSession(authSession);
      const result=await authRequest({action:"set_member_locale",locale:value},fresh.accessToken);
      if(!current())return;
      if(result.saved!==true||result.locale!==value)throw new Error("LOCALE_NOT_SAVED");
      setAuthSession(previous=>previous&&scopeOf(previous)===scopeOf(fresh)?{...previous,account:{...previous.account,default_locale:value}}:previous);
      setLocale(value);setAuthMessage("Langue enregistrée.");
    } catch {if(current())setAuthMessage("Impossible de modifier la langue.");}
  }
  const languagePicker=<label className="language-picker" aria-label={t("Langue")}><span>{t("Langue")}</span><select aria-label={t("Langue")} value={locale} onChange={e=>void changeLocale(localeOf(e.target.value))} disabled={busy}><option value="fr">Français</option><option value="en">English</option><option value="ff-CM">Fulfulde</option></select></label>;
  async function requestSubscription(payload:Record<string,unknown>) {
    if(!authSession)throw new Error("Connexion requise.");
    const current=captureSession(authSession);
    const fresh=await ensureFreshSession(authSession);
    if(!current())throw new Error("Session expirée.");
    const result=await authRequest(payload,fresh.accessToken);
    if(!current())throw new Error("Session expirée.");
    return payload.action === "subscription_access" ? result.subscription_access : result.subscription_result;
  }
  async function hydrateWebRecords(activeSession: WebAuthSession) {
    const isCurrent=captureSession(activeSession);
    const [allEvents,pending]=await Promise.all([listAppEvents(OFFLINE_APP_ID,activeSession.deviceId,activeSession.account.organization_id),listQueued(OFFLINE_APP_ID,activeSession.deviceId,activeSession.account.organization_id)]);
    if(!isCurrent())return;
    setPendingSyncCount(pending.length);
    setEntries(previous=>{
      if(!isCurrent())return previous;
      const next={...previous};
      for(const item of allEvents){
        let command:Record<string,unknown>={};
        try{command=JSON.parse(item.payload) as Record<string,unknown>;}catch{continue;}
        const moduleId=typeof command.module_id==="string"?command.module_id as ModuleId:"stock";
        if(!modules.some(module=>module.id===moduleId))continue;
        const id=typeof command.aggregate_id==="string"?command.aggregate_id:item.eventId;
        const storedPayload=command.payload && typeof command.payload==="object" && !Array.isArray(command.payload)?command.payload as Record<string,unknown>:{};
        const title=moduleId==="workOrders"&&typeof storedPayload.title==="string"&&storedPayload.title.trim()?storedPayload.title.trim():typeof command.display_title==="string"?command.display_title:id;
        const detail=typeof command.display_detail==="string"?command.display_detail:"";
        const state=item.state==="acknowledged"?"Confirmé":item.state==="rejected"?"Rejeté — vérifier le dossier":item.state==="conflict"?"Conflit — résolution nécessaire":"En attente de confirmation";
        const rows=next[moduleId]??[],existing=rows.findIndex(entry=>entry.id===id);
        const existingEntry=existing>=0?rows[existing]:undefined;
        const payload = command.payload && typeof command.payload === "object" ? command.payload as Record<string,unknown> : {};
        const metadata = payload.metadata_json && typeof payload.metadata_json === "object" && !Array.isArray(payload.metadata_json)
          ? payload.metadata_json as Record<string,unknown> : {};
        const rawFields = metadata.fields && typeof metadata.fields === "object" && !Array.isArray(metadata.fields)
          ? metadata.fields as Record<string,unknown> : {};
        const extraFields = Object.fromEntries(Object.entries(rawFields).filter((entry): entry is [string,string] => typeof entry[1] === "string"));
        const rawProfile = metadata.activity ?? metadata.activity_profile;
        const storedReceipt = item.serverReceipt && typeof item.serverReceipt === "object" && !Array.isArray(item.serverReceipt)
          ? item.serverReceipt as Record<string,unknown> : {};
        const receiptResult = storedReceipt.result && typeof storedReceipt.result === "object" && !Array.isArray(storedReceipt.result)
          ? storedReceipt.result as Record<string,unknown> : {};
        const serverRecord = Object.keys(receiptResult).length ? receiptResult
          : payload.server_result && typeof payload.server_result === "object" && !Array.isArray(payload.server_result)
            ? payload.server_result as Record<string,unknown> : {};
        const incomingRevision = typeof serverRecord.revision === "number" && Number.isSafeInteger(serverRecord.revision)
          ? serverRecord.revision : null;
        const existingRevision = typeof existingEntry?.revision === "number" ? existingEntry.revision : 0;
        if (incomingRevision !== null && incomingRevision < existingRevision) continue;
        const receiptIsNewer = incomingRevision !== null && incomingRevision >= existingRevision;
        const record:Entry={
          ...existingEntry,
          id,title,detail,state,createdAt:new Date(item.createdAt).toLocaleString("fr-FR"),
          recordType: command.aggregate_type === "work_order" || command.aggregate_type === "repair_order" || command.aggregate_type === "service_order" || command.aggregate_type === "pressing_order"
            ? command.aggregate_type : existingEntry?.recordType,
          aggregateType: typeof command.aggregate_type === "string" ? command.aggregate_type : existingEntry?.aggregateType,
          actionCode: typeof command.action_code === "string" ? command.action_code : existingEntry?.actionCode,
          data: { ...(existingEntry?.data ?? {}), ...payload, server_result: serverRecord, server_recorded_at: typeof storedReceipt.recorded_at === "string" ? storedReceipt.recorded_at : typeof payload.server_recorded_at === "string" ? payload.server_recorded_at : undefined },
          status: receiptIsNewer && typeof serverRecord.status === "string" ? serverRecord.status
            : item.state!=="acknowledged"&&existingRevision>0 ? existingEntry?.status
            : typeof payload.to_status === "string" ? payload.to_status
            : typeof payload.status === "string" ? payload.status
            : existingEntry?.status,
          revision: receiptIsNewer ? incomingRevision! : existingEntry?.revision,
          siteId: typeof command.site_id === "string" ? command.site_id : existingEntry?.siteId,
          activityProfile: typeof rawProfile === "string" ? getActivityWorkflow(rawProfile).profile
            : command.aggregate_type === "pressing_order" ? "pressing" : existingEntry?.activityProfile,
          metadata: Object.keys(extraFields).length ? extraFields : existingEntry?.metadata,
        };
        next[moduleId]=existing>=0?rows.map((entry,index)=>index===existing?record:entry):[...rows,record];
      }
      return next;
    });
  }

  useEffect(() => {
    if (!authSession) return;
    const handleOnline = () => {
      void syncWebOutbox(authSession).catch((error) => setAuthMessage(error instanceof Error ? error.message : "Reprise réseau impossible."));
    };
    window.addEventListener("online", handleOnline);
    return () => window.removeEventListener("online", handleOnline);
  }, [authSession]);

  async function loadPerformanceReport() {
    if (!authSession) throw new Error("AUTHENTICATION_REQUIRED");
    if (!accountingEndpoint || !anonKey) throw new Error("Service comptable indisponible.");
    const siteIds = authSession.account.active_site_ids;
    if (!siteIds.length) throw new Error("Aucun site de lecture n'est autorisé pour cette session.");
    const parsedDate=new Date(performanceFromDate+"T00:00:00Z");
    if (!/^\d{4}-\d{2}-\d{2}$/.test(performanceFromDate) || performanceFromDate.startsWith("0000-") || !Number.isFinite(parsedDate.getTime()) || parsedDate.toISOString().slice(0,10)!==performanceFromDate) {
      setPerformanceError("Date de début invalide.");return;
    }
    const sessionCurrent=captureSession(authSession), requestId=++performanceRequest.current;
    const isCurrent=()=>sessionCurrent()&&performanceRequest.current===requestId;
    setPerformanceBusy(true);
    setPerformanceData(null);
    setPerformanceError("");
    try {
      const fresh = await ensureFreshSession(authSession);
      const response = await fetch(accountingEndpoint, {
        method: "POST", credentials: "omit",
        headers: { "Content-Type": "application/json", apikey: anonKey, Authorization: "Bearer " + fresh.accessToken },
        body: JSON.stringify({
          action: "performance",
          org_id: fresh.account.organization_id,
          site_ids: siteIds,
          from_date: performanceFromDate,
        }),
      });
      const data = await response.json().catch(() => ({})) as Record<string, unknown>;
      if (!response.ok || data.ok !== true || !data.result || typeof data.result !== "object") {
        throw new Error(typeof data.error === "string" ? data.error : "Rapport indisponible ou accès refusé.");
      }
      const result = data.result as Record<string, unknown>;
      const daily = Array.isArray(result.daily) ? result.daily as Record<string,unknown>[] : [];
      const monthly = Array.isArray(result.monthly) ? result.monthly as Record<string,unknown>[] : [];
      const annual = Array.isArray(result.annual) ? result.annual as Record<string,unknown>[] : [];
      if(!isCurrent())return;
      setPerformanceData({ daily, monthly, annual });
      setAuthMessage("Rapport actualisé pour vos établissements.");
    } catch(error){
      if(isCurrent())setPerformanceError(error instanceof Error?error.message:"Chargement du rapport impossible.");
    } finally {
      if(isCurrent())setPerformanceBusy(false);
    }
  }

  async function signIn(event: React.FormEvent) {
    event.preventDefault();
    setBusy(true);
    setAuthMessage("");
    try {
      const data = await authRequest({
        action: "login",
        identifier: identifier.trim().toUpperCase(),
        password,
        remember_device: false,
        device: webDevicePayload(),
      }, anonKey);
      const nextSession = parseWebSession(data);
      sessionFence.current={generation:sessionFence.current.generation+1,scope:scopeOf(nextSession)};
      setAuthSession(nextSession);
      setLocale(localeOf(nextSession.account.default_locale));
      setActiveSiteId(nextSession.account.active_site_ids[0] ?? "");
      setMode(nextSession.account.business_mode ?? "solo");
      setSiteName(nextSession.account.organization_name || nextSession.account.active_sites[0]?.name || "Point de vente principal");
      setWorkstationSiteId(nextSession.account.active_site_ids[0] ?? "");
      void hydrateWebRecords(nextSession).catch((error)=>setAuthMessage(error instanceof Error?error.message:"Historique local indisponible."));
      setAuthenticated(true);
      void syncWebPullChanges(nextSession).then((result) => { if(result.morePending)setAuthMessage("Certaines données restent à actualiser."); }).catch((error) => setAuthMessage(error instanceof Error?error.message:"Actualisation impossible."));
      setPreview(false);
      setPassword("");
      setAuthMessage(nextSession.requirePasswordChange
        ? "Connexion réussie. Le mot de passe initial doit être remplacé avant les opérations."
        : "Bienvenue dans votre espace.");
    } catch (error) {
      setAuthSession(null);
      setAuthenticated(false);
      setAuthMessage(error instanceof Error ? error.message : "Connexion impossible.");
    } finally {
      setBusy(false);
    }
  }

  async function requestRecovery(event: React.FormEvent) {
    event.preventDefault();
    setBusy(true);
    setAuthMessage("");
    try {
      await authRequest({ action: "request_recovery", identifier: identifier.trim().toUpperCase(), request_note: recoveryNote, device: webDevicePayload() }, anonKey);
      setAuthMessage("Demande transmise si le compte est identifiable. Le responsable effectuera le contrôle d'identité.");
    } catch (error) {
      setAuthMessage(error instanceof Error ? error.message : "Demande impossible.");
    } finally {
      setBusy(false);
    }
  }

  async function refreshWebSession(activeSession: WebAuthSession): Promise<WebAuthSession> {
    const isCurrent=captureSession(activeSession);
    const data = await authRequest({
      action: "refresh",
      refresh_token: activeSession.refreshToken,
      remember_device: false,
      device: webDevicePayload(),
    }, anonKey);
    const refreshed = parseWebSession(data);
    if(!isCurrent() || scopeOf(refreshed)!==scopeOf(activeSession))throw new Error("WEB_SESSION_CHANGED");
    setAuthSession(refreshed);
    return refreshed;
  }

  async function ensureFreshSession(activeSession: WebAuthSession): Promise<WebAuthSession> {
    captureSession(activeSession);
    if (activeSession.expiresAt > Date.now() + 60_000) return activeSession;
    return await refreshWebSession(activeSession);
  }

  async function saveWebOrganizationProfile(displayName: string, businessMode: BusinessMode, locale: "fr" | "en" | "ff-CM") {
    if (!authSession) throw new Error("AUTHENTICATION_REQUIRED");
    const isCurrent=captureSession(authSession);
    const fresh = await ensureFreshSession(authSession);
    const data = await authRequest({
      action: "update_organization_profile",
      display_name: displayName,
      business_mode: businessMode,
      default_locale: locale,
    }, fresh.accessToken);
    if(!isCurrent())throw new Error("WEB_SESSION_CHANGED");
    if (data.saved !== true) throw new Error("ORGANIZATION_PROFILE_NOT_SAVED");
    const account = { ...fresh.account, organization_name: displayName, business_mode: businessMode, default_locale: locale };
    const updated = { ...fresh, account };
    setAuthSession(updated);
    setMode(businessMode);
    setSiteName(displayName);
    setAuthMessage("Profil enregistré.");
  }

  async function createWebSite(input: { code: string; name: string; address_label: string; phone_contact: string }) {
    if (!authSession) throw new Error("AUTHENTICATION_REQUIRED");
    const isCurrent=captureSession(authSession);
    const fresh = await ensureFreshSession(authSession);
    const data = await authRequest({ action: "create_site", ...input }, fresh.accessToken);
    if(!isCurrent())throw new Error("WEB_SESSION_CHANGED");
    const site = data.site as { id?: string; code?: string; name?: string; address_label?: string; phone_contact?: string } | undefined;
    if (data.saved !== true || !site || typeof site.id !== "string") throw new Error("SITE_CREATE_NOT_CONFIRMED");
    const activeSite = {
      id: site.id, code: site.code ?? input.code, name: site.name ?? input.name,
      address_label: site.address_label ?? input.address_label, phone_contact: site.phone_contact ?? input.phone_contact,
    };
    setAuthSession(previous => previous ? {
      ...previous,
      account: {
        ...previous.account,
        active_site_ids: previous.account.active_site_ids.includes(activeSite.id)
          ? previous.account.active_site_ids : [...previous.account.active_site_ids, activeSite.id],
        active_sites: [...previous.account.active_sites.filter(item => item.id !== activeSite.id), activeSite],
      },
    } : previous);
    setActiveSiteId(activeSite.id);
    setAuthMessage("Point de vente créé par Auth : " + activeSite.name);
    return activeSite;
  }

  async function loadWebWorkstations(siteId: string) {
    if (!authSession) throw new Error("AUTHENTICATION_REQUIRED");
    const isCurrent=captureSession(authSession);
    if (!authSession.account.active_site_ids.includes(siteId)) throw new Error("SITE_SCOPE_FORBIDDEN");
    const fresh = await ensureFreshSession(authSession);
    const data = await authRequest({ action: "list_workstations", site_id: siteId }, fresh.accessToken);
    if(!isCurrent())throw new Error("WEB_SESSION_CHANGED");
    if (!Array.isArray(data.workstations)) throw new Error("WORKSTATION_LIST_INVALID");
    setWorkstations(data.workstations as WebWorkstation[]);
    setWorkstationSiteId(siteId);
    return data.workstations as WebWorkstation[];
  }

  async function createWebWorkstation(input: { site_id: string; code: string; name: string; kind: string; capacity: number }) {
    if (!authSession) throw new Error("AUTHENTICATION_REQUIRED");
    const isCurrent=captureSession(authSession);
    if (!authSession.account.active_site_ids.includes(input.site_id)) throw new Error("SITE_SCOPE_FORBIDDEN");
    const fresh = await ensureFreshSession(authSession);
    const data = await authRequest({ action: "create_workstation", ...input }, fresh.accessToken);
    if(!isCurrent())throw new Error("WEB_SESSION_CHANGED");
    const workstation = data.workstation as WebWorkstation | undefined;
    if (data.saved !== true || !workstation || typeof workstation.id !== "string") throw new Error("WORKSTATION_CREATE_NOT_CONFIRMED");
    setWorkstations(previous => [...previous.filter(item => item.id !== workstation.id), workstation]);
    setWorkstationSiteId(input.site_id);
    setAuthMessage("Emplacement créé par Auth : " + workstation.name);
    return workstation;
  }

  async function loadOwnDevices():Promise<WebDevice[]> {
    if(!authSession)throw new Error("AUTHENTICATION_REQUIRED");
    const isCurrent=captureSession(authSession);
    const fresh=await ensureFreshSession(authSession);
    const data=await authRequest({action:"list_own_devices"},fresh.accessToken);
    if(!isCurrent())throw new Error("WEB_SESSION_CHANGED");
    if(!Array.isArray(data.devices))throw new Error("DEVICE_LIST_INVALID");
    return data.devices as WebDevice[];
  }
  async function revokeOwnDevice(device:WebDevice) {
    if(!authSession||device.current||device.revoked_at)throw new Error("Utilise la déconnexion pour fermer cet appareil.");
    const isCurrent=captureSession(authSession);
    const fresh=await ensureFreshSession(authSession);
    const data=await authRequest({action:"revoke_device",installation_id:device.installation_id},fresh.accessToken);
    if(!isCurrent())throw new Error("WEB_SESSION_CHANGED");
    if(data.revoked!==true)throw new Error("DEVICE_REVOCATION_NOT_CONFIRMED");
  }
  async function changeWebPassword(event: React.FormEvent) {
    event.preventDefault();
    const activeSession = authSession;
    if (!activeSession) return;
    if (newPassword.length < 10 || newPassword.length > 256) {
      setAuthMessage("Le nouveau mot de passe doit contenir entre 10 et 256 caractères.");
      return;
    }
    if (newPassword !== confirmPassword) {
      setAuthMessage("La confirmation du nouveau mot de passe ne correspond pas.");
      return;
    }
    setBusy(true);
    setAuthMessage("");
    try {
      const freshSession = await ensureFreshSession(activeSession);
      const data = await authRequest({
        action: "change_password",
        current_password: currentPassword,
        new_password: newPassword,
        refresh_token: freshSession.refreshToken,
      }, freshSession.accessToken);
      const updated = parseWebSession(data);
      setAuthSession(updated);
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
      setAuthMessage("Mot de passe modifié. Les données affichées dans le portail restent des brouillons locaux.");
    } catch (error) {
      setAuthMessage(error instanceof Error ? error.message : "Le changement de mot de passe a échoué.");
    } finally {
      setBusy(false);
    }
  }

  async function signOut() {
    const activeSession = authSession;
    setBusy(true);
    let serverRevoked = false;
    try {
      if (activeSession) {
        const freshSession = await ensureFreshSession(activeSession);
        await authRequest({ action: "logout", device: webDevicePayload() }, freshSession.accessToken);
        serverRevoked = true;
      }
    } catch {
      serverRevoked = false;
    } finally {
      sessionFence.current={generation:sessionFence.current.generation+1,scope:""};
      setAuthSession(null);
      setAuthenticated(false);
      setPreview(false);
      setPassword("");
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
      setEntries({} as Record<ModuleId, Entry[]>);
      setRemoteChanges([]);
      setPendingSyncCount(0);
      setWorkstations([]);
      setWorkstationSiteId("");
      setActiveSiteId("");
      performanceRequest.current++;
      setPerformanceData(null);
      setPerformanceError("");
      setPerformanceBusy(false);
      setDialogOpen(false);
      setActive("overview");
      setBusy(false);
      setAuthMessage(serverRevoked || !activeSession
        ? "Session fermée."
        : "Vous êtes déconnecté. Une nouvelle connexion sera nécessaire.");
    }
  }


  async function syncWebOutbox(activeSession: WebAuthSession) {
    const isCurrent=captureSession(activeSession);
    if (!accountingEndpoint || !anonKey) throw new Error("Actualisation indisponible.");
    const freshSession = await ensureFreshSession(activeSession);
    const batch = await acquireDueBatch(25, Date.now(), 60_000, OFFLINE_APP_ID, freshSession.deviceId, freshSession.account.organization_id);
    let acknowledged=0,retrying=0,rejected=0,billingHolds=0;
    for (const queued of batch) {
      let status:number|null=null,errorCode="NETWORK_UNAVAILABLE",command:Record<string,unknown>={};
      try {
        command=JSON.parse(queued.payload) as Record<string,unknown>;
        if(queued.deviceId!==freshSession.deviceId||!Number.isSafeInteger(queued.deviceSequence)||(queued.deviceSequence??0)<=0){status=422;errorCode="LEGACY_QUEUE_EVENT_REQUIRES_REENQUEUE";throw new Error(errorCode);}
        const payload=command.payload;
        if(!payload||typeof payload!=="object"||Array.isArray(payload)||command.org_id!==freshSession.account.organization_id||typeof command.aggregate_type!=="string"||typeof command.aggregate_id!=="string"||typeof command.action_code!=="string"){status=422;errorCode="INVALID_QUEUED_DOMAIN_EVENT";throw new Error(errorCode);}
        const event={event_id:queued.eventId,device_id:freshSession.deviceId,device_sequence:queued.deviceSequence,org_id:command.org_id,site_id:typeof command.site_id==="string"?command.site_id:null,workstation_id:typeof command.workstation_id==="string"?command.workstation_id:null,aggregate_type:command.aggregate_type,aggregate_id:command.aggregate_id,action_code:command.action_code,payload};
        const response=await fetch(accountingEndpoint,{method:"POST",credentials:"omit",headers:{"Content-Type":"application/json",apikey:anonKey,Authorization:"Bearer "+freshSession.accessToken},body:JSON.stringify({action:"apply_sync_event",app_code:"naxa-services",event})});
        status=response.status;
        const data=await response.json().catch(()=>({})) as Record<string,unknown>;
        if(!response.ok||data.ok!==true){errorCode=typeof data.error==="string"?data.error:"REMOTE_REQUEST_FAILED";throw new Error(errorCode);}
        if(!data.result||typeof data.result!=="object"||Array.isArray(data.result)){errorCode="SERVER_RECEIPT_MISSING";throw new Error(errorCode);}
        const queueState=await applyServerReceipt(queued.eventId,data.result,OFFLINE_APP_ID);
        if(queueState==="acknowledged"){
          acknowledged++;
          const moduleId=typeof command.module_id==="string"?command.module_id as ModuleId:"stock";
          const id=typeof command.aggregate_id==="string"?command.aggregate_id:"";
          const receipt=data.result as Record<string,unknown>;
          const serverRecord=receipt.result&&typeof receipt.result==="object"&&!Array.isArray(receipt.result)?receipt.result as Record<string,unknown>:{};
          const eventPayload=command.payload&&typeof command.payload==="object"&&!Array.isArray(command.payload)?command.payload as Record<string,unknown>:{};
          if(id&&isCurrent())setEntries(prev=>!isCurrent()?prev:({...prev,[moduleId]:(prev[moduleId]??[]).map(x=>x.id===id?{
            ...x,state:"Confirmé",
            aggregateType:typeof command.aggregate_type==="string"?command.aggregate_type:x.aggregateType,
            actionCode:typeof command.action_code==="string"?command.action_code:x.actionCode,
            siteId:typeof command.site_id==="string"?command.site_id:x.siteId,
            data:{...(x.data??{}),...eventPayload,server_result:serverRecord,server_recorded_at:typeof receipt.recorded_at==="string"?receipt.recorded_at:x.data?.server_recorded_at},
            revision:typeof serverRecord.revision==="number"?serverRecord.revision:x.revision,
            status:typeof serverRecord.status==="string"?serverRecord.status:x.status,
          }:x)}));
        }
        else if(queueState==="rejected"||queueState==="conflict")rejected++;
      }catch{
        const willRetry=await scheduleRetry(queued.eventId,{status,errorCode},Date.now(),OFFLINE_APP_ID).catch(()=>false);
        if(willRetry){retrying++;if(errorCode==="NS_SUBSCRIPTION_ACCESS_REQUIRED")billingHolds++;}else rejected++;
      }
    }
    const remaining=await listQueued(OFFLINE_APP_ID,freshSession.deviceId,freshSession.account.organization_id);
    if(!isCurrent())return{acknowledged,retrying,rejected,remaining:remaining.length};
    setPendingSyncCount(remaining.length);
    await syncWebPullChanges(freshSession).catch(()=>undefined);
    if(!isCurrent())return{acknowledged,retrying,rejected,remaining:remaining.length};
    await hydrateWebRecords(freshSession);
    if(!isCurrent())return{acknowledged,retrying,rejected,remaining:remaining.length};
    if(acknowledged)setAuthMessage(acknowledged+" opération(s) confirmée(s).");
    else if(billingHolds)setAuthMessage("Abonnement à renouveler : les opérations locales sont conservées en attente de synchronisation.");
    else if(retrying)setAuthMessage(retrying+" opération(s) en attente de reprise réseau.");
    else if(rejected)setAuthMessage(rejected+" opération(s) rejetée(s) ou anciennes à ré-enregistrer ; aucun reçu n'a été fabriqué.");
    else if(!batch.length)setAuthMessage("Aucune opération Web en attente.");
    return{acknowledged,retrying,rejected,remaining:remaining.length};
  }
  async function syncWebPullChanges(activeSession: WebAuthSession) {
    const isCurrent=captureSession(activeSession);
    if(!accountingEndpoint||!anonKey)throw new Error("Actualisation indisponible.");
    const fresh=await ensureFreshSession(activeSession);
    let cursor=await getSyncCursor(OFFLINE_APP_ID,fresh.deviceId,fresh.account.organization_id),pages=0,received=0,more=true;
    while(more&&pages<20&&isCurrent()){
      const response=await fetch(accountingEndpoint,{method:"POST",credentials:"omit",headers:{"Content-Type":"application/json",apikey:anonKey,Authorization:"Bearer "+fresh.accessToken},body:JSON.stringify({action:"pull_sync_changes",org_id:fresh.account.organization_id,device_id:fresh.deviceId,after_cursor:cursor,limit:200})});
      const data=await response.json().catch(()=>({})) as Record<string,unknown>;
      if(!response.ok||data.ok!==true||!data.result||typeof data.result!=="object")throw new Error(typeof data.error==="string"?data.error:"WEB_SYNC_PULL_FAILED");
      const page=data.result as {changes?:WebSyncChange[];next_cursor?:number;has_more?:boolean};
      if(!Array.isArray(page.changes)||typeof page.next_cursor!=="number"||!Number.isSafeInteger(page.next_cursor)||typeof page.has_more!=="boolean"||page.next_cursor<cursor)throw new Error("WEB_SYNC_PULL_INVALID_PAGE");
      await applySyncPage(OFFLINE_APP_ID,fresh.deviceId,{changes:page.changes,next_cursor:page.next_cursor,has_more:page.has_more},fresh.account.organization_id);
      received+=page.changes.length;cursor=page.next_cursor;more=page.has_more;pages++;
    }
    const stored=await listSyncChanges(OFFLINE_APP_ID,fresh.deviceId,fresh.account.organization_id);
    if(!isCurrent())return{received,cursor,morePending:more};
    setRemoteChanges(stored);
    setEntries(previous=>{
      if(!isCurrent())return previous;
      const next={...previous};
      for(const change of stored){
        const moduleId=moduleForSyncAction(change.action_code);
        if(!moduleId)continue;
        const payload=change.payload;
        const rows=next[moduleId]??[],existing=rows.findIndex(entry=>entry.id===change.aggregate_id);
        const prior=rows[existing];
        const title=changeText(payload,["title","display_name","name","ticket_number","customer_name","customer_reference_or_name","subject","category","staff_name_snapshot","sku"],prior?.title??change.aggregate_id);
        const detail=changeText(payload,["description","counterparty","items_summary","service_reference_or_name","phone_contact","unit"],prior?.detail??change.action_code);
        const metadata = payload.metadata_json && typeof payload.metadata_json === "object" && !Array.isArray(payload.metadata_json)
          ? payload.metadata_json as Record<string,unknown> : {};
        const rawFields = metadata.fields && typeof metadata.fields === "object" && !Array.isArray(metadata.fields)
          ? metadata.fields as Record<string,unknown> : {};
        const extraFields = Object.fromEntries(Object.entries(rawFields).filter((entry): entry is [string,string] => typeof entry[1] === "string"));
        const serverRecord = payload.server_result && typeof payload.server_result === "object" && !Array.isArray(payload.server_result)
          ? payload.server_result as Record<string,unknown> : {};
        const profileValue = metadata.activity ?? metadata.activity_profile;
        const revision=typeof serverRecord.revision==="number"?serverRecord.revision:undefined;
        if(revision!==undefined && prior?.revision!==undefined && revision<prior.revision)continue;
        const record:Entry={
          id:change.aggregate_id,title,detail,state:"Confirmé · autre appareil",createdAt:new Date(change.recorded_at).toLocaleString("fr-FR"),
          recordType: change.aggregate_type === "work_order" || change.aggregate_type === "repair_order" || change.aggregate_type === "service_order" || change.aggregate_type === "pressing_order" ? change.aggregate_type : undefined,
          aggregateType: change.aggregate_type,
          actionCode: change.action_code,
          data: { ...prior?.data, ...payload, server_result: serverRecord, server_recorded_at: change.recorded_at },
          status: typeof serverRecord.status === "string" ? serverRecord.status
            : typeof payload.to_status === "string" ? payload.to_status
            : typeof payload.status === "string" ? payload.status : prior?.status,
          revision: revision ?? prior?.revision,
          siteId: change.site_id ?? undefined,
          activityProfile: typeof profileValue === "string" ? getActivityWorkflow(profileValue).profile
            : change.aggregate_type === "pressing_order" ? "pressing" : prior?.activityProfile,
          metadata: { ...prior?.metadata, ...extraFields },
        };
        next[moduleId]=existing>=0?rows.map((entry,index)=>index===existing?record:entry):[...rows,record];
      }
      return next;
    });
    return{received,cursor,morePending:more};
  }

  async function submitStockItem() {
    const activeSession = authSession;
    if (!activeSession) { addLocalEntry(); return; }
    const isCurrent=captureSession(activeSession);
    setBusy(true);
    try {
      const siteId = activeSiteId || activeSession.account.active_site_ids[0] || "";
      if (!siteId || !activeSession.account.active_site_ids.includes(siteId)) throw new Error("Choisis un point de vente autorisé pour cette session.");
      const item = normalizeInventoryItemDraft({
        name: draftTitle, sku: draftSku, unit: draftUnit,
        reorderLevel: Number(draftReorderLevel), supplierWhatsApp: draftSupplierWhatsApp,
      });
      const inventoryItemId = crypto.randomUUID();
      const eventId = crypto.randomUUID();
      const payload={module_id:"stock",display_title:item.name,display_detail:item.sku||item.unit,action_code:"inventory_item.created",aggregate_type:"inventory_item",aggregate_id:inventoryItemId,org_id:activeSession.account.organization_id,site_id:siteId,payload:{inventory_item_id:inventoryItemId,org_id:activeSession.account.organization_id,site_id:siteId,sku:item.sku,name:item.name,unit:item.unit,reorder_level:item.reorderLevel,supplier_whatsapp:item.supplierWhatsApp}};
      await enqueueOfflineEvent({appId:OFFLINE_APP_ID,eventId,deviceId:activeSession.deviceId,organizationId:activeSession.account.organization_id,payload:JSON.stringify(payload),state:"queued",createdAt:Date.now()});
      if(!isCurrent())return;
      setEntries((previous) => !isCurrent()?previous:({
        ...previous,
        stock: [...(previous.stock ?? []), {
          id: inventoryItemId, title: item.name, detail: item.sku || item.unit,
          state: navigator.onLine ? "En attente de confirmation" : "En attente de connexion",
          createdAt: new Date().toLocaleString("fr-FR"), siteId,
        }],
      }));
      setDraftTitle(""); setDraftDetail(""); setDraftSku(""); setDraftUnit("pièce");
      setDraftReorderLevel("0"); setDraftSupplierWhatsApp(""); setDialogOpen(false);
      setPendingSyncCount((count) => count + 1);
      if (navigator.onLine) await syncWebOutbox(activeSession);
      else setAuthMessage("Article placé dans la file hors ligne. Utilise Synchroniser après le retour du réseau.");
    } catch (error) {
      setAuthMessage(error instanceof Error ? error.message : "Création du consommable impossible.");
    } finally { setBusy(false); }
  }

  async function submitWebBusinessEvent(
    moduleId: ModuleId, actionCode: string, aggregateType: string, aggregateId: string,
    payload: Record<string, unknown>, siteId: string, title: string, detail: string, extra: Partial<Entry> = {},
  ) {
    const session = authSession;
    if (!session) throw new Error("AUTHENTICATION_REQUIRED");
    const isCurrent=captureSession(session);
    if (!session.account.active_site_ids.includes(siteId)) throw new Error("SITE_SCOPE_FORBIDDEN");
    const eventId = crypto.randomUUID();
    const command = {
      module_id: moduleId, display_title: title, display_detail: detail,
      action_code: actionCode, aggregate_type: aggregateType,
      aggregate_id: aggregateId, org_id: session.account.organization_id, site_id: siteId,
      payload: { ...payload, org_id: session.account.organization_id, site_id: siteId },
    };
    await enqueueOfflineEvent({appId:OFFLINE_APP_ID,eventId,deviceId:session.deviceId,organizationId:session.account.organization_id,payload:JSON.stringify(command),state:"queued",createdAt:Date.now()});
    if(!isCurrent())return;
    setEntries(previous => {
      if(!isCurrent())return previous;
      const rows=previous[moduleId]??[];
      const index=rows.findIndex(entry=>entry.id===aggregateId);
      const existing=index>=0?rows[index]:undefined;
      const next:Entry={
        ...existing,
        id:aggregateId,title,detail,
        state:navigator.onLine?"En attente de confirmation":"En attente de connexion",
        createdAt:existing?.createdAt??new Date().toLocaleString("fr-FR"),
        aggregateType, actionCode, siteId,
        data:{...(existing?.data??{}),...payload},
        ...extra,
      };
      return {...previous,[moduleId]:index>=0?rows.map((entry,rowIndex)=>rowIndex===index?next:entry):[...rows,next]};
    });
    setPendingSyncCount(count=>count+1);
    setDialogOpen(false);
    setDraftTitle("");setDraftDetail("");setDraftSku("");setDraftPhone("");setDraftAmount("0");
    setDraftDate("");setDraftEndDate("");setDraftContactConsent(false);setDraftPriority("normal");setDraftActivity("general");
    if(navigator.onLine)await syncWebOutbox(session);
    else setAuthMessage("Opération enregistré hors connexion ; elle sera envoyée au retour du réseau.");
  }

  async function submitModuleOperation() {
    const session=authSession;
    if(!session)throw new Error("AUTHENTICATION_REQUIRED");
    const siteId=activeSiteId||session.account.active_site_ids[0]||"";
    if(!siteId||!session.account.active_site_ids.includes(siteId))throw new Error("Choisis un point de vente autorisé.");
    const id=crypto.randomUUID(),title=draftTitle.trim(),detail=draftDetail.trim(),amount=Number(draftAmount);
    const toIso=(value:string,label:string)=>{const date=new Date(value);if(!value||!Number.isFinite(date.getTime()))throw new Error("Date invalide : "+label);return date.toISOString();};
    switch(active){
      case "customers":
        if(title.length<2)throw new Error("Le nom du client doit contenir au moins 2 caractères.");
        await submitWebBusinessEvent("customers","customer.created","customer",id,{
          customer_id:id,display_name:title,phone_contact:draftPhone.trim(),contact_consent:draftContactConsent,
          address_line:"",neighborhood:"",landmark:"",notes_private:"",
        },siteId,title,draftPhone||"Fiche client");return;
      case "services":
        if(title.length<2||!draftSku.trim())throw new Error("Le nom et le code de prestation sont obligatoires.");
        if(!Number.isSafeInteger(amount)||amount<0)throw new Error("Tarif invalide : montant entier positif ou nul en FCFA.");
        await submitWebBusinessEvent("services","service.created","service",id,{
          service_id:id,code:draftSku.trim().toUpperCase(),activity:draftActivity,name:title,
          duration_minutes:null,price_xaf:amount,active:true,category:"",description:detail,
          provider_member_ids:[],required_workstation_kinds:[],package_sessions:null,
        },siteId,title,draftSku.toUpperCase()+" · "+amount.toLocaleString("fr-FR")+" FCFA");return;
      case "pressing":
        if(title.length<2||detail.length<2||!Number.isSafeInteger(amount)||amount<=0)throw new Error("Client, détail des articles et montant total sont obligatoires.");
        await submitWebBusinessEvent("pressing","pressing_order.created","pressing_order",id,{
          order_id:id,ticket_number:"PS-"+id.slice(0,8).toUpperCase(),customer_name:title,customer_phone:draftPhone.trim(),
          items_summary:detail,total_xaf:amount,deposit_xaf:0,deposit_payment_method:null,cash_session_id:null,
          promised_at:toIso(draftDate,"date promise"),workstation_id:null,
        },siteId,"PS-"+id.slice(0,8).toUpperCase()+" · "+title,amount.toLocaleString("fr-FR")+" FCFA · sans acompte",{
          recordType:"pressing_order",status:"received",siteId,activityProfile:"pressing",
        });return;
      case "agenda":{
        if(title.length<2||detail.length<2)throw new Error("Client et prestation obligatoires.");
        const starts=toIso(draftDate,"début"),ends=toIso(draftEndDate,"fin");
        if(new Date(ends).getTime()<=new Date(starts).getTime())throw new Error("La fin doit être postérieure au début.");
        await submitWebBusinessEvent("agenda","appointment.created","appointment",id,{
          appointment_id:id,customer_reference_or_name:title,service_reference_or_name:detail,
          assigned_member_id:session.account.member_id,starts_at:starts,ends_at:ends,
          deposit_xaf:0,status:"booked",workstation_id:null,
        },siteId,title,detail);return;
      }
      case "cash":
        if(!title||detail.length<2||!Number.isSafeInteger(amount)||amount<=0)throw new Error("Catégorie, motif et montant de dépense obligatoires.");
        await submitWebBusinessEvent("cash","expense.created","expense",id,{
          expense_id:id,category:title,description:detail,amount_xaf:amount,
          occurred_at:draftDate?toIso(draftDate,"date de dépense"):new Date().toISOString(),
          cash_session_id:null,idempotency_key:id,
        },siteId,title,amount.toLocaleString("fr-FR")+" FCFA");return;
      case "help":
        if(title.length<3||detail.length<3)throw new Error("Sujet et description doivent contenir au moins 3 caractères.");
        await submitWebBusinessEvent("help","support_request.created","support_request",id,{
          request_id:id,subject:title,description:detail,priority:draftPriority,
        },siteId,title,"Assistance · "+draftPriority);return;
      case "team": await recordStaffTimeEvent("staff_clock_in");return;
      default: throw new Error("Aucun parcours métier Web n'est livré pour ce module.");
    }
  }


  function sharedOperationSiteId(): string {
    const session=authSession;
    if(!session)throw new Error("AUTHENTICATION_REQUIRED");
    const siteId=activeSiteId||session.account.active_site_ids[0]||"";
    if(!siteId||!session.account.active_site_ids.includes(siteId))throw new Error("Choisis un point de vente autorisé.");
    return siteId;
  }

  async function createCashRegister(input:{code:string;name:string}) {
    const id=crypto.randomUUID(),siteId=sharedOperationSiteId();
    const code=input.code.trim().toUpperCase(),name=input.name.trim();
    if(!/^[A-Z0-9][A-Z0-9_-]{1,19}$/.test(code)||name.length<1)throw new Error("Code ou nom du registre invalide.");
    await submitWebBusinessEvent("cash","cash_register.created","cash_register",id,
      {register_id:id,code,name,workstation_id:null},siteId,name,"Registre "+code);
  }

  async function openCashSession(input:{register:Entry;openingFloat:number}) {
    const id=crypto.randomUUID(),siteId=sharedOperationSiteId();
    if(!Number.isSafeInteger(input.openingFloat)||input.openingFloat<0)throw new Error("Fonds d'ouverture invalide.");
    if(!input.register.state.includes("Confirmé")&&!input.register.state.startsWith("Confirmé"))throw new Error("Le registre doit être confirmé.");
    await submitWebBusinessEvent("cash","cash_session.opened","cash_session",id,
      {cash_session_id:id,register_id:input.register.id,register_name:String(input.register.data?.name??input.register.title),
       opening_float_xaf:input.openingFloat,opened_at:new Date().toISOString()},
      siteId,"Session · "+input.register.title,"Fonds d'ouverture "+input.openingFloat.toLocaleString("fr-FR")+" FCFA");
  }

  async function createCashSale(input:{session:Entry;description:string;amount:number;itemId:string;quantity:number;paymentMethod:string}) {
    const session=authSession;if(!session)throw new Error("AUTHENTICATION_REQUIRED");
    const siteId=sharedOperationSiteId(),id=crypto.randomUUID();
    if(input.session.status!=="open"||(!input.session.state.includes("Confirmé")&&!input.session.state.startsWith("Confirmé")))throw new Error("La caisse doit être ouverte et confirmée.");
    if(input.description.trim().length<2||!Number.isSafeInteger(input.amount)||input.amount<=0)throw new Error("Désignation et montant entier positif obligatoires.");
    if(input.itemId&&(!Number.isFinite(input.quantity)||input.quantity<=0))throw new Error("Quantité de sortie stock invalide.");
    await submitWebBusinessEvent("cash","sale.created","sale",id,{
      sale_id:id,cash_session_id:input.session.id,sale_number:"VS-"+id.slice(0,8).toUpperCase(),
      description:input.description.trim(),total_xaf:input.amount,payment_method:input.paymentMethod,status:"confirmed",
      inventory_item_id:input.itemId||null,stock_quantity:input.itemId?input.quantity:null,
      created_at:new Date().toISOString(),
    },siteId,"Vente · "+input.description.trim(),input.amount.toLocaleString("fr-FR")+" FCFA · "+(input.paymentMethod==="cash"?"espèces":"Mobile Money externe"),{status:"pending"});
  }

  async function closeCashSession(input:{session:Entry;countedClose:number;reason:string}) {
    const siteId=sharedOperationSiteId();
    if(input.session.status!=="open"||!Number.isSafeInteger(input.countedClose)||input.countedClose<0)throw new Error("Session ou montant compté invalide.");
    await submitWebBusinessEvent("cash","cash_session.closed","cash_session",input.session.id,{
      cash_session_id:input.session.id,counted_close_xaf:input.countedClose,variance_reason:input.reason.trim(),closed_at:new Date().toISOString(),
    },siteId,"Clôture · "+input.session.title,"Montant compté "+input.countedClose.toLocaleString("fr-FR")+" FCFA",{status:"closing"});
  }

  async function transitionWebAppointment(entry:Entry,nextStatus:string,reason:string) {
    if(entry.aggregateType!=="appointment"||!entry.siteId||!entry.revision||!entry.status)throw new Error("Rendez-vous en attente de confirmation.");
    const allowed:Record<string,string[]>={booked:["confirmed","cancelled","no_show"],confirmed:["cancelled","no_show","completed"]};
    if(!(allowed[entry.status]??[]).includes(nextStatus)||reason.trim().length<3)throw new Error("Transition ou motif invalide.");
    const payload={appointment_id:entry.id,from_status:entry.status,to_status:nextStatus,reason:reason.trim(),expected_version:entry.revision,transitioned_at:new Date().toISOString()};
    await submitWebBusinessEvent("agenda","appointment.status_changed","appointment",entry.id,payload,entry.siteId,entry.title,"Statut : "+nextStatus,{status:nextStatus});
  }

  async function rescheduleWebAppointment(entry:Entry,startsAt:string,endsAt:string,reason:string) {
    if(entry.aggregateType!=="appointment"||!entry.siteId||!entry.revision||!["booked","confirmed"].includes(entry.status??""))throw new Error("Ce rendez-vous ne peut pas être reporté.");
    const starts=new Date(startsAt),ends=new Date(endsAt);
    if(!startsAt||!endsAt||!Number.isFinite(starts.getTime())||!Number.isFinite(ends.getTime())||ends<=starts||reason.trim().length<3)throw new Error("Dates ou motif de report invalides.");
    await submitWebBusinessEvent("agenda","appointment.rescheduled","appointment",entry.id,{
      appointment_id:entry.id,starts_at:starts.toISOString(),ends_at:ends.toISOString(),
      workstation_id:null,assigned_member_id:null,expected_version:entry.revision,reason:reason.trim(),
    },entry.siteId,entry.title,"Report · "+starts.toLocaleString("fr-FR"),{data:{...(entry.data??{}),starts_at:starts.toISOString(),ends_at:ends.toISOString()}});
  }

  async function createInventoryMovement(input:{itemId:string;type:string;quantity:number;reason:string}) {
    const siteId=sharedOperationSiteId(),id=crypto.randomUUID();
    if(!["in","consumption","loss","adjustment"].includes(input.type)||!Number.isFinite(input.quantity)||input.quantity===0||(input.type!=="adjustment"&&input.quantity<0)||input.reason.trim().length<3)throw new Error("Mouvement de stock invalide.");
    const delta=input.type==="in"?Math.abs(input.quantity):input.type==="adjustment"?input.quantity:-Math.abs(input.quantity);
    await submitWebBusinessEvent("stock","inventory_movement.created","inventory_movement",id,{
      movement_id:id,inventory_item_id:input.itemId,movement_type:input.type,quantity_delta:delta,reason:input.reason.trim(),
    },siteId,"Mouvement de stock",input.type+" · "+delta);
  }

  async function createSupplier(input:{name:string;phone:string;whatsapp:string;email:string;address:string;paymentTermsDays:number}) {
    const siteId=sharedOperationSiteId(),id=crypto.randomUUID();
    if(input.name.trim().length<2||!Number.isInteger(input.paymentTermsDays)||input.paymentTermsDays<0||input.paymentTermsDays>365)throw new Error("Fiche fournisseur invalide.");
    await submitWebBusinessEvent("stock","supplier.saved","supplier",id,{
      supplier_id:id,name:input.name.trim(),phone:input.phone.trim(),whatsapp:input.whatsapp.trim(),
      email:input.email.trim(),address:input.address.trim(),payment_terms_days:input.paymentTermsDays,notes:"",
    },siteId,input.name.trim(),"Fiche fournisseur");
  }

  async function createSupplierPurchase(input:{supplier:Entry;item:Entry;reference:string;quantity:number;unitCost:number}) {
    const siteId=sharedOperationSiteId(),id=crypto.randomUUID(),lineId=crypto.randomUUID();
    if(input.reference.trim().length<3||!Number.isFinite(input.quantity)||input.quantity<=0||!Number.isSafeInteger(input.unitCost)||input.unitCost<=0)throw new Error("Ligne de commande fournisseur invalide.");
    const unit=typeof input.item.data?.unit==="string"?input.item.data.unit:"unité";
    const payload={
      purchase_id:id,idempotency_key:id,supplier_id:input.supplier.id,reference:input.reference.trim(),
      supplier_invoice_number:"",recoverable_tax_xaf:0,non_recoverable_tax_xaf:0,shipping_xaf:0,other_fees_xaf:0,due_at:null,notes:"",
      lines:[{line_id:lineId,inventory_item_id:input.item.id,description:input.item.title,item_type:"stock",unit,quantity_ordered:input.quantity,unit_cost_xaf:input.unitCost}],
    };
    await submitWebBusinessEvent("stock","purchase.ordered","purchase",id,payload,siteId,"Achat "+input.reference.trim(),
      moneyLabel(input.quantity*input.unitCost)+" · "+input.supplier.title);
  }

  async function receiveSupplierPurchase(input:{purchase:Entry;quantity:number}) {
    const siteId=sharedOperationSiteId(),key=crypto.randomUUID(),lines=input.purchase.data?.lines as Record<string,unknown>[]|undefined,lineId=lines?.[0]?.line_id;
    if(typeof lineId!=="string"||!Number.isFinite(input.quantity)||input.quantity<=0)throw new Error("Réception fournisseur sans ligne valide.");
    await submitWebBusinessEvent("stock","purchase.receipt.confirmed","purchase_receipt",key,{
      receipt_id:key,idempotency_key:key,purchase_id:input.purchase.id,line_id:lineId,quantity:input.quantity,
    },siteId,"Réception · "+input.purchase.title,input.quantity+" unité(s)");
  }

  async function paySupplier(input:{purchase:Entry;amount:number;reference:string}) {
    const siteId=sharedOperationSiteId(),key=crypto.randomUUID();
    if(!Number.isSafeInteger(input.amount)||input.amount<=0)throw new Error("Montant de règlement bancaire invalide.");
    const receipts=entries.stock??[];
    if(!receipts.some(x=>x.actionCode==="purchase.receipt.confirmed"&&x.data?.purchase_id===input.purchase.id&&
      (x.state.includes("Confirmé")||x.state.startsWith("Confirmé"))))throw new Error("Un reçu de réception confirmé est requis avant règlement.");
    await submitWebBusinessEvent("stock","supplier.payment.recorded","supplier_payment",key,{
      payment_id:key,idempotency_key:key,purchase_id:input.purchase.id,amount_xaf:input.amount,payment_method:"bank",
      cash_session_id:null,payment_reference:input.reference.trim(),
    },siteId,"Règlement fournisseur","Virement · "+input.amount.toLocaleString("fr-FR")+" FCFA");
  }

  async function recordStaffTimeEvent(eventType:"staff_clock_in"|"staff_break_start"|"staff_break_end"|"staff_clock_out") {
    const session=authSession;if(!session)throw new Error("AUTHENTICATION_REQUIRED");
    const siteId=sharedOperationSiteId(),id=crypto.randomUUID();
    if(env.VITE_NAXA_SERVICES_ATTENDANCE_ENABLED==="true"&&rosterModeEnabled(session.account.business_mode)){setAttendanceRequest({scope:scopeOf(session)+":"+sessionFence.current.generation,site:siteId,action:eventType});setDialogOpen(false);return;}
    await submitWebBusinessEvent("team",eventType+".recorded",eventType,id,{
      time_event_id:id,staff_member_id:session.account.member_id,staff_name_snapshot:session.account.display_name,
      occurred_at:new Date().toISOString(),workstation_id:null,
    },siteId,session.account.display_name,eventType.replaceAll("_"," "));
  }

  async function createCustomerFollowup(input:{customer:Entry;title:string;frequency:string;channel:string;notes:string;nextDue:string}) {
    const siteId=sharedOperationSiteId(),id=crypto.randomUUID(),due=new Date(input.nextDue);
    if(!Number.isFinite(due.getTime())||input.title.trim().length<1||input.frequency.trim().length<1||input.channel.trim().length<1)throw new Error("Données de suivi client invalides.");
    await submitWebBusinessEvent("customers","customer_followup.created","customer_followup",id,{
      followup_id:id,customer_id:input.customer.id,title:input.title.trim(),frequency:input.frequency.trim(),
      channel:input.channel.trim(),notes:input.notes,next_due_at:due.toISOString(),status:"active",
    },siteId,input.title.trim(),input.customer.title+" · "+due.toLocaleDateString("fr-FR"));
  }

  async function completeCustomerFollowup(input:{followup:Entry;note:string;nextDue:string}) {
    const siteId=sharedOperationSiteId(),now=new Date(),nextDue=input.nextDue?new Date(input.nextDue):null;
    if(input.followup.aggregateType!=="customer_followup"||input.followup.siteId!==siteId||input.followup.status!=="active"||
      !(input.followup.state.includes("Confirmé")||input.followup.state.startsWith("Confirmé")))throw new Error("Suivi actif et confirmé du site requis.");
    if(input.note.length>1000||(nextDue&&(!Number.isFinite(nextDue.getTime())||nextDue<=now)))throw new Error("Note ou nouvelle échéance invalide.");
    await submitWebBusinessEvent("customers","customer_followup.completed","customer_followup",input.followup.id,{
      followup_id:input.followup.id,completed_at:now.toISOString(),next_due_at_if_repeating:nextDue?.toISOString()??null,completion_note:input.note.trim(),
    },siteId,input.followup.title,input.followup.detail,{status:input.followup.status});
  }

  function moneyLabel(value:number):string{return Number.isFinite(value)?Math.round(value).toLocaleString("fr-FR")+" FCFA":"Montant invalide";}

  async function createWebWorkOrder(input: {
    customer: string; title: string; amountXaf: number; dueDate: string; fields: Record<string,string>;
  }) {
    const session = authSession;
    if (!session) throw new Error("AUTHENTICATION_REQUIRED");
    const workflow = getActivityWorkflow(session.account.activity_profile);
    if (workflow.profile === "pressing") throw new Error("Le Pressing utilise son parcours de dépôt et de ticket dédié.");
    const missing = validateActivityFields(workflow.profile, input.fields);
    if (missing.length) throw new Error("Champs métier obligatoires manquants : " + missing.join(", "));
    const siteId = activeSiteId || session.account.active_site_ids[0] || "";
    if (!siteId || !session.account.active_site_ids.includes(siteId)) throw new Error("Choisis un point de vente autorisé.");
    if (input.customer.trim().length < 2 || input.title.trim().length < 2) throw new Error("Client et intitulé du dossier sont obligatoires.");
    if (!Number.isSafeInteger(input.amountXaf) || input.amountXaf < 0) throw new Error("Le montant estimatif doit être un entier positif ou nul en FCFA.");
    const id = crypto.randomUUID();
    const recordType = workflow.recordType === "retail" ? "work_order" : workflow.recordType;
    if (recordType === "pressing_order") throw new Error("Le Pressing possède son propre registre de tickets.");
    const dueAt = input.dueDate ? new Date(input.dueDate).toISOString() : null;
    const metadata = {
      activity: workflow.profile,
      activity_profile: workflow.profile,
      workflow_version: 1,
      journey: workflow.journey,
      fields: input.fields,
    };
    if (new TextEncoder().encode(JSON.stringify(metadata)).byteLength > 3800) {
      throw new Error("Les informations du dossier sont trop volumineuses. Réduis les notes avant de réessayer.");
    }
    const displayDetail = workflow.profile === "parfumerie"
      ? "Commande spéciale · " + Object.values(input.fields).filter(Boolean).join(" · ")
      : Object.values(input.fields).filter(Boolean).join(" · ");
    await submitWebBusinessEvent(
      "workOrders", recordType + ".created", recordType, id,
      {
        record_id: id, record_type: recordType,
        reference: (recordType === "repair_order" ? "REP-" : recordType === "service_order" ? "SRV-" : "WO-") + id.slice(0, 8).toUpperCase(),
        title: input.title.trim(), counterparty: input.customer.trim(),
        amount_xaf: input.amountXaf, paid_xaf: 0, due_at: dueAt,
        status: "received", workstation_id: null, metadata_json: metadata,
      },
      siteId, input.title.trim(),
      input.customer.trim() + " · " + displayDetail,
      {
        recordType, status: "received", siteId,
        activityProfile: workflow.profile,
        metadata: input.fields,
      },
    );
  }

  async function transitionWebPressing(entry: Entry, nextStatus: string, reason: string) {
    const session=authSession;
    if(!session||entry.recordType!=="pressing_order"||!entry.siteId||!entry.status||
      !confirmedActivityRevision(entry)) {
      throw new Error("Attendez la confirmation avant de passer à l'étape suivante.");
    }
    if(entry.siteId !== (activeSiteId || session.account.active_site_ids[0])) throw new Error("Sélectionne le point de vente du ticket avant sa transition.");
    if(!canTransitionActivity("pressing",entry.status,nextStatus)) throw new Error("Transition Pressing interdite.");
    if(reason.trim().length<3||reason.trim().length>500) throw new Error("Un motif de trois à 500 caractères est obligatoire.");
    await submitWebBusinessEvent(
      "pressing","pressing_order.status_changed:"+nextStatus,"pressing_order",entry.id,
      {order_id:entry.id,from_status:entry.status,reason:reason.trim(),expected_version:entry.revision,transitioned_at:new Date().toISOString()},
      entry.siteId,entry.title,entry.detail+" · "+entry.status+" → "+nextStatus,
      {...entry,status:nextStatus,revision:undefined,state:"Étape en attente de confirmation"},
    );
  }

  async function transitionWebWorkOrder(entry: Entry, nextStatus: string, reason: string) {
    const session = authSession;
    if (!session || !entry.recordType || !entry.siteId || !entry.status || !confirmedActivityRevision(entry)) {
      throw new Error("Attendez la confirmation avant de poursuivre.");
    }
    if(entry.siteId !== (activeSiteId || session.account.active_site_ids[0])) throw new Error("Sélectionne le point de vente du dossier avant sa transition.");
    const profile = entry.activityProfile ?? session.account.activity_profile;
    if (!canTransitionActivity(profile, entry.status, nextStatus)) throw new Error("Transition interdite pour ce parcours métier.");
    if (reason.trim().length < 3 || reason.trim().length > 500) throw new Error("Un motif de trois à 500 caractères est obligatoire.");
    await submitWebBusinessEvent(
      "workOrders", entry.recordType + ".status_changed", entry.recordType, entry.id,
      {
        record_id: entry.id, from_status: entry.status, to_status: nextStatus,
        reason: reason.trim(), expected_version: entry.revision,
        metadata_json_delta: {}, transitioned_at: new Date().toISOString(), workstation_id: null,
      },
      entry.siteId, entry.title, entry.detail + " · " + entry.status + " → " + nextStatus,
      { ...entry, status: nextStatus, revision: undefined, state: "Étape en attente de confirmation" },
    );
  }

  function addLocalEntry() {
    if (!preview) { setAuthMessage("Cette action est indisponible. Aucune donnée n'a été enregistrée."); setDialogOpen(false); return; }
    const title = draftTitle.trim();
    if (!title) return;
    const item: Entry = { id: crypto.randomUUID(), title, detail: draftDetail.trim(), state: "Brouillon local", createdAt: new Date().toLocaleString("fr-FR") };
    setEntries((prev) => ({ ...prev, [active]: [...(prev[active] ?? []), item] }));
    setDraftTitle("");
    setDraftDetail("");
    setDialogOpen(false);
  }

  const visibleModules = modules.filter((m) => (m.title + " " + m.description + " " + m.group).toLowerCase().includes(search.toLowerCase()));

  if (authenticated && authSession?.requirePasswordChange) {
    return (
      <div className={"app auth-app " + theme}>
        <div className="auth-art"><BusinessBackdrop kind="auth"/>
          <div className="auth-brand"><img src="/naxa-services-logo.svg" alt="NAXA Services" /></div>
          <div className="auth-copy">
            <span className="eyebrow">{t("PROTECTION DU COMPTE")}</span>
            <h1>{t("Une dernière")}<br /><em>{t("étape.")}</em></h1>
            <p>{t("Le mot de passe initial doit être remplacé avant tout accès aux pages de gestion.")}</p>
            <div className="auth-proof"><span>01</span> {t("Votre identité est authentifiée")}</div>
          </div>
          <div className="auth-footer">{t("NAXA SERVICES · COMPTE SÉCURISÉ")}</div>
        </div>
        <main className="auth-panel"><button className="auth-theme-toggle btn secondary" type="button" onClick={toggleTheme}>{theme==="dark"?t("Mode clair"):t("Mode nuit")}</button><NightTorch active={nightPulse}/>{languagePicker}
          <div className="mobile-brand"><img src="/naxa-services-logo.svg" alt="NAXA Services" /></div>
          <div className="auth-form-wrap">
            <span className="eyebrow">{t("CHANGEMENT OBLIGATOIRE")}</span>
            <h2>{t("Créer un nouveau mot de passe")}</h2>
            <p className="muted">{t("Choisissez un mot de passe d'au moins 10 caractères.")}</p>
            <form onSubmit={changeWebPassword} className="auth-form">
              <label>{t("Mot de passe actuel")}<input type="password" value={currentPassword} onChange={(e) => setCurrentPassword(e.target.value)} autoComplete="current-password" required /></label>
              <label>{t("Nouveau mot de passe")}<input type="password" value={newPassword} onChange={(e) => setNewPassword(e.target.value)} autoComplete="new-password" minLength={10} maxLength={256} required /></label>
              <label>{t("Confirmer le nouveau mot de passe")}<input type="password" value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} autoComplete="new-password" minLength={10} maxLength={256} required /></label>
              {authMessage && <div className="notice" role="status">{t(customerMessage(authMessage))}</div>}
              <button className="btn primary" disabled={busy}>{busy ? t("Vérification…") : t("Enregistrer le nouveau mot de passe")}</button>
            </form>
            <button className="link-button" onClick={signOut} disabled={busy}>{t("Fermer la session")}</button>
          </div>
          <div className="panel-bottom"><span>FR · EN · FF</span><span>{t("Connexion sécurisée")}</span></div>
        </main>
      </div>
    );
  }

  if (!authenticated && !preview) {
    return (
      <div className={"app auth-app " + theme}>
        <div className="auth-art"><BusinessBackdrop kind="auth"/>
          <div className="auth-brand"><img src="/naxa-services-logo.svg" alt="NAXA Services" /></div>
          <div className="auth-copy">
            <span className="eyebrow">{t("GESTION INTELLIGENTE DES PRESTATIONS")}</span>
            <h1>{t("Votre établissement.")}<br /><em>{t("Maîtrisé.")}</em></h1>
            <p>{t("Pressing, coiffure, équipes, caisse et points de vente réunis dans un espace professionnel.")}</p>
            <div className="auth-proof"><span>01</span> {t("Des opérations suivies de bout en bout")}</div>
            <div className="auth-proof"><span>02</span> {t("Une autonomie par établissement")}</div>
            <div className="auth-proof"><span>03</span> {t("Une vision réseau sans mélange des caisses")}</div>
          </div>
          <div className="auth-footer">{t("NAXA SERVICES · ESPACE PROFESSIONNEL")}</div>
        </div>
        <main className="auth-panel"><button className="auth-theme-toggle btn secondary" type="button" onClick={toggleTheme}>{theme==="dark"?t("Mode clair"):t("Mode nuit")}</button><NightTorch active={nightPulse}/>{languagePicker}
          <div className="mobile-brand"><img src="/naxa-services-logo.svg" alt="NAXA Services" /></div>
          <div className="auth-form-wrap">
            <span className="eyebrow">{showRecovery ? t("ASSISTANCE D'ACCÈS") : t("ESPACE SÉCURISÉ")}</span>
            <h2>{showRecovery ? t("Récupérer mon accès") : t("Content de vous revoir.")}</h2>
            <p className="muted">{showRecovery ? t("Votre responsable vous aidera à retrouver votre accès.") : t("Accédez à votre espace professionnel.")}</p>
            <form onSubmit={showRecovery ? requestRecovery : signIn} className="auth-form">
              <label>{t("Identifiant NAXA Services")}<input value={identifier} onChange={(e) => setIdentifier(e.target.value.toUpperCase())} placeholder="NS-000000" autoComplete="username" required /></label>
              {!showRecovery && <label>{t("Mot de passe")}<input type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" required /></label>}
              {showRecovery && <label>{t("Note au responsable (facultatif)")}<textarea rows={3} value={recoveryNote} onChange={(e) => setRecoveryNote(e.target.value)} placeholder={t("Expliquez brièvement votre demande")} /></label>}
              {authMessage && <div className="notice" role="status">{t(customerMessage(authMessage))}</div>}
              <button className="btn primary" disabled={busy}>{busy ? t("Traitement…") : showRecovery ? t("Envoyer la demande") : t("Se connecter")}</button>
            </form>
            <button className="link-button" onClick={() => { setShowRecovery(!showRecovery); setAuthMessage(""); }}>{showRecovery ? t("Retour à la connexion") : t("Mot de passe oublié ?")}</button>
            <button className="preview-link" onClick={() => { setPreview(true); setAuthMessage(""); }}>{t("Découvrir NAXA Services")}</button>
          </div>
          <div className="panel-bottom"><span>FR · EN · FF</span><span>{t("Mode sécurisé")}</span></div>
        </main>
      </div>
    );
  }

  return (
    <LocaleContext.Provider value={locale}><div className={"app erp-app " + theme}><NightTorch active={nightPulse}/>
      {preview && <div className="preview-banner"><strong>{t("DÉMONSTRATION")}</strong> Essayez les fonctionnalités sans enregistrer d'opérations réelles. <button onClick={() => { setPreview(false); setAuthenticated(false); setActive("overview"); }}>{t("Quitter l'aperçu")}</button></div>}
      {mobileMenu&&<button className="menu-scrim" aria-label={t("Fermer le menu")} onClick={()=>setMobileMenu(false)}/>}<aside className={"sidebar "+(mobileMenu?"mobile-open":"")} id="ns-navigation">
        <div className="side-brand"><img src="/naxa-services-logo.svg" alt="NAXA Services" /></div>
        <div className="workspace-label">{t("ESPACE DE TRAVAIL")}</div>
        <div className="site-select"><span className="site-dot" /> <div>{authSession && !preview ? <label>{t("Point de vente actif")}<select aria-label={t("Point de vente actif")} value={activeSiteId || authSession.account.active_site_ids[0] || ""} onChange={event => setActiveSiteId(event.target.value)} disabled={busy}>{authSession.account.active_sites.map(site => <option key={site.id} value={site.id}>{site.name}</option>)}</select></label> : <strong>{siteName}</strong>}<small>{t(modeLabel(mode))}</small></div></div>
        <nav className="side-nav">
          {grouped.map(([group, groupModules]) => <div className="nav-group" key={group}>
            <div className="nav-heading">{t(group)}</div>
            {groupModules.map((m) => <button key={m.id} data-module-id={m.id} aria-current={active===m.id?"page":undefined} className={"nav-item " + (active === m.id ? "active" : "")} onClick={() => {setActive(m.id);setMobileMenu(false);}}><span className="nav-glyph" aria-hidden="true">{iconFor(m.id)}</span><span>{t(m.title)}</span></button>)}
          </div>)}
        </nav>
        <div className="side-bottom">
          <button className="nav-item" onClick={toggleTheme}><span className="nav-glyph">◐</span>{theme === "dark" ? t("Mode clair") : t("Mode sombre")}</button>
          <button className="nav-item" onClick={signOut} disabled={busy}><span className="nav-glyph">↪</span>{t("Déconnexion")}</button>
          <div className="user-mini"><div className="avatar">NS</div><div><strong>{preview ? "Démonstration" : authSession?.account.display_name ?? "Espace connecté"}</strong><small>{authSession ? (authSession.account.organization_name || authSession.account.role_code || "NAXA Services") : "NAXA Services"}</small></div></div>
        </div>
      </aside>
      <main className="main-area">
        <header className="topbar">
          <div className="crumb"><button className="mobile-menu-trigger icon-button" aria-label={t("Tous les modules")} aria-expanded={mobileMenu} aria-controls="ns-navigation" onClick={()=>setMobileMenu(v=>!v)}>☰</button><span>NAXA SERVICES</span><b>/</b>{t(selected.title)}</div>
          <div className="top-actions">{languagePicker}
            <span className="sync-pill"><i /> {preview ? "Démonstration" : authSession ? (authSession.requirePasswordChange ? t("Changement du mot de passe requis") : t("Connecté")) : t("Non connecté")}</span>
            <button className="icon-button mobile-theme-toggle" aria-label={theme==="dark"?t("Mode clair"):t("Mode nuit")} onClick={toggleTheme}>{theme==="dark"?"☀":"☾"}</button><button className="icon-button" title={t("Aide")} onClick={() => setActive("help")}>?</button>
            {authSession && !preview && !authSession.requirePasswordChange ? <ProfilePhoto key={scopeOf(authSession)+":"+sessionFence.current.generation} authEndpoint={authEndpoint} anonKey={anonKey} orgId={authSession.account.organization_id} memberId={authSession.account.member_id} initials={authSession.account.display_name.slice(0,2).toUpperCase()} getToken={async()=>{const current=captureSession(authSession);const fresh=await ensureFreshSession(authSession);if(!current())throw new Error("Session expirée.");return fresh.accessToken;}}/> : <div className="avatar">NS</div>}
          </div>
        </header>
        <section className="content-area">
          {authSession && authMessage && <div className="notice" role="status">{t(customerMessage(authMessage))}</div>}
          <div className="page-heading">
            <div><span className="eyebrow">{t(moduleCopy[active].eyebrow)}</span><h1>{t(moduleCopy[active].headline)}</h1><p>{t(moduleCopy[active].helper)}</p></div>
            <div className="heading-actions">
              {active !== "overview" && <button className="btn secondary" onClick={() => setActive("overview")}>{t("Vue d'ensemble")}</button>}
              {authSession && <button className="btn secondary" disabled={busy} onClick={() => {
                const operation = pendingSyncCount > 0 ? syncWebOutbox(authSession) : syncWebPullChanges(authSession);
                void operation.catch((error) => setAuthMessage(error instanceof Error ? error.message : "Synchronisation impossible."));
              }}>{pendingSyncCount > 0 ? "Synchroniser (" + pendingSyncCount + ")" : t("Actualiser")}</button>}
              {active !== "workOrders" && active !== "team" && <button className="btn primary" disabled={busy || (!preview && !["stock","agenda","pressing","cash","services","customers","team","help"].includes(active))} title={!preview && !["stock","agenda","pressing","cash","services","customers","team","help"].includes(active) ? "Action indisponible." : undefined} onClick={() => {
                if (!preview && !["stock","agenda","pressing","cash","services","customers","team","help"].includes(active)) { setAuthMessage("Cette action est indisponible."); return; }
                setDraftTitle(active==="team"&&authSession?authSession.account.display_name:"");setDraftDetail("");setDraftSku("");setDraftUnit("pièce");setDraftReorderLevel("0");setDraftSupplierWhatsApp("");setDraftPhone("");setDraftAmount("0");setDraftDate("");setDraftEndDate("");setDraftPriority("normal");setDraftActivity("general");setDraftContactConsent(false);setDialogOpen(true);
              }}>{!preview&&!["stock","agenda","pressing","cash","services","customers","team","help"].includes(active)?"Indisponible":active==="team"?t("Pointer mon arrivée"):t(selected.action)}</button>}
            </div>
          </div>

          {active === "overview" ? <><Overview entries={entries} onNavigate={setActive} mode={mode} activity={authSession?.account.activity_profile} locale={locale} />{env.VITE_NAXA_SERVICES_BRIEFING_ENABLED==="true"&&authSession&&!preview&&!authSession.requirePasswordChange&&<DailyBriefing key={scopeOf(authSession)+":"+sessionFence.current.generation+":"+(activeSiteId||authSession.account.active_site_ids[0])} account={authSession.account} siteId={activeSiteId||authSession.account.active_site_ids[0]||""} authEndpoint={authEndpoint} anonKey={anonKey} getToken={async()=>{const current=captureSession(authSession);const fresh=await ensureFreshSession(authSession);if(!current())throw new Error("SESSION_CHANGED");return fresh.accessToken;}}/>}{env.VITE_NAXA_SERVICES_MEETINGS_ENABLED==="true"&&authSession&&!preview&&!authSession.requirePasswordChange&&rosterModeEnabled(authSession.account.business_mode)&&<InternalMeetings key={scopeOf(authSession)+":"+sessionFence.current.generation+":"+(activeSiteId||authSession.account.active_site_ids[0])} account={authSession.account} siteId={activeSiteId||authSession.account.active_site_ids[0]||""} authEndpoint={authEndpoint} anonKey={anonKey} getToken={async()=>{const current=captureSession(authSession);const fresh=await ensureFreshSession(authSession);if(!current())throw new Error("SESSION_CHANGED");return fresh.accessToken;}}/>}</> :
            active === "organization" ? <><OrganizationPage mode={mode} setMode={setMode} siteName={siteName} setSiteName={setSiteName} editable={preview || authSession?.account.role_code === "promoter"} onSave={saveWebOrganizationProfile} locale={authSession?.account.default_locale ?? "fr"} /><SubscriptionPage key={authSession?.account.organization_id+":"+authSession?.account.member_id+":"+authSession?.deviceId} canRead={Boolean(authSession&&!preview)} requiresPremium={Boolean(authSession&&authSession.account.business_mode!=="solo")} enabled={Boolean(authSession&&!preview&&authSession.account.role_code==="promoter")} request={requestSubscription}/></> :
            active === "network" || active === "sites" ? <SitesPage mode={mode} siteName={siteName} sites={authSession?.account.active_sites ?? []} canCreate={authSession?.account.role_code === "promoter"} onCreateSite={createWebSite} entries={entries.network ?? []} /> :
            active === "workstations" ? <WorkstationsPage mode={mode} sites={authSession?.account.active_sites ?? []} selectedSiteId={workstationSiteId || activeSiteId} workstations={workstations} onLoad={loadWebWorkstations} onCreate={createWebWorkstation} canCreate={Boolean(authSession && ["promoter","network_manager","site_manager"].includes(authSession.account.role_code))} /> :
            active === "security" ? <DeviceSecurityPage key={authSession?.deviceId??"preview"} authenticated={Boolean(authSession&&!preview)} onLoad={loadOwnDevices} onRevoke={revokeOwnDevice} /> :
            active === "reports" ? <PerformancePage data={performanceData} fromDate={performanceFromDate} setFromDate={changePerformanceDate} loading={performanceBusy} error={performanceError} onLoad={() => { void loadPerformanceReport(); }} authenticated={Boolean(authSession&&!preview)} locale={authSession?.account.default_locale??"fr"} /> :
            active === "agenda" ? <AgendaOperationsPage entries={(entries.agenda ?? []).filter(entry=>!entry.siteId||entry.siteId===(activeSiteId||authSession?.account.active_site_ids[0]))} authenticated={Boolean(authSession && !preview)} busy={busy} onTransition={transitionWebAppointment} onReschedule={rescheduleWebAppointment} /> :
            active === "pressing" ? <PressingPage
              entries={(entries.pressing ?? []).filter(entry => preview || entry.siteId === (activeSiteId || authSession?.account.active_site_ids[0]))} canPreviewEdit={preview}
              authenticated={Boolean(authSession && !preview)} busy={busy}
              onAdvance={(id) => setEntries((prev) => ({ ...prev, pressing: (prev.pressing ?? []).map((x) => x.id === id ? { ...x, state: nextPressingState(x.state) } : x) }))}
              onTransition={transitionWebPressing}
            /> :
            active === "workOrders" ? <WorkOrdersPage
              workflow={getActivityWorkflow(authSession?.account.activity_profile)}
              entries={(entries.workOrders ?? []).filter(entry => preview || entry.siteId === (activeSiteId || authSession?.account.active_site_ids[0]))}
              authenticated={Boolean(authSession && !preview)}
              busy={busy}
              siteName={authSession?.account.active_sites.find(site=>site.id===activeSiteId)?.name ?? siteName}
              onCreate={createWebWorkOrder}
              onTransition={transitionWebWorkOrder}
            /> :
            active === "cash" ? <CashOperationsPage
              entries={(entries.cash ?? []).filter(entry=>!entry.siteId||entry.siteId===(activeSiteId||authSession?.account.active_site_ids[0]))} stockEntries={(entries.stock ?? []).filter(entry=>!entry.siteId||entry.siteId===(activeSiteId||authSession?.account.active_site_ids[0]))}
              authenticated={Boolean(authSession && !preview)}
              canManage={Boolean(authSession && ["promoter","network_manager","site_manager"].includes(authSession.account.role_code))}
              busy={busy} onCreateRegister={createCashRegister} onOpenSession={openCashSession}
              onCreateSale={createCashSale} onCloseSession={closeCashSession}
            /> :
            active === "stock" ? <StockOperationsPage
              entries={(entries.stock ?? []).filter(entry=>!entry.siteId||entry.siteId===(activeSiteId||authSession?.account.active_site_ids[0]))} authenticated={Boolean(authSession && !preview)}
              canManage={Boolean(authSession && ["promoter","network_manager","site_manager"].includes(authSession.account.role_code))}
              busy={busy} onCreateSupplier={createSupplier} onMovement={createInventoryMovement}
              onPurchase={createSupplierPurchase} onReceive={receiveSupplierPurchase} onPay={paySupplier}
            /> :
            active === "team" ? <><TeamOperationsPage memberId={authSession?.account.member_id} entries={(entries.team ?? []).filter(entry=>!entry.siteId||entry.siteId===(activeSiteId||authSession?.account.active_site_ids[0]))} authenticated={Boolean(authSession && !preview)} busy={busy} onTimeEvent={recordStaffTimeEvent} />{env.VITE_NAXA_SERVICES_ATTENDANCE_ENABLED==="true"&&authSession&&!preview&&!authSession.requirePasswordChange&&rosterModeEnabled(authSession.account.business_mode)&&<AttendanceProofPanel key={scopeOf(authSession)+":"+sessionFence.current.generation+":"+(activeSiteId||authSession.account.active_site_ids[0])} account={authSession.account} siteId={activeSiteId||authSession.account.active_site_ids[0]||""} authEndpoint={authEndpoint} anonKey={anonKey} action={attendanceRequest?.scope===scopeOf(authSession)+":"+sessionFence.current.generation&&attendanceRequest.site===(activeSiteId||authSession.account.active_site_ids[0])?attendanceRequest.action:null} onClose={()=>setAttendanceRequest(null)} getToken={async()=>{const current=captureSession(authSession);const fresh=await ensureFreshSession(authSession);if(!current())throw new Error("SESSION_CHANGED");return fresh.accessToken;}} onSubmit={async(id,occurred,eventType)=>{const s=authSession;const current=captureSession(s);if(!current()||!attendanceRequest||attendanceRequest.scope!==scopeOf(s)+":"+sessionFence.current.generation||attendanceRequest.site!==sharedOperationSiteId()||attendanceRequest.action!==eventType)throw new Error("SESSION_CHANGED");await submitWebBusinessEvent("team",eventType+".recorded",eventType,id,{time_event_id:id,staff_member_id:s.account.member_id,staff_name_snapshot:s.account.display_name,occurred_at:occurred,workstation_id:null,attendance_proof_ref:id},attendanceRequest.site,s.account.display_name,eventType.replaceAll("_"," "));}}/>}{env.VITE_NAXA_SERVICES_ROSTER_ENABLED==="true" && authSession && !preview && !authSession.requirePasswordChange && rosterModeEnabled(authSession.account.business_mode) && <StaffRoster key={scopeOf(authSession)+":"+sessionFence.current.generation+":"+(activeSiteId||authSession.account.active_site_ids[0])} account={authSession.account} siteId={activeSiteId||authSession.account.active_site_ids[0]||""} authEndpoint={authEndpoint} anonKey={anonKey} getToken={async()=>{const current=captureSession(authSession);const fresh=await ensureFreshSession(authSession);if(!current())throw new Error("SESSION_CHANGED");return fresh.accessToken;}}/>}</> :
            active === "customers" ? <CustomerFollowupsPage entries={(entries.customers ?? []).filter(entry=>!entry.siteId||entry.siteId===(activeSiteId||authSession?.account.active_site_ids[0]))} authenticated={Boolean(authSession && !preview)} busy={busy} onCreate={createCustomerFollowup} onComplete={completeCustomerFollowup} /> :
            <GenericPage active={active} entries={entries[active] ?? []} copy={moduleCopy[active]} preview={preview} authenticated={Boolean(authSession && !preview)} />}
        </section>
        <nav className="mobile-tabs">
          {(["overview", "agenda", "pressing", "cash", "services"] as ModuleId[]).map((id) => <button key={id} className={active === id ? "selected" : ""} onClick={() => setActive(id)}><span>{iconFor(id)}</span>{t(modules.find((m) => m.id === id)?.title??"").split(" ")[0]}</button>)}
        </nav>
      </main>
      {dialogOpen && <div className="modal-backdrop" role="presentation" onMouseDown={(e) => { if (e.target === e.currentTarget) setDialogOpen(false); }}>
        <div className="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title">
          <div className="modal-head"><div><span className="eyebrow">{t(authSession&&!preview?"NOUVELLE OPÉRATION":"NOUVELLE OPÉRATION · DÉMONSTRATION")}</span><h2 id="modal-title">{active==="team"&&authSession&&!preview?t("Pointer mon arrivée"):t(selected.action)}</h2></div><button className="icon-button" onClick={() => setDialogOpen(false)}>×</button></div>
          <form onSubmit={(e) => {e.preventDefault();if(active==="stock"&&authSession)void submitStockItem();else if(authSession&&!preview)void submitModuleOperation().catch(error=>setAuthMessage(error instanceof Error?error.message:"Opération impossible."));else if(preview)addLocalEntry();else{setAuthMessage("Action indisponible.");setDialogOpen(false);}}}>
            <label>{t(active==="customers"||active==="pressing"?"Nom du client":active==="agenda"?"Nom / référence du client":active==="help"?"Sujet":active==="cash"?"Catégorie de dépense":active==="team"?"Membre":"Nom / référence")}<input autoFocus value={draftTitle} readOnly={active==="team"&&authSession&&!preview} onChange={(e) => setDraftTitle(e.target.value)} required placeholder={t("Saisir la valeur")} /></label>
            {active === "stock" && authSession ? <>
              <label>{t("Point de vente")}<select value={activeSiteId} onChange={(e) => setActiveSiteId(e.target.value)} required>{authSession.account.active_site_ids.map((siteId) => <option key={siteId} value={siteId}>{siteId}</option>)}</select></label>
              <label>{t("SKU (facultatif)")}<input value={draftSku} onChange={(e) => setDraftSku(e.target.value)} maxLength={80} /></label>
              <label>{t("Unité")}<input value={draftUnit} onChange={(e) => setDraftUnit(e.target.value)} required maxLength={40} /></label>
              <label>{t("Seuil d'alerte")}<input type="number" min="0" step="0.001" value={draftReorderLevel} onChange={(e) => setDraftReorderLevel(e.target.value)} required /></label>
              <label>{t("WhatsApp fournisseur")}<input value={draftSupplierWhatsApp} onChange={(e) => setDraftSupplierWhatsApp(e.target.value)} maxLength={32} placeholder="+237 6xx xx xx xx" /></label>
              <div className="notice">{t("L'article sera disponible après confirmation.")}</div>
            </> : authSession && !preview && active==="customers" ? <>
              <label>{t("Téléphone facultatif")}<input value={draftPhone} onChange={e=>setDraftPhone(e.target.value)} maxLength={32}/></label>
              <label><input type="checkbox" checked={draftContactConsent} onChange={e=>setDraftContactConsent(e.target.checked)}/> Consentement de contact obtenu</label>
            </> : authSession && !preview && active==="services" ? <>
              <label>{t("Code prestation")}<input value={draftSku} onChange={e=>setDraftSku(e.target.value)} required maxLength={80}/></label>
              <label>{t("Activité")}<select value={draftActivity} onChange={e=>setDraftActivity(e.target.value)}>{["pressing","hair","beauty","treatment","tailoring","perfume","repair","part","manufacturing","vehicle","cleaning","contract","home","printing","event","package","material","service","retail","general"].map(v=><option key={v} value={v}>{v}</option>)}</select></label>
              <label>{t("Tarif FCFA")}<input type="number" min="0" step="1" value={draftAmount} onChange={e=>setDraftAmount(e.target.value)} required/></label>
              <label>{t("Description")}<textarea rows={3} value={draftDetail} onChange={e=>setDraftDetail(e.target.value)} maxLength={2000}/></label>
            </> : authSession && !preview && active==="pressing" ? <>
              <label>{t("Téléphone client")}<input value={draftPhone} onChange={e=>setDraftPhone(e.target.value)} maxLength={32}/></label>
              <label>{t("Articles déposés")}<textarea rows={3} value={draftDetail} onChange={e=>setDraftDetail(e.target.value)} required minLength={2}/></label>
              <label>{t("Montant total FCFA")}<input type="number" min="1" step="1" value={draftAmount} onChange={e=>setDraftAmount(e.target.value)} required/></label>
              <label>{t("Date promise")}<input type="datetime-local" value={draftDate} onChange={e=>setDraftDate(e.target.value)} required/></label>
              <div className="notice">{t("Aucun acompte n'est encaissé dans ce parcours de création.")}</div>
            </> : authSession && !preview && active==="agenda" ? <>
              <label>{t("Prestation (nom ou code)")}<input value={draftDetail} onChange={e=>setDraftDetail(e.target.value)} required/></label>
              <label>{t("Début")}<input type="datetime-local" value={draftDate} onChange={e=>setDraftDate(e.target.value)} required/></label>
              <label>{t("Fin")}<input type="datetime-local" value={draftEndDate} onChange={e=>setDraftEndDate(e.target.value)} required/></label>
              <div className="notice">{t("Le rendez-vous sera attribué à votre compte. Vérifiez les horaires.")}</div>
            </> : authSession && !preview && active==="cash" ? <>
              <label>{t("Motif")}<textarea rows={3} value={draftDetail} onChange={e=>setDraftDetail(e.target.value)} required minLength={2}/></label>
              <label>{t("Montant FCFA")}<input type="number" min="1" step="1" value={draftAmount} onChange={e=>setDraftAmount(e.target.value)} required/></label>
              <label>{t("Date")}<input type="datetime-local" value={draftDate} onChange={e=>setDraftDate(e.target.value)}/></label>
              <div className="notice">{t("Dépense hors caisse. Aucun paiement client ou encaissement n'est créé.")}</div>
            </> : authSession && !preview && active==="help" ? <>
              <label>{t("Description")}<textarea rows={4} value={draftDetail} onChange={e=>setDraftDetail(e.target.value)} required minLength={3}/></label>
              <label>{t("Priorité")}<select value={draftPriority} onChange={e=>setDraftPriority(e.target.value)}>{["low","normal","high","urgent"].map(v=><option key={v} value={v}>{v}</option>)}</select></label>
            </> : authSession && !preview && active==="team" ? <>
              <div className="notice">{t("Le pointage est enregistré uniquement pour le membre authentifié.")}</div>
            </> : <>
              <label>{t("Détails")}<textarea rows={3} value={draftDetail} onChange={(e) => setDraftDetail(e.target.value)} placeholder={t("Informations complémentaires")} /></label>
              <div className="notice">{t("Cette démonstration ne crée aucune opération réelle.")}</div>
            </>}
            <div className="modal-actions"><button type="button" className="btn secondary" onClick={() => setDialogOpen(false)}>{t("Annuler")}</button><button className="btn primary" disabled={busy}>{authSession&&!preview?t("Enregistrer"):t("Ajouter à la démonstration")}</button></div>
          </form>
        </div>
      </div>}
    </div></LocaleContext.Provider>
  );
}

function moduleForSyncAction(action: string): ModuleId | null {
  if(action.startsWith("inventory_item.")||action.startsWith("inventory_movement.")||action.startsWith("supplier.")||action.startsWith("purchase."))return "stock";
  if(action.startsWith("cash_register.")||action.startsWith("cash_session.")||action.startsWith("sale.")||action.startsWith("expense."))return "cash";
  if(action.startsWith("customer_followup.")||action.startsWith("loyalty_"))return "customers";
  if(action.startsWith("service."))return "services";
  if(action.startsWith("customer."))return "customers";
  if(action.startsWith("pressing_order."))return "pressing";
  if(action.startsWith("work_order.")||action.startsWith("repair_order.")||action.startsWith("service_order."))return "workOrders";
  if(action.startsWith("appointment."))return "agenda";
  if(action.startsWith("staff_"))return "team";
  if(action==="support_request.created")return "help";
  return null;
}
function changeText(payload:Record<string,unknown>,keys:string[],fallback:string):string {
  for(const key of keys)if(typeof payload[key]==="string"&&(payload[key] as string).trim())return (payload[key] as string).trim();
  return fallback;
}
function modeLabel(mode: BusinessMode) {
  if (mode === "single_site_multi_workstation") return "Responsable · plusieurs emplacements";
  if (mode === "multi_site_network") return "Promoteur · réseau multi-sites";
  return "PME autonome";
}
function iconFor(id: ModuleId) {
  const map: Record<ModuleId, string> = { overview: "⌂", agenda: "◷", pressing: "▤", workOrders: "▣", cash: "₣", services: "✦", customers: "◎", team: "♙", stock: "▥", reports: "▤", organization: "⌂", network: "⌘", sites: "▦", workstations: "▥", security: "◇", settings: "⚙", help: "?" };
  return map[id];
}
function nextPressingState(state: string) {
  if (state === "Brouillon local" || state === "Reçu") return "En cours";
  if (state === "En cours") return "Prêt";
  if (state === "Prêt") return "Retiré";
  return "Retiré";
}
function Overview({ entries, onNavigate, mode, activity, locale }: { entries: Record<ModuleId, Entry[]>; onNavigate: (id: ModuleId) => void; mode: BusinessMode; activity?:string;locale:Locale }) {
  const t=(value:string)=>translate(locale,value);
  const totalDrafts = Object.values(entries).reduce((sum, list) => sum + (list?.length ?? 0), 0);
  return <div className="overview-grid">
    <div className="overview-main">
      <div className="hero-card"><BusinessBackdrop activity={activity}/><div className="hero-content"><span className="hero-kicker">{t("VOTRE ESPACE DE GESTION")}</span><h2>{t("Une journée bien organisée commence ici.")}</h2><p>{t("Retrouvez vos activités, vos objectifs et vos priorités.")}</p></div></div>
      <div className="metric-grid">
        <Metric label={t("Rendez-vous aujourd'hui")} value="—" meta={t("En attente de confirmation")} />
        <Metric label={t("Tickets à rendre")} value="—" meta={t("En attente de confirmation")} />
        <Metric label={t("Caisse du jour")} value="—" meta={t("Aucun solde disponible")} />
        <Metric label={t("Équipe présente")} value="—" meta={t("Aucun pointage disponible")} />
      </div>
      <div className="section-title"><div><span className="eyebrow">{t("VOTRE ACTIVITÉ")}</span><h2>{t("Accès rapides")}</h2></div><span className="local-counter">{totalDrafts} opération(s) enregistrée(s)</span></div>
      <div className="shortcut-grid">
        {(["agenda", "pressing", "cash", "services"] as ModuleId[]).map((id) => {
          const item = modules.find((m) => m.id === id)!;
          return <button className="shortcut-card" key={id} onClick={() => onNavigate(id)}><span className="shortcut-icon">{iconFor(id)}</span><strong>{t(item.title)}</strong><small>{t(item.description)}</small><b>{t("Ouvrir")} <span>→</span></b></button>;
        })}
      </div>
    </div>
    <aside className="overview-side">
      <div className="side-card"><div className="section-title"><div><span className="eyebrow">{t("STRUCTURE")}</span><h3>{t("Mode d'exploitation")}</h3></div></div><strong className="mode-name">{t(modeLabel(mode))}</strong><p>{t("Les données restent isolées par organisation, site et poste selon les droits attribués.")}</p><button className="text-action" onClick={() => onNavigate("organization")}>{t("Configurer la structure")} →</button></div>
      <div className="side-card"><span className="eyebrow">{t("BRIEFING DU MATIN")}</span><h3>{t("À préparer")}</h3><ul className="brief-list"><li>{t("Vérifier les rendez-vous et les créneaux.")}</li><li>{t("Contrôler les tickets dont la date promise approche.")}</li><li>{t("Ouvrir les caisses de chaque poste autorisé.")}</li><li>{t("Consulter les alertes de consommables.")}</li></ul></div>
      <div className="side-card alert-card"><span className="eyebrow">{t("SYNCHRONISATION")}</span><h3>{t("Indicateurs à venir")}</h3><p>{t("Vos indicateurs apparaîtront dès que les données seront disponibles.")}</p></div>
    </aside>
  </div>;
}
function Metric({ label, value, meta }: { label: string; value: string; meta: string }) {
  return <div className="metric-card"><span>{label}</span><strong>{value}</strong><small>{meta}</small></div>;
}
function DeviceSecurityPage({authenticated,onLoad,onRevoke}:{authenticated:boolean;onLoad:()=>Promise<WebDevice[]>;onRevoke:(device:WebDevice)=>Promise<void>}) {
  const t=useTranslation();
  const [devices,setDevices]=useState<WebDevice[]>([]);
  const [loading,setLoading]=useState(false),[loaded,setLoaded]=useState(false);
  const [selected,setSelected]=useState<WebDevice|null>(null),[error,setError]=useState("");
  async function load(){setLoading(true);setError("");try{setDevices(await onLoad());setLoaded(true);}catch(cause){setError(cause instanceof Error?cause.message:"Lecture impossible.");}finally{setLoading(false);}}
  async function revoke(){if(!selected)return;setLoading(true);setError("");try{await onRevoke(selected);setSelected(null);setDevices(await onLoad());setLoaded(true);}catch(cause){setError(cause instanceof Error?cause.message:"Révocation impossible.");}finally{setLoading(false);}}
  return <div className="module-layout"><div className="module-main-card">
    <span className="eyebrow">{t("SÉCURITÉ DU COMPTE")}</span><h2>{t("Mes appareils et sessions")}</h2>
    <p className="muted">{t("Gérez les appareils connectés à votre compte. Un appareil retiré devra se reconnecter.")}</p>
    <button className="btn primary" disabled={!authenticated||loading} onClick={()=>void load()}>{t("Charger mes appareils")}</button>
    {error&&<div role="alert" className="notice">{error}</div>}
    {loaded&&!devices.length&&<p>{t("Aucun appareil enregistré.")}</p>}
    {devices.map(device=><div className="record" key={device.id}><div><strong>{device.label||device.platform}</strong><small>{device.platform} · {t(device.current?"Cet appareil":device.revoked_at?"Révoqué":"Actif")}</small><small>Dernière activité : {device.last_seen_at?new Date(device.last_seen_at).toLocaleString("fr-FR"):"—"}</small></div>{!device.current&&!device.revoked_at&&<button className="btn secondary" disabled={loading} onClick={()=>setSelected(device)}>{t("Révoquer")}</button>}</div>)}
    {selected&&<div className="notice"><p>Révoquer l’appareil {selected.label||selected.platform} ?</p><button className="btn secondary" disabled={loading} onClick={()=>setSelected(null)}>{t("Annuler")}</button><button className="btn primary" disabled={loading} onClick={()=>void revoke()}>{t("Confirmer la révocation")}</button></div>}
  </div><div className="module-main-card"><h2>{t("Protection des accès")}</h2><p>{t("Pour protéger votre compte, déconnectez les appareils que vous ne reconnaissez pas.")}</p></div></div>;
}
function GenericPage({ active, entries, copy, preview, authenticated }: { active: ModuleId; entries: Entry[]; copy: typeof moduleCopy[ModuleId]; preview: boolean; authenticated: boolean }) {
  const t=useTranslation();
  const serverWriteAvailable = authenticated && ["stock", "services", "customers", "team", "help"].includes(active);
  return <div className="module-layout">
    <div className="module-main-card"><div className="module-card-head"><div><span className="eyebrow">{t("VOTRE ACTIVITÉ")}</span><h2>{t("Fonctionnalités")}</h2></div><span className="status-tag pending">{t(preview?"Démonstration":serverWriteAvailable?"Disponible":"Indisponible")}</span></div>
      <div className="feature-list">{copy.features.map((feature,i)=><div className="feature-row" key={feature}><span className="feature-number">{String(i+1).padStart(2,"0")}</span><span>{t(feature)}</span><span className="feature-check">◇</span></div>)}</div>
      {!preview&&!serverWriteAvailable&&<div className="notice">{t("Cette fonctionnalité est disponible en consultation uniquement.")}</div>}
    </div>
    <div className="module-main-card"><div className="module-card-head"><div><span className="eyebrow">{t(preview?"SESSION EN COURS":"HISTORIQUE")}</span><h2>{t(preview?"Brouillons":"Opérations")}</h2></div><span className="status-tag local">{t(preview?"Local":serverWriteAvailable?"Historique":"Consultation")}</span></div>
      {entries.length===0?<Empty text={t(preview?copy.empty:serverWriteAvailable?"Aucune opération pour le moment.":"Aucun résultat disponible pour le moment.")}/>:<div className="record-list">{entries.map(entry=><Record key={entry.id} entry={entry}/>)}</div>}
    </div>
  </div>;
}
function AgendaPage({ entries, authenticated }: { entries: Entry[]; authenticated: boolean }) {
  const t=useTranslation();
  const today = new Date();
  const monday = new Date(today);
  monday.setDate(today.getDate() - ((today.getDay() + 6) % 7));
  const days = Array.from({ length: 7 }, (_, index) => {
    const date = new Date(monday);
    date.setDate(monday.getDate() + index);
    return { label: date.toLocaleDateString("fr-FR", { weekday: "short" }), day: date.getDate(), isToday: date.toDateString() === today.toDateString() };
  });
  return <div className="module-layout"><div className="module-main-card"><div className="module-card-head"><div><span className="eyebrow">{t("PLANNING")}</span><h2>{t("Vue de la semaine")}</h2></div><span className="status-tag pending">{t(authenticated?"Rendez-vous":"Démonstration")}</span></div><div className="calendar-strip">{days.map((day) => <div key={day.label} className={day.isToday ? "today" : ""}><small>{day.label}</small><strong>{String(day.day).padStart(2, "0")}</strong></div>)}</div><div className="schedule-empty"><span className="empty-glyph">◷</span><strong>{t("Aucun créneau disponible")}</strong><p>{t("Les rendez-vous créés ou reçus apparaissent dans le journal ci-dessous. La grille de disponibilité par membre et poste reste à connecter.")}</p></div></div><div className="module-main-card"><h2>{t("Rendez-vous")}</h2>{entries.length ? entries.map((e) => <Record key={e.id} entry={e} />) : <Empty text={t("Aucun rendez-vous dans le périmètre chargé.")} />}</div></div>;
}
function PressingPage({
  entries,onAdvance,onTransition,canPreviewEdit,authenticated,busy,
}:{
  entries:Entry[];onAdvance:(id:string)=>void;onTransition:(entry:Entry,nextStatus:string,reason:string)=>Promise<void>;
  canPreviewEdit:boolean;authenticated:boolean;busy:boolean;
}) {
  const t=useTranslation();
  const [reasons,setReasons]=useState<Record<string,string>>({});
  const [error,setError]=useState("");
  const nextStatus:Record<string,string>={received:"in_progress",in_progress:"ready",ready:"picked_up"};
  const statusLabels:Record<string,string>={received:"Reçu",in_progress:"En cours",ready:"Prêt",picked_up:"Retiré"};
  return <div className="module-layout">
    <div className="module-main-card">
      <div className="module-card-head"><div><span className="eyebrow">{t("SUIVI DES TICKETS")}</span><h2>{t("Étapes de traitement")}</h2></div><span className="status-tag pending">{t(canPreviewEdit?"Démonstration":authenticated?"Suivi des tickets":"Lecture seule")}</span></div>
      <div className="pressing-steps">{["Reçu","En cours","Prêt","Retiré"].map((step,i)=><div key={step}><span>{i+1}</span><strong>{t(step)}</strong></div>)}</div>
      <p className="muted">{t("Suivez les étapes de chaque ticket jusqu'au retrait.")}</p>
    </div>
    <div className="module-main-card">
      <h2>{t("Tickets")}</h2>
      {error&&<div className="notice" role="status">{t(customerMessage(error))}</div>}
      {entries.length?entries.map(entry=>{
        const status=entry.status??"received";
        const next=nextStatus[status];
        return <div className="activity-record" key={entry.id}>
          <div className="record"><div><strong>{entry.title}</strong><small>{entry.detail}</small><small>{t(confirmedActivityRevision(entry)?"Confirmé":entry.state)}</small></div><span className="status-tag local">{t(statusLabels[status]??entry.state)}</span></div>
          {canPreviewEdit&&<button className="btn secondary" onClick={()=>onAdvance(entry.id)} disabled={status==="picked_up"}>{t("Avancer l'aperçu")}</button>}
          {authenticated&&next&&entry.recordType==="pressing_order"&&entry.siteId&&confirmedActivityRevision(entry)?<div className="activity-transition">
            <label>{t("Motif du changement d'étape")}<input value={reasons[entry.id]??""} onChange={e=>setReasons(previous=>({...previous,[entry.id]:e.target.value}))} minLength={3} maxLength={500}/></label>
            <button className="btn secondary" disabled={busy||(reasons[entry.id]??"").trim().length<3} onClick={()=>void onTransition(entry,next,reasons[entry.id]??"").then(
              ()=>setReasons(previous=>({...previous,[entry.id]:""})),
              cause=>setError(cause instanceof Error?cause.message:"Transition refusée.")
            )}>{busy?"Envoi…":"Passer à "+statusLabels[next]}</button>
          </div>:authenticated&&next&&<p className="muted">{t("Patientez jusqu'à la confirmation du ticket.")}</p>}
        </div>;
      }):<Empty text={t("Aucun ticket disponible pour cet établissement.")}/>}
    </div>
  </div>;
}

function WorkOrdersPage({
  workflow, entries, authenticated, busy, siteName, onCreate, onTransition,
}: {
  workflow: ReturnType<typeof getActivityWorkflow>;
  entries: Entry[];
  authenticated: boolean;
  busy: boolean;
  siteName: string;
  onCreate: (input:{customer:string;title:string;amountXaf:number;dueDate:string;fields:Record<string,string>})=>Promise<void>;
  onTransition: (entry:Entry,nextStatus:string,reason:string)=>Promise<void>;
}) {
  const t=useTranslation();
  const [customer,setCustomer]=useState("");
  const [title,setTitle]=useState("");
  const [amount,setAmount]=useState("0");
  const [dueDate,setDueDate]=useState("");
  const [fields,setFields]=useState<Record<string,string>>({});
  const [reasonByEntry,setReasonByEntry]=useState<Record<string,string>>({});
  const [saving,setSaving]=useState(false);
  const [transitioning,setTransitioning]=useState("");
  const [error,setError]=useState("");
  const isRetail = workflow.journey === "retail";
  async function create(event:React.FormEvent) {
    event.preventDefault();setSaving(true);setError("");
    try {
      const missing=validateActivityFields(workflow.profile,fields);
      if(missing.length)throw new Error("Renseigne les champs obligatoires : "+missing.join(", "));
      await onCreate({customer,title,amountXaf:Number(amount),dueDate,fields});
      setCustomer("");setTitle("");setAmount("0");setDueDate("");setFields({});
    } catch(cause) { setError(cause instanceof Error?cause.message:"Création du dossier refusée."); }
    finally { setSaving(false); }
  }
  async function transition(entry:Entry,next:string) {
    setTransitioning(entry.id);setError("");
    try {
      await onTransition(entry,next,reasonByEntry[entry.id]??"");
      setReasonByEntry(previous=>({...previous,[entry.id]:""}));
    } catch(cause) { setError(cause instanceof Error?cause.message:"Transition refusée."); }
    finally { setTransitioning(""); }
  }
  return <div className="module-layout activity-work-layout">
    <div className="module-main-card">
      <div className="module-card-head"><div><span className="eyebrow">PARCOURS MÉTIER · {workflow.profile.toUpperCase()}</span><h2>{workflow.label}</h2></div><span className="status-tag pending">{authenticated?"Gestion des dossiers":"Lecture seule"}</span></div>
      <p className="muted">{workflow.purpose}</p>
      {isRetail && <div className="notice">Le flux principal de parfumerie reste le catalogue produit, le stock, les achats fournisseurs et la vente comptoir. Ce formulaire crée uniquement une réservation ou commande spéciale client ; il ne réalise pas une vente.</div>}
      <div className="feature-list">{workflow.stages.map((stage,index)=><div className="feature-row" key={stage.code}><span className="feature-number">{String(index+1).padStart(2,"0")}</span><span>{stage.label}</span><span className="feature-check">{stage.next.length? "→ "+stage.next.map(code=>workflow.stages.find(item=>item.code===code)?.label??code).join(" / "):"Terminé"}</span></div>)}</div>
      <p className="muted">Services associés : {workflow.sharedModules.join(" · ")}.</p>
    </div>
    <div className="module-main-card">
      <div className="module-card-head"><div><span className="eyebrow">{t("NOUVEAU DOSSIER")}</span><h2>{t("Créer une opération métier")}</h2></div><span className="status-tag local">{siteName}</span></div>
      {authenticated ? <form onSubmit={create}>
        <label>{t("Client / donneur d'ordre")}<input value={customer} onChange={e=>setCustomer(e.target.value)} minLength={2} maxLength={180} required /></label>
        <label>{t("Intitulé du dossier")}<input value={title} onChange={e=>setTitle(e.target.value)} minLength={2} maxLength={180} required /></label>
        {workflow.fields.map(field=>{
          const value=fields[field.key]??"";
          const update=(nextValue:string)=>setFields(previous=>({...previous,[field.key]:nextValue}));
          const kind=field.kind??"text";
          return <label key={field.key} data-activity-field={field.key}>{field.label}{field.required?" *":""}
            {kind==="textarea"
              ? <textarea value={value} onChange={e=>update(e.target.value)} maxLength={field.maxLength??1200} rows={3} required={field.required}/>
              : kind==="select"
                ? <select value={value} onChange={e=>update(e.target.value)} required={field.required}>
                    <option value="">{t("Sélectionner…")}</option>
                    {(field.options??[]).map(option=><option key={option.value} value={option.value}>{option.label}</option>)}
                  </select>
                : <input
                    type={kind==="date"?"date":kind==="number"?"number":"text"}
                    value={value}
                    onChange={e=>update(e.target.value)}
                    maxLength={kind==="text"?(field.maxLength??500):undefined}
                    min={field.min}
                    max={field.max}
                    step={kind==="number"?1:undefined}
                    required={field.required}
                  />}
            {field.help&&<small className="muted">{field.help}</small>}
          </label>;
        })}
        <label>{t("Montant estimatif (FCFA)")}<input type="number" min="0" step="1" value={amount} onChange={e=>setAmount(e.target.value)} required /></label>
        <label>{t("Date d'échéance globale (facultatif)")}<input type="date" value={dueDate} onChange={e=>setDueDate(e.target.value)} /></label>
        <button className="btn primary" disabled={saving||busy}>{saving||busy?"Enregistrement…":"Créer et synchroniser le dossier"}</button>
      </form> : <div className="notice">{t("Connectez-vous pour créer un dossier.")}</div>}
      {error&&<div className="notice" role="status">{t(customerMessage(error))}</div>}
    </div>
    <div className="module-main-card activity-record-list">
      <div className="module-card-head"><div><span className="eyebrow">{t("REGISTRE DU SITE")}</span><h2>{t("Dossiers enregistrés")}</h2></div><span className="status-tag local">{entries.length}</span></div>
      {entries.length===0?<Empty text={t("Aucun dossier métier reçu pour ce site et cet appareil.")}/>:entries.map(entry=>{
        const entryProfile=entry.activityProfile??workflow.profile;
        const entryWorkflow=getActivityWorkflow(entryProfile);
        const status=entry.status??"received";
        const stage=getActivityStage(entryProfile,status);
        const next=stage?.next??[];
        const detailRows=Object.entries(entry.metadata??{}).filter(([,value])=>Boolean(value));
        return <div className="activity-record" key={entry.id} data-record-id={entry.id}>
          <div className="record"><div><strong>{entry.title}</strong><small>{entry.detail||entry.createdAt}</small><small data-testid="record-confirmation" data-version={confirmedActivityRevision(entry)?entry.revision:0}>{t(confirmedActivityRevision(entry)?"Confirmé":entry.state)}</small></div><span className="status-tag local">{stage?.label??entry.state}</span></div>
          {detailRows.length>0&&<ul className="brief-list">{detailRows.map(([key,value])=><li key={key}>{key} : {value}</li>)}</ul>}
          {authenticated&&next.length>0&&confirmedActivityRevision(entry)&&entry.siteId&&<div className="activity-transition">
            <label>{t("Motif du changement d'étape")}<input value={reasonByEntry[entry.id]??""} onChange={e=>setReasonByEntry(previous=>({...previous,[entry.id]:e.target.value}))} minLength={3} maxLength={500} /></label>
            <div className="activity-transition-buttons">{next.map(code=><button className="btn secondary" key={code} disabled={busy||transitioning===entry.id||(reasonByEntry[entry.id]??"").trim().length<3} onClick={()=>void transition(entry,code)}>{transitioning===entry.id?"Envoi…":entryWorkflow.stages.find(item=>item.code===code)?.label??code}</button>)}</div>
          </div>}
        </div>;
      })}
    </div>
  </div>;
}

function CashPage({ entries }: { entries: Entry[] }) {
  const t=useTranslation();
  return <div className="module-layout"><div className="module-main-card"><div className="module-card-head"><div><span className="eyebrow">{t("TRÉSORERIE")}</span><h2>{t("Sessions de caisse")}</h2></div><span className="status-tag pending">{t("Dépenses")}</span></div><div className="cash-summary"><div><small>{t("Fonds d'ouverture")}</small><strong>—</strong></div><div><small>{t("Encaissements confirmés")}</small><strong>—</strong></div><div><small>{t("Écart de clôture")}</small><strong>—</strong></div></div><div className="notice">{t("Ce formulaire enregistre une dépense, pas une vente ni un paiement client. Les ouvertures/clôtures, encaissements et reçus ne sont pas encore raccordés à cette vue.")}</div></div><div className="module-main-card"><h2>{t("Dépenses du journal serveur")}</h2>{entries.length ? entries.map((e) => <Record key={e.id} entry={e} />) : <Empty text={t("Aucune dépense dans le périmètre chargé.")} />}</div></div>;
}
function PerformancePage({
  data, fromDate, setFromDate, loading, error, onLoad, authenticated, locale,
}: {
  data: {daily:Record<string,unknown>[];monthly:Record<string,unknown>[];annual:Record<string,unknown>[]} | null;
  fromDate:string;setFromDate:(value:string)=>void;loading:boolean;error:string;onLoad:()=>void;authenticated:boolean;locale:Locale;
}) {
  const t=useTranslation();
  const [exportError,setExportError]=useState(false);
  const tr=(fr:string,en:string,ff:string)=>locale==="en"?en:locale==="ff-CM"?ff:fr;
  function exportReport(format:"xlsx"|"pdf"){
    if(!authenticated||loading||!data)return;setExportError(false);
    try{const report=financialRows(data,[t("Journalier"),t("Mensuel"),t("Annuel")],[tr("Type de période","Period type","Fannu sahaa"),t("Période"),t("Recettes confirmées")+" (FCFA)",t("Coût connu")+" (FCFA)",t("Marge brute")+" (FCFA)",t("Ventes confirmées"),t("Coût manquant")]);if(format==="xlsx")downloadFinancialXlsx(report);else printFinancialReport(report,t("Performances financières confirmées"));}
    catch{setExportError(true);}
  }
  const fmt=(value:unknown)=>typeof value==="number"?new Intl.NumberFormat("fr-FR").format(value)+" FCFA":value==null?"—":String(value);
  const rows=(values:Record<string,unknown>[],key:string)=>values.length===0?<Empty text={t("Aucune donnée disponible pour cette période.")}/>:
    <div style={{overflowX:"auto"}}><table className="data-table"><thead><tr><th>{t("Période")}</th><th>{t("Recettes confirmées")}</th><th>{t("Coût connu")}</th><th>{t("Marge brute")}</th><th>{t("Ventes confirmées")}</th><th>{t("Coût manquant")}</th></tr></thead><tbody>
      {values.map((row,index)=><tr key={String(row[key]??index)}><td>{String(row[key]??"—")}</td><td>{fmt(row.revenue_xaf)}</td><td>{fmt(row.cost_of_goods_xaf??row.known_cost_of_goods_xaf)}</td><td>{fmt(row.gross_profit_xaf)}</td><td>{row.confirmed_sales_count==null?"—":String(row.confirmed_sales_count)}</td><td>{row.uncosted_sales_count==null?"—":String(row.uncosted_sales_count)}</td></tr>)}
    </tbody></table></div>;
  return <div className="module-layout">
    <div className="module-main-card"><div className="module-card-head"><div><span className="eyebrow">{t("ANALYSE FINANCIÈRE")}</span><h2>{t("Performances financières confirmées")}</h2></div><span className="status-tag pending">{t(data?"Données confirmées":"À charger")}</span></div>
      {authenticated?<><label>{t("À partir du")}<input type="date" value={fromDate} onChange={e=>setFromDate(e.target.value)} max={new Intl.DateTimeFormat("en-CA",{timeZone:"Africa/Douala",year:"numeric",month:"2-digit",day:"2-digit"}).format(new Date())}/></label><button className="btn primary" disabled={loading} onClick={onLoad}>{t(loading?"Chargement…":"Charger les rapports")}</button></>:<div className="notice">{t("Connectez-vous pour consulter vos rapports.")}</div>}
      {error&&<div className="notice" role="status">{t(customerMessage(error))}</div>}
      <p className="muted">{t("Les indicateurs tiennent compte des ventes confirmées.")}</p>
      {authenticated&&data&&<><button className="btn secondary" disabled={loading} onClick={()=>exportReport("xlsx")}>{tr("Exporter Excel","Export Excel","Yaltin Excel")}</button><button className="btn secondary" disabled={loading} onClick={()=>exportReport("pdf")}>{tr("Imprimer / enregistrer en PDF","Print / save as PDF","Winndit / danndu PDF")}</button></>}
      {exportError&&<p role="alert">{tr("Export indisponible. Réessayez.","Export unavailable. Try again.","Yaltinol heɓotaako. Eto kadi.")}</p>}
    </div>
    <div className="module-main-card"><h2>{t("Journalier")}</h2>{rows(data?.daily??[],"performance_day")}</div>
    <div className="module-main-card"><h2>{t("Mensuel")}</h2>{rows(data?.monthly??[],"performance_month")}</div>
    <div className="module-main-card"><h2>{t("Annuel")}</h2>{rows(data?.annual??[],"performance_year")}</div>
  </div>;
}
function OrganizationPage({
  mode, setMode, siteName, setSiteName, editable, onSave, locale,
}: {
  mode: BusinessMode; setMode: (mode: BusinessMode) => void; siteName: string; setSiteName: (s: string) => void;
  editable: boolean; onSave: (name: string, mode: BusinessMode, locale: "fr" | "en" | "ff-CM") => Promise<void>;
  locale: "fr" | "en" | "ff-CM";
}) {
  const t=useTranslation();
  const [selectedLocale, setSelectedLocale] = useState<"fr" | "en" | "ff-CM">(locale);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  async function save() {
    setSaving(true); setError("");
    try { await onSave(siteName.trim(), mode, selectedLocale); }
    catch (cause) { setError(cause instanceof Error ? cause.message : "Impossible d’enregistrer vos modifications."); }
    finally { setSaving(false); }
  }
  return <div className="structure-grid">
    <div className="module-main-card">
      <span className="eyebrow">{t("ORGANISATION")}</span><h2>{t("Modèle d'exploitation")}</h2>
      <div className="mode-options">
        <button disabled={!editable || saving} className={mode==="solo"?"mode-option selected":"mode-option"} onClick={()=>setMode("solo")}><b>{t("01 · PME autonome")}</b><strong>{t("Un établissement indépendant")}</strong><small>{t("Un point de vente, une organisation et ses opérations.")}</small></button>
        <button disabled={!editable || saving} className={mode==="single_site_multi_workstation"?"mode-option selected":"mode-option"} onClick={()=>setMode("single_site_multi_workstation")}><b>{t("02 · Responsable multi-emplacements")}</b><strong>{t("Plusieurs postes dans un même lieu")}</strong><small>{t("Plusieurs ressources dans un point de vente.")}</small></button>
        <button disabled={!editable || saving} className={mode==="multi_site_network"?"mode-option selected":"mode-option"} onClick={()=>setMode("multi_site_network")}><b>{t("03 · Promoteur multi-sites")}</b><strong>{t("Plusieurs points de vente autonomes")}</strong><small>{t("Consolidation réseau, opérations isolées.")}</small></button>
      </div>
    </div>
    <div className="module-main-card">
      <span className="eyebrow">{t("PROFIL DE L'ORGANISATION")}</span><h2>{t("Identité & langue")}</h2>
      <label>{t("Nom de l'organisation")}<input disabled={!editable || saving} value={siteName} onChange={e=>setSiteName(e.target.value)} /></label>
      <label>{t("Langue par défaut")}<select disabled={!editable || saving} value={selectedLocale} onChange={e=>setSelectedLocale(e.target.value as "fr"|"en"|"ff-CM")}><option value="fr">Français</option><option value="en">English</option><option value="ff-CM">Fulfulde</option></select></label>
      {editable && !saving && <button className="btn primary" onClick={()=>void save()}>{t("Enregistrer le profil")}</button>}
      {saving && <div className="notice">{t("Enregistrement en cours…")}</div>}
      {error && <div className="notice" role="status">{t(customerMessage(error))}</div>}
      {!editable && <div className="notice">{t("Lecture seule : seul le Promoteur ayant le périmètre Organisation peut enregistrer ces réglages.")}</div>}
    </div>
  </div>;
}

function SitesPage({
  mode, siteName, sites, canCreate, onCreateSite, entries,
}: {
  mode: BusinessMode; siteName: string; sites: {id:string;code:string;name:string;address_label:string;phone_contact:string}[];
  canCreate: boolean; onCreateSite: (site:{code:string;name:string;address_label:string;phone_contact:string})=>Promise<unknown>; entries: Entry[];
}) {
  const t=useTranslation();
  const [code,setCode]=useState(""); const [name,setName]=useState(""); const [address,setAddress]=useState(""); const [phone,setPhone]=useState("");
  const [saving,setSaving]=useState(false); const [error,setError]=useState("");
  async function submit(e:React.FormEvent) {
    e.preventDefault();setSaving(true);setError("");
    try { await onCreateSite({code,name,address_label:address,phone_contact:phone});setCode("");setName("");setAddress("");setPhone(""); }
    catch(cause){setError(cause instanceof Error?cause.message:"Création impossible.");}
    finally{setSaving(false);}
  }
  return <div className="module-layout">
    <div className="module-main-card"><span className="eyebrow">{t("PÉRIMÈTRE RÉSEAU")}</span><h2>{t("Points de vente sous contrôle")}</h2>
      <div className="site-list">
        {sites.length ? sites.map(site=><div className="site-row" key={site.id}><span className="site-dot"/><div><strong>{site.name||site.code}</strong><small>{site.code} · {site.address_label||"Adresse non renseignée"}</small></div><span className="status-tag local">{t("Autorisé")}</span></div>)
          : <Empty text={t("Aucun établissement accessible pour le moment.")}/>}
      </div>
      <p className="muted">Organisation : {siteName}. Mode : {t(modeLabel(mode))}. Retrouvez les établissements auxquels vous avez accès.</p>
    </div>
    <div className="module-main-card"><h2>{t("Créer un point de vente")}</h2>
      {mode!=="multi_site_network" && <div className="notice">{t("Le modèle multi-sites doit d'abord être activé par le Promoteur dans le profil d'organisation.")}</div>}
      {canCreate && mode==="multi_site_network" ? <form onSubmit={submit}>
        <label>{t("Code du site")}<input value={code} onChange={e=>setCode(e.target.value.toUpperCase())} required minLength={2} maxLength={20}/></label>
        <label>{t("Nom du site")}<input value={name} onChange={e=>setName(e.target.value)} required maxLength={120}/></label>
        <label>{t("Adresse / repère")}<input value={address} onChange={e=>setAddress(e.target.value)} maxLength={200}/></label>
        <label>{t("Téléphone")}<input value={phone} onChange={e=>setPhone(e.target.value)} maxLength={32}/></label>
        <button className="btn primary" disabled={saving}>{t("Créer le point de vente")}</button>
      </form> : <div className="notice">{t("La création requiert le rôle Promoteur, le périmètre Organisation et le mode multi-sites.")}</div>}
      {error&&<div className="notice" role="status">{t(customerMessage(error))}</div>}
      <h3>{t("Principes d'autonomie")}</h3><ul className="brief-list"><li>{t("Caisse et clôture propres à chaque site.")}</li><li>{t("Stock et historique distincts.")}</li><li>{t("Équipe et affectations séparées.")}</li><li>{t("Vue d’ensemble du réseau et gestion indépendante de chaque établissement.")}</li></ul>
      {entries.map(e=><Record key={e.id} entry={e}/>)}
    </div>
  </div>;
}

function WorkstationsPage({
  mode, sites, selectedSiteId, workstations, onLoad, onCreate, canCreate,
}: {
  mode:BusinessMode; sites:{id:string;code:string;name:string}[]; selectedSiteId:string; workstations:WebWorkstation[];
  onLoad:(siteId:string)=>Promise<unknown>; onCreate:(input:{site_id:string;code:string;name:string;kind:string;capacity:number})=>Promise<unknown>;
  canCreate:boolean;
}) {
  const t=useTranslation();
  const [siteId,setSiteId]=useState(selectedSiteId||sites[0]?.id||"");
  const [code,setCode]=useState("");const [name,setName]=useState("");const [kind,setKind]=useState("other");const [capacity,setCapacity]=useState("1");
  const [loading,setLoading]=useState(false);const [saving,setSaving]=useState(false);const [error,setError]=useState("");
  async function load(){if(!siteId){setError("Choisis un site autorisé.");return;}setLoading(true);setError("");try{await onLoad(siteId);}catch(cause){setError(cause instanceof Error?cause.message:"Lecture des postes refusée.");}finally{setLoading(false);}}
  async function create(e:React.FormEvent){e.preventDefault();setSaving(true);setError("");try{await onCreate({site_id:siteId,code,name,kind,capacity:Number(capacity)});setCode("");setName("");setCapacity("1");}catch(cause){setError(cause instanceof Error?cause.message:"Création du poste refusée.");}finally{setSaving(false);}}
  return <div className="module-layout">
    <div className="module-main-card"><span className="eyebrow">{t("POSTES & RESSOURCES")}</span><h2>{t("Emplacements d'un même établissement")}</h2>
      <label>{t("Point de vente")}<select value={siteId} onChange={e=>setSiteId(e.target.value)}>{sites.map(site=><option key={site.id} value={site.id}>{site.name||site.code}</option>)}</select></label>
      <button className="btn secondary" disabled={loading||!siteId} onClick={()=>void load()}>{t(loading?"Chargement…":"Afficher les postes")}</button>
      <div className="workstation-grid">{workstations.filter(item=>item.site_id===siteId).map((item,i)=><div className="workstation-card" key={item.id}><span>{String(i+1).padStart(2,"0")}</span><strong>{item.name}</strong><small>{item.code} · {item.kind} · capacité {item.capacity}</small></div>)}</div>
      {!workstations.some(item=>item.site_id===siteId)&&<Empty text={t("Aucun emplacement chargé pour ce point de vente.")}/>}
    </div>
    <div className="module-main-card"><h2>{t("Créer un emplacement")}</h2>
      {canCreate&&siteId?<form onSubmit={create}>
        <label>{t("Code")}<input value={code} onChange={e=>setCode(e.target.value.toUpperCase())} required minLength={2} maxLength={20}/></label>
        <label>{t("Nom")}<input value={name} onChange={e=>setName(e.target.value)} required maxLength={120}/></label>
        <label>{t("Type")}<select value={kind} onChange={e=>setKind(e.target.value)}>{["hair_chair","pressing_counter","pressing_workshop","reception","cashier","other"].map(value=><option key={value} value={value}>{value}</option>)}</select></label>
        <label>{t("Capacité")}<input type="number" min="1" max="100" step="1" value={capacity} onChange={e=>setCapacity(e.target.value)}/></label>
        <button className="btn primary" disabled={saving}>{t("Créer le poste")}</button>
      </form>:<div className="notice">{t("Seuls les responsables autorisés peuvent créer un poste dans cet établissement.")}</div>}
      <p className="muted">Mode : {t(modeLabel(mode))}. Les droits d'un poste ne sont pas élargis au site entier.</p>
      {error&&<div className="notice" role="status">{t(customerMessage(error))}</div>}
    </div>
  </div>;
}
function Empty({ text }: { text: string }) {
  const t=useTranslation(); return <div className="empty-state"><span className="empty-glyph">◌</span><strong>{t("Tout est prêt pour commencer")}</strong><p>{t(text)}</p></div>; }
function Record({ entry }: { entry: Entry }) {
  const t=useTranslation(); return <div className="record"><div><strong>{entry.title}</strong><small>{entry.detail || entry.createdAt}</small></div><span className="status-tag local">{t(entry.state)}</span></div>; }

createRoot(document.getElementById("root")!).render(<React.StrictMode><App /></React.StrictMode>);
