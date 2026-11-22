# Audit anti-collision — BOOTIK / NAXA SERVICES / NAXA

> Date : 22 novembre 2026  
> Branche examinée : `feat/bootik-retail-foundation-2026-11-22`  
> Type : audit statique du monorepo et des documents sources.  
> Statut : frontières définies ; aucune connexion Supabase ni recette Android n'a été exécutée dans cette passe.

## 1. Résumé exécutif

BOOTIK doit être construit comme une application autonome, avec ses propres écrans, modèles métier, stockage local et schéma SQL. Il peut utiliser les contrats techniques communs Famille NAXA après audit, mais il ne doit ni importer le domaine métier de NAXA SERVICES, ni modifier le projet NAXA indépendant/pharmacie.

La séparation retenue :
- **BOOTIK Android** : package `cm.naxa.bootik`, Room `bootik-local.db`, tables locales `bk_*`, code d'application `bootik`.
- **BOOTIK serveur candidat** : schéma PostgreSQL `bootik`, objets `bk_*`, aucun droit direct client dans le draft.
- **Famille NAXA partagé** : identité/applications/organisations/sites/abonnements/audit et synchronisation seulement via les contrats communs validés.
- **NAXA SERVICES** : namespace, authentification et tables métier `ns_*` propres ; aucune modification réalisée.
- **NAXA Pharmacie / projet indépendant** : hors périmètre applicatif de ce monorepo selon `docs/CONTINUITE.md` ; aucune modification ou import de code effectué.

## 2. Constat technique vérifié

### 2.1 BOOTIK avant cette passe

Le code source métier Android BOOTIK était un squelette :
- `MainActivity.kt` affichait un titre et un texte générique ;
- `OfflineQueue.kt` contenait une table Room nommée `offline_events` et une base `OfflineQueueDb` ;
- le module Gradle avait Room et Compose, mais aucune suite de tests BOOTIK dédiée n'était présente dans les sources applicatives observées.

Les nombreux fichiers sous `apps/android/bootik/build/**` sont des artefacts générés versionnés ; ils ne constituent pas la source métier de référence et ne sont pas modifiés dans cette passe.

### 2.2 NAXA SERVICES

Le code et les documents consultés confirment une application spécialisée dans les prestations :
- Pressing : dépôt, ticket, pièces, tarif par vêtement, date promise, suivi reçu/en cours/prêt/retiré.
- Coiffure : prestations, durées, habilitations, agenda, réservations et affectations.
- Commerce des services : clients, caisse, paiements, reçus, dépenses, commissions, consommables et rapports.
- Organisation multi-sites et postes de travail propres au même établissement.

