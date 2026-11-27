# WideMeet — continuité B5 : Assistance et administration
Date : 27 novembre 2026. Base auditée : 0963b9183fc13538ff5e3bfa6f37f422e9598e74.
Branche isolée : work/widemeet-b5-20261127. Aucun merge main, déploiement, mutation production ni modification des applications sœurs ou B1/B2/B3/B4/B6. Lecture des briques sœurs autorisée pour réemploi.

## Référentiel et preuves
- [Cahier §12, §13, N5 et méthode](../../7%20famille%20naxa/01-cahiers-des-charges/12-widemeet.md) ; [continuité générale](CONTINUITE_WIDEMEET.md). La décision exige FAQ multilingue, livechat, tickets, feedback, assistance audio, partage écran explicite, récupération sécurisée et console centrale avec droits techniques, comptes/organisations, offres, paiements, quotas, incidents, langues, métriques, audit, suspension/réactivation ; interconnexion autorisée, sans lecture invisible de réunion ni accès par défaut aux minutes privées.
- Code lu au SHA : apps/web/widemeet/src/{HelpCenter,SupportCenter}.tsx ; apps/android/widemeet/src/main/java/cm/naxa/widemeet/{MainActivity,SupportCenter}.kt ; supabase/drafts/widemeet_support.sql ; supabase/functions/widemeet-auth/index.ts ; scripts/widemeet/replay.mjs ; FoundationInstrumentedTest.kt.
- [Replay 45984772124, job 140457443178](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45984772124/job/140457443178) SUCCESS : logs lus, PASS récupération individuelle réelle GoTrue, clé à usage unique et révocation de deux appareils ; PASS ticket privé, idempotence, refus tiers, attribution atomique, réponse et clôture ; PASS navigateur demande, attribution, réponse, rafraîchissement et clôture. Stack jetable, non production.
- [Gate Android 45984772068, job 140457443687](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45984772068/job/140457443687) SUCCESS : 5 instrumentés exécutés Android 15, zéro échec ; test nativeFaqNavigation présent. Pas de preuve native de tout le cycle support.
- NAXA historique, code et recettes lus sur main : [workflow](https://github.com/audreymendomo23-netizen/NAXA/blob/main/.github/workflows/naxa-support-livechat-e2e.yml), [contrat audio/écran](https://github.com/audreymendomo23-netizen/NAXA/blob/main/scripts/test-support-audio.cjs), [recette agents](https://github.com/audreymendomo23-netizen/NAXA/blob/main/scripts/e2e/naxa-support-agent-browser.cjs). Les tests citent les migrations, routes et composants réutilisables ; leurs derniers résultats CI n'ont pas été vérifiés ici. Aucun transfert de secrets, utilisateurs ou données.

## Jauge de référence : 2/6 qualifiés de base, 1/6 partiel, 3/6 ouverts
Score provisoire (2+0,5)/6 = 41,67 %, arrondi 42 %. Ce score historique est conservé, non une certification exhaustive. Découpage de suivi proposé ci-dessous ; chaque bloc garde ses réserves. 1 point seulement si critères de clôture complets et preuve terminale ; 0,5 si partiel, 0 si absent/non prouvé. Recalcul contradictoire après couverture exhaustive, pas de hausse sur compilation seule.

| Bloc | Constat au SHA | Réserves / critères de clôture |
|---|---|---|
| B5.1 FAQ | FR/EN, 4 thèmes Web, recherche et navigation, test natif de navigation | Parité, traductions qualifiées selon CDC, parcours public/auth, FAQ cohérente, recherche et liens testés ; pas de prétention langues non qualifiées |
| B5.2 Tickets et Livechat texte, agents | SQL service-only, RLS, file masquée avant claim, demandeur/agent attribué, retries, limites, polling 5 s, Replay API+Web PASS | Android E2E, cycle d'agent (provisionnement, habilitations, révocation, réaffectation), feedback, échecs/retry, suivi et confidentialité ; libellé fallback HelpCenter à clarifier selon session |
| B5.3 Récupération | Individuelle par clé PASS ; demande neutre | Processus supervisé perte de clé ou incident GoTrue, vérification d'identité indépendante et contrôle des habilitations, révocation, anti-abus, audit, aucune divulgation ni reset anonyme ; approbation de la méthode avant activation |
| B5.4 Assistance audio | UI Web/Android déclarent indisponible ; SQL support actuel ne gère pas d'appel | Réemployer contrat NAXA : demande/acceptation/refus, consentement explicite, un appel par ticket, audio réel bidirectionnel, bail, fin, révocation agent/session/ticket, deux clients et refus tiers |
| B5.5 Partage écran | UI déclarent indisponible | Réemployer capture explicite NAXA, contrôle utilisateur, aucun audio système ni accès réunion, arrêt/retrait/revocation, audit et test média réel sur Web/Android, refus tiers |
| B5.6 Administration centrale | HelpCenter admin informatif ; aucune console centrale WideMeet prouvée ; rôle agent limité | Auditer admin famille/ZIPPLE (TOTP à vérifier), rôles dédiés, opérations comptes/org/droits/offres/quotas/incidents/support/langues/métriques/paiements en lecture ou mutation autorisée, suspension/réactivation journalisées, interconnexion API explicite, pas de lecture des minutes ni mutation financière non autorisée, tests négatifs et parité selon rôle |

## Contradictions et risques
1. Le vert du Replay prouve tickets/clé, pas audio/écran ni console. Les deux UI le disent explicitement. Ne pas confondre écran de réunion et assistance.
2. Agent booléen provisionné en fixture, pas de preuve d'administration opérationnelle. Le support n'est pas un administrateur de réunion. Le fallback HelpCenter dit tickets non connectés : vérifier chemin anonyme vs authentifié avant correction.
3. wm_request_recovery est une demande neutre, pas un parcours de récupération supervisée. Ne pas transformer en reset libre.
4. Le support de réunion n'est pas autorisé à accéder aux médias/minutes. Une assistance partage écran distincte nécessite consentement visible, révocation et aucun lien implicite avec salle.
5. WM_SUPPORT_QUALIFIED et WM_RECOVERY_KEY_QUALIFIED activés en Replay ; aucune preuve de production. Pas de changement de flags de production.

## Plan d'exécution strict B5
- Auditer fichiers NAXA exacts référencés dans test-support-audio.cjs, composants Android sœurs et console famille ; inventorier interfaces transport avant extraction/adaptation, ne pas coupler données ni droits interproduit.
- Construire appels et écran d'assistance sur contrat de ticket isolé ; compléter gestion agents/feedback et FAQ en parallèle logique ; concevoir récupération supervisée avec preuve indépendante ; console centrale par permissions dédiées et journal minimisé. Tous les ajouts WideMeet uniquement ; dépendances transverses en lecture seule si modification affecterait un autre bulk.
- Tests unitaires, SQL/RLS/ACL, Edge, navigateur deux comptes et média réel, Android natif avec comptes de recette, rejet tiers et concurrence, révocation, fermeture, expiration, reprise et nettoyage. Ne pas masquer les échecs, ne pas déclarer 100 % si test ignoré ou preuve manquante.
- À chaque réponse : jauge six blocs avec preuve SHA/run/job, delta, réserves, prochaines actions. Mettre à jour ce fichier et ne pas écraser le document de continuité général depuis cette branche parallèle.

## Journal
27/11/2026 — audit documentaire/code et logs CI de la base effectués. Document de suivi B5 créé. Aucun correctif fonctionnel ni nouvelle recette exécuté dans cette passe ; aucune progression fonctionnelle additionnelle revendiquée.

## 27/11/2026 — Passe de développement B5 (base code 64ad9058)
### Audit de réemploi effectif
- NAXA historique : migration audio 20261119150000_naxa_support_audio_calls.sql (blob 5bb8ea7a4acf022a06c8409007820aaf373233a1), migration consentement écran 20261120005321_naxa_support_screen_share_audit.sql (9d7a2a9c4336ff2d7b954f340e50b080822f8bca), SupportAudioCall.tsx (160fb9fef406c63c1bcf8da8f4a15b9d445b964e) : modèle agent assigné, permission, bail, consentement et arrêt de capture. Route admin/support-agents (c2125661a91a66497be6a97bbdffcc634bbaf9d9) : permissions explicites et cycle de vie. Contrats inspectés, pas de copie du transport/pharmacie ou des données. Recherche admin TOTP dans le monorepo sans résultat exploitable ; console et raccordement restent ouverts.
- WideMeet : SQL support, route Edge identité, SupportCenter Web/Compose et HelpCenter lus et adaptés. Pas de migration persistante.

### Livré sur la branche
- B5.1 : fallback anonyme Web/Android corrigé ; accès explicite à la connexion, pas de déclaration erronée d'indisponibilité du Livechat texte. Commit ae5a5c89 (Android), aacb440c (Web).
- B5.2 : note explicite 1–5 après clôture, demandeur uniquement, rejeu exact, autre valeur refusée, visibilité privée ; journal d'attribution append-only pour le service, remise en file par agent attribué et version d'attribution, refus du rejeu ancien même après reprise par le même agent. SQL service-only + RLS, route Edge et UI Web/Compose raccordées. Correctif de génération du SQL (substitution JS du motif regex) b8fe449f ; une seule définition de RPC, regex littérales préservées. Aucun résultat SQL ni build Android de cette révision encore attesté. Déploiement interdit.
- Recette API étendue : note avant fermeture, hors plage et type invalide, agent/tiers, rejeu exact, ancien agent révoqué, nouvelle attribution et ancien rejeu. Recette Chromium étendue : sélection de note et confirmation par lecture serveur. Commit 64ad9058. Recettes écrites, pas déclarées réussies.
- B5.4/B5.5 : contrat pur de politique média propre à WideMeet (packages/widemeet-domain/support-media-policy.mjs) et tests, adaptés du consentement et bail NAXA. Demande/acceptation/refus, identité/appareil, révocation bilatérale, version du ticket, échéance et renouvellement bilatéral, consentement écran explicite et arrêt. Les valeurs 60 s demande, 30 s bail, 30 min maximum sont des valeurs candidates de qualification, pas des règles commerciales approuvées. Le contrat exige des instantanés serveur authentifiés et n'est pas encore raccordé à une route, un stockage transactionnel ou un transport média. Les UI conservent l'indication d'indisponibilité audio/écran.
- Preuve locale : Node 22.16.0, node --test support-media-policy.test.mjs : 37/37 PASS, 0 fail/skip. Copies contrôlées avec git hash-object : contrat 85779f17dccac5a6b02d25d78624f160ccb1680f, tests fad9607002412e8ffd6434bc30f070f8bed9ab19. Les 35 assertions directes de l'ancienne révision ne sont pas additionnées. Aucune preuve média réelle.

### Jauge mise à jour (estimation de construction, non recette exhaustive)
| Bloc | Avant | Après | Justification |
|---|---:|---:|---|
| B5.1 FAQ | 1 | 1 | base qualifiée, aide corrigée, requalification requise |
| B5.2 Tickets/agents | 1 | 1 | base Replay qualifiée, feedback et remise en file candidats CI |
| B5.3 Récupération | 0,5 | 0,5 | clé individuelle qualifiée, supervision ouverte |
| B5.4 Audio | 0 | 0,5 | contrat pur testé, transport non raccordé |
| B5.5 Écran | 0 | 0,5 | contrat pur testé, capture/transport non raccordés |
| B5.6 Admin | 0 | 0 | audit de source agent, console non implémentée |
Construction estimée : 42 % → 58 % (3,5/6 ; deux blocs qualifiés de base, trois partiels, un ouvert). Qualification historique de référence : 42 %, non augmentée par les seuls contrats. Les 37 tests concernent la logique, pas une certification E2E ; les extensions tickets doivent passer Replay/Android.
Reprise stricte B5 : qualification API/Chromium et natif, branchement transactionnel de la politique (unicité des appels actifs, nonce de capture, sessions fraîches, audit, révocation effective), transport audio/écran Web et Android en environnement isolé, gestion complète des agents, récupération supervisée et administration centrale dédiée. Aucun accès de support aux réunions, aucun changement production/main ou autre bulk.
