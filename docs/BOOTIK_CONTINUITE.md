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

### Bulk droits et prix — 26 novembre
Run 45841440818 4/4 SUCCESS. Contrats SQL renforcés : essai unique 72 h par organisation/univers sans reset, registre périodes payées et idempotence référence prestataire, contrôle des droits et prix canonique avant vente, annulation demande média. Tests négatifs et positifs dans operations.sql. Fonction paiement réservée au serveur de confiance après confirmation prestataire (aucune intégration prestataire effective). Pas de déploiement ni de droit client direct. CI à vérifier.

### Correction CI contrats 45843955223
Erreur SQL ligne 63 : délimiteurs dollar-quote réduits à un seul dollar par remplacement JavaScript. Correction des huit délimiteurs et cohérence temporelle de l'activation d'essai dans la transaction PostgreSQL (now()). Web et inventaire réussis, Android encore en cours au constat. Nouvelle recette requise.


## Point de reprise consolidé — 26 novembre 2026

**Ce point prévaut sur les anciens statuts contradictoires.** Dernier commit de code qualifié : `9808152678676462357b538579242061715d2529`. Branche exclusive : `work/bootik-n0-20261126`. [Recette 45844215281](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45844215281) terminée SUCCESS, 4/4 jobs (android, contracts, web, jobly-inventory). Journaux : 8 tests JavaScript réussis, 0 échec ; PostgreSQL 17 : BOOTIK_N0_DRAFT_ISOLATION_PASS et BOOTIK_BULK_OPERATIONS_PASS, transaction de test annulée (ROLLBACK). APK debug et APK de tests instrumentés compilés ; tests unitaires Android exécutés ; **pas d'exécution instrumentée sur émulateur attestée**. Web : build réussi, pas de recette navigateur E2E attestée. JOBLY : inventaire 788 fichiers, pas d'audit exhaustif du contenu. Correction des huit délimiteurs SQL et horloge transactionnelle de l'essai validées. Aucun déploiement ni application du draft au Supabase hébergé.

### Tableau de vérité N0–N12

| Niveau | Réalisé et prouvé | Reste à terminer | Statut |
|---|---|---|---|
| N0 | CI isolée, schéma BOOTIK privé, inventaire JOBLY, identité visuelle | audit approfondi JOBLY et qualification runtime | CI verte, qualification partielle |
| N1 | Session Web, coffre Keystore/PIN Android, membres et droits site SQL, interfaces initiales | serveur d'authentification, login Android/Web réel, récupération, révocation, biométrie, navigation, synchronisation | jaune |
| N2 | Tarifs 1/12 mois, essai 72 h non réinitialisable par organisation/univers, périodes payées idempotentes et droit SQL testé | API prestataire paiement réelle, admin central, activation et contrôle des droits sur toutes les opérations | jaune |
| N3 | Schéma catalogue, unités, lots, stock ; contrôles SQL lors de vente | CRUD, import Excel, codes-barres, inventaire, transferts, réapprovisionnement et UI | jaune |
| N4 | Vente SQL unitaire atomique, prix canonique, déduction et journal stock, idempotence | panier multiligne, caisse multi-opérateurs, encaissements saisis, reçus, annulations/retours, clôtures, API et UI | jaune |
| N5 | Modèles clients, fournisseurs et journal stock | achats, dettes, crédit client, fidélité, dépenses, comptabilité, rapprochements, relances | jaune |
| N6 | Référentiel 14 profils Détaillants, brouillons locaux Android | parcours spécifiques et recettes complètes des 14 profils en parallèle | jaune |
| N7 | Espaces équipe et IA référencés | RH, pointage, objectifs, rapports, IA opérationnelle | jaune |
| N8 | Référentiel 8 profils Distributeurs, modèles métiers | dépôts, commerciaux/livreurs, territoires, commandes, recouvrement, parcours complets | jaune |
| N9 | Modèles liens B2B, compatibilité et approbation | accès et conditions privées, zone/gamme, approbations serveur, commandes, réapprovisionnement opt-in, tests E2E | jaune |
| N10 | Contrats demande média, contrôle site, consentement et annulation SQL | NAXA SECURITY réel (vidéosurveillance, caméras, alertes, incidents, journal, pointage, multisite), support distinct (tickets, livechat, audio, visioconférence bidirectionnelle, partage écran consentement révocable), flux et notifications réels | jaune |
| N11 | CI 4/4, tests contrats et PostgreSQL | émulateur Android, E2E navigateur, tests API réels, offline/reprise/conflits, sécurité intertenant et parcours 22 profils | jaune |
| N12 | Pas de livraison production revendiquée | qualification complète, APK release, PWA, déploiement et recette finale selon autorisations | non clôturé |

### Prochain lot obligatoire : Android et Web intégralement en bulk

Dernière demande du propriétaire : terminer Android et Web entièrement, pas seulement compiler. Les interventions postérieures au commit de correction n'ont produit aucun nouveau commit : reprendre exactement au code qualifié ci-dessus, ne pas considérer les annonces de travaux comme des implémentations. Android MainActivity affiche encore le parcours de brouillon local ; Web main.tsx présente l'interface initiale, devis et connexion conditionnée à VITE_BOOTIK_API_URL. Les clients ne sont pas raccordés aux opérations métier réelles. Les contrats SQL privés SECURITY INVOKER n'ont aucun droit direct anon/authenticated ; construire un adaptateur serveur authentifié qui dérive l'identité du jeton vérifié, contrôle organisation/site/activité/rôle et droits, ne fait jamais confiance aux identifiants fournis par le client, et ne transmet aucun secret privilégié aux clients. Pas de simulation de réussite ni de paiement.

