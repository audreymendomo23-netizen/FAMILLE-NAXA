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
  ]
};
export function translate(locale:Locale, text:string):string { if(locale==="fr")return text;return catalogue[text]?.[locale==="en"?0:1]??text; }

export const LocaleContext=createContext<Locale>("fr");
export function useTranslation(){const locale=useContext(LocaleContext);return (text:string)=>translate(locale,text);}
