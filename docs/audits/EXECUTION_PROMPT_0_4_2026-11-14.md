# Exécution Prompt 0.4 — comptes créés et administrés
Date : 14 novembre 2026
Dépôt : FAMILLE-NAXA / main
Statut initial : AUDIT STRUCTUREL PARTIEL.

## Réalisations dans cette passe
- Conservation de `auth.users` et `public.profiles` comme identités canoniques ; aucune seconde table utilisateur.
- Migration candidate additive `0004_prompt_0_4_account_lifecycle.sql` dans le schéma privé `famille_private` : droits applicatifs explicites, invitations à usage unique, registre d'appareils, verrouillage des tentatives, demandes de récupération, journal d'audit.
- Fonction SQL transactionnelle `register_device` : plafond de deux appareils par compte/application/organisation/lieu, révocation du plus ancien sous verrou consultatif.
- Fonctions SQL de verrouillage après cinq échecs, blocage de quinze minutes, remise à zéro après connexion réussie.
- Edge Function `famille-account-lifecycle` : création/invitation administrative, activation avec définition du mot de passe, connexion avec garde anti-bruteforce, enregistrement/révocation d'appareil, demande de récupération WhatsApp sans secret.
- Console d'administration Web bilingue FR/EN avec connexion administrateur et création d'accès (données d'identité, application, type, plan, durée, remise, essai).
- Bibliothèque Android commune : PIN local quatre chiffres protégé par Android Keystore/HMAC et préférences chiffrées, verrouillage temporaire après cinq erreurs, passerelle biométrique facultative.
- Tests PostgreSQL 17 isolés, tests Deno et builds Web/Android ajoutés.

## Matrice des ressources
| Besoin | Ressource canonique | Action |
|---|---|---|
| Identité | `auth.users` | Réutilisée |
| Profil | `public.profiles` + trigger existant | Réutilisé via metadata d'activation |
| Membres partenaires | `public.partner_members` | Autorisation d'invitation par rôle owner/manager et univers actif |
| Pharmacie | `public.promoteur_pharmacies`, `public.naxa_professional_assignments`, `public.naxa_roles` | Contrôle du périmètre et rôle assignable |
| Invitations spécialisées | `exam_staff_invites`, `naxa_livreur_invites` | Conservées, non remplacées |
| Appareils pharmacie | `public.appareils` | Conservé ; le registre privé couvre le scope multi-app non couvert par ce registre, à raccorder avant usage production |
| Sessions | `auth.sessions`, `naxa_session_audit` | Source canonique conservée ; pas de trigger Auth modifié |
| Appareils santé | `suivi_user_devices` | Hors périmètre |

## Limites bloquantes à la clôture
1. La migration est une candidate non appliquée. L'Edge Function n'est pas déployée ; aucun compte réel n'a été créé.
2. Le mécanisme de session de l'Auth NAXA ne peut pas encore garantir qu'une révocation de l'appareil invalide immédiatement le JWT déjà émis. L'endpoint indique explicitement `requires_server_session_gate`. Le hook/contrôle de session de Prompt 0.3 doit être raccordé avant de déclarer le cycle appareil entièrement sûr.
3. Le code Android local PIN/biométrie est une bibliothèque compilable, mais n'est pas encore branché au parcours Auth Compose des dix applications ; les écrans d'activation/login natifs restent à intégrer.
4. La console admin et Edge Function supposent les variables `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `FAMILLE_ACTIVATION_URL`. Aucun secret n'est commité. Le compte Admin doit recevoir `app_metadata.naxa_platform_admin=true` par une procédure hors client.
5. Le flux de récupération email officiel Supabase Auth est prévu par la console/SDK mais le parcours UI de reset email n'est pas encore relié ; l'assistance WhatsApp est un ticket humain générique.
6. L'affectation métier après activation doit être raccordée transactionnellement à `naxa_professional_assignments` ou `partner_members` ; l'autorisation d'inviter est vérifiée, mais l'insertion de l'affectation métier n'est pas encore exécutée par la fonction.

## Statut honnête
**PROMPT 0.4 : PARTIEL — NON VERT.** Les tests de la couche privée et les builds ne certifient pas encore le parcours complet Android/Web ni la révocation immédiate des sessions. Les points listés ci-dessus sont les critères exacts restant à fermer, pas une extension de périmètre.
Aucun DDL, DML, réglage Auth, création d'utilisateur, révocation de session, déploiement ou publication n'a été effectué sur Supabase NAXA Production.