- Traiter en parallèle authentification, autorisations, abonnement, navigation, ERP, les 22 profils, offline avec idempotence et reçus validés, NAXA SECURITY et support, FR/EN et langues validées par le cahier des charges. Réutiliser après audit les composants ZIPPLE, NAXA SERVICES, NAXA et JOBLY ; ne jamais modifier leurs domaines ou données. Vidéosurveillance et visioconférence distinctes : aucune activation implicite de caméra, micro ou écran ; droits, consentement, révocation et expiration des sessions.
- Conserver les règles métier V1.1 : ACCÈS/PREMIUM seuls, mensualité et annuel 12 pour 10, essai 72 h sans prépaiement ; encaissements métier hors API prestataire, confirmation réelle requise pour abonnement ; priorité Détaillants, architecture Distributeurs compatible, pas de réactivation pharmacie.
- Méthode imposée : traiter les N en bulk, corriger les causes racines des échecs simultanément, lancer recettes et lire les journaux, enregistrer les preuves et mettre ce document à jour. Fractionnement technique des écritures Git permis uniquement pour contourner les limites du connecteur, pas de découpage fonctionnel imposé. Ne pas s'arrêter à un audit lorsque des modifications réalisables restent ouvertes. Vert uniquement pour une capacité réellement implémentée et testée ; distinguer CI verte de vert fonctionnel global.
- Garde-fous : branche BOOTIK exclusive, pas de fusion main ni déploiement BOOTIK non autorisé ; aucun changement NAXA/NS/ZIPPLE/JOBLY, aucun changement de données réelles ; drafts PostgreSQL en CI isolée avant qualification des migrations hébergées. 

### BULK 01 — raccordements clients et service candidat
Commits 37ba37f6 (Android login/récupération, site, droits/essai, demandes média), 4fcb3c12 (Web mêmes contrats + annulation demande), 63081e7f (serveur Node, identifiants scrypt, jetons hachés expirables, droits dérivés de session, accès PostgreSQL dédié, adaptateur catalogue/vente/droits/support). Nouveau test réel PostgreSQL avec rôle runtime distinct, refus accès tiers, prix/stock, expiration/révocation, consentement ; recette Android émulateur ajoutée. Serveur HTTP local derrière futur proxy TLS, aucun endpoint hébergé configuré. Paiement réel, création/récupération complète comptes, biométrie/PIN branchés, offline intégral, administration et flux Security réels restent ouverts. Aucun déploiement. CI nouvelle à confirmer.


## BULK 01 — consolidation de la passe de développement

Branche BOOTIK exclusive : work/bootik-n0-20261126. Dernier code de qualification : 0d5344bdbff0e99a6108e7999feecb4b862c65d0. Les composants suivants ont été réellement enregistrés :
- Android et Web : écrans de connexion, récupération (enregistrement de la demande), sélection site, consultation droits, essai 72 h, demandes Security/support et révocation. Serveur Node privé : authentification interne scrypt, jetons opaques hachés, expiration, contrôle de portée, opérations catalogue/vente et abonnements. Tests PostgreSQL sur rôle runtime dédié.
- Android : PIN personnel avec Keystore, verrouillage local, biométrie optionnelle, renouvellement des jetons de reprise avec rotation, coffre session ; Web session en mémoire.
- Paiement abonnement : adaptation du modèle NAXA, intention canonique MTN/Orange, preuve déclarée débit, preuve crédit indépendante par appareil marchand enrôlé, réconciliation via rôle PostgreSQL séparé, contrôle de référence/montant/destination/fenêtre temporelle, idempotence. Interfaces Android/Web, aucun PIN ni OTP financier demandé, SMS brut non persisté ni transmis ; preuve client structurée, pas une validation financière autonome. Test de rapprochement simulé sur PostgreSQL réel. Les téléphones marchands, destinations officielles et captures SMS réelles ne sont pas configurés.
- Offline : cache catalogue par organisation/membre/site, file ventes Room v2 (migration conservant les tables historiques) et IndexedDB v2, accusé serveur contrôlé par application/organisation/membre/site/événement, conflit bloquant et abandon explicite. Stock et vente confirmés seulement après accusé. Les autres opérations et la connexion totalement hors ligne restent ouvertes.
- CI : 45848402511 et 45848888347 SUCCESS 5/5 (dont émulateur). 45849759060 SUCCESS 5/5 avec backend paiement et interfaces ventes/paiement, contrats PostgreSQL et tests instrumentés. Un échec transitoire Maven 429 a motivé le passage aux APK compilés en amont (2b23fbda), sans réduction des tests. Dernière recette étendue 45850316735 ajoute Chromium avec API/HTTPS de test et PostgreSQL réel, persistance de file, paiement, support et test IndexedDB. Ne pas assimiler un job en cours à un résultat vert.
- Administration centrale : la console existante ZIPPLE a été auditée ; la tentative d'enregistrement du raccordement BOOTIK a été bloquée par le contrôle de sécurité du connecteur. Aucun commit d'administration n'a été enregistré. Provisionnement de comptes, résolution des demandes et intégration centrale restent ouverts. Ne pas contourner le contrôle.
- Aucun déploiement, aucune migration Supabase hébergée, aucune configuration réelle d'API/compte marchand, aucun changement des autres applications. Les flux vidéo/RTC réels relèvent du BULK 04 ; les demandes et consentements sont raccordés, pas le média en direct.

