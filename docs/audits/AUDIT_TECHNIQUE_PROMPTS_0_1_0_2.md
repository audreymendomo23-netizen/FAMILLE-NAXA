# AUDIT TECHNIQUE — PROMPTS 0.1 ET 0.2

**Date : 14 novembre 2026**  
**Branche : main**  
**Périmètre : correction des incompatibilités et vérification des prérequis techniques.**  
**Décision : VERT TECHNIQUE NON ACQUIS. Ne pas ouvrir le Prompt 0.3.**

## 1. État initial vérifié

Au commit de départ `490c368fa656ba160a4c6c4d49532abc2c20ac35`, le dépôt contenait les documents de cadrage et le SQL draft, mais pas de bootstrap applicatif à sa racine.

Fichiers attendus absents lors de la lecture GitHub :
- `package.json`
- `pnpm-workspace.yaml`
- `settings.gradle.kts`
- `gradle/libs.versions.toml`

Aucun projet Android, aucune application Next.js, aucun wrapper Gradle, aucun lockfile et aucun pipeline de build ne sont donc établis par les éléments contrôlés.

## 2. Correction de compatibilité Android

La combinaison publiée dans Prompt 0.1 — Kotlin 2.2.21 + AGP 9.5.0 + Gradle 9.6.0 — présentait une incompatibilité de versions officiellement documentée :
- Kotlin 2.2.20–2.2.21 : support complet AGP 7.3.1 à 8.11.1 et Gradle 7.6.3 à 8.14.
- AGP 9.5.0 requiert Gradle 9.6.0.
- AGP 9.3 prend en charge API 37 et requiert Gradle 9.5.0.
- Kotlin 2.4.20–2.4.21 : support complet AGP jusqu'à 9.3.1 et Gradle jusqu'à 9.7.0.

Baseline corrigée dans Prompt 0.1 :
- Kotlin 2.4.21
- Android Gradle Plugin 9.3.1
- Gradle 9.5.0
- JDK 17
- compileSdk/targetSdk 37, minSdk 26

Cette combinaison est cohérente avec les matrices publiées consultées, mais elle n'a pas encore été compilée dans ce dépôt. Les autres versions Android (Compose BOM, supabase-kt, Ktor, CameraX, Room, etc.) doivent encore être verrouillées et vérifiées ensemble dans un vrai build.

Sources :
- Kotlin Gradle compatibility : https://kotlinlang.org/docs/gradle-configure-project.html
- AGP 9.3 release notes : https://developer.android.com/build/releases/agp-9-3-0-release-notes
- AGP 9.5 release notes : https://developer.android.com/build/releases/agp-9-5-0-release-notes

## 3. Web/PWA — contrôle partiel des versions

Versions retrouvées dans les sources publiques au 14/11/2026 :
- Next.js 16.4.6 : publication et version latest observées.
- React 19.3.0 : release indiquée dans le journal React.
- Serwist 9.5.13 et @serwist/next 9.5.13 : versions publiées.

Cela confirme l'existence des versions, pas la compatibilité de l'ensemble, ni la réussite d'un build. Il manque les manifests, le workspace, les dix apps, les lockfiles, les configurations PWA et les tests.

Sources :
- Next.js releases : https://github.com/vercel/next.js/releases/
- React versions : https://react.dev/versions
- Serwist : https://www.npmjs.com/package/serwist
- @serwist/next : https://www.npmjs.com/package/@serwist/next

## 4. Correction structurelle du SQL draft 0.2

Le draft a été durci sur quatre invariants inter-périmètres :
1. Une affectation de rôle doit référencer le membership avec le même triplet membership/app/organisation.
2. Un lieu affecté doit appartenir à la même organisation que le membership.
3. Un abonnement doit référencer une activation organisation/application existante.
4. Le plan référencé doit appartenir à la même application que l'abonnement.

Clés composites et index d'appui ajoutés dans `supabase/drafts/0001_famille_core_proposed.sql`.

**Limite importante :** aucun serveur PostgreSQL local, aucun `psql`, aucun Docker et aucun parseur PostgreSQL n'étaient disponibles dans l'environnement de vérification. Le SQL n'a donc pas été exécuté ni validé syntaxiquement par PostgreSQL. Il reste explicitement non exécutable/non approuvé tant que les policies, GRANT, tests RLS, matrice métier, Auth lifecycle et revue complète ne sont pas terminés. Aucune base Replay ou Production n'a été modifiée.

## 5. Environnement de vérification constaté

- Java disponible : OpenJDK 21.0.12 ; le JDK 17 requis par la baseline Android n'est pas installé dans l'environnement contrôlé.
- Node disponible : v22.16.0.
- Gradle : absent.
- pnpm : absent.
- Android SDK / adb : non établis dans l'environnement.
- PostgreSQL / psql : absent.
- Docker : absent.

Conséquence : aucun build Android, build Web/PWA, test d'intégration PostgreSQL ou test RLS n'a pu être exécuté ici.

## 6. Critères impératifs avant VERT technique

### Prompt 0.1
- [ ] Bootstrap monorepo réel, reproductible, sur main.
- [ ] Wrapper Gradle + JDK 17 + Android SDK installés et versions verrouillées.
- [ ] Dix applications Android distinctes, natives Kotlin/Compose, applicationId et manifests propres.
- [ ] Dix applications Web/Next.js indépendantes, responsive et PWA, scopes/manifests/cache séparés.
- [ ] Lockfiles et dépendances résolues sans versions flottantes.
- [ ] Build debug/release Android pour les dix apps.
- [ ] Build production Web pour les dix apps.
- [ ] Tests unitaires, UI et smoke/e2e essentiels exécutés.
- [ ] Preuves de résultats conservées dans le dépôt ou CI.

### Prompt 0.2
- [ ] Exécution du draft uniquement dans PostgreSQL local/éphémère isolé, jamais Replay/Production.
- [ ] Validation syntaxique et migration up/down contrôlée.
- [ ] Matrice complète des entités et règles métier des dix applications.
- [ ] Audit des contraintes composites, unicités, index, montants, dates, idempotence et cycles de vie.
- [ ] GRANT minimaux et policies RLS par table/opération, sans exposition prématurée.
- [ ] Tests positifs et négatifs : anon, utilisateur, autre utilisateur, autre organisation, autre lieu, autre application.
- [ ] Tests de non-escalade des rôles, d'isolation et de révocation.
- [ ] Aucun secret serveur dans les clients.
- [ ] Rapport de tests et revue indépendante avant toute décision de migration.

## 7. Résultat

| Contrôle | État |
|---|---|
| Correction incompatibilité Kotlin/AGP/Gradle | CORRIGÉE DOCUMENTAIREMENT |
| Existence des versions Web vérifiées | PARTIELLEMENT CONFIRMÉE |
| Build Android réel | NON EXÉCUTÉ |
| Build Web/PWA réel | NON EXÉCUTÉ |
| Dix applications natives et dix PWA | ABSENTES DU DÉPÔT |
| Contraintes croisées SQL | DURCIES DANS LE DRAFT |
| Validation PostgreSQL du draft | NON EXÉCUTÉE |
| Policies/GRANT/RLS Famille | NON FINALISÉS |
| Tests RLS/isolation | NON EXÉCUTÉS |
| Migration Supabase | AUCUNE |
| Déploiement | AUCUN |

**Conclusion :** les erreurs documentaires détectées sont corrigées et des contraintes SQL ont été ajoutées, mais les Prompts 0.1 et 0.2 ne sont pas VERT TECHNIQUE. Le chantier doit rester sur ces prérequis jusqu'à production des preuves listées ci-dessus.
