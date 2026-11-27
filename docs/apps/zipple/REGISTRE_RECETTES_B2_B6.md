# ZIPPLE — Registre maître des recettes B2 à B6

Audit du 27/11/2026. Base documentaire et code : `cd73cd21a545a94b790881469c2c7e91361da4b9` ; candidat fonctionnel qualifié `be6022782138d069d2cd5ae65770fbaf37bce235`.

Sources : [CDC V2.0](../../cahiers-des-charges/ZIPPLE_V2_0.md), [audit](AUDIT_CONFORMITE_BULKS.md), [continuité](CONTINUITE_ZIPPLE.md), gateway, inventaire SQL, workspaces Web et Android et suites réelles ci-dessous. CDC §§23.1–23.11 et addenda intégrés; B1 exclu du décompte (ses régressions transversales sont conservées en B6). Découpage de l'auditeur : une ligne = un scénario fonctionnel distinct avec résultat observable; variantes positives/négatives et assertions peuvent être regroupées. Ce nombre n'est ni le nombre de fonctions de test automatisées ni une mesure du pourcentage de code. Les cas supplémentaires révélés par implémentation ou tests doivent être ajoutés avec nouvel ID, sans renumérotation. Aucun test n'est créé ou exécuté par ce commit documentaire. Le registre est une couverture de référence large, pas une preuve que chaque permutation ou écran a déjà été vérifié.

## Décompte

| Bulk | Total | V | P | A | D | Restant à qualifier |
|---|---:|---:|---:|---:|---:|---:|
| B2 | 37 | 26 | 11 | 0 | 0 | 11 |
| B3 | 46 | 31 | 13 | 0 | 2 | 15 |
| B4 | 36 | 8 | 10 | 6 | 12 | 28 |
| B5 | 29 | 3 | 22 | 4 | 0 | 26 |
| B6 | 31 | 6 | 16 | 0 | 9 | 25 |
| **TOTAL** | **179** | **74** | **72** | **10** | **23** | **105** |

V = scénario local couvert par preuves existantes, périmètre explicitement indiqué (pas preuve hébergée/physique); P = preuve partielle ou couverture exhaustive non établie; A = action/parcours à compléter ou qualification dédiée sans preuve; D = dépendance réelle, arbitrage ou autorisation nécessaire. Pour toute recette P/A/D, conserver les assertions existantes, construire ou compléter l'action, jouer le positif et les refus, vérifier la persistance et archiver run/commit/rapport. Une absence de preuve ne prouve pas absence de code. B2 reste clôturé sur son gate local; les compléments identifiés sont des réserves de couverture et non une réouverture automatique des parcours déjà verts. Aucune fausse confirmation opérateur, aucun skip d'un parcours exigé, aucun secret publié, aucun main ni production sans autorisation.

## Preuves de référence

- SQL : [46028484900](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46028484900), 46/46 ; `n2-n5/recipe.test.mjs` et contrats de la même suite.
- WEB-OP : [140605912477](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46028484883/job/140605912477), `n2-n5/local-business.test.mjs`, 1/1 ; WEB-WS : [140605911950](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46028484883/job/140605911950), `n2-n5/local-workspaces.test.mjs`, 1/1.
- NATIVE : [140605912474](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46028484883/job/140605912474), `n2-n5/local-business-device.test.mjs` et `Bulk2LiveDeviceTest.kt`, 1/1. Marqueurs ci-dessous abrégés (préfixes ZIPPLE_/BULKx_ et suffixe _PASS parfois omis), recherchables dans les suites. Les trois suites E2E sur GoTrue, Edge et PostgreSQL local ont zéro échec/skip.
- SOCLE : [46028484878](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46028484878) ; APK : [46028484799](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46028484799) tentative 2 SUCCESS, job 140610313405 (429 Maven de la tentative 1 résolu sans modification de code). Un APK compilé ne vaut pas recette métier hébergée.

## Matrice unique

### Bulk 2 — 37 recettes