Point de vérité : socle testé en environnement isolé, mais BULK 01 fonctionnel intégral non clôturé. Prochaines preuves nécessaires : terminer la recette Chromium/émulateur sur le dernier code, qualifier l'administration centrale via un canal autorisé, intégration avec l'environnement hébergé BOOTIK isolé et réception des preuves opérateur sur téléphones autorisés, puis recettes positives/négatives Android et Web réelles. Ne pas relancer les travaux déjà prouvés sans régression constatée.


## Directive permanente de construction — validée le 26 novembre 2026

Le cahier des charges BOOTIK V1.1 est la source de vérité fonctionnelle. Avant chaque lot, auditer les modules effectivement codés de NAXA SERVICES, NAXA, JOBLY et ZIPPLE, et les packages communs. Ne pas réimplémenter un module compatible ; réutiliser directement un composant générique ou adapter le composant métier dans le périmètre BOOTIK. Le cahier prévaut en cas de divergence ; aucune réduction de périmètre implicite.

| Référence | Modules à auditer et réutiliser | Contraintes |
|---|---|---|
| NAXA SERVICES | Multi-activité, multisite, équipes, PIN, caisse, facturation, stock, fournisseurs, CRM, objectifs, notifications, IA | Adapter les droits aux univers détaillant/distributeur ; aucun accès ns_* |
| NAXA | Catalogue, lots, stock, caisse, comptabilité, paiement abonnement à double preuve, support RTC, caméras | Pas de pharmacie BOOTIK, pas de partage de données historiques ; distinguer vidéosurveillance et assistance |
| JOBLY | Administration, gestion des comptes, abonnements, assistance, onboarding, UX | Inventaire de l'archive effectué, audit détaillé à poursuivre ; ne pas revendiquer une réutilisation sans preuve source |
| ZIPPLE | Authentification, Keystore, reprise de session, file offline, reçus, WorkManager, PWA, recette navigateur, administration centrale | Adapter noms d'application, scopes et identifiants ; ne jamais écrire dans les tables zp_* |
| Packages communs | core-android, core-kotlin, contracts, core-web, offline-web, billing-core, design-system, assistant | Réutiliser sans modifier les autres consommateurs ; ne pas reprendre les durées offline 7/14 jours sans validation |

Références auditées : NAXA SERVICES branche work/naxa-services-completion-20261120 commit 86e0948509008dc12429983c3cbf9155c4860220 ; NAXA main 4acbab129b403ef87e879c87e99793fb9d35e98f (architecture paiement et composants cités plus haut) ; ZIPPLE et packages présents dans l'arbre BOOTIK cb812e83 ; JOBLY inventaire 788 fichiers, non audit exhaustif. Composants vérifiés : ZippleSyncWorker.kt, NotificationChannels.kt, BriefingScheduler.kt, NotificationContract.kt, SyncContract.kt. Le scheduler commun ne suffit pas à garantir la confidentialité du briefing après déconnexion : n'utiliser que des messages génériques ou un contrôle de session. 

Procédure obligatoire de chaque passe bulk : matrice exigence V1.1 → référence source et commit → adaptation BOOTIK Android/Web/backend → tests positifs/négatifs et intertenant → correction des logs → mise à jour de continuité. Les 14 profils Détaillants sont prioritaires, les 8 Distributeurs restent prévus. Ne pas fusionner les activités, les sites, les caisses ni les stocks. Tarifs et essais validés inchangés. Ne pas confondre CI verte et disponibilité réelle ; aucun accès ou paiement simulé ne doit être affiché confirmé.

### Point de reprise vérifié

Commit cb812e83a971ff56ad3a81ee87e3a3a11ada4101 : recette 45852191947 SUCCESS (5/5). B01-01 recette Chromium corrigée et validée, B01-04 PIN/Keystore testé sur émulateur (biométrie physique non attestée), B01-09 affichage équipe et expiration session implémentés, renouvellement des intentions de paiement corrigé sur Android/Web. Les tests isolés ne prouvent pas la réception opérateur ni les flux en production. B01-02/03 administration centrale et cycle complet de création/récupération restent ouverts (précédente tentative bloquée par contrôle de sécurité, à traiter uniquement par canal autorisé), B01-05/06 paiements réels nécessitent environnement marchand, B01-07 backend hébergé non raccordé, B01-08 offline au-delà des ventes, B01-09 droits fins par activité/poste et gestion multisite complète, B01-10 recette de livraison. Aucune modification des autres applications, aucune fusion main, aucun déploiement BOOTIK non autorisé. Continuer en adaptant d'abord les briques éprouvées au lieu de redévelopper le socle.


### Application de la directive : reprise réseau et synchronisation

Commits 78c44f29 et 079497a2 : adaptation de ZippleSyncWorker au DAO Room et aux reçus BOOTIK existants, sans modifier ZIPPLE ni les packages communs. WorkManager avec contrainte réseau, backoff, UUID de liaison de session uniquement dans les données de tâche, jetons en mémoire ; activation automatique facultative par utilisateur, arrêt au verrouillage/déconnexion/changement de portée/expiration et refus d'une tâche issue d'une ancienne session. Mutex partagé par synchronisations manuelle et automatique, conflits conservés, état Room observable. Web : reprise réseau opt-in et relance périodique si file en attente, contrôle de portée et verrou de synchronisation, arrêt sur conflit. Recettes ajoutées : changement de portée/opt-out sur émulateur et scénario Chromium de remise en réseau avec contrôle du stock réel de la base de test. Dernier code 079497a22a06518cbe83b714eb62b3c003fe28d2 ; recette étendue à vérifier. B01-08 reste ouvert pour les mouvements, réceptions et inventaires et la politique d'expiration offline configurable. Aucun changement d'environnement hébergé.


