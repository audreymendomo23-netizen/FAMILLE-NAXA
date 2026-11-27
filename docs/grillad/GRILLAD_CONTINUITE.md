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

## 11. Construction N0 et premier socle léger — 27/11/2026

Branche dédiée `work/grillad-foundation-20261127`, créée depuis main dbd4564bc6dd20b21a753ca9a2df59b0c57357ff afin de ne pas toucher à main ni aux applications voisines pendant le développement (choix de travail isolé, aucune fusion). Le cahier V1.5 demeure la référence.

### Preuves Git
- f22a5090adedc07f4a8354c93d12eabeab509a26 : préparation Cloudflare/Firebase, validation publique, règles statiques et quatre tests à blanc.
- f02667348fe7390d47b8a9a0e4b05a60fd59ef44 : Web local, moteur de démonstration et recettes Chromium.
- 400f952b3bf4a0aaa5d3eda4d417d71440929ee2 : Android natif Compose et workflow dédié.
- 05d9a48d5cba5dfc11170c88d2d94837679bbff6 : garde de non-publication, attribution vendeur fictif et rapports calendaires Web.

### Couverture constatée (construction locale seulement)
17 entrées Android et Web (Accueil, Catalogue, Préparations, Ventes, Caisse, Dépenses, Équipe, Points de vente, Rapports, Prévisions, Point journalier, Notifications, Vidéosurveillance, ZIPPLE Connect, Abonnement, Profil, Aide). Catalogue cinq familles, quantités, caisse, vente, charges, marge indicative, rapports, simulation plans exacts et alertes locales sont raccordés à un moteur en mémoire. Web : attribution vendeur démo, objectifs par site, filtres jour/semaine/mois/année et consolidation démo. Android : moteur natif simplifié, parité exacte à compléter. Aucune persistance des données de démonstration ni authentification serveur. Prévision locale de quantités sur jours de vente observés, non modèle de demande validé. Les entrées vidéo, Connect, pointage GPS/photo et support indiquent explicitement que le service réel n'est pas raccordé. Pas d'achat ni paiement réel. Aucun vert métier revendiqué pour REC-01–39. Le prototype ne doit pas traiter de vraies données.

### Infrastructure et qualification
Cloudflare et Firebase : voir INFRASTRUCTURE.md. Aucun accès administratif permettant de créer ou vérifier un projet Cloudflare Pages ou Firebase dédié ; FCM non intégré. Check Cloudflare monorepo automatique détecté, pas preuve de projet GRILLAD. Aucune migration ou déploiement de production volontaire. Publication release bloquée par script tant que vrai auth/backend absents.
- [Run 46069501371](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46069501371), SHA 400f952b3bf4a0aaa5d3eda4d417d71440929ee2 : job infrastructure success (4 tests), Web tests unitaires et build candidat success ; Chromium encore en cours au relevé. Android échec avant compilation : setup-android@v3 recherche le paquet SDK obsolète tools ; correction v4 alignée NAXA SERVICES dans le commit suivant. Pas de preuve APK.
- [Run 46069600370](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46069600370), SHA 05d9a48d5cba5dfc11170c88d2d94837679bbff6 : en file au relevé. Une nouvelle qualification sera déclenchée par le commit de correction SDK. Ne pas reporter le vert d'un ancien SHA sur le HEAD.

### Prochains critères obligatoires
N0 : créer/vérifier projet Pages GRILLAD, client Firebase dédié, FCM réelle ; B1/B5 : auth/session et scopes RLS, entitlements, API, persistance sécurisée, sync et confirmation des paiements ; B2/B3 : opérations atomiques, corrections, parité Android/Web, rapports et service minuit, export et vraie prévision ; B4 : pointage GPS/photo privé et gestion équipe ; B6 : vidéo NAXA SECURITY et Connect ZIPPLE Snack-Bar sous contrat et droits ; 39 recettes métier et sécurité réelles à exécuter. Aucune extrapolation de complétude à partir du nombre d'écrans.

