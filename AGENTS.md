# Instructions agents — Famille NAXA

## Gouvernance
- Travailler sur `main` uniquement ; pas de branche ni PR sans demande explicite.
- Aucun déploiement, migration Supabase Production ou publication APK sans autorisation explicite distincte.
- Ce dépôt `FAMILLE-NAXA` est le monorepo ; le dépôt historique `NAXA` reste une source documentaire historique.
- Dépôt public : aucun secret, token, mot de passe, OTP, dump ou donnée personnelle réelle.

## Méthode obligatoire
**audit → contradiction → cause racine → correction → test/preuve → documentation → état**.
- Séparer décisions validées, propositions et points ouverts.
- Ne jamais inventer un test, une preuve ou une validation.
- Ne pas déclarer VERT sur la seule base d'un build.
- Marquer PARTIEL ou BLOQUÉ si les critères ne sont pas prouvés.
- Préserver les ressources existantes ; préférer les changements additifs et réversibles.

## Architecture
- Dix applications autonomes, identités, parcours et permissions indépendants.
- Packages communs uniquement après audit de compatibilité.
- Isolation inter-applications et inter-organisations contrôlée côté serveur/RLS.
- Aucune clé `service_role` côté client.
- Android par APK depuis le site officiel NAXA, sans Play Store.