### BULK 01 — extension offline aux stocks (B01-08)

Le run 45853065895 sur 079497a2 est SUCCESS 5/5, y compris Chromium et émulateur ; ne pas reconstruire le worker ni la vente offline validés. Reprise NAXA : migrations historiques 192 (réception atomique), 194 (inventaire transactionnel), 206 (ajustement contrôlé) auditées, adaptées au périmètre BOOTIK par 861a5fec. Les événements réception physique d'un stock existant, perte et comptage utilisent un identifiant stable, un motif, la version serveur du stock et un reçu immuable. Transaction : contrôle rôle promoteur/manager, site, activité, abonnement, verrou stock, quantités réservées/endommagées, état du lot à la réception ; doublon exact idempotent, modification concurrente refusée. Les articles sérialisés sont refusés tant que leur parcours individuel n'est pas disponible. Le comptage sans écart produit un reçu sans mouvement nul. Aucun lien fictif vers commande fournisseur ni clôture d'inventaire multi-lignes : ces parcours relèvent du BULK 02.

ec7aec6a : mêmes événements en file Room/IndexedDB existante, réutilisation du transport et des workers, reçus typés stock/vente et isolés, formulaire motif, lecture du stock physique et conflits sans écrasement. Recette Chromium ajoutée en réseau coupé puis reprise, test SQL sur vrais stocks de fixture, tests négatifs rôle, portée et reçu. Aucun nouveau système de file, aucune réécriture des parcours verts, aucune migration hébergée. CI nouvelle en cours au moment de l'enregistrement ; résultat à confirmer.

B01-08 reste partiel : réception et comptage par référence réalisés en candidat ; réception adossée à commande, inventaires groupés/validation, autres mouvements, politique offline configurable, autorisations fines restent ouverts. B01-02/03 blocage de sécurité du connecteur antérieur non contourné ; B01-05/06/07 environnements réels toujours non qualifiés.


### B01-09 — restriction par activité (candidat, 26 novembre)
Source auditée : NAXA SERVICES, `supabase/functions/naxa-services-auth/scope_contract.ts` et `docs/naxa-services/hosted-migrations/20261126080317_naxa_services_strict_site_management_scope.sql`. Adaptation du principe non-élargissement : une affectation site restreinte exige une activité explicitement attribuée ; absence d'attribution = aucun catalogue ni mouvement. Les anciennes affectations site entier conservent leur portée. Contrôles SQL avant lecture de reçus de vente/stock, filtrage catalogue serveur, rejet des mutations hors portée, révocation effective côté serveur. Rôle runtime lecture seule des affectations ; aucun accès client direct. Recette PostgreSQL étendue : restriction vide, autorisation explicite, révocation, rejeu idempotent et stock inchangé. CI à confirmer. Restent : administration des affectations, droits poste/caisse, portée des autres modules, invalidation des caches offline et environnement hébergé. Aucun changement NAXA/NS, aucune migration hébergée ni fusion.


### BULK 02 — catalogue et tiers, premier raccordement (26 novembre)
B01-09 : run 45859721051 SUCCESS. Reprise NAXA SERVICES : `apps/web/naxa-services/src/erp/inventory.ts` (normalisation nom/SKU/unité), `shared-operations.tsx` (fiche fournisseur et état confirmé), `supabase/functions/naxa-services-accounting/accounting_contract.ts` (seules ventes confirmées dans le CA). Adaptation BOOTIK : activités autorisées, création atomique d'article standard à stock nul (article/unité/solde/prix), création client/fournisseur et consultation par activité, reçu de création idempotent et audité, indicateur serveur ventes unitaires du jour Africa/Douala, interfaces Android/Web avec reçu serveur. Aucun paiement ni mouvement de stock inventé. Tests API étendus : doublon identique, conflit, stock nul, restriction activité, staff interdit, CA réel. CI à confirmer. Restent notamment profils spécialisés/lots/sérialisation, édition/import Excel, caisses/sessions/panier, achats/réceptions/dettes, CRM avancé, comptabilité, autres gates B01 et déploiement. Aucun changement des autres produits ou de Supabase hébergé.


### BULK STOCK — catalogue, lots initiaux, emplacements et capacité (candidat)
Run 45861608160 5/5 SUCCESS avant cette passe. Références effectivement lues : NAXA `src/lib/importStock.ts`, migrations 057 FEFO, 191 emplacements, 194 inventaires, 207 transferts ; NAXA SERVICES `erp/inventory.ts`, `accounting_contract.ts`. Adaptation de la normalisation de recherche, lot initial avec contrôle de date, emplacement initial, seuil et cible en table existante, quantité initiale nulle. Catalogue BOOTIK paginé par UUID, cache complet uniquement après toutes pages, recherche accent-insensible par nom/SKU/barcode/lot/emplacement/activité et pages de 100 sur Android/Web ; les 100 premières ne constituent plus une limite de données. Disponibilité exclut les lots bloqués/périmés et les articles sérialisés non qualifiés ; vente/mouvement fractionnaire d'unités discrètes refusés. Test SQL 5103 références et test JS 5100, lot et emplacement, droits et fraction. CI nouvelle à vérifier. Limites explicites : pagination non transactionnelle entre appels, lecture code-barres saisie mais scanner caméra non raccordé, seuils sans notifications, lot initial seulement, FEFO automatique multi-lots, import Excel, inventaire collectif, transferts, coûts, achats, WMS et verticales 22 profils non clôturés. Aucun déploiement ni migration hébergée ; aucune modification des sources NAXA/NS.


