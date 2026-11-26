# BOOTIK — Document de continuité V1.1

> **Date de référence :** 21 novembre 2026  
> **Statut :** décisions métier structurantes validées ; spécification V1.1 figée pour la conception ; implémentation non attestée par ce document.  
> **Document associé :** [Cahier des charges BOOTIK V1.1](BOOTIK_CAHIER_DES_CHARGES_V1.1.md)  
> **Historique :** le cahier historique `7 famille naxa/01-cahiers-des-charges/02-bootik.md` (V1.0 du 31 octobre 2026) est conservé comme source historique. La présente V1.1 le complète et le remplace pour les arbitrages contradictoires ; elle n'autorise aucune suppression de fonctionnalité métier déjà validée sans décision expresse.

## 1. Règle de continuité et priorité des sources

BOOTIK est une application de la Famille NAXA. Pour toute reprise :

1. Le présent document fixe les décisions de continuité BOOTIK.
2. Le cahier BOOTIK V1.1 fixe le périmètre fonctionnel et les critères d'acceptation.
3. Les décisions explicites prises par le propriétaire du projet le 21 novembre 2026 prévalent sur les anciennes hypothèses divergentes.
4. Le cahier historique V1.0, les prompts historiques et les autres documents Famille NAXA restent consultables pour identifier les fonctionnalités à préserver ; ils ne réactivent pas un tarif ou un profil supprimé par une décision récente.
5. Une capacité décrite comme cible, exigence ou critère n'est pas réputée codée, testée, déployée ou opérationnelle sans preuve technique.

Les statuts documentaires sont : **[V] validé**, **[P] proposition**, **[O] ouvert**, **[C] constaté**, **[B] bloqué**. Les fonctionnalités métier approuvées ne sont pas renégociées implicitement pendant le développement.

## 2. Décisions figées au 21 novembre 2026

### 2.1 Deux univers métier

- **Détaillants :** première priorité de construction.
- **Distributeurs :** deuxième phase, mais le modèle de données, les contrats, les identifiants, les catalogues, les stocks, les tiers, la facturation, les droits et les APIs doivent être compatibles dès la conception initiale.
- Un même produit BOOTIK présente deux univers séparés. Les parcours, menus, règles commerciales, tableaux de bord, rôles et droits ne sont pas fusionnés.
- Le socle technique partagé ne justifie jamais de fusionner les caisses, stocks, dettes, marges, journaux ou comptes entre activités, sites ou organisations.

### 2.2 Les 14 profils Détaillants

1. Boutique
2. Supérette
3. Poissonnerie
4. Boulangerie
5. Shopping — vêtements, chaussures, sacs, bijoux et accessoires de mode
6. Alimentation
7. Cave
8. Quincaillerie
9. Parfumerie
10. Boucherie
11. Ferme
12. Dépôt de gaz
13. Supermarché
14. Brocante

La Brocante est un profil validé. Elle gère les articles uniques ou d'occasion, leur état, provenance, photos, estimation, prix négociable, historique et vente. Un article unique ne peut pas être vendu en quantité supérieure à son stock disponible.

Le profil historique « petite pharmacie informelle » n'est pas un 15e profil V1.1 : il reste un élément historique [O], non activé dans le catalogue V1.1 sans décision et validation de conformité distinctes. BOOTIK ne remplace pas NAXA Pharmacie.

### 2.3 Profils Distributeurs

Huit profils sont retenus :
1. Boissons et brasseries.
2. Gaz et énergie domestique.
3. Produits alimentaires de grande consommation.
4. Produits frais, réfrigérés et surgelés.
5. Hygiène et entretien domestique.
6. Beauté et soins personnels.
7. Importateurs et distributeurs de marques.
8. Agro-intrants et alimentation animale.

Un distributeur peut exercer plusieurs activités, mais chaque activité garde son catalogue, ses lots, unités, règles de stockage, autorisations documentaires, tarifs, marges et indicateurs.

### 2.4 Tarifs confirmés — mensuels et annuels

| Univers | ACCÈS | PREMIUM |
|---|---:|---:|
| Détaillants | 4 000 FCFA/mois | 10 000 FCFA/mois |
| Distributeurs | 10 000 FCFA/mois | 25 000 FCFA/mois |

