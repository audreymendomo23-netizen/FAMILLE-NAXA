# Exécution simultanée — Lot 1 des cinq pistes (0.3 à 0.13)

Date : 14 novembre 2026  
Branche : main  
Commits du lot : `d19ae2d0b512c0bf71f343596b2d1677a7671263` (générateur), `d560615af51bc0e2ef1725f26cdec1c2b3161e17` (CI Web/Android), `c56040653763e9ce0d476d7db71ad9704fa631b1` (mapping Gradle), `d30a59db0d8a8f1157f6b640a80a4c01e13a50a1` (installation SDK), puis extensions console Admin et moteur explicable jusqu'au commit CI `29e88e990d1258545058011fa3afaa6e8013cab2`.

## 1. Ce qui a été effectivement créé

- `scripts/bootstrap-foundations.mjs` : générateur déterministe des socles Android Kotlin/Compose et Web/PWA pour les dix applications.
- Les projets Android générés ont chacun un module Gradle, un manifeste Android et une activité Compose native minimale.
- Les dix applications Web/PWA ont chacune un package Vite/React, un index responsive, une configuration Vite et un manifeste PWA.
- `packages/contracts` : contrats partagés de synchronisation versionnée, identité d'application, types de preuves de paiement et états de notification ; politique de conflit qui interdit l'écrasement silencieux des événements financiers et exige une compensation pour les conflits de stock.
- `packages/design-system` : premiers jetons partagés de thème/couleurs.
- `packages/assistant` : moteur de règles déterministes explicables, soumis à décision humaine.
- `apps/web/admin-console` : coquille Web de la console Admin ; aucune opération privilégiée n'est encore activée.
- `infra/SECURITY_BASELINE.md` : règles de sécurité client.
- `infra/RELEASE_MANIFEST.md` : exigences de distribution APK hors Play Store.

Le générateur est versionné ; les projets générés sont produits à l'exécution CI et ne sont pas encore matérialisés comme fichiers suivis dans Git. Il faut les matérialiser dans un lot dédié après validation de la génération.

## 2. CI et preuves

Workflow : `.github/workflows/famille-technical-gate.yml`.

- Les dix cibles Web/PWA ont passé une compilation Vite sur le run `43550594076` avant que l'installation Android ne bloque le job.
- Les 20 manifests et les manifestes Android/PWA ont été générés et contrôlés avec succès dans les runs successifs.
- Les jobs PostgreSQL 17 du draft 0001 et des assertions 0002 ont réussi sur des bases éphémères dans les runs `43550680382` et `43550728397`.
- L'action `android-actions/setup-android@v3` échouait car elle tentait d'installer le paquet SDK obsolète `tools` alors que le runner préinstallait un sdkmanager récent. Elle a été remplacée par l'acceptation des licences et l'installation explicite de `platforms;android-35`, `build-tools;35.0.0` et `platform-tools`.
- Le run `43550728397` est en cours au dernier contrôle ; le job Android est à l'étape de préparation du SDK. La compilation native des dix apps n'est donc pas encore prouvée.
- Le dernier commit CI `29e88e990d1258545058011fa3afaa6e8013cab2` a déclenché un nouveau run ; son résultat final doit être récupéré.

Liens :
- [Workflow CI](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/workflows/famille-technical-gate.yml)
- [Run 43550728397](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/43550728397)

## 3. Statut par piste

| Piste | Avancement prouvé | Non couvert — donc non vert |
|---|---|---|
| A — sécurité, identité, comptes, paiements, admin | Contrats d'événement et de paiement ; baseline sécurité ; coquille admin | Pas de raccordement Auth/RLS NAXA, pas de provisioning, MFA, permissions serveur, workflow paiement ni journal Admin complet. Les défauts 0002 connus restent ouverts. |
| B — stockage, sync, notifications, briefings | Contrat de synchronisation, versionnement, décisions de conflit, états de notification | Pas de Room/SQLite, queue persistante Android, service de sync serveur, FCM, WorkManager ni briefing opérationnel. |
| C — 10 Android + 10 Web/PWA + design | Générateur des 20 squelettes ; 10 Web compilées ; thème partagé initial | Compilation Android encore en attente ; écrans métier, authentification, navigation, accessibilité, offline et thèmes propres aux apps non implémentés. |
| D — signature, exports, versions, distribution | Contrat de manifeste et règles d'intégrité | Pas de keystore CI, signature, validation serveur, exports PDF/XLSX, site de téléchargement ni publication. |
| E — IA locale et explicable | Moteur de règles explicables supervisé par humain | Pas de modèle embarqué, données locales, anonymisation testée, connecteur IA ni tests de confidentialité. |

## 4. Limites et sécurité

Aucun changement n'a été appliqué au projet Supabase NAXA réel. Aucune migration, DDL/DML, modification Auth, déploiement ou publication n'a été effectué. Les contrôles SQL sont uniquement exécutés sur PostgreSQL 17 éphémère.

Les assertions 0.3 existantes passent, mais elles ne démontrent pas encore l'isolation inter-app/inter-organisation/inter-lieu exhaustive. Le prompt 0.3 reste NON VERT. Les prompts 0.4 à 0.13 restent NON VERTS.

## 5. Point de reprise exact

1. Récupérer le résultat du run `43550728397` et du run déclenché par `29e88e990d1258545058011fa3afaa6e8013cab2`.
2. Corriger les erreurs Gradle/SDK jusqu'à compilation native des dix modules.
3. Matérialiser les fichiers générés dans Git (pas seulement dans l'environnement CI).
4. Ajouter Room/SQLite et une queue offline persistante ; tests d'idempotence, séquence et reprise réseau.
5. Reprendre 0.3 : cartographier le backend NAXA canonique, corriger les helpers/policies avec contexte app et tests négatifs inter-app/org/lieu ; ne pas appliquer en Production.
6. Étendre simultanément provisioning, paiement, notifications, Admin MFA, distribution et règles IA avec tests spécifiques.

**État global : fondations simultanées initialisées ; aucun prompt 0.3–0.13 déclaré VERT.**


## Extension du lot 1 — offline local (commit e919bed3cb26768a95e7a665fbf4c8ad7e8bc3d4)
Le générateur crée maintenant une file persistante Room par application Android, une file IndexedDB commune pour les cibles Web, et un service worker PWA limité au shell statique. Les routes Auth et API sont explicitement exclues du cache. Ces composants constituent un stockage local initial : ils ne prouvent pas encore la synchronisation serveur, le rejeu idempotent bout en bout, la résolution des conflits en ligne ou les notifications push. Les builds Web et tests de contrats/règles sont passés dans le run `43550999833`; le build Android de cette version est encore en cours au dernier contrôle.


## Diagnostic compilation Android et correction
Le premier build natif (run `43550939743`) a atteint `:bootik:compileDebugKotlin` puis échoué sur l'incompatibilité JVM Java 8/Kotlin 17. Le générateur a été corrigé pour aligner Java et Kotlin sur 17 dans chaque module (`d5dbea85e3340c2ce0e002c7544bbdfbcc25a30e`). Le run post-correctif doit fournir la preuve finale de compilation ; il était encore en préparation Gradle au dernier contrôle. Le workflow est maintenant sérialisé par groupe de concurrence pour éviter les collisions de cache causées par les pushes successifs.