## 12. Directive produit — Android natif, autonomie et excellence visuelle

Décision exprimée le 27/11/2026 : GRILLAD est une application autonome de la Famille NAXA, simple, excellente et belle, Android native. Cible principale : Kotlin + Jetpack Compose, package cm.naxa.grillad, APK propre, identité et navigation propres ; aucune WebView ni interface ERP générique comme application Android. Authentification et données GRILLAD isolées ; services transversaux et intégrations autorisés par contrats, sans dépendance à l'installation de ZIPPLE ou NAXA SERVICES. Le Web/PWA existant est conservé comme surface complémentaire et environnement de recette, non comme substitut à l'Android. Cloudflare pour les surfaces web et QR autorisées ; Firebase pour les notifications ; aucun projet tiers ni backend de production déclaré actif.

Orientation UX proposée : quatre destinations principales Accueil, Vente, Activité (préparations, caisse, dépenses), Plus (profil, équipe, rapports, sécurité, abonnement, Connect selon droits). Accès rapide à la vente depuis l'accueil ; navigation adaptée aux rôles, sans exposer les 17 destinations comme un ruban permanent. Palette chaude grillades, accent braise, surfaces lisibles, thème clair/sombre, typographie et icônes cohérentes, grands contrôles tactiles, états vides/erreur/chargement utiles. Aucun logo ni palette finale imposés par cette décision. Minimiser les étapes de vente et afficher les informations métier dans le contexte, sans supprimer aucune fonctionnalité validée en V1.5. Préserver les prix, les cinq familles, le pointage, la vidéo multiniveau et ZIPPLE Snack-Bar.

Gate Android prioritaire : compiler/tester l'APK natif, recettes Compose sur appareil, lisibilité et navigation sur petits écrans, parcours réel vente/préparation/caisse, droits, qualité visuelle, performances sur appareils modestes et états réseau. Les résultats Chromium ne qualifient pas Android. Les preuves restent à produire. Cette passe est une clarification documentaire, pas une modification UI ni une qualification.

## 13. Audit de charte et construction mobile-first — 27/11/2026

### Sources graphiques effectivement lues
- Dépôt historique NAXA, `7 famille naxa/02-prompts/08-refonte-du-design.md` (blob e417eba97016681e44af9c82b2a7bdc7b2fb5e6e), prompt 8.0 : sept palettes officielles, directions A/B/C, cartes 18 dp, champs 16 dp, boutons 48–52 dp, espacement 4/8/12/16/24/32, contraste texte 4,5:1, clair/sombre, animation légère et réduction des mouvements, FR/EN. GRILLAD n'est pas dans les sept palettes/directions. Ne pas lui attribuer la palette de KIOSKO Callbox, ZIPPLE ou NAXA SERVICES.
- Historique `00-socle-commun.md` (blob 98839936d355e04bd09faa099790d7f6c311d94d), prompt 0.9 : même réserve ; `08-grillad.md` (blob 8f4a1e7758bc1a6ada6b3cd5db2ebd9113d48c14) : identité autonome, périmètre métier ; kit et continuité du 10/11 consultés. `packages/design-system/src/tokens.css` (cc37d1d4541733ff3c31f85b39ceb0c200d9f5da) : palettes des trois dernières applications non validées ; aucune palette GRILLAD.
- 14 fichiers d'inspiration historiques Kiosco (Grillades) repérés par inventaire, pas de logo définitif identifié ni pixels inspectés. Recherche bibliothèque et contexte antérieur sans charte spécifique probante. Ne pas inventer une validation.
- Réemploi du modèle de thème NAXA SERVICES `NaxaServicesTheme.kt` (9b12c684b8620393c9647759aaa8530baec12c28) : Material3 et jetons sémantiques ; palette GRILLAD provisoire héritée de la proposition §12, accent #A43C0C en clair, #FFB785 en sombre, fond clair #FBF6EF, sombre #181411, surfaces #FFFFFF/#251E19. Monogramme G temporaire (pas le logo officiel). Police système temporaire ; aucune police embarquée validée. FR existant, EN et revue d'accessibilité exhaustive restent à faire.

