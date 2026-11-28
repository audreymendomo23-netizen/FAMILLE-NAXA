// Shared family vocabulary recovered from NAXA SERVICES; GRILLAD-specific navigation additions are provisional for ff-CM.
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
    "Settings",
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
    "Prix",
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
    "Retour",
    "Retour"
  ],
  "Nouvelle vente": [
    "New sale",
    "Jaaygol kesol"
  ]
};
export function localeOf(x){return x==='en'||x==='ff-CM'?x:'fr'}
export function translate(key,locale){return locale==='fr'?key:labels[key]?.[locale==='en'?0:1]??key}
