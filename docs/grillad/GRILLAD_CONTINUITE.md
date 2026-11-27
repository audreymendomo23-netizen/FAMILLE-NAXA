# GRILLAD — Continuité de construction

**Ouverture :** 27 novembre 2026, Africa/Douala. **Périmètre :** GRILLAD uniquement. **Base auditée :** main @ 8ab45776cd3606b43e97aae5d641fab7f89aa750.

## Références
- [Cahier V1.5](../cahiers-des-charges/GRILLAD_V1_5.md)
- [Passation historique](../passations/GRILLAD_CONTINUITE_2026-11-21.md)
- [Décisions](../DECISIONS.md)

## Décisions non régressives
Cinq familles strictes : porc, poulet, poisson, brochettes, omelettes. Vente directe comme canal principal ; GRILLAD Connect côté ZIPPLE Snack-Bar est l'unique exception partenaire validée en V1.4. Préparé/vendu/restant, caisse, dépenses, coût de revient, marges, organisation mono/multisite et plusieurs vendeurs par point. ACCÈS : 2 000 F/mois, 24 000 F/an, un point multi-vendeurs. PREMIUM : 6 000 F/mois, 60 000 F/an, plusieurs points multi-vendeurs. Pas de PRO, pas de plafond inventé. Les autres propositions et points ouverts de V1.5 ne sont pas activés implicitement.

## 2. Audit statique du 27/11/2026

Base figée : main@8ab45776cd3606b43e97aae5d641fab7f89aa750. Inventaire des arbres Git Android src et Web src non tronqués, lecture des sources GRILLAD et de composants donneurs. Aucun test exécuté, aucune qualification de production.

| Source GRILLAD | Constat |
|---|---|
| apps/android/grillad/src/main/java/cm/naxa/grillad/MainActivity.kt | 611 caractères, titre et message « parcours métier à intégrer ». Pas de parcours opérationnel. |
| apps/android/grillad/src/main/java/cm/naxa/grillad/OfflineQueue.kt | 817 caractères : Room, DAO enqueue/queued/updateState, DB v1. Aucun org/site/acteur/appareil/version d'agrégat, worker ou appel serveur constaté ; pas de raccordement à MainActivity. |
| apps/android/grillad/build.gradle.kts | Compose, Room, core-android, SDK 35, version 0.1.0. Dépendances seules, non preuve d'intégration. |
| apps/android/grillad/src/main/AndroidManifest.xml | Activité lanceur, allowBackup=false ; pas de service ni permission réseau dans ce manifeste. |
| apps/web/grillad/src/main.tsx | 479 caractères : titre, texte du socle PWA et enregistrement service worker. Aucun parcours métier. |
| apps/web/grillad/package.json et public/sw.js | React/Vite, contracts, design-system ; cache shell, pas de synchronisation métier ni dépendance offline-web déclarée. |
| supabase/drafts/0001_famille_core_proposed.sql | GRILLAD dans le catalogue commun ; tables proposées, pas de preuve de migration réelle. |
| supabase/migrations/0002_famille_core_rls.sql | RLS communes ; aucune politique métier GRILLAD démontrée. |
| supabase/functions/ et supabase/tests/ | Aucun endpoint ou test spécifique GRILLAD repéré dans les arbres de main examinés. |

Aucune branche GRILLAD trouvée par recherche de branches. Aucun parcours métier de bout en bout constaté. Aucun pourcentage de code estimé.

## 3. Sources de capitalisation

Les SHA suivants sont des références en lecture, pas des branches à fusionner. Aucun changement chez les donneurs.

- Socle commun main : 8ab45776cd3606b43e97aae5d641fab7f89aa750.
- NAXA SERVICES, work/naxa-services-completion-20261120 : 98929a8996206fcbd2547ca473c5301ebc6938ee.
- ZIPPLE, work/zipple-completion-20261126 : f412b831a8635839cdc07784119f515107e2313c.
- BOOTIK, work/bootik-n0-20261126 : 1e9f0ca96c76f079c5fed2d4782a8ac87961fda9.