### Code et preuves par SHA
- 62116b711a21c87ceda40b7574f62b76ef0da96f : refonte native Compose (GrilladTheme, Hero, Metric, barre inférieure quatre destinations), Web mobile-first avec navigation adaptée desktop, apparence clair/sombre/système et accès rapides, PWA manifeste dédié, icône provisoire, cache isolé et précompilation des ressources de build. 17 entrées conservées. [Run 46071244283](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46071244283) : 3/3 jobs SUCCESS, Android APK debug et unitaires, Web build et Chromium, infrastructure. Ce n'est pas une recette sur appareil ni la validation exhaustive visuelle.
- af5d603190a79f0ae882fe3e03607ba524fa0912 : draft `supabase/drafts/grillad_business_v1.sql` et test `supabase/local-tests/grillad_business_v1_assertions.sql`, privé par défaut, RPC à périmètre GRILLAD, session et droits, opérations atomiques sérialisées par site, idempotence et conflits, préparation, vente, annulation, caisse, dépenses, objectifs et synthèse. [Run 46071426442](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46071426442) : Android/Web/infra success, SQL échec variable cash ambiguë dans snapshot.
- 7f9e85d27aef147758d4f01c8224541efe3e5249 : correction SQL, moteur local Android/Web enrichi annulation motivée et restitution stock, clôture écart motivé, vendeur démo, rapports calendaires, objectif site, recette PWA compilée offline. [Run 46071597898](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46071597898) : infra, SQL isolé et Web SUCCESS constatés ; 6 tests métier Web et 4 recettes Chromium passés d'après logs, dont viewport 320px, thème sombre et rechargement offline ; Android en cours lors du relevé. SQL tests rollback, aucun hébergement Supabase modifié.
- 5cf6808ad3cdb28f9ae4645afdb3ef8e705e5b24 : renforcements d'entitlements : quatre codes tarifaires exacts, liste de sites explicitement activés pour GRILLAD (refus des sites communs non activés), scope propriétaire/gérant/vendeur, RPC workspace dérivé serveur, refus ACCÈS si plusieurs sites actifs. [Run 46071701536](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46071701536) en qualification au relevé. Ne pas reporter les preuves de SHA antérieurs sur cette modification.

### Limites et suite de construction
Le moteur serveur est un candidat PostgreSQL isolé, pas une migration déployée. Les deux UI restent en mode de démonstration mémoire, sans session réelle ni raccordement HTTP. Le modèle central de session `famille-account-lifecycle` et le draft 0004 compte/appareil ont été inspectés ; la recette d'intégration du cycle de vie réel (provisionnement, login, appareil, récupération, renouvellement/révocation) reste requise ; le test actuel utilise le contexte signé simulé 0003. Les preuves privées GPS/photo, sync métier persistante, FCM, vidéo NAXA SECURITY, commandes/paiements ZIPPLE Connect, rapports exportés, traductions complètes, assistant étendu et parrainage restent à construire/qualifier selon les arbitrages. Aucun flux réel, appareil ou paiement simulé présenté comme opérationnel. Le cache PWA hors ligne ne constitue pas une synchronisation métier. Aucun logo final choisi ; pas de déploiement de production, fusion main ni migration hébergée. Le connecteur Cloudflare automatique peut générer des previews de branche ; pas de projet GRILLAD dédié confirmé.

Jauge : aucune des 39 recettes du cahier V1.5 n'est déclarée entièrement qualifiée sur les vrais clients, API, RLS et services réels ; les tests locaux ci-dessus constituent des preuves intermédiaires. Android prioritaire, Web responsive complémentaire, ne pas complexifier l'interface.

