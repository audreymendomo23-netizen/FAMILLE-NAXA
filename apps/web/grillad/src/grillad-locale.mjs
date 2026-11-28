// Common vocabulary reused from NAXA SERVICES; GRILLAD-specific Fulfulde labels remain pending native review.
export const labels={
  "Accueil": [
    "Home",
    "Jaɓɓorgo"
  ],
  "Vente": [
    "Sale",
    "Jaaygol"
  ],
  "Ventes": [
    "Sales",
    "Jaaygol"
  ],
  "Préparations": [
    "Preparations",
    "Heblugol"
  ],
  "Catalogue": [
    "Catalogue",
    "Doggol"
  ],
  "Activité": [
    "Activity",
    "Golle"
  ],
  "Caisse": [
    "Cash register",
    "Ceede"
  ],
  "Dépenses": [
    "Expenses",
    "Njoɓdi"
  ],
  "Achats": [
    "Purchases",
    "Soottugol"
  ],
  "Rapports": [
    "Reports",
    "Jaŋte"
  ],
  "Prévisions": [
    "Forecasts",
    "Ƴeewtagol yeeso"
  ],
  "Point journalier": [
    "Daily summary",
    "Jaŋtol hannde"
  ],
  "Plus": [
    "More",
    "Goɗɗe"
  ],
  "Équipe": [
    "Team",
    "Golluɓe"
  ],
  "Notifications": [
    "Notifications",
    "Tintine"
  ],
  "Vidéosurveillance": [
    "Video security",
    "Kisal video"
  ],
  "ZIPPLE Connect": [
    "ZIPPLE Connect",
    "ZIPPLE Connect"
  ],
  "Abonnement": [
    "Subscription",
    "Abonman"
  ],
  "Profil": [
    "Profile",
    "Humpito"
  ],
  "Assistance": [
    "Support",
    "Ballal"
  ],
  "Déconnexion": [
    "Sign out",
    "Yaltu"
  ],
  "Actualiser": [
    "Refresh",
    "Hesɗitin"
  ],
  "Langue": [
    "Language",
    "Ɗemngal"
  ],
  "Système": [
    "System default",
    "Teelte"
  ],
  "Clair": [
    "Light",
    "Jayngol"
  ],
  "Sombre": [
    "Dark",
    "Niɓɓere"
  ],
  "Point de vente": [
    "Location",
    "Nokkuure jaaygol"
  ],
  "Enregistrer": [
    "Save",
    "Danndu"
  ],
  "Annuler": [
    "Cancel",
    "Haaytu"
  ],
  "Quantité": [
    "Quantity",
    "Keewal"
  ],
  "Prix": [
    "Price",
    "Prix"
  ],
  "Mot de passe": [
    "Password",
    "Finnde"
  ],
  "Se connecter": [
    "Sign in",
    "Naatu"
  ],
  "Aide": [
    "Help",
    "Ballal"
  ],
  "Mode nuit": [
    "Night mode",
    "Jemma"
  ],
  "Mode clair": [
    "Light mode",
    "Jayngol"
  ],
  "Mode sombre": [
    "Dark mode",
    "Niɓɓere"
  ],
  "Ouvrir": [
    "Open",
    "Uddit"
  ],
  "Indisponible": [
    "Unavailable",
    "Alaa jooni"
  ],
  "Créer un ticket": [
    "Create ticket",
    "Sos kayit"
  ],
  "Envoyer la demande": [
    "Submit request",
    "Neldu ɗaɓɓitannde"
  ],
  "Retour": [
    "Back",
    "Retour"
  ],
  "Nouvelle vente": [
    "New sale",
    "Jaaygol kesol"
  ],
  "Points de vente": [
    "Locations",
    "Nokkuuji jaaygol"
  ],
  "Sécurité": [
    "Security",
    "Kisal"
  ],
  "Ouvrir la caisse": [
    "Open register",
    "Uddit keesu"
  ],
  "Espèces": [
    "Cash",
    "Ceede e juuɗe"
  ],
  "Choisir un article": [
    "Choose item",
    "Suɓo jawdi"
  ],
  "Motif": [
    "Reason",
    "Daliilu"
  ],
  "Actif": [
    "Active",
    "Nana golla"
  ],
  "Créer le point de vente": [
    "Create location",
    "Sos nokkuure"
  ],
  "Mot de passe oublié": [
    "Forgot password?",
    "A yejjitii finnde maa?"
  ],
  "Téléphone (+237…)": [
    "Phone (+237…)",
    "Telefon (+237…)"
  ],
  "Téléphone de récupération": [
    "Recovery phone",
    "Telefon"
  ],
  "Ajouter l’article": [
    "Add item",
    "Ɓeydu jawdi"
  ],
  "Fermer la session locale": [
    "Sign out",
    "Yaltu"
  ],
  "Connexion": [
    "Sign in",
    "Naatugol e kisal"
  ],
  "Connexion professionnelle": [
    "Professional sign in",
    "Naatugol e kisal"
  ]
};
export function localeOf(x){return x==='en'||x==='ff-CM'?x:'fr'}
export function translate(key,locale){return localeOf(locale)==='fr'?key:labels[key]?.[locale==='en'?0:1]??key}
