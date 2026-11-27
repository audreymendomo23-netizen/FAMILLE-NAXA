# GRILLAD — Infrastructure N0 (27/11/2026)
## 1. Cloudflare Pages
Modèle repris de ZIPPLE et NAXA SERVICES. Projet Pages dédié à GRILLAD à créer/vérifier dans le compte Cloudflare, sans réutiliser l'alias famille-naxa.pages.dev ni la configuration ZIPPLE. Racine du dépôt, commande npm install puis node scripts/grillad/cloudflare-pages-build.mjs, sortie apps/web/grillad/dist. _headers et _redirects propres. Aucun secret dans VITE_* ; le mode GRILLAD_RELEASE=1 est bloqué tant que l'authentification et le backend réels ne sont pas raccordés. Une URL candidate doit être HTTPS /functions/v1/grillad. Ce contrôle syntaxique ne prouve pas l'existence du backend. Prévisualisation de construction sans backend uniquement. Aucun déploiement voulu ni URL publique revendiquée.

## 2. Firebase
Projet dédié et client Android cm.naxa.grillad à enregistrer/vérifier. Le script firebase-android-config.mjs valide les métadonnées publiques du client, pas un service account. Pas de token FCM, clé serveur ou fichier privé dans Git. Notifications locales d'abord ; FCM nécessite configuration SDK, permission, association token/application/organisation/vendeur/site et révocation, transport serveur et recette sur appareil. Aucun projet ou envoi FCM réel attesté.
 
## 3. Qualification
Les tests infrastructure.test.mjs vérifient la configuration à blanc et les refus. Le workflow GRILLAD de construction ne contient aucune action de déploiement. Lancer après construction UI et métier ; vérifier le SHA, les résultats et corriger. Le connecteur Firebase non connecté et l'absence d'accès administratif Cloudflare empêchent de créer/vérifier les ressources réelles dans cette passe. Ne pas demander de secrets dans le chat. N0 reste partiel.

Le connecteur Cloudflare existant du monorepo a émis un check automatique `Cloudflare Pages: famille-naxa` sur la branche de travail. Ce check n'atteste pas un projet GRILLAD dédié ; une prévisualisation publique de branche peut être générée par la configuration externe existante. Aucune modification volontaire des réglages Cloudflare ou déploiement de production.
