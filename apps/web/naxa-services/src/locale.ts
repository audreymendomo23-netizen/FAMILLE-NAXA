export type Locale = "fr" | "en" | "ff-CM";
export const LANGUAGES: readonly Locale[] = ["fr","en","ff-CM"];
export function localeOf(value: unknown): Locale { return value === "en" || value === "ff-CM" ? value : "fr"; }
const catalogue: Record<string, readonly [string,string]> = {
  "Bienvenue": [
    "Welcome",
    "A jaɓɓaama"
  ],
  "Content de vous revoir.": [
    "Welcome back.",
    "A jaɓɓaama."
  ],
  "Accédez à votre espace professionnel.": [
    "Access your workspace.",
    "Naatu e nokkuure golle maa."
  ],
  "Identifiant NAXA Services": [
    "NAXA Services ID",
    "Innol NAXA Services"
  ],
  "Mot de passe": [
    "Password",
    "Finnde"
  ],
  "Se connecter": [
    "Sign in",
    "Naatu"
  ],
  "Déconnexion": [
    "Sign out",
    "Yaltu"
  ],
  "Mot de passe oublié ?": [
    "Forgot password?",
    "A yejjitii finnde maa?"
  ],
  "Récupérer mon accès": [
    "Recover access",
    "Heɓtu naatugol maa"
  ],
  "Votre responsable vous aidera à retrouver votre accès.": [
    "Your manager can help you regain access.",
    "Hooreejo maa maa wallu ma."
  ],
  "Note au responsable (facultatif)": [
    "Note to the manager (optional)",
    "Ɓatakuru to hooreejo (so a yiɗi)"
  ],
  "Expliquez brièvement votre demande": [
    "Briefly explain your request",
    "Haal duŋ ko a yiɗi"
  ],
  "Envoyer la demande": [
    "Submit request",
    "Neldu ɗaɓɓitannde"
  ],
  "Retour à la connexion": [
    "Back to sign in",
    "Rutto to naatugol"
  ],
  "Découvrir NAXA Services": [
    "Explore NAXA Services",
    "Yiy NAXA Services"
  ],
  "ASSISTANCE D'ACCÈS": [
    "ACCESS HELP",
    "BALLAL NAATUGOL"
  ],
  "ESPACE SÉCURISÉ": [
    "SECURE WORKSPACE",
    "NOKKUURE KISAL"
  ],
  "GESTION INTELLIGENTE DES PRESTATIONS": [
    "SMART SERVICE MANAGEMENT",
    "ƊOWTUGOL GOLLE"
  ],
  "Votre établissement.": [
    "Your business.",
    "Golle maa."
  ],
  "Maîtrisé.": [
    "Under control.",
    "E juuɗe maa."
  ],
  "Pressing, coiffure, équipes, caisse et points de vente réunis dans un espace professionnel.": [
    "Laundry, hairdressing, teams, cash and locations in one workspace.",
    "Lootugol, ñaawugol sukundu, golluɓe e ceede e nokkuure wootere."
  ],
  "Des opérations suivies de bout en bout": [
    "Track your operations from start to finish",
    "Rewindo golle maa"
  ],
  "Une autonomie par établissement": [
    "Independent management for each location",
    "Nokkuure kala e golle mum"
  ],
  "Une vision réseau sans mélange des caisses": [
    "Network overview with separate registers",
    "Yiy nokkuuji maa, ceede kala seerɗe"
  ],
  "Mode sécurisé": [
    "Secure mode",
    "Kisal"
  ],
  "Mode clair": [
    "Light mode",
    "Jayngol"
  ],
  "Mode nuit": [
    "Night mode",
    "Jemma"
  ],
  "Mode sombre": [
    "Dark mode",
    "Niɓɓere"
  ],
  "Traitement…": [
    "Processing…",
    "Nana golla…"
  ],
  "Langue": [
    "Language",
    "Ɗemngal"
  ],
  "ESPACE DE TRAVAIL": [
    "WORKSPACE",
    "NOKKUURE GOLLE"
  ],
  "Point de vente actif": [
    "Active location",
    "Nokkuure jaaygol"
  ],
  "Tous les modules": [
    "All modules",
    "Golle fof"
  ],
  "Fermer le menu": [
    "Close menu",
    "Uddu doggol"
  ],
  "Aide": [
    "Help",
    "Ballal"
  ],
  "Connecté": [
    "Signed in",
    "A naatii"
  ],
  "Non connecté": [
    "Signed out",
    "A yaltii"
  ],
  "Démonstration": [
    "Demo",
    "Ƴeewndugol"
  ],
  "Changement du mot de passe requis": [
    "Password change required",
    "Waylu finnde maa"
  ],
  "Vue d'ensemble": [
    "Overview",
    "Yiyde fof"
  ],
  "Agenda & rendez-vous": [
    "Calendar & appointments",
    "Ɗaɓɓitanɗe e sahaa"
  ],
  "Pressing": [
    "Laundry",
    "Lootugol"
  ],
  "Dossiers métier": [
    "Work orders",
    "Golle"
  ],
  "Caisse & ventes": [
    "Cash & sales",
    "Ceede e jaaygol"
  ],
  "Catalogue de prestations": [
    "Service catalogue",
    "Doggol golle"
  ],
  "Clients & fidélité": [
    "Customers & loyalty",
    "Soottotooɓe"
  ],
  "Équipe & commissions": [
    "Team & commissions",
    "Golluɓe e ceede"
  ],
  "Consommables": [
    "Supplies",
    "Jawdi golle"
  ],
  "Rapports & comptabilité": [
    "Reports & accounting",
    "Jaŋtol e limtol ceede"
  ],
  "PME & organisation": [
    "Business & organization",
    "Golle e fedde"
  ],
  "Réseau multi-sites": [
    "Location network",
    "Nokkuuji"
  ],
  "Points de vente": [
    "Locations",
    "Nokkuuji jaaygol"
  ],
  "Emplacements & postes": [
    "Workstations",
    "Nokkuuji golle"
  ],
  "Sécurité & appareils": [
    "Security & devices",
    "Kisal e kaɓirɗe"
  ],
  "Paramètres": [
    "Settings",
    "Teelte"
  ],
  "Assistance & briefings": [
    "Help & briefings",
    "Ballal e jaŋtol"
  ],
  "Pilotage": [
    "Management",
    "Ɗowtugol"
  ],
  "Opérations": [
    "Operations",
    "Golle"
  ],
  "Finance": [
    "Finance",
    "Ceede"
  ],
  "Référentiels": [
    "Catalogue",
    "Doggol"
  ],
  "Relation client": [
    "Customer relations",
    "Soottotooɓe"
  ],
  "Ressources": [
    "Resources",
    "Jawdi"
  ],
  "Organisation": [
    "Organization",
    "Fedde"
  ],
  "Sécurité": [
    "Security",
    "Kisal"
  ],
  "Système": [
    "Settings",
    "Teelte"
  ],
  "Actualiser la vue": [
    "Refresh overview",
    "Hesɗitin yiyde"
  ],
  "Nouveau rendez-vous": [
    "New appointment",
    "Sahaa keso"
  ],
  "Créer un ticket": [
    "Create ticket",
    "Sos kayit"
  ],
  "Créer un dossier métier": [
    "Create work order",
    "Sos golle"
  ],
  "Nouvelle dépense": [
    "New expense",
    "Njoɓdi hesere"
  ],
  "Ajouter une prestation": [
    "Add service",
    "Ɓeydu golle"
  ],
  "Créer une fiche client": [
    "Create customer",
    "Ɓeydu soottotooɗo"
  ],
  "Ajouter un membre": [
    "Add team member",
    "Ɓeydu gollotooɗo"
  ],
  "Ajouter un article": [
    "Add item",
    "Ɓeydu jawdi"
  ],
  "Préparer un rapport": [
    "Prepare report",
    "Heblu jaŋtol"
  ],
  "Modifier le profil": [
    "Edit profile",
    "Waylu humpito"
  ],
  "Ajouter un point de vente": [
    "Add location",
    "Ɓeydu nokkuure jaaygol"
  ],
  "Créer un site": [
    "Create location",
    "Sos nokkuure"
  ],
  "Ajouter un emplacement": [
    "Add workstation",
    "Ɓeydu nokkuure golle"
  ],
  "Ouvrir le journal": [
    "Open activity log",
    "Uddit jaŋtol"
  ],
  "Gérer les paramètres": [
    "Manage settings",
    "Teeltu"
  ],
  "Créer une demande": [
    "Create request",
    "Sos ɗaɓɓitannde"
  ],
  "Votre activité, au même endroit.": [
    "Your business, in one place.",
    "Golle maa e nokkuure wootere."
  ],
  "Retrouvez vos chiffres et vos objectifs.": [
    "Find your figures and goals.",
    "Yiy limooje e faandaare maa."
  ],
  "PILOTAGE": [
    "MANAGEMENT",
    "ƊOWTUGOL"
  ],
  "VOTRE ESPACE DE GESTION": [
    "YOUR MANAGEMENT WORKSPACE",
    "NOKKUURE GOLLE MAA"
  ],
  "Une journée bien organisée commence ici.": [
    "A well-organized day starts here.",
    "Ñalawma moƴƴo fuɗɗata ɗoo."
  ],
  "Retrouvez vos activités, vos objectifs et vos priorités.": [
    "Find your activities, goals and priorities.",
    "Yiy golle e faandaare maa."
  ],
  "Rendez-vous aujourd'hui": [
    "Today's appointments",
    "Sahaaaji hannde"
  ],
  "Tickets à rendre": [
    "Tickets due",
    "Kayite yoɓteede"
  ],
  "Caisse du jour": [
    "Today's cash",
    "Ceede hannde"
  ],
  "Équipe présente": [
    "Team present",
    "Golluɓe ɗoo"
  ],
  "En attente de confirmation": [
    "Awaiting confirmation",
    "Nana fadi ƴeewtagol"
  ],
  "Aucun solde disponible": [
    "No balance available",
    "Alaa ceede hollitaande"
  ],
  "Aucun pointage disponible": [
    "No attendance recorded",
    "Alaa winndannde naatugol"
  ],
  "Accès rapides": [
    "Quick access",
    "Naatugol yaawngol"
  ],
  "VOTRE ACTIVITÉ": [
    "YOUR BUSINESS",
    "GOLLE MAA"
  ],
  "Ouvrir": [
    "Open",
    "Uddit"
  ],
  "Actualiser": [
    "Refresh",
    "Hesɗitin"
  ],
  "Indisponible": [
    "Unavailable",
    "Alaa jooni"
  ],
  "Bienvenue dans votre espace.": [
    "Welcome to your workspace.",
    "A jaɓɓaama e nokkuure golle maa."
  ],
  "Session fermée.": [
    "Signed out.",
    "A yaltii."
  ],
  "Identifiant ou mot de passe incorrect.": [
    "Incorrect ID or password.",
    "Innol walla finnde feewaani."
  ],
  "Connexion impossible.": [
    "Unable to sign in.",
    "Naatugol waawataa."
  ],
  "Fermer la session": [
    "Sign out",
    "Yaltu"
  ],
  "Créer un nouveau mot de passe": [
    "Create a new password",
    "Sos finnde hesere"
  ],
  "Mot de passe actuel": [
    "Current password",
    "Finnde jooni"
  ],
  "Nouveau mot de passe": [
    "New password",
    "Finnde hesere"
  ],
  "Confirmer le nouveau mot de passe": [
    "Confirm new password",
    "Tabbitin finnde hesere"
  ],
  "Enregistrer le nouveau mot de passe": [
    "Save new password",
    "Danndu finnde hesere"
  ],
  "Choisissez un mot de passe d'au moins 10 caractères.": [
    "Choose a password of at least 10 characters.",
    "Suɓo finnde binndi sappo walla ɓuri."
  ],
  "Langue enregistrée.": [
    "Language saved.",
    "Ɗemngal danndaama."
  ],
  "Impossible de modifier la langue.": [
    "Unable to change language.",
    "Waylugol ɗemngal waawataa."
  ],
  "Tout est prêt pour commencer": [
    "Ready to get started",
    "Fof hebiima ngam fuɗɗaade"
  ],
  "Enregistrer": [
    "Save",
    "Danndu"
  ],
  "Annuler": [
    "Cancel",
    "Haaytu"
  ],
  "Nom du client": [
    "Customer name",
    "Innde soottotooɗo"
  ],
  "Téléphone facultatif": [
    "Phone (optional)",
    "Telefon (so a yiɗi)"
  ],
  "Activité, alertes et briefings de l'établissement.": [
    "Business activity, alerts and briefings.",
    "Golle, tintine e jaŋtol."
  ],
  "Créneaux par prestataire, poste, date et point de vente.": [
    "Appointments by provider, workstation, date and location.",
    "Sahaaaji gollotooɗo e nokkuure."
  ],
  "Tickets, pièces, étapes de traitement et retraits.": [
    "Tickets, items, processing and collection.",
    "Kayite, jawdi e golle."
  ],
  "Ventes, paiements, reçus, dépenses et clôtures.": [
    "Sales, payments, receipts, expenses and closing.",
    "Jaaygol, njoɓdi, kayite e ceede."
  ],
  "Tarifs, durées, habilitations, forfaits et produits comptoir.": [
    "Prices, durations, skills, packages and products.",
    "Njoɓdi, sahaa e jawdi."
  ],
  "Mode d'exploitation": [
    "Operating model",
    "No golle ɗowtirtee"
  ],
  "Configurer la structure": [
    "Configure business",
    "Teeltu golle"
  ],
  "À préparer": [
    "To prepare",
    "Ko hebletee"
  ],
  "Indicateurs à venir": [
    "Upcoming figures",
    "Limooje aranteeje"
  ],
  "Vos indicateurs apparaîtront dès que les données seront disponibles.": [
    "Your figures will appear when data is available.",
    "Limooje maa njiyete so humpito heɓaama."
  ],
  "Connexion sécurisée": [
    "Secure sign in",
    "Naatugol e kisal"
  ],
  "PROTECTION DU COMPTE": [
    "ACCOUNT PROTECTION",
    "KISAL KONTE"
  ],
  "CHANGEMENT OBLIGATOIRE": [
    "REQUIRED CHANGE",
    "WAYLUGOL WAAJIB"
  ],
  "Votre identité est authentifiée": [
    "Your identity is verified",
    "Innol maa ƴeewtaama"
  ],
  "Le mot de passe initial doit être remplacé avant tout accès aux pages de gestion.": [
    "Change the initial password before accessing your workspace.",
    "Waylu finnde arande hade naatugol."
  ],
  "Une dernière": [
    "One last",
    "Goɗɗum gootum"
  ],
  "étape.": [
    "step.",
    "timmude."
  ],
  "Vérification…": [
    "Checking…",
    "Nana ƴeewta…"
  ],
  "Aucune opération pour le moment.": [
    "No operations yet.",
    "Alaa golle jooni."
  ]
};
export function translate(locale:Locale, text:string):string { if(locale==="fr")return text;return catalogue[text]?.[locale==="en"?0:1]??text; }
