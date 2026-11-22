import React, { useEffect, useMemo, useState } from "react";
import { enqueue as enqueueOfflineEvent, acquireDueBatch, applyServerReceipt, scheduleRetry, listQueued, listAppEvents, applySyncPage, getSyncCursor, listSyncChanges, type WebSyncChange } from "@famille/offline-web";
import { normalizeInventoryItemDraft } from "./erp/inventory";
import { parseWebSession, type WebAuthSession } from "./auth/session";
import { createRoot } from "react-dom/client";
import "@famille/design-system/tokens.css";
import "./naxa-services.css";

type ModuleId =
  | "overview" | "agenda" | "pressing" | "cash" | "services" | "customers"
  | "team" | "stock" | "reports" | "organization" | "network" | "sites"
  | "workstations" | "security" | "settings" | "help";

type BusinessMode = "solo" | "single_site_multi_workstation" | "multi_site_network";
const OFFLINE_APP_ID = "naxa-services-web";
type Entry = { id: string; title: string; detail: string; state: string; createdAt: string };
type WebWorkstation = { id: string; site_id: string; code: string; name: string; kind: string; capacity: number; status: string };

const modules: { id: ModuleId; title: string; description: string; group: string; action: string }[] = [
  { id: "overview", title: "Vue d'ensemble", description: "Activité, alertes et briefings de l'établissement.", group: "Pilotage", action: "Actualiser la vue" },
  { id: "agenda", title: "Agenda & rendez-vous", description: "Créneaux par prestataire, poste, date et point de vente.", group: "Opérations", action: "Nouveau rendez-vous" },
  { id: "pressing", title: "Pressing", description: "Tickets, pièces, étapes de traitement et retraits.", group: "Opérations", action: "Créer un ticket" },
  { id: "cash", title: "Caisse & ventes", description: "Ventes, paiements, reçus, dépenses et clôtures.", group: "Finance", action: "Nouvelle vente" },
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
  overview: { eyebrow: "PILOTAGE", headline: "Votre activité, au même endroit.", helper: "Les indicateurs apparaîtront dès qu'un compte et des données métier auront été synchronisés.", empty: "Aucune opération synchronisée pour le moment.", features: ["Rendez-vous du jour", "Tickets pressing à rendre", "Situation de caisse", "Briefing du matin / soir"] },
  agenda: { eyebrow: "PLANNING", headline: "Un planning lisible par poste et prestataire.", helper: "Les contrôles de chevauchement doivent être appliqués côté serveur avant confirmation.", empty: "Aucun rendez-vous dans cette vue.", features: ["Vues jour et semaine", "Disponibilité du prestataire", "Disponibilité du fauteuil / poste", "Acompte, annulation et liste d'attente"] },
  pressing: { eyebrow: "ATELIER", headline: "Chaque dépôt possède son ticket et son historique.", helper: "Les transitions de statut sont chronologiques et contrôlées.", empty: "Aucun ticket pressing dans la liste locale.", features: ["Pièces et prix par catégorie", "Date promise et acompte", "Reçu → En cours → Prêt → Retiré", "Relance des vêtements non retirés"] },
  cash: { eyebrow: "ENCAISSEMENTS", headline: "Une caisse traçable, par point de vente.", helper: "Une vente locale de prévisualisation ne constitue pas une preuve de paiement.", empty: "Aucune vente enregistrée dans la session de prévisualisation.", features: ["Espèces et Mobile Money confirmé", "Paiement mixte et reçu", "Ouverture et clôture de caisse", "Dépenses, écarts et justificatifs"] },
  services: { eyebrow: "CATALOGUE", headline: "Des prestations adaptées à chaque activité.", helper: "Les tarifs effectifs doivent être versionnés et associés au point de vente.", empty: "Le catalogue n'a pas encore été synchronisé.", features: ["Pressing et coiffure distincts", "Durée et prix par prestation", "Habilitations par employé et poste", "Forfaits et produits comptoir"] },
  customers: { eyebrow: "RELATION CLIENT", headline: "Connaître l'historique, respecter les préférences.", helper: "Les coordonnées et notes client sont privées et restent sous le scope autorisé.", empty: "Aucune fiche client disponible.", features: ["Historique des prestations", "Préférences et dernières visites", "Consentement de contact", "Fidélité, QR et anniversaires"] },
  team: { eyebrow: "ÉQUIPE", headline: "Des comptes individuels et des droits précis.", helper: "Chaque membre possède son propre accès ; les comptes partagés sont exclus.", empty: "Aucun membre opérationnel chargé.", features: ["Rôles et permissions", "Affectation site / emplacement", "Présence, avances et primes", "Commissions calculées selon une règle datée"] },
  stock: { eyebrow: "CONSOMMABLES", headline: "Un stock léger centré sur l'exploitation.", helper: "Les mouvements doivent être append-only et rattachés au site.", empty: "Aucun consommable suivi pour le moment.", features: ["Lessive et produits coiffure", "Entrées et consommation", "Pertes et ajustements motivés", "Alertes de seuil"] },
  reports: { eyebrow: "ANALYTIQUE", headline: "Piloter les résultats, pas seulement les ventes.", helper: "Le détail du réseau n'est consultable que par les rôles autorisés.", empty: "Les rapports seront calculés à partir des données synchronisées.", features: ["Recettes et dépenses", "Écarts de caisse", "Rentabilité des prestations", "Remplissage agenda et commissions"] },
  organization: { eyebrow: "STRUCTURE", headline: "Votre organisation détermine les scopes.", helper: "Le mode sélectionné configure les niveaux d'exploitation ; il ne crée pas plusieurs applications.", empty: "Le profil juridique et commercial n'est pas encore paramétré.", features: ["PME autonome", "Responsable multi-emplacements dans un site", "Promoteur multi-sites autonomes", "Rôles et entitlements indépendants"] },
  network: { eyebrow: "RÉSEAU", headline: "Consolider sans mélanger les opérations.", helper: "Chaque point de vente garde ses propres caisses, stocks, équipes et tickets.", empty: "Aucun autre point de vente rattaché à cette organisation.", features: ["Vue consolidée du réseau", "Accès détaillé selon délégation", "Comparaison des sites", "Transferts inter-sites avec validation et audit"] },
  sites: { eyebrow: "POINTS DE VENTE", headline: "Chaque site fonctionne de façon autonome.", helper: "Les opérations d'un point ne sont jamais réaffectées implicitement à un autre.", empty: "Aucun point de vente supplémentaire.", features: ["Responsable et équipe du site", "Caisse et sessions propres", "Stock et consommables propres", "Catalogue et paramètres effectifs"] },
  workstations: { eyebrow: "EMPLACEMENTS", headline: "Organiser plusieurs postes dans le même lieu.", helper: "Les emplacements sont des unités de planning et de ressources à l'intérieur d'un point de vente.", empty: "Aucun emplacement configuré.", features: ["Fauteuils de coiffure", "Atelier / comptoir pressing", "Planning et capacité", "Affectation des prestataires"] },
  security: { eyebrow: "PROTECTION", headline: "Maîtriser les sessions et les appareils.", helper: "La récupération est administrée après une vérification hors bande ; aucun OTP ni e-mail.", empty: "Aucun événement disponible dans l'aperçu local.", features: ["Sessions et appareils enrôlés", "Révocation à distance", "Demandes de récupération", "Audit des opérations privilégiées"] },
  settings: { eyebrow: "CONFIGURATION", headline: "Un environnement adapté à l'équipe.", helper: "Les réglages système et les préférences métier sont séparés des permissions.", empty: "Les paramètres de production ne sont pas connectés.", features: ["Français et English", "Thème sombre / clair", "Mode offline et reprise de synchronisation", "Imprimantes et notifications"] },
  help: { eyebrow: "ASSISTANCE", headline: "Faire remonter les blocages avec contexte.", helper: "Les demandes de support ne doivent contenir aucun mot de passe, PIN ou jeton.", empty: "Aucune demande de support dans cette session.", features: ["FAQ et guides", "Demande d'assistance", "Briefing du matin", "Briefing du soir"] },
};