## 14. Poursuite intégrale du chantier connecté — 27/11/2026

### Baseline et preuves exactes
Révision db406f145d0ba4bb9411732503544f5d8b4d0421 : [run 46071835948](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46071835948), 4/4 success. Corrige et qualifie le renforcement des droits de §13.
- da64956b50ab5b168ed2df46bf630e4ffc462e77 — passerelle GRILLAD et client Web connecté, contrôle du périmètre serveur et reprise du même UUID en cas de réponse incertaine, sans confirmation locale fictive. [46072304573](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46072304573), 4/4 success.
- ee8cd2766e5ee1d4a235be066fe5a411652051c7 — client Kotlin/Compose connecté, opération métier par RPC, modification prix historisée, rapports et prévisions initiales. [46072396081](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46072396081), 4/4 success.
- e9269c395c180bd673f0f97d32b550f95d1c46fe + 8707584a2801e96899ad6df6beb7f23959832b76 — preuves privées de pointage et clients GPS/photo; serveur isolé success, Android échec import Gradle util. Correctif 20365c692918cf6e3d2541d52c683fd2570689b0, [46072690132](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46072690132), 4/4 success ; recette Chromium de client connecté sur HTTP simulé.
- 015839b0d68ff43c4784e8e9e49492bd04702e77 — adaptation du cycle de vie 0004, GoTrue, registre d'appareils et session liée à GRILLAD, quatre comptes (promoteur + trois vendeurs) sans éviction croisée, révocation, throttling. [46072800306](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46072800306), 4/4 success. Règle technique proposée : deux appareils actifs par utilisateur, pas de plafond vendeur/site ; support, vraie récupération, activation/mot de passe, authentification réelle à qualifier.
- 4fc275ad8d6935b6ce4c7951cc3084e6c802b1db — point journalier versionné et rejouable par service, heure configurable, centre de notifications et préférences, identifiant installation stable. [46073008551](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46073008551), 4/4 success. Pas de cron hébergé créé.
- 0f1811ae8b8a167d519dea997c601661682ad243 — ZIPPLE Connect côté GRILLAD, liens bilatéraux, QR opaque, panier distinct, réservation lors de l'acceptation, transitions, paiement espèces séparé candidat à la remise, stock/CA et replay. [46073166002](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46073166002), 4/4 success. Voir ZIPPLE_CONNECT_CONTRACT.md.
- 88f9f4bc1900e7bbebf3f916da1c7327210e8b36 — rapports filtrés site/famille/article/vendeur, consolidation autorisée et mode indépendant par défaut ; export CSV Web et partage texte Android. Projection de liste caméras/incidents NAXA SECURITY avec liaison explicite, droits et fraîcheur, direct non activé. [46073431133](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46073431133), 4/4 success. Aucun flux réel ; audit de NAXA SECURITY indique clients squelettes, voir NAXA_SECURITY_CONTRACT.md.
- 6eb17acf999189ea635ac81d73347c23b845c7f2 — inscription FCM Android avec consentement, registre privé et message générique. [46073536687](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46073536687), serveur/Web/infra success, Android échec kaptDebugKotlin, logs sans cause interne détaillée. Aucun projet/clé réels, aucun envoi réel. Voir FIREBASE_CONTINUITY.md.
- e530eceabbb47d8d0d3b247792c1f2dcf57c9435 — objectifs CA, prévision déterministe basée sur services clôturés, quantité/CA, limites de stock, historique insuffisant, comptage Connect corrigé. [46073601625](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46073601625), serveur/Web/infra success, Android échec KAPT.
- 37a1cacf560c64ae239ea1a1bcc9b47ff5d9fc89 — parcours client QR GRILLAD, catalogue, panier indépendant et suivi, replay. [46073663145](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46073663145), serveur/Web/infra success, Android échec KAPT. Recettes Web avec endpoint simulé, pas un test inter-applications réel.
- c722c272ef2bbbc58e77335ea2fa37f6943e04e4 — correctif technique : combinaison KSP 2.0.20-1.0.25 et Room 2.8.5 reprise de NAXA SERVICES (même Kotlin 2.0.20, BOM Firebase 35.2.0) uniquement dans GRILLAD, stacktrace activé. [46073734120](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46073734120), serveur/Web/infra success, Android en cours au relevé. Ne pas annoncer le vert de la correction avant résultat.
- 6c692d20050cf9c923638d072700730c18497806 — panier direct multiarticles transactionnel, annulation groupée motivée, prix attendu contrôlé, compte une vente par panier et non par ligne, stock direct/Connect commun sans double consommation, reprise même événement, UI native/Web et assertions serveur. [46073856860](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46073856860), infra success, Android/Web/serveur en cours au relevé. Tests de panier à qualifier.

