# NAXA SERVICES — contrat Auth mobile/serveur

Statut : contrat applicatif préparatoire ; serveur non déployé ; alias Auth à prouver localement.

## Conventions
- Edge Function attendue : naxa-services-auth.
- Le client transmet la clé anon Supabase, jamais service_role.
- app_code est imposé côté serveur à naxa-services ; le client ne peut pas demander une autre application.
- Identifiant public NAXA Services ; alias Auth jamais renvoyé au mobile.
- Erreurs de connexion non énumérables ; aucun secret dans logs/analytics.

## login

Requête : action=login, app_code=naxa-services, identifier, password, remember_device et device (installation_id, label, platform).

Réponse attendue : access_token, refresh_token, expires_in, token_type, require_password_change et account (member_id, display_name, role_code, organization_id, active_site_ids). Aucun alias.

## request_recovery

Requête : action=request_recovery, app_code=naxa-services, identifier, request_note et device.

Réponse générique identique que l'identifiant existe ou non. Aucune émission d'OTP, d'e-mail, de SMS ou de lien magique. L'agent habilité suit une vérification hors bande puis autorise ou rejette la demande avec audit.

## change_password
Requête authentifiée par le JWT courant. Le serveur vérifie le secret actuel/temporaire, applique la politique de mot de passe et enlève require_password_change uniquement après réussite Auth.

## refresh et logout
Refresh lié à l'appareil ; logout révoque la session et efface le coffre local. Un appareil perdu peut être révoqué à distance par un rôle habilité.

## Rester connecté
- Décoché : jeton en mémoire uniquement ; aucune session renouvelable ne survit à la fermeture.
- Coché : refresh token stocké chiffré via Android Keystore ; jamais le mot de passe.
- La préférence ne donne aucun droit : seules les sessions serveur et les scopes RLS l'autorisent.
- Rotation, durée, révocation et tolérance offline restent à configurer et tester.

## Messages UI
- Identifiant/mot de passe invalide, compte inexistant ou suspendu : « Identifiant ou mot de passe incorrect. »
- Limite d'essais : message neutre et contact du responsable.
- API non configurée/indisponible : état technique séparé, sans accuser le compte.
- Récupération : confirmation générique sans révéler si le compte existe.

## Conditions avant statut vert
1. Prouver l'alias GoTrue localement et l'absence d'e-mail sortant.
2. Implémenter Edge Function, provisioning, recovery et actions Admin.
3. Tester limitation, anti-énumération, rotation et révocation.
4. Tester remember-me, perte d'appareil et déconnexion distante.
5. Tester les parcours sur appareil Android réel.


## Complément — changement de mot de passe et persistance
L'action change_password transporte le refresh token courant dans le corps protégé par HTTPS afin de retourner la session complète après modification. Les jetons ne sont jamais persistés en clair. L'Android Keystore chiffre les jetons uniquement si la personne active « Rester connecté ». Cette option est décochée par défaut.


## Actions complémentaires de gestion d'accès

### provision_member
Action sécurisée pour un Promoteur, Responsable réseau ou Responsable de site autorisé :
- Corps : `action=provision_member`, `app_code=naxa-services`, `display_name`, `contact_phone` facultatif, `role_code` et `scopes[]`.
- Un scope est soit `{scope_type:"site", site_id}`, soit `{scope_type:"workstation", site_id, workstation_id}`.
- Le backend vérifie que l'acteur peut administrer les sites et le type de rôle demandé.
- Il crée l'identité Auth avec l'alias opaque de l'application, le compte, le membre et les scopes.
- Réponse unique : `login_id` + `temporary_password`, avec obligation de changer le mot de passe. La remise doit être contrôlée (idéalement en main propre). Aucun canal SMS/e-mail/WhatsApp n'est appelé.

### complete_recovery
Action réservée au Promoteur / Responsable réseau / Responsable de site sur son périmètre :
- Corps : `recovery_request_id`, `identity_check_method`, `identity_check_note`.
- Après vérification hors bande, le serveur change le mot de passe via l'API Admin, force la modification à la prochaine connexion, marque les appareils comme révoqués, clôt la demande et journalise l'action.
- Réponse unique : identifiant + mot de passe temporaire remis sous contrôle. Pas de notification e-mail/SMS.

### revoke_device
Action réservée à soi-même ou à un responsable autorisé : `account_id` (facultatif si révocation personnelle) + `installation_id`. La révocation marque l'appareil et invalide son futur renouvellement ; le contrôle RLS vérifie le `session_id` du JWT courant. Un JWT déjà délivré reste limité par sa durée de vie et par les contrôles de session RLS : ne pas promettre un effet rétroactif avant que la politique RLS soit appliquée et testée.

## Liaison technique des appareils
- L'appareil transmet un identifiant d'installation persistant non secret.
- Le serveur conserve le SHA-256 du refresh token et le `session_id` du JWT, jamais le refresh token en clair.
- À chaque renouvellement, le hash présenté doit correspondre au hash enregistré ; le serveur enregistre le hash du refresh token nouvellement rotaté.
- Une reconnexion avec mot de passe peut ré-enrôler l'appareil ; un refresh depuis une installation révoquée ou présentant un ancien refresh token est refusé.
- Le mode « rester connecté » contrôle seulement le stockage local du refresh token dans Android Keystore ; la table serveur garde des métadonnées et un hash non réversible pour lier l'état de session.
