# Architecture cible — Famille NAXA

## Applications
1. Kiosko — Mobile Money
2. Bootik — boutiques, commerces et dépôt de gaz
3. Zipple — bars et restaurants
4. NAXA Services — pressing et coiffure
5. CotiZ — tontines
6. Loyable — gestion locative
7. NAXA Hotel — hôtellerie
8. Campus237 — ERP scolaire
9. NAXA Security — sécurité des biens/personnes, télésurveillance et IA
10. GrillaD — gestion spécialisée des vendeurs de grillades

## Cibles
Dix applications Android autonomes installables séparément par APK distribuées depuis le site NAXA (pas Play Store), et expériences Web responsive/PWA autonomes selon leur périmètre.

## Backend
Réutiliser directement les ressources Supabase NAXA existantes après audit, sans duplication inutile. Production `eouwtuusnsuxaejsxknf` et Replay `pwfftcsjyeibxxqhwysw` sont deux projets distincts. Ces identifiants ne sont pas des autorisations d'accès ni de modification.

Avant toute migration : inventorier tables, colonnes, contraintes, index, fonctions/RPC, triggers, vues, extensions, RLS, GRANT, SECURITY DEFINER, search_path, Storage et dépendances ; comparer Replay et Production ; classer chaque ressource réutiliser/adapter/créer/écarter ; préparer et tester des migrations additives sur Replay. Aucun changement Production sans autorisation explicite.

## Isolation et sécurité
Chaque application conserve son identité, ses parcours et ses permissions. Un backend partagé ne donne aucun accès transversal implicite. Contrôles serveur et RLS obligatoires ; jamais de `service_role` côté client.

## Packages envisagés (non implémentés)
`auth`, `ui`, `domain`, `supabase`, `offline`, `observability`, `i18n`. Ne créer un package commun qu'après preuve d'un besoin partagé et tests de non-régression.

## Livraison
Tests unitaires, intégration, SQL/RLS, parcours métier, sécurité et non-régression. Aucun déploiement Vercel, aucune migration Production, aucune publication APK sans accord explicite.
