# Audit Prompt 0.4 — Comptes, invitations et appareils

Date : 14 novembre 2026  
Cible : Supabase Naxa — `eouwtuusnsuxaejsxknf`  
PostgreSQL : 17.11.0.002 — région `eu-west-1` — statut `ACTIVE_HEALTHY`  
Nature : audit SQL/catalogue en lecture seule. Aucun DDL, DML, réglage Auth ou déploiement effectué.

## 1. Conclusion exécutive

Le backend NAXA contient déjà les entités canoniques nécessaires pour l'identité, les profils, les partenaires, les pharmacies, les memberships, les affectations professionnelles, certaines invitations et plusieurs registres d'appareils.

**Décision : réutiliser le socle NAXA ; ne pas créer de table Famille parallèle pour users, profils, organisations, memberships, pharmacies, affectations ou appareils sans démonstration préalable d'un besoin distinct.**

Le Prompt 0.4 ne peut pas encore être déclaré prêt à implémenter. Deux anomalies majeures ont été identifiées :
1. Les fonctions `public.naxa_enforce_session_limit()` et `public.naxa_session_count(uuid)` sont des stubs : la première retourne simplement `NEW`, la seconde retourne toujours `0`. Elles n'appliquent donc aucune limite de sessions.
2. Le registre `public.appareils` est sous RLS mais sans policy ; il n'accorde aucun privilège direct à `anon` ou `authenticated`. Il est donc fermé pour les clients ordinaires, et son utilisation opérationnelle doit passer par des mécanismes serveur contrôlés ou être conçue explicitement.

Autres limites : aucune table générale d'invitations Famille/partenaire n'a été identifiée ; les invitations existantes sont spécialisées (examens médicaux, livreurs). Les réglages Auth globaux (inscription activée/désactivée, politique mot de passe, MFA, protection contre mots de passe compromis, templates et limites Auth) n'ont pas pu être lus par les requêtes SQL catalogue exécutées.

## 2. Preuves de structure et volumes

Comptages constatés sur la cible au moment de l'audit :
| Ressource | Lignes |
|---|---:|
| `auth.users` | 10 |
| `public.profiles` | 10 |
| `public.partners` | 0 |
| `public.partner_members` | 0 |
| `public.pharmacies` | 4 |
| `public.promoteur_pharmacies` | 1 |
| `public.naxa_professional_assignments` | 0 |
| `public.appareils` | 0 |
| `public.naxa_livreur_invites` | 0 |
| `public.exam_staff_invites` | 0 |
| `public.suivi_user_devices` | 1 |

Les volumes sont des nombres, sans extraction de données personnelles.

### 2.1 Identité et profil

- `auth.users` est bien la source d'identité Supabase.
- `public.profiles.id` est PK et FK vers `auth.users.id` avec cascade ; aucun identifiant de compte parallèle n'est nécessaire.
- `profiles` contient déjà téléphone, pays, prénom, nom, date de naissance, vérification de majorité, consentement, statut actif, parent de profil, fonction interne, niveau hiérarchique et rôle personnalisé.
- Un trigger actif `auth.users.on_auth_user_created` appelle `public.handle_new_user()`.
- La fonction exige username, prénom/nom, date de naissance majeure, consentement et téléphone/pays ; elle crée le profil à partir de `raw_user_meta_data`. Les données utilisateur ne doivent jamais devenir une source d'autorisation. Ici, le trigger s'en sert pour initialiser les champs du profil ; les droits doivent rester contrôlés par les tables canoniques et le serveur.
- La politique d'inscription Auth (ouverte/fermée) n'a pas été confirmée ; ne pas affirmer que l'inscription libre est bloquée.

### 2.2 Organisations, memberships et lieux