- Seules les périodicités mensuelle et annuelle sont autorisées (décision du 26 novembre 2026).
- Le palier Pro générique est supprimé et ne doit pas réapparaître dans les écrans, données de référence, rapports, tests ou textes commerciaux BOOTIK.
- ACCÈS conserve l'ensemble des fonctions métier essentielles, dont l'ERP et le CRM complet pour les Distributeurs.
- PREMIUM ajoute des capacités avancées de dimensionnement, d'organisation multiniveau, de consolidation, de contrôle et d'automatisation ; il ne déverrouille pas artificiellement les opérations fondamentales.
- Une souscription Promoteur couvre l'organisation et son réseau de sites du même univers ; ne pas facturer mécaniquement chaque caisse, dépôt ou boutique comme un abonnement indépendant.
- Essai initial : 72 heures d'utilisation gratuite sans paiement préalable, à compter de l'activation serveur, pour la formule choisie ; non réinitialisable par réinstallation ou recréation locale du compte. À expiration, paiement confirmé requis pour poursuivre les opérations payantes ; données conservées.
- Annuel : 12 mois au prix de 10, soit 16,67 % de ristourne. Durées 3 et 6 mois supprimées et refusées par le contrat BOOTIK.
- L'IA opérationnelle est incluse dans l'abonnement ; pas de facturation par requête.
- La confirmation, l'activation des droits et la réconciliation passent par le circuit canonique de paiement NAXA/KIOSKO après qualification réelle de son état. Un écran ou une référence saisie ne vaut pas confirmation de paiement.

### 2.5 Grille tarifaire applicable

| Univers / formule | Mensuel | Annuel |
|---|---:|---:|
| Détaillants ACCÈS | 4 000 | 40 000 |
| Détaillants PREMIUM | 10 000 | 100 000 |
| Distributeurs ACCÈS | 10 000 | 100 000 |
| Distributeurs PREMIUM | 25 000 | 250 000 |

Montants en FCFA. Le contrat BOOTIK valide exclusivement 1 ou 12 mois avant appel au moteur commun ; les autres solutions restent inchangées.

## 3. Interconnexion Détaillants ↔ Distributeurs : décision structurante

L'extension de l'écosystème par activité est une exigence V1.1, pas un simple lien WhatsApp.

- BOOTIK maintient un référentiel de métiers/secteurs et une matrice de compatibilité entre chaque profil Détaillant, les familles d'articles qu'il achète et les profils Distributeurs capables de le servir.
- Le rapprochement prend aussi en compte la zone desservie, la gamme réellement disponible, les conditions commerciales, la capacité logistique, le statut du distributeur et les éventuelles restrictions.
- Le détaillant peut demander une connexion, accepter une invitation ou utiliser un annuaire de partenaires qualifiés. Le distributeur accepte ou refuse la relation. Aucun partage de portefeuille client n'est implicite.
- Un détaillant peut travailler avec plusieurs distributeurs compatibles ; il peut désigner un distributeur préféré par famille de produits. Aucune exclusivité commerciale n'est imposée par BOOTIK.
- Une connexion active permet un catalogue B2B autorisé, des prix contractuels visibles par le seul détaillant concerné, des disponibilités, des commandes, des confirmations, des factures, des livraisons, des retours et un historique.
- Les données du détaillant restent dans son tenant ; le distributeur ne voit que les données partagées nécessaires à la relation, à ses commandes et à son recouvrement.
- Les références d'un même produit peuvent être rapprochées par GTIN/code-barres ou par correspondance contrôlée. Ne jamais fusionner automatiquement deux fiches qui se ressemblent.

### 3.1 Réapprovisionnement et validation humaine

Le comportement cible est le suivant :

1. Un seuil, une prévision ou une rupture imminente déclenche une alerte de stock.
2. Le moteur propose une quantité fondée sur les ventes, le stock disponible, les réservations, les commandes ouvertes, le délai fournisseur, le stock de sécurité, les unités/conditionnements et le minimum de commande.
3. Selon une règle activée par le Promoteur, BOOTIK crée soit un brouillon à valider par le détaillant, soit une demande/commande préremplie transmise automatiquement au distributeur préféré dans l'état **En attente de validation du distributeur**.
4. **La validation humaine du distributeur est obligatoire** avant acceptation commerciale définitive, réservation ferme et préparation.
5. Toute modification de prix, quantité, substitution, frais ou date par le distributeur exige l'acceptation du détaillant avant de devenir définitive.
6. L'acceptation, le refus, la proposition alternative, la réception partielle, la réception complète et le litige sont journalisés.
7. Une clé d'idempotence empêche une même alerte de créer plusieurs commandes identiques.
8. Les paramètres d'automatisation sont bornés : produits admissibles, distributeur cible, quantités maximales, montant maximum, fréquence, créneau, plafond de crédit et règles d'arrêt.
9. Sans connexion réseau, l'application prépare la demande localement et la met en file ; elle ne prétend pas qu'elle a été transmise ou acceptée.