Sources effectivement lues : NS SessionVault.kt, SecureLocalDatabase.kt, NaxaServicesSyncWork.kt, NativeReportExport.kt, auth/session.ts, erp/transverse-operations.tsx ; ZIPPLE cash-calculations.ts, DirectSaleWorkspace.tsx, BraiseWorkspace.tsx ; BOOTIK SmsPaymentParser.kt, ScopedOffline.kt ; packages/contracts, offline-web, assistant, LocalInsights, billing-core, LocalAppLock et BiometricGate. Les autres fichiers donneurs cités ci-dessous ont été repérés dans les arbres mais demandent une lecture de compatibilité avant portage. Les recettes existantes chez les donneurs ne certifient pas GRILLAD.

NAXA historique/JOBLY et autres applications de la famille : modèles documentaires, pas d'audit direct approfondi de leur code dans cette passe. Pas de copie de comptes, données, secrets ou règles commerciales des donneurs.

## 4. Matrice des 24 domaines transversaux

Statuts : P = fondation GRILLAD partielle ; A = aucune implémentation propre repérée. V = baseline ou exigence de sécurité/architecture ; O = arbitrage ou extension à confirmer. D = candidat au réemploi direct après tests ; AD = adaptation ; R = réécriture métier sur modèle. Pas de vert sur lecture de code seule.

| ID | Domaine | État/périmètre | Candidat et mode de reprise | Preuve attendue |
|---|---|---|---|---|
| T01 | Shell Android/Web, navigation et accessibilité | P/V | design-system, NS ExperienceScreens, ZIPPLE shell ; AD | Navigation réelle, états erreurs, deux cibles autonomes |
| T02 | Auth, récupération, session | A/V, modalités à cadrer | NS AuthApi, SessionVault, auth/session.ts ; AD | Comptes GRILLAD, session révocable, aucun compte donneur |
| T03 | PIN local, biométrie, coffre | A/V, modalités à cadrer | core-android LocalAppLock/BiometricGate, NS LocalAccessPin ; D/AD | PIN local, repli, essais limités, coffre ; auth serveur distincte |
| T04 | Profil, paramètres, photo privée, CGU/PC | A/V, détails à cadrer | NS PrivateProfilePhoto, Preferences, modèles juridiques NS/BOOTIK ; AD | Documents GRILLAD relus, photo isolée, minimisation |
| T05 | Promoteur, points, modes indépendant/centralisé, multi-vendeurs | A/V | SQL commun, NS auth/session.ts, BOOTIK périmètres ; R/AD | REC-11/12/23/24/27, comptes distincts, aucun mélange |
| T06 | RBAC, RLS, affectation vendeur, journal | A/V | SQL commun, BOOTIK ScopedOffline, NS site scope ; AD | Refus serveur croisés app/org/site, acteur tracé |
| T07 | Plans, paiement abonnement, entitlements, expiration | A/V | billing-core, NS subscription/billing-panel ; AD obligatoire | REC-28, 4 prix, rejet 3/6 mois, ACCÈS refuse point 2 |
| T08 | Paiement vente et rapprochement | A/O moyens ; V sécurité | BOOTIK SmsPaymentParser, ZIPPLE TreasuryReconciliation ; AD | SMS indicatif, aucun PIN/OTP, confirmation serveur idempotente |
| T09 | Catalogue, recherche, unités, prix | A/V | ZIPPLE CatalogDetails/CatalogRules, BOOTIK CatalogSearch ; R | Cinq familles fixes, historique prix, désactivation |
| T10 | Préparations, vendu/restant, ajustements | A/V | ZIPPLE BraiseWorkspace ; R simplifiée | Vente concurrente atomique, pas de production avancée |
| T11 | Vente directe, panier, correction, reçu | A/V, format reçu O | ZIPPLE DirectSaleWorkspace, cash-calculations, BOOTIK SalesPanel ; AD/R | Vente et correction tracées, aucune réservation/livraison |
| T12 | Caisse, sessions, fonds, clôture, écarts | A/V, modèle multi-vendeur O | ZIPPLE CashDeskWorkspace/CashOutflows, BOOTIK CashPanel ; AD | Session/site/auteur, clôture contrôlée, aucun double encaissement |
| T13 | Dépenses, justificatifs, charges | A/V, détails O | NS ManagementModules/RecurringChargeReminderWorker, ZIPPLE CashOutflows ; AD | Dépenses tracées, corrections et rapports |
| T14 | Achats, fournisseurs, inventaire intrants | A/O profondeur | ZIPPLE ProcurementWorkspace, SupplierReturns, BOOTIK PurchasePanel ; AD | Intrants distincts des familles vendues, transferts à cadrer |
| T15 | CA, coûts, marges, résultat, objectifs et pilotage léger | A/V, valorisation O | NS transverse-operations, ZIPPLE FinancialStatements/Pilotage ; R/AD | Coût incomplet signalé, ventilation, pas de certification présumée |
| T16 | Rapports jour/semaine/mois/année, point journalier, PDF/Excel | A/V, formats/conditions O | NS NativeReportExport, ZIPPLE FinanceDocuments/NativeDocuments ; AD | Filtres site/vendeur/période, export privé, fraîcheur |
| T17 | Équipe, pointage arrivée/départ, heure, GPS et photo | A/V multiniveau | NS StaffRosterCard/AttendanceProofJournal, ZIPPLE HrWorkspace ; AD | Affectations révoquées, GPS ponctuel et photo privée aux deux événements, durée et anomalies ; pas de suivi GPS permanent |
| T18 | Stockage sécurisé, offline et sync | P/V isolation ; O étendue | NS SecureLocalDatabase/SyncWork, BOOTIK ScopedOffline, contracts/offline-web ; AD | Périmètre compte/site, idempotence, conflits, reprise |
| T19 | Langues, locale, formats | A/O langues ; V cohérence | NS resources FR/EN/ff-CM et Web locale ; AD | Chaînes propres, traductions relues, FCFA/Douala |
| T20 | Notifications, alertes, push | A/V centre et alertes ; O canaux externes | core-android BriefingScheduler/Worker/Channels, NS NotificationInbox/FirebasePushClient ; AD | Préférences, déduplication, accusés réels |
| T21 | FAQ, support, Livechat, admin central | A/O fonctions ; V séparation | SQL support_tickets, ZIPPLE SupportGuide, NS support à vérifier ; AD | Tickets isolés, transfert humain si approuvé, pas d'accès global aux données |
| T22 | Parrainage, QR, récompenses | A/O | NS ReferralScreen et modèles ledger ; AD | Règles GRILLAD validées, anti-doublon/auto-parrainage |
| T23 | Prédiction ventes/CA, quantités conseillées et recommandations | A/V prédiction légère ; O assistant étendu | assistant explainSignals, core-kotlin LocalInsights, NS PerformanceEngine, ZIPPLE intelligence ; AD | Explicabilité, pas d'action sensible autonome |
| T24 | Vidéosurveillance multiniveau, sécurité, sauvegarde, Connect | A/V vidéo et Connect ; O modalités | core-web verifyManifest, recettes NS/ZIPPLE, NAXA SECURITY à auditer ; AD | Restauration, CI, contrôle réseau, vidéo privée par site et révocation, Connect sous contrat et droits ; caisses et commandes séparées |

