# AUDIT DE COMPATIBILITÉ — BACKEND COMMUN FAMILLE NAXA

Date : 14 novembre 2026, 03:26 (UTC+1)
Projet : Supabase `Naxa` — `eouwtuusnsuxaejsxknf`
Portée : inventaire initial en lecture seule ; aucune écriture.

## Identification

- Organisation : `unuefguzgsohvietmvmq`
- Région : `eu-west-1`
- Statut : `ACTIVE_HEALTHY`
- PostgreSQL : `17.11.0.002`

## Inventaire observé

| Élément | Résultat |
|---|---:|
| Schéma `famille_core` | Absent |
| Tables `public` | 246 |
| Tables `private` | 7 |
| Tables `cron` | 2 |
| Tables `net` | 2 |
| Tables tous schémas non système | 305 |
| Tables avec RLS | 281 / 305 |
| Tables avec FORCE RLS | 19 |
| Policies | 367 |
| Fonctions | 680 |
| Fonctions SECURITY DEFINER | 428 |
| Fonctions SECURITY DEFINER dans `public` | 344 |
| Vues / vues matérialisées | 11 |
| Historique des migrations | 541 entrées |

Historique de migrations : première version `20261004030744`, dernière `20261114004001`.

Extensions : http 1.6, pg_cron 1.6.4, pg_net 0.20.4, pg_stat_statements 1.11, pg_trgm 1.6, pgcrypto 1.3, plpgsql 1.0, supabase_vault 0.3.1, unaccent 1.1, uuid-ossp 1.1.

Aucune table sans RLS n'a été détectée dans les schémas `public` et `bi` par la requête ciblée. Les advisors ont également signalé de nombreuses policies permissives multiples et au moins un index dupliqué sur `public.stocks_lots` ; à rapprocher des audits NAXA existants.

## Analyse

1. L'absence de `famille_core` évite une collision immédiate de schéma.
2. Le backend est déjà riche et fortement personnalisé : les migrations Famille ne peuvent pas être injectées sans analyse des conventions existantes.
3. Les 428 fonctions SECURITY DEFINER, dont 344 dans `public`, nécessitent une revue des droits EXECUTE, search_path et contrôles d'identité.
4. Les 11 vues doivent être inspectées individuellement pour vérifier leur mode de sécurité et leur exposition.
5. L'historique de 541 migrations exige un contrôle précis de l'ordre, des dépendances et de la compatibilité.
6. Le modèle d'identité, les memberships, les rôles, les organisations et les lieux NAXA doivent être comparés au modèle Famille pour éviter une seconde source de vérité.

## Décision

**État : AUDIT INITIAL PARTIEL. Aucune migration autorisée à ce stade.**

Le backend commun reste le projet Supabase NAXA existant. Ne pas créer un backend distinct par application ni un projet Famille séparé par défaut. La prochaine phase doit comparer les tables, fonctions, identités et scopes existants au draft Famille, puis proposer une intégration additive sans régression NAXA.

## Preuve et limites

Les constats proviennent d'appels d'inventaire et de requêtes SELECT sur le projet identifié. Aucun DDL, DML, changement de configuration ou déploiement n'a été effectué. L'audit ne prouve pas encore la compatibilité fonctionnelle ou la sécurité exhaustive du schéma Famille.
