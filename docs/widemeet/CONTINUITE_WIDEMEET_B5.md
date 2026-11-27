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
