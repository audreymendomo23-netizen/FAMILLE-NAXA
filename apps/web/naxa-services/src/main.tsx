import React, { useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import "@famille/design-system/tokens.css";
import "./naxa-services.css";

type ModuleId =
  | "overview" | "agenda" | "pressing" | "cash" | "services" | "customers"
  | "team" | "stock" | "reports" | "organization" | "network" | "sites"
  | "workstations" | "security" | "settings" | "help";

type BusinessMode = "solo" | "single_site_multi_workstation" | "multi_site_network";
type Entry = { id: string; title: string; detail: string; state: string; createdAt: string };

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
  const [preview, setPreview] = useState(false);
  const [active, setActive] = useState<ModuleId>("overview");
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(false);
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
  const [search, setSearch] = useState("");

  const selected = modules.find((m) => m.id === active)!;
  const grouped = useMemo(() => {
    const groups = new Map<string, typeof modules>();
    modules.forEach((m) => groups.set(m.group, [...(groups.get(m.group) ?? []), m]));
    return Array.from(groups.entries());
  }, []);

  const env = (import.meta as unknown as { env?: Record<string, string> }).env ?? {};
  const authEndpoint = env.VITE_NAXA_SERVICES_AUTH_URL ?? "";
  const anonKey = env.VITE_SUPABASE_ANON_KEY ?? "";

  async function authRequest(body: Record<string, unknown>) {
    if (!authEndpoint || !anonKey) throw new Error("Le service d'authentification web n'est pas configuré.");
    const response = await fetch(authEndpoint, {
      method: "POST",
      credentials: "include",
      headers: { "Content-Type": "application/json", apikey: anonKey, Authorization: "Bearer " + anonKey },
      body: JSON.stringify({ app_code: "naxa-services", ...body }),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data.message ?? "Service indisponible. Réessaie plus tard.");
    return data;
  }

  async function signIn(event: React.FormEvent) {
    event.preventDefault();
    setBusy(true);
    setAuthMessage("");
    try {
      await authRequest({ action: "login", identifier: identifier.trim().toUpperCase(), password, remember_device: remember, device: { platform: "web", label: navigator.userAgent.slice(0, 90) } });
      setAuthMessage("La réponse de connexion est reçue. La création de session Web reste à valider avec la politique de cookies sécurisés.");
    } catch (error) {
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
      await authRequest({ action: "request_recovery", identifier: identifier.trim().toUpperCase(), request_note: recoveryNote, device: { platform: "web" } });
      setAuthMessage("Demande transmise si le compte est identifiable. Le responsable effectuera le contrôle d'identité.");
    } catch (error) {
      setAuthMessage(error instanceof Error ? error.message : "Demande impossible.");
    } finally {
      setBusy(false);
    }
  }

  function addLocalEntry() {
    const title = draftTitle.trim();
    if (!title) return;
    const item: Entry = { id: crypto.randomUUID(), title, detail: draftDetail.trim(), state: "Brouillon local", createdAt: new Date().toLocaleString("fr-FR") };
    setEntries((prev) => ({ ...prev, [active]: [...(prev[active] ?? []), item] }));
    setDraftTitle("");
    setDraftDetail("");
    setDialogOpen(false);
  }

  const visibleModules = modules.filter((m) => (m.title + " " + m.description + " " + m.group).toLowerCase().includes(search.toLowerCase()));

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
              {!showRecovery && <label className="check-label"><input type="checkbox" checked={remember} onChange={(e) => setRemember(e.target.checked)} /><span>Rester connecté sur cet appareil</span></label>}
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
          <button className="nav-item" onClick={() => { setPreview(false); setAuthenticated(false); setActive("overview"); }}><span className="nav-glyph">↪</span>Déconnexion</button>
          <div className="user-mini"><div className="avatar">NS</div><div><strong>{preview ? "Aperçu local" : "Espace connecté"}</strong><small>NAXA Services</small></div></div>
        </div>
      </aside>
      <main className="main-area">
        <header className="topbar">
          <div className="crumb"><span>NAXA SERVICES</span><b>/</b>{selected.title}</div>
          <div className="top-actions">
            <span className="sync-pill"><i /> {preview ? "Données locales" : "Connexion en attente"}</span>
            <button className="icon-button" title="Aide" onClick={() => setActive("help")}>?</button>
            <div className="avatar">NS</div>
          </div>
        </header>
        <section className="content-area">
          <div className="page-heading">
            <div><span className="eyebrow">{moduleCopy[active].eyebrow}</span><h1>{moduleCopy[active].headline}</h1><p>{moduleCopy[active].helper}</p></div>
            <div className="heading-actions">
              {active !== "overview" && <button className="btn secondary" onClick={() => setActive("overview")}>Vue d'ensemble</button>}
              <button className="btn primary" onClick={() => { setDraftTitle(""); setDraftDetail(""); setDialogOpen(true); }}>{selected.action}</button>
            </div>
          </div>

          {active === "overview" ? <Overview entries={entries} onNavigate={setActive} mode={mode} /> :
            active === "organization" ? <OrganizationPage mode={mode} setMode={setMode} siteName={siteName} setSiteName={setSiteName} /> :
            active === "network" || active === "sites" ? <SitesPage mode={mode} siteName={siteName} entries={entries.network ?? []} /> :
            active === "workstations" ? <WorkstationsPage mode={mode} /> :
            active === "agenda" ? <AgendaPage entries={entries.agenda ?? []} /> :
            active === "pressing" ? <PressingPage entries={entries.pressing ?? []} onAdvance={(id) => setEntries((prev) => ({ ...prev, pressing: (prev.pressing ?? []).map((x) => x.id === id ? { ...x, state: nextPressingState(x.state) } : x) }))} /> :
            active === "cash" ? <CashPage entries={entries.cash ?? []} /> :
            <GenericPage active={active} entries={entries[active] ?? []} copy={moduleCopy[active]} />}

          <div className="page-footnote"><span>ⓘ</span> {preview ? "Les créations sont gardées en mémoire dans cette session uniquement." : "Aucun accès opérationnel n'est accordé avant authentification et synchronisation côté serveur."}</div>
        </section>
        <nav className="mobile-tabs">
          {(["overview", "agenda", "pressing", "cash", "services"] as ModuleId[]).map((id) => <button key={id} className={active === id ? "selected" : ""} onClick={() => setActive(id)}><span>{iconFor(id)}</span>{modules.find((m) => m.id === id)?.title.split(" ")[0]}</button>)}
        </nav>
      </main>
      {dialogOpen && <div className="modal-backdrop" role="presentation" onMouseDown={(e) => { if (e.target === e.currentTarget) setDialogOpen(false); }}>
        <div className="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title">
          <div className="modal-head"><div><span className="eyebrow">NOUVELLE OPÉRATION · APERÇU</span><h2 id="modal-title">{selected.action}</h2></div><button className="icon-button" onClick={() => setDialogOpen(false)}>×</button></div>
          <form onSubmit={(e) => { e.preventDefault(); addLocalEntry(); }}>
            <label>Nom / référence<input autoFocus value={draftTitle} onChange={(e) => setDraftTitle(e.target.value)} required placeholder="Ex. Référence de l'opération" /></label>
            <label>Détails<textarea rows={3} value={draftDetail} onChange={(e) => setDraftDetail(e.target.value)} placeholder="Informations complémentaires" /></label>
            <div className="notice">Brouillon local : aucun encaissement, ticket ou rendez-vous réel n'est créé.</div>
            <div className="modal-actions"><button type="button" className="btn secondary" onClick={() => setDialogOpen(false)}>Annuler</button><button className="btn primary">Ajouter à l'aperçu</button></div>
          </form>
        </div>
      </div>}
    </div>
  );
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
function GenericPage({ active, entries, copy }: { active: ModuleId; entries: Entry[]; copy: typeof moduleCopy[ModuleId] }) {
  return <div className="module-layout">
    <div className="module-main-card"><div className="module-card-head"><div><span className="eyebrow">PÉRIMÈTRE FONCTIONNEL</span><h2>Fonctions prévues</h2></div><span className="status-tag pending">À connecter</span></div>
      <div className="feature-list">{copy.features.map((feature, i) => <div className="feature-row" key={feature}><span className="feature-number">{String(i + 1).padStart(2, "0")}</span><span>{feature}</span><span className="feature-check">◇</span></div>)}</div>
    </div>
    <div className="module-main-card"><div className="module-card-head"><div><span className="eyebrow">SESSION EN COURS</span><h2>Brouillons locaux</h2></div><span className="status-tag local">Local</span></div>
      {entries.length === 0 ? <Empty text={copy.empty} /> : <div className="record-list">{entries.map((entry) => <Record key={entry.id} entry={entry} />)}</div>}
    </div>
  </div>;
}
function AgendaPage({ entries }: { entries: Entry[] }) {
  return <div className="module-layout"><div className="module-main-card"><div className="module-card-head"><div><span className="eyebrow">PLANNING</span><h2>Vue des créneaux</h2></div><span className="status-tag pending">Planning non synchronisé</span></div><div className="calendar-strip">{["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"].map((d, i) => <div key={d} className={i === 2 ? "today" : ""}><small>{d}</small><strong>{String(i + 20).padStart(2, "0")}</strong></div>)}</div><div className="schedule-empty"><span className="empty-glyph">◷</span><strong>Aucun créneau chargé</strong><p>Les horaires, absences, postes et rendez-vous apparaîtront après synchronisation.</p></div></div><div className="module-main-card"><h2>Demandes de rendez-vous locales</h2>{entries.length ? entries.map((e) => <Record key={e.id} entry={e} />) : <Empty text="Aucune demande créée dans cette session." />}</div></div>;
}
function PressingPage({ entries, onAdvance }: { entries: Entry[]; onAdvance: (id: string) => void }) {
  return <div className="module-layout"><div className="module-main-card"><div className="module-card-head"><div><span className="eyebrow">SUIVI DES TICKETS</span><h2>Étapes de traitement</h2></div><span className="status-tag pending">Données locales</span></div><div className="pressing-steps">{["Reçu", "En cours", "Prêt", "Retiré"].map((step, i) => <div key={step}><span>{i + 1}</span><strong>{step}</strong></div>)}</div><p className="muted">Une transition réelle exigera le contrôle des permissions et l'ajout d'un événement d'historique.</p></div><div className="module-main-card"><h2>Tickets de cette session</h2>{entries.length ? entries.map((e) => <div className="record-row" key={e.id}><Record entry={e} /><button className="btn secondary" onClick={() => onAdvance(e.id)} disabled={e.state === "Retiré"}>Avancer l'aperçu</button></div>) : <Empty text="Aucun ticket local. Créez un brouillon depuis le bouton principal." />}</div></div>;
}
function CashPage({ entries }: { entries: Entry[] }) {
  return <div className="module-layout"><div className="module-main-card"><div className="module-card-head"><div><span className="eyebrow">SESSION CAISSE</span><h2>Registre non ouvert</h2></div><span className="status-tag pending">À connecter</span></div><div className="cash-summary"><div><small>Fonds d'ouverture</small><strong>—</strong></div><div><small>Encaissements</small><strong>—</strong></div><div><small>Écart</small><strong>—</strong></div></div><div className="notice">Les montants ne sont pas calculés dans cet aperçu. Une session réelle sera ouverte sur le serveur et rattachée à une caisse et un opérateur.</div></div><div className="module-main-card"><h2>Ventes de cette session</h2>{entries.length ? entries.map((e) => <Record key={e.id} entry={e} />) : <Empty text="Aucune vente locale. Aucun paiement n'a été confirmé." />}</div></div>;
}
function OrganizationPage({ mode, setMode, siteName, setSiteName }: { mode: BusinessMode; setMode: (mode: BusinessMode) => void; siteName: string; setSiteName: (s: string) => void }) {
  return <div className="structure-grid"><div className="module-main-card"><span className="eyebrow">ARCHITECTURE DE GESTION</span><h2>Choisir le modèle de votre entreprise</h2><div className="mode-options">
    <button className={mode === "solo" ? "mode-option selected" : "mode-option"} onClick={() => setMode("solo")}><b>01 · PME autonome</b><strong>Un établissement indépendant</strong><small>Un point de vente, une organisation et ses propres opérations.</small></button>
    <button className={mode === "single_site_multi_workstation" ? "mode-option selected" : "mode-option"} onClick={() => setMode("single_site_multi_workstation")}><b>02 · Responsable multi-emplacements</b><strong>Plusieurs postes dans un même lieu</strong><small>Planning et affectations par poste ; caisse et stock partagés par établissement par défaut.</small></button>
    <button className={mode === "multi_site_network" ? "mode-option selected" : "mode-option"} onClick={() => setMode("multi_site_network")}><b>03 · Promoteur multi-sites</b><strong>Plusieurs points de vente autonomes</strong><small>Consolidation réseau, mais caisses, stocks, équipes et opérations distincts.</small></button>
  </div></div><div className="module-main-card"><span className="eyebrow">ÉTABLISSEMENT PRINCIPAL</span><h2>Profil de l'entreprise</h2><label>Nom du point de vente<input value={siteName} onChange={(e) => setSiteName(e.target.value)} /></label><div className="notice">Cette modification reste locale à la session d'aperçu. La fiche légale et l'enregistrement serveur ne sont pas raccordés.</div></div></div>;
}
function SitesPage({ mode, siteName, entries }: { mode: BusinessMode; siteName: string; entries: Entry[] }) {
  return <div className="module-layout"><div className="module-main-card"><span className="eyebrow">PÉRIMÈTRE RÉSEAU</span><h2>Points de vente sous contrôle</h2><div className="site-list"><div className="site-row"><span className="site-dot" /><div><strong>{siteName}</strong><small>Point principal · données non synchronisées</small></div><span className="status-tag local">Actuel</span></div>{entries.map((e) => <Record key={e.id} entry={e} />)}</div><p className="muted">Mode actif : {modeLabel(mode)}. Les sites supplémentaires ne sont pas inventés ; ils doivent être créés par un responsable autorisé.</p></div><div className="module-main-card"><h2>Principes d'autonomie</h2><ul className="brief-list"><li>Une caisse et des clôtures propres à chaque site.</li><li>Un stock et un historique de mouvements par site.</li><li>Une équipe et des affectations distinctes.</li><li>Une consolidation réseau sans mutation cross-site implicite.</li></ul></div></div>;
}
function WorkstationsPage({ mode }: { mode: BusinessMode }) {
  return <div className="module-layout"><div className="module-main-card"><span className="eyebrow">POSTES & RESSOURCES</span><h2>Emplacements d'un même établissement</h2><div className="workstation-grid">{["Fauteuil coiffure", "Atelier pressing", "Comptoir réception", "Caisse"].map((w, i) => <div className="workstation-card" key={w}><span>0{i + 1}</span><strong>{w}</strong><small>À configurer</small></div>)}</div><p className="muted">Ces cartes représentent des types d'emplacements disponibles, pas des ressources déjà créées.</p></div><div className="module-main-card"><h2>Règle de périmètre</h2><p>Un responsable d'emplacements peut gérer plusieurs postes dans le même point de vente, sans obtenir un accès automatique aux autres sites du réseau.</p><span className="status-tag local">{modeLabel(mode)}</span></div></div>;
}
function Empty({ text }: { text: string }) { return <div className="empty-state"><span className="empty-glyph">◌</span><strong>Tout est prêt pour commencer</strong><p>{text}</p></div>; }
function Record({ entry }: { entry: Entry }) { return <div className="record"><div><strong>{entry.title}</strong><small>{entry.detail || entry.createdAt}</small></div><span className="status-tag local">{entry.state}</span></div>; }

createRoot(document.getElementById("root")!).render(<React.StrictMode><App /></React.StrictMode>);
