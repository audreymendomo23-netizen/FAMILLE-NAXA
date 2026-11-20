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