| ID | CDC | Action et résultat attendu | Statut | Preuve ou travail restant |
|---|---|---|---|---|
| B2-001 | 2.1,23.1 | Créer plusieurs établissements et choisir Restaurant ou Snack-Bar ; option Bar seulement en Restaurant | V | SQL, WEB-OP : séparation des sites et mode |
| B2-002 | 2.1,13.1 | Administrer hiérarchie entité juridique, organisation, établissement, espace, zone, poste ; délégations fines par fonction | P | SQL, WEB-OP : scope et rôles opérationnels ; entité juridique et toutes fonctions à vérifier |
| B2-003 | 3.1,23.2 | Créer table et retrait, générer QR opaque unique, renouveler table fermée ; refuser ancienne session | V | NATIVE_TABLE_QR_PERSISTENCE, REAL_EDGE_QR_RESERVATION |
| B2-004 | 3.1 | Afficher, exporter PNG, partager QR natif ; vérifier décodage et droits URI | V | NATIVE_TABLE_QR, NATIVE_QR_PNG_SHARE_CONTRACT ; choix physique B6 |
| B2-005 | 3.2,23.2 | Ouvrir menu public sans compte, lier commande à table et jeton ; refuser commande d'un autre invité | V | WEB-OP : scénario invité et isolation |
| B2-006 | 3.3,23.3 | Désactiver article, actualiser disponibilité, rejeter commande périmée | V | WEB-OP : disponibilité serveur |
| B2-007 | 3.3,23.3 | Deux clients concurrents dernière portion : une seule vente, quantité jamais négative | V | REAL_EDGE_LAST_PORTION_RACE |
| B2-008 | 3.3,23.3 | Libérer réservation stock sur expiration, annulation, no-show ; tous types de stocks et canaux | P | SQL : NO_SHOW_STATION_WINDOW ; couverture croisée à compléter |
| B2-009 | 3.4,8.1 | Panier multi-articles, variantes obligatoires/facultatives, suppléments et substitutions ; prix exact | V | SQL : OPTIONS_PRICING_CHANNELS ; WEB-OP : formule |
| B2-010 | 3.4,8.2 | Formules composées, stock composants déduit une fois et rejet si indisponible | V | SQL : COMPOSITE_FORMULA ; REAL_EDGE_FORMULA_GROUP_PAYMENT |
| B2-011 | 8.3 | Prix par canal, fenêtres tarifaires, historique, plafond de vente | V | SQL : SALE_LIMIT_PRICE_HISTORY, OPTIONS_PRICING_CHANNELS |
| B2-012 | 3.5 | Deux invités même table, commandes distinctes, lecture privée et addition consolidée | V | WEB-OP : FLOOR_BILL_FEEDBACK et isolation invité |
| B2-013 | 3.5 | Addition groupée et individuelle, transfert motivé vers table ouverte, conservation commande d'origine | V | NATIVE_TABLE_BILL_TRANSFER_AND_GROUP, NATIVE_GROUP_BILL_PERSISTENCE |
| B2-014 | 3.5,11.2 | Fractionnement par quantité, montant, même moyen ; empêcher surpaiement et doublon | V | SQL : ITEM_QUANTITY_PARTIAL_SETTLEMENT_AND_CASH ; NATIVE : SPLIT_QUANTITY_AMOUNT_AND_CASH |
| B2-015 | 3.5,11.2 | Encaissement mixte trois moyens, référence requise non espèces et clôture exacte | V | WEB_THREE_TENDER_PARITY, NATIVE : SPLIT_QUANTITY_AMOUNT_AND_CASH |
| B2-016 | 3.4,addendum | Reçu PDF uniquement après règlement intégral ; paiement simple, mixte et fractionné | V | GUEST_PAID_PDF_RECEIPT, GUEST_MIXED_AND_SPLIT_RECEIPTS |
| B2-017 | addendum | Reçu propre après table fermée, refus autre invité ou jeton expiré | V | RECEIPT_SCOPE_CLOSED_TABLE_EXPIRY |
| B2-018 | 4.1 | Routage commande cuisine, Bar, snack et sous-postes ; consolider lignes par commande | V | REAL_SUBSTATION_LABEL, SQL : SCOPED_SUBSTATION_ROUTING |
| B2-019 | 4.2 | Vérifier chaque transition reçue, acceptée, préparée, prête, remise, servie, clôturée et refus transitions illégales | P | WEB-OP : SNACK_TABLE_HANDOFF ; matrice exhaustive de transitions à établir |
| B2-020 | 4.3 | Charge, priorité et capacité des postes ; délai global non additif | V | SQL : QUEUE_CAPACITY_DELAY |
| B2-021 | 4.4 | Horodatage serveur, compte à rebours invité et poste ; cohérence et révocation | V | REAL_SUBSTATION_CLOCK_AND_REVOCATION |
| B2-022 | 4.3,4.4 | Prolongations répétées motivées, historique initial/nouveau, horloges divergentes, zéro et retard persistant | P | WEB-OP : clock ; cas limites et historique complet à vérifier |
| B2-023 | 4.5,4.6 | Confirmer servi avant/après délai, séparer événement personnel/client, excuse, feedback facultatif | P | WEB-OP : CHECKOUT_FEEDBACK, SNACK_TABLE_HANDOFF ; tous cas temporels à qualifier |
| B2-024 | 4.7 | Coupure réseau poste puis reprise sans double mutation ; accusé perdu sur paiement fractionné | V | STATION_OFFLINE_RESYNC, REAL_SPLIT_UI_LOST_ACK_RETRY, NATIVE_RETRY_IDEMPOTENCE |
| B2-025 | 4.7 | Panier invité conservé durant coupure, nouvelle tentative contrôlée, pas de confirmation locale trompeuse | P | Contrat idempotence présent ; parcours invité hors ligne dédié requis |
| B2-026 | 5.1,5.3 | Restaurant-Bar : plat et boisson vers postes dédiés ; option Bar désactivable | V | WEB-OP : commande multi-postes |
| B2-027 | 5.1,5.4 | Catalogue Bar par verre/bouteille/pack/casier, prix, ventes et indicateurs par période | P | SQL : conversions et coûts ; UI Bar exhaustive à qualifier avec B3 |
| B2-028 | 6.1,6.3 | Snack comptoir/retrait : numéro, file, appel, non-retrait et disponibilité | V | REAL_EDGE_SNACK_PICKUP, SQL : NO_SHOW_STATION_WINDOW |
| B2-029 | 6.2,6.5,addendum | Snack à table : QR, préparation, remise par serveur habilité, confirmation invité, avis ; aucune mission externe | V | SNACK_STATION_HANDOFF_UI_BOUNDARY, SNACK_TABLE_HANDOFF_AND_PERFORMANCE |
| B2-030 | 2.1 | Zones, capacités tables, réservation et refus chevauchement | V | REAL_FLOOR_PERMISSION_AND_OVERLAP, NATIVE_FLOOR_RESERVATIONS_WAITLIST |
| B2-031 | 2.1 | Accueil, ouverture réelle session, annulation, installation attente, clôture completed et persistance | V | NATIVE_FLOOR_PERSISTENCE |
| B2-032 | 2.1 | Expiration réservation, arrivée tardive, refus capacité, concurrence simultanée et reprise après incident | P | SQL : FLOOR_RESERVATION_CATALOG ; tests UI de tous cas limites à compléter |
| B2-033 | 13.1,17.2 | Attribution et révocation rôles salle, caisse, serveur, préparation et sous-postes ; refus non habilité | V | REAL_EDGE_STAFF_REVOCATION, REAL_FLOOR_PERMISSION_AND_OVERLAP |
| B2-034 | 13.1 | Matrice complète des fonctions cumulées, accès caisse/stock/achats/comptabilité/livreur/support | P | Backend rôles génériques et grants ; rôles spécialisés à qualifier |
| B2-035 | 13.3 | Avis global et par poste réellement impliqué, refus avis d'un tiers | V | REAL_EDGE_SUBSTATION_FEEDBACK, REAL_CHECKOUT_FEEDBACK |
| B2-036 | 13.3 | Note caisse/accueil, motifs précis et modération, absence de classement sur échantillon faible | P | SQL : POST_FEEDBACK, SCOPED_POST_SATISFACTION ; modération et couverture caisse à vérifier |
| B2-037 | 18.2,18.3,18.4 | Vue gérant, cuisine, Bar et caisse : données de service, priorités, délais, disponibilité et clôture | P | WEB-OP : PILOTAGE ; matrice visuelle et native B6 |

