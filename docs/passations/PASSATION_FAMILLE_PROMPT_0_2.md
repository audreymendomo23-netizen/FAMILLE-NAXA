# FICHIER DE PASSATION — SOCLE COMMUN — PROMPT 0.2 — 14/11/2026

1. Fait : Prompt 0.1 stack documentée, 20 builds non faits ; Prompt 0.2 modèle 24 entités et draft 22 tables ; inventaires Replay/Production lecture seule ; run groupé PostgreSQL #1 PASS sur draft et trois refus inter-scope ; 20 manifests absents ; VERT technique 0.1/0.2 non acquis.
2. Références : Prompt 0.1, Prompt 0.2, draft SQL 0001, audit 0.1/0.2, continuité Famille.
3. Tables/fonctions : 22 tables proposées dans famille_core ; aucune fonction RLS avant 0.3.
4. Décisions : 10 apps ; Android natif + Web/PWA ; backend Famille séparé ; droits par app/organisation/lieu/rôle/état ; main uniquement ; pas de branche/PR/CI, migration, déploiement ou dépense sans accord.
5. Points ouverts : builds 20 apps ; exécution tests locaux ; tolérance à définir par facturation ; rôles par app ; raccordement tables transactionnelles/agrégats ; revue indépendante.
6. Prochain prompt : 0.3 — Sécurité des données et règles RLS.
7. Accord explicite : migration Supabase, Data API, déploiement, APK, dépenses, CI/workflows.


## Mise à jour de clôture — 14/11/2026

- Run de preuve : https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/43563686065 — SUCCESS.
- Le draft `0001_famille_core_proposed.sql` a été exécuté sous PostgreSQL 17 éphémère ; les 22 tables, 10 applications, le scénario positif, les trois refus inter-périmètres et le default-deny sans GRANT/policies sont PASS.
- Prompt 0.2 : **VERT TECHNIQUE pour le modèle commun et le draft SQL isolé**.
- Aucune migration Replay/Production, aucun GRANT, aucune policy RLS fonctionnelle, aucune exposition Data API ni aucun déploiement. La validation ne certifie pas la sécurité globale NAXA.
- Prompt 0.1 : les 20 builds (10 Android + 10 Web/PWA) et leur persistance sont PASS dans le même run.
