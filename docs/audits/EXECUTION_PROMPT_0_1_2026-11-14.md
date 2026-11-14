# Exécution du Prompt 0.1 — 14 novembre 2026

## Audit de départ

Le cadrage exige Kotlin 2.4.21 / AGP 9.3.1 / Gradle 9.5.0 / API 37 et Next.js 16.4.6 / React 19.3.0 / Serwist 9.5.13 / pnpm.
Le générateur et le workflow antérieurs produisaient AGP 8.6.1 / Kotlin 2.0.20 / compileSdk 35 / Compose BOM 2024.10.01, Vite / React 18.3.1 et Gradle 8.7. Le build vert antérieur ne prouvait donc pas la conformité au stack approuvé.

## Corrections apportées

- Générateur déterministe remplacé : dix modules Android natifs indépendants, dix applications Next.js, manifestes PWA, icônes, service workers, ressources FR/EN et tests par produit.
- Versions Gradle centralisées ; wrapper Gradle 9.5.0 et SHA-256 officiel ; pnpm workspace avec liste explicite des dix apps et lockfile.
- AGP9 : Kotlin intégré désactivé temporairement pour utiliser KGP 2.4.21 ; migration vers Kotlin intégré requise avant AGP10.
- Serwist configuré en configurator mode ; pas de pré-cache des pages pré-rendues et pas de runtime caching de contenu métier ou privé.
- CI renforcée : tests des packages, dix builds Next/PWA, Playwright/axe, dix builds Android debug/release, tests unitaires et tests Compose instrumentés.
- Ressources Android centrales FR/EN ; canaux de notifications et dialogue biométrique localisés.

## Périmètre non touché

Aucune migration ni modification Supabase Replay/Production, aucun réglage Auth, aucune fonction déployée, aucun déploiement Netlify, aucune publication APK, aucun secret ajouté.
La console admin Vite historique est conservée hors du workspace des dix produits.

## État

Ce commit prépare le socle et les contrôles ; le statut VERT dépend de la preuve CI complète exécutée sur ce commit, wrapper et lockfile inclus. Un build seul ne clôture pas les tests instrumentés et E2E.
