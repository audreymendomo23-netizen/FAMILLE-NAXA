# AUDIT — PROMPT 0.3 — RLS

Date : 14 novembre 2026. Dépôt FAMILLE-NAXA, main.

Livré : migration candidate 0002, helpers, policies du socle, GRANT minimaux, action paiement idempotente, tests locaux, FR/EN et passation reconstituée.

Tests écrits : compte mère voit deux lieux et son abonnement ; gérant voit son lieu, pas un autre propriétaire ni les données de facturation ; autre propriétaire isolé ; admin zéro détail mais agrégat/abonnements ; commercial/partenaire zéro transaction ; accès conservé pendant grace_until puis lecture/INSERT/UPDATE/DELETE bloqués après expiration ; paiement et action « J'ai payé » accessibles ; payment_matches non lisible.

Contrôle complémentaire : `bash -n supabase/local-tests/run_prompt_0_3_local.sh` = PASS. Limites : psql/createdb/dropdb, Docker/Podman absents ; tests PostgreSQL/RLS non exécutés ; fixture de test et non vraies tables métier ; tables transactionnelles et vues agrégées réelles des dix apps à raccorder ; durée de grâce fournie par facturation ; aucune CI lancée, aucun SQL appliqué à Replay/Production.

Décision : Prompt 0.3 préparé, VERT technique non acquis. Commits d'implémentation et durcissement : `884f44a63d8b5518009dbbe4d25ebbfe4431f1e4`, `62738cb4f8a762cc260c8dd58a9f3da465acc5b1`, `f6de74718827dac95e1be048be9d1926bb1d94d1`, `9a4fcde9fb823235c08ef431276281a8d4eac9df` ; documentation/continuité : `9c6600bb98cf2a62b97ba3a82af1fe80c92a43b3`. Correctifs de durcissement : rôle manager exclu de la lecture des abonnements ; test de la fenêtre de grâce et des quatre opérations d'écriture. Commits de cette passe : `884f44a63d8b5518009dbbe4d25ebbfe4431f1e4`, `62738cb4f8a762cc260c8dd58a9f3da465acc5b1`, `f6de74718827dac95e1be048be9d1926bb1d94d1`, `9a4fcde9fb823235c08ef431276281a8d4eac9df`.
