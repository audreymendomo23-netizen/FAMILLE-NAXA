# AUDIT TECHNIQUE — PROMPTS 0.1 ET 0.2

**Date : 14 novembre 2026**  
**Branche : main**  
**Périmètre : correction des incompatibilités et vérification des prérequis techniques.**  
**Décision : VERT TECHNIQUE NON ACQUIS. Ne pas ouvrir le Prompt 0.3.**

**Mise à jour groupée :** un workflow GitHub Actions commun a été ajouté pour tester le draft sous PostgreSQL 17 éphémère et contrôler la présence des 20 manifests applicatifs. Le premier run GitHub Actions a été exécuté : [run #1](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/43541652922), commit testé `24792bb8dd2b0247f96ba45f09dde2208c91b9b5`. Job PostgreSQL 17 : **SUCCESS**. Job inventaire des 20 applications : **FAILURE**, avec exactement 20 manifests manquants (10 Android + 10 Web).

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

## 6. Contrôle groupé ajouté sur main

Fichiers ajoutés au commit `24792bb8dd2b0247f96ba45f09dde2208c91b9b5` :
- `.github/workflows/famille-technical-gate.yml` : deux jobs groupés. Le premier démarre PostgreSQL 17 éphémère, crée le minimum Auth isolé, exécute le draft et lance les tests SQL. Le second vérifie les dix manifests Android et les dix manifests Web/PWA et échoue si un seul manque.
- `supabase/tests/0001_famille_core_smoke.sql` : tests du seed des dix applications, des 22 tables, du chemin valide des clés composites, de trois refus de liens inter-app/organisation, et de l'absence de grants/policies (default-deny uniquement).

**État de preuve :** workflow présent sur `main`, mais aucun run GitHub Actions n'est visible à la consultation (`total_count=0`). Le job SQL n'est donc pas déclaré PASS. Le job applicatif est conçu pour signaler les manifests manquants ; l'inventaire Git montre qu'aucun fichier sous `apps/android/` ou `apps/web/` n'existe à ce stade.

## 7. Critères impératifs avant VERT technique

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

## 8. Résultat

| Contrôle | État |
|---|---|
| Correction incompatibilité Kotlin/AGP/Gradle | CORRIGÉE DOCUMENTAIREMENT |
| Existence des versions Web vérifiées | PARTIELLEMENT CONFIRMÉE |
| Build Android réel | NON EXÉCUTÉ |
| Build Web/PWA réel | NON EXÉCUTÉ |
| Dix applications natives et dix PWA | ABSENTES DU DÉPÔT |
| Contraintes croisées SQL | DURCIES DANS LE DRAFT |
| Validation PostgreSQL 17 du draft | PASS — run #1 |
| Policies/GRANT/RLS Famille | NON FINALISÉS |
| Tests contraintes / refus inter-scope | PASS — 3 refus testés |\n| Default-deny (aucun grant/policy) | PASS — vérification structurelle seulement |\n| Tests RLS/isolation fonctionnels | NON EXÉCUTÉS ; policies absentes |
| Migration Supabase | AUCUNE |
| Déploiement | AUCUN |

**Conclusion :** les corrections SQL et le contrôle groupé sont préparés, mais le socle SQL passe les tests PostgreSQL 17 de syntaxe, de seed et de contraintes composites ; cependant, les policies/grants fonctionnels restent absents et les vingt projets applicatifs sont absents. Le run global reste en échec. Le Prompt 0.2 ne peut pas être déclaré vert techniquement tant que les policies/grants et tests RLS fonctionnels ne sont pas conçus, exécutés et approuvés. Le Prompt 0.1 ne peut pas être déclaré vert tant que les vingt applications ne sont pas construites et compilées. Aucun faux VERT.


## 9. Mise à jour de preuve — 14 novembre 2026

Le constat historique des sections précédentes est conservé comme photographie du premier contrôle. Il est supersédé, pour le SQL draft 0.2 uniquement, par le run GitHub Actions **43563686065**, commit testé `52d5b2b2b52d4eae59521091e85812ceda39e39c` : https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/43563686065.

Le job `SQL draft + contraintes + isolation par défaut` est **SUCCESS** sous PostgreSQL 17 éphémère. Il exécute le draft `supabase/drafts/0001_famille_core_proposed.sql`, puis `supabase/tests/0001_famille_core_smoke.sql`. Assertions réussies : 22 tables, exactement 10 applications seedées, insertion valide, rejet de trois liens inter-périmètres (application, organisation/lieu, plan/application), RLS activé et aucun GRANT ni policy Data API dans le draft.

### Verdict révisé
- **Prompt 0.2 — VERT TECHNIQUE (modèle commun et draft SQL isolé)** : syntaxe/exécution PostgreSQL 17, seed et contraintes testés avec succès.
- **Prompt 0.1 — VERT BUILD DES 20 SOCLES** : les 10 Web/PWA et 10 Android ont compilé et leur persistance a réussi dans le job applicatif du même run.
- **Sécurité RLS fonctionnelle / exposition Data API / autorisation de migration : HORS VERT.** Le draft n'a volontairement aucun GRANT ni policy ; les tests de ce job prouvent le refus par défaut, pas des parcours RLS autorisés. Ces sujets ne sont pas requalifiés en critères du Prompt 0.2 et restent soumis au chantier sécurité dédié.

Aucune base Supabase Replay ou Production n'a été modifiée. Aucun DDL/DML n'a été exécuté hors du conteneur PostgreSQL éphémère. Aucun déploiement ni publication.