### Bulk 3 — 46 recettes

| ID | CDC | Action et résultat attendu | Statut | Preuve ou travail restant |
|---|---|---|---|---|
| B3-001 | 9.1,9.4 | Créer matières, lots, quantités et seuils ; stock et traçabilité site | V | N5_REAL_EDGE_STOCK_EXPENSE_UI, N5_LOTS_RECIPE_PRODUCTION_EXPENSE |
| B3-002 | 9.2 | Conversions exactes unités/quantités ; achat et réception convertis | V | REAL_BROWSER_CONVERTED_PURCHASE, EXACT_UNIT_CONVERSION |
| B3-003 | 9.2,5.2 | Conversion verre/bouteille/casier/pack, ouverture et reliquat ; arrondis et unités incompatibles | P | Moteur conversion présent ; scénarios bar complets à établir |
| B3-004 | 9.3,9.9 | Fournisseur, commande, réception partielle, paiement et dette | V | N5_REAL_EDGE_PROCUREMENT_UI, N5_PROCUREMENT_AND_INVENTORY |
| B3-005 | 9.9 | Achat multi-lignes atomique, plusieurs réceptions, exactitude totale | V | REAL_EDGE_MULTILINE_PURCHASE |
| B3-006 | 9.9,10.4 | Approbation achat, qualité réception, seuils, droits et rejet avant stock | V | REAL_CONTROLS_AND_SCAN, ERP_APPROVAL_AND_QUALITY_CONTROL |
| B3-007 | 9.9 | Retour fournisseur, avoir/remboursement et valorisation | V | SUPPLIER_RETURN_CREDIT_REFUND |
| B3-008 | 9.9 | Retour lot enrichi par excédent, multi-lignes, cas de litige fournisseur | P | Refus conservateur documenté ; arbitrer et qualifier |
| B3-009 | 9.9,12.4 | Relevé fournisseur groupé, conversion des achats, rapprochement sans double dette | V | REAL_BROWSER_GROUP_STATEMENT, PURCHASE_CONVERSIONS_AND_GROUP_STATEMENTS |
| B3-010 | 9.9,17.4 | Commande fournisseur par WhatsApp, bon PDF, suivi réception et statut | P | Champs fournisseur existants ; preuve envoi/documents bout en bout requise |
| B3-011 | 9.5 | Recette versionnée, consommation exacte, coût théorique et réel par portion | V | RECIPE_VERSION_HISTORY, N5_COST_OF_RECORDED_SALE |
| B3-012 | 9.6 | Production par lot, quantités et valorisation ; coût de vente | V | N5_LOTS_RECIPE_PRODUCTION_EXPENSE |
| B3-013 | 9.6 | Préparation intermédiaire convertie, conservation du coût | V | INTERMEDIATE_PREPARATION_COST_CONSERVATION |
| B3-014 | 9.7 | Braisage rendement, perte d'invendus, vente au poids | V | REAL_EDGE_WEIGHTED_PRODUCTION, WEIGHTED_BRAISING_AND_SALE |
| B3-015 | 9.4,9.6 | Péremption préparation, blocage vente et transfert, perte valorisée | V | REAL_EDGE_PREPARED_EXPIRY |
| B3-016 | 9.4 | FEFO, FIFO si applicable, traçabilité lots au niveau de toutes recettes et retours | P | Contrôles péremption présents ; matrice rotation/concurrence à compléter |
| B3-017 | 9.5 | Vente directe, réservation/consommation matière et coût exact | V | REAL_EDGE_DIRECT_SALE |
| B3-018 | 9.8 | Inventaire excédent avec demande/validation/rejet, coût et idempotence | V | REAL_EDGE_INVENTORY_GAIN |
| B3-019 | 9.8 | Inventaire négatif, pertes motifs, ajustements multi-lots, prévention double comptage | P | OFFLINE_RECEIPT_COUNT_EXPENSE ; cas complets à qualifier |
| B3-020 | 2.4 | Transfert marchandise entre sites demande/validation/en transit/réception/écart sans vente | V | N5_REAL_EDGE_TRANSFER_UI, N5_TRANSFER_LIFECYCLE |
| B3-021 | 2.4 | Transfert préparation et conservation coût, péremption et écarts | V | REAL_EDGE_PREPARED_TRANSFER |
| B3-022 | 2.4 | Transferts multi-lignes, rejets, annulation, livraison partielle, reprise simultanée | P | Moteurs présents ; parcours exhaustif non démontré |
| B3-023 | 5.2 | Consignes et bouteilles vides, mouvements et solde financier | V | N5_REAL_EDGE_CONTAINER_UI, CONTAINER_FINANCE |
| B3-024 | 10.1–10.4 | Dépense, catégorie, référence, validation, journal et garde période clôturée | V | REAL_EDGE_LEDGER, ERP_APPROVAL_AND_QUALITY_CONTROL |
| B3-025 | 10.3,17.5 | Déposer pièce privée PDF/JPEG/PNG, contrôle hash/format et téléchargement authentifié | V | REAL_EDGE_DOCUMENT, REAL_DOCUMENT_REVIEW_AUDIT |
| B3-026 | 10.4,17.5 | Revue documentaire, blocage et historique append-only | V | REAL_DOCUMENT_REVIEW_AUDIT |
| B3-027 | 17.5,19.4 | Stockage industriel, analyse antivirus réelle, rétention/purge et sauvegardes | D | Politique de stockage et moyens réels nécessaires ; revue manuelle ≠ antivirus |
| B3-028 | 11.1 | Multi-caisses et permissions, fonds ouverture, paiements mixtes et clôture | V | MULTIDESK_MIXED_RECEIPT, REAL_EDGE_MIXED_CASH |
| B3-029 | 11.2,10.4 | Sortie de caisse, retrait motivé, remboursement selon moyen d'origine et plafonds | V | CASH_OUTFLOWS_AND_ORIGINAL_METHOD_REFUND |
| B3-030 | 11.3 | Avoir commercial, retour physique, remboursement et conservation traces | V | REAL_EDGE_COMMERCIAL_NOTES_RETURNS |
| B3-031 | 11.3 | Annulations, offerts, remboursements partiels sur tous moyens, cas cumulés et contrôles concurrentiels | P | REAL_EDGE_REFUND ; scénarios exhaustifs à compléter |
| B3-032 | 11.4 | Compte ardoise, plafond, échéance, paiement partiel, solde et suivi | V | REAL_EDGE_CREDIT_UI, REAL_EDGE_CREDIT_REVISION_FOLLOWUP |
| B3-033 | 11.4,17.4 | Relances créances automatiques, canaux, historique envoi et désabonnement | P | Suivi créance présent ; délivrance réelle B4 |
| B3-034 | 12.1 | Journal équilibré, écritures multi-lignes, mapping approuvé et contrepassation | V | REAL_EDGE_LEDGER_CORRECTION, LEDGER_SPLIT_AND_REVERSAL |
| B3-035 | 12.1,12.2 | Export CSV protégé, clôture de période, balance et états de gestion | V | REAL_EDGE_LEDGER_EXPORT, REAL_EDGE_STATEMENTS |
| B3-036 | 12.3 | Distinction achat/stock/coût ventes, marge réelle, pertes et remboursements | V | N5_COST_OF_RECORDED_SALE, SCOPED_BALANCED_LEDGER |
| B3-037 | 10.4,12.1 | Rapprochement trésorerie, caisse, moyens et références | V | REAL_EDGE_TREASURY, TREASURY_RECONCILIATION |
| B3-038 | 12.2 | Règle fiscale datée, capture TTC et rapport sur données synthétiques | V | REAL_TAX_CONFIG_REPORT |
| B3-039 | 11.5,12.2,24.2 | Validation comptable et fiscale Cameroun/SYSCOHADA, plan/mappings, pièces et factures réglementaires | D | Professionnel et règles validées requis ; ne pas inventer taux |
| B3-040 | 12.4,18.5 | Consolidation multi-sites, comparatifs, filtres, export et exactitude source | P | REAL_BROWSER_GROUP_STATEMENT ; consolidation complète à qualifier |
| B3-041 | 17.3 | Offline production sur recette connue, reçu idempotent, conflit sans écriture | V | REAL_BROWSER_OFFLINE_PRODUCTION |
| B3-042 | 17.3 | Offline réception lot, comptage négatif et dépense, revue append-only | V | OFFLINE_RECEIPT_COUNT_EXPENSE, OFFLINE_EXPENSE_SUBMISSION, REAL_WEB_OFFLINE_REVIEW |
| B3-043 | 17.3 | Résolution complète des conflits, reprise après extinction, autres mutations ERP admissibles ; paiement autoritatif en ligne | P | Outbox et revue présentes ; catalogue mutations à couvrir |
| B3-044 | 9–12 | Scan code article HID, ambiguïté et accès ; scanner caméra et périphériques | P | REAL_CONTROLS_AND_SCAN ; matériel B6 |
| B3-045 | 9–12 | Parité native des opérations ERP sur achats/production/journal/pièces/offline et autres écrans | P | ANDROID_REAL_ERP_LEDGER_EVIDENCE_OFFLINE_REVIEW ; toutes actions B6 |
| B3-046 | 12.2 | Documents PDF devis/bon/réception/inventaire/états et exports par rôle | P | CSV et justificatifs prouvés ; modèles PDF et exhaustivité à qualifier |

