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

## Phase 2 — vérification approfondie et décision d'intégration (14 novembre 2026, 03:28 UTC+1)

### Vérifications complémentaires du projet NAXA

| Contrôle | Résultat vérifié |
|---|---|
| Tables public | 246/246 avec RLS |
| Tables RLS sans policy | 66 signalées par Advisor : 59 public, 7 private |
| Accès direct aux 59 tables publiques sans policy | Aucun GRANT direct à anon ou authenticated ; seulement postgres et service_role |
| Schéma private | anon n'a pas USAGE ; authenticated a USAGE mais les 7 tables sans policy restent refusées par RLS |
| Fonctions SECURITY DEFINER | 428 au total ; 344 dans public |
| SECURITY DEFINER sans search_path fixé | 0 selon le catalogue |
| Fonctions SECURITY DEFINER exécutables par anon | 7 signalées par Advisor |
| Fonctions SECURITY DEFINER exécutables par authenticated | 216 signalements Advisor |
| Vues SECURITY DEFINER | 3 : public.medicaments_cima_photos_public, public.marketplace_assureurs, public.marketplace_assurance_conventions |
| Autres vues sans option security_invoker constatées | bi.activite_mensuelle, bi.stock_pharmacies ; exposition et ACL à vérifier |
| Protection Auth contre mots de passe compromis | Désactivée selon Advisor |
| Advisors performance | 245 FK sans index couvrant, 13 alertes auth_rls_initplan, 267 index inutilisés, 83 groupes de policies permissives multiples, 1 index dupliqué |
| Edge Functions | 1 fonction active : naxa-images-import-temp, JWT requis |
| Storage | 7 buckets : 4 publics d'images/catalogue et 3 privés de documents/preuves/résultats ; 17 policies |
| Cron | 14 tâches NAXA actives |
| Extensions | 10 extensions, inventaire conservé dans la phase 1 |

Les 7 RPC SECURITY DEFINER accessibles à anon sont : get_home_service_catalog(), get_universe_catalog(text), marketplace_offre_stock_disponible(uuid,uuid), naxa_creer_proposition_favoris_apres_encaissement(), produits_populaires(integer,integer), search_pharmacies_panier(jsonb,double precision,double precision,double precision), universe_partner_is_public(uuid,text). Certaines semblent destinées à la lecture publique ; la fonction de proposition de favoris est à examiner en priorité car son nom évoque un effet d'écriture. Aucun test d'exploitation ni changement n'a été réalisé.

Les 59 tables publiques sans policy ne sont pas un accès ouvert : le contrôle ACL confirme zéro droit direct anon et zéro droit direct authenticated sur ces tables. Elles sont donc en refus par défaut pour les clients. Les 7 tables privées sans policy sont également à conserver fermées.

### Comparaison du modèle Famille au modèle existant

Le projet NAXA possède déjà :
- identité Auth dans auth.users et profil métier dans public.profiles ;
- structures partenaires dans public.partners, membres dans public.partner_members, univers dans public.partner_universes ;
- pharmacies/lieux existants dans public.pharmacies, liens Promoteur-pharmacie dans public.promoteur_pharmacies ;
- affectations professionnelles contextualisées pharmacie dans public.naxa_professional_assignments ;
- appareils, notifications, abonnements, paiements, caisse, stock, livraison et journaux déjà modélisés.

Le modèle Famille candidat ne peut donc pas être appliqué tel quel comme seconde source de vérité :
1. famille_core.identities duplique potentiellement les données de auth.users et profiles ; conserver Auth comme identité canonique et ne créer une projection minimale que si sa nécessité est démontrée.
2. famille_core.organizations et locations peuvent dupliquer partners, pharmacies et les points d'activité. Définir une correspondance d'identifiants et une source de vérité avant de créer des enregistrements parallèles.
3. profiles.role est un rôle historique NAXA spécialisé ; ne pas l'étendre en enum universel des dix applications. Le modèle Famille doit gérer les rôles par application, organisation et lieu, sans casser le modèle NAXA.
4. partner_members n'est pas équivalent à un membership par application et ne remplace pas les affectations localisées.
5. Les fonctions et tables NAXA spécialisées ne doivent pas être renommées, déplacées ou remplacées par les entités génériques Famille.

