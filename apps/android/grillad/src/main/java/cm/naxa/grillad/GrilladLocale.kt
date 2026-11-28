package cm.naxa.grillad
// Shared presentation keys; missing Fulfulde retains French source.
internal fun grilladLabel(key:String,locale:String):String=if(locale!="en"&&locale!="ff-CM")key else when(key){
 "Accueil" -> if(locale=="en")"Home" else "Jaɓɓorgo"
 "Vente" -> if(locale=="en")"Sale" else "Jaaygol"
 "Ventes" -> if(locale=="en")"Sales" else "Jaaygol"
 "Préparations" -> if(locale=="en")"Preparations" else "Heblugol"
 "Catalogue" -> if(locale=="en")"Catalogue" else "Doggol"
 "Activité" -> if(locale=="en")"Activity" else "Golle"
 "Caisse" -> if(locale=="en")"Cash register" else "Ceede"
 "Dépenses" -> if(locale=="en")"Expenses" else "Njoɓdi"
 "Achats" -> if(locale=="en")"Purchases" else "Soottugol"
 "Rapports" -> if(locale=="en")"Reports" else "Jaŋte"
 "Prévisions" -> if(locale=="en")"Forecasts" else "Ƴeewtagol yeeso"
 "Point journalier" -> if(locale=="en")"Daily summary" else "Jaŋtol hannde"
 "Plus" -> if(locale=="en")"More" else "Goɗɗe"
 "Équipe" -> if(locale=="en")"Team" else "Golluɓe"
 "Notifications" -> if(locale=="en")"Notifications" else "Tintine"
 "Vidéosurveillance" -> if(locale=="en")"Video security" else "Kisal video"
 "ZIPPLE Connect" -> if(locale=="en")"ZIPPLE Connect" else "ZIPPLE Connect"
 "Abonnement" -> if(locale=="en")"Subscription" else "Abonman"
 "Profil" -> if(locale=="en")"Profile" else "Humpito"
 "Assistance" -> if(locale=="en")"Support" else "Ballal"
 "Déconnexion" -> if(locale=="en")"Sign out" else "Yaltu"
 "Actualiser" -> if(locale=="en")"Refresh" else "Hesɗitin"
 "Langue" -> if(locale=="en")"Language" else "Ɗemngal"
 "Système" -> if(locale=="en")"System default" else "Teelte"
 "Clair" -> if(locale=="en")"Light" else "Jayngol"
 "Sombre" -> if(locale=="en")"Dark" else "Niɓɓere"
 "Point de vente" -> if(locale=="en")"Location" else "Nokkuure jaaygol"
 "Enregistrer" -> if(locale=="en")"Save" else "Danndu"
 "Annuler" -> if(locale=="en")"Cancel" else "Haaytu"
 "Quantité" -> if(locale=="en")"Quantity" else "Keewal"
 "Prix" -> if(locale=="en")"Price" else "Prix"
 "Mot de passe" -> if(locale=="en")"Password" else "Finnde"
 "Se connecter" -> if(locale=="en")"Sign in" else "Naatu"
 "Aide" -> if(locale=="en")"Help" else "Ballal"
 "Mode nuit" -> if(locale=="en")"Night mode" else "Jemma"
 "Mode clair" -> if(locale=="en")"Light mode" else "Jayngol"
 "Mode sombre" -> if(locale=="en")"Dark mode" else "Niɓɓere"
 "Ouvrir" -> if(locale=="en")"Open" else "Uddit"
 "Indisponible" -> if(locale=="en")"Unavailable" else "Alaa jooni"
 "Créer un ticket" -> if(locale=="en")"Create ticket" else "Sos kayit"
 "Envoyer la demande" -> if(locale=="en")"Submit request" else "Neldu ɗaɓɓitannde"
 "Retour" -> if(locale=="en")"Back" else "Retour"
 "Nouvelle vente" -> if(locale=="en")"New sale" else "Jaaygol kesol"
 "Points de vente" -> if(locale=="en")"Locations" else "Nokkuuji jaaygol"
 "Sécurité" -> if(locale=="en")"Security" else "Kisal"
 "Ouvrir la caisse" -> if(locale=="en")"Open register" else "Uddit keesu"
 "Espèces" -> if(locale=="en")"Cash" else "Ceede e juuɗe"
 "Choisir un article" -> if(locale=="en")"Choose item" else "Suɓo jawdi"
 "Motif" -> if(locale=="en")"Reason" else "Daliilu"
 "Actif" -> if(locale=="en")"Active" else "Nana golla"
 "Créer le point de vente" -> if(locale=="en")"Create location" else "Sos nokkuure"
 "Mot de passe oublié" -> if(locale=="en")"Forgot password?" else "A yejjitii finnde maa?"
 "Téléphone (+237…)" -> if(locale=="en")"Phone (+237…)" else "Telefon (+237…)"
 "Téléphone de récupération" -> if(locale=="en")"Recovery phone" else "Telefon"
 "Ajouter l’article" -> if(locale=="en")"Add item" else "Ɓeydu jawdi"
 "Fermer la session locale" -> if(locale=="en")"Sign out" else "Yaltu"
 "Connexion" -> if(locale=="en")"Sign in" else "Naatugol e kisal"
 "Connexion professionnelle" -> if(locale=="en")"Professional sign in" else "Naatugol e kisal"
 "Article" -> if(locale=="en")"Item" else "Jawdi"
 "Période" -> if(locale=="en")"Period" else "Sahaa"
 "Catégorie de dépense" -> if(locale=="en")"Expense category" else "Fannu njoɓdi"
 "Accès professionnel GRILLAD" -> if(locale=="en")"GRILLAD professional access" else key
 "Première connexion avec invitation" -> if(locale=="en")"First sign-in with invitation" else key
 "Référence invitation" -> if(locale=="en")"Invitation reference" else key
 "Code invitation" -> if(locale=="en")"Invitation code" else key
 "Rester connecté sur cet appareil" -> if(locale=="en")"Stay signed in on this device" else key
 "Réinitialiser mon code local après connexion vérifiée" -> if(locale=="en")"Reset my local code after verified sign-in" else key
 "Renouvellement uniquement" -> if(locale=="en")"Renewal only" else key
 "CA net" -> if(locale=="en")"Net revenue" else key
 "Objectif du jour" -> if(locale=="en")"Today's target" else key
 "Objectif CA FCFA" -> if(locale=="en")"Revenue target (XAF)" else key
 "Enregistrer l’objectif" -> if(locale=="en")"Save target" else key
 "Exporter le point journalier PDF" -> if(locale=="en")"Export daily summary PDF" else key
 "Pas de données confirmées." -> if(locale=="en")"No confirmed data." else key
 "Nom de l’article" -> if(locale=="en")"Item name" else key
 "Coût facultatif" -> if(locale=="en")"Optional cost" else key
 "Modifier le prix" -> if(locale=="en")"Change price" else key
 "Modifier le prix sélectionné" -> if(locale=="en")"Change selected price" else key
 "Actualiser le coût" -> if(locale=="en")"Update cost" else key
 "Désactiver" -> if(locale=="en")"Disable" else key
 "Désactiver l’article" -> if(locale=="en")"Disable item" else key
 "Réactiver" -> if(locale=="en")"Reactivate" else key
 "Corriger les quantités" -> if(locale=="en")"Adjust quantities" else key
 "Corriger la quantité" -> if(locale=="en")"Adjust quantity" else key
 "Enregistrer la correction" -> if(locale=="en")"Save adjustment" else key
 "Télécharger le reçu PDF" -> if(locale=="en")"Download receipt PDF" else key
 "Annuler cette vente" -> if(locale=="en")"Cancel sale" else key
 "Attendu" -> if(locale=="en")"Expected" else key
 "Clôturer" -> if(locale=="en")"Close" else key
 "Rapprochement des règlements mobiles" -> if(locale=="en")"Mobile payment reconciliation" else key
 "Rapprocher le règlement" -> if(locale=="en")"Reconcile payment" else key
 "Clôtures confirmées" -> if(locale=="en")"Confirmed closings" else key
 "Catégorie" -> if(locale=="en")"Category" else key
 "Intrants" -> if(locale=="en")"Inputs" else key
 "Combustible" -> if(locale=="en")"Fuel" else key
 "Emballages" -> if(locale=="en")"Packaging" else key
 "Entretien" -> if(locale=="en")"Maintenance" else key
 "Personnel" -> if(locale=="en")"Staff" else key
 "Autres" -> if(locale=="en")"Other" else key
 "Annuler la dépense" -> if(locale=="en")"Cancel expense" else key
 "Service en cours" -> if(locale=="en")"Current service" else key
 "CA estimé au prochain service" -> if(locale=="en")"Estimated revenue for next service" else key
 "Marquer comme lu" -> if(locale=="en")"Mark as read" else key
 "Préférences" -> if(locale=="en")"Preferences" else key
 "Inscrire cet appareil" -> if(locale=="en")"Register device" else key
 "Désactiver les notifications distantes" -> if(locale=="en")"Disable remote notifications" else key
 "Équipe du point" -> if(locale=="en")"Location team" else key
 "Affectations au point actif" -> if(locale=="en")"Assignments at active location" else key
 "Non affecté" -> if(locale=="en")"Unassigned" else key
 "Vendeur" -> if(locale=="en")"Seller" else key
 "Responsable" -> if(locale=="en")"Manager" else key
 "Confirmer l’affectation" -> if(locale=="en")"Confirm assignment" else key
 "Confirmer le statut" -> if(locale=="en")"Confirm status" else key
 "Apparence" -> if(locale=="en")"Appearance" else key
 "Animation nocturne" -> if(locale=="en")"Night animation" else key
 "Mode de gestion" -> if(locale=="en")"Management mode" else key
 "Indépendant" -> if(locale=="en")"Independent" else key
 "Centralisé" -> if(locale=="en")"Centralized" else key
 "Confirmer le mode" -> if(locale=="en")"Confirm mode" else key
 "Configurer le service" -> if(locale=="en")"Configure service" else key
 "Horaires futurs" -> if(locale=="en")"Future hours" else key
 "Programmer l’horaire futur" -> if(locale=="en")"Schedule future hours" else key
 "Sujet assistance" -> if(locale=="en")"Support subject" else key
 "Description assistance" -> if(locale=="en")"Support description" else key
 "Réessayer la même demande" -> if(locale=="en")"Retry same request" else key
 "Mes dossiers / Actualiser" -> if(locale=="en")"My tickets / Refresh" else key
 "Conversation" -> if(locale=="en")"Conversation" else key
 "Conversation assistance" -> if(locale=="en")"Support conversation" else key
 "Actualiser la conversation" -> if(locale=="en")"Refresh conversation" else key
 "Message assistance" -> if(locale=="en")"Support message" else key
 "Réessayer" -> if(locale=="en")"Retry" else key
 "Envoyer le message" -> if(locale=="en")"Send message" else key
 "Vous" -> if(locale=="en")"You" else key
 "Assistant de pilotage" -> if(locale=="en")"Management assistant" else key
 "Libellé" -> if(locale=="en")"Label" else key
 "Montant" -> if(locale=="en")"Amount" else key
 "Motif de correction" -> if(locale=="en")"Correction reason" else key
 "Motif d’annulation" -> if(locale=="en")"Cancellation reason" else key
 "Motif de réactivation" -> if(locale=="en")"Reactivation reason" else key
 "Motif de création" -> if(locale=="en")"Creation reason" else key
 "Nom du nouveau point" -> if(locale=="en")"New location name" else key
 "Verrouiller" -> if(locale=="en")"Lock" else key
 "Reconnexion et vérification" -> if(locale=="en")"Reconnect and verify" else key
 else -> key
}