### Bulk 4 — 36 recettes

| ID | CDC | Action et résultat attendu | Statut | Preuve ou travail restant |
|---|---|---|---|---|
| B4-001 | 3.6,23.11 | Fiche client facultative sans identifiant de connexion, commande anonyme possible | V | GUEST_LOYALTY_OPAQUE_CARD_SCOPE, CRM_REAL_EDGE_BROWSER |
| B4-002 | 3.6 | QR carte fidélité et parrainage uniques, sans donnée personnelle ; affichage natif/partage | V | NATIVE_LOYALTY_QR_DISPLAY, NATIVE_LOYALTY_QR_PERSISTENCE |
| B4-003 | 3.6 | Rattacher carte/code avec consentement avant validation, refus accès tiers | V | REAL_BROWSER_GUEST_CARD_AND_REDEMPTION |
| B4-004 | 3.6 | Un seul parrain par filleul et organisation, auto-parrainage/doublon ; revue anti-fraude | P | SQL : LOYALTY_REVERSAL_AND_CONNECTION_SETUP ; cas limites à isoler |
| B4-005 | 3.6 | Attribution points, consommation récompense et restauration suite annulation/remboursement | V | LOYALTY_REAL_REDEMPTION_AND_RESTORE |
| B4-006 | 3.6,23.11 | Première commande payée qualifiante, impayé/annulé/remboursement total non qualifiant ; historique complet | P | SQL : LOYALTY_REVERSAL_AND_CONNECTION_SETUP ; matrice première commande à compléter |
| B4-007 | 3.6,25 | Barème/nature récompense client et activation commerciale après arbitrage ; aucun mois logiciel | D | Décision promoteur requise ; pas de montant inventé |
| B4-008 | 3.6,18.1 | Indicateurs parrainage/qualification/conversion/coût avantages et filtres par site | P | Loyalty snapshot présent ; preuve consolidée exhaustive requise |
| B4-009 | 17.6,21 | Tarifs 5000/50000 et 18000/180000 FCFA, mensuel/annuel uniquement | V | SQL politique canonique et B1 ; régression sur candidat |
| B4-010 | 17.6 | Accès mono-compte, Premium multiniveau ; droits et expiration serveur | V | ACCESS_MONO_ACCOUNT, ACCESS_AND_GUEST_BOUNDARIES |
| B4-011 | 17.6,24.2 | Quotas de sites/appareils et entitlements détaillés : validation puis contrôles positifs/négatifs | D | Arbitrage requis, ne pas inventer de limites |
| B4-012 | 17.6,21 | Souscription et renouvellement réellement payés via NAXA, callback signé, montant/devise, refus rejoués | D | Contrat opérateur et environnement de test autorisés requis |
| B4-013 | 17.6 | Annuel douze mois, non-repricing périodes payées, suspension et restauration droits | P | Tests synthétiques existants ; renouvellement réel à qualifier |
| B4-014 | 17.8 | Parrainage professionnel code unique, rattachement, 4/5/10 filleuls, mois/extension cadence et idempotence | P | referral_claim et politique famille ; preuves ZIPPLE complètes à établir |
| B4-015 | 17.8 | Premier paiement réel, rejet essai/pending/renouvellement, entitlement appliqué avant crédit | D | Dépend du contrat paiement et preuve réelle |
| B4-016 | 7.1,7.8 | Livraison désactivée par défaut, Restaurant seul ; pas de mission/frais coursier Snack-Bar | V | Mode et contrôles local ; SNACK_TABLE_HANDOFF |
| B4-017 | 7.1,7.3 | Configurer zones et frais, état actif et permissions | P | REAL_BROWSER_LOYALTY_DELIVERY_CONNECTIONS ; configuration seule |
| B4-018 | 7.2,7.4 | Générer QR livraison de zone, menu public, panier, commande sans compte et contact minimal | A | Construire/raccorder parcours livraison public réel |
| B4-019 | 7.3 | Autorisation GPS et saisie manuelle si refus, validation serveur zone et refus hors zone | A | Raccorder NAXA, tester précision et données minimales |
| B4-020 | 7.3,7.5 | Tarif/frais livraison visibles et comptabilisés, horodatage, annulation et historique | A | Raccorder devis, commande, caisse et journal B3 |
| B4-021 | 7.7 | Paiement NAXA livraison, confirmation authentique, idempotence commande/paiement et remboursement | D | Contrat opérateur sandbox requis |
| B4-022 | 7.5,7.6 | Assigner livreur, accepter mission, préparation, prise en charge, en route, remise et clôture | A | Interface livreur et cycle opérationnel à construire/qualifier |
| B4-023 | 7.6 | Droits livreur limités à missions assignées, réaffectation/révocation et preuve de remise | A | Recettes négatives et bout en bout |
| B4-024 | 7.3,7.5 | Routage/ETA réel, incidents livraison et politique rétention contact/GPS | D | Contrat NAXA et politique de conservation |
| B4-025 | 14.1–14.3 | Demande raccordement NAXA SECURITY, établissements, équipements et validation | P | Connection workspace présent ; pas de flux réel |
| B4-026 | 14.2,23.9 | Flux vidéo réel autorisé sur appareil compatible, sélection caméra et disponibilité | D | Contrat et caméra de test nécessaires |
| B4-027 | 14.4,23.9 | Refus rôle/organisation, expiration/révocation jeton, absence flux QR public, journal consultation | D | Tester contrat vidéo réel, pas une demande de connexion |
| B4-028 | 24.2,FAM-023 | NAXA HOTEL : liaison hôtel/site/folio, consentement et validation avant imputation, absence doublon | D | Contrat réciproque réel requis |
| B4-029 | 24.2 | GRILLAD Connect : droits Premium et accord bilatéral, QR deux espaces, commandes/paiements séparés | D | Blocage GRILLAD V1.3 et accord technique à résoudre |
| B4-030 | 16.3 | Assistance invité liée à commande ; réponse staff et isolation autre commande | V | ORDER_SUPPORT_ISOLATION, REAL_STAFF_SUPPORT_UI |
| B4-031 | 16.1 | Ticket professionnel catégorie, priorité, pièces, historique, statut et satisfaction | P | Workspace ticket prouvé ; toutes options/agent central à qualifier |
| B4-032 | 16.1,16.2 | FAQ, guides, livechat automatisé, transfert humain avec contexte et clôture | A | Réutiliser support famille ; parcours central réel absent/non prouvé |
| B4-033 | 16.2,17.4 | WhatsApp Business officiel, consentement et livraison du message | D | Canal officiel et identifiants requis |
| B4-034 | 17.4 | Notifications internes, préférences, rappel et lecture | P | Workspace notifications existant ; matrice événements à couvrir |
| B4-035 | 17.4 | Push FCM réel, tokens révoqués, notification arrière-plan, absence fuite intersite | D | Configuration/test appareil et service autorisés |
| B4-036 | 17.4,17.5 | Partage reçu/bon/relance via canaux autorisés avec garde de confidentialité | P | PDF local prouvé ; transmission effective et historique à qualifier |