- `partners` et `partner_members` existent. Le membership relie `partner_id` à `auth.users.id`, avec rôles owner/manager/operator/viewer et PK composite.
- `partner_universes` porte les univers activés pour un partenaire.
- `pharmacies` et `promoteur_pharmacies` forment déjà le lien promoteur/pharmacie.
- Pour le périmètre pharmacie NAXA, les affectations de personnel reposent sur `profiles` et `naxa_professional_assignments`, pas sur `partner_members`.
- `partners` et `partner_members` sont actuellement vides sur cette cible ; leur présence ne signifie pas qu'ils doivent être forcés pour les pharmacies ou pour toutes les dix applications. Faire un mapping par application et type d'organisation.

### 2.3 Affectations professionnelles

`naxa_professional_assignments` est déjà le registre métier d'affectation à une pharmacie :
- profil cible, pharmacie, fonction, statut, motif, date de début et expiration éventuelle ;
- auteur de l'affectation, date et motif de révocation ;
- nature ordinaire ou urgence ;
- code de rôle référencé dans `naxa_roles`.
- Les fonctions métier admises comprennent caisse, gestionnaire_stock, magasinier, pharmacien, responsable, comptable et livreur.
- Les contraintes protègent les dates d'urgence, les transitions active/revoked et les fonctions.
- Les RPC `naxa_grant_professional_assignment`, `naxa_revoke_professional_assignment` et `naxa_set_professional_assignment_status` existent ; l'affectation est déjà contrôlée par le rôle et le périmètre pharmacie.
- Triggers synchronisent les rôles actifs et leurs alias.

### 2.4 Invitations existantes

- `exam_staff_invites` : invitation par e-mail, rôle, centre, auteur, expiration de sept jours, acceptation, affectation liée et révocation ; RPC de création, liste, acceptation, renvoi/révocation présentes.
- `naxa_livreur_invites` : invitation par e-mail liée à une pharmacie et à l'invitant, expiration de sept jours, acceptation et affectation liée ; RPC `naxa_create_livreur_invite`, `naxa_accept_livreur_invite`, `naxa_revoke_livreur_invite`.
- Ces flux sont spécialisés. Ils prouvent la possibilité de réutiliser des patterns, mais ne constituent pas un service générique d'invitation multi-applications. Ne pas fusionner ces parcours sans vérifier leurs règles propres.

## 3. Appareils et sessions — constat critique

### 3.1 Registres d'appareils

Deux registres à ne pas confondre :
- `public.appareils` : appareil rattaché à une pharmacie et à un utilisateur/profil, nom, hash de jeton, date de création, dernière synchronisation, actif et installation_id. FK vers `pharmacies` et `profiles`. RLS activé, zéro policy, pas de privilège direct anon/authenticated constaté ; service_role uniquement dans les grants vérifiés.
- `public.suivi_user_devices` : appareil de suivi de santé connecté, lié à `auth.users`, clé de type d'appareil, mode de connexion et consentement. Ce registre est spécialisé Santé ; il ne faut pas le réutiliser pour les sessions des dix applications.

Conclusion : `appareils` est le candidat NAXA pour les appareils professionnels liés aux pharmacies, mais ne couvre pas encore proprement l'ensemble des dix applications, les appareils client, ni un modèle multi-organisation générique. Vérifier les consommateurs et RPC avant toute extension. Aucun nouveau registre universel ne doit être créé avant cet inventaire d'usage.

### 3.2 Sessions Auth

- `auth.sessions` existe et RLS est activé ; il contient notamment user_id, session id, expiration éventuelle, user-agent et IP.
- Le trigger Auth de création de session doit être vérifié : les fonctions associées observées sont des stubs.
- `public.naxa_session_audit` et `naxa_session_audit_failures` existent pour tracer les sessions et rejets. L'audit contient session_id, user_id, pharmacie éventuelle, type d'événement, date, IP, user-agent et provider.
- `naxa_record_session_audit` et `naxa_record_session_limit_rejected` sont des fonctions SECURITY DEFINER réservées aux rôles serveur (service_role/postgres) avec search_path explicite.
- `naxa_enforce_session_limit()` est SECURITY DEFINER avec search_path `pg_catalog, auth`, mais son corps est actuellement `RETURN NEW` : aucune limitation n'est effectuée.
- `naxa_session_count(uuid)` est SECURITY DEFINER, réservé au serveur, mais retourne toujours `0`.
- Ces deux stubs rendent toute promesse actuelle de plafond ou de comptage de sessions non prouvée. Le plafond historique « deux appareils par point » n'est donc PAS démontré par ce mécanisme.
- Les tentatives échouées Auth ne sont pas équivalentes aux échecs du verrouillage local ; il faut une politique de limitation distincte, qui évite le déni de service contre un compte.