Ce mécanisme automatise la préparation et, sur opt-in explicite, la transmission d'une demande soumise à validation humaine ; il n'autorise jamais une IA ou un seuil de stock à engager seul un achat ferme.

## 4. Fonctionnalités à préserver sans régression

Tous les éléments ci-dessous restent dans le périmètre BOOTIK ; leur présence dans V1.0 impose de les couvrir dans la nouvelle recette.

### Détaillants
- Caisse multi-caisses et multi-sites, sessions, fonds initiaux, entrées/sorties, clôtures, écarts, annulations et remboursements tracés.
- Ventes espèces, Mobile Money, carte/TPE, virement, crédit client et paiement mixte ; acomptes, retours, avoirs, devis, factures, reçus, impression Bluetooth et partage préparé WhatsApp.
- Prix détail/gros, listes de prix, remises conditionnelles et validations.
- Catalogue, catégories, marques, SKU, codes-barres, variantes, unités et conversions, coût d'achat, coût moyen pondéré, lots et péremptions.
- Import Excel/CSV, export, modèles par profil, inventaires par scan, pertes/casse, ajustements, transferts entre sites et traçabilité des mouvements.
- Emplacements physiques hiérarchiques, recherche d'emplacement.
- Ardoise, plafonds, acomptes, paiements partiels, échéances, relances ; registre séparé des dettes fournisseurs.
- CRM, historique, fidélité, points, QR client, parrainage client et roue promotionnelle plafonnée et auditée.
- Fournisseurs, comparatifs, commandes, réception partielle/complète, facture fournisseur par photo/OCR si disponible, dette et paiements partiels.
- Dépenses, charges récurrentes, justificatifs, trésorerie, résultat de gestion, journaux et exports.
- Personnel, rôles, commissions, salaires/avances/primes si activés, présence, objectifs et audit.
- Multi-boutiques, stock consolidé et transferts acceptés par le site receveur.
- Dépôt de gaz : pleines/vides, marque, capacité, consigne, caution, retours, défauts, livraison, détenteur et propriétaire.
- Mobile Money accessoire séparé de la caisse de marchandises.
- Fonctionnement hors connexion, synchronisation idempotente, notifications et messages WhatsApp préparés.
- Assistance IA explicable, qui propose sans réaliser d'action sensible à la place d'un humain.

### Distributeurs
- ERP complet : achats, fournisseurs, importations, entrepôts, inventaires, lots, coût de revient, ventes B2B, prix, factures, encaissements, crédit, retours, livraisons, véhicules, commerciaux, territoires et comptabilité de gestion.
- CRM B2B complet : comptes détaillants, contacts, qualification, segmentation, interactions, visites, prospects, opportunités, portefeuille commercial, relances, réclamations, contrats, historique des commandes et recouvrement.
- Réseau de détaillants connectés et commandes issues des alertes de stock.
- Traçabilité de bouteilles consignées, emballages, palettes, fûts, produits frais, produits importés et produits soumis à des justificatifs.

## 5. Socle technique et règles d'architecture