### Bulk 5 — 29 recettes

| ID | CDC | Action et résultat attendu | Statut | Preuve ou travail restant |
|---|---|---|---|---|
| B5-001 | 13.2 | Dossier employé, onboarding, affectation site/poste, historique et compétences | P | Workspace équipe/RH présent ; dossier exhaustif à qualifier |
| B5-002 | 13.2 | Pointage GPS avec scope, preuve début/fin, idempotence et pauses | V | REAL_BROWSER_ATTENDANCE, ATTENDANCE_GPS_SCOPE_IDEMPOTENCE, HR_APPROVAL_AND_GPS_BREAK |
| B5-003 | 13.2 | Planning shifts, chevauchements, jours fériés/retards, approbations et affectations multi-sites | P | Planning présent ; règles et parcours limites à qualifier |
| B5-004 | 13.2 | Demande congé et décision, rôle et persistance | V | REAL_BROWSER_HR_APPROVAL, NATIVE_WORKSPACE_PERSISTENCE |
| B5-005 | 13.2 | Absences, retards, corrections justificatifs, confidentialité et historique | P | HR workspace présent ; matrice complète non démontrée |
| B5-006 | 13.2 | Objectifs individuels/équipe, suivi jour/semaine/mois et comparaison cible | P | Workspace objectifs existant ; preuve chiffrée exhaustive requise |
| B5-007 | 13.2 | Primes, commissions, avances, paie et rapprochement comptable avec validations | A | Implémenter/raccorder modèle famille, aucun calcul réglementaire inventé |
| B5-008 | 13.6 | Formation, compétences attendues/actuelles, progression JOBLY et validation manager | P | Workspace formation présent ; parcours complet à qualifier |
| B5-009 | 13.4 | Incident/feedback interne distinct de l'avis public, action corrective, responsable, échéance et clôture | P | Workspace incidents présent ; cycle et droits complets à qualifier |
| B5-010 | 13.3,13.5 | Note et volume par poste, feedback limité à postes impliqués | V | REAL_POST_SATISFACTION_UI, SCOPED_POST_SATISFACTION |
| B5-011 | 13.5 | Satisfaction, délai, exactitude, retards et tendances ; filtres service/jour/semaine/mois/site | P | Indicateurs existants ; exhaustivité/échantillon faible à tester |
| B5-012 | 13.5 | Modération données personnelles, rattachement individuel fiable, aucune sanction automatique | P | Contrôle humain exigé ; tests explicites à établir |
| B5-013 | 2.3,18.1,18.5 | Compte mère, CA/marge/trésorerie/dettes/stock/retards et comparatifs sans mutation source | P | N7_REAL_EDGE_PILOTAGE_UI ; consolidations et toutes sources à qualifier |
| B5-014 | 18.2–18.4 | Vue gérant, cuisine/Bar, caisse et performance ; période/scope/source | P | Pilotage présent ; matrice des KPI et exactitude par rôle |
| B5-015 | 15.1 | Demand Intelligence : prévisions ventes, affluence, saison, besoin par site et mesure d'erreur | P | Moteur analytique existant ; prévisions robustes et backtest requis |
| B5-016 | 15.1 | Stock Intelligence : rupture, réapprovisionnement, dormant, péremption et justification | P | Données stocks présentes ; moteur/recommandations à qualifier |
| B5-017 | 15.1 | Recipe Intelligence : coût portion, rendement, impact variation fournisseur | P | Coûts réels prouvés ; simulations et explication à qualifier |
| B5-018 | 15.1 | Pricing Intelligence : prix sous coût, marge, simulation, validation humaine | P | Politique manuelle ; test suggestion et absence mutation automatique |
| B5-019 | 15.1 | Waste Intelligence : invendus, pertes récurrentes et quantité à produire | P | Données pertes présentes ; prévision et validation à qualifier |
| B5-020 | 15.1 | Fraude/anomalies : annulation, remboursement, offert, écart caisse, surconsommation, doublon | P | Contrôles métier présents ; détection explicable et faux positifs à qualifier |
| B5-021 | 15.1 | Workforce Intelligence : demande personnel, périodes de pointe, suggestion planning et délai | P | Données RH présentes ; moteur spécifique et garde humaine |
| B5-022 | 15.1 | Feedback Intelligence : motifs, synthèse, causes récurrentes, recommandation | P | Agrégats poste présents ; synthèse et traçabilité à qualifier |
| B5-023 | 15.1 | OCR facture/bon, préremplissage stock/dépense, rapprochement achat/réception et correction humaine | A | Implémenter OCR réel, tester document illisible et validation |
| B5-024 | 15.1 | Business Companion écrit FR/EN, questions multi-sites, période/sources et données manquantes | A | Assistant conversationnel réel à intégrer |
| B5-025 | 15.1 | Business Companion vocal FR/EN, transcription, accessibilité, confidentialité | A | Interface et service vocal à qualifier |
| B5-026 | 15.2 | Briefing matin : veille, stocks, achats, réservations, échéances et retours | P | Pilotage existant ; briefing complet et déclenchement à qualifier |
| B5-027 | 15.2 | Briefing soir : CA, trésorerie, écarts, coûts, pertes et actions du lendemain, consolidé | P | Pilotage existant ; briefing complet à qualifier |
| B5-028 | 15.3 | IA explicable, données/hypothèses, distinction exact/estimé, absence données → indisponible | P | Règles CDC ; tests négatifs systématiques nécessaires |
| B5-029 | 15.3 | Aucune décision sensible automatique ni fuite PII/paiement, fonctionnement métier sans IA | P | Garde métier existante ; tests IA dédiés et contrôle prestataire |