### Défauts de conception bloquants identifiés dans la migration candidate 0002

La revue statique de supabase/migrations/0002_famille_core_rls.sql montre :
- famille_core.outlet_ids() et has_organization_access(uuid) ne prennent pas de contexte app_id. Une membership active dans une application peut donc contribuer à un périmètre organisation/lieu utilisé par une autre application. Cela contredit l'isolation stricte par application.
- outlet_ids() retourne des lieux de l'organisation sans filtrage par application.
- is_admin() est global et ne porte pas de contexte d'application ; son sens doit être spécifié (administrateur plateforme global ou administrateur d'une app).
- Les rôles génériques owner/manager/platform_admin/commercial/partner sont insérés pour les dix apps sans matrice de rôles métier par app.
- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA famille_core TO authenticated ouvre tous les helpers SECURITY DEFINER aux utilisateurs authentifiés ; remplacer par une liste blanche d'API réellement appelables, garder les helpers internes non exécutables directement.
- Le modèle ne fournit pas encore le cycle complet et testé d'écriture pour création d'organisation, membership, affectation, appareil et installation ; les policies actuelles sont majoritairement SELECT et la seule RPC métier d'écriture centrale est la soumission d'intention de paiement.
- 0001_famille_core_proposed.sql se trouve dans supabase/drafts/ et est explicitement un draft non exécutable. 0002_famille_core_rls.sql se trouve dans supabase/migrations/ mais dépend du schéma et des tables de 0001. Le runner CI applique le draft 0001 avant 0002 ; le répertoire migrations seul ne constitue donc pas une séquence autonome prête à déployer.

### Décision de compatibilité

**Backend commun confirmé :** le projet Supabase NAXA eouwtuusnsuxaejsxknf reste la cible de partage décidée par l'utilisateur. Les dix apps n'auront pas dix backends.

**Intégration du DDL candidat : NON COMPATIBLE EN L'ÉTAT.** L'absence actuelle de collision de nom (famille_core absent) ne suffit pas. Le modèle proposé duplique des concepts déjà présents et ses helpers RLS présentent un risque de portée inter-applications. Aucun DDL Famille ne doit être appliqué avant refonte.

**Architecture à retenir pour la suite des prompts :**
- conserver auth.users comme identité d'authentification unique ;
- inventorier et réutiliser les entités NAXA qui correspondent réellement ;
- créer une couche de correspondance/abstraction Famille seulement là où le modèle NAXA ne couvre pas les dix applications ;
- pour chaque donnée Famille, imposer un périmètre explicite app_id, puis organization_id, puis location_id selon le domaine ;
- ajouter les tables métier des applications dans des schémas séparés et non exposés par défaut, plutôt que d'empiler les tables métier dans public ;
- ne jamais autoriser un helper de scope à retourner des droits ou lieux d'une autre application ;
- établir une matrice d'API et de GRANT explicite, pas de EXECUTE ON ALL FUNCTIONS.

### Périmètre restant hors de cette clôture

Le contrôle a terminé l'audit de compatibilité architecturale nécessaire pour reprendre les prompts. Il ne constitue pas une certification de sécurité exhaustive de NAXA : revue manuelle du code des 428 fonctions SECURITY DEFINER, inspection détaillée des 83 groupes de policies permissives, validation de toutes les vues/ACL, revue des sauvegardes/PITR, des secrets/configurations Auth et des flux de données de chaque Edge Function restent à planifier dans le chantier de sécurité NAXA. Le schéma Data API exposé doit être confirmé dans les réglages du projet ; la lecture SQL seule ne permet pas de conclure sur la liste de schémas PostgREST configurée.

Aucun DDL, DML, changement de configuration, migration, création de projet ou déploiement n'a été effectué pendant cet audit.
