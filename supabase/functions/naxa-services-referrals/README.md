# NAXA SERVICES — parrainage PME

## Règle fonctionnelle
- Une PME (organisation) dispose d'un code de parrainage actif unique.
- Le code est créé à la demande depuis Profil → Parrainage et suivi de mes gains.
- Le Promoteur de la PME filleule peut rattacher le code une seule fois. Une PME ne peut pas se parrainer elle-même et le rattachement n'est pas transférable.
- Un filleul ne compte qu'après confirmation serveur de son premier abonnement effectivement payé. Une inscription, un essai, un renouvellement ou un paiement encore pending ne qualifie pas le filleul.
- Chaque groupe de cinq activations qualifiées produit une récompense numérotée : formule mensuelle du parrain → un cycle mensuel gratuit ; formule annuelle du parrain → un mois d'accès supplémentaire à la fin de la période annuelle.
- Le registre des vagues est idempotent : un identifiant d'événement fournisseur et un abonnement ne peuvent pas être comptés deux fois. L'ordre d'activation verrouille la PME marraine pendant l'attribution d'une vague.

## Front/API
index.ts expose dashboard, create_code et apply_code pour un Promoteur authentifié. Les appels Android utilisent le jeton Auth utilisateur. Les tables ne sont pas lisibles par anon ou authenticated ; les lectures sont effectuées côté Edge Function après vérification de la session et du rôle.

subscription_first_paid est une entrée serveur à serveur. Elle exige x-naxa-referral-signature: sha256=<HMAC-SHA256(raw-request-body)> avec le secret NS_REFERRAL_WEBHOOK_SECRET. Seul le webhook du fournisseur de paiement, après vérification d'une capture initiale réussie et consultation de la cadence active réelle de la PME marraine, doit appeler cette action. Ne jamais autoriser l'application Android à appeler cette route.

## Mise en service non effectuée
Le fichier supabase/drafts/naxa_services_referrals_v1.sql est un candidat de migration non appliqué. Pour rendre le service actif, il faut d'abord vérifier la base de recette, appliquer cette migration dans un environnement isolé, configurer NS_REFERRAL_WEBHOOK_SECRET, déployer la fonction naxa-services-referrals, fournir NS_REFERRALS_FUNCTION_URL aux builds, puis raccorder le webhook de paiement et le service d'entitlements. Tant que cette dernière intégration n'a pas appliqué les récompenses, elles restent affichées pending_entitlement et ne doivent pas être présentées comme des mois gratuits déjà consommés.

## Vérification JWT à la passerelle Supabase

`supabase/config.toml` fixe `verify_jwt = false` uniquement pour cette fonction, car elle expose deux chemins d'authentification distincts :
- actions de Promoteur : la fonction vérifie elle-même le bearer via Supabase Auth puis vérifie le compte, l'organisation et le rôle actifs ;
- webhook fournisseur : la fonction vérifie le HMAC-SHA256 du corps brut avant d'appeler le RPC.

Ce réglage est volontairement compensé par ces contrôles applicatifs obligatoires. Ne jamais supprimer la vérification Auth des actions Promoteur ni la vérification HMAC du webhook. Ne pas réutiliser ce réglage pour une autre fonction sans une authentification applicative équivalente.
