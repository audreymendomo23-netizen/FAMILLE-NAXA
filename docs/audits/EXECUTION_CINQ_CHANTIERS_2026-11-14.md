# Exécution coordonnée — cinq chantiers Famille NAXA
Date : 14 novembre 2026. Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA`, branche `main`.

## Preuves réelles
- Run [43551672204](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/43551672204) : SUCCESS — PostgreSQL 17, RLS 0.3, claims et contrats.
- Run [43557643046](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/43557643046) : SUCCESS — PostgreSQL 17, tests contrats, 10 builds Web/PWA, 10 builds Android natifs, persistance des sources générées sur `main`.
- Commit de persistance : `4a8af10c82017485578ebb24af82c48aeeb31b2f`.

## État des cinq chantiers
| Chantier | Livré et prouvé | Limites restantes | État |
|---|---|---|---|
| Sécurité / comptes / paiements | Draft 0001 + candidate RLS 0002 + candidate 0003 testés sur PostgreSQL 17 éphémère | Correctif 0003 multi-app dans le run suivant ; Auth Hook signé absent ; pas de migration réelle | PARTIEL |
| Offline / synchronisation / notifications | Contrat offline, Room queue, IndexedDB queue ; module Android partagé de canaux et briefings WorkManager ajouté au générateur | Sync serveur, FCM, jetons et statuts de réception non intégrés ; WorkManager reste best-effort | PARTIEL |
| 10 applications Android + Web/PWA | 10 modules Android Kotlin/Compose et 10 cibles Web/PWA générés, compilés et persistés sur main | Squelettes initiaux seulement ; parcours métiers, tests instrumentés et tests d'acceptation absents | PARTIEL |
| Distribution / versions / exports | SHA-256 et contrôle de version minimale | Keystore hors dépôt, vérification certificat serveur, exports PDF/XLSX, page de téléchargement et mise à jour non intégrés | PARTIEL |
| IA locale | Moteur de règles/statistiques et recommandations explicables | Adaptateurs métiers, voix, anonymisation et interface assistant non intégrés | PARTIEL |

## Lot suivant
- 0003 durcit chaque helper d'accès avec le claim signé `app_metadata.active_app_id`, retire le GRANT EXECUTE global et ajoute un test négatif entre Kiosko et Campus237 pour un même utilisateur/organisation.
- Le générateur crée un module Android partagé `core-android` avec les cinq canaux locaux et la planification de briefings WorkManager ; il ajoute cette dépendance aux dix APK.
- Calculs d'abonnement FCFA ajoutés et testés : trimestre -10 % arrondi à la centaine inférieure, semestre 5 mois, annuel 10 mois, prorata montée de palier, minimum 100 F, plafond 3 mois offerts/an et accès provisoire de 24 h une fois par période.
- Sept thèmes historiques définis ; contrastes WCAG AA testés. Les trois palettes des apps ajoutées plus tard ne sont pas inventées.

## Garde-fous et non-preuves
Aucune migration Supabase réelle, aucune configuration Auth Production, aucun secret/keystore dans le dépôt, aucune publication ni déploiement. Aucun prompt 0.3 à 0.13 n'est VERT tant que les parcours fonctionnels complets ne sont pas prouvés.
