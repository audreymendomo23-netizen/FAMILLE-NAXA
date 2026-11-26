import { createContext, useContext } from "react";
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
  ],
  "PLANNING": [
    "CALENDAR",
    "SAHAAAJI"
  ],
  "Rendez-vous et disponibilité": [
    "Appointments and availability",
    "Sahaaaji e heɓugol"
  ],
  "Les conflits d'horaires sont vérifiés lors de la réservation ou du report.": [
    "Schedule conflicts are checked when booking or rescheduling.",
    "Sahaaaji ƴeewtatee so a suɓii walla a wayli sahaa."
  ],
  "Réservation avec membre affecté": [
    "Booking with assigned staff",
    "Sahaa gollotooɗo"
  ],
  "Confirmation, annulation et absence": [
    "Confirmation, cancellation and absence",
    "Tabbitinol, haaytugol e ŋakkugol"
  ],
  "Report daté et contrôle des conflits": [
    "Rescheduling and conflict checks",
    "Waylugol sahaa e ƴeewtagol"
  ],
  "Rendez-vous du site": [
    "Location appointments",
    "Sahaaaji nokkuure"
  ],
  "Aucun rendez-vous chargé": [
    "No appointments loaded",
    "Alaa sahaaaji hollitaaɗi"
  ],
  "Aucun rendez-vous pour le moment.": [
    "No appointments yet.",
    "Alaa sahaaaji jooni."
  ],
  "Motif obligatoire (3 à 500 caractères)": [
    "Reason required (3 to 500 characters)",
    "Daliilu (binndi 3 haa 500)"
  ],
  "Nouvelle date et heure de début": [
    "New start date and time",
    "Ñalnde e sahaa fuɗɗagol hesere"
  ],
  "Nouvelle date et heure de fin": [
    "New end date and time",
    "Ñalnde e sahaa timmugol hesere"
  ],
  "Reporter le rendez-vous": [
    "Reschedule appointment",
    "Waylu sahaa"
  ],
  "Cette opération n'est pas modifiable pour le moment.": [
    "This operation cannot be changed yet.",
    "Golle ɗee waawaa wayleede jooni."
  ],
  "TRÉSORERIE": [
    "CASH MANAGEMENT",
    "CEEDE"
  ],
  "Registres et sessions": [
    "Registers and shifts",
    "Keesuuji ceede"
  ],
  "Créer la première caisse": [
    "Create first register",
    "Sos keesu adano"
  ],
  "Code unique": [
    "Unique code",
    "Innol keeriiɗol"
  ],
  "Nom du registre": [
    "Register name",
    "Innde keesu"
  ],
  "Créer le registre": [
    "Create register",
    "Sos keesu"
  ],
  "La création d'un registre exige le droit de gestion du site.": [
    "Only authorized managers can create a register.",
    "Hooreeɓe yamiraaɓe tan mbaawi sosde keesu."
  ],
  "Création en attente de confirmation.": [
    "Creation awaiting confirmation.",
    "Nana fadi tabbitinol."
  ],
  "Ouvrir une session": [
    "Open a shift",
    "Uddit sahaa golle"
  ],
  "Registre": [
    "Register",
    "Keesu"
  ],
  "Fonds d'ouverture (FCFA)": [
    "Opening cash (XAF)",
    "Ceede fuɗɗagol (FCFA)"
  ],
  "Ouvrir la caisse": [
    "Open register",
    "Uddit keesu"
  ],
  "Une session est déjà ouverte sur ce registre. Fermez-la avant d'en ouvrir une autre.": [
    "This register is already open. Close it before opening another.",
    "Keesu nguu udditaama. Uddu ngu hade udditde goɗɗu."
  ],
  "L’ouverture de cette caisse est en attente de confirmation.": [
    "Register opening is awaiting confirmation.",
    "Udditugol keesu nana fadi tabbitinol."
  ],
  "Session actuellement ouverte": [
    "Current open shift",
    "Sahaa golle udditiiɗo"
  ],
  "Registre à clôturer": [
    "Register to close",
    "Keesu uddeteengu"
  ],
  "Montant compté à la clôture (FCFA)": [
    "Cash counted at closing (XAF)",
    "Ceede limtaaɗe e timmugol (FCFA)"
  ],
  "Motif d'écart (si nécessaire)": [
    "Difference reason (if needed)",
    "Daliilu seertugol (so ena sokli)"
  ],
  "Clôturer et calculer l'écart": [
    "Close and calculate difference",
    "Uddu e limtu seertugol"
  ],
  "VENTES AU COMPTOIR": [
    "COUNTER SALES",
    "JAAYGOL"
  ],
  "Enregistrer un encaissement reçu": [
    "Record received payment",
    "Danndu ceede keɓaaɗe"
  ],
  "Saisie manuelle": [
    "Manual entry",
    "Winndugol"
  ],
  "Saisissez uniquement les fonds déjà reçus. Cette action n'effectue aucun transfert d'argent.": [
    "Enter only funds already received. No money is transferred.",
    "Winndu tan ceede keɓaaɗe. Ceede neldaaka."
  ],
  "Session ouverte": [
    "Open shift",
    "Sahaa golle udditiiɗo"
  ],
  "Désignation vendue": [
    "Item sold",
    "Jawdi jaayndi"
  ],
  "Article en stock (facultatif)": [
    "Stock item (optional)",
    "Jawdi (so a yiɗi)"
  ],
  "Prestation / vente sans sortie stock": [
    "Service / sale without stock movement",
    "Golle / jaaygol tawa jawdi yaltaaki"
  ],
  "Quantité sortie": [
    "Quantity issued",
    "Keewal yaltungal"
  ],
  "Mode d’encaissement reçu": [
    "Payment method received",
    "Laawol heɓugol ceede"
  ],
  "Espèces": [
    "Cash",
    "Ceede e juuɗe"
  ],
  "Mobile Money (externe)": [
    "Mobile Money (external)",
    "Mobile Money"
  ],
  "Total encaissé (FCFA)": [
    "Total received (XAF)",
    "Ceede keɓaaɗe fof (FCFA)"
  ],
  "Enregistrer la vente comptant": [
    "Record cash sale",
    "Danndu jaaygol"
  ],
  "Dernières opérations": [
    "Latest operations",
    "Golle sakkitiiɗe"
  ],
  "FOURNISSEURS": [
    "SUPPLIERS",
    "HOKKOOƁE JAWDI"
  ],
  "Référentiel fournisseur": [
    "Supplier directory",
    "Doggol hokkooɓe jawdi"
  ],
  "Nom du fournisseur": [
    "Supplier name",
    "Innde hokkooɗo jawdi"
  ],
  "Téléphone": [
    "Phone",
    "Telefon"
  ],
  "Adresse": [
    "Address",
    "Nokkuure"
  ],
  "Délai de paiement (jours)": [
    "Payment term (days)",
    "Sahaa yoɓde (balɗe)"
  ],
  "Enregistrer le fournisseur": [
    "Save supplier",
    "Danndu hokkooɗo jawdi"
  ],
  "Mouvements de consommables": [
    "Stock movements",
    "Dirtugol jawdi"
  ],
  "Article": [
    "Item",
    "Jawdi"
  ],
  "Choisir un article": [
    "Choose item",
    "Suɓo jawdi"
  ],
  "Nature du mouvement": [
    "Movement type",
    "Fannu dirtugol"
  ],
  "Entrée": [
    "Incoming",
    "Naatugol"
  ],
  "Consommation": [
    "Consumption",
    "Huutoraade"
  ],
  "Perte": [
    "Loss",
    "Majjugol"
  ],
  "Ajustement signé": [
    "Signed adjustment",
    "Peewngol"
  ],
  "Quantité": [
    "Quantity",
    "Keewal"
  ],
  "Motif": [
    "Reason",
    "Daliilu"
  ],
  "Enregistrer le mouvement": [
    "Save movement",
    "Danndu dirtugol"
  ],
  "ACHATS ET RÉCEPTIONS": [
    "PURCHASES AND RECEIPTS",
    "SOODUGOL E HEƁUGOL"
  ],
  "Commander auprès d'un fournisseur": [
    "Order from supplier",
    "Ɗaɓɓu jawdi"
  ],
  "Fournisseur": [
    "Supplier",
    "Hokkooɗo jawdi"
  ],
  "Choisir": [
    "Choose",
    "Suɓo"
  ],
  "Article commandé": [
    "Ordered item",
    "Jawdi ɗaɓɓitaandi"
  ],
  "Référence de commande": [
    "Order reference",
    "Innol ɗaɓɓitannde"
  ],
  "Quantité commandée": [
    "Quantity ordered",
    "Keewal ɗaɓɓitaangal"
  ],
  "Coût unitaire (FCFA)": [
    "Unit cost (XAF)",
    "Njoɓdi gootal (FCFA)"
  ],
  "Valider la commande fournisseur": [
    "Confirm supplier order",
    "Tabbitin ɗaɓɓitannde jawdi"
  ],
  "La commande fournisseur exige le droit de gestion du site.": [
    "Only authorized managers may place supplier orders.",
    "Hooreeɓe yamiraaɓe tan mbaawi ɗaɓɓude jawdi."
  ],
  "Réception et règlement": [
    "Receipt and payment",
    "Heɓugol e yoɓugol"
  ],
  "Commande à réceptionner": [
    "Order to receive",
    "Ɗaɓɓitannde heɓetende"
  ],
  "Choisir une commande": [
    "Choose order",
    "Suɓo ɗaɓɓitannde"
  ],
  "Quantité reçue": [
    "Quantity received",
    "Keewal heɓaangal"
  ],
  "Enregistrer la réception partielle ou complète": [
    "Record partial or full receipt",
    "Danndu jawdi heɓaandi"
  ],
  "Montant du règlement bancaire (FCFA)": [
    "Bank payment amount (XAF)",
    "Ceede yoɓaaɗe e banki (FCFA)"
  ],
  "Référence bancaire": [
    "Bank reference",
    "Innol banki"
  ],
  "Enregistrer un règlement bancaire": [
    "Record bank payment",
    "Danndu njoɓdi banki"
  ],
  "Journal stock / achats": [
    "Stock / purchase log",
    "Jaŋtol jawdi e soodugol"
  ],
  "PRÉSENCE & TEMPS": [
    "ATTENDANCE & TIME",
    "NAATUGOL E SAHAA"
  ],
  "Pointage de l'utilisateur connecté": [
    "Your attendance",
    "Naatugol maa"
  ],
  "Pointez votre arrivée, vos pauses, votre reprise et votre départ dans cet ordre.": [
    "Record arrival, breaks, return and departure in order.",
    "Winndu naatugol, fooftugol, ruttugol e yaltugol."
  ],
  "Aucun pointage aujourd'hui": [
    "No attendance today",
    "Alaa naatugol hannde"
  ],
  "Commence par pointer ton arrivée.": [
    "Start by recording your arrival.",
    "Fuɗɗo e winndugol naatugol maa."
  ],
  "Attendez la confirmation du dernier pointage avant de poursuivre.": [
    "Wait for the last attendance confirmation before continuing.",
    "Fad tabbitinol hade jokkude."
  ],
  "Historique": [
    "History",
    "Jaŋtol"
  ],
  "Aucun pointage disponible.": [
    "No attendance available.",
    "Alaa winndannde naatugol."
  ],
  "RELATION CLIENT": [
    "CUSTOMER RELATIONS",
    "SOOTTOTOOƁE"
  ],
  "Créer un suivi": [
    "Create follow-up",
    "Sos rewindo"
  ],
  "Crée ou synchronise d'abord une fiche client pour pouvoir lui rattacher un suivi.": [
    "Create or refresh a customer record before adding a follow-up.",
    "Sos humpito soottotooɗo hade rewindo."
  ],
  "Client": [
    "Customer",
    "Soottotooɗo"
  ],
  "Choisir une fiche": [
    "Choose record",
    "Suɓo humpito"
  ],
  "Objet du suivi": [
    "Follow-up subject",
    "Ko rewindo"
  ],
  "Fréquence": [
    "Frequency",
    "Sahaa"
  ],
  "Canal": [
    "Channel",
    "Laawol"
  ],
  "Notes": [
    "Notes",
    "Ɓatakuuji"
  ],
  "Prochaine échéance": [
    "Next due date",
    "Ñalnde aroore"
  ],
  "Créer le suivi client": [
    "Create customer follow-up",
    "Sos rewindo soottotooɗo"
  ],
  "Fiches clients": [
    "Customer records",
    "Humpito soottotooɓe"
  ],
  "Aucune fiche client dans le site actif.": [
    "No customer records at this location.",
    "Alaa humpito soottotooɓe e nokkuure ndee."
  ],
  "Suivis enregistrés": [
    "Saved follow-ups",
    "Rewindo danndaaɗe"
  ],
  "Note de réalisation": [
    "Completion note",
    "Ɓatakuru timmugol"
  ],
  "Prochaine échéance (facultative, suivi récurrent)": [
    "Next due date (optional, recurring follow-up)",
    "Ñalnde aroore (so a yiɗi)"
  ],
  "Aucun suivi client synchronisé.": [
    "No customer follow-ups available.",
    "Alaa rewindo soottotooɓe."
  ],
  "ABONNEMENT NAXA SERVICES": [
    "NAXA SERVICES SUBSCRIPTION",
    "ABONMAN NAXA SERVICES"
  ],
  "Abonnement et règlement": [
    "Subscription and payment",
    "Abonman e njoɓdi"
  ],
  "Ce paiement concerne exclusivement votre abonnement NAXA. Les encaissements de votre entreprise restent externes et sont saisis dans la caisse ERP.": [
    "This payment is for your NAXA subscription only. Record your own business payments separately.",
    "Njoɓdi ɗee ko abonman NAXA tan. Winndu ceede golle maa seertunde."
  ],
  "Vérifier les droits payés": [
    "Check paid access",
    "Ƴeewto abonman maa"
  ],
  "Règlement réservé au Promoteur authentifié.": [
    "Only the business owner may pay.",
    "Jom golle tan waawi yoɓde."
  ],
  "Consulter mon abonnement": [
    "View my subscription",
    "Yiy abonman am"
  ],
  "Formule": [
    "Plan",
    "Fannu abonman"
  ],
  "PREMIUM requis pour une organisation multi-postes ou multisite.": [
    "PREMIUM is required for multiple workstations or locations.",
    "PREMIUM soklaa so nokkuuji keewi."
  ],
  "Durée": [
    "Duration",
    "Sahaa"
  ],
  "Mensuelle": [
    "Monthly",
    "Lewru"
  ],
  "Annuelle": [
    "Annual",
    "Hitaande"
  ],
  "Opérateur": [
    "Provider",
    "Hokkooɗo"
  ],
  "Obtenir le montant et la destination": [
    "Get amount and payment destination",
    "Yiy ceede e nokkuure yoɓde"
  ],
  "Aucune destination NAXA n’est activée. Ne payez pas sur un autre compte.": [
    "No NAXA payment destination is active. Do not pay another account.",
    "Alaa nokkuure yoɓde NAXA. Hoto yoɓ konte goɗɗo."
  ],
  "Ouvrir le composeur": [
    "Open dialler",
    "Uddit telefon"
  ],
  "Numéro du payeur": [
    "Payer phone number",
    "Tonngoode telefon yoɓooɗo"
  ],
  "Date et heure du paiement (Cameroun)": [
    "Payment date and time (Cameroon)",
    "Ñalnde e sahaa njoɓdi (Kameruun)"
  ],
  "SMS de débit de cette transaction uniquement": [
    "Debit SMS for this payment only",
    "SMS njoɓdi ɗee tan"
  ],
  "Déclarer le paiement": [
    "Declare payment",
    "Hollu njoɓdi"
  ],
  "Je confirme n’avoir effectué aucun paiement pour cette demande.": [
    "I confirm I have not paid this request.",
    "Mi tabbitinii mi yoɓaani ɗaɓɓitannde ndee."
  ],
  "Abandonner la demande non payée": [
    "Cancel unpaid request",
    "Haaytu ɗaɓɓitannde nde yoɓaaka"
  ],
  "Reçu": [
    "Received",
    "Heɓaama"
  ],
  "Confirmé": [
    "Confirmed",
    "Tabbitinaama"
  ],
  "Réservé": [
    "Booked",
    "Suɓaama"
  ],
  "En attente": [
    "Pending",
    "Nana fadi"
  ],
  "Actif": [
    "Active",
    "Nana golla"
  ],
  "Ouvert": [
    "Open",
    "Udditaaɗo"
  ],
  "Clôturé": [
    "Closed",
    "Uddaaɗo"
  ],
  "Commandé": [
    "Ordered",
    "Ɗaɓɓitaama"
  ],
  "Annulé": [
    "Cancelled",
    "Haaytaama"
  ],
  "Terminé": [
    "Completed",
    "Timmii"
  ],
  "Absent": [
    "Absent",
    "Alaa ɗoo"
  ],
  "Enregistré": [
    "Saved",
    "Danndaama"
  ],
  "Refusé": [
    "Rejected",
    "Salaama"
  ],
  "Lecture seule": [
    "View only",
    "Yiyde tan"
  ],
  "Rendez-vous": [
    "Appointments",
    "Sahaaaji"
  ],
  "NAXA SERVICES · COMPTE SÉCURISÉ": [
    "NAXA SERVICES · SECURE ACCOUNT",
    "NAXA SERVICES · KONTE KISAL"
  ],
  "NAXA SERVICES · ESPACE PROFESSIONNEL": [
    "NAXA SERVICES · WORKSPACE",
    "NAXA SERVICES · NOKKUURE GOLLE"
  ],
  "DÉMONSTRATION": [
    "DEMO",
    "ƳEEWNDUGOL"
  ],
  "Essayez les fonctionnalités sans enregistrer d'opérations réelles.": [
    "Try the features without recording real transactions.",
    "Ƴeewto golle ɗee tawa golle goonga ndanndaaka."
  ],
  "Quitter l'aperçu": [
    "Exit preview",
    "Yaltu e ƴeewndugol"
  ],
  "Point de vente": [
    "Location",
    "Nokkuure jaaygol"
  ],
  "SKU (facultatif)": [
    "SKU (optional)",
    "SKU (so a yiɗi)"
  ],
  "Unité": [
    "Unit",
    "Keewal"
  ],
  "Seuil d'alerte": [
    "Alert threshold",
    "Keewal les ngam tintinol"
  ],
  "WhatsApp fournisseur": [
    "Supplier WhatsApp",
    "WhatsApp hokkooɗo jawdi"
  ],
  "L'article sera disponible après confirmation.": [
    "The item will be available after confirmation.",
    "Jawdi ndii maa heɓee caggal tabbitinol."
  ],
  "Consentement de contact obtenu": [
    "Contact consent obtained",
    "Soottotooɗo jaɓii jokkondiral"
  ],
  "Code prestation": [
    "Service code",
    "Innol golle"
  ],
  "Activité": [
    "Activity",
    "Golle"
  ],
  "Tarif FCFA": [
    "Price (XAF)",
    "Njoɓdi FCFA"
  ],
  "Description": [
    "Description",
    "Cifagol"
  ],
  "Téléphone client": [
    "Customer phone",
    "Telefon soottotooɗo"
  ],
  "Articles déposés": [
    "Items dropped off",
    "Jawdi njabbaaɗi"
  ],
  "Montant total FCFA": [
    "Total amount (XAF)",
    "Ceede fof FCFA"
  ],
  "Date promise": [
    "Promised date",
    "Ñalnde fodoonde"
  ],
  "Aucun acompte n'est encaissé dans ce parcours de création.": [
    "No deposit is collected when creating this ticket.",
    "Alaa ceede adiiɗe keɓeteeɗe e sosde kayit ngol."
  ],
  "Prestation (nom ou code)": [
    "Service (name or code)",
    "Golle (innde walla innol)"
  ],
  "Début": [
    "Start",
    "Fuɗɗagol"
  ],
  "Fin": [
    "End",
    "Timmugol"
  ],
  "Le rendez-vous sera attribué à votre compte. Vérifiez les horaires.": [
    "The appointment will be assigned to your account. Check the schedule.",
    "Sahaa oo maa jokkire e konte maa. Ƴeewto sahaaaji."
  ],
  "Montant FCFA": [
    "Amount (XAF)",
    "Ceede FCFA"
  ],
  "Date": [
    "Date",
    "Ñalnde"
  ],
  "Dépense hors caisse. Aucun paiement client ou encaissement n'est créé.": [
    "Expense outside the register. No customer payment or receipt is created.",
    "Njoɓdi tawa keesu alaa. Alaa ceede soottotooɗo keɓeteeɗe."
  ],
  "Priorité": [
    "Priority",
    "Ko ɓuri yaawde"
  ],
  "Le pointage est enregistré uniquement pour le membre authentifié.": [
    "Attendance is recorded only for the signed-in member.",
    "Naatugol winndetee ngam gollotooɗo naatiiɗo tan."
  ],
  "Détails": [
    "Details",
    "Humpito"
  ],
  "Cette démonstration ne crée aucune opération réelle.": [
    "This demo does not create real transactions.",
    "Ƴeewndugol ngol sosataa golle goonga."
  ],
  "STRUCTURE": [
    "STRUCTURE",
    "FEDDE"
  ],
  "Les données restent isolées par organisation, site et poste selon les droits attribués.": [
    "Each business and location keeps its own information, according to your permissions.",
    "Humpito fedde e nokkuure kala seertii e yamiroore maa."
  ],
  "BRIEFING DU MATIN": [
    "MORNING BRIEFING",
    "JAŊTOL SUBAKA"
  ],
  "Vérifier les rendez-vous et les créneaux.": [
    "Check appointments and time slots.",
    "Ƴeewto sahaaaji."
  ],
  "Contrôler les tickets dont la date promise approche.": [
    "Check tickets nearing their promised date.",
    "Ƴeewto kayite ɗe ñalnde mum ɓadii."
  ],
  "Ouvrir les caisses de chaque poste autorisé.": [
    "Open the registers you are authorized to use.",
    "Uddit keesuuji ɗi a yamiraa."
  ],
  "Consulter les alertes de consommables.": [
    "Review stock alerts.",
    "Yiy tintine jawdi."
  ],
  "SYNCHRONISATION": [
    "SYNC",
    "HESƊITINGOL"
  ],
  "SÉCURITÉ DU COMPTE": [
    "ACCOUNT SECURITY",
    "KISAL KONTE"
  ],
  "Mes appareils et sessions": [
    "My devices and sessions",
    "Kaɓirɗe am e naatugol"
  ],
  "Gérez les appareils connectés à votre compte. Un appareil retiré devra se reconnecter.": [
    "Manage devices connected to your account. A removed device must sign in again.",
    "Ɗowtu kaɓirɗe konte maa. Kaɓirgol ittungol foti naatude kadi."
  ],
  "Charger mes appareils": [
    "Load my devices",
    "Yiy kaɓirɗe am"
  ],
  "Aucun appareil enregistré.": [
    "No registered device.",
    "Alaa kaɓirgol danndaangol."
  ],
  "Révoquer": [
    "Remove access",
    "Ittu yamiroore"
  ],
  "Confirmer la révocation": [
    "Confirm removal",
    "Tabbitin ittugol"
  ],
  "Protection des accès": [
    "Access protection",
    "Kisal naatugol"
  ],
  "Pour protéger votre compte, déconnectez les appareils que vous ne reconnaissez pas.": [
    "Protect your account by removing devices you do not recognize.",
    "Reenu konte maa, ittu kaɓirɗe ɗe a anndaa."
  ],
  "Fonctionnalités": [
    "Features",
    "Golle"
  ],
  "Cette fonctionnalité est disponible en consultation uniquement.": [
    "This feature is view-only.",
    "Golle ɗee ko yiyde tan."
  ],
  "Vue de la semaine": [
    "Weekly view",
    "Yiyde yontere"
  ],
  "Aucun créneau disponible": [
    "No available time slot",
    "Alaa sahaa keɓeteeɗo"
  ],
  "Les rendez-vous créés ou reçus apparaissent dans le journal ci-dessous. La grille de disponibilité par membre et poste reste à connecter.": [
    "Appointments appear in the list below. Staff availability is not available here.",
    "Sahaaaji njiyete e doggol les ɗoo. Sahaaaji golluɓe kolliraaka ɗoo."
  ],
  "SUIVI DES TICKETS": [
    "TICKET TRACKING",
    "REWINDO KAYITE"
  ],
  "Étapes de traitement": [
    "Processing steps",
    "Feere golle"
  ],
  "Suivez les étapes de chaque ticket jusqu'au retrait.": [
    "Track every ticket until pickup.",
    "Rewindo kayit kala haa heɓtugol."
  ],
  "Tickets": [
    "Tickets",
    "Kayite"
  ],
  "Avancer l'aperçu": [
    "Next preview step",
    "Jokku e ƴeewndugol"
  ],
  "Motif du changement d'étape": [
    "Reason for changing step",
    "Daliilu waylugol feere"
  ],
  "Patientez jusqu'à la confirmation du ticket.": [
    "Wait until the ticket is confirmed.",
    "Fad haa kayit tabbitinee."
  ],
  "NOUVEAU DOSSIER": [
    "NEW WORK ORDER",
    "GOLLE KESEEƊE"
  ],
  "Créer une opération métier": [
    "Create work order",
    "Sos golle"
  ],
  "Client / donneur d'ordre": [
    "Customer / requester",
    "Soottotooɗo / ɗaɓɓitotooɗo"
  ],
  "Intitulé du dossier": [
    "Work order title",
    "Innde golle"
  ],
  "Sélectionner…": [
    "Select…",
    "Suɓo…"
  ],
  "Montant estimatif (FCFA)": [
    "Estimated amount (XAF)",
    "Ceede tanƴaaɗe (FCFA)"
  ],
  "Date d'échéance globale (facultatif)": [
    "Overall due date (optional)",
    "Ñalnde timmugol (so a yiɗi)"
  ],
  "Connectez-vous pour créer un dossier.": [
    "Sign in to create a work order.",
    "Naatu ngam sosde golle."
  ],
  "REGISTRE DU SITE": [
    "LOCATION REGISTER",
    "JAŊTOL NOKKUURE"
  ],
  "Dossiers enregistrés": [
    "Saved work orders",
    "Golle danndaaɗe"
  ],
  "Sessions de caisse": [
    "Cash shifts",
    "Sahaaaji keesu"
  ],
  "Dépenses": [
    "Expenses",
    "Njoɓdi"
  ],
  "Fonds d'ouverture": [
    "Opening cash",
    "Ceede fuɗɗagol"
  ],
  "Encaissements confirmés": [
    "Confirmed receipts",
    "Ceede keɓaaɗe tabbitinaaɗe"
  ],
  "Écart de clôture": [
    "Closing difference",
    "Seertugol ceede"
  ],
  "Ce formulaire enregistre une dépense, pas une vente ni un paiement client. Les ouvertures/clôtures, encaissements et reçus ne sont pas encore raccordés à cette vue.": [
    "This form records an expense only. Use the cash screen for sales, receipts and shifts.",
    "Ɗoo a winndata njoɓdi tan. Huutoro keesu ngam jaaygol, ceede e kayite njoɓdi."
  ],
  "Dépenses du journal serveur": [
    "Recorded expenses",
    "Njoɓdi danndaaɗe"
  ],
  "Période": [
    "Period",
    "Sahaa"
  ],
  "Recettes confirmées": [
    "Confirmed revenue",
    "Ceede keɓaaɗe tabbitinaaɗe"
  ],
  "Coût connu": [
    "Known cost",
    "Njoɓdi anndaaɗi"
  ],
  "Marge brute": [
    "Gross margin",
    "Ceede heddiiɗe"
  ],
  "Ventes confirmées": [
    "Confirmed sales",
    "Jaaygol tabbitinaangol"
  ],
  "Coût manquant": [
    "Missing cost",
    "Njoɓdi anndaaka"
  ],
  "ANALYSE FINANCIÈRE": [
    "FINANCIAL ANALYSIS",
    "ƳEEWTAGOL CEEDE"
  ],
  "Performances financières confirmées": [
    "Confirmed financial performance",
    "Limooje ceede tabbitinaaɗe"
  ],
  "À partir du": [
    "From",
    "Fuɗɗo e"
  ],
  "Connectez-vous pour consulter vos rapports.": [
    "Sign in to view your reports.",
    "Naatu ngam yiyde jaŋte maa."
  ],
  "Les indicateurs tiennent compte des ventes confirmées.": [
    "Figures reflect confirmed sales.",
    "Limooje ɗee ko jaaygol tabbitinaangol."
  ],
  "Journalier": [
    "Daily",
    "Ñalawma kala"
  ],
  "Mensuel": [
    "Monthly",
    "Lewru kala"
  ],
  "Annuel": [
    "Annual",
    "Hitaande kala"
  ],
  "ORGANISATION": [
    "ORGANIZATION",
    "FEDDE"
  ],
  "Modèle d'exploitation": [
    "Operating model",
    "No golle ɗowtirtee"
  ],
  "01 · PME autonome": [
    "01 · Independent business",
    "01 · Golle seeɗa keeriiɗe"
  ],
  "Un établissement indépendant": [
    "Independent location",
    "Nokkuure keeriiɗe"
  ],
  "Un point de vente, une organisation et ses opérations.": [
    "One location, one business and its operations.",
    "Nokkuure wootere, fedde wootere e golle mum."
  ],
  "02 · Responsable multi-emplacements": [
    "02 · Multi-workstation manager",
    "02 · Hooreejo nokkuuji golle"
  ],
  "Plusieurs postes dans un même lieu": [
    "Multiple workstations at one location",
    "Nokkuuji golle keewɗi e nokkuure wootere"
  ],
  "Plusieurs ressources dans un point de vente.": [
    "Several workstations in one location.",
    "Nokkuuji golle keewɗi e nokkuure wootere."
  ],
  "03 · Promoteur multi-sites": [
    "03 · Multi-location owner",
    "03 · Jom nokkuuji keewɗi"
  ],
  "Plusieurs points de vente autonomes": [
    "Multiple independent locations",
    "Nokkuuji jaaygol keewɗi keeriiɗi"
  ],
  "Consolidation réseau, opérations isolées.": [
    "Combined overview, separate operations.",
    "Limooje renndinaaɗe, golle seertiiɗe."
  ],
  "PROFIL DE L'ORGANISATION": [
    "BUSINESS PROFILE",
    "HUMPITO GOLLE"
  ],
  "Identité & langue": [
    "Identity & language",
    "Innol e ɗemngal"
  ],
  "Nom de l'organisation": [
    "Business name",
    "Innde fedde"
  ],
  "Langue par défaut": [
    "Default language",
    "Ɗemngal arande"
  ],
  "Enregistrer le profil": [
    "Save profile",
    "Danndu humpito"
  ],
  "Enregistrement en cours…": [
    "Saving…",
    "Nana dannda…"
  ],
  "Lecture seule : seul le Promoteur ayant le périmètre Organisation peut enregistrer ces réglages.": [
    "View-only: only an authorized business owner can save these settings.",
    "Yiyde tan: jom golle yamiraaɗo tan waawi danndude teelte ɗee."
  ],
  "PÉRIMÈTRE RÉSEAU": [
    "LOCATION NETWORK",
    "NOKKUUJI"
  ],
  "Points de vente sous contrôle": [
    "Managed locations",
    "Nokkuuji jaaygol ɗowtaaɗi"
  ],
  "Autorisé": [
    "Authorized",
    "Yamiraama"
  ],
  "Créer un point de vente": [
    "Create location",
    "Sos nokkuure jaaygol"
  ],
  "Le modèle multi-sites doit d'abord être activé par le Promoteur dans le profil d'organisation.": [
    "The owner must enable multiple locations in the business profile first.",
    "Jom golle foti udditde nokkuuji keewɗi e humpito golle tawo."
  ],
  "Code du site": [
    "Location code",
    "Innol nokkuure"
  ],
  "Nom du site": [
    "Location name",
    "Innde nokkuure"
  ],
  "Adresse / repère": [
    "Address / landmark",
    "Nokkuure / maantore"
  ],
  "Créer le point de vente": [
    "Create location",
    "Sos nokkuure jaaygol"
  ],
  "La création requiert le rôle Promoteur, le périmètre Organisation et le mode multi-sites.": [
    "Only an authorized owner in multi-location mode can create a location.",
    "Jom golle yamiraaɗo tan waawi sosde nokkuure so nokkuuji keewɗi."
  ],
  "Principes d'autonomie": [
    "Independent management",
    "Ɗowtugol keeriiɗol"
  ],
  "Caisse et clôture propres à chaque site.": [
    "Separate register and closing for each location.",
    "Keesu e uddude mum nokkuure kala."
  ],
  "Stock et historique distincts.": [
    "Separate stock and history.",
    "Jawdi e jaŋtol seertiiɗi."
  ],
  "Équipe et affectations séparées.": [
    "Separate staff and assignments.",
    "Golluɓe e golle mum seertii."
  ],
  "Vue d’ensemble du réseau et gestion indépendante de chaque établissement.": [
    "Combined overview and independent management at each location.",
    "Yiyde nokkuuji fof e ɗowtugol nokkuure kala."
  ],
  "POSTES & RESSOURCES": [
    "WORKSTATIONS & RESOURCES",
    "NOKKUUJI GOLLE E JAWDI"
  ],
  "Emplacements d'un même établissement": [
    "Workstations at one location",
    "Nokkuuji golle e nokkuure wootere"
  ],
  "Créer un emplacement": [
    "Create workstation",
    "Sos nokkuure golle"
  ],
  "Code": [
    "Code",
    "Innol"
  ],
  "Nom": [
    "Name",
    "Innde"
  ],
  "Type": [
    "Type",
    "Fannu"
  ],
  "Capacité": [
    "Capacity",
    "Keewal"
  ],
  "Créer le poste": [
    "Create workstation",
    "Sos nokkuure golle"
  ],
  "Seuls les responsables autorisés peuvent créer un poste dans cet établissement.": [
    "Only authorized managers can create a workstation at this location.",
    "Hooreeɓe yamiraaɓe tan mbaawi sosde nokkuure golle ɗoo."
  ],
  "Saisir la valeur": [
    "Enter value",
    "Winndu"
  ],
  "Informations complémentaires": [
    "Additional information",
    "Humpito goɗɗo"
  ],
  "Aucun rendez-vous dans le périmètre chargé.": [
    "No appointments available.",
    "Alaa sahaaaji."
  ],
  "Aucun ticket disponible pour cet établissement.": [
    "No tickets for this location.",
    "Alaa kayite e nokkuure ndee."
  ],
  "Aucun dossier métier reçu pour ce site et cet appareil.": [
    "No work orders available for this location.",
    "Alaa golle danndaaɗe e nokkuure ndee."
  ],
  "Aucune dépense dans le périmètre chargé.": [
    "No expenses available.",
    "Alaa njoɓdi."
  ],
  "Aucune donnée disponible pour cette période.": [
    "No data for this period.",
    "Alaa humpito e sahaa oo."
  ],
  "Aucun établissement accessible pour le moment.": [
    "No locations accessible at the moment.",
    "Alaa nokkuure heɓetee ndee jooni."
  ],
  "Aucun emplacement chargé pour ce point de vente.": [
    "No workstation available at this location.",
    "Alaa nokkuure golle e nokkuure jaaygol ndee."
  ],
  "Coiffure, beauté, couture, réparation, production, interventions et commandes spéciales.": [
    "Hairdressing, beauty, tailoring, repairs, production, call-outs and special orders.",
    "Ñaawugol sukundu, labbingol, mahugol comci, peewngol, sosugol e golle goɗɗe."
  ],
  "Fiches, historique, préférences, points et consentements.": [
    "Records, history, preferences, points and consent.",
    "Humpito, jaŋtol, cuɓe, puwan e jaɓugol."
  ],
  "Comptes individuels, affectations, présence et commissions.": [
    "Individual accounts, assignments, attendance and commissions.",
    "Konte, nokkuuji golle, naatugol e komisiyoŋ."
  ],
  "Lessive, produits de coiffure, seuils et mouvements.": [
    "Laundry and hair products, thresholds and stock movements.",
    "Jawdi lootugol, ñaawugol sukundu, keewal e dirtugol."
  ],
  "Caisse, activité, commissions, analytique et exports.": [
    "Cash, activity, commissions, analytics and exports.",
    "Keesu, golle, komisiyoŋ, limooje e neltugol."
  ],
  "Profil, mode d'exploitation, contrat et droits fonctionnels.": [
    "Profile, operating model, contract and permissions.",
    "Humpito, no golle ɗowtirtee, kontrat e yamiroore."
  ],
  "Consolidation du Promoteur, sites et délégations.": [
    "Owner overview, locations and delegated access.",
    "Yiyde jom golle, nokkuuji e yamiroore."
  ],
  "Autonomie opérationnelle, équipe, caisse et stock par site.": [
    "Independent operations, staff, register and stock per location.",
    "Golle, golluɓe, keesu e jawdi nokkuure kala."
  ],
  "Fauteuils, ateliers, comptoirs et ressources d'un même site.": [
    "Chairs, workshops, counters and resources at one location.",
    "Jooɗorgal, nokkuuji golle e jawdi nokkuure wootere."
  ],
  "Accès, sessions, récupération et audit des opérations.": [
    "Access, sessions, recovery and activity review.",
    "Naatugol, heɓtugol e ƴeewtagol golle."
  ],
  "Langue, thème, synchronisation et périphériques.": [
    "Language, theme, synchronization and devices.",
    "Ɗemngal, jayngol, hesɗitingol e kaɓirɗe."
  ],
  "Aide, demandes support et synthèses du matin et du soir.": [
    "Help, support requests and morning/evening summaries.",
    "Ballal, ɗaɓɓitanɗe e jaŋte subaka e kikiiɗe."
  ],
  "Rendez-vous du jour": [
    "Today's appointments",
    "Sahaaaji hannde"
  ],
  "Tickets pressing à rendre": [
    "Laundry tickets due",
    "Kayite lootugol heɓteteeɗe"
  ],
  "Situation de caisse": [
    "Cash position",
    "No ceede ngoni"
  ],
  "Briefing du matin / soir": [
    "Morning / evening briefing",
    "Jaŋtol subaka / kikiiɗe"
  ],
  "Un planning lisible par poste et prestataire.": [
    "Clear schedule by workstation and provider.",
    "Sahaaaji laaɓtuɗi e nokkuure e gollotooɗo."
  ],
  "Organisez les horaires de vos rendez-vous.": [
    "Organize your appointment times.",
    "Teeltu sahaaaji maa."
  ],
  "Aucun rendez-vous dans cette vue.": [
    "No appointments in this view.",
    "Alaa sahaaaji ɗoo."
  ],
  "Vues jour et semaine": [
    "Daily and weekly views",
    "Yiyde ñalawma e yontere"
  ],
  "Disponibilité du prestataire": [
    "Provider availability",
    "Sahaaaji gollotooɗo"
  ],
  "Disponibilité du fauteuil / poste": [
    "Workstation availability",
    "Sahaaaji nokkuure golle"
  ],
  "Acompte, annulation et liste d'attente": [
    "Deposit, cancellation and waiting list",
    "Ceede adiiɗe, haaytugol e doggol fadotooɓe"
  ],
  "Chaque dépôt possède son ticket et son historique.": [
    "Every drop-off has its own ticket and history.",
    "Comci njabbaaɗi kala e kayit e jaŋtol mum."
  ],
  "Les transitions de statut sont chronologiques et contrôlées.": [
    "Track progress step by step.",
    "Rewindo golle feere kala."
  ],
  "Aucun ticket pressing pour le moment.": [
    "No laundry tickets yet.",
    "Alaa kayite lootugol jooni."
  ],
  "Pièces et prix par catégorie": [
    "Items and prices by category",
    "Comci e njoɓdi fannu kala"
  ],
  "Date promise et acompte": [
    "Promised date and deposit",
    "Ñalnde fodoonde e ceede adiiɗe"
  ],
  "Reçu → En cours → Prêt → Retiré": [
    "Received → In progress → Ready → Collected",
    "Heɓaama → Nana golla → Hebiima → Heɓtaama"
  ],
  "Relance des vêtements non retirés": [
    "Remind customers of uncollected clothes",
    "Tintin soottotooɓe comci ɗi heɓtaaka"
  ],
  "PARCOURS MÉTIERS": [
    "WORK ORDERS",
    "GOLLE"
  ],
  "Un dossier adapté au métier de votre organisation.": [
    "Work orders tailored to your business.",
    "Golle nannduɗe e golle maa."
  ],
  "Gérez les prestations propres à votre activité.": [
    "Manage your business services.",
    "Ɗowtu golle maa."
  ],
  "Aucun dossier métier à afficher.": [
    "No work orders to display.",
    "Alaa golle hollitaaɗe."
  ],
  "Formulaire spécialisé par activité": [
    "Activity-specific form",
    "Ɗerewol ngam golle kala"
  ],
  "Devis, échéance et ressources": [
    "Quotes, due dates and resources",
    "Devis, ñalɗi e jawdi"
  ],
  "Suivi des étapes de traitement": [
    "Processing step tracking",
    "Rewindo feere golle"
  ],
  "Historique et synchronisation multi-appareils": [
    "History and updates across devices",
    "Jaŋtol e hesɗitingol kaɓirɗe"
  ],
  "Une caisse traçable, par point de vente.": [
    "A trackable cash register for each location.",
    "Keesu nokkuure kala e jaŋtol mum."
  ],
  "Suivez vos ventes, paiements et dépenses.": [
    "Track sales, payments and expenses.",
    "Rewindo jaaygol, njoɓdi e ceede maa."
  ],
  "Aucune vente enregistrée.": [
    "No sales recorded.",
    "Alaa jaaygol danndaangol."
  ],
  "Espèces et Mobile Money confirmé": [
    "Cash and confirmed Mobile Money",
    "Ceede e juuɗe e Mobile Money tabbitinaangol"
  ],
  "Paiement mixte et reçu": [
    "Mixed payment and receipt",
    "Njoɓdi laabi keewɗi e kayit"
  ],
  "Ouverture et clôture de caisse": [
    "Register opening and closing",
    "Udditugol e uddude keesu"
  ],
  "Dépenses, écarts et justificatifs": [
    "Expenses, differences and supporting documents",
    "Njoɓdi, seertugol e kayite"
  ],
  "Des prestations adaptées à chaque activité.": [
    "Services tailored to each activity.",
    "Golle nannduɗe e golle kala."
  ],
  "Adaptez vos tarifs à votre établissement.": [
    "Set prices for your business.",
    "Teeltu njoɓdi golle maa."
  ],
  "Aucune prestation dans votre catalogue pour le moment.": [
    "No services in your catalogue yet.",
    "Alaa golle e doggol maa jooni."
  ],
  "Pressing et coiffure distincts": [
    "Separate laundry and hairdressing",
    "Lootugol e ñaawugol sukundu seertii"
  ],
  "Durée et prix par prestation": [
    "Duration and price per service",
    "Sahaa e njoɓdi golle kala"
  ],
  "Habilitations par employé et poste": [
    "Permissions per staff member and workstation",
    "Yamiroore gollotooɗo e nokkuure kala"
  ],
  "Forfaits et produits comptoir": [
    "Packages and counter products",
    "Forfait e jawdi jaaygol"
  ],
  "Connaître l'historique, respecter les préférences.": [
    "Know customer history and respect preferences.",
    "Anndu jaŋtol soottotooɓe e cuɓe mum."
  ],
  "Les coordonnées et notes client sont confidentielles.": [
    "Customer details and notes are confidential.",
    "Humpito soottotooɓe ko sirri."
  ],
  "Aucune fiche client disponible.": [
    "No customer records available.",
    "Alaa humpito soottotooɓe."
  ],
  "Historique des prestations": [
    "Service history",
    "Jaŋtol golle"
  ],
  "Préférences et dernières visites": [
    "Preferences and recent visits",
    "Cuɓe e garugol sakkitiiɗo"
  ],
  "Consentement de contact": [
    "Contact consent",
    "Jaɓugol jokkondiral"
  ],
  "Fidélité, QR et anniversaires": [
    "Loyalty, QR and birthdays",
    "Hoolaare, QR e ñalɗi jibinannde"
  ],
  "Des comptes individuels et des droits précis.": [
    "Individual accounts and clear permissions.",
    "Konte kala e yamiroore mum."
  ],
  "Chaque membre possède son propre accès ; les comptes partagés sont exclus.": [
    "Every team member has their own account.",
    "Gollotooɗo kala e konte mum."
  ],
  "Aucun membre opérationnel chargé.": [
    "No team members available.",
    "Alaa gollotooɗo hollitaano."
  ],
  "Rôles et permissions": [
    "Roles and permissions",
    "Golle e yamiroore"
  ],
  "Affectation site / emplacement": [
    "Location / workstation assignment",
    "Suɓugol nokkuure golle"
  ],
  "Présence, avances et primes": [
    "Attendance, advances and bonuses",
    "Naatugol, ceede adiiɗe e bonis"
  ],
  "Commissions calculées selon une règle datée": [
    "Commissions calculated using dated rules",
    "Komisiyoŋ limtaaɗe e laabi"
  ],
  "Un stock léger centré sur l'exploitation.": [
    "Simple inventory for daily operations.",
    "Jawdi ngam golle ñalawma kala."
  ],
  "Consultez l'historique de vos mouvements de stock.": [
    "View your stock movement history.",
    "Yiy jaŋtol dirtugol jawdi maa."
  ],
  "Aucun consommable suivi pour le moment.": [
    "No supplies tracked yet.",
    "Alaa jawdi rewindoondi jooni."
  ],
  "Lessive et produits coiffure": [
    "Laundry and hair products",
    "Jawdi lootugol e ñaawugol sukundu"
  ],
  "Entrées et consommation": [
    "Incoming stock and consumption",
    "Naatugol e huutorgol jawdi"
  ],
  "Pertes et ajustements motivés": [
    "Losses and documented adjustments",
    "Majjugol e peewngol e daliilu"
  ],
  "Alertes de seuil": [
    "Threshold alerts",
    "Tintine keewal les"
  ],
  "Piloter les résultats, pas seulement les ventes.": [
    "Manage results, not just sales.",
    "Ɗowtu limooje maa, wonaa jaaygol tan."
  ],
  "Consultez les résultats de vos établissements autorisés.": [
    "View results for your authorized locations.",
    "Yiy limooje nokkuuji ɗi a yamiraa."
  ],
  "Vos rapports apparaîtront dès que des opérations seront disponibles.": [
    "Reports appear when operations are available.",
    "Jaŋte maa njiyete so golle ndanndaama."
  ],
  "Recettes et dépenses": [
    "Revenue and expenses",
    "Ceede keɓaaɗe e njoɓdi"
  ],
  "Écarts de caisse": [
    "Cash differences",
    "Seertugol ceede"
  ],
  "Rentabilité des prestations": [
    "Service profitability",
    "Njariñ golle"
  ],
  "Remplissage agenda et commissions": [
    "Schedule occupancy and commissions",
    "Heewugol sahaaaji e komisiyoŋ"
  ],
  "Organisez les accès à votre établissement.": [
    "Manage access to your business.",
    "Teeltu naatugol e golle maa."
  ],
  "Organisez votre établissement ou votre réseau.": [
    "Manage your location or network.",
    "Ɗowtu nokkuure walla nokkuuji maa."
  ],
  "Le profil juridique et commercial n'est pas encore paramétré.": [
    "Business and legal profile not set up yet.",
    "Humpito sariya e jaaygol teeltaaka tawo."
  ],
  "PME autonome": [
    "Independent business",
    "Golle seeɗa keeriiɗe"
  ],
  "Responsable multi-emplacements dans un site": [
    "Multi-workstation manager",
    "Hooreejo nokkuuji golle"
  ],
  "Promoteur multi-sites autonomes": [
    "Multi-location owner",
    "Jom nokkuuji keewɗi"
  ],
  "Rôles et droits d'accès distincts": [
    "Separate roles and access rights",
    "Golle e yamiroore seertiiɗe"
  ],
  "Consolider sans mélanger les opérations.": [
    "Combine results without merging operations.",
    "Renndin limooje tawa golle njillitaaki."
  ],
  "Chaque point de vente garde ses propres caisses, stocks, équipes et tickets.": [
    "Each location keeps its own registers, stock, team and tickets.",
    "Nokkuure kala e keesuuji, jawdi, golluɓe e kayite mum."
  ],
  "Aucun autre établissement.": [
    "No other locations.",
    "Alaa nokkuure goɗɗere."
  ],
  "Vue consolidée du réseau": [
    "Combined network overview",
    "Yiyde nokkuuji fof"
  ],
  "Accès détaillé selon délégation": [
    "Detailed access based on permissions",
    "Naatugol e yamiroore"
  ],
  "Comparaison des sites": [
    "Location comparison",
    "Yerondirgol nokkuuji"
  ],
  "Transferts inter-sites avec validation et audit": [
    "Location transfers with confirmation and review",
    "Dirtugol jawdi hakkunde nokkuuji e tabbitinol"
  ],
  "POINTS DE VENTE": [
    "LOCATIONS",
    "NOKKUUJI JAAYGOL"
  ],
  "Chaque site fonctionne de façon autonome.": [
    "Each location operates independently.",
    "Nokkuure kala e golle mum."
  ],
  "Les opérations d'un point ne sont jamais réaffectées implicitement à un autre.": [
    "Transactions stay with their original location.",
    "Golle kala heddotoo e nokkuure mum."
  ],
  "Aucun point de vente supplémentaire.": [
    "No additional locations.",
    "Alaa nokkuure jaaygol goɗɗere."
  ],
  "Responsable et équipe du site": [
    "Location manager and team",
    "Hooreejo e golluɓe nokkuure"
  ],
  "Caisse et sessions propres": [
    "Separate register and shifts",
    "Keesu e sahaaaji mum"
  ],
  "Stock et consommables propres": [
    "Separate stock and supplies",
    "Jawdi mum"
  ],
  "Catalogue et paramètres du point de vente": [
    "Location catalogue and settings",
    "Doggol golle e teelte nokkuure"
  ],
  "Organiser plusieurs postes dans le même lieu.": [
    "Organize multiple workstations at one location.",
    "Teeltu nokkuuji golle keewɗi e nokkuure wootere."
  ],
  "Les emplacements sont des unités de planning et de ressources à l'intérieur d'un point de vente.": [
    "Workstations organize scheduling and resources at a location.",
    "Nokkuuji golle ɗowtata sahaaaji e jawdi e nokkuure."
  ],
  "Aucun emplacement configuré.": [
    "No configured workstation.",
    "Alaa nokkuure golle teeltaande."
  ],
  "Fauteuils de coiffure": [
    "Hairdressing chairs",
    "Jooɗorgal ñaawugol sukundu"
  ],
  "Atelier / comptoir pressing": [
    "Laundry workshop / counter",
    "Nokkuure lootugol"
  ],
  "Planning et capacité": [
    "Schedule and capacity",
    "Sahaaaji e keewal"
  ],
  "Affectation des prestataires": [
    "Provider assignments",
    "Suɓugol golluɓe"
  ],
  "Maîtriser les sessions et les appareils.": [
    "Manage sessions and devices.",
    "Ɗowtu naatugol e kaɓirɗe."
  ],
  "Contactez votre responsable pour récupérer votre accès.": [
    "Contact your manager to regain access.",
    "Jokkondir e hooreejo maa ngam heɓtude naatugol."
  ],
  "Aucune opération disponible.": [
    "No transactions available.",
    "Alaa golle jooni."
  ],
  "Sessions et appareils enrôlés": [
    "Sessions and registered devices",
    "Naatugol e kaɓirɗe danndaaɗe"
  ],
  "Révocation à distance": [
    "Remote access removal",
    "Ittugol yamiroore"
  ],
  "Demandes de récupération": [
    "Recovery requests",
    "Ɗaɓɓitanɗe heɓtugol"
  ],
  "Audit des opérations privilégiées": [
    "Review of authorized operations",
    "Ƴeewtagol golle yamiraaɗe"
  ],
  "Un environnement adapté à l'équipe.": [
    "A workspace tailored to your team.",
    "Nokkuure golle nanndunde e golluɓe maa."
  ],
  "Personnalisez votre espace de travail.": [
    "Customize your workspace.",
    "Teeltu nokkuure golle maa."
  ],
  "Personnalisez votre espace.": [
    "Customize your space.",
    "Teeltu nokkuure maa."
  ],
  "Français, English et Fulfulde": [
    "French, English and Fulfulde",
    "Français, English e Fulfulde"
  ],
  "Thème sombre / clair": [
    "Dark / light theme",
    "Jemma / jayngol"
  ],
  "Travail sans Internet et mise à jour au retour du réseau": [
    "Work offline and update when online",
    "Golle tawa internet alaa e hesɗitingol so internet artii"
  ],
  "Imprimantes et notifications": [
    "Printers and notifications",
    "Imprimante e tintine"
  ],
  "Obtenez de l’aide quand vous en avez besoin.": [
    "Get help when you need it.",
    "Heɓ ballal so a sokli."
  ],
  "Ne communiquez jamais vos codes confidentiels.": [
    "Never share confidential codes.",
    "Hoto hokku kode sirri maa."
  ],
  "Aucune demande d’assistance pour le moment.": [
    "No support requests yet.",
    "Alaa ɗaɓɓitannde ballal jooni."
  ],
  "FAQ et guides": [
    "FAQ and guides",
    "Naamne e jaabawuuji"
  ],
  "Demande d'assistance": [
    "Support request",
    "Ɗaɓɓitannde ballal"
  ],
  "Briefing du matin": [
    "Morning briefing",
    "Jaŋtol subaka"
  ],
  "Briefing du soir": [
    "Evening briefing",
    "Jaŋtol kikiiɗe"
  ],
  "ATELIER": [
    "WORKSHOP",
    "NOKKUURE GOLLE"
  ],
  "ENCAISSEMENTS": [
    "PAYMENTS",
    "CE EDE"
  ],
  "CATALOGUE": [
    "CATALOGUE",
    "DOGGOL"
  ],
  "ÉQUIPE": [
    "TEAM",
    "GOLLUƁE"
  ],
  "CONSOMMABLES": [
    "SUPPLIES",
    "JAWDI"
  ],
  "ANALYTIQUE": [
    "ANALYTICS",
    "LIMOOJE"
  ],
  "RÉSEAU": [
    "NETWORK",
    "NOKKUUJI"
  ],
  "EMPLACEMENTS": [
    "WORKSTATIONS",
    "NOKKUUJI GOLLE"
  ],
  "PROTECTION": [
    "SECURITY",
    "KISAL"
  ],
  "CONFIGURATION": [
    "SETTINGS",
    "TEELTE"
  ],
  "ASSISTANCE": [
    "HELP",
    "BALLAL"
  ],
  "Disponible": [
    "Available",
    "Ena woodi"
  ],
  "SESSION EN COURS": [
    "CURRENT SESSION",
    "SAHAA GOLLE"
  ],
  "HISTORIQUE": [
    "HISTORY",
    "JAŊTOL"
  ],
  "Brouillons": [
    "Drafts",
    "Golle heblitteeɗe"
  ],
  "Local": [
    "On device",
    "E kaɓirgol"
  ],
  "Consultation": [
    "View only",
    "Yiyde tan"
  ],
  "Aucun résultat disponible pour le moment.": [
    "No results available yet.",
    "Alaa limooje jooni."
  ],
  "En cours": [
    "In progress",
    "Nana golla"
  ],
  "Prêt": [
    "Ready",
    "Hebiima"
  ],
  "Retiré": [
    "Collected",
    "Heɓtaama"
  ],
  "Suivi des tickets": [
    "Ticket tracking",
    "Rewindo kayite"
  ],
  "Données confirmées": [
    "Confirmed data",
    "Humpito tabbitinaango"
  ],
  "À charger": [
    "Load data",
    "Hollu humpito"
  ],
  "Chargement…": [
    "Loading…",
    "Nana hebla…"
  ],
  "Charger les rapports": [
    "Load reports",
    "Hollu jaŋte"
  ],
  "Afficher les postes": [
    "Show workstations",
    "Hollu nokkuuji golle"
  ],
  "Cet appareil": [
    "This device",
    "Kaɓirgol ngol"
  ],
  "Révoqué": [
    "Access removed",
    "Yamiroore ittaama"
  ],
  "Dernière activité": [
    "Last activity",
    "Golle sakkitiiɗe"
  ],
  "Photo de profil": [
    "Profile photo",
    "Natal am"
  ],
  "Supprimer la photo": [
    "Remove photo",
    "Ittu natal"
  ],
  "Fichier photo de profil": [
    "Profile photo file",
    "Fiilde natal"
  ],
  "Photo enregistrée.": [
    "Photo saved.",
    "Natal danndaama."
  ],
  "Photo supprimée.": [
    "Photo removed.",
    "Natal ittaama."
  ],
  "Nom / référence du client": [
    "Customer name / reference",
    "Innde / innol soottotooɗo"
  ],
  "Sujet": [
    "Subject",
    "Ko ɗaɓɓitaa"
  ],
  "Catégorie de dépense": [
    "Expense category",
    "Fannu njoɓdi"
  ],
  "Membre": [
    "Member",
    "Gollotooɗo"
  ],
  "Nom / référence": [
    "Name / reference",
    "Innde / innol"
  ],
  "NOUVELLE OPÉRATION": [
    "NEW OPERATION",
    "GOLLE KESEEƊE"
  ],
  "NOUVELLE OPÉRATION · DÉMONSTRATION": [
    "NEW DEMO OPERATION",
    "GOLLE ƳEEWNDUGOL"
  ],
  "Pointer mon arrivée": [
    "Clock in",
    "Winndu naatugol am"
  ],
  "Ajouter à la démonstration": [
    "Add to demo",
    "Ɓeydu e ƴeewndugol"
  ],
  "Opération impossible.": [
    "Operation unavailable.",
    "Golle ɗee waawataa."
  ],
  "Espace connecté": [
    "Signed-in workspace",
    "Nokkuure golle"
  ],
  "Lecture impossible.": [
    "Unable to load.",
    "Hollugol waawataa."
  ],
  "Révocation impossible.": [
    "Unable to remove access.",
    "Ittugol yamiroore waawataa."
  ],
  "Cette opération est momentanément indisponible. Réessayez ou contactez l’assistance.": [
    "This action is temporarily unavailable. Try again or contact support.",
    "Golle ɗee alaa jooni. Eto kadi walla ɗaɓɓu ballal."
  ],
  "Impossible d’enregistrer vos modifications.": [
    "Unable to save changes.",
    "Danndugol wayle waawataa."
  ],
  "Profil enregistré.": [
    "Profile saved.",
    "Humpito danndaama."
  ],
  "Création impossible.": [
    "Unable to create.",
    "Sosugol waawataa."
  ]
};
export function translate(locale:Locale, text:string):string { if(locale==="fr")return text;return catalogue[text]?.[locale==="en"?0:1]??text; }

export const LocaleContext=createContext<Locale>("fr");
export function useTranslation(){const locale=useContext(LocaleContext);return (text:string)=>translate(locale,text);}
