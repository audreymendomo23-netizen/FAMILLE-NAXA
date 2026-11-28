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