**Bilan : 24 domaines audités, 2 fondations partielles (T01/T18), 22 sans implémentation propre repérée, 0/24 qualifiés verts, 0 recette exécutée.** Indicateur de qualification et non taux de code. Les extensions ouvertes ne deviennent pas des exigences commerciales par cette matrice.

## 5. Contradictions et blocages prioritaires

1. Facturation : billing-core/src/index.js, blob da850b2a141f8d78eeb3a09a92c3681e2da3382f, packagePrice(monthly,months) accepte 3/6/12 mois et calcule 12 = 10 × mensuel. ACCÈS sortirait à 20 000 F au lieu de 24 000 F. Catalogue GRILLAD explicite par plan/cycle, sans modifier les autres apps. Pas de prorata/gift automatique non validé.
2. Offline : Room GRILLAD ne porte pas org/site/acteur/appareil/version ; DAO queued non filtré. Adapter SyncEnvelope et modèle BOOTIK/NS avant usage réel.
3. PWA : SW utilise famille-shell-v1, efface les autres caches à l'activation ; offline-web utilise famille-naxa-offline et QueueItem sans périmètre. Risque si origine partagée ; cache/DB isolés, données privées exclues du cache réseau par défaut.
4. Backend : code SQL commun ne prouve pas le déploiement. Schéma, API/RLS métier GRILLAD et tests croisés à construire.
5. PIN/biométrie : BiometricGate exige FragmentActivity tandis que MainActivity GRILLAD hérite ComponentActivity. Adapter le cycle de vie, ne pas assimiler verrou local et autorisation.
6. ZIPPLE BraiseWorkspace plus riche que GRILLAD : ne reprendre que contrôles quantité/idempotence. Pas de cuisson avancée, tables, réservations, précommandes, livraison, marketplace ou sixième famille.
7. Parseur SMS BOOTIK : candidat, jamais preuve de règlement ; séparation ventes/abonnements, contrôle serveur.
8. GRD-014 prime sur FAM-020 pour ACCÈS. Les éléments [O], [C/O], [P/O], [B] du cahier V1.3 restent conditionnels : parrainage, assistant IA étendu, offline étendu, langues, support, achats détaillés, méthode coûts, caisse multi-vendeur et modalités vidéo/canaux externes. Pointage GPS/photo et Connect Snack-Bar validés par V1.4 ; prédictions, CA, rapports, pilotage léger, point journalier, notifications et vidéo multiniveau validés par V1.5. Ne pas importer règles métier spécifiques des donneurs sans arbitrage.

