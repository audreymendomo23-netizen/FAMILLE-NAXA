# B2 — Historique de messagerie privée
Pagination serveur stable (created_at,id), borne 1–200, pages UI 50, recherche et accusé explicite, polling sur page/filtre validés, refus curseurs hors conversation ou malformés. SQL et Replay Edge réels ajoutés. Ne revendique pas une pagination native E2E tant que build et recette ciblée non passés. Aucun main, migration hébergée, déploiement ou FCM réel.

### Réponses contextualisées
Candidat c6fe82f : 10/10 SUCCESS, preuve réelle pagination Edge. Ajout reply_to validé même conversation, extrait serveur limité à 180 caractères, idempotence inclut la référence, refus référence étrangère/inexistante, sélection/annulation Web/Compose. Replay réel ajouté. Les mentions, signalements avec mandat dédié et watch direct complet restent ouverts; aucune permission administrative implicite. Aucun déploiement ni migration hébergée.
