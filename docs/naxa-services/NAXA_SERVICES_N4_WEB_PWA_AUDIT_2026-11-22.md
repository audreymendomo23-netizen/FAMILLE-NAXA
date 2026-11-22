# NAXA SERVICES — N4 Web/PWA : corrections du socle et points encore ouverts

**Date :** 22 novembre 2026  
**Branche :** `work/naxa-services-completion-20261120`  
**Verdict : PARTIEL** — transport entrant/sortant raccordé au journal N3 ; raccordement métier de tous les modules et recette navigateur E2E restent à terminer.

## Corrections livrées
- Le `device_id` Auth est maintenant obligatoire dans la session Web.
- IndexedDB v3 conserve les métadonnées, une séquence monotone par application/appareil, les changements entrants et leur curseur.
- L'outbox attribue la séquence et insère l'événement dans une transaction atomique ; une réutilisation d'ID avec autre appareil ou payload est rejetée.
- Push Web utilise `apply_sync_event` et le reçu SQL `event_id` / statut `applied` est vérifié avant acquittement. Aucun reçu n'est fabriqué côté navigateur.
- Pull Web utilise `pull_sync_changes`; les pages et curseurs sont persistés ensemble, les curseurs ne peuvent pas reculer, les changements reçus sont visibles sans réémission dans l'outbox.
- Les formulaires génériques, transitions pressing simulées et réglages organisation non raccordés sont neutralisés en session authentifiée ; le mode aperçu reste local et identifié.

## Limites qui restent à fermer
Le draft SQL v4 contient 48 branches d'action dans `ns_apply_sync_event`, mais cela ne vaut pas 48 interfaces Web métier. La création d'article de stock reste le seul parcours de création actuellement raccordé depuis cette interface. Agenda, pressing, caisse/ventes/paiements, catalogue, CRM/fidélité, équipe/commissions, sites/postes, achats/fournisseurs et rapports nécessitent des formulaires typés et leurs projections de données.

La recette E2E navigateur (IndexedDB réel, deux onglets, offline/online, reprise/crash, réponse perdue, changement de compte, révocation, scopes et convergence Android/Web) reste à exécuter. Le projet Supabase NAXA Services dédié n'est pas disponible pour tests hébergés ; drafts et CI PostgreSQL jetable ne sont pas un déploiement.

**Garde-fous :** aucun commit sur `main`, aucune fusion, aucun déploiement, aucune migration sur le Supabase historique NAXA/pharmacie. Les modules sans parcours serveur explicite restent désactivés hors aperçu.