### BULK STOCK — inventaires groupés et transferts (candidat)
Adaptation NAXA migrations 194 et 207 : comptage par lot de 1–30 lignes même activité/site, atomique, validation des versions et quantités via le moteur BOOTIK existant, rejet d'un événement réutilisé, reçu de groupe et rollback si une seule ligne est invalide. Transfert expédition et réception distinctes, stock en transit = quantité expédiée moins reçue ; destination créditée seulement par réception autorisée, partielle ou complète, lot identique, pas de mélange de site/activité/organisation, reçus idempotents, écritures stock séparées. UI Android et Web branchées au serveur, aucune confirmation hors réseau de ces opérations. Tests PostgreSQL : rollback, rejeu, droits réceptionnaire, réception partielle, dépassement interdit, conservation quantité. Limites : inventaires de grande taille/sessions durables et scanner, litige/annulation, valorisation transfert et emplacement destination avancé, opérations groupées hors ligne, autres profils métier et WMS encore ouverts. CI à confirmer ; aucune modification des autres solutions ni environnement hébergé.


### BULK STOCK — import de démarrage CSV par 22 profils (candidat)
Réutilisation du principe de normalisation de NAXA `src/lib/importStock.ts`, sans rapprochement flou ni ambiguïté des nombres. Modèles CSV par activité, colonnes spécifiques 14+8, analyse stricte et aperçu par ligne, doublons fichier/base, confirmation atomique de 1–30 créations, reçu de groupe idempotent, stock initial par mouvement opening (jamais écrasement), données spécifiques stockées dans attributes, articles uniques Brocante bloqués pour l'entrée de stock tant que parcours dédié absent. Web téléchargement/upload et Android document picker/éditeur, serveur partagé. Aucun prétendu import XLSX natif ni mise à jour/annulation compensatoire. Le CSV est ouvrable dans Excel ; fichier limité à 10 000 caractères. Tests 22 modèles, parseur et API PostgreSQL. Corrections du comptage : ambiguïté SQL x corrigée par 1dbcb477, recette à vérifier. Restent XLSX multi-feuilles, imports volumineux, édition, sérialisation complète, conversions, FEFO automatique, achats et coût, notifications, métiers 22 profils et WMS.


### BULK STOCK — FEFO et unités de vente (candidat)
Adaptation du moteur NAXA migration 057 sans dupliquer la mutation de vente BOOTIK : allocation automatique multi-lots par péremption, lignes verrouillées, stock débité atomiquement, refus d'une vente directe sur un lot plus tardif, reçu de groupe idempotent, annulation transactionnelle si insuffisant. Configuration de lots supplémentaires avec métadonnées et solde initial nul ; unité de vente immuable et facteur vers unité de base, configuration globale seulement si périmètre tous sites de l'activité. Android/Web : sélection unité et file offline existante pour vente groupée, reçu typé sync-item-sale. Tests PostgreSQL de FEFO, rollback, rejeu, facteur et refus inter-site. Limites : conversions achat/stock, exceptions FEFO autorisées, coût historique, sérialisation, scanner, workflows métiers spécifiques et production encore ouverts. CI à confirmer.


### BULK STOCK — coût moyen et état des alertes (candidat)
Adaptation NAXA 217 (coût historique figé), NAXA SERVICES accounting_contract.ts (coût moyen pondéré). Coût de réception déclaré facultatif, calcul par solde au serveur, valeurs inconnues explicitement nulles, mouvement sans coût entrant rend la valorisation indéterminée ; coût de vente et marge figés, transfert conserve coût source et pondère réception. Interface manager Android/Web, pas de fuite coût catalogue staff. Indicateurs agrégés par article/site, seuil minimum, quantité de réassort, lots à échéance 30 jours ou bloqués, valeur si tous soldes connus. Tests reçus coût, rejeu, changement coût, coût figé et permissions. Ce n'est pas encore un journal comptable achat/dette ni notification push, politique de coût global et export final restent à qualifier. CI à vérifier.


### BULK STOCK — recette élargie des parcours réels
Les runs 45862449979 (catalogue) et 45862708785 (inventaire/transfert corrigé) et 45862991550 (CSV) sont SUCCESS 5/5. Correction SQL alias x validée, ne pas relancer l'ancien échec. Ajout d'un scénario Chromium de création CSV, recherche offline, création deuxième lot, réception valorisée, vente FEFO offline, inventaire groupé, indicateurs, changement de site et réception de transfert. Ajout Room instrumenté cache 5100 fiches, recherche code-barres et contrôle reçu de groupe. CI du code final à confirmer. Aucun test caméra ni parcours physique réel revendiqué.


### Reprise après recette consolidée
Valorisation 45863520967 et FEFO 45863295045 : SUCCESS 5/5. Recette 45863709732 : 4/5, échec Chromium à la sélection de l'activité par libellé accessible. Correction des noms accessibles explicites des listes métier et nouvelle recette ; ne pas masquer le test.


