# Registre des décisions

| ID | Décision | État |
|---|---|---|
| FAM-001 | Dix applications autonomes dans un nouveau monorepo indépendant du dépôt NAXA historique | VALIDÉ |
| FAM-002 | Dépôt de référence audreymendomo23-netizen/FAMILLE-NAXA | VALIDÉ |
| FAM-003 | Branche main uniquement | VALIDÉ |
| FAM-004 | APK depuis le site NAXA, sans Play Store | VALIDÉ |
| FAM-005 | Backend Supabase NAXA partagé après audit, sans duplication inutile | VALIDÉ SOUS CONDITION |
| FAM-006 | Aucune migration Production, aucun déploiement ni APK publiée sans accord explicite | VALIDÉ |
| FAM-007 | Nom GrillaD retenu ; disponibilité de marque/domaine à vérifier | RETENU |
| FAM-008 | GrillaD : porc braisé, poulet braisé, poisson braisé, brochettes, omelettes uniquement | VALIDÉ |
| FAM-009 | GrillaD : Manager autonome, Manager + un vendeur, Manager + plusieurs vendeurs sur lieux précis | VALIDÉ |
| FAM-010 | Dix applications Android entièrement natives, chacune avec sa version Web responsive installable en PWA ; aucune WebView-wrapper | VALIDÉ |
| FAM-011 | Android : Kotlin 2.4.21, AGP 9.3.1, Gradle 9.5.0, JDK17, API37/min26, Compose BOM 2026.09.00, Room 2.8.5, DataStore, WorkManager, Keystore, Ktor 3.0.3 et supabase-kt 3.5.0 | VALIDÉ POUR LE CADRAGE ; PREUVE CI REQUISE |
| FAM-012 | Web : Next.js 16.4.6, React 19.3.0, TypeScript strict, Serwist 9.5.13 et pnpm 12.21.0 ; dix PWA autonomes | VALIDÉ POUR LE CADRAGE ; PREUVE CI REQUISE |
| FAM-013 | Monorepo : dix modules Android indépendants + dix apps Web indépendantes + packages communs limités | VALIDÉ |
| FAM-014 | Identité Auth commune ; autorisations contextualisées par application/organisation/lieu ; séparation des tables métier NAXA | PROPOSÉ, AUDIT REQUIS |
| FAM-015 | Aucun schéma Famille exposé au Data API sans grants minimaux et RLS/policies testés | VALIDÉ COMME EXIGENCE |
| FAM-016 | AGP 9.3.1 : Kotlin intégré désactivé temporairement afin d'utiliser KGP 2.4.21 ; migration requise avant AGP 10 | TRANSITOIRE DOCUMENTÉ |
| FAM-017 | Un seul Administrateur central Famille pour les dix plateformes ; accès transversal limité aux métadonnées d'administration, comptes, états, abonnements, paramètres et agrégats autorisés ; aucune lecture des transactions métier détaillées | VALIDÉ |
| FAM-018 | Identités utilisateurs distinctes par plateforme : un compte Auth utilisateur ordinaire ne peut être rattaché qu'à une seule application ; l'Administrateur central dispose d'un compte dédié hors memberships applicatifs | VALIDÉ |
| FAM-019 | L'Administrateur central peut effectuer les opérations d'administration autorisées ; toute mutation doit être journalisée de façon append-only avec acteur, application, organisation/lieu si applicable, action, cible et horodatage | VALIDÉ |