## 6. Plan de construction proposé — six bulks parallèles

| Bulk | Domaines | Résultat |
|---|---|---|
| B1 Socle, identité, accès | T01–T06 | Shell, auth, profil, organisation, permissions, audit |
| B2 Commerce/production simple | T09–T12 | Catalogue strict, quantités, vente directe, caisse |
| B3 Finance et pilotage | T13–T16 | Dépenses, coûts/marges, CA, rapports et point journalier, pilotage léger ; intrants simples selon arbitrage |
| B4 Équipe et expérience | T17, T19–T21 | Équipe, pointage GPS/photo, notifications ; langues/support selon périmètre |
| B5 Souscription et résilience | T07, T08, T18 | Tarifs exacts, paiements, outbox cloisonnée |
| B6 Extensions et qualification | T22–T24 | Connect Snack-Bar, vidéo multiniveau, prédictions, sécurité, exploitation, recettes |

Contrats stables permettant construction en parallèle ; scopes B1 et contrats B5 obligatoires avant écritures réelles B2/B3. Tests B6 dès le départ. B1 et B5 ont chacun une fondation partielle ; aucun bulk vert.

## 7. Recettes et garde de sortie

REC-01 à REC-39 du cahier V1.5 maintenues. Compléments transversaux à construire : auth/révocation ; PIN/biométrie/repli ; refus croisés app/org/site/rôle ; changement de compte/cache/outbox ; concurrence vendeurs sur stock limité ; consolidation sans mélange ; quatre montants et rejet 3/6 mois ; paiement pending/échec/rejeu ; reprise et conflits ; rapport partiel ; PWA isolation et absence de cache privé ; export privé ; traduction et support/notifications selon validation ; restauration ; tests Android, Web Chromium, API/RLS en environnement de test. Rien n'est déclaré exécuté.

## 8. Journal et limites

- 27/11/2026 : document dédié créé (commit 1acfa53dd2b1b079ba7830b258fec10f442acafb), 24 domaines inventoriés, trois donneurs épinglés, blocages documentés, plan B1–B6.
- Aucune modification de code Android/Web/Supabase ou des autres applications, aucun build/test/CI déclenché volontairement, aucune migration ni déploiement. Travail documentaire main conformément à AGENTS.md.
- Audit statique des sources disponibles : pas d'inspection de l'environnement Supabase réel, pas de réexécution des tests donneurs ni lecture de tous leurs fichiers, ni de toutes les conversations historiques. Les points ouverts restent à arbitrer avant activation. Le prochain chantier de construction doit commencer par les contrats d'accès, de facturation et d'isolation.

## 9. Arbitrages du 27/11/2026 — historique V1.4