### Jauge de reprise par bulk (construction/qualification séparées)
- B1 — socle/navigation/identité/droits : construit candidat, 4/4 sur auth bridge; cycle complet GoTrue réel, provisionnement, verrou local et session coffre à qualifier.
- B2 — ventes/catalogue/préparations/caisse : opérations principales et Connect qualifiées serveur isolé sur SHA antérieurs, panier multiarticles ajouté en qualification, reçus/paiement réel et politique caisse/retours à finaliser.
- B3 — finance/pilotage : dépenses, rapports filtrés, consolidation, CSV et partage construits ; objectifs/prédiction/point journalier candidats ; coûts de composition, export PDF/XLSX et complétude des filtres réels à qualifier.
- B4 — équipe/pointage/notifications : capture GPS et photo native/Web, paire arrivée/départ, politiques et préférences, centre interne ; correction de pointage, preuve photo consultable et audit, rétention, invitations et FCM delivery à terminer.
- B5 — abonnements/offline : quatre prix exacts, entitlements et revocation ; paiement vérifié, persistance de session et outbox métier durable, arbitrage du périmètre offline, conflits et tests hors réseau à terminer.
- B6 — prévisions/Connect/sécurité : prévisions légères, commandes/QR côté GRILLAD et caméra/incident read-only construits ; aucune passerelle NAXA SECURITY opérationnelle trouvée, pas de flux live/extraits; contrat et QR ZIPPLE réels, worker FCM, historiques/annulations après remise à qualifier. Parrainage, assistant conversationnel étendu, langues et Livechat restent conditionnels aux arbitrages V1.5.

### Réserves de construction et activation
Toutes les données de recettes sont fictives. Les drafts sont exécutés uniquement dans PostgreSQL jetable ; ni Supabase hébergé ni main modifiés ; aucun déploiement, publication APK, partenaire réel, projet Firebase réel, paiement réel ou caméra réelle activés. La version connectée est conditionnée à la configuration explicite du service GRILLAD ; le build sans configuration reste démo. Les preuves HTTP Chromium utilisent des interceptions, pas GoTrue ni API hébergée. Pas de test sur téléphone physique exécuté. Les opérations incertaines sont conservées en mémoire uniquement ; une fermeture/reprise durable requiert coffre/outbox et traitement explicite de l'état incertain. Les règles de service, pointage, vidéo et consolidation sont des politiques à provisionner (désactivées par défaut). Récupération compte, réinitialisation mot de passe et support ne sont pas prouvés bout en bout. FCM inscription ne signifie pas livraison ; worker dédié, session/appareil actif et accusé appareil sont requis. Aucune décision de commission ou de tarif supplémentaire. Palette et logo demeurent provisoires. Le gate de release reste bloquant volontairement.
Les 39 recettes V1.5 doivent être réconciliées ligne à ligne avec ces preuves partielles, API réelle, clients et services physiques. Pas de pourcentage global inventé, ni de déclaration « application prête ». Tous les chantiers demeurent au minimum jaunes au niveau produit, même quand une révision technique est verte.