- Conserver l'isolation par application, organisation, activité, site, dépôt, caisse, utilisateur et relation B2B.
- Une fonction partagée est un service technique ; elle ne doit pas fusionner les règles métier.
- Prévoir la structure Distributeur dès la première modélisation Détaillant : références d'organisation, profils, unités, catalogue, lots, sites, tiers, listes de prix, mouvements de stock, commandes et événements auditables doivent être extensibles.
- Architecture Android native Kotlin + Jetpack Compose pour l'application Android ; les expériences Web/PWA, si retenues, sont séparées et reposent sur des APIs/contrats partagés, pas sur une conversion automatique du code Kotlin.
- Le développement doit respecter l'architecture et les conventions réelles du monorepo après inspection ; ne pas inventer de packages ou tables réputés existants.
- Base locale persistante pour les opérations hors connexion ; synchronisation par événements avec identifiants stables, idempotence, reprise et gestion explicite des conflits.
- Les commandes B2B nécessitant une réponse du distributeur sont des opérations réseau : un brouillon local peut être créé hors ligne, mais aucun statut « transmis », « accepté » ou « livré » n'est affiché sans accusé réel.
- RLS, contrôles serveur, moindre privilège, validation des permissions à chaque opération sensible et tests d'isolation inter-tenant obligatoires.
- Aucun secret, OTP, PIN, mot de passe, clé privée, identifiant client réel ou donnée personnelle réelle dans le dépôt public.
- Aucune clé service_role dans le client.
- Les SMS entrants existants, lorsqu'ils sont autorisés et pertinents, ne constituent qu'une source de rapprochement contrôlée. Un message contenant un OTP ou un PIN est ignoré ; aucun PIN/OTP n'est lu, conservé, transmis ou affiché. Les alternatives manuelles et le circuit de paiement canonique restent disponibles.
- NAXA SECURITY est le module/service propriétaire de la vidéosurveillance et des alertes ; BOOTIK ne fournit ni caméra, ni matériel, ni service humain de surveillance.
- KIOSKO demeure le produit spécialisé Mobile Money. Le module Mobile Money accessoire de BOOTIK est un registre de suivi et de rapprochement ; il ne devient pas un opérateur de paiement ni un détenteur de fonds de tiers.
- Les sauvegardes doivent être chiffrées, indépendantes de la base opérationnelle, vérifiées et restaurables sur un environnement isolé. Ne pas revendiquer la continuité de service avant preuve de restauration.

## 6. UX, langues et charte

- Charte BOOTIK : bleu nuit **#052163**, orange **#FC7820** ; les thèmes clair/sombre et la programmation horaire sont prévus.
- Français, anglais et Fulfulde (locale **ff-CM**) ; les textes réglementaires et traductions sensibles doivent être vérifiés humainement.
- Mobile-first, lisible sur téléphones d'entrée de gamme, écrans clés atteignables en trois actions au plus lorsque possible, boutons lisibles et contrastes d'accessibilité.
- États toujours exprimés par un libellé et un repère visuel, pas par une couleur seule.
- Montants FCFA formatés de manière cohérente ; calculs exacts au franc, arrondis explicités pour la facturation.
- Aucun libellé métier important n'est codé en dur ; les ressources de langue sont centralisées.

## 7. Ordre de construction retenu

1. **Fondations Détaillants et modèle extensible Distributeurs** : tenant, activités, sites, profils, identités, rôles, catalogue de référence, audit, offline/sync, sauvegarde, billing/entitlements.
2. **Catalogue, stock et caisse Détaillants** : import contrôlé, localisation, unités, variantes, ventes, moyens de paiement, sessions, clôtures, reçus, retours.
3. **Achats, fournisseurs, clients, CRM et finances** : ardoise, dettes, commandes, dépenses, fidélité, rapports.
4. **Spécificités des 14 profils** : tests dédiés à chaque métier ; ne pas afficher un formulaire universel.
5. **Pilotage, IA, notifications et intégrations** : tableaux de bord, exports, FCM, WhatsApp préparé, support, NAXA SECURITY, Mobile Money accessoire.
6. **Univers Distributeurs complet** : ERP, CRM, achats/import, entrepôts, commerciaux, commandes B2B, livraison, recouvrement et pilotage.
7. **Réseau métier et commandes intelligentes** : compatibilité, annuaire, demandes de connexion, tarifs, alertes, auto-préparation, validation distributeur, livraison et rapprochement.
8. **Qualification globale** : tests métier, multi-sites, multi-caisses, offline, sécurité/RLS, sauvegarde-restauration, billing, paiement, matériels compatibles et migration de données.

## 8. Méthode de travail et définition du statut VERT

Chaque étape doit suivre strictement : **audit → contradictions → cause racine → correction → tests/preuves → documentation → état**.