### Bulk 6 — 31 recettes

| ID | CDC | Action et résultat attendu | Statut | Preuve ou travail restant |
|---|---|---|---|---|
| B6-001 | 1.2,20 | Compilation Web, Android et socle API sur candidat be60227 | V | SOCLE 46028484878 SUCCESS |
| B6-002 | 1.2,20 | APK debug pointant endpoint hébergé, compilation et artefact | V | APK 46028484799 tentative 2 SUCCESS ; pas recette métier hébergée |
| B6-003 | 23 | Recette intégrée locale Web opérations sur GoTrue/Edge/PostgreSQL | V | WEB-OP 1/1 sans skip |
| B6-004 | 23 | Recette intégrée locale Web espaces professionnels et invité | V | WEB-WS 1/1 sans skip |
| B6-005 | 23 | Recette intégrée locale Android API35, vraie DB, caisse, salles et QR | V | NATIVE 1/1 sans skip |
| B6-006 | 23 | Matrice SQL/contrats isolés et permissions | V | SQL 46/46 sans skip |
| B6-007 | 1.2,20 | Inventaire exhaustif routes, pages, champs, boutons, états vides/chargement/erreur, liens et retour | P | Workspaces et parcours intégrés ; générer matrice route × action × rôle |
| B6-008 | 1.2,20 | Parité Android/Web/PWA pour toutes actions professionnelles B2–B5, y compris dialogues et exports | P | Native core prouvé ; matrice exhaustive par action nécessaire |
| B6-009 | 20 | Responsive mobile bas de gamme, tablette et desktop ; navigation clavier et gros boutons | P | Build/recettes navigateur prouvés ; tailles et accessibilité à qualifier |
| B6-010 | 20 | Charte #0E224D/#F56202, logo, mode clair/sombre, contraste 4,5:1 et plein soleil | P | Charte CDC ; mesures UI réelles et logo fourni à contrôler |
| B6-011 | 20 | FR/EN : chaque texte, validation, erreur, reçu, dates et notifications | P | PROFILE_LANGUAGE_APPLIED ; traduction exhaustive à auditer |
| B6-012 | 20 | Fulfulde/Fufuldé si exigence famille confirmée pour ZIPPLE : traductions validées, police et reçus | P | Décision portefeuille ; confirmer portée ZIPPLE et validation linguistique |
| B6-013 | 1.2,17.3 | PWA installable, mise à jour service worker, cache privé, logout et reprise hors réseau | P | Ancienne qualification PWA verte ; requalifier candidat final |
| B6-014 | 1.2,20 | Chromium/Firefox/WebKit sur matrice complète invité/pro et mobile ; navigateurs faibles débits | P | PWA antérieure ; E2E actuel Chromium, autres moteurs à qualifier |
| B6-015 | 3.1,20 | Imprimer QR physique, lecture caméra depuis téléphone bas de gamme, faible luminosité et rotation | D | Équipement réel requis |
| B6-016 | 3.6,20 | Scanner fidélité/code article caméra, permissions refusées, partage et enregistrement SAF réels | D | Appareil physique et fichiers de test nécessaires |
| B6-017 | 17.1,17.7 | Session, PIN, biométrie, Keystore, révocation, recovery admin/MFA, isolation token et réinstallation | P | SOCLE vert ; parcourir compte hébergé et appareil réel |
| B6-018 | 19.2 | Matrice RLS/RPC complète : anon, authenticated, service-role, cross-org/site, accès QR et rôle révoqué | P | SQL ALL_RPC_AND_TABLE_GRANTS ; requalifier toutes nouvelles API |
| B6-019 | 19.3 | Audit avant/après, acteur, validateur, motif, horodatage et impossibilité suppression sur chaque mutation | P | Registres partiels existants ; cartographie action × audit |
| B6-020 | 19.4 | Politique confidentialité/CGU, minimisation, rétention, purge et demandes des personnes | D | Politiques et obligations validées ; tests de suppression/archivage |
| B6-021 | 17.7 | Observabilité : erreurs corrélées, alertes, redaction secrets/PII, journaux CI | P | Diagnostics CI présents ; monitoring hébergé à qualifier |
| B6-022 | 17.7 | Tests de charge/concurrence : QR, dernière portion, caisse, offline, connexions simultanées et quotas techniques | P | Cas dernière portion prouvé ; objectifs capacité à définir et mesurer |
| B6-023 | 17.3 | Réseau lent/coupure, redémarrage application, double clic/rejeu, conflits, horloge, persistance | P | Outbox et ACK perdu prouvés ; matrice tous modules et appareils |
| B6-024 | 17.7 | Sauvegarde et restauration sur environnement de recette, objectifs RPO/RTO, reprise incident sans perte | D | Autorisation environnement et objectifs requis |
| B6-025 | 17.7 | Analyse dépendances, verrouillage versions, signature, permissions Android, absence secrets frontend | P | Build et garde existants ; revue finale et SBOM à établir |
| B6-026 | 19.3,24.2 | Provisionner backend métier hébergé isolé, appliquer migrations validées, grants, rollback testé | D | Autorisation explicite et environnement de recette requis |
| B6-027 | 1.2,23 | Recette positive métier hébergée sur comptes de test, vrai navigateur + APK + PostgreSQL | D | Backend candidat hébergé et comptes de test requis |
| B6-028 | 1.2,20 | Qualification Cloudflare Pages ZIPPLE, URL QR canonique, TLS, CSP et PWA sur candidat déployé | D | Déploiement recette autorisé requis ; Pages live ancien ≠ nouveau candidat |
| B6-029 | 1.2,20 | APK signé de distribution, installation/upgrade physique, permissions, publication et procédure rollback | D | Signature et autorisation de distribution requises |
| B6-030 | 25 | Compatibilité famille NAXA, régression applications sœurs, aucune modification main implicite | P | Contrats partagés ; matrice non-régression inter-apps à exécuter |
| B6-031 | 23,25 | Recette intégrée finale multi-sites avec intégrations réelles, preuves archivées, validation utilisateur et décision de mise en production | D | Dépend des réserves B3–B6 ; aucun déploiement sans accord |

