# GRILLAD — Registre des campagnes de recettes

Baseline : bd266b0 ; dernière qualification 4/4 fd36c54. Périmètre V1.5, REC-01 à REC-39. Les cas GRC sont des contrôles techniques indépendants et ne certifient pas les REC produit.

## Lots (50 maximum)
| Lot | Contenu | Exécution | Taille |
|---|---|---|---:|
| 01 | GRC-001–050, 25 contrats API authentifiés + 25 refus anonymes | job lot-01 | 50 |
| 02 | Android 4, Web unitaires 14, Chromium démo 4 + connecté 2, infra/API historiques 10, 3 suites SQL transactionnelles + GRC-051–063 (13) | 9 jobs indépendants | 50 |
| 03 | GRC-064–093 (mode réseau, service, régularisations, composition, sites, affectations, objectifs, suspension) + 12 parcours Chromium métier (HTTP simulé) + 4 tests PIN Android (job Android du lot 02) + 1 drill de sauvegarde/restauration | 4 jobs concernés (incl. restauration isolée) | 47 |
| 04 | GRC-094–115 (recomptage, achats, arrivées manquantes, renouvellement, politique de pointage, Connect) + 9 parcours Chromium (horaires, demandes centrales, recomptage, achats, arrivée, renouvellement, politique, Connect) | job lot-04 + Web métier | 31 |

Total après extension : 174 tests nommés (115 GRC + 34 existants + 21 parcours Chromium + 4 PIN) et 3 suites SQL + 1 drill isolé (178 unités exécutables ; les assertions SQL internes ne constituent pas des tests indépendants). Ne pas gonfler le compteur avec les assertions ou compter deux fois les mêmes tests. Les matrices Web et SQL ont fail-fast:false et aucun partage de base. Une révision = un run ; les runs antérieurs ne sont pas annulés par le développement. Les échecs doivent rester visibles.

## REC produit : rapprochement et limites
| REC | Couverture actuelle candidate | Reste pour certification |
|---|---|---|
| 01–05 | Catalogue, stock, prix, SQL, UI | cinq familles et historique sur clients réels |
| 06–09 | Autorisations, annulation, caisse et dépenses | appareil/API, politique de caisse finale |
| 10 | coût manuel, inconnu explicite | composition validée |
| 11–14 | SQL sites/droits/rapport/replay | provisionnement et authentification réels |
| 15–16 | journal incertain et conflits SQL | hors-ligne métier validé et concurrence réelle |
| 17,20,25,27 | portée, accès et consolidation SQL | comptes et API réels |
| 18–19 | conditionnels | arbitrage IA étendue/parrainage |
| 21–22 | replay après rechargement, données serveur | offline étendu, chiffres partiels à qualifier |
| 23–24,26 | fixture comptes multiples, isolation et atomicité | création équipe/sites réelle, concurrence multi-vendeurs |
| 28 | tarifs tests unitaires et SQL | souscription commerciale et paiement |
| 29–30 | capture, photo privée, GPS, durée, SQL | téléphone, correction et minuit |
| 31–32 | QR, commande, statut, réservation et replay candidat | partenariat ZIPPLE réel |
| 33 | démo et build natif | parcours cinq familles sur appareil |
| 34 | liste caméra et refus vendeur | flux temporaire, partenaire et révocation réels |
| 35 | rapport, filtres, PDF/XLSX | rapprochement complet et API réelle |
| 36 | préférences, déduplication interne | FCM livré et événements réels |
| 37–38 | prévision, objectifs et rapport | historique suffisant et cas limite réels |
| 39 | service et daily_tick idempotent | minuit, corrections versionnées, état provisoire et cron |

Aucune recette produit n'est certifiée intégralement ici. Les tests HTTP simulent l'amont, les SQL utilisent PostgreSQL jetable ; pas de paiement, caméra, FCM, déploiement ou migration hébergée.

## Extension de reprise — sections 21–23
Trois tests nommés ajoutés aux jobs existants : récupération uniforme, export PDF achats, export XLSX achats. Assertions SQL complémentaires (même suite lifecycle). Nouveau total : 177 tests nommés + 3 suites SQL + 1 drill = 181 unités ; lot 04 : 34 unités (complément exécuté par infrastructure/Web unitaires). Les autres lots restent 50/50/47. Pas de qualification produit présumée.

Complément §24 : un parcours Chromium métier de réactivation après confirmation serveur ; lot 04 = 35 unités, total 182 (178 tests nommés + 3 suites SQL + 1 drill). Réactivation et paiements réels non simulés comme preuves de production.

Complément profil : un test API et un parcours Chromium métier (profil individuel), assertions SQL lifecycle enrichies. Total 184 unités (180 tests nommés, 3 suites SQL et 1 drill), lots 50/50/47/37. À qualifier sur le SHA de code.

Complément opérations : 1 test API nommé + 1 suite SQL intégrée lifecycle (provisionnement, paiement, lot et invitation). Total 186 unités (181 tests nommés, 4 suites SQL, 1 drill), lots 50/50/47/39 ; qualification en cours.

Complément invitation : 1 test API supplémentaire, assertions partenaires ZIPPLE/SECURITY ajoutées à la suite SQL opérations. Total 187 unités (182 tests nommés, 4 suites SQL, 1 drill), lots 50/50/47/40.

Complément : 1 test API paiement et 2 parcours Chromium (référence sans débit et lot de préparations). Total 190 unités (185 tests nommés, 4 suites SQL, 1 drill), lots 50/50/47/43.

Complément conflits hors ligne : 1 test API d’annulation vérifiée et assertions SQL tombstone/rejeu ; total 191 unités (186 tests nommés, 4 suites SQL, 1 drill), lots 50/50/47/44.

Complément démarrage Android : 1 test unitaire nommé (validité cache), assertions lifecycle invitation/renouvellement/projection enrichies. Total 192 unités (187 tests nommés + 4 suites SQL + 1 drill), lots 50/50/47/45.