### BULK ACHATS — raccordement NAXA SERVICES (candidat)
Réutilisation des parcours StockOperationsPage (commande, réception, règlement) et du contrat de valorisation comptable déjà adapté ; aucune réécriture du moteur stock. Commande mono-référence en unité de base, fournisseur de même activité, solde de site autorisé, réception partielle atomique avec mouvement et frais attribuables, coût pondéré, dette créée seulement à réception (hors frais de tiers), règlement externe partiel journalisé, sur-réception/sur-paiement refusés, reçus idempotents, aucun transfert financier. UI Android/Web et tests API réels. Reste commandes multi-lignes, avances, avoirs, litiges, échéances, pièces jointes, WhatsApp, B2B et journaux comptables complets. CI à confirmer. Aucun déploiement ni modification d'autres solutions.


### Achats — recette UI et durcissement
La réception fournisseur crée un UUID de mouvement serveur distinct, afin de ne jamais rattacher un événement manuel préexistant. Le reçu de mutation reste confirmé même si le rafraîchissement de la liste échoue. Extension Chromium : fournisseur, commande, réception partielle avec frais, dette et règlement. CI à confirmer.


### BULK CAISSE — reprise des contrats NAXA SERVICES (candidat)
Sources auditées : CashOperationsPage et ns_open_cash_session/ns_close_cash_session/ns_record_expense de naxa_services_v4_supplier_accounting_forecast.sql. Caisses par activité/site, une session ouverte par caisse, ouverture avec fonds, panier jusqu'à 20 références (unité de base), réutilisation bk_sell_item/FEFO sans moteur parallèle, transaction atomique avec espèces et monnaie rendue, entrées/sorties/dépenses justifiées, clôture manager avec écart et motif, reçus idempotents, droits et RLS privés. Web/Android raccordés, tests API sur reprise, stock, montant insuffisant, solde, écart et session close. Vente stock historique non rattachée conservée mais ne doit pas être comptée en espèces. Restent caisse offline, modes non espèces et mixte, postes, clients/crédit, retours, documents PDF/thermique et migration des anciens flux, journaux comptables complets. Pas de production ni changement autres apps. CI à confirmer.


### Caisse — durcissement et recette UI
Verrou d'ouverture par caisse (sans élargir les droits d'UPDATE sur les registres), validation stricte des identifiants de reçus côté Android/Web, tests de panier avec seconde ligne invalide et doublon (rollback total), recette Chromium de caisse, panier deux articles, espèces, mouvement, clôture et écart. Les runs stock 45864871421 5/5 et achats 45865240235 contrats PostgreSQL/Chromium et compilations réussis à la dernière vérification ; CI caisse finale à confirmer.


### Audit contradictoire et plan de clôture — 26 novembre 2026
Baseline 2c22759a173e01555dd148b0e434561630982fc7, run 45865644483 SUCCESS 5/5, achats 45865240235 SUCCESS 5/5. La CI verte ne signifie pas conformité intégrale. Référentiel de finalisation : [BOOTIK_AUDIT_CONFORMITE_6_BULK.md](BOOTIK_AUDIT_CONFORMITE_6_BULK.md). Six lots restants maximum : B01 fondations/administration/entitlements ; B02 stock/14 profils ; B03 ERP Détaillants ; B04 ERP Distributeurs/WMS/logistique ; B05 CRM B2B/réseau/réapprovisionnement ; B06 pilotage/intégrations/recette finale. Aucun changement du cahier V1.1 ni du code métier dans cette passe d'audit. Recettes progressives obligatoires, aucun vert sans preuve.


### BULK 01 — premier lot sécurité/entitlements (candidat)
Sources réellement lues : NAXA SERVICES scope_contract.ts, naxa-services-device-session.ts et subscription_credit_contract.ts. Adaptation aux jetons opaques BOOTIK : identifiant de session stable au refresh, plafond configurable de sessions par membre (2 par défaut, distinct du plafond physique par point), révocation distante et audit append-only, restrictions d'activités et désactivation par promoteur, révocation des sessions après changement. Essai unique organisation/app (aucune double activation inter-univers), grille serveur capabilities Access/Premium ; pas de forfait mixte inventé. Recettes API ajoutées, CI à confirmer. Administration centrale/provisionnement, rôles/postes, terminaux physiques et notification FCM non clôturés ; aucun contournement ni écriture auth.users par runtime, pas de migration hébergée.


### BULK 01 — délégations et sécurité UI (candidat)
Rôles métier restrictifs superposés aux rôles SQL historiques, refus par défaut pour opérations non prévues des profils spécialisés, contrôles serveur avant mutation, affectation d'activités (vide = aucun accès), désactivation et révocation de sessions après modification. Audit avant/après, raison, acteur/site ; pas d'UPDATE/DELETE sur audit pour runtime. Interfaces Web/Android et tests API (comptable lecture seulement, interdiction vente, scope vide, faux ID, ancienne session refusée, désactivation) et vérification navigateur. Les profils liés à des modules futurs n'ouvrent que catalogue/activités jusqu'à livraison. Le provisionnement central, périmètres poste/caisse/dépôt/territoire, notification physique et preuves hébergées restent ouverts. CI à vérifier.


### BULK 01 — séparation des privilèges administratifs
Run 45867656640 : le test historique de refus d'écriture directe sur scopes a détecté une régression de grants. Correction sans affaiblir le test : connexion serveur BOOTIK_SECURITY_DATABASE_URL dédiée, rôle bootik_security_runtime isolé, aucune lecture des credentials, aucun droit de modification des ventes/stock, pas d'UPDATE/DELETE audit ; runtime ERP ne peut ni écrire les scopes ni invoquer bk_admin_action. En l'absence de connexion admin, réponse 503. CI nouvelle à vérifier. Ce contrat de runtime ne constitue pas une connexion effective à l'administration centrale hébergée.