Une étape n'est VERT que si :
- les parcours nominaux et les cas d'erreur passent ;
- les permissions et RLS sont démontrées ;
- l'isolation inter-organisation et inter-activité est testée ;
- les opérations hors connexion et la synchronisation sont vérifiées ;
- les conflits, doublons et reprises après échec sont testés ;
- les calculs financiers et les états de caisse sont rapprochés ;
- les exports et pièces jointes sont contrôlés ;
- la sauvegarde et la restauration ont été exécutées avec preuve ;
- la documentation correspond au code livré.

**État documentaire au 21 novembre 2026 :** périmètre fonctionnel et arbitrages de prix/profils validés dans cette V1.1. Ce document et le cahier associé ne prouvent pas que les modules BOOTIK sont implémentés. Les migrations, écrans, APIs, tests et services réels restent à auditer et à construire selon le plan de livraison.

## 9. Points à traiter sans bloquer le périmètre métier

- Construire et valider la matrice de compatibilité détaillant ↔ distributeur, en particulier pour les profils sans équivalent direct évident (Brocante, Quincaillerie, Ferme, Boulangerie).
- Finaliser les seuils par défaut, limites d'auto-soumission et stratégies de demande selon les paramètres du client ; les valeurs sont configurables et ne sont pas hardcodées.
- Valider par un professionnel les états SYSCOHADA, la TVA et les obligations propres aux secteurs concernés avant de les qualifier de déclaratifs/certifiés.
- Vérifier les règles, autorisations, certificats et contraintes de conservation par produit et territoire ; BOOTIK conserve les pièces et les échéances mais ne remplace pas les autorisations des autorités.
- Qualifier la disponibilité effective des paiements, webhooks et entitlements du socle partagé avant d'annoncer une activation automatique opérationnelle.
- Définir le traitement commercial d'une organisation qui exploiterait simultanément les deux univers sous un même compte de facturation ; ne pas inventer un tarif combiné.

## 10. Instruction de reprise

À chaque nouvelle session de travail BOOTIK :

1. Lire ce document et le cahier V1.1 en entier.
2. Auditer les fichiers et l'état du dépôt, sans supposer que les exigences sont déjà réalisées.
3. Consulter les tests et preuves de l'étape précédente.
4. Reprendre au premier point non terminé, sans recommencer un contrôle déjà vert sauf si une modification l'invalide.
5. Ne pas réduire le périmètre validé pour accélérer une livraison.
6. Ne pas modifier la branche principale, ne pas déployer, ne pas appliquer de migration à un environnement partagé et ne pas publier d'APK sans autorisation explicite du propriétaire du projet.


## 11. Compléments de non-régression intégrés au cahier V1.1

Les exigences historiques suivantes ont été conservées ou adaptées au nouveau périmètre :
- Registre des appareils autorisés par organisation/site/caisse, notification au Promoteur lors d'un nouvel appareil et révocation/déconnexion à distance ; le plafond doit rester configurable pour ne pas bloquer les scénarios multi-caisses.
- Rapprochement distinct des espèces et des encaissements Mobile Money marchand.
- Mini-catalogue partageable, avec sélection explicite des articles et des informations publiables ; aucune donnée de coût, marge ou client n'est exposée.
- Recherche locale fluide sur au moins 5 000 fiches et scan code-barres hors connexion dans la recette de référence.
- Les autres fonctionnalités historiques identifiées dans la section 4 du présent document restent couvertes par les critères de non-régression du cahier des charges.


## 12. État d'implantation — première tranche (22 novembre 2026)

La première tranche du socle Détaillants a été préparée dans la branche :

`feat/bootik-retail-foundation-mainline-2026-11-22`

Elle comprend :
- le namespace Android autonome `cm.naxa.bootik` ;
- l'écran initial BOOTIK Détaillants, avec nom d'organisation, premier site et sélection des 14 profils ;
- les identifiants métier stables des 14 profils Détaillants et des 8 profils Distributeurs réservés à la phase suivante ;
- le stockage local Room `bootik-local.db` et les brouillons organisation/activité/site, non synchronisés ;
- une outbox locale dédiée `bk_offline_events` ;
- les ressources de langue françaises et anglaises ;
- un contrat de domaine qui interdit la confirmation d'une commande B2B sans validation humaine du distributeur, et exige l'accord du détaillant si le distributeur a modifié les conditions ;
- un draft SQL isolé sous le schéma `bootik`, objets `bk_*`, avec RLS activé/forcé et aucun grant/policy client ;
- un contrat de recette anti-collision et un audit dédié.

