# CONTINUITÉ — FAMILLE NAXA

**Dernière mise à jour : 14 novembre 2026 — reprise technique (heure Cameroun)**  
**Référence de travail : branche `main` uniquement**  
**Dépôt :** https://github.com/audreymendomo23-netizen/FAMILLE-NAXA

## 1. Point de reprise immédiat

Les Prompts **0.1 et 0.2 restent ouverts pour leur validation technique**, à la demande explicite de l'utilisateur. Le cadrage documentaire existe, mais aucun VERT technique n'est acquis. Ne pas ouvrir le Prompt 0.3 avant les preuves de build Android/Web et les tests PostgreSQL/RLS du socle commun.

**Statut exact :**
- Cadrage et conception du Prompt 0.2 : **CLOS**.
- Schéma SQL Famille : **DRAFT UNIQUEMENT, NON EXÉCUTABLE**.
- Migration Supabase : **AUCUNE**.
- Sécurité globale Supabase : **NON CERTIFIÉE**.
- Production et Replay : **NON MODIFIÉS** pendant ce travail.
- Déploiement, publication APK et dépense : **AUCUN**.

## 2. Dernière preuve GitHub

- Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA`
- Branche : `main`
- Dernier commit de continuité antérieur : `490c368fa656ba160a4c6c4d49532abc2c20ac35`\n- Corrections techniques de cette reprise : `0d34889b89099183d054770bd6a67b405db4975b` (compatibilité Android), `1217a9cbe055a3aa2ab850b697b888eea2d8f218` (contraintes SQL), `5f28c1422e1d80f51b49e40f5177acb4152fc102` (audit technique), `6ec53f4d160dbcafbc41d906be162dcb381d4868` (index documentaire), `f57bb82e965eca8fd0b96cb3b3d670422776e127` (Prompt 0.2 aligné), `24792bb8dd2b0247f96ba45f09dde2208c91b9b5` (workflow et smoke SQL groupés), `52920be44db2ca9e54d430c92635b05596bda3bc` (rapport d'audit groupé initial), `b46010f8fb0a78878a1120fd528d088853f060aa` (résultat réel du run #1 intégré).
- [Prompt 0.1 corrigé](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/docs/architecture-360/PROMPT_0_1_CADRAGE_TECHNIQUE.md)\n- [Prompt 0.2](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/docs/architecture-360/PROMPT_0_2_SCHEMA_DONNEES_COMMUN.md)\n- [Audit technique 0.1/0.2](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/docs/audits/AUDIT_TECHNIQUE_PROMPTS_0_1_0_2.md)
- [SQL draft durci mais toujours non exécutable/non approuvé](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/supabase/drafts/0001_famille_core_proposed.sql)
- Prompt 0.1 : [Cadrage technique](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/docs/architecture-360/PROMPT_0_1_CADRAGE_TECHNIQUE.md)

## 3. Résultats de la dernière reprise

Contrôles Supabase en lecture seule, le 14/11/2026 :
- Replay `pwfftcsjyeibxxqhwysw` : 249 tables public, 2 private, 372 policies, 446 fonctions SECURITY DEFINER dans le relevé SQL ; Advisor avait relevé 447 à un instant de mesure différent.
- Production `eouwtuusnsuxaejsxknf` : 246 tables public, 7 private, 367 policies, 427 fonctions SECURITY DEFINER.
- Aucun schéma Famille (`famille_core` et les dix schémas applicatifs) n'existe encore en Production ni Replay.
- Replay : Advisor signale 66 tables RLS sans policy, 2 vues marketplace sans `security_invoker=true`, protection contre les mots de passe compromis désactivée, 215 clés étrangères sans index couvrant.
- Trois fonctions SECURITY DEFINER publiques exécutables par anon ont été lues : `marketplace_offre_stock_disponible`, `search_pharmacies`, `search_pharmacies_bulk`. Elles sont des endpoints Marketplace NAXA, pas des fonctions Famille.
- Replay : 9 buckets Storage, 23 policies Storage, 6 tâches cron actives, 9 extensions, 2 Edge Functions NAXA.
- Les inventaires Replay et Production diffèrent ; aucune synchronisation ou migration n'a été tentée.

Ces chiffres sont des instantanés du catalogue et des Advisor, pas une certification de sécurité. L'audit manuel exhaustif des fonctions, policies, grants, vues, triggers, migrations et tests d'accès n'a pas été réalisé. Voir la section 12 du Prompt 0.2 pour les limites exactes.

## 4. Architecture retenue

- Dix applications : Kiosko, Bootik, Zipple, NAXA Services, CotiZ, Loyable, NAXA Hotel, Campus237, NAXA Security, GrillaD.
- Dix applications Android natives, chacune avec son application Web responsive et sa PWA autonome. Aucune WebView-wrapper.
- APK distribuées depuis le site NAXA ; pas de Play Store.
- Monorepo indépendant du dépôt NAXA historique.
- Couche transverse proposée : `famille_core`.
- Schémas métier séparés : `kiosko`, `bootik`, `zipple`, `naxa_services`, `cotiz`, `loyable`, `naxa_hotel`, `campus237`, `naxa_security`, `grillad`.
- Auth commune possible via `auth.users`, mais l'authentification ne vaut jamais autorisation métier.
- Permissions contextualisées par application, organisation, lieu, rôle et statut.
- Aucune table Famille dans `public` par défaut ; aucun schéma Famille exposé au Data API sans GRANT minimal, RLS/policies et tests négatifs.
- Les données sensibles métier (paiements, soldes, stocks, caisses, tontines, loyers, réservations, comptabilité, sécurité) restent gouvernées par leurs domaines et transitions serveur.

## 5. Fichiers de référence

1. [Prompt 0.1 — Cadrage technique](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/docs/architecture-360/PROMPT_0_1_CADRAGE_TECHNIQUE.md)
2. [Prompt 0.2 — Schéma commun clôturé](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/docs/architecture-360/PROMPT_0_2_SCHEMA_DONNEES_COMMUN.md)
3. [SQL draft non appliqué](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/supabase/drafts/0001_famille_core_proposed.sql)
4. [Registre des décisions](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/docs/DECISIONS.md)

## 6. Règles de reprise à respecter

- Reprendre depuis ce document et les fichiers GitHub, pas depuis des suppositions.
- Travailler sur `main` uniquement ; ne créer ni branche ni PR.
- Ne jamais exécuter le SQL draft.
- Ne modifier ni Replay ni Production, ne pas exposer le Data API, ne pas déployer, publier d'APK ou engager de dépense sans accord explicite.
- Ne pas rouvrir le Prompt 0.2 pour ajouter du périmètre.
- Ne jamais déclarer VERT sans preuve ; distinguer clôture documentaire et readiness technique.
- À chaque réponse qui fait avancer le projet Famille NAXA, mettre à jour ce document avec date, commit, preuves, décisions, statut et point de reprise exact.

## 7. Prochaine étape de travail

**Point de reprise : ouvrir le Prompt 0.3 / prochain prompt du corpus source et le traiter strictement dans son périmètre.** Avant de commencer, relire son texte source exact et les décisions déjà publiées. Ne pas commencer les dix applications ni créer de tables Supabase tant que le prompt correspondant ne le demande pas explicitement et que les prérequis ne sont pas validés.

Si le prochain prompt source n'est pas présent dans le dépôt, le retrouver dans les fichiers du corpus ZIP déjà importé ou dans la bibliothèque du projet ; ne pas inventer son contenu.

## 8. Journal des mises à jour

| Date | Changement | Preuve |
|---|---|---|
| 14/11/2026 | Reprise de validation technique : incompatibilité Kotlin 2.2.21 / AGP 9.5 / Gradle 9.6 détectée et corrigée dans Prompt 0.1 ; contraintes composites app/organisation ajoutées au SQL draft ; audit technique et blocages documentés ; audit ajouté à l'index, Prompt 0.2 aligné sur les contraintes SQL partiellement ajoutées et contrôle CI groupé exécuté : PostgreSQL PASS, inventaire 20 apps FAIL (20 manifests absents). VERT technique non acquis. | Commits `0d34889b89099183d054770bd6a67b405db4975b`, `1217a9cbe055a3aa2ab850b697b888eea2d8f218`, `5f28c1422e1d80f51b49e40f5177acb4152fc102`, `6ec53f4d160dbcafbc41d906be162dcb381d4868`, `f57bb82e965eca8fd0b96cb3b3d670422776e127` |
| 14/11/2026 | Création de ce document de continuité | Commit `80e4664e24a9b233ec5c69b5ccabfbd7052908a2` |
| 14/11/2026 | Ajout de la continuité Famille dans l'index documentaire | Commit `a4932604f23d0d985de8b72dce5551569d9802b4` |