## 4. Sécurité et accès

- RLS est activé sur les tables métier examinées.
- `profiles` a des policies de lecture soi-même/parent/admin et de modification conditionnelle ; la table a cependant des grants SQL directs larges à anon/authenticated. RLS doit donc rester strictement correct ; le grant anon est à revoir, car aucun besoin d'accès anonyme direct au profil personnel n'a été établi.
- `partners` et `partner_members` ont policies admin + lecture membre ; les rôles et relations sont contrôlés.
- `naxa_professional_assignments` est directement lisible par authenticated sous policies participant/équipe ; aucun droit direct d'écriture authenticated n'a été relevé dans les grants inspectés, les RPC serveur font les mutations.
- `appareils`, `naxa_livreur_invites`, `exam_staff_invites` n'ont aucune policy RLS directe observée et aucun grant anon/authenticated dans les grants vérifiés : accès client direct fermé. Les RPC dédiées sont donc le chemin prévu, mais leurs ACL, implémentations privées, contrôles d'appelant et tests doivent être examinés au niveau de chaque flux.
- Les RPC métier privilégiées inspectées sont majoritairement SECURITY DEFINER avec search_path vide explicite ; quelques fonctions d'audit ont un search_path explicite limité. Le contrôle des EXECUTE et des fonctions SECURITY DEFINER doit continuer au-delà de cet échantillon.
- La fonction `public.handle_new_user()` est SECURITY DEFINER avec search_path vide, déclenchée par Auth. Elle crée un profil mais ne doit pas devenir un canal d'attribution de droits métiers.
- Le grant direct anon/authenticated sur `profiles` est une anomalie de moindre privilège à examiner en priorité, sans le retirer avant d'avoir vérifié les dépendances de l'application et les vues/RPC.

## 5. Matrice de décision

| Besoin Prompt 0.4 | Ressource existante | Décision |
|---|---|---|
| Identité de compte | `auth.users` | RÉUTILISER |
| Profil utilisateur | `profiles` | RÉUTILISER / ADAPTER prudemment |
| Téléphone et pays | `auth.users.phone`, `profiles.phone/phone_country` | RÉUTILISER ; auditer synchronisation et unicité |
| Organisation partenaire | `partners` | RÉUTILISER quand sémantiquement partenaire |
| Membership partenaire | `partner_members` | RÉUTILISER pour l'écosystème partenaire, pas pour toute affectation |
| Pharmacie / point NAXA | `pharmacies`, `promoteur_pharmacies` | RÉUTILISER |
| Affectation professionnelle | `naxa_professional_assignments`, `naxa_roles` | RÉUTILISER |
| Invitations employés pharmacie | Aucun flux générique confirmé ; livreur spécialisé existant | ADAPTER/ÉTENDRE après audit des fonctions privées |
| Invitation centre d'examens | `exam_staff_invites` | RÉUTILISER dans son seul domaine |
| Invitation livreur | `naxa_livreur_invites` | RÉUTILISER dans son seul domaine |
| Appareils professionnels pharmacie | `appareils` | RÉUTILISER après correction/validation du contrôle d'accès |
| Appareils suivi santé | `suivi_user_devices` | ÉCARTER du périmètre session/auth |
| Sessions Auth | `auth.sessions` | RÉUTILISER |
| Audit de session | `naxa_session_audit`, `naxa_session_audit_failures` | RÉUTILISER |
| Plafond de sessions | Fonctions stubs | CORRIGER ; ne pas annoncer actif |
| PIN/biométrie locale | Aucun mécanisme DB requis | IMPLÉMENTER côté Android natif ; ne pas stocker le PIN serveur |
| Récupération e-mail | Supabase Auth | RÉUTILISER après audit des réglages et templates |
| Récupération WhatsApp humaine | Pas de workflow générique confirmé | CONCEVOIR côté support/admin, sans PIN/OTP transmis |
| Autorisations Famille 10 apps | Pas de matrice universelle vérifiée dans cet audit | CONCEVOIR au-dessus des relations canoniques, sans duplication |