**Limites à conserver explicitement :** aucun compte ou abonnement serveur n'est créé par l'écran initial ; aucune synchronisation distante, caisse, vente, import Excel, CRM complet, achat, paiement, reporting ni vertical métier n'est déclaré livré dans cette tranche. Le draft SQL n'est appliqué ni à Replay ni à Production. Les tests JUnit/Compose/PostgreSQL sont écrits mais leur exécution n'est pas encore prouvée.

Rapports de tranche :
- [Audit anti-collision BOOTIK / NAXA SERVICES / NAXA](audits/AUDIT_ANTI_COLLISION_BOOTIK_NAXA_SERVICES_NAXA_2026-11-22.md)
- [État d'implantation tranche 1](audits/BOOTIK_IMPLANTATION_TRANCHE_1_2026-11-22.md)

La branche de travail a été créée depuis le HEAD courant de `main` observé pendant cette passe, afin d'intégrer la continuité NAXA SERVICES la plus récente sans écrire dans ses fichiers. La branche n'est pas fusionnée dans `main`.


## N0 — 26 novembre 2026
Branche de reprise work/bootik-n0-20261126. Voir [audit N0](audits/BOOTIK_N0_20261126.md). Backend Famille vérifié en lecture seule, aucun objet BOOTIK hébergé. Ancien draft non applicable en l'état. Audit PARTIEL : JOBLY inaccessible et qualification runtime en attente. Aucun déploiement, aucune modification NAXA/NS/ZIPPLE.

### Reprise N0 — qualification
Draft BOOTIK autonome sans famille_core, recette PostgreSQL éphémère, CI Android/Web et inventaire JOBLY par ZIP en lecture seule ajoutés. Politique 1/12 mois testée par contrat candidat. Aucun résultat CI revendiqué avant lecture des runs. Aucun déploiement.

### Recette N0 — correction Android
Run 45834117940 : contrats 6/6 et PostgreSQL 17 PASS, Web build SUCCESS, JOBLY inventaire 788 fichiers SUCCESS. Android échec mergeDebugResources : six ressources FR contenant des apostrophes ASCII non échappées. Correction systématique des valeurs de chaînes FR, EN vérifié sans apostrophes non échappées. Relance CI ; aucune validation Android revendiquée avant résultat. JOBLY inventaire distinct de qualification du code. Aucun déploiement.

### N0 — correction résolution Compose tests
Run 45835804979 : ressources XML désormais compilées, contrats/PostgreSQL, Web et inventaire JOBLY SUCCESS. Job Android échoue sur checkDebugAndroidTestAarMetadata : Could not find androidx.compose.ui:ui-test-junit4:. Cause : BOM Compose absent de la configuration androidTestImplementation. Correction locale BOOTIK alignée sur ZIPPLE (BOM 2024.10.01), sans changer les versions ni les packages communs. Nouvelle CI requise ; pas de statut vert avant résultat.

### Lot transverse N0–N10 — 26 novembre
CI N0 45837071003 SUCCESS 4/4 ; tests instrumentés compilés, pas exécutés sur émulateur ; JOBLY inventaire 788 fichiers, qualification code ouverte. Commits 8f9b810a et 0a5ec47b : coffre Keystore et PIN ZIPPLE adaptés, session Web et IndexedDB isolés, référentiel 22 profils et 14 espaces, devis Kotlin/Web, interface responsive connexion et offres, SW isolé, contrat candidat accès Security/support. Aucune API BOOTIK configurée par défaut ; aucun accès métier ni droit payant simulé. Les modules restent en construction. Vidéosurveillance et support RTC séparés ; vidéo bidirectionnelle à implémenter et tester, consentement explicite. Aucun déploiement.

### Bulk opérations serveur — 26 novembre
Run 45840646356 4/4 SUCCESS. Ajout candidat SQL isolé : adhésions et droits par site, registre essai par organisation/univers, devis, vente unitaire atomique avec déduction stock et mouvement idempotent, demande support avec consentement. Recette rollback stock, répétition, survente, site étranger, consentement, tarifs. Fonctions invoker sans droits clients ; appel réservé à un futur adaptateur serveur authentifié, prix fourni encore non canonique et droits abonnement non raccordés. Aucun paiement, flux RTC, migration hébergée ni parcours client opérationnel revendiqué. CI requise.
