# CONTINUITÉ — FAMILLE NAXA

14 novembre 2026 — dépôt `audreymendomo23-netizen/FAMILLE-NAXA`, branche `main`.

- Prompt 0.1 : cadrage documenté ; VERT technique non acquis (20 apps non compilées).
- Prompt 0.2 : schéma documenté ; draft 0001 exécuté dans PostgreSQL 17 éphémère au run #1 ; VERT technique complet non acquis.
- Prompt 0.3 : migration candidate, helpers RLS, policies core, GRANT minimaux, tests locaux, FR/EN et passation préparés ; gérant exclu de la lecture de facturation ; tests écrits couvrent grâce active puis blocage SELECT/INSERT/UPDATE/DELETE après grâce ; VERT technique non acquis (tests non exécutés, tables métier non raccordées).

Source 0.3 : `Projet.zip` → `Nouveau projet/Prompt/Prompts_00_Socle_commun.pdf`, page 6. Passation formelle 0.2 absente ; reconstituée dans `docs/passations/PASSATION_FAMILLE_PROMPT_0_2.md`.

Décisions : 10 apps, Android natif + Web responsive/PWA ; compte mère = rôle organisation ; gérant = lieux assignés ; admin = agrégats/abonnements sans détails ; commercial/partenaire sans transactions ; `grace_until` fixé par facturation, sans durée inventée. Main seulement, aucune CI, migration, Data API, déploiement, APK ou dépense.

Fichiers 0.3 : Prompt 0.3, migration 0002, bootstrap/tests locaux, runner, FR/EN, audit et passation.

Commits Prompt 0.3 : `884f44a63d8b5518009dbbe4d25ebbfe4431f1e4`, `62738cb4f8a762cc260c8dd58a9f3da465acc5b1`, `f6de74718827dac95e1be048be9d1926bb1d94d1`, `9a4fcde9fb823235c08ef431276281a8d4eac9df`.

Point de reprise : installer PostgreSQL 17 local, exécuter `bash supabase/local-tests/run_prompt_0_3_local.sh`, corriger/relancer, raccorder les vraies tables et vues des dix apps, valider capacités et grace_until. Ne pas ouvrir 0.4 avant preuve et clôture.