### BULK 01 — récupération interne et rotation (candidat)
Adaptation du contrat NAXA SERVICES Auth provision/complete_recovery/change_password : demande générique anti-énumération, liste uniquement Promoteur autorisé sur toutes affectations de la cible, vérification humaine hors bande, mot de passe aléatoire temporaire affiché une seule fois (pas dans reçu persistant/audit), changement obligatoire, rotation avec version de credentials et verrou commun à l'émission de session, révocation des sessions, absence OTP/email/SMS. Android/Web raccordés. Tests réels sur compte délégué, récupération inconnue, rejeu, refus des opérations avant rotation, révocation et nouveau secret. Réserves : identité centrale et reset Promoteur par support central non raccordés, politique physique appareils à compléter. CI à vérifier.


### BULK 01 — installations et parc par site (candidat)
Contrat NAXA SERVICES device installation_id repris : UUID non secret persisté Android/Web, lié au refresh, ré-enrôlement après vérification du mot de passe révoque précédente session de même installation. Plafond distinct par membre et par site (2 par défaut, configurable sous autorité du Promoteur) ; inscription au premier usage du site avec verrou transactionnel, journal unique new-site-device, inventaire et révocation des sessions depuis UI. Identifiant d'installation n'est pas une attestation matérielle. Tests wrong-install refresh, droits, liste et extension parc. FCM/attestation physique et politique de tolérance offline restent à qualifier. CI à vérifier.


### BULK 01 — adaptation provisionnement Famille (candidat)
Référence NAXA SERVICES contrat provision_member : demande employé par Promoteur, périmètre site/activités/fonction vérifié, état pending explicite ; central crée l'identité Auth puis transmet un événement BOOTIK via adaptateur dédié (family-pending/family-provision, authentification serveur et rôle SQL séparé). Création organisation+site+activité+promoteur ou employé selon demande, FK identité existante, secret temporaire émis une fois, changement obligatoire, audit sans secret et idempotence. Tests isolés (identité manquante, transaction annulée, mauvais jeton, faux tenant, rejeu et demande approuvée) ; UI demande/état Android/Web. Aucune connexion réelle au service central ni modification de l'admin central ; l'adaptateur est une proposition de contrat à valider et raccorder par canal autorisé. Configuration BOOTIK_PROVISION_DATABASE_URL et BOOTIK_FAMILY_PROVISION_TOKEN côté serveur uniquement. Ne pas déclarer B01-01 vert hébergé.


### BULK 01 — bail offline et invalidation cache (candidat)
Durée configurable 1–15 minutes, bornée à la session serveur actuelle (15 min), aucun 7/14 jours inventé. Bail avec heure serveur et ancre monotone Android/Web, contrôle recul d'horloge, expiration de la lecture cache et de la mise en file ; synchronisation serveur conserve son contrôle de droits. Empreinte déterministe du périmètre effectif (rôle, fonction, sites, activités) ; cache Room/IndexedDB partitionné par empreinte et anciennes versions purgées au login sans effacer les événements historiques en attente. Tests serveur, JS et Room. Changement de durée à la prochaine connexion/rotation ; révocation distante offline ne peut être instantanée, garantie limitée au bail ; droits vérifiés côté serveur à reconnexion. CI à confirmer.


### BULK 01 — affectations de ressources (candidat)
Postes et territoires de référence, liaison caisse/poste, affectation explicite caisse/poste/zone de stock/territoire par site à un membre, intersection activité + fonction + ressource, catalogue/état caisse filtrés, mouvement stock et action caisse vérifiés SQL avant rejeu. Périmètre restreint sans ressource = refus, ventes directes hors caisse interdites pour un poste/caisse restreint. Empreinte cache comprend la règle ressource ; sessions révoquées. Territoires préparés, opérations B2B restent fermées jusqu'à B05 ; une catégorie de ressource par site, plusieurs IDs, pas de fusion implicite de catégories. UI Android/Web et tests de caisse liée/refus autre caisse et révocation. Recette à vérifier.

### BULK 01 — lecture ressources et remboursement confirmé
Correction du paramètre de lecture ressources et restriction au Promoteur non restreint; test API lecture réelle. Remboursement intégral déjà confirmé par intégration de facturation autorisée : rôle SQL séparé, référence et montant exacts, reçu immuable, rejeu idempotent, révocation de la période, statut Android/Web. Aucun transfert d'argent initié. `/confirm-refund` exige une intégration externe vérifiant la preuve opérateur et un secret serveur distinct, non configuré en production. Les remboursements partiels et la preuve opérateur réelle restent à qualifier. CI à vérifier.

### BULK 01 — seuils et validation financière (candidat)
Politiques optionnelles par activité/site pour règlement fournisseur et sortie/dépense de caisse ; Promoteur configure, délégataire au-delà du seuil soumet, mutation bloquée en SQL jusqu'à décision d'un Promoteur distinct, exactitude du payload, décision auditée, rejeu sûr. Interface Web/Android et registre de demandes. La décision n'exécute pas le paiement externe. Le seuil s'applique aux opérations implémentées seulement, les autres opérations sensibles et circuits multiniveaux restent à compléter avec leurs modules. Tests de non-écriture avant approbation, refus écriture directe et rejeu. CI à confirmer.

