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

Complément réorientation métier : assertions SQL vente MTN/réconciliation/caisse, 1 test nommé de pagination caméra (total 193 unités : 188 tests nommés + 4 suites SQL + 1 drill ; lots 50/50/47/46).
Complément modèle NAXA : 1 test API nommé d'extraction SMS volontaire sans confirmation et sans transmission du texte brut au RPC. Total 194 unités (189 tests nommés + 4 suites SQL + 1 drill), lots 50/50/47/47.

Complément : 2 tests nommés de la passerelle vidéo (refus non configuré, ticket HTTPS et périmètre). Total 196 unités (191 tests nommés + 4 suites SQL + 1 drill), lots 50/50/47/49. Assertions SQL registre de références global enrichies.

Complément : 1 parcours Chromium vente Orange Money déclarée manuellement, ajustement libellés et PDF Android. Total 197 unités (192 tests nommés + 4 suites SQL + 1 drill), lots 50/50/47/50.

Requalification : cinq campagnes complètes de cette passe vertes (70/70 jobs). Les campagnes 46087767668 et 46087851364 sont nouvelles et non certifiées au relevé ; voir section 30 de GRILLAD_CONTINUITE.md. Ne pas confondre les 197 unités du registre et les 14 jobs d'une campagne.

Passe challenge : 2 tests unitaires Web catalogue/lot, 2 tests identité centrale, 1 test natif ticket vidéo, 2 tests intake SMS, 1 parcours Chromium de reprise multi-lots. Total 205 unités (200 tests nommés + 4 suites SQL + 1 drill), lots 50/50/47/50/8. Les tests existants corrigés ne sont pas comptés deux fois.

Complément QR commun : 1 test API nommé, assertions SQL autorisation/révocation de paire. Total 206 unités (201 tests nommés + 4 suites SQL + 1 drill), lots indicatifs 50/50/47/50/9.

Dernier relevé : sept campagnes 14/14 ; dernière campagne 46089210628, quatre suites SQL vertes, vérifier le reste. 206 unités distinctes du nombre de jobs.

## Reprise challenge — section 32
4 tests nommés B1/B4 (UUID/autorevue, baux média et GPS) et 1 test API B5 (capture Admin sans dossier explicite) ajoutés ; assertions SQL de rapprochement par référence enrichies. Total 211 unités : 206 tests nommés + 4 suites SQL + 1 drill ; lots 50/50/47/50/14. Runs 46089210628 (relance), 46090190513, 46090290325 : chacun 14/14 SUCCESS. Migration 20261128005431 grillad_capture_match_a239147 réellement appliquée. Les 39 REC produit restent à certifier en environnement réel autorisé ; voir §32 de continuité.

## Section 33 — Recettes transactionnelles et contrats de raccordement
Ajout d'une suite PostgreSQL multivendeur (job server product-race, indépendante) et de cinq tests API nommés ; assertion minuit dans la suite de pointage existante. Total 217 unités (211 tests nommés + 5 suites SQL + 1 drill), lots 50/50/47/50/20. Les 15 jobs d'une campagne ne sont pas 217 jobs. Preuves : product-race SUCCESS sur 46091363065 ; les cinq nouveaux tests API SUCCESS dans infrastructure 46091421116 ; correctif syntaxe minuit f1b4db0, run 46091449597 à vérifier selon le relevé de continuité. Qualification produit complète et matérielle non présumée.

## Section 34 — NAXA Replay
Campagne locale 46091449597 : 15/15 SUCCESS. Un scénario supplémentaire enregistré (deux comptes Auth réels, Chromium, permissions et logout), workflow dédié 46091864360 : BLOCKED au préflight (six secrets absents), navigateur non exécuté. 217 unités locales + 1 scénario Replay bloqué = 218 enregistrées ; aucune recette réelle déclarée réussie. Voir §34 continuité.

## Section 35 — Réemploi du runner NAXA
Trois tests d'adaptateur ajoutés (ciblage Replay/opt-in, deux identités et clôture des sessions, refus du téléphone de profil non confirmé). Registre : 220 unités locales et 1 scénario Replay bloqué = 221 enregistrées. Campagne 46092177818 : 4/15 SUCCESS ; 0 échec(s) ; 11 en attente/en cours. Pas de preuve Auth réelle ; voir §35.

## Section 36 — Vérification effective des prérequis Replay
Campagne locale 46092177818 : 15/15 SUCCESS. Audit NAXA 46092597233 : comptes Promoteur/Caisse existants, téléphones Auth non confirmés, Edge GRILLAD 404, RPC non visibles ; scénario réel BLOCKED avant navigateur. Aucun changement de données et arbre NAXA temporaire restauré à l'identique. 220 unités locales + 1 scénario Replay bloqué, décompte 221 inchangé.

## Section 37 — Recettes d'interactions et Auth réelle locale
Matrice docs/grillad/RECETTES_INTERACTIONS.md. Run local réel 46092875856 bloqué au droit sur auth.sessions, nettoyage PASS. Run global 46092875806 15/15 SUCCESS. Correctif 00e7885 et enrichissement du scénario existant ; run réel 46093153386 local-real queued , run global 46093153453 lancé. Les assertions supplémentaires ne sont pas des recettes indépendantes ; 220 unités techniques locales historiques + 1 scénario autonome de qualification non encore validé, historique Replay conservé sans double comptage. Aucun nouveau PASS revendiqué.

## Section 38 — Vague parallèle
Six suites réelles isolées (journey existant, identity, catalogue, cash, read-models, resilience) ; 5 nouvelles recettes nommées. 220 unités historiques + 6 scénarios locaux réels = 226 enregistrées ; pas de PASS présumé. Campagnes 46093327908 (15 jobs standard), 46093327871 (6 jobs réels en attente de verrou précédent au relevé). Voir §38.

- Run 46093153386 : pile locale, schémas, provisionnement des deux identités, installation npm/Chromium PASS. Le premier login propriétaire retourne HTTP 401. Le log CLI confirme « no SMS provider is enabled. Disabling phone login ». Nettoyage effectué. Campagne standard 46093153453 : 15/15 SUCCESS.
- Commit 51140bcd2bab691eb55ecebff391b00ead110dd4 : configuration Twilio factice strictement locale, aucune clé de fournisseur réelle, aucun SMS envoyé ; précontrôle des deux grants password GoTrue et déconnexion des sessions temporaires. Configuration documentée par https://supabase.com/docs/guides/auth/testing-auth-flows. Aucun changement de handler/contrôles de sécurité produit. Verrou par SHA pour que les corrections n'attendent pas une ancienne révision. Les anciens runs continuent sans fail-fast.
- Nouvelles campagnes 46093425891 (6 suites réelles) et 46093425901 (15 jobs standard) acceptées par GitHub, en file au relevé. Aucun résultat nouveau encore certifié. 226 unités enregistrées et jauge 94 % maintenues ; aucune opération hébergée ni SMS payant.