- GRD-015 : application légère, récupérer les fonctions de base de toute la famille ; éviter ERP complexe, comptabilité générale, paie avancée et production industrielle. Conserver contrôles serveur et traçabilité derrière une UI simple. Les 24 domaines sont un inventaire de couverture et non une liste de modules lourds obligatoires.
- GRD-016 : pointage arrivée ET départ avec heure, GPS ponctuel et photo en architecture multiniveau. Interprétation proposée : Manager + vendeurs, même dans un point ACCÈS, et réseau PREMIUM ; pas d'obligation pour le manager seul. Durée, anomalies, corrections tracées, preuves privées ; pas de GPS permanent ni reconnaissance faciale. Seuils, rétention, exceptions et offline restent à cadrer.
- GRD-017 : GRILLAD Connect côté ZIPPLE Snack-Bar, seule exception partenaire à la vente directe. QR avec deux espaces, commandes/paiements/caisses/stocks/recettes séparés ; droits et accords réciproques, partenaire actif, catalogue et disponibilité GRILLAD. Maintenir le modèle Premium existant sous réserve de vérification du contrat exact ; aucun nouveau tarif. Aucun accès ZIPPLE aux données internes ou RH. Contrat et recettes restent à construire.
- Réemploi confirmé comme candidat par inspection additionnelle : NAXA SERVICES apps/web/naxa-services/src/erp/attendance-proof.tsx (GPS récent, caméra, stockage privé, requêtes scope), AttendanceProofJournal.kt (journal et replay) ; ZIPPLE ZippleAttendance.kt (GPS ponctuel et validation de réponse), TableQr.tsx (génération QR locale, pas preuve d'intégration Connect). Les paramètres spécifiques aux donneurs ne sont pas automatiquement appliqués.
- Documents historiques retrouvés depuis l'audit : docs/apps/grillad/CAHIER_DES_CHARGES.md et PROMPTS.md ; leur périmètre ERP/production avancée et leurs anciennes propositions ne prévalent pas sur V1.4.
- B4 porte le pointage ; B2 fournit commandes/préparation simple ; B6 porte le contrat Connect et la recette croisée, B1/B5 assurent droits et paiement. REC-29–33 ajoutées. Aucun code, test ou déploiement exécuté ; jauge inchangée.

## 10. Arbitrages complémentaires du 27/11/2026 — V1.5 prévaut

- GRD-018 : vidéo multiniveau via NAXA SECURITY, consultation simple des caméras autorisées par site, direct, état et incidents ; aucun accès vendeur par défaut, ni partage ZIPPLE. Interprétation multiniveau identique au pointage : manager + vendeur(s) même en ACCÈS, ou réseau PREMIUM, sous réserve des droits NAXA SECURITY. Matériel, accès aux extraits, rétention, coût, quotas et conditions de souscription à cadrer ; pas de gratuité présumée. Information du personnel, zones appropriées, pas de surveillance cachée, audio ou biométrie par défaut. Référence documentaire : docs/naxa-security/NAXA_SECURITY_CAHIER_DES_CHARGES_V1.1.md (blob cc8ae1703c0b91badd894c007a83a2e73a41ecc7) ; aucun flux vérifié.
- GRD-019 : CA par site/vendeur/article/famille/période, rapports synthétiques, objectifs facultatifs et pilotage léger, point journalier automatique. CA net des ventes validées distinct des encaissements, marge indicative, état partiel explicite, journée de service pouvant traverser minuit, consolidation sans doublon ZIPPLE Connect. Formats PDF/Excel et heure de synthèse à qualifier.
- GRD-020 : prédiction des ventes, CA et quantités utiles à préparer, basée sur historique confirmé ; estimation séparée du réalisé, qualité et données insuffisantes, aucune action autonome. Réutiliser NS PerformanceEngine.kt (blob f125b2f310987b037e1ba489a858a781d1e1a2f2) et ZIPPLE pilotage.mjs (6327042f05024a1c7c548a4552ac07ce9a35777d), lus comme candidats ; simplifier et adapter au service GRILLAD.
- GRD-021 : notifications centre interne, alertes et point journalier, scope/rôle, préférences et déduplication ; push à qualifier, canaux externes non imposés. Réutiliser NS daily-briefing.tsx (a07adeefa7574740f13455a6386c1d5fc2de9bd6) et socle notifications. Aucune livraison distante prouvée.
- REC-34 à REC-39 ajoutées. B3 porte CA/rapports/point journalier, B4 notifications et droits du personnel, B6 vidéo/prévisions et Connect ; B1/B5 portent habilitations et souscription. Jauge inchangée : aucun code GRILLAD, build, recette ou déploiement dans cette passe documentaire. Les tarifs ACCÈS/PREMIUM et les cinq familles restent inchangés.