## 6. Contradictions et causes racines

1. **Prompt 0.4 suppose une limite appareil/session opérationnelle ; la DB contient deux fonctions stubs.** Cause : la surface SQL et les noms des fonctions donnent une impression de capacité sans logique d'application.
2. **Le prompt historique parle d'un plafond universel de deux appareils par point ; le modèle appareil actuel est pharmacie-spécifique et le modèle Auth est utilisateur/session.** Cause : confusion entre installation, appareil, session Auth et point de vente.
3. **Le prompt demande une création admin générique ; le backend montre un trigger Auth de création de profil, plus des invitations spécifiques par métier.** Cause : absence de flux générique unique démontré, et paramètres Auth non inspectés.
4. **Le modèle Famille ne peut pas simplement reprendre partners/members partout.** Cause : certaines apps utilisent une organisation/lieu métier qui n'est pas nécessairement un partenaire NAXA ; le mapping doit être par application.
5. **Le grant anon sur profiles est trop large par moindre privilège, même si RLS filtre les lignes.** Cause : héritage de grants génériques ; l'usage réel doit être cartographié avant révocation.

## 7. Travaux non couverts / vérifications restantes

- Lire les définitions complètes des triggers Auth de session, fonctions privées d'invitation et helpers de révocation ; reconstituer tous les consommateurs de `appareils`.
- Lire la configuration Auth via Dashboard/API autorisée : allow signups, mot de passe minimum, leaked password protection, MFA, rate limits, email templates, phone provider.
- Auditer la synchronisation `auth.users.phone` ↔ `profiles.phone`, unicité et normalisation par pays.
- Vérifier les politiques exactes de révocation de sessions, durée JWT, refresh tokens et invalidation après désactivation du profil.
- Auditer les grants EXECUTE de toutes les RPC de provisioning/invitation, pas seulement l'échantillon.
- Faire la matrice d'identité/organisation/membership par les dix applications.
- Vérifier les flux Android natifs et Web/PWA pour première connexion, biométrie, verrouillage local et changement de mot de passe.
- Tester le tout sur PostgreSQL 17 éphémère, avec scénarios positifs et négatifs inter-app/organisation/lieu. Cet audit de production n'est pas un test d'implémentation.

## 8. État et interdictions

**Prompt 0.4 : AUDIT STRUCTUREL PARTIEL — NON VERT.**  
**Prompt 0.3 : reste PARTIEL / NON CLOS.**

Aucune modification de base, migration, réglage Auth, création d'utilisateur, révocation de session, déploiement ou publication n'a été effectuée. Toutes les requêtes exécutées pour ce rapport sont des lectures du catalogue et des comptages agrégés.

## 9. Reprise exacte

1. Inspecter les définitions des triggers de sessions et la chaîne d'appel ; résoudre les stubs `naxa_enforce_session_limit` et `naxa_session_count` dans un environnement PostgreSQL 17 éphémère, pas en Production.
2. Auditer les RPC privées d'invitation et les consommateurs de `appareils`.
3. Confirmer les réglages Auth dans le Dashboard/API ; définir le provisioning administratif et le mode sans inscription libre.
4. Définir la matrice des organisations/lieux par application et les règles distinctes appareil/session.
5. Produire les tests et le diff de correction ; demander autorisation avant toute modification Production.
