# CONTINUITÉ — FAMILLE NAXA

**Dernière mise à jour : 14 novembre 2026 — 02:2x (heure Cameroun)**  
**Référence de travail : branche `main` uniquement**  
**Dépôt :** https://github.com/audreymendomo23-netizen/FAMILLE-NAXA

## 1. Point de reprise immédiat

Le **Prompt 0.2 — Schéma de données commun** est clôturé comme livrable de cadrage et de conception. Ne pas le relancer ni élargir son périmètre. Le modèle commun des dix applications, les frontières de schémas et la décision de ne pas réutiliser aveuglément le modèle pharmacie NAXA sont documentés.

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
- Dernier commit réalisé pendant cette reprise : `2634028153eb2e5fa70a0a0324f701ddd3fb8391`
- Fichier mis à jour : [Prompt 0.2](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/docs/architecture-360/PROMPT_0_2_SCHEMA_DONNEES_COMMUN.md)
- SQL draft conservé sans modification : [0001_famille_core_proposed.sql](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/supabase/drafts/0001_famille_core_proposed.sql)
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
| 14/11/2026 | Prompt 0.2 clôturé comme livrable de cadrage ; ajout du comparatif Replay/Production, des constats de sécurité et des limites exactes | Commit `2634028153eb2e5fa70a0a0324f701ddd3fb8391` |
| 14/11/2026 | Création de ce document de continuité | Commit `80e4664e24a9b233ec5c69b5ccabfbd7052908a2` |
