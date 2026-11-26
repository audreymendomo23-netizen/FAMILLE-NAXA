# ZIPPLE — Audit N0 consolidé (bulk)
Date : 26 novembre 2026. Autorité : validation du promoteur de tous les modules réutilisables et instruction de traiter N0 en bulk.
État : PARTIEL — cadrage et contrôles documentaires terminés; preuves techniques listées ci-dessous encore ouvertes. Ne jamais transformer une absence de preuve en VERT.
## Références contrôlées
- Famille NAXA main, commit lu a229f62b41ddffbf4dc923fe4a90d36edbcca927; ZIPPLE V2.0 blob 08c18db438df168e0bef20371c0614cd7079c614; AGENTS.md; Android MainActivity.kt et OfflineQueue.kt; Web main.tsx, manifest, sw.js, Vite. Android et Web sont des squelettes, pas des recettes.
- NAXA Services : branche work/naxa-services-completion-20261120, arbre relevé ef2ce87e9b54681a324c4fd40998fb3e8fac7ef7; AuthApi.kt, SessionVault.kt, LocalAccessPin.kt, ErpModules.kt, ManagementModules.kt, LocalErpStore.kt, ReferralScreen.kt, PerformanceEngine.kt, NaxaServicesSyncWork.kt, shared-operations.tsx; Edge auth/accounting/notifications/referrals/customer-promotions. Lire les sources et tests avant extraction, ne pas fusionner la branche entière.
- NAXA : arbre relevé 4acbab129b403ef87e879c87e99793fb9d35e98f; src/lib/server/delivery-routing.ts, src/lib/merchant-payment.ts, android/app/src/main/java/cm/naxa/app/NativeSupportRepository.kt, NativeSupportRtcClient.kt, src/app/api/security/cameras/live-session/route.ts et composants delivery/stock/OCR. Adaptation aux identités ZIPPLE nécessaire.
- JOBLY : archive jobly/Jobly-source-minimal (1).zip, blob 002e1ce0fe6639af0df14ed9da0d8597efe3e850, taille 1787758 octets. README consulté; dépôt JOBLY autonome non retrouvé. Le connecteur contents/base64 a rendu une chaîne vide, blob UTF-8 a échoué, téléchargement brut inaccessible (DNS/cache). Dossier technique JOBLY dans bibliothèque consulté : Billing/Entitlements, feature flags, back-office, QR opaque, notifications, chat, IA, observabilité, tests. Aucun code JOBLY déclaré audité ou importé. Exclure Partner/parrainage/commissions JOBLY et fonctionnalités recrutement.
- Logo original : 7 famille naxa/Logo/ZippLe.jpg et 7 famille naxa/Les logos/Les logos/ZippLe.jpg, même blob 77ca18018d39d38030b16610d3d54acfff9c12cf, inspecté visuellement. Z bleu nuit, flèche/coche orange, nom Zipple. Conserver sans modification.
## Identité et architecture
Palette #0E224D, #F56202, #C04F00, #FFF0E3, #16203A, #0A1632, #15244D, blanc; succès #197A33, erreur #C62828, avertissement #8F5400. Montserrat, clair par défaut, sombre optionnel. Texte bleu nuit sur orange, ne pas mettre petit texte orange vif sur blanc. Assets vectorisés et icônes adaptatives/PWA à produire et vérifier N1. tokens.css contient les 2 couleurs de marque. Android Kotlin/Compose natif, applicationId cm.naxa.zipple, Room, WorkManager, Keystore; Web/PWA React/Vite/TypeScript/IndexedDB, interface publique QR sans compte. Versions réelles main AGP 8.6.1, Kotlin 2.0.20, compile/target 35, min26, Compose BOM 2024.10.01, React 18/Vite 5.4; décisions FAM-011/012 cible différente. Ne pas prétendre que la cible compile; conserver baseline effective jusqu'à preuve de migration compatible.
## Backend — observation en lecture seule du 26/11
Projets accessibles : FAMILLE-NAXA idupfjbkwjcavyisxteo (ACTIVE_HEALTHY PostgreSQL 17), NAXA ykgjfindlgseegmznaog (ACTIVE_HEALTHY PostgreSQL 17). Ancienne documentation de projet NAXA partagé et Replay ne correspond pas aux projets aujourd'hui accessibles. Inventaire pg_class/pg_namespace : Famille public 76 tables, 76 RLS activées, 3 vues; toutes les tables listées préfixées ns_, aucune table ZIPPLE identifiée, pas de schéma famille_core observé. NAXA public 37 tables, 37 RLS activées, 0 vue. Famille : cinq Edge Functions ACTIVE v2 (naxa-services-auth, accounting, notifications, referrals, customer-promotions). NAXA : aucune Edge Function listée (ne signifie pas absence d'API Next.js). RLS activée ne prouve pas absence de fuite; plusieurs tables ns_ ont zéro policy, à contrôler par grants et accès serveur, pas à modifier arbitrairement. Aucun enregistrement métier consulté, aucune mutation ni migration.
Décision technique proposée : ZIPPLE cible le projet Famille distinct, avec identité app/org/site/poste et ressources propres; réutiliser logique, pas les lignes ns_ ni les tables pharmacie. Contrats cross-app par appels autorisés et contrôle des accords. Avant N1/N2 migration : valider projet cible et inventaire DDL/RPC/grants/policies/storage; tests RLS inter-app, anon QR et admin central; aucune opération de production par cet audit.
## Contradictions et corrections
| ID | Cause | Correction / état |
|---|---|---|
| C01 | packagePrice historique accepte 3/6 et tests les approuvent | Politique ZIPPLE canonique et contrat de refus 3/6 établis; ancien helper partagé reste intact pour éviter régression NAXA Services/autres produits, interdit à ZIPPLE; intégration runtime/test de non-régression N2 |
| C02 | branche de travail catalogue ZIPPLE launch 5000/15000, mature 6000/18000 | Cahier validé fait autorité 5000/18000 mensuel et 50000/180000 annuel; aucune bascule ZIPPLE sans nouveau prix validé. Ne pas repricer périodes payées. Contrat documentaire machine-readable joint; correction du runtime à N2, pas de modification de branche NAXA Services |
| C03 | Confusion consommateur et PME | Cahier ZIPPLE enrichi du modèle PME NAXA Services : 5 premiers paiements confirmés, mois gratuit/extension, idempotence, aucun accès client supplémentaire |
| C04 | Versions cible vs sources | Versions constatées et stratégie de montée de version documentées; tests build N1 |
| C05 | Droits et quotas non fixés | Principe validé portefeuille mono-compte / multiniveau et héritage; matrice proposée non substitutive. Valeurs détaillées non approuvées, pas de quota inventé |
| C06 | Ancienne cible backend et dépendances pharmacie | Inventaire réel effectué; compatibilité et recette RLS à N1/N2/N6 |
| C07 | JOBLY archive non récupérable | Références documentaires identifiées, aucune importation de code avant extraction et examen; réserve bloquante pour audit exhaustif |
| C08 | GRILLAD V1.3 §2.3 P/B malgré orientation Connect | Contrat QR distinct, paiements/caisse séparés, droit et accord bilatéral; ne pas activer avant résolution côté GRILLAD |
| C09 | NAXA HOTEL FAM-023 interaction ZIPPLE | Contrat de commande restaurant/bar distinct, folio soumis à validation; aucune collision données |
## Vérifications exécutées
- PASS : ACCESS monthly
- PASS : ACCESS annual
- PASS : PREMIUM monthly
- PASS : PREMIUM annual
- PASS : reject quarterly
- PASS : reject semiannual
- PASS : reject 3
- PASS : reject 6
- PASS : reject 
- PASS : reject null
- PASS : wave 5
- PASS : no duplicate qualification
- PASS : both rewards one month
- PASS : consumer separate
- PASS : premium inherits
- PASS : no automatic price change
Ces contrôles JS en mémoire testent le contrat de cadrage, pas le code de production, le fournisseur de paiement ni les écrans. Le registre de décisions garde les exceptions explicites propres à d'autres produits (ne pas les modifier dans ZIPPLE).
## Clôture
Cadrage fonctionnel, identité, provenance, stratégie de réutilisation, inventaire backend, contrat tarifaire et plan N1–N8 : établis. N0 n'est pas intégralement VERT : archive JOBLY non auditée, droits détaillés non arbitrés, contrat runtime partagé non mis en conformité dans ce chantier, compatibilité RLS/API et recettes non exécutées. Ne pas appeler une migration ni un déploiement pour résoudre ces réserves sans autorisation. Aucun code des applications existantes modifié.
