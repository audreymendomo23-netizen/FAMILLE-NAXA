# Prompt 0.3 — compatibilité avec le backend Supabase NAXA

Date du contrôle : 14 novembre 2026  
Projet Supabase contrôlé en lecture seule : `eouwtuusnsuxaejsxknf` (NAXA Production)  
Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA`, branche `main`

## 1. Sources de vérité existantes — correspondance observée

| Besoin | Ressource canonique existante | Usage observé |
|---|---|---|
| Identité Auth | `auth.users.id` | Identifiant utilisateur canonique |
| Profil utilisateur | `public.profiles.id` | Même UUID que Auth ; rôle historique, état, pharmacie et rattachement hiérarchique |
| Organisation partenaire | `public.partners.id` | Structure partenaire, type, état et coordonnées |
| Membres partenaire | `public.partner_members(partner_id,user_id)` | Lien entre un partenaire et ses utilisateurs |
| Pharmacie / lieu | `public.pharmacies.id` | Lieu physique ; utilisé comme clé de portée dans les tables pharmacie |
| Promoteur ↔ pharmacie | `public.promoteur_pharmacies(promoteur_id,pharmacie_id)` | Affectation d'un Promoteur à une ou plusieurs pharmacies |
| Personnel ↔ pharmacie | `public.naxa_professional_assignments(profile_id,pharmacie_id,...)` | Affectation métier, rôle, statut, dates et révocation |
| Abonnement pharmacie | `public.abonnements` | Formule, montant, début, fin, échéance et statut |
| Paiement abonnement | `public.abonnement_paiements` | Référence, montant, période, payeur et date |
| Transactions de vente | `public.ventes` et tables liées | Données transactionnelles rattachées par `pharmacie_id` |
| Stock | `public.stocks` et tables de lots/mouvements | Données opérationnelles rattachées par `pharmacie_id` |

**Règle de non-duplication :** ne pas créer une deuxième identité, un deuxième profil utilisateur ou une deuxième pharmacie pour représenter les mêmes personnes et lieux. Le schéma Famille ne peut contenir que des références ou des correspondances réellement nécessaires, avec cardinalités et cycle de vie documentés.

## 2. RLS existante observée — objets prioritaires

Le projet possède déjà des policies sur les objets inspectés. Les règles principales observées :

- `profiles` : lecture du profil propre, des profils enfants hiérarchiques ou de l'administration ; modification contrôlée par l'administration ou le Promoteur dans un cas limité.
- `partners` : lecture par les membres du partenaire actif ; administration séparée.
- `partner_members` : lecture de sa propre appartenance ; administration.
- `promoteur_pharmacies` : lecture par le Promoteur concerné ou l'administration.
- `naxa_professional_assignments` : lecture du collaborateur, du donneur/révocateur ou d'un utilisateur disposant du privilège de consultation d'équipe.
- `stocks` : droits de lecture/écriture fondés sur les privilèges NAXA et la pharmacie.
- `abonnements` et `abonnement_paiements` : policies observées réservant les opérations à l'administration.
- `ventes` : policy SELECT `ventes_scope` observée avec la condition `is_admin() OR can_access_pharmacy(pharmacie_id)`.

Les fonctions canoniques inspectées comprennent `private.is_admin()`, `public.can_access_pharmacy(uuid)`, `private.naxa_scope_allows(uuid,uuid,text)` et `private.naxa_has_privilege(text,uuid,text)`. Elles sont fondées sur le modèle NAXA historique : profil, rôle actif, Promoteur, affectation et pharmacie. Elles ne reçoivent pas de claim `active_app_id` Famille.

## 3. Contradictions bloquantes pour la clôture du Prompt 0.3

### 3.1 Administration et transactions détaillées

La policy existante `ventes_scope` autorise explicitement `is_admin()` à lire les lignes de vente. Cela contredit le critère Famille « administration = agrégats et abonnements, jamais les transactions détaillées ».

Il est interdit de supprimer cette autorisation sans arbitrage de compatibilité : il faut établir si l'Admin NAXA historique et l'Admin des dix applications Famille sont le même rôle, ou deux capacités/applications distinctes. Le rôle NAXA actuel est déterminé par `public.naxa_business_function(auth.uid())='admin'`, sans contexte applicatif Famille.

### 3.2 Contexte applicatif

Les tables NAXA inspectées utilisent principalement `pharmacie_id` et ne possèdent pas de colonne `app_id`. Les helpers existants vérifient les rôles et pharmacies NAXA, mais ne garantissent pas l'isolation des dix applications Famille. Le claim signé `app_metadata.active_app_id` n'est pas émis par un Auth Hook Famille à ce stade.

### 3.3 Couverture des dix domaines

Les tables métier NAXA pharmacie ne constituent pas les tables métier de Kiosko, Bootik, Zipple, NAXA Services, CotiZ, Loyable, NAXA Hotel, Campus237, NAXA Security et GrillaD. Les squelettes Android/Web générés ne prouvent pas l'existence des tables ni des politiques métier de ces domaines. Les droits de chaque application doivent être reliés à ses propres agrégats métier avant de certifier leur isolation.

### 3.4 Candidats `famille_core`

Les fichiers `0001`, `0002` et `0003` constituent un banc de conception/test PostgreSQL 17. Le modèle `famille_core` contient encore des entités génériques `identities`, `organizations`, `locations`, `memberships`, `subscriptions` et `payment_intents` qui ne sont pas encore raccordées aux ressources canoniques NAXA. Ils ne doivent pas être appliqués au projet réel en l'état.

## 4. Correctifs réalisés dans le banc de test Famille

La candidate `0003_prompt_0_3_contextual_rls.sql` est durcie pour :

- contextualiser `is_admin()`, `outlet_ids()`, `has_organization_access()` et les helpers métier par le claim signé `app_metadata.active_app_id` ;
- refuser l'accès d'un gérant limité à un lieu à l'échelle complète de l'organisation ;
- ne plus retourner les identifiants de lieux lorsque l'application est inactive ou que l'abonnement est expiré au-delà de `grace_until` ;
- conserver les fonctions de facturation accessibles pour le parcours de paiement après expiration ;
- révoquer l'EXECUTE global et accorder une liste blanche de fonctions nécessaires.

Les tests vérifient les scénarios propriétaire/compte mère, gérant/lieu, autre propriétaire, Admin agrégats sans détails, commercial, partenaire, expiration, grâce, paiement « J'ai payé », isolation Kiosko/Campus237 et refus avec claim absent ou malformé.

Ces tests s'exécutent sur PostgreSQL 17 éphémère. Ils ne sont pas une migration ni une preuve d'intégration au backend NAXA réel.

## 5. Décision et état

**État : candidat RLS Famille testable ; Prompt 0.3 global non vert tant que les contradictions 3.1 à 3.4 ne sont pas levées.**

Prochain livrable requis avant une migration réelle :

1. arbitrer la séparation ou l'unification des capacités Admin NAXA / Admin Famille ;
2. figer la correspondance Auth/profil/partenaire/pharmacie/affectation sans dupliquer les sources de vérité ;
3. définir la table de correspondance applicative minimale, seulement si nécessaire, pour les dix codes d'application ;
4. inventorier les tables transactionnelles et RPC par domaine, avec matrice SELECT/INSERT/UPDATE/DELETE et droits EXECUTE ;
5. produire une migration additive compatible et des tests PostgreSQL 17 reproduisant les politiques réelles ;
6. faire relire le diff et obtenir une autorisation explicite avant toute écriture Supabase réelle.

Aucune table, policy, fonction, configuration Auth ou migration n'a été modifiée sur le projet Supabase NAXA. Contrôle effectué en lecture seule.

## 6. Preuve de test locale — 14 novembre 2026

Le workflow dédié https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/43559938233 est SUCCESS. PostgreSQL 17 éphémère a appliqué le schéma 0001, les policies 0002 et la candidate contextualisée 0003 ; les assertions de claims/refus par défaut et la matrice complète après durcissement ont toutes réussi.

Cette preuve confirme la logique RLS du banc de test Famille. Elle ne change pas les constats de compatibilité des sections 3.1 à 3.4 : Auth Hook Famille absent, contexte app non raccordé au backend NAXA, tables métier des dix domaines non encore couvertes et sémantique Admin NAXA/Famille à formaliser. Le Prompt 0.3 global reste PARTIEL / NON VERT. Aucun changement Supabase réel n'a été réalisé.
