# PROMPT 0.1 — Cadrage technique et structure du projet

**État : STACK CORRIGÉE SUR MATRICE DE COMPATIBILITÉ ; BUILDS ET TESTS À PROUVER.**

## 1. Architecture produit

Chacun des dix produits possède deux réalisations indépendantes :
- Android : application entièrement native, APK autonome.
- Web : application responsive mobile/tablette/ordinateur et installable en PWA.

Produits : Kiosko, Bootik, Zipple, NAXA Services, CotiZ, Loyable, NAXA Hotel, Campus237, NAXA Security, GrillaD.

Aucune WebView-wrapper, aucun Capacitor, aucune UI Web embarquée dans Android. Les plateformes partagent contrats API, règles métier, validations, formats, traductions et tests, pas leurs interfaces.

## 2. Stack Android arrêtée

| Couche | Choix de référence |
|---|---|
| Langage | Kotlin 2.4.21 |
| UI | Jetpack Compose + Material 3 |
| Build | AGP 9.3.1 ; Gradle 9.5.0 ; JDK 17 |
| SDK | compileSdk 37 ; targetSdk 37 ; minSdk 26 |
| Compose | BOM 2026.09.00 |
| Base locale | Room / SQLite |
| Préférences | DataStore |
| Synchronisation | WorkManager |
| Secrets locaux | Android Keystore |
| HTTP | Ktor Client 3.0.3 |
| Supabase | supabase-kt BOM 3.5.0 et modules nécessaires |
| Caméra | CameraX |
| OCR / codes-barres | ML Kit local lorsque pertinent |
| Push | Firebase Cloud Messaging |
| Tests | JUnit, tests instrumentés, Compose UI tests |

Dix projets/modules Android indépendants, chacun avec applicationId, manifeste, permissions, icônes, version et APK propres. Les packages Kotlin communs sont limités à la sécurité, au réseau, à la synchronisation, au stockage, aux contrats et aux utilitaires. Pas de partage forcé des écrans métier.

Room porte les opérations métier locales ; WorkManager assure une synchronisation reprenable. Les mutations financières et sensibles restent validées côté serveur. Les clés de données sensibles sont protégées par Android Keystore. Les permissions sont demandées au moment du besoin.

Le SDK Supabase Kotlin reste communautaire : il sera isolé derrière un adaptateur pour pouvoir le remplacer sans réécrire le domaine métier. Les versions sont une baseline au 14/11/2026. La combinaison initiale Kotlin 2.2.21 + AGP 9.5.0 + Gradle 9.6.0 était incompatible selon la matrice officielle Kotlin : Kotlin 2.2.21 est pleinement supporté jusqu'à AGP 8.11.1 et Gradle 8.14. Elle est remplacée par Kotlin 2.4.21 + AGP 9.3.1 + Gradle 9.5.0 : la matrice Kotlin indique AGP jusqu'à 9.3.1 et Gradle jusqu'à 9.7.0 ; AGP 9.3 prend en charge API 37 et requiert Gradle 9.5.0. Cette correction de compatibilité documentaire ne vaut pas preuve de compilation. Les versions seront verrouillées dans les catalogues Gradle puis compilées sur un prototype avant développement massif.

## 3. Stack Web/PWA arrêtée

| Couche | Choix |
|---|---|
| Framework | Next.js 16.4.6 stable |
| UI | React 19.3.0 |
| Langage | TypeScript strict |
| PWA/service worker | Serwist 9.5.13 |
| Style | CSS responsive + design tokens ; Tailwind si utile |
| Workspace | pnpm workspaces + lockfile |
| Tests | Vitest, Playwright, tests d'accessibilité |

Dix applications Web/PWA autonomes, chacune avec manifeste, icône, nom, thème, scope et cache propres. Les écrans privés et tokens ne sont jamais mis en cache automatiquement. La PWA ne prétend pas remplacer les services Android lorsque le navigateur est fermé.

## 4. Monorepo et livraison

Dépôt de référence : audreymendomo23-netizen/FAMILLE-NAXA, branche main.

- Dix projets Android construits et livrés séparément par Gradle.
- Dix applications Next.js séparées dans un workspace pnpm.
- Packages communs limités aux contrats, règles partagées, validations, internationalisation, design tokens et jeux de tests.
- Aucune dépendance directe entre applications.
- APK distribuées depuis le site NAXA, sans Play Store.

Structure cible :
- apps/android/{kiosko,bootik,zipple,naxa-services,cotiz,loyable,naxa-hotel,campus237,naxa-security,grillad}
- apps/web/{mêmes dix applications}
- packages/{android-core,web-core,contracts,domain-rules,validation,localization,design-tokens,test-vectors}
- supabase/{drafts,migrations,functions,tests}
- docs/{architecture-360,apps,decisions,audits}

## 5. Backend, identité et données

Supabase/PostgreSQL reste le backend partagé cible, sous réserve de l'audit. Identité Auth commune ; profils et droits contextualisés par application, organisation et lieu. Les rôles métier de la pharmacie NAXA ne sont pas des rôles universels Famille.

Les données Famille sont isolées dans un schéma dédié et des schémas métier par application ; aucune nouvelle table Famille dans public par défaut. Chaque table exposée doit avoir des grants minimaux et RLS testée. Aucun service_role ou secret serveur dans une APK ou PWA. Aucune migration, modification Replay/Production ou fonction déployée sans accord explicite.

## 6. Conventions

- Montants en FCFA, stockés en entiers ou NUMERIC exact, jamais FLOAT.
- Horodatages timestamptz UTC ; fuseau d'affichage explicite, Africa/Douala par défaut.
- Français/anglais ; aucune chaîne UI codée en dur.
- Identifiants techniques anglais, libellés localisés.
- Journalisation structurée sans secret, PIN, OTP ni SMS brut.
- Suppression douce pour données opérationnelles lorsque permise ; journaux et écritures financières append-only.
- Dépendances épinglées, lockfiles versionnés, inventaire SBOM/licences.
- Aucun coût ou service payant sans accord.

## 7. Sources techniques consultées

- Supabase Kotlin quickstart : https://supabase.com/docs/guides/getting-started/quickstarts/kotlin
- Statut communautaire supabase-kt : https://supabase.com/docs/reference/kotlin/introduction
- Compose BOM : https://developer.android.com/develop/ui/compose/bom
- AGP / Gradle : https://developer.android.com/build/releases/about-agp
- Next.js support policy : https://nextjs.org/support-policy
- React versions : https://react.dev/versions

## 8. État

Android natif dix apps : EXIGENCE VALIDÉE, CODE ABSENT. Web responsive + PWA dix apps : EXIGENCE VALIDÉE, CODE ABSENT. Stack de référence : CORRIGÉE SUR MATRICE DOCUMENTAIRE, NON COMPILÉE. Monorepo : STRUCTURE CIBLE DOCUMENTÉE, PAS ENCORE BOOTSTRAPPÉE. Backend partagé : SOUS CONDITION D'AUDIT. Dépendances/lockfiles : absents. Build : non exécuté. Tests : non exécutés. Migration et déploiement : aucun.

**Prompt 0.1 : cadrage documentaire terminé ; VERT TECHNIQUE NON ACQUIS. Critères techniques restants : bootstrap reproductible, wrapper Gradle et toolchain Android, dix modules Android natifs, dix apps Web/PWA indépendantes, lockfiles, builds release/debug, tests unitaires/UI/e2e et preuve CI ou exécution locale reproductible.**
