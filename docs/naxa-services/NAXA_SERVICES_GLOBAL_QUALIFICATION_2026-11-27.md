# NAXA SERVICES — Matrice globale des recettes résiduelles B1 à B6

27 novembre 2026 — baseline 79643ea1b29464b60e7e706e2caff67b086540e5

Registre des recettes résiduelles connues d'après continuité §22.119 et §22.129–130, audit fermeture, contradictions C01–C24, red gates et workflows. Ce n'est pas un audit exhaustif de tout le code ni la preuve d'absence d'autres défauts.

Les sept workflows de qualification sont déclenchés sur le même commit par la modification du registre JSON. Aucune signature commerciale, migration hébergée, paiement ou déploiement manuel. Les preuves historiques #105 et #859 sont vertes ; le présent lot est nouveau.

- **replay** : Recette existante relancée ; succès à constater, périmètre limité.
- **partial** : Recette partielle relancée ; reste non qualifié.
- **development** : Critère documenté, implémentation/recette E2E manquante ; workflow voisin ne peut pas le déclarer vert.
- **external** : Preuve réelle, autorisation ou expertise externe requise ; workflow voisin ne peut pas le déclarer vert.

| ID | Recette | État avant campagne | Workflow | Critère de fermeture |
|---|---|---|---|---|
| B1-01 | Droits positifs/négatifs des 10 rôles, site, poste, hiérarchie | partial | replay-isolated | JWT de chaque rôle, deux sites et deux postes ; lecture/écriture/compteurs limités ; aucun accès transversal ; compléter matrice poste/DAO. |
| B1-02 | Planning, congés, remplacements, rotations et conflit concurrent | replay | replay-isolated | Deux comptes ; publication, accusé, justification, refus conflit, remplacement atomique, congé, modèle et archivage. |
| B1-03 | Cache chiffré et reprise Android après redémarrage | partial | independent-reserves | Redémarrage OS émulateur ; journal intact, preuve ancienne rejetée ; reprise autorisée après preuve temps/session fiable reste à tester. |
| B1-04 | Offline prolongé et révocation des droits | partial | replay-isolated | Déconnexion, perte de reçu, replay identique, scope B/C et droit révoqué ; compléter coupure longue et cache subordonné. |
| B1-05 | GPS/selfie par site/poste/rôle, politique et historique | partial | replay-isolated | Preuve simulée, expiration, revue privée et anti-rejeu ; développer/qualifier héritage de politique par poste/rôle. |
| B1-06 | Nettoyage automatique hébergé des preuves temporaires | external | replay-isolated | Staging jetable puis vérification du cron et objets orphelins sur cible autorisée ; aucune suppression réelle sans périmètre. |
| B1-07 | Capteurs et permissions physiques | external | hosted-device-test | Deux téléphones autorisés ; refus permission, GPS mock, caméra avant, arrière-plan, reprise, révocation ; fournir logs expurgés. |
| B2-01 | Agenda, récurrences, invitations et rappels | partial | replay-isolated | Deux JWT, création/rejeu, RSVP, modification, annulation ; compléter persistance native, calendrier, documents et remise réelle des rappels. |
| B2-02 | Autorisation média, exclusion, chat, main et réactions | replay | replay-isolated | Invité/hôte même salle, anonyme/étranger/salle fermée refusés ; modération et consentement ; plan de contrôle seulement. |
| B2-03 | Transport SFU/TURN et présence effective | development | technical-gate | Réutiliser WideMeet après audit compatibilité ; deux appareils/réseaux, ICE/relay, audio bidirectionnel, caméra et quitter. |
| B2-04 | Partage écran, micro/caméra, exclusion effective | development | technical-gate | Vérifier flux effectivement retirés, publication/interdiction, reconnexion et révocation active ; permissions SQL seules insuffisantes. |
| B2-05 | Parité native/Web/PWA et réseau dégradé | external | hosted-device-test | Deux appareils réels et navigateur ; coupure, reprise, caméra/micro/écran et consommation ; dépend du transport livré. |
| B3-01 | Consentement et demande d'enregistrement | replay | replay-isolated | Hôte et invité, consentement, retrait, demande annulée ; aucun fichier audio revendiqué. |
| B3-02 | Enregistrement egress, annonce, retrait et clôture | development | technical-gate | Démarrer seulement après accord requis ; arrêt effectif, fichier mixé vérifiable ; aucun enregistrement clandestin. |
| B3-03 | Stockage privé audio, lecture et expiration | development | replay-isolated | Fichier véritable, contrôle locataire, URL courte, retrait/expiration/rétention, lecture sur clients ; dépend egress. |
| B3-04 | Traduction/transcription vocale six langues | development | technical-gate | FR/EN/FF/ES/IT/mandarin, original conservé, streaming, mesures latence/qualité et échantillons consentis ; aucun faux résultat. |
| B3-05 | Résumé IA et validation humaine | development | technical-gate | Résumé sourcé, décisions éditables, refus de fabrication, validation humaine, isolation et consentement. |
| B3-06 | Bilan historique daté et cloisonnement | replay | replay-isolated | Promoteur/invité, veille, limite 366 jours, dates future/ancienne refusées ; aucune finance pour personnel. |
| B3-07 | Bilan complet multi-périodes, archives, notifications et Q&A vocal | development | technical-gate | Consolidations autorisées, rubriques complètes, archive, notification et interaction vocale ; aucune donnée inventée. |
| B3-08 | Six voix et lecture sur appareils | external | hosted-device-test | Voix locales qualifiées, arrêt arrière-plan, consentement, voix indisponible signalée ; revue Fulfulde. |
| B4-01 | 39 combinaisons activité/mode et interactions ERP | replay | replay-isolated | 39 cycles Chromium ; facturation/avoirs, stocks/transferts, CRM/fidélité, objectifs, charges et concurrence déjà testés. |
| B4-02 | Confidentialité des rémunérations et moteur financier | replay | technical-gate | Dix cas supplémentaires REST/sync dans replay ; moteur fixe/proportionnel, part, bornes et règle manquante ; pas de virement. |
| B4-03 | Configuration facultative des commissions, défaut désactivé | development | technical-gate | Promoteur uniquement ; règles par collaborateur/prestation/activité/site, aucune valeur par défaut, absence de règle sans commission ; contrôle priorités explicites. |
| B4-04 | Raccordement automatique prestations/exécutants/encaissements | development | replay-isolated | Cas terminé + paiement confirmé + allocation explicite ; idempotence, concurrence, annulation et extournes transactionnelles ; sans taux universel. |
| B4-05 | Parité Android/Web/PWA, rôles et deux appareils | partial | technical-gate | Builds, Chromium et instrumentation existants ; compléter toutes opérations par rôle, mode et poste, exports natifs et conflits. |
| B4-06 | Impression et export matériel | external | hosted-device-test | PDF/reçu, Bluetooth/imprimante réelle, pas de doublon ni perte, rapprochement des totaux et exports natifs. |
| B4-07 | Fiscalité SYSCOHADA, paie et commissions réglementaires | external | release-readiness | Visa professionnel daté, comptes et taux validés ; tests moteur ne valent pas certification. |
| B5-01 | Alignement des cinq sources Edge actives | development | cloudflare-preflight | Diff source dépôt/déployé, analyse de divergence, alignement autorisé et test authentifié ; OPTIONS n'est pas la parité. |
| B5-02 | Premier promoteur et authentification cible | external | replay-isolated | Auth Admin officiel en local déjà prouvé ; compte de recette hébergé autorisé, rotation, révocation et séparation ; aucun compte réel créé automatiquement. |
| B5-03 | OM/MoMo abonnement et rapprochement | external | technical-gate | Contrats/intentions testés ; sandbox marchand autorisée, callbacks signés, montants et bénéficiaires ; aucun argent réel ni PIN/OTP. |
| B5-04 | FCM livraison et révocation réelles | external | hosted-device-test | Enregistrement et contrats existants ; deux appareils, reçu physique, permission refusée, token réattribué, logout et notifications ciblées. |
| B5-05 | NAXA SECURITY matériel, WhatsApp, support/partage écran | external | hosted-device-test | Matériel et comptes autorisés, permissions, alerte, escalade, message et partage effectif ; pas de simulation déclarée réelle. |
| B5-06 | Sauvegarde chiffrée/restauration isolée | replay | backup-restore | Bases jetables PostgreSQL, contrôle manifeste/intégrité/ACL, restauration et validation. |
| B5-07 | Restauration hébergée base et Storage | external | backup-restore | Sauvegarde cible autorisée et restauration sur environnement distinct, objets/ACL/chiffrement, aucune destruction production. |
| B5-08 | Contrôle public PWA et cinq passerelles | replay | cloudflare-preflight | Build exact, correspondance preview/alias si disponible, CORS officiel/refus origine tierce ; pas de test métier hébergé. |
| B5-09 | Roue promotionnelle et parrainage en exploitation | external | replay-isolated | Contrats et isolation en local ; validation juridique applicable, activation autorisée et parcours cible ; aucune dépense. |
| B6-01 | Inventaire interactions et traductions FR/EN/FF | partial | technical-gate | Catalogue, ressources et placeholders ; compléter textes indirects, PDF/erreurs, voix et revue linguistique. |
| B6-02 | CGU/PC Fulfulde et consentement versionné | external | technical-gate | Relecture juridique FR/EN/FF ; implémenter version FF et parcours acceptation si manquant ; aucune approbation inventée. |
| B6-03 | Accessibilité et responsive Web/PWA/Android | partial | independent-reserves | Playwright, shell public, tailles et navigation ; compléter lecteur d'écran, contraste, focus, tactile et appareils physiques. |
| B6-04 | Sécurité, performance et audit CDC final | partial | technical-gate | 13 jobs, RLS, session, SQL et compilation ; compléter charge, mesures, couverture exhaustive CDC et audit indépendant. |
| B6-05 | APK debug connecté et recette propriétaire | partial | hosted-device-test | APK debug vérifié et hash/commit ; installation et acceptation physique restent distinctes. |
| B6-06 | Préparation certificat de signature | replay | release-readiness | Présence coffre + empreinte indépendante ; ne jamais générer ou auto-approuver le certificat. |
| B6-07 | Release signée, distribution et autorisation finale | external | release-readiness | Signature commerciale uniquement après autorisation, même SHA, installation et distribution contrôlées ; workflow release non déclenché. |

Clôture : preuve terminale par ID et périmètre, aucun succès par association à un workflow voisin. Les points development/external sont des spécifications de recette et ne sont pas encore exécutables intégralement. La campagne ne certifie pas le lancement commercial.