Le draft SQL NAXA SERVICES contient 25 tables, 15 fonctions et 41 policies observées ; les tables/fonctions/policies de ce draft portent le préfixe `ns_*. Les documents indiquent que ce draft n'est pas appliqué. L'Edge Function dédiée fixe `app_code=naxa-services`. Ces contrats ne sont pas des services BOOTIK réutilisables tels quels.

**Frontière métier :** BOOTIK ne crée pas de tickets pressing, de rendez-vous coiffure, d'agenda de prestataires, de catalogue de prestations, de commissions de coiffeurs ou de workflows de retrait de vêtements. NAXA SERVICES ne devient pas un système de gestion de marchandises, de lots, de stock commercial multi-unités ou de commandes grossistes.

### 2.3 NAXA Pharmacie / projet indépendant

`docs/CONTINUITE.md` confirme que NAXA Pharmacie n'est pas une application à construire dans le monorepo FAMILLE-NAXA. Le document d'audit du schéma historique décrit des objets spécialisés pharmacie (profils, pharmacies, appareils et marketplace) et interdit leur réutilisation aveugle comme fondation multi-applications.

**Frontière :** BOOTIK n'ajoute pas de profil officine/pharmacie informelle en V1.1, ne gère pas de prescriptions, d'assurance pharmacie, de réservation de médicaments, de marketplace patient/pharmacie, de stock pharmaceutique ni de règles de dispensation. Aucun dépôt NAXA indépendant, schéma `public` historique ou service IA NAXA n'a été modifié.

### 2.4 Socle Famille NAXA

- `packages/contracts` connaît déjà `bootik` dans l'union `AppId`.
- `docs/architecture-360/PROMPT_0_2_SCHEMA_DONNEES_COMMUN.md` propose un schéma métier `bootik` séparé et un contrôle app/org/location.
- Le draft `famille_core` n'est pas une preuve de backend déployé. Ses migrations et fonctions doivent encore être auditées/testées.
- `packages/README.md` précise que les packages partagés ne sont pas considérés comme implémentés. On n'ajoute donc aucune nouvelle dépendance métier partagée avant contrat et preuve.

## 3. Matrice de frontières

| Domaine | BOOTIK possède | NAXA SERVICES possède | NAXA Pharmacie possède |
|---|---|---|---|
| Caisse | ventes de marchandises, caisses indépendantes, stocks et clôtures commerce | encaissements de prestations pressing/coiffure et postes | caisse et ventes pharmacie |
| Catalogue | marchandises, SKU, variantes, lots, unités et prix détail/gros | prestations, forfaits, consommables et produits comptoir | médicaments, références pharmaceutiques et catalogue officine |
| Stock | inventaire marchandises, entrepôts, lots, conversions, consignes | stock léger de consommables et mouvements liés aux prestations | stock pharmaceutique, lots et règles pharmacie |
| Clients | clients détaillants et comptes B2B | clientèle des établissements de service | patients/clients pharmacie et parcours spécialisés |
| Commandes | achats fournisseurs et commandes B2B Détaillant ↔ Distributeur | approvisionnement des consommables de service | réservations/commandes de médicaments |
| Planning | réapprovisionnement, picking, tournées et livraisons marchandises | agenda, rendez-vous, postes et prestataires | parcours pharmacie propres au projet NAXA |
| Documents | devis/factures marchandises, bons de livraison, inventaires | tickets pressing, reçus de prestations, rendez-vous | prescriptions, documents et reçus pharmacie |
| Intégration | contrats techniques communs après audit uniquement | contrat Auth `naxa-services-auth` dédié | projet, API et règles propres hors monorepo |

## 4. Garde-fous appliqués dans la première tranche BOOTIK

1. Namespace Android `cm.naxa.bootik` seulement.
2. Base Room `bootik-local.db` seulement.
3. Tables Room `bk_workspace_drafts`, `bk_activity_drafts`, `bk_site_drafts`, `bk_site_activity_drafts`, `bk_offline_events`.
4. Schéma SQL candidat `bootik` et objets `bk_*` seulement ; aucune table `public.*` et aucune table `ns_*`.
5. Aucun appel à `naxa-services-auth`, aucun stockage `ns_*`, aucun accès aux dossiers pressing/coiffure.
6. Aucun import de rôle pharmaceutique, prescription, marketplace ou fichier du projet NAXA indépendant.
7. Les brouillons de paramétrage initiaux restent locaux et non synchronisés. Ils ne créent aucun compte, abonnement, identité ou organisation côté serveur.
8. L'accès serveur futur devra passer par les identités/contrats Famille validés, un `app_id` BOOTIK authentifié, le moindre privilège et des tests RLS inter-tenant. Aucun droit Data API n'est accordé par ce draft.

## 5. Risques et blocages à ne pas masquer

- Le schéma `famille_core` est encore documentaire/candidat. Le draft BOOTIK dépend des tables `famille_core.applications`, `organization_apps`, `organizations` et `locations`, qui doivent être réellement qualifiées avant une migration.
- Aucun test Gradle/Kotlin, test Compose instrumenté ou test PostgreSQL n'a été exécuté via le connecteur GitHub. Les tests sources sont ajoutés mais restent **NON EXÉCUTÉS**.
- Le code NAXA SERVICES consulté référence des classes `data.*` absentes de l'inventaire source observé lors de cette passe ; ce point n'est pas corrigé par BOOTIK et doit rester dans son propre audit.
- Le Fulfulde `ff-CM` reste à traduire et vérifier par un locuteur humain ; seules les ressources FR/EN de cette première UI sont livrées.
- Les parcours caisse, paiements, achats, stock réel, CRM, synchronisation distante et interconnexion distributeur ne sont pas encore déclarés opérationnels. La première tranche ne couvre que la sélection de profil et le brouillon local.

## 6. Vérification de périmètre

Changements applicatifs autorisés dans cette tranche :
- `apps/android/bootik/**`
- `supabase/drafts/bootik_v1.sql`
- `supabase/tests/drafts/bootik_rls_contract.sql`
- `docs/BOOTIK_*` et ce rapport d'audit.

Aucun fichier sous `apps/android/naxa-services/**`, `supabase/drafts/naxa_services_v1.sql`, `supabase/functions/naxa-services-auth/**`, aucun fichier NAXA Pharmacie historique et aucun projet Supabase externe ne doit être modifié par la suite BOOTIK sans décision séparée.

**État :** frontières anti-collision définies et premiers fichiers BOOTIK isolés ; compilation/recette technique non exécutée ; backend inchangé ; aucune migration ni aucun déploiement.