Reprise des approbations après redémarrage : liste serveur des demandes propres, finalisation avec UUID et payload d'origine, nouvelle vérification de la session/rôle/ressource via opération métier et reçu original, aucune duplication. Android/Web. Recette API ajoutée.

### B01 — extension de dossier central et récupération Promoteur
Adaptation du contrat site/activité de NAXA SERVICES : événements centraux idempotents site, activity, member-site, promoter-recovery. Extension sans second compte ni abonnement, vérification tenant/profil/activité, nouvel accès employé explicitement limité, ancien jeton employé révoqué, récupération Promoteur par événement central avec preuve humaine et secret provisoire unique. Tests PostgreSQL/API ajoutés. Aucun accès ni modification du service central réel ; preuve de transport hébergé encore nécessaire.

### B01 — affectations cumulatives
La clé des règles inclut la catégorie de ressource. Les règles caisse et poste sont maintenant intersectées (aucun écrasement implicite), fingerprint cache inclut toutes les règles ; lecture activité et catalogue intersectées. Les zones de stock associées à un poste/caisse restent fermées à la vente FEFO tant que B02/B03 ne garantit pas l'allocation de lot par zone ; territoire interdit aux opérations non encore raccordées B05. Test combiné caisse A+B et poste A : seule caisse A autorisée. Aucune permission élargie.

### B01 — notifications de sécurité
Réutilisation du principe inbox par destinataire et états lu/non lu de NAXA SERVICES (notification_contract.ts, v6 SQL et NotificationInboxContent.kt). Inbox BOOTIK dérivée des événements immuables, identifiants stables, reçu de lecture unique, accès selon site et identité, préférence d'approbation désactivable, sécurité non désactivable, aucun contenu secret ou motif brut. Android/Web raccordés. Tests réel PostgreSQL de lecture, rejeu, autre tenant et préférence. Pas de prétention de livraison push FCM : configuration BOOTIK dédiée et appareil réels non vérifiés.

### B01 — matrice et clôture contrôlée
Version explicite de la grille serveur ACCÈS/PREMIUM (16 capacités), sans changer les prix ni la formule mixte non arbitrée. Seuil configurable de clôture sur écart absolu, capture du solde théorique dans la demande ; si le solde ou le comptage change, le payload ne correspond plus et l'ancienne approbation ne s'applique pas. Reprise idempotente par demande serveur. Tests de sortie caisse, écart, aucune clôture avant approbation, rejeu. Seuils des futures mutations (remises, avoirs, crédit, B2B) à intégrer dans leur module, pas de succès fictif.

### B01 — périodes d’affectation
Début/fin optionnels par employé/site, validation temporelle ISO avec fuseau, révocation des anciennes sessions après modification, contrôle SQL avant opérations et filtre login, bail offline plafonné par la première échéance d’affectation. Aucun effet sur les autres sites actifs. UI Android/Web, journal et recette réelle (période active, expiration et rejet site expiré).

### B01 — recette UI et défense SQL
Recette navigateur réelle sur notifications : nouvel appareil, reçu de lecture, préférence et persistance après reconnexion. Contrôles croisés caisse/zone appliqués aussi dans les fonctions de mutation SQL, pas seulement dans le routeur API. CI à confirmer.

### B01 — parcours de première connexion NAXA SERVICES
Sources exactes : MainActivity.kt routeAfterAuthentication/LoginScreen, ExperienceScreens.kt DiscoveryScreen/FirstUseTourContent, auth/session.ts (jetons Web jamais persistés), LoginScreenUiInstrumentedTest.kt, commit NS 5e039635. BOOTIK conserve profil central, mot de passe initial à changer et PIN/biométrie Android. Présentation en 4 cartes et visite en 5 étapes, progression serveur par organisation/membre, skip explicite, rejeu, changement de compte isolé. Android/Web raccordés et test navigateur progression/reconnexion + test Compose validation formulaire. Acceptation explicite version/hash du texte BOOTIK si fourni par administration (BOOTIK_LEGAL_DOCUMENTS_JSON), contrôlée serveur, aucune acceptation inventée ; pas de documents juridiques BOOTIK approuvés dans le dépôt, configuration à valider. Pas de persistance navigateur de jetons. Traductions complètes et parcours visuel identique restent à qualifier. CI à vérifier.

### B01 — recette première connexion renforcée
Recette Chromium de toutes les cartes et cinq étapes avec persistance SQL ; correction du test de préférence de notification (contrôle asynchrone : clic puis attente de la valeur effectivement confirmée, vérification SQL conservée). Recette API documents fictifs de test : refus avant acceptation, hash incorrect refusé, idempotence. Les textes fictifs ne sont pas des CGU de production.

### B01 — entrée Android et langue de connexion
Android ouvre désormais directement la connexion (brouillons accessibles par action explicite), comme NAXA SERVICES. Libellés FR/EN/Fulfulde repris des strings de connexion NAXA SERVICES ; sélection locale et mot de passe masquable. Tests Compose de bascule de langue et formulaire ; Web mêmes libellés à la connexion. Cette adaptation ne couvre pas encore la traduction intégrale des écrans ERP et du tutoriel.

### B01 — navigation après découverte
Cinq raccourcis fonctionnels vers les sections réellement disponibles, Web/PWA et Android natif, présentation adaptée au rôle staff. Tests navigateur de présence des cinq cibles. Les modules non livrés ne sont pas présentés comme opérationnels.