function App() {
  const [authenticated, setAuthenticated] = useState(false);
  const [authSession, setAuthSession] = useState<WebAuthSession | null>(null);
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
  const [theme, setTheme] = useState<"dark" | "light">("dark");
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

  const selected = modules.find((m) => m.id === active)!;
  const grouped = useMemo(() => {
    const groups = new Map<string, typeof modules>();
    modules.forEach((m) => groups.set(m.group, [...(groups.get(m.group) ?? []), m]));
    return Array.from(groups.entries());
  }, []);

  const env = (import.meta as unknown as { env?: Record<string, string> }).env ?? {};
  const authEndpoint = env.VITE_NAXA_SERVICES_AUTH_URL ?? "";
  const accountingEndpoint = env.VITE_NAXA_SERVICES_ACCOUNTING_URL ?? authEndpoint.replace(/naxa-services-auth(?=\/?$)/, "naxa-services-accounting");
  const anonKey = env.VITE_SUPABASE_ANON_KEY ?? "";

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

  async function hydrateWebRecords(activeSession: WebAuthSession) {
    const [allEvents,pending]=await Promise.all([listAppEvents(OFFLINE_APP_ID,activeSession.deviceId),listQueued(OFFLINE_APP_ID)]);
    setPendingSyncCount(pending.length);
    setEntries(previous=>{
      const next={...previous};
      for(const item of allEvents){
        let command:Record<string,unknown>={};
        try{command=JSON.parse(item.payload) as Record<string,unknown>;}catch{continue;}
        const moduleId=typeof command.module_id==="string"?command.module_id as ModuleId:"stock";
        if(!modules.some(module=>module.id===moduleId))continue;
        const id=typeof command.aggregate_id==="string"?command.aggregate_id:item.eventId;
        const title=typeof command.display_title==="string"?command.display_title:id;
        const detail=typeof command.display_detail==="string"?command.display_detail:"";
        const state=item.state==="acknowledged"?"Confirmé par le serveur":item.state==="rejected"?"Rejeté — vérifier le dossier":item.state==="conflict"?"Conflit — résolution nécessaire":"En attente de synchronisation";
        const rows=next[moduleId]??[],existing=rows.findIndex(entry=>entry.id===id);
        const record:Entry={id,title,detail,state,createdAt:new Date(item.createdAt).toLocaleString("fr-FR")};
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
      setAuthSession(nextSession);
      setActiveSiteId(nextSession.account.active_site_ids[0] ?? "");
      setMode(nextSession.account.business_mode ?? "solo");
      setSiteName(nextSession.account.organization_name || nextSession.account.active_sites[0]?.name || "Point de vente principal");
      setWorkstationSiteId(nextSession.account.active_site_ids[0] ?? "");
      void hydrateWebRecords(nextSession).catch((error)=>setAuthMessage(error instanceof Error?error.message:"Historique local indisponible."));
      setAuthenticated(true);
      void syncWebPullChanges(nextSession).then((result) => { if(result.morePending)setAuthMessage("Synchronisation entrante partielle : d'autres pages restent à charger."); }).catch((error) => setAuthMessage(error instanceof Error?error.message:"Lecture du journal serveur impossible."));
      setPreview(false);
      setPassword("");
      setAuthMessage(nextSession.requirePasswordChange
        ? "Connexion réussie. Le mot de passe initial doit être remplacé avant les opérations."
        : "Session authentifiée. Les modules métier Web restent en brouillons locaux tant que leurs connecteurs ERP ne sont pas raccordés.");
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
    const data = await authRequest({
      action: "refresh",
      refresh_token: activeSession.refreshToken,
      remember_device: false,
      device: webDevicePayload(),
    }, anonKey);
    const refreshed = parseWebSession(data);
    setAuthSession(refreshed);
    return refreshed;
  }

  async function ensureFreshSession(activeSession: WebAuthSession): Promise<WebAuthSession> {
    if (activeSession.expiresAt > Date.now() + 60_000) return activeSession;
    return await refreshWebSession(activeSession);
  }

  async function saveWebOrganizationProfile(displayName: string, businessMode: BusinessMode, locale: "fr" | "en" | "ff-CM") {
    if (!authSession) throw new Error("AUTHENTICATION_REQUIRED");
    const fresh = await ensureFreshSession(authSession);
    const data = await authRequest({
      action: "update_organization_profile",
      display_name: displayName,
      business_mode: businessMode,
      default_locale: locale,
    }, fresh.accessToken);
    if (data.saved !== true) throw new Error("ORGANIZATION_PROFILE_NOT_SAVED");
    const account = { ...fresh.account, organization_name: displayName, business_mode: businessMode, default_locale: locale };
    const updated = { ...fresh, account };
    setAuthSession(updated);
    setMode(businessMode);
    setSiteName(displayName);
    setAuthMessage("Profil d'organisation enregistré par Auth et journalisé côté serveur.");
  }

  async function createWebSite(input: { code: string; name: string; address_label: string; phone_contact: string }) {
    if (!authSession) throw new Error("AUTHENTICATION_REQUIRED");
    const fresh = await ensureFreshSession(authSession);
    const data = await authRequest({ action: "create_site", ...input }, fresh.accessToken);
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
    if (!authSession.account.active_site_ids.includes(siteId)) throw new Error("SITE_SCOPE_FORBIDDEN");
    const fresh = await ensureFreshSession(authSession);
    const data = await authRequest({ action: "list_workstations", site_id: siteId }, fresh.accessToken);
    if (!Array.isArray(data.workstations)) throw new Error("WORKSTATION_LIST_INVALID");
    setWorkstations(data.workstations as WebWorkstation[]);
    setWorkstationSiteId(siteId);
    return data.workstations as WebWorkstation[];
  }

  async function createWebWorkstation(input: { site_id: string; code: string; name: string; kind: string; capacity: number }) {
    if (!authSession) throw new Error("AUTHENTICATION_REQUIRED");
    if (!authSession.account.active_site_ids.includes(input.site_id)) throw new Error("SITE_SCOPE_FORBIDDEN");
    const fresh = await ensureFreshSession(authSession);
    const data = await authRequest({ action: "create_workstation", ...input }, fresh.accessToken);
    const workstation = data.workstation as WebWorkstation | undefined;
    if (data.saved !== true || !workstation || typeof workstation.id !== "string") throw new Error("WORKSTATION_CREATE_NOT_CONFIRMED");
    setWorkstations(previous => [...previous.filter(item => item.id !== workstation.id), workstation]);
    setWorkstationSiteId(input.site_id);
    setAuthMessage("Emplacement créé par Auth : " + workstation.name);
    return workstation;
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
      setAuthSession(null);
      setAuthenticated(false);
      setPreview(false);
      setPassword("");
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
      setEntries({} as Record<ModuleId, Entry[]>);
      setActive("overview");
      setBusy(false);
      setAuthMessage(serverRevoked || !activeSession
        ? "Session fermée."
        : "Session locale fermée ; la révocation serveur n'a pas pu être confirmée. Une reconnexion sera nécessaire.");
    }
  }


  async function syncWebOutbox(activeSession: WebAuthSession) {
    if (!accountingEndpoint || !anonKey) throw new Error("Le connecteur de synchronisation Web n’est pas configuré.");
    const freshSession = await ensureFreshSession(activeSession);
    const batch = await acquireDueBatch(25, Date.now(), 60_000, OFFLINE_APP_ID);
    let acknowledged=0,retrying=0,rejected=0;
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
        if(queueState==="acknowledged"){acknowledged++;const moduleId=typeof command.module_id==="string"?command.module_id as ModuleId:"stock";const id=typeof command.aggregate_id==="string"?command.aggregate_id:"";if(id)setEntries(prev=>({...prev,[moduleId]:(prev[moduleId]??[]).map(x=>x.id===id?{...x,state:"Confirmé par le serveur"}:x)}));}
        else if(queueState==="rejected"||queueState==="conflict")rejected++;
      }catch{
        const willRetry=await scheduleRetry(queued.eventId,{status,errorCode},Date.now(),OFFLINE_APP_ID).catch(()=>false);
        if(willRetry)retrying++;else rejected++;
      }
    }
    const remaining=await listQueued(OFFLINE_APP_ID);setPendingSyncCount(remaining.length);
    await syncWebPullChanges(freshSession).catch(()=>undefined);
    if(acknowledged)setAuthMessage(acknowledged+" opération(s) confirmée(s) par le journal serveur.");
    else if(retrying)setAuthMessage(retrying+" opération(s) en attente de reprise réseau.");
    else if(rejected)setAuthMessage(rejected+" opération(s) rejetée(s) ou anciennes à ré-enregistrer ; aucun reçu n'a été fabriqué.");
    else if(!batch.length)setAuthMessage("Aucune opération Web en attente.");
    return{acknowledged,retrying,rejected,remaining:remaining.length};
  }
  async function syncWebPullChanges(activeSession: WebAuthSession) {
    if(!accountingEndpoint||!anonKey)throw new Error("Le connecteur de synchronisation Web n’est pas configuré.");
    const fresh=await ensureFreshSession(activeSession);
    let cursor=await getSyncCursor(OFFLINE_APP_ID,fresh.deviceId),pages=0,received=0,more=true;
    while(more&&pages<20){
      const response=await fetch(accountingEndpoint,{method:"POST",credentials:"omit",headers:{"Content-Type":"application/json",apikey:anonKey,Authorization:"Bearer "+fresh.accessToken},body:JSON.stringify({action:"pull_sync_changes",org_id:fresh.account.organization_id,device_id:fresh.deviceId,after_cursor:cursor,limit:200})});
      const data=await response.json().catch(()=>({})) as Record<string,unknown>;
      if(!response.ok||data.ok!==true||!data.result||typeof data.result!=="object")throw new Error(typeof data.error==="string"?data.error:"WEB_SYNC_PULL_FAILED");
      const page=data.result as {changes?:WebSyncChange[];next_cursor?:number;has_more?:boolean};
      if(!Array.isArray(page.changes)||typeof page.next_cursor!=="number"||!Number.isSafeInteger(page.next_cursor)||typeof page.has_more!=="boolean"||page.next_cursor<cursor)throw new Error("WEB_SYNC_PULL_INVALID_PAGE");
      await applySyncPage(OFFLINE_APP_ID,fresh.deviceId,{changes:page.changes,next_cursor:page.next_cursor,has_more:page.has_more});
      received+=page.changes.length;cursor=page.next_cursor;more=page.has_more;pages++;
    }
    const stored=await listSyncChanges(OFFLINE_APP_ID,fresh.deviceId);
    setRemoteChanges(stored);
    setEntries(previous=>{
      const next={...previous};
      for(const change of stored){
        const moduleId=moduleForSyncAction(change.action_code);
        if(!moduleId)continue;
        const payload=change.payload;
        const title=changeText(payload,["display_name","name","ticket_number","customer_name","customer_reference_or_name","subject","category","staff_name_snapshot","sku"],change.aggregate_id);
        const detail=changeText(payload,["description","items_summary","service_reference_or_name","phone_contact","unit"],change.action_code);
        const rows=next[moduleId]??[],existing=rows.findIndex(entry=>entry.id===change.aggregate_id);
        const record:Entry={id:change.aggregate_id,title,detail,state:"Reçu du serveur · autre appareil",createdAt:new Date(change.recorded_at).toLocaleString("fr-FR")};
        next[moduleId]=existing>=0?rows.map((entry,index)=>index===existing?record:entry):[...rows,record];
      }
      return next;
    });
    return{received,cursor,morePending:more};
  }

  async function submitStockItem() {
    const activeSession = authSession;
    if (!activeSession) { addLocalEntry(); return; }
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
      await enqueueOfflineEvent({appId:OFFLINE_APP_ID,eventId,deviceId:activeSession.deviceId,payload:JSON.stringify(payload),state:"queued",createdAt:Date.now()});
      setEntries((previous) => ({
        ...previous,
        stock: [...(previous.stock ?? []), {
          id: inventoryItemId, title: item.name, detail: item.sku || item.unit,
          state: navigator.onLine ? "En attente de confirmation serveur" : "En attente de connexion",
          createdAt: new Date().toLocaleString("fr-FR"),
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
    payload: Record<string, unknown>, siteId: string, title: string, detail: string,
  ) {
    const session = authSession;
    if (!session) throw new Error("AUTHENTICATION_REQUIRED");
    if (!session.account.active_site_ids.includes(siteId)) throw new Error("SITE_SCOPE_FORBIDDEN");
    const eventId = crypto.randomUUID();
    const command = {
      module_id: moduleId, display_title: title, display_detail: detail,
      action_code: actionCode, aggregate_type: aggregateType,
      aggregate_id: aggregateId, org_id: session.account.organization_id, site_id: siteId,
      payload: { ...payload, org_id: session.account.organization_id, site_id: siteId },
    };
    await enqueueOfflineEvent({appId:OFFLINE_APP_ID,eventId,deviceId:session.deviceId,payload:JSON.stringify(command),state:"queued",createdAt:Date.now()});
    setEntries(previous => ({...previous,[moduleId]:[...(previous[moduleId]??[]),{
      id:aggregateId,title,detail,state:navigator.onLine?"En attente de confirmation serveur":"En attente de connexion",
      createdAt:new Date().toLocaleString("fr-FR"),
    }]}));
    setPendingSyncCount(count=>count+1);
    setDialogOpen(false);
    setDraftTitle("");setDraftDetail("");setDraftSku("");setDraftPhone("");setDraftAmount("0");
    setDraftDate("");setDraftEndDate("");setDraftContactConsent(false);setDraftPriority("normal");setDraftActivity("general");
    if(navigator.onLine)await syncWebOutbox(session);
    else setAuthMessage("Opération mise en file hors ligne ; elle sera envoyée au retour du réseau.");
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
        },siteId,"PS-"+id.slice(0,8).toUpperCase()+" · "+title,amount.toLocaleString("fr-FR")+" FCFA · sans acompte");return;
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
      case "team":
        await submitWebBusinessEvent("team","staff_clock_in.recorded","staff_clock_in",id,{
          time_event_id:id,staff_member_id:session.account.member_id,
          staff_name_snapshot:session.account.display_name,occurred_at:new Date().toISOString(),workstation_id:null,
        },siteId,session.account.display_name,"Pointage d'arrivée");return;
      default: throw new Error("Aucun parcours métier Web n'est livré pour ce module.");
    }
  }

  function addLocalEntry() {
    if (!preview) { setAuthMessage("Ce module est en aperçu uniquement tant que son parcours métier serveur n'est pas livré. Aucune donnée n'a été enregistrée."); setDialogOpen(false); return; }
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
        <div className="auth-art">
          <div className="auth-brand"><img src="/naxa-services-logo.svg" alt="NAXA Services" /></div>
          <div className="auth-copy">
            <span className="eyebrow">PROTECTION DU COMPTE</span>
            <h1>Une dernière<br /><em>étape.</em></h1>
            <p>Le mot de passe initial doit être remplacé avant tout accès aux pages de gestion.</p>
            <div className="auth-proof"><span>01</span> Votre identité est authentifiée</div>
            <div className="auth-proof"><span>02</span> Le changement est contrôlé côté serveur</div>
            <div className="auth-proof"><span>03</span> Les jetons restent en mémoire dans cet onglet</div>
          </div>
          <div className="auth-footer">NAXA SERVICES · COMPTE SÉCURISÉ</div>
        </div>
        <main className="auth-panel">
          <div className="mobile-brand"><img src="/naxa-services-logo.svg" alt="NAXA Services" /></div>
          <div className="auth-form-wrap">
            <span className="eyebrow">CHANGEMENT OBLIGATOIRE</span>
            <h2>Créer un nouveau mot de passe</h2>
            <p className="muted">Minimum 10 caractères. Le changement est vérifié par le serveur avant l'ouverture de l'espace.</p>
            <form onSubmit={changeWebPassword} className="auth-form">
              <label>Mot de passe actuel<input type="password" value={currentPassword} onChange={(e) => setCurrentPassword(e.target.value)} autoComplete="current-password" required /></label>
              <label>Nouveau mot de passe<input type="password" value={newPassword} onChange={(e) => setNewPassword(e.target.value)} autoComplete="new-password" minLength={10} maxLength={256} required /></label>
              <label>Confirmer le nouveau mot de passe<input type="password" value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} autoComplete="new-password" minLength={10} maxLength={256} required /></label>
              {authMessage && <div className="notice">{authMessage}</div>}
              <button className="btn primary" disabled={busy}>{busy ? "Vérification…" : "Enregistrer le nouveau mot de passe"}</button>
            </form>
            <button className="link-button" onClick={signOut} disabled={busy}>Fermer la session</button>
          </div>
          <div className="panel-bottom"><span>FR · EN</span><span>Connexion sécurisée</span></div>
        </main>
      </div>
    );
  }

  if (!authenticated && !preview) {
    return (
      <div className={"app auth-app " + theme}>
        <div className="auth-art">
          <div className="auth-brand"><img src="/naxa-services-logo.svg" alt="NAXA Services" /></div>
          <div className="auth-copy">
            <span className="eyebrow">GESTION INTELLIGENTE DES PRESTATIONS</span>
            <h1>Votre établissement.<br /><em>Maîtrisé.</em></h1>
            <p>Pressing, coiffure, équipes, caisse et points de vente réunis dans un espace professionnel.</p>
            <div className="auth-proof"><span>01</span> Des opérations suivies de bout en bout</div>
            <div className="auth-proof"><span>02</span> Une autonomie par établissement</div>
            <div className="auth-proof"><span>03</span> Une vision réseau sans mélange des caisses</div>
          </div>
          <div className="auth-footer">NAXA SERVICES · ESPACE PROFESSIONNEL</div>
        </div>
        <main className="auth-panel">
          <div className="mobile-brand"><img src="/naxa-services-logo.svg" alt="NAXA Services" /></div>
          <div className="auth-form-wrap">
            <span className="eyebrow">{showRecovery ? "ASSISTANCE D'ACCÈS" : "ESPACE SÉCURISÉ"}</span>
            <h2>{showRecovery ? "Récupérer mon accès" : "Content de vous revoir."}</h2>
            <p className="muted">{showRecovery ? "Une demande interne sera envoyée au responsable pour vérification." : "Connectez-vous avec l'identifiant fourni par votre responsable."}</p>
            <form onSubmit={showRecovery ? requestRecovery : signIn} className="auth-form">
              <label>Identifiant NAXA Services<input value={identifier} onChange={(e) => setIdentifier(e.target.value.toUpperCase())} placeholder="NS-000000" autoComplete="username" required /></label>
              {!showRecovery && <label>Mot de passe<input type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" required /></label>}
              {showRecovery && <label>Note au responsable (facultatif)<textarea rows={3} value={recoveryNote} onChange={(e) => setRecoveryNote(e.target.value)} placeholder="Expliquez brièvement votre demande" /></label>}
              {!showRecovery && <p className="small muted">Session Web conservée uniquement en mémoire dans cet onglet. Aucun jeton n'est enregistré dans le stockage persistant du navigateur.</p>}
              {authMessage && <div className="notice">{authMessage}</div>}
              <button className="btn primary" disabled={busy}>{busy ? "Traitement…" : showRecovery ? "Envoyer la demande" : "Se connecter"}</button>
            </form>
            <button className="link-button" onClick={() => { setShowRecovery(!showRecovery); setAuthMessage(""); }}>{showRecovery ? "Retour à la connexion" : "Mot de passe oublié ?"}</button>
            <p className="small muted">Pas d'inscription libre, pas d'OTP et pas de boîte mail. Le reset de mot de passe est administré après contrôle d'identité.</p>
            <button className="preview-link" onClick={() => { setPreview(true); setAuthMessage(""); }}>Ouvrir l'aperçu des pages ERP (données locales uniquement)</button>
          </div>
          <div className="panel-bottom"><span>FR · EN</span><span>Mode sécurisé</span></div>
        </main>
      </div>
    );
  }

  return (
    <div className={"app erp-app " + theme}>
      {preview && <div className="preview-banner"><strong>APERÇU LOCAL</strong> Les opérations de cette session ne sont pas synchronisées et ne constituent pas un registre commercial. <button onClick={() => { setPreview(false); setAuthenticated(false); setActive("overview"); }}>Quitter l'aperçu</button></div>}
      <aside className="sidebar">
        <div className="side-brand"><img src="/naxa-services-logo.svg" alt="NAXA Services" /></div>
        <div className="workspace-label">ESPACE DE TRAVAIL</div>
        <div className="site-select"><span className="site-dot" /> <div><strong>{siteName}</strong><small>{modeLabel(mode)}</small></div><span className="chevron">⌄</span></div>
        <nav className="side-nav">
          {grouped.map(([group, groupModules]) => <div className="nav-group" key={group}>
            <div className="nav-heading">{group}</div>
            {groupModules.map((m) => <button key={m.id} className={"nav-item " + (active === m.id ? "active" : "")} onClick={() => setActive(m.id)}><span className="nav-glyph">{iconFor(m.id)}</span><span>{m.title}</span></button>)}
          </div>)}
        </nav>
        <div className="side-bottom">
          <button className="nav-item" onClick={() => setTheme(theme === "dark" ? "light" : "dark")}><span className="nav-glyph">◐</span>{theme === "dark" ? "Mode clair" : "Mode sombre"}</button>
          <button className="nav-item" onClick={signOut} disabled={busy}><span className="nav-glyph">↪</span>Déconnexion</button>
          <div className="user-mini"><div className="avatar">NS</div><div><strong>{preview ? "Aperçu local" : authSession?.account.display_name ?? "Espace connecté"}</strong><small>{authSession ? (authSession.account.organization_name || authSession.account.role_code || "NAXA Services") : "NAXA Services"}</small></div></div>
        </div>
      </aside>
      <main className="main-area">
        <header className="topbar">
          <div className="crumb"><span>NAXA SERVICES</span><b>/</b>{selected.title}</div>
          <div className="top-actions">
            <span className="sync-pill"><i /> {preview ? "Données locales" : authSession ? (authSession.requirePasswordChange ? "Changement du mot de passe requis" : "Session authentifiée · modules locaux") : "Connexion en attente"}</span>
            <button className="icon-button" title="Aide" onClick={() => setActive("help")}>?</button>
            <div className="avatar">NS</div>
          </div>
        </header>
        <section className="content-area">
          {authSession && authMessage && <div className="notice">{authMessage}</div>}
          {authSession && <div className="module-main-card" style={{marginBottom:18}}>
            <div className="module-card-head"><div><span className="eyebrow">JOURNAL SERVEUR</span><h2>Changements reçus</h2></div><span className="status-tag local">{remoteChanges.length}</span></div>
            {remoteChanges.length===0?<Empty text="Aucun changement entrant chargé pour cet appareil."/>:<div className="record-list">{remoteChanges.slice(-12).reverse().map(c=><div className="record" key={c.cursor}><div><strong>{c.action_code}</strong><small>{c.aggregate_type} · {c.aggregate_id} · curseur {c.cursor}</small></div><span className="status-tag local">Serveur</span></div>)}</div>}
          </div>}
          <div className="page-heading">
            <div><span className="eyebrow">{moduleCopy[active].eyebrow}</span><h1>{moduleCopy[active].headline}</h1><p>{moduleCopy[active].helper}</p></div>
            <div className="heading-actions">
              {active !== "overview" && <button className="btn secondary" onClick={() => setActive("overview")}>Vue d'ensemble</button>}
              {authSession && <button className="btn secondary" disabled={busy} onClick={() => {
                const operation = pendingSyncCount > 0 ? syncWebOutbox(authSession) : syncWebPullChanges(authSession);
                void operation.catch((error) => setAuthMessage(error instanceof Error ? error.message : "Synchronisation impossible."));
              }}>{pendingSyncCount > 0 ? "Synchroniser (" + pendingSyncCount + ")" : "Actualiser depuis le serveur"}</button>}
              <button className="btn primary" disabled={busy || (!preview && !["stock","agenda","pressing","cash","services","customers","team","help"].includes(active))} title={!preview && !["stock","agenda","pressing","cash","services","customers","team","help"].includes(active) ? "Connecteur métier Web non livré." : undefined} onClick={() => {
                if (!preview && !["stock","agenda","pressing","cash","services","customers","team","help"].includes(active)) { setAuthMessage("Connecteur métier Web non livré pour ce module."); return; }
                setDraftTitle(active==="team"&&authSession?authSession.account.display_name:"");setDraftDetail("");setDraftSku("");setDraftUnit("pièce");setDraftReorderLevel("0");setDraftSupplierWhatsApp("");setDraftPhone("");setDraftAmount("0");setDraftDate("");setDraftEndDate("");setDraftPriority("normal");setDraftActivity("general");setDraftContactConsent(false);setDialogOpen(true);
              }}>{!preview&&!["stock","agenda","pressing","cash","services","customers","team","help"].includes(active)?"Connecteur à livrer":active==="team"?"Pointer mon arrivée":selected.action}</button>
            </div>
          </div>

          {active === "overview" ? <Overview entries={entries} onNavigate={setActive} mode={mode} /> :
            active === "organization" ? <OrganizationPage mode={mode} setMode={setMode} siteName={siteName} setSiteName={setSiteName} editable={preview || authSession?.account.role_code === "promoter"} onSave={saveWebOrganizationProfile} locale={authSession?.account.default_locale ?? "fr"} /> :
            active === "network" || active === "sites" ? <SitesPage mode={mode} siteName={siteName} sites={authSession?.account.active_sites ?? []} canCreate={authSession?.account.role_code === "promoter"} onCreateSite={createWebSite} entries={entries.network ?? []} /> :
            active === "workstations" ? <WorkstationsPage mode={mode} sites={authSession?.account.active_sites ?? []} selectedSiteId={workstationSiteId || activeSiteId} workstations={workstations} onLoad={loadWebWorkstations} onCreate={createWebWorkstation} canCreate={Boolean(authSession && ["promoter","network_manager","site_manager"].includes(authSession.account.role_code))} /> :
            active === "agenda" ? <AgendaPage entries={entries.agenda ?? []} /> :
            active === "pressing" ? <PressingPage entries={entries.pressing ?? []} canPreviewEdit={preview} onAdvance={(id) => setEntries((prev) => ({ ...prev, pressing: (prev.pressing ?? []).map((x) => x.id === id ? { ...x, state: nextPressingState(x.state) } : x) }))} /> :
            active === "cash" ? <CashPage entries={entries.cash ?? []} /> :
            <GenericPage active={active} entries={entries[active] ?? []} copy={moduleCopy[active]} preview={preview} />}

          <div className="page-footnote"><span>ⓘ</span> {preview ? "Les créations sont gardées en mémoire dans cette session uniquement." : authSession ? "Session authentifiée. Stock utilise le journal serveur ; les autres actions restent désactivées tant que leurs parcours métier Web ne sont pas livrés." : "Aucun accès opérationnel n'est accordé avant authentification et synchronisation côté serveur."}</div>
        </section>
        <nav className="mobile-tabs">
          {(["overview", "agenda", "pressing", "cash", "services"] as ModuleId[]).map((id) => <button key={id} className={active === id ? "selected" : ""} onClick={() => setActive(id)}><span>{iconFor(id)}</span>{modules.find((m) => m.id === id)?.title.split(" ")[0]}</button>)}
        </nav>
      </main>
      {dialogOpen && <div className="modal-backdrop" role="presentation" onMouseDown={(e) => { if (e.target === e.currentTarget) setDialogOpen(false); }}>
        <div className="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title">
          <div className="modal-head"><div><span className="eyebrow">{authSession&&!preview?"OPÉRATION · JOURNAL SERVEUR":"NOUVELLE OPÉRATION · APERÇU LOCAL"}</span><h2 id="modal-title">{active==="team"&&authSession&&!preview?"Pointer mon arrivée":selected.action}</h2></div><button className="icon-button" onClick={() => setDialogOpen(false)}>×</button></div>
          <form onSubmit={(e) => {e.preventDefault();if(active==="stock"&&authSession)void submitStockItem();else if(authSession&&!preview)void submitModuleOperation().catch(error=>setAuthMessage(error instanceof Error?error.message:"Opération impossible."));else if(preview)addLocalEntry();else{setAuthMessage("Connecteur métier non disponible.");setDialogOpen(false);}}}>
            <label>{active==="customers"?"Nom du client":active==="pressing"?"Nom du client":active==="agenda"?"Nom / référence du client":active==="help"?"Sujet":active==="cash"?"Catégorie de dépense":active==="team"?"Membre":"Nom / référence"}<input autoFocus value={draftTitle} readOnly={active==="team"&&authSession&&!preview} onChange={(e) => setDraftTitle(e.target.value)} required placeholder="Saisir la valeur" /></label>
            {active === "stock" && authSession ? <>
              <label>Point de vente<select value={activeSiteId} onChange={(e) => setActiveSiteId(e.target.value)} required>{authSession.account.active_site_ids.map((siteId) => <option key={siteId} value={siteId}>{siteId}</option>)}</select></label>
              <label>SKU (facultatif)<input value={draftSku} onChange={(e) => setDraftSku(e.target.value)} maxLength={80} /></label>
              <label>Unité<input value={draftUnit} onChange={(e) => setDraftUnit(e.target.value)} required maxLength={40} /></label>
              <label>Seuil d'alerte<input type="number" min="0" step="0.001" value={draftReorderLevel} onChange={(e) => setDraftReorderLevel(e.target.value)} required /></label>
              <label>WhatsApp fournisseur<input value={draftSupplierWhatsApp} onChange={(e) => setDraftSupplierWhatsApp(e.target.value)} maxLength={32} placeholder="+237 6xx xx xx xx" /></label>
              <div className="notice">La fiche article rejoint l'outbox avec un identifiant et une séquence liés à cet appareil. Elle n'est confirmée qu'après le reçu du journal serveur.</div>
            </> : authSession && !preview && active==="customers" ? <>
              <label>Téléphone facultatif<input value={draftPhone} onChange={e=>setDraftPhone(e.target.value)} maxLength={32}/></label>
              <label><input type="checkbox" checked={draftContactConsent} onChange={e=>setDraftContactConsent(e.target.checked)}/> Consentement de contact obtenu</label>
            </> : authSession && !preview && active==="services" ? <>
              <label>Code prestation<input value={draftSku} onChange={e=>setDraftSku(e.target.value)} required maxLength={80}/></label>
              <label>Activité<select value={draftActivity} onChange={e=>setDraftActivity(e.target.value)}>{["pressing","hair","beauty","treatment","tailoring","perfume","repair","part","manufacturing","vehicle","cleaning","contract","home","printing","event","package","material","service","retail","general"].map(v=><option key={v} value={v}>{v}</option>)}</select></label>
              <label>Tarif FCFA<input type="number" min="0" step="1" value={draftAmount} onChange={e=>setDraftAmount(e.target.value)} required/></label>
              <label>Description<textarea rows={3} value={draftDetail} onChange={e=>setDraftDetail(e.target.value)} maxLength={2000}/></label>
            </> : authSession && !preview && active==="pressing" ? <>
              <label>Téléphone client<input value={draftPhone} onChange={e=>setDraftPhone(e.target.value)} maxLength={32}/></label>
              <label>Articles déposés<textarea rows={3} value={draftDetail} onChange={e=>setDraftDetail(e.target.value)} required minLength={2}/></label>
              <label>Montant total FCFA<input type="number" min="1" step="1" value={draftAmount} onChange={e=>setDraftAmount(e.target.value)} required/></label>
              <label>Date promise<input type="datetime-local" value={draftDate} onChange={e=>setDraftDate(e.target.value)} required/></label>
              <div className="notice">Aucun acompte n'est encaissé dans ce parcours de création.</div>
            </> : authSession && !preview && active==="agenda" ? <>
              <label>Prestation (nom ou code)<input value={draftDetail} onChange={e=>setDraftDetail(e.target.value)} required/></label>
              <label>Début<input type="datetime-local" value={draftDate} onChange={e=>setDraftDate(e.target.value)} required/></label>
              <label>Fin<input type="datetime-local" value={draftEndDate} onChange={e=>setDraftEndDate(e.target.value)} required/></label>
              <div className="notice">Le rendez-vous est affecté au membre connecté ; les chevauchements sont vérifiés côté serveur.</div>
            </> : authSession && !preview && active==="cash" ? <>
              <label>Motif<textarea rows={3} value={draftDetail} onChange={e=>setDraftDetail(e.target.value)} required minLength={2}/></label>
              <label>Montant FCFA<input type="number" min="1" step="1" value={draftAmount} onChange={e=>setDraftAmount(e.target.value)} required/></label>
              <label>Date<input type="datetime-local" value={draftDate} onChange={e=>setDraftDate(e.target.value)}/></label>
              <div className="notice">Dépense hors caisse. Aucun paiement client ou encaissement n'est créé.</div>
            </> : authSession && !preview && active==="help" ? <>
              <label>Description<textarea rows={4} value={draftDetail} onChange={e=>setDraftDetail(e.target.value)} required minLength={3}/></label>
              <label>Priorité<select value={draftPriority} onChange={e=>setDraftPriority(e.target.value)}>{["low","normal","high","urgent"].map(v=><option key={v} value={v}>{v}</option>)}</select></label>
            </> : authSession && !preview && active==="team" ? <>
              <div className="notice">Le pointage est enregistré uniquement pour le membre authentifié.</div>
            </> : <>
              <label>Détails<textarea rows={3} value={draftDetail} onChange={(e) => setDraftDetail(e.target.value)} placeholder="Informations complémentaires" /></label>
              <div className="notice">Aperçu local : aucune opération réelle n'est créée.</div>
            </>}
            <div className="modal-actions"><button type="button" className="btn secondary" onClick={() => setDialogOpen(false)}>Annuler</button><button className="btn primary" disabled={busy}>{authSession&&!preview?"Mettre en file & synchroniser":"Ajouter à l'aperçu"}</button></div>
          </form>
        </div>
      </div>}
    </div>
  );
}

function moduleForSyncAction(action: string): ModuleId | null {
  if(action.startsWith("inventory_item.")||action.startsWith("inventory_movement.")||action.startsWith("supplier.")||action.startsWith("purchase."))return "stock";
  if(action.startsWith("service."))return "services";
  if(action.startsWith("customer."))return "customers";
  if(action.startsWith("pressing_order."))return "pressing";
  if(action.startsWith("appointment."))return "agenda";
  if(action.startsWith("expense.")||action.startsWith("sale.")||action.startsWith("cash_session."))return "cash";
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
  const map: Record<ModuleId, string> = { overview: "⌂", agenda: "◷", pressing: "▤", cash: "₣", services: "✦", customers: "◎", team: "♙", stock: "▥", reports: "▤", organization: "⌂", network: "⌘", sites: "▦", workstations: "▥", security: "◇", settings: "⚙", help: "?" };
  return map[id];
}
function nextPressingState(state: string) {
  if (state === "Brouillon local" || state === "Reçu") return "En cours";
  if (state === "En cours") return "Prêt";
  if (state === "Prêt") return "Retiré";
  return "Retiré";
}
function Overview({ entries, onNavigate, mode }: { entries: Record<ModuleId, Entry[]>; onNavigate: (id: ModuleId) => void; mode: BusinessMode }) {
  const totalDrafts = Object.values(entries).reduce((sum, list) => sum + (list?.length ?? 0), 0);
  return <div className="overview-grid">
    <div className="overview-main">
      <div className="hero-card"><div><span className="hero-kicker">VOTRE ESPACE DE GESTION</span><h2>Une journée bien organisée commence ici.</h2><p>Les chiffres apparaîtront après la première synchronisation de vos données métier.</p></div><div className="hero-symbol">N</div></div>
      <div className="metric-grid">
        <Metric label="Rendez-vous aujourd'hui" value="—" meta="En attente de synchronisation" />
        <Metric label="Tickets à rendre" value="—" meta="En attente de synchronisation" />
        <Metric label="Caisse du jour" value="—" meta="Aucun solde simulé" />
        <Metric label="Équipe présente" value="—" meta="Pointage non connecté" />
      </div>
      <div className="section-title"><div><span className="eyebrow">VOTRE ACTIVITÉ</span><h2>Accès rapides</h2></div><span className="local-counter">{totalDrafts} brouillon(s) local(aux)</span></div>
      <div className="shortcut-grid">
        {(["agenda", "pressing", "cash", "services"] as ModuleId[]).map((id) => {
          const item = modules.find((m) => m.id === id)!;
          return <button className="shortcut-card" key={id} onClick={() => onNavigate(id)}><span className="shortcut-icon">{iconFor(id)}</span><strong>{item.title}</strong><small>{item.description}</small><b>Ouvrir <span>→</span></b></button>;
        })}
      </div>
    </div>
    <aside className="overview-side">
      <div className="side-card"><div className="section-title"><div><span className="eyebrow">STRUCTURE</span><h3>Mode d'exploitation</h3></div></div><strong className="mode-name">{modeLabel(mode)}</strong><p>Les données restent isolées par organisation, site et poste selon les droits attribués.</p><button className="text-action" onClick={() => onNavigate("organization")}>Configurer la structure →</button></div>
      <div className="side-card"><span className="eyebrow">BRIEFING DU MATIN</span><h3>À préparer</h3><ul className="brief-list"><li>Vérifier les rendez-vous et les créneaux.</li><li>Contrôler les tickets dont la date promise approche.</li><li>Ouvrir les caisses de chaque poste autorisé.</li><li>Consulter les alertes de consommables.</li></ul></div>
      <div className="side-card alert-card"><span className="eyebrow">SYNCHRONISATION</span><h3>Backend non connecté</h3><p>Aucun chiffre n'est inventé. Les pages sont en aperçu tant que les contrats et l'authentification ne sont pas validés.</p></div>
    </aside>
  </div>;
}
function Metric({ label, value, meta }: { label: string; value: string; meta: string }) {
  return <div className="metric-card"><span>{label}</span><strong>{value}</strong><small>{meta}</small></div>;
}
function GenericPage({ active, entries, copy, preview }: { active: ModuleId; entries: Entry[]; copy: typeof moduleCopy[ModuleId]; preview: boolean }) {
  return <div className="module-layout">
    <div className="module-main-card"><div className="module-card-head"><div><span className="eyebrow">PÉRIMÈTRE FONCTIONNEL</span><h2>Fonctions prévues</h2></div><span className="status-tag pending">{preview?"Aperçu fonctionnel":"Connecteur non livré"}</span></div>
      <div className="feature-list">{copy.features.map((feature,i)=><div className="feature-row" key={feature}><span className="feature-number">{String(i+1).padStart(2,"0")}</span><span>{feature}</span><span className="feature-check">◇</span></div>)}</div>
      {!preview&&<div className="notice">Les écritures sont désactivées en session réelle jusqu'à livraison du formulaire et de la projection métier.</div>}
    </div>
    <div className="module-main-card"><div className="module-card-head"><div><span className="eyebrow">{preview?"SESSION EN COURS":"DONNÉES MÉTIER"}</span><h2>{preview?"Brouillons locaux":"Projection non livrée"}</h2></div><span className="status-tag local">{preview?"Local":"Non projeté"}</span></div>
      {entries.length===0?<Empty text={preview?copy.empty:"Le journal entrant reste visible dans la zone globale ; la projection métier de ce module n'est pas encore livrée."}/>:<div className="record-list">{entries.map(entry=><Record key={entry.id} entry={entry}/>)}</div>}
    </div>
  </div>;
}
function AgendaPage({ entries }: { entries: Entry[] }) {
  return <div className="module-layout"><div className="module-main-card"><div className="module-card-head"><div><span className="eyebrow">PLANNING</span><h2>Vue des créneaux</h2></div><span className="status-tag pending">Planning non synchronisé</span></div><div className="calendar-strip">{["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"].map((d, i) => <div key={d} className={i === 2 ? "today" : ""}><small>{d}</small><strong>{String(i + 20).padStart(2, "0")}</strong></div>)}</div><div className="schedule-empty"><span className="empty-glyph">◷</span><strong>Aucun créneau chargé</strong><p>Les horaires, absences, postes et rendez-vous apparaîtront après synchronisation.</p></div></div><div className="module-main-card"><h2>Demandes de rendez-vous locales</h2>{entries.length ? entries.map((e) => <Record key={e.id} entry={e} />) : <Empty text="Aucune demande créée dans cette session." />}</div></div>;
}
function PressingPage({ entries, onAdvance, canPreviewEdit }: { entries: Entry[]; onAdvance: (id: string) => void; canPreviewEdit: boolean }) {
  return <div className="module-layout"><div className="module-main-card"><div className="module-card-head"><div><span className="eyebrow">SUIVI DES TICKETS</span><h2>Étapes de traitement</h2></div><span className="status-tag pending">{canPreviewEdit?"Aperçu local":"Connecteur non livré"}</span></div><div className="pressing-steps">{["Reçu","En cours","Prêt","Retiré"].map((step,i)=><div key={step}><span>{i+1}</span><strong>{step}</strong></div>)}</div><p className="muted">Les transitions réelles exigent un handler pressing et un reçu serveur ; elles ne sont pas simulées.</p></div><div className="module-main-card"><h2>Tickets de cette session</h2>{entries.length?entries.map(e=><div className="record-row" key={e.id}><Record entry={e}/>{canPreviewEdit&&<button className="btn secondary" onClick={()=>onAdvance(e.id)} disabled={e.state==="Retiré"}>Avancer l'aperçu</button>}</div>):<Empty text="Aucun ticket disponible dans cette vue."/>}</div></div>;
}
function CashPage({ entries }: { entries: Entry[] }) {
  return <div className="module-layout"><div className="module-main-card"><div className="module-card-head"><div><span className="eyebrow">SESSION CAISSE</span><h2>Registre non ouvert</h2></div><span className="status-tag pending">À connecter</span></div><div className="cash-summary"><div><small>Fonds d'ouverture</small><strong>—</strong></div><div><small>Encaissements</small><strong>—</strong></div><div><small>Écart</small><strong>—</strong></div></div><div className="notice">Les montants ne sont pas calculés dans cet aperçu. Une session réelle sera ouverte sur le serveur et rattachée à une caisse et un opérateur.</div></div><div className="module-main-card"><h2>Ventes de cette session</h2>{entries.length ? entries.map((e) => <Record key={e.id} entry={e} />) : <Empty text="Aucune vente locale. Aucun paiement n'a été confirmé." />}</div></div>;
}
function OrganizationPage({
  mode, setMode, siteName, setSiteName, editable, onSave, locale,
}: {
  mode: BusinessMode; setMode: (mode: BusinessMode) => void; siteName: string; setSiteName: (s: string) => void;
  editable: boolean; onSave: (name: string, mode: BusinessMode, locale: "fr" | "en" | "ff-CM") => Promise<void>;
  locale: "fr" | "en" | "ff-CM";
}) {
  const [selectedLocale, setSelectedLocale] = useState<"fr" | "en" | "ff-CM">(locale);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  async function save() {
    setSaving(true); setError("");
    try { await onSave(siteName.trim(), mode, selectedLocale); }
    catch (cause) { setError(cause instanceof Error ? cause.message : "Enregistrement refusé par Auth."); }
    finally { setSaving(false); }
  }
  return <div className="structure-grid">
    <div className="module-main-card">
      <span className="eyebrow">ARCHITECTURE DE GESTION</span><h2>Modèle d'exploitation</h2>
      <div className="mode-options">
        <button disabled={!editable || saving} className={mode==="solo"?"mode-option selected":"mode-option"} onClick={()=>setMode("solo")}><b>01 · PME autonome</b><strong>Un établissement indépendant</strong><small>Un point de vente, une organisation et ses opérations.</small></button>
        <button disabled={!editable || saving} className={mode==="single_site_multi_workstation"?"mode-option selected":"mode-option"} onClick={()=>setMode("single_site_multi_workstation")}><b>02 · Responsable multi-emplacements</b><strong>Plusieurs postes dans un même lieu</strong><small>Plusieurs ressources dans un point de vente.</small></button>
        <button disabled={!editable || saving} className={mode==="multi_site_network"?"mode-option selected":"mode-option"} onClick={()=>setMode("multi_site_network")}><b>03 · Promoteur multi-sites</b><strong>Plusieurs points de vente autonomes</strong><small>Consolidation réseau, opérations isolées.</small></button>
      </div>
    </div>
    <div className="module-main-card">
      <span className="eyebrow">PROFIL DE L'ORGANISATION</span><h2>Identité & langue</h2>
      <label>Nom de l'organisation<input disabled={!editable || saving} value={siteName} onChange={e=>setSiteName(e.target.value)} /></label>
      <label>Langue par défaut<select disabled={!editable || saving} value={selectedLocale} onChange={e=>setSelectedLocale(e.target.value as "fr"|"en"|"ff-CM")}><option value="fr">Français</option><option value="en">English</option><option value="ff-CM">Fulfulde</option></select></label>
      {editable && !saving && <button className="btn primary" onClick={()=>void save()}>Enregistrer le profil Auth</button>}
      {saving && <div className="notice">Enregistrement côté serveur…</div>}
      {error && <div className="notice">{error}</div>}
      {!editable && <div className="notice">Lecture seule : seul le Promoteur ayant le périmètre Organisation peut enregistrer ces réglages.</div>}
    </div>
  </div>;
}

function SitesPage({
  mode, siteName, sites, canCreate, onCreateSite, entries,
}: {
  mode: BusinessMode; siteName: string; sites: {id:string;code:string;name:string;address_label:string;phone_contact:string}[];
  canCreate: boolean; onCreateSite: (site:{code:string;name:string;address_label:string;phone_contact:string})=>Promise<unknown>; entries: Entry[];
}) {
  const [code,setCode]=useState(""); const [name,setName]=useState(""); const [address,setAddress]=useState(""); const [phone,setPhone]=useState("");
  const [saving,setSaving]=useState(false); const [error,setError]=useState("");
  async function submit(e:React.FormEvent) {
    e.preventDefault();setSaving(true);setError("");
    try { await onCreateSite({code,name,address_label:address,phone_contact:phone});setCode("");setName("");setAddress("");setPhone(""); }
    catch(cause){setError(cause instanceof Error?cause.message:"Création refusée par Auth.");}
    finally{setSaving(false);}
  }
  return <div className="module-layout">
    <div className="module-main-card"><span className="eyebrow">PÉRIMÈTRE RÉSEAU</span><h2>Points de vente sous contrôle</h2>
      <div className="site-list">
        {sites.length ? sites.map(site=><div className="site-row" key={site.id}><span className="site-dot"/><div><strong>{site.name||site.code}</strong><small>{site.code} · {site.address_label||"Adresse non renseignée"} · {site.id}</small></div><span className="status-tag local">Autorisé</span></div>)
          : <Empty text="Aucun site n'est inclus dans le périmètre actif de cette session."/>}
      </div>
      <p className="muted">Organisation : {siteName}. Mode : {modeLabel(mode)}. Les sites sont affichés uniquement lorsqu'Auth les inclut dans le périmètre de session.</p>
    </div>
    <div className="module-main-card"><h2>Créer un point de vente</h2>
      {mode!=="multi_site_network" && <div className="notice">Le modèle multi-sites doit d'abord être activé par le Promoteur dans le profil d'organisation.</div>}
      {canCreate && mode==="multi_site_network" ? <form onSubmit={submit}>
        <label>Code du site<input value={code} onChange={e=>setCode(e.target.value.toUpperCase())} required minLength={2} maxLength={20}/></label>
        <label>Nom du site<input value={name} onChange={e=>setName(e.target.value)} required maxLength={120}/></label>
        <label>Adresse / repère<input value={address} onChange={e=>setAddress(e.target.value)} maxLength={200}/></label>
        <label>Téléphone<input value={phone} onChange={e=>setPhone(e.target.value)} maxLength={32}/></label>
        <button className="btn primary" disabled={saving}>Créer le site avec Auth</button>
      </form> : <div className="notice">La création requiert le rôle Promoteur, le périmètre Organisation et le mode multi-sites.</div>}
      {error&&<div className="notice">{error}</div>}
      <h3>Principes d'autonomie</h3><ul className="brief-list"><li>Caisse et clôture propres à chaque site.</li><li>Stock et historique distincts.</li><li>Équipe et affectations séparées.</li><li>Consolidation réseau sans mutation cross-site implicite.</li></ul>
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
  const [siteId,setSiteId]=useState(selectedSiteId||sites[0]?.id||"");
  const [code,setCode]=useState("");const [name,setName]=useState("");const [kind,setKind]=useState("other");const [capacity,setCapacity]=useState("1");
  const [loading,setLoading]=useState(false);const [saving,setSaving]=useState(false);const [error,setError]=useState("");
  async function load(){if(!siteId){setError("Choisis un site autorisé.");return;}setLoading(true);setError("");try{await onLoad(siteId);}catch(cause){setError(cause instanceof Error?cause.message:"Lecture des postes refusée.");}finally{setLoading(false);}}
  async function create(e:React.FormEvent){e.preventDefault();setSaving(true);setError("");try{await onCreate({site_id:siteId,code,name,kind,capacity:Number(capacity)});setCode("");setName("");setCapacity("1");}catch(cause){setError(cause instanceof Error?cause.message:"Création du poste refusée.");}finally{setSaving(false);}}
  return <div className="module-layout">
    <div className="module-main-card"><span className="eyebrow">POSTES & RESSOURCES</span><h2>Emplacements d'un même établissement</h2>
      <label>Point de vente<select value={siteId} onChange={e=>setSiteId(e.target.value)}>{sites.map(site=><option key={site.id} value={site.id}>{site.name||site.code}</option>)}</select></label>
      <button className="btn secondary" disabled={loading||!siteId} onClick={()=>void load()}>{loading?"Chargement…":"Charger les postes Auth"}</button>
      <div className="workstation-grid">{workstations.filter(item=>item.site_id===siteId).map((item,i)=><div className="workstation-card" key={item.id}><span>{String(i+1).padStart(2,"0")}</span><strong>{item.name}</strong><small>{item.code} · {item.kind} · capacité {item.capacity}</small></div>)}</div>
      {!workstations.some(item=>item.site_id===siteId)&&<Empty text="Aucun emplacement chargé pour ce point de vente."/>}
    </div>
    <div className="module-main-card"><h2>Créer un emplacement</h2>
      {canCreate&&siteId?<form onSubmit={create}>
        <label>Code<input value={code} onChange={e=>setCode(e.target.value.toUpperCase())} required minLength={2} maxLength={20}/></label>
        <label>Nom<input value={name} onChange={e=>setName(e.target.value)} required maxLength={120}/></label>
        <label>Type<select value={kind} onChange={e=>setKind(e.target.value)}>{["hair_chair","pressing_counter","pressing_workshop","reception","cashier","other"].map(value=><option key={value} value={value}>{value}</option>)}</select></label>
        <label>Capacité<input type="number" min="1" max="100" step="1" value={capacity} onChange={e=>setCapacity(e.target.value)}/></label>
        <button className="btn primary" disabled={saving}>Créer le poste avec Auth</button>
      </form>:<div className="notice">Seuls Promoteur, Network Manager ou Site Manager peuvent tenter la création ; Auth contrôle le périmètre du site.</div>}
      <p className="muted">Mode : {modeLabel(mode)}. Les droits d'un poste ne sont pas élargis au site entier.</p>
      {error&&<div className="notice">{error}</div>}
    </div>
  </div>;
}
function Empty({ text }: { text: string }) { return <div className="empty-state"><span className="empty-glyph">◌</span><strong>Tout est prêt pour commencer</strong><p>{text}</p></div>; }
function Record({ entry }: { entry: Entry }) { return <div className="record"><div><strong>{entry.title}</strong><small>{entry.detail || entry.createdAt}</small></div><span className="status-tag local">{entry.state}</span></div>; }

createRoot(document.getElementById("root")!).render(<React.StrictMode><App /></React.StrictMode>);
