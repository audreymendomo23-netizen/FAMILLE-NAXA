# GRILLAD — Matrice d'interactions à qualifier
Les scénarios ne sont pas des probabilités statistiques : couverture par classes d'équivalence, valeurs limites, transitions d'état, rôles, sites, idempotence et concurrence. Aucun PASS avant résultat du runner. Les suites locales historiques ne prouvent pas à elles seules le navigateur sur Auth réelle.

| Domaine | Interactions / variations à couvrir | Preuve ou cible |
|---|---|---|
| Identité | Connexion correcte/incorrecte, récupération, invitations, expiration, révocation, deux appareils, rôle/site, déconnexion | Auth réelle locale + contrats B1 |
| Catalogue | Cinq familles, famille interdite, prix/coût historique, activation/désactivation, quantité nulle/négative/max, stock insuffisant | SQL business + navigateur/API local |
| Caisse | Ouverture, doublon, clôture équilibrée/écart, correction, espèces/MTN/OM, rapprochement, refus vendeur | SQL business/operations + local réel |
| Ventes | Individuelle, panier, annulation, permissions, reçu, doublon même événement, payload modifié, rupture, ventes concurrentes | product-race + local réel |
| Finance | CA, charges, coût inconnu/connu, résultat, achats, objectifs, filtres site/période/famille/article/vendeur | SQL + API ; local réel à enrichir |
| Équipe | propriétaire, manager, vendeur, site A/B, droits révoqués, pointage, correction, photo, GPS, minuit | attendance + auth bridge + local réel |
| Hors ligne | brouillons, perte réseau avant/après validation, relance, conflits, replay, changement de compte, restauration | Chromium fixture + SQL ; réseau réel à compléter |
| Abonnements | expiration, renouvellement, refus, justificatifs, rapprochement, doublon, SMS incomplet | API/SQL ; opérateurs réels distincts |
| ZIPPLE | QR, lien inactif, stock réservé, transition, refus, annulation, encaissements séparés | SQL/API + navigateur fixture ; partenaire réel distinct |
| Security | inventaire, scopes, session vidéo, révocation, incident | API ; caméra physique distincte |
| Notifications | destinataire, doublon, préférences, historique, point journalier | SQL/API ; push physique distinct |
| Appareils | Web, PWA, Android, petit écran, rotation, hors ligne, permissions, installation | CI builds et recettes existantes ; appareils physiques distincts |

## Campagne locale réelle
Premier run 46092875856 : Supabase démarre, erreur de propriétaire auth.sessions avant Auth, nettoyage réussi. Correction limitée au conteneur éphémère : rôle administrateur local pour colonne tag et permissions postgres strictement nécessaires. Nouveau scénario Chromium : connexion, vente via formulaire, contrôle de persistance et replay, catalogue cinq familles, refus de sixième, stock, rôles, charges et annulation idempotente, objectif, règlements déclarés et rapprochement. Les mutations supplémentaires passent par API réelle, pas par interaction UI complète ; pas de simulation de réponse. Aucune opération externe ou sur production.

## Vague parallèle — section 38
Six groupes autonomes, chacun sur sa propre base jetable : journey (formulaire Chromium + backend), identity, catalogue, cash, read-models, resilience (les cinq derniers via Playwright APIRequestContext et vrai handler, non UI complète). Aucun arrêt entre groupes sur un échec (fail-fast:false). Les contrôles matériels et les services externes non configurés restent distincts. Exécution réelle et couverture totale ne sont pas synonymes.

- Run 46093153386 : pile locale, schémas, provisionnement des deux identités, installation npm/Chromium PASS. Le premier login propriétaire retourne HTTP 401. Le log CLI confirme « no SMS provider is enabled. Disabling phone login ». Nettoyage effectué. Campagne standard 46093153453 : 15/15 SUCCESS.
- Commit 51140bcd2bab691eb55ecebff391b00ead110dd4 : configuration Twilio factice strictement locale, aucune clé de fournisseur réelle, aucun SMS envoyé ; précontrôle des deux grants password GoTrue et déconnexion des sessions temporaires. Configuration documentée par https://supabase.com/docs/guides/auth/testing-auth-flows. Aucun changement de handler/contrôles de sécurité produit. Verrou par SHA pour que les corrections n'attendent pas une ancienne révision. Les anciens runs continuent sans fail-fast.
- Nouvelles campagnes 46093425891 (6 suites réelles) et 46093425901 (15 jobs standard) acceptées par GitHub, en file au relevé. Aucun résultat nouveau encore certifié. 226 unités enregistrées et jauge 94 % maintenues ; aucune opération hébergée ni SMS payant.

- Révision 51140bcd : run 46093425901 15/15 SUCCESS ; run 46093425891 5/6 SUCCESS (journey Chromium, identity, catalogue, cash, resilience). Soit 20/21 jobs verts = 95,24 % de cette campagne, distinct de la jauge produit. Les vrais grants téléphone GoTrue, la vente UI, la persistance et les opérations réelles locales sont validés sur cette révision.
- Seul échec read-models, job 140819339160 : renouvellement attendu HTTP 200 alors que l'abonnement était actif. HTTP 403 est conforme au contrat renewal_guard. Aucun affaiblissement de la sécurité métier. Commit 5f0c3e505094b85ed139a7da0deaf21bed3bec07 : correction du test, refus de renouvellement-only sur abonnement actif, refus QR inconnu/malformé HTTP 403, transition locale contrôlée actif → expiré → actif, accès métier refusé à expiration, renouvellement propriétaire et rejeu/annulation, exclusion vendeur et site non autorisé. Transition uniquement via psql loopback sur fixture jetable, aucune écriture hébergée.
- Nouvelle vague complète : 46093780506 (15 jobs standard), 46093780509 (6 jobs réels), acceptées et en file au relevé. Aucun PASS présumé de la nouvelle révision. Les 226 unités enregistrées restent le décompte de référence (assertions supplémentaires dans le scénario existant). Jauge produit 94 % conservée en attendant le verdict et les réserves matérielles/externes. Aucun coût cloud ajouté, aucun main, aucun déploiement, aucun changement NAXA.