## Inventaire technique des actions exposées (hors décompte fonctionnel)

Extraction des allowlists `professionalActions` / `publicActions` de `n2-n5/business-gateway.mjs` au SHA audité : **169 actions professionnelles + 11 actions publiques = 180 actions distinctes**. Ce décompte concerne le gateway métier, pas les sous-actions `*_write`, RPC internes, endpoints N1, interfaces externes non raccordées ni actions UI. Il sert de checklist technique complémentaire, non additionnée aux recettes. Pour chaque action: positif, type/valeur invalide, rôle/scope, état illégal, doublon/rejeu si mutation, erreur réseau, preuve DB et journal si applicable. Pour chaque interface: vérifier action visible et exécutable selon droits, état de chargement/erreur, absence de fuite. Les sous-actions des workspaces doivent être dépliées au moment de la matrice B6-007/B6-008.

### Professionnelles (169)

- `attendance_record`
- `attendance_snapshot`
- `bill_transfer`
- `braise_discard`
- `braise_measure`
- `braise_snapshot`
- `call_number`
- `cancel`
- `capacity_set`
- `capacity_snapshot`
- `cash_close`
- `cash_desk_add`
- `cash_desk_open`
- `cash_desks_snapshot`
- `cash_open`
- `cash_outflow_record`
- `cash_outflows_snapshot`
- `cash_record`
- `cash_record_mixed`
- `catalog_base_set`
- `catalog_channels`
- `catalog_rules`
- `catalog_update`
- `category_set`
- `commercial_snapshot`
- `connection_snapshot`
- `connection_write`
- `container_account`
- `container_finance_record`
- `container_move`
- `container_snapshot`
- `conversion_add`
- `count_lot`
- `credit_account_add`
- `credit_authorize`
- `credit_collect`
- `credit_followup`
- `credit_limit_revise`
- `credit_note_record`
- `credit_snapshot`
- `crm_snapshot`
- `customer_add`
- `customer_attach`
- `delay`
- `direct_sale_set`
- `direct_sale_snapshot`
- `erp_control_set`
- `erp_control_snapshot`
- `erp_review_discard`
- `erp_review_snapshot`
- `erp_snapshot`
- `expense_apply`
- `expense_decide`
- `expense_record`
- `expense_submit`
- `finance_document_add`
- `finance_document_read`
- `finance_document_review`
- `finance_documents_snapshot`
- `floor_snapshot`
- `followup_complete`
- `followup_create`
- `formula_define`
- `formula_groups_define`
- `formula_snapshot`
- `group_pay`
- `hr_snapshot`
- `hr_write`
- `ingredient_add`
- `intermediate_convert`
- `intermediate_snapshot`
- `inventory_gain_decide`
- `inventory_gain_request`
- `inventory_gain_snapshot`
- `ledger_account_add`
- `ledger_classify`
- `ledger_close`
- `ledger_correct`
- `ledger_group_statement`
- `ledger_mapping_set`
- `ledger_mapping_snapshot`
- `ledger_post`
- `ledger_post_mapped`
- `ledger_post_split`
- `ledger_snapshot`
- `ledger_statement`
- `line_advance`
- `lot_receive`
- `lot_receive_converted`
- `loyalty_snapshot`
- `loyalty_write`
- `menu_add`
- `mode`
- `no_show`
- `offline_erp_apply`
- `operational_grant`
- `order_create`
- `order_priority`
- `order_support_reply`
- `order_support_snapshot`
- `pickup_create`
- `pilotage`
- `preparation_expiry_discard`
- `preparation_expiry_set`
- `preparation_expiry_snapshot`
- `prepared_transfer_decide`
- `prepared_transfer_dispatch`
- `prepared_transfer_receive`
- `prepared_transfer_request`
- `prepared_transfer_snapshot`
- `price_schedule`
- `procurement_snapshot`
- `produce`
- `purchase_batch_create`
- `purchase_conversion_snapshot`
- `purchase_create`
- `purchase_create_converted`
- `purchase_decide`
- `purchase_receive`
- `purchase_receive_checked`
- `purchase_receive_converted`
- `quote`
- `recipe_define`
- `recipe_revise`
- `referral_claim`
- `reservation_transition`
- `reserve_table`
- `sale_return_record`
- `snapshot`
- `split_collect`
- `split_snapshot`
- `station_availability`
- `station_grant`
- `station_limit`
- `station_snapshot`
- `station_window`
- `substation_assign`
- `substation_configure`
- `substation_grant`
- `substation_snapshot`
- `supplier_add`
- `supplier_pay`
- `supplier_refund`
- `supplier_return`
- `supplier_return_snapshot`
- `table_bill`
- `table_close`
- `table_config`
- `table_create`
- `table_open`
- `table_rotate_qr`
- `tax_report`
- `tax_rule_set`
- `tax_snapshot`
- `transfer_decide`
- `transfer_dispatch`
- `transfer_receive`
- `transfer_request`
- `transfer_snapshot`
- `treasury_reconcile`
- `treasury_snapshot`
- `waitlist_add`
- `waitlist_transition`
- `weighted_produce`
- `weighted_rule_set`
- `weighted_snapshot`
- `workspace_snapshot`
- `workspace_write`
- `zone_add`

### Publiques (11)

- `guest_feedback`
- `guest_loyalty_attach`
- `guest_menu`
- `guest_open`
- `guest_order_create`
- `guest_order_read`
- `guest_post_feedback`
- `guest_receipt`
- `guest_served`
- `guest_support_create`
- `guest_support_read`

## Règle d'exécution en bulk

Lancer les lots indépendants en parallèle sans fail-fast, conserver B2 en régression. Chaque réserve P/A/D reçoit un responsable technique, preuve de fermeture (commit, run, job, test/assertion, artefact), date et état final. Ne jamais convertir P/A/D en V par simple compilation ou présence de code. B3 traite ERP/finance, B4 raccordements et commerce, B5 RH/IA, B6 matrice transversale et livraison; les validations externes sont explicites. Les recettes dont les conditions ne sont pas disponibles restent bloquées, pas ignorées. Le passage au vert global exige toutes les lignes applicables prouvées, arbitrages tracés et gates finaux réussis.
