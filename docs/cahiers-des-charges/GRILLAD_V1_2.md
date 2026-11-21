# GRILLAD — Cahier des charges fonctionnel V1.2

**Date de référence :** 21 novembre 2026  
**Produit :** GRILLAD  
**Type :** ERP autonome spécialisé dans la gestion des activités de grillades  
**Dépôt de référence :** audreymendomo23-netizen/FAMILLE-NAXA  
**Statut :** référentiel fonctionnel consolidé ; cinq arbitrages métier confirmés, décisions historiques conservées, compléments explicitement classés [C], [P] ou [O]  
**Document de continuité :** [GRILLAD — Continuité et passation](../passations/GRILLAD_CONTINUITE_2026-11-21.md)

---

## 0. Objet, statut et règles d'interprétation

Le présent document consolide le périmètre GRILLAD pour cadrer la conception fonctionnelle, l'UX/UI, le modèle de données, les contrats API, le développement, les tests et la recette.

Il remplace le document V1.0 retrouvé dans la bibliothèque comme référentiel documentaire de travail, mais **ne transforme pas automatiquement tous les éléments de V1.0 en décisions approuvées**. Les statuts rendent explicite la provenance de chaque exigence.

### 0.1 Statuts

- **[V] Validé :** décision directement exprimée par le commanditaire ou inscrite au registre officiel des décisions.
- **[C] Constat documentaire :** fonctionnalité ou règle décrite dans un document de référence sans preuve primaire d'approbation retrouvée.
- **[P] Proposition :** détail recommandé pour construire une solution testable, encore soumis à validation lorsqu'il touche au métier ou au modèle commercial.
- **[O] Ouvert :** arbitrage requis avant la finalisation du sous-parcours.
- **[B] Bloqué :** ne pas intégrer dans le périmètre de livraison avant résolution d'une contradiction ou accord explicite.

### 0.2 Principes non négociables

1. GRILLAD est une application autonome de la Famille NAXA. [V]
2. Le périmètre de vente GRILLAD est limité strictement à cinq familles : porc, poulet, poisson, brochettes et omelettes. [V]
3. La vente directe est le seul canal retenu dans la baseline. [V]
4. Le suivi de préparation est volontairement simple : quantités préparées, quantités vendues et quantités restantes. [V]
5. La gestion mono/multisite dispose des modes indépendant et centralisé, avec des droits configurables. [V]
6. Le périmètre financier comprend caisse, dépenses, coûts de revient et marges. [V]
7. Les données et les opérations de chaque site restent identifiables et séparées, y compris en mode centralisé. [V]
8. L'IA, si le périmètre V1.0 est confirmé, reste assistive : elle analyse et recommande ; elle ne valide pas seule une opération sensible. [C/O]
9. Une spécification écrite, une maquette ou un build ne constituent pas une preuve de livraison. La recette complète est obligatoire.

### 0.3 Ce que ce document ne certifie pas

Ce cahier décrit le produit attendu ; il ne certifie pas que les fonctions existent dans les applications Android ou Web, que le backend est déployé, que les politiques RLS sont actives, que les paiements sont configurés ou que les tests ont été exécutés.

## 1. Vision et objectifs produit

GRILLAD aide un promoteur de grillades à exploiter un ou plusieurs points de vente, enregistrer les ventes directes, suivre les quantités préparées et vendues, tenir la caisse, enregistrer les dépenses et comprendre la rentabilité par article, famille, vendeur, site et période.

Le logiciel doit être rapide à utiliser dans un environnement commercial, avec un parcours de vente court et des informations financières explicables.

### 1.1 Objectifs

- Limiter les erreurs de caisse et les ventes non rapprochées.
- Connaître les quantités préparées, vendues et restantes.
- Comparer les cinq familles et les articles.
- Identifier les dépenses et comprendre leur impact sur les résultats.
- Estimer les coûts de revient avec les données réellement renseignées.
- Gérer un ou plusieurs lieux de vente sans mélanger les stocks, les caisses ou les recettes.
- Déléguer les tâches avec des permissions contrôlables.
- Donner au promoteur une vue fidèle de son réseau.

### 1.2 Périmètre métier strict

**Les seules familles de vente autorisées sont :**

| Famille | Articles et formats possibles | Unités envisageables |
|---|---|---|
| Porc | Porc braisé, morceaux, portions | kg, pièce, portion ou format paramétré |
| Poulet | Poulet entier, demi-poulet, quart, portion | pièce, fraction, portion, calibre |
| Poisson | Poisson braisé, espèces et calibres distincts | pièce, poids ou format paramétré |
| Brochettes | Brochettes de viande, poulet ou porc | unité, lot ou quantité paramétrée |
| Omelettes | Omelette simple, taille ou variante | unité, taille ou variante paramétrée |

Les articles doivent être rattachés à une seule famille. Aucun écran d'administration ne doit permettre de créer une sixième famille standard.

**Clarification [O] :** les cinq familles sont présentes dans le périmètre du produit, mais la règle imposant que chaque établissement active les cinq simultanément n'a pas été retrouvée comme arbitrage utilisateur. La configuration doit donc pouvoir gérer les familles autorisées et activées par site sans rendre obligatoire leur activation simultanée avant validation de ce point.

## 2. Canaux de vente, limites et exclusions

### 2.1 Vente directe [V]

La vente est enregistrée directement par un vendeur ou un utilisateur autorisé dans le point de vente. Le parcours standard est :

1. L'utilisateur ouvre le point de vente autorisé.
2. Il accède au catalogue actif.
3. Il sélectionne les articles et les quantités.
4. Le système affiche le prix et le total.
5. L'utilisateur confirme la vente et saisit le paiement reçu.
6. GRILLAD crée une référence, met à jour les quantités disponibles et enregistre l'encaissement.
7. Le système affiche la confirmation et produit un reçu selon les capacités approuvées.

### 2.2 Hors périmètre [V]

- Réservation de table, de place ou de créneau.
- Précommande ou commande anticipée.
- Commande à distance ou canal de livraison.
- Gestion de livreurs et suivi de livraison.
- Marketplace, agrégateur ou prise de commande par un tiers.
- Vente de boissons, desserts, accompagnements, repas complets ou autres familles de restauration.
- Fabrication d'un ERP générique de restaurant ou de snack-bar.

Ces exclusions doivent être contrôlées dans l'expérience utilisateur, les APIs et les règles serveur, et non uniquement par masquage d'écran.

### 2.3 QR ZIPPLE / GRILLAD Connect [P]/[B]

Une proposition d'intégration depuis le QR de table ZIPPLE a été formulée : une entrée « Services partenaires » présenterait un vendeur GRILLAD associé. Ce parcours peut être commercialement intéressant, mais il risque de contredire la vente directe exclusive et l'exclusion de la prise de commande par des tiers.

En conséquence, cette fonctionnalité est **hors périmètre de livraison du présent cahier** tant qu'une décision explicite n'a pas défini l'exception à la vente directe.

En cas de validation ultérieure, les exigences minimales proposées sont :

- accord bilatéral entre le bar ZIPPLE et l'établissement GRILLAD ;
- catalogue et prix contrôlés par GRILLAD ;
- commande, référence, stock, préparation, recette et caisse appartenant à GRILLAD ;
- commande ZIPPLE distincte pour les articles du bar ;
- aucun panier, paiement, stock ou chiffre d'affaires fusionné ;
- aucune visibilité ZIPPLE sur les coûts, marges, inventaires internes ou caisses GRILLAD ;
- entitlement GRILLAD vérifié côté serveur, sans considérer un simple écran Premium comme une autorisation ;
- suivi d'acceptation/refus, préparation, remise et clôture, uniquement après arbitrage commercial et fonctionnel.

Le libellé « Services partenaires » et l'activation Premium sont des propositions, pas des règles tarifaires ou fonctionnelles approuvées dans cette version.

## 3. Architecture d'organisation : Promoteur, points de vente et vendeurs

### 3.1 Hiérarchie de l'organisation [V]

GRILLAD doit gérer une organisation de vente structurée en trois niveaux :

**Promoteur / Organisation**
- possède et administre le réseau ;
- crée, active, suspend ou archive les points de vente ;
- désigne les responsables et attribue les permissions ;
- consulte les données consolidées autorisées.

**Points de vente**
- une organisation peut posséder plusieurs points de vente ;
- chaque point de vente est un périmètre opérationnel distinct ;
- chaque point possède ses données locales : catalogue applicable, préparations, disponibilités, ventes, caisse, dépenses, équipe et rapports ;
- les stocks, préparations et caisses de deux points différents ne sont jamais mélangés.

**Vendeurs**
- un point de vente peut avoir plusieurs vendeurs actifs ;
- chaque vendeur dispose de son propre compte et de ses propres identifiants ;
- chaque vente est attribuée au vendeur connecté et au point de vente dans lequel elle est réalisée ;
- plusieurs vendeurs peuvent travailler au même point de vente pendant le même service ;
- un vendeur peut être affecté à plusieurs points de vente uniquement si le Promoteur ou un responsable autorisé lui en donne explicitement le droit.

Le système ne doit jamais imposer un seul vendeur par point de vente. L'ajout d'un vendeur ne crée pas un nouveau point de vente.

### 3.2 Architectures d'exploitation prises en charge [V]

| Architecture | Organisation | Fonctionnement attendu |
|---|---|---|
| A — Point unique autonome | 1 point de vente, Manager seul | Le Manager exploite le point, prépare, vend et pilote les opérations selon ses droits. |
| B — Point unique avec équipe | 1 point de vente, 1 Manager et plusieurs vendeurs | Chaque vendeur réalise ses ventes avec son propre compte ; le Manager supervise l'équipe et les résultats du point. |
| C — Réseau multisite | Plusieurs points de vente, chacun avec un ou plusieurs vendeurs et un responsable local lorsque nécessaire | Chaque point fonctionne dans son propre périmètre ; les vendeurs sont affectés à leur(s) point(s) autorisé(s). |
| D — Réseau centralisé | Plusieurs points de vente, plusieurs vendeurs par point, Manager réseau et responsables locaux éventuels | Le Promoteur pilote le réseau, délègue la gestion locale et consulte une consolidation autorisée sans fusionner les opérations locales. |

Les architectures A à D sont des configurations du même produit et du même compte Promoteur ; elles ne nécessitent pas de créer une application ou un compte commercial indépendant pour chaque vendeur.

### 3.3 Rôles et périmètres

Les rôles à mettre en place, à préciser dans la matrice finale, comprennent :

- **Promoteur / propriétaire :** administration globale de l'organisation et accès aux rapports autorisés.
- **Manager réseau :** supervision des points de vente qui lui sont attribués et consultation consolidée autorisée.
- **Responsable de point de vente :** gestion quotidienne d'un ou plusieurs points autorisés, affectations et contrôles selon délégation.
- **Vendeur :** opérations de vente et consultation strictement nécessaires à son activité.
- **Préparateur / gestionnaire de préparation :** saisie des quantités préparées et ajustements autorisés.
- **Gestionnaire financier / caissier :** opérations de caisse, dépenses et clôtures selon les droits accordés.

Un utilisateur peut cumuler plusieurs rôles, mais chaque permission doit avoir une portée explicite : organisation, point de vente et action. Une permission accordée sur un point ne s'étend pas automatiquement aux autres.

### 3.4 Deux modes de gestion des données [V]

| Mode | Fonctionnement | Visibilité |
|---|---|---|
| Indépendant | Chaque point de vente gère son catalogue autorisé, ses prix, ses vendeurs, préparations, stocks, ventes, caisse, dépenses et rapports. | Les autres points restent invisibles sauf autorisation expresse. |
| Centralisé | Le Promoteur peut partager certains paramètres, superviser plusieurs sites et consulter des rapports consolidés. | Les opérations sources restent ventilées par point de vente ; un responsable local ne voit pas automatiquement les autres sites. |

Les trois configurations historiques Manager (Manager seul ; Manager avec vendeur(s) ; Manager supervisant plusieurs vendeurs sur plusieurs lieux) sont ainsi conservées. Elles décrivent l'organisation humaine ; les modes indépendant/centralisé décrivent la gestion des données.

### 3.5 Règles de cloisonnement et de caisse

- Chaque vente, ligne de vente, préparation, mouvement de stock, dépense, session de caisse et rapport est associé à un point de vente et à un utilisateur auteur.
- Les ventes d'un même point peuvent être réalisées par plusieurs vendeurs en parallèle ; le système doit attribuer chaque opération au bon vendeur sans double décrémentation des quantités disponibles.
- Chaque point conserve sa caisse et ses rapprochements propres.
- Les sessions de caisse doivent identifier clairement le responsable de la session et les opérations des vendeurs rattachées. Le choix entre une caisse commune par point et plusieurs sessions/tiroirs par vendeur reste à détailler avant développement final ; il ne doit jamais y avoir de confusion sur l'auteur et le point de rattachement.
- Les rapports doivent pouvoir être filtrés par réseau, point de vente, vendeur, famille, article et période, selon les permissions.
- Les données non synchronisées sont signalées comme partielles et ne doivent pas être présentées comme une consolidation complète.

### 3.6 Affectations et mouvements entre points

Les affectations d'un vendeur ou d'un manager à plusieurs points doivent être explicites, datées et révocables. Le changement de point actif dans l'application ne modifie pas ses droits.

Les transferts d'intrants entre points restent soumis à un processus documenté ; les transferts de produits déjà préparés restent à arbitrer. Aucun transfert ne doit être enregistré comme une vente.

## 4. Catalogue et gestion des quantités préparées

### 4.1 Catalogue

Pour chaque article, prévoir :

- famille parmi les cinq familles autorisées ;
- nom commercial et description interne ;
- unité de vente et format ;
- prix de vente ;
- statut actif / inactif ;
- établissement(s) concerné(s) ;
- date d'effet et auteur des changements de prix.

Un article désactivé conserve son historique et ne peut plus être vendu.

### 4.2 Quantités préparées et vendues [V]

Le suivi de production doit être volontairement simple.

Pour chaque site, journée/service et article :

- quantité préparée ou mise à disposition ;
- quantité vendue ;
- ajustements entrants ou sortants justifiés si une correction est autorisée ;
- quantité restante.

Formule de référence :

**Restant = quantité préparée + ajustements entrants validés − quantité vendue − ajustements sortants validés.**

Les ventes réduisent la quantité disponible. Le système bloque normalement une vente supérieure au solde disponible. Toute dérogation éventuelle exige une règle explicite, un droit spécial, un motif et une trace d'audit.

Les corrections ne doivent jamais réécrire silencieusement la valeur historique. Elles sont ajoutées comme mouvements datés et attribués.

### 4.3 Production avancée exclue [V]

Le système ne doit pas imposer :

- une chaîne détaillée d'étapes de cuisson ;
- la température, la durée et les paramètres de cuisson ;
- une gestion de lots industriels ;
- le calcul de rendement de transformation avancé ;
- un suivi détaillé de la consommation de combustible en temps réel.

Ces fonctions sortent du choix de suivi simple.

### 4.4 Stocks d'intrants, achats et fournisseurs [C/O]

V1.0 décrit des fiches fournisseurs, achats, réceptions et inventaire des intrants : viandes, poulet, poisson, œufs, condiments, huile, charbon, brochettes et emballages.

Ces éléments peuvent soutenir le calcul des coûts, mais leur profondeur fonctionnelle n'a pas été identifiée comme un arbitrage direct récent distinct. Ils sont donc à confirmer au niveau de détail avant développement.

Leur présence éventuelle dans le stock interne ne crée pas une nouvelle famille de vente. Les intrants ne sont pas des articles commercialisables au client par GRILLAD.

## 5. Vente, paiement et caisse

### 5.1 Parcours de vente

La vente directe permet de sélectionner un ou plusieurs articles autorisés. Avant validation, l'écran montre les prix, quantités, sous-totaux et total.

Une remise n'est possible qu'avec une permission et une règle définie. Les paiements associés sont attachés à la vente et au site. La référence de vente doit être unique.

Une vente validée ne peut pas être effacée. Une correction ou annulation conserve la transaction initiale, l'acteur, le motif, l'heure et l'effet sur les stocks et la caisse.

### 5.2 Paiements [O]

Le document V1.0 envisage plusieurs moyens de paiement, mais aucun fournisseur ni mode particulier n'est confirmé ici.

À arbitrer avant l'activation commerciale :

- moyens acceptés ;
- paiements multiples ou mixtes ;
- frais éventuels ;
- remboursement ou annulation après encaissement ;
- rapprochement Mobile Money ;
- preuve de paiement et reçu.

Ne jamais afficher un paiement comme confirmé sur la seule base d'une saisie locale ou d'une capture d'écran. Les paiements en ligne exigent une confirmation serveur, une idempotence et une réconciliation.

### 5.3 Sessions de caisse

La caisse est organisée par établissement et session.

Le modèle fonctionnel à confirmer comprend :

- ouverture de session ;
- fonds initial si retenu ;
- ventes encaissées ;
- entrées et sorties autorisées ;
- dépenses payées depuis la caisse si cette règle est retenue ;
- montant théorique ;
- montant réellement compté ;
- écart et justification ;
- clôture, validation et historique.

Les règles de fonds initial obligatoire, de caisse mixte et de réouverture après clôture restent [O].

### 5.4 Dépenses

Une dépense doit au minimum comporter un libellé, une catégorie, un montant, une date, un établissement, un auteur et un statut. Le justificatif peut être requis selon la règle de l'organisation.

Le modèle de statuts proposé dans V1.0 est : brouillon, soumise, validée, rejetée, payée ou annulée. [C/P]

Une dépense validée ne peut pas être modifiée silencieusement ; toute correction est historisée.

## 6. Coût de revient, marges et pilotage financier

### 6.1 Objectif [V]

GRILLAD doit permettre au promoteur de comprendre le coût de revient et la marge des articles, familles et établissements.

### 6.2 Méthode de calcul [O]

V1.0 décrit une fiche de consommation indicative par article/format : intrants, quantité de référence et unité. Les coûts d'achat peuvent valoriser les intrants.

Les choix suivants restent ouverts :

- dernier coût d'achat ;
- coût moyen pondéré ;
- coût standard ;
- inclusion du charbon, emballages, huile, condiments et autres coûts directs ;
- répartition des charges indirectes ;
- niveau de granularité par article, portion ou formule.

### 6.3 Présentation obligatoire de la qualité du coût

Le système ne doit pas présenter un coût comme exact lorsque les fiches de consommation, unités ou prix d'achat sont incomplets.

Chaque résultat de coût doit être étiqueté :

- **Renseigné :** toutes les données requises de la méthode choisie existent.
- **Estimé :** le résultat repose sur une approximation ou des paramètres partiels explicitement identifiés.
- **Incomplet :** une ou plusieurs données indispensables manquent ; ne pas calculer une marge présentée comme fiable.

### 6.4 Indicateurs minimums

| Indicateur | Définition |
|---|---|
| Chiffre d'affaires net | Ventes validées nettes des annulations et corrections. |
| Encaissements | Paiements effectivement enregistrés, séparés des ventes si des créances sont un jour autorisées. |
| Coût matière estimé | Quantités vendues × coût unitaire calculé ou estimé. |
| Marge brute estimée | Chiffre d'affaires net − coût matière estimé. |
| Dépenses opérationnelles | Dépenses validées rattachées au périmètre et à la période. |
| Résultat opérationnel indicatif | Marge brute estimée − dépenses prises en compte. |
| Solde préparé | Préparé, vendu, ajustements et restant par article/famille/site. |

Les rapports affichent toujours la période, le site ou périmètre consolidé, la monnaie, les filtres, la date de génération et l'état de synchronisation.

### 6.5 Limite comptable et fiscale

Le tableau de bord est un outil de gestion. Il ne constitue pas une comptabilité générale certifiée, un grand livre SYSCOHADA certifiable, une déclaration fiscale, un calcul réglementaire de TVA ou un bulletin de paie. Ces périmètres nécessitent des exigences distinctes, arbitrage et validation par des professionnels compétents.

## 7. Personnel, rôles et permissions

### 7.1 Profils fonctionnels de départ [C/P]

V1.0 recense les profils suivants, à confirmer dans la matrice finale :

- Promoteur / propriétaire ;
- Administrateur ;
- Responsable d'établissement ;
- Préparateur / responsable préparation ;
- Caissier / vendeur ;
- Gestionnaire de stock ;
- Comptable / gestionnaire financier ;
- Superviseur.

Un même compte peut cumuler plusieurs rôles si le promoteur le permet, dans les limites des permissions.

### 7.2 Matrice de droits

Les autorisations doivent combiner au minimum :

- application ;
- organisation ;
- établissement ;
- utilisateur ;
- rôle ;
- permission ;
- action ;
- seuil de validation lorsqu'il existe.

Actions à contrôler séparément : consulter, créer, modifier, annuler, valider, clôturer, réouvrir par exception, exporter et administrer.

Les droits financiers ne sont pas attribués automatiquement à tous les vendeurs. Le droit de voir une donnée ne donne pas automatiquement le droit de la modifier.

### 7.3 Audit

Journaliser au minimum :

- changement de prix ;
- ouverture et clôture de caisse ;
- vente, correction et annulation ;
- paiement, remboursement et rapprochement ;
- dépense et validation ;
- ajustement et transfert de stock ;
- modification de rôle et d'affectation ;
- changement de site ;
- changement d'abonnement ;
- actions d'administration sensibles.

Une entrée d'audit indique l'acteur, l'organisation, le site, l'action, la cible, la date, le motif quand nécessaire et la source de l'action. Elle ne doit pas exposer de secrets.

### 7.4 Pointage GPS du personnel [O]

V1.0 classe le pointage et la géolocalisation de présence comme non validés. Aucun pointage GPS n'est donc exigé par cette baseline.

Une proposition ultérieure peut envisager heure d'arrivée / départ et preuve de présence, mais uniquement après arbitrage. Aucun suivi GPS permanent ou hors service ne doit être ajouté implicitement. L'adresse et la géolocalisation du site ne sont pas un suivi du salarié.

## 8. Abonnements et formules GRILLAD

### 8.1 Deux formules commerciales uniquement [V]

GRILLAD ne comporte que deux formules d'abonnement :

- **ACCÈS**
- **PREMIUM**

Aucune troisième formule PRO, aucun palier automatique selon le nombre de points et aucun tarif intermédiaire ne doit être ajouté.

### 8.2 Architecture couverte par les formules [V]

| Formule | Architecture d'exploitation | Organisation des vendeurs |
|---|---|---|
| **ACCÈS** | Un point de vente | Plusieurs vendeurs peuvent être affectés au même point de vente ; aucun plafond vendeur n'est arrêté dans la présente décision. |
| **PREMIUM** | Plusieurs points de vente dans le réseau du Promoteur | Chaque point de vente peut disposer de plusieurs vendeurs, d'un responsable local et d'une équipe distincte. Le Promoteur peut superviser le réseau selon ses droits. |

PREMIUM inclut les capacités d'ACCÈS. Les fonctionnalités métier essentielles (catalogue, ventes directes, quantités, caisse, dépenses, rentabilité et sécurité) ne sont pas retirées à ACCÈS pour pousser artificiellement vers PREMIUM.

**Aucun nombre maximal de vendeurs par point, ni aucun plafond maximal de points de vente PREMIUM n'est défini ici.** Ces limites ne doivent pas être inventées ou codées en dur. La matrice finale d'entitlements précisera les capacités éventuellement plafonnées après arbitrage.

### 8.3 Tarifs et périodicités [V/O]

Les seules périodicités autorisées sont :

- **Mensuelle :** un mois de service facturé au tarif mensuel de la formule.
- **Annuelle :** douze mois de service facturés au prix de **dix mensualités** de la même formule, soit deux mois de service offerts.

| Formule | Tarif mensuel | Tarif annuel pour 12 mois |
|---|---:|---:|
| ACCÈS | À confirmer | 10 × le tarif mensuel ACCÈS |
| PREMIUM | À confirmer | 10 × le tarif mensuel PREMIUM |

Les montants exacts en FCFA n'ont pas été retrouvés dans les décisions et documents accessibles au moment de cette révision. Ils restent donc **ouverts** et ne doivent pas être remplacés par les anciennes valeurs de 1 500 F, 3 000 F ou 5 000 F, ni par une autre estimation.

Aucune formule de trois ou six mois n'est autorisée. Aucun supplément par vendeur, par compte utilisateur ou par point de vente ne doit être ajouté sans décision tarifaire explicite. La règle exacte d'unité contractuelle et les éventuelles limites d'architecture doivent être décrites dans le catalogue avant toute facturation automatisée.

### 8.4 Gestion technique des droits

Le modèle de référence reste :

**Plan → Subscription → Payment → Entitlements**

- Seuls ACCÈS et PREMIUM sont enregistrés comme plans GRILLAD.
- Le paiement est confirmé côté serveur avant activation ou renouvellement des droits.
- Les entitlements définissent l'architecture autorisée ; les permissions déterminent les actions de chaque utilisateur sur chaque point de vente.
- Le système doit empêcher qu'un vendeur obtienne un accès à un point qui ne lui est pas affecté.
- L'expiration ou l'échec d'un paiement applique les règles contractuelles validées ; les opérations déjà engagées et l'accès à l'historique doivent être traités sans perte silencieuse de données.
- Les changements de formule, de nombre de points ou d'affectations sont historisés et ne réécrivent pas rétroactivement une période payée.


## 9. Parrainage GRILLAD [C/O]

V1.0 décrit un programme de parrainage avec identifiant, QR/lien, relation parrain-filleul, suivi des conversions et commissions. La preuve de l'arbitrage primaire n'est pas retrouvée dans les échanges accessibles ; le programme est donc à confirmer avant d'être considéré comme commercialement approuvé.

Si l'activation est confirmée, le socle fonctionnel proposé est :

1. Génération d'un identifiant parrain et d'un QR/lien.
2. Rattachement du filleul à un seul parrain.
3. Date, canal et statut du rattachement.
4. Étapes de conversion définies par le programme.
5. Commission ou récompense calculée selon un catalogue de règles versionné.
6. États : en attente, validée, payable, payée, rejetée, annulée.
7. Historique complet des changements et paiements.

Contrôles anti-fraude proposés : interdiction de l'auto-parrainage, détection des doublons, rattachement unique, événement déclencheur confirmé par le serveur, idempotence et journalisation.

**Aucun montant, seuil de cinq filleuls, abonnement gratuit, renouvellement ou règle de NAXA SERVICES n'est transféré à GRILLAD sans validation distincte.**

## 10. Assistant IA GRILLAD [C/O]

V1.0 décrit un assistant IA d'analyse et d'aide au pilotage. La validation primaire du périmètre détaillé reste à confirmer.

Si ce module est confirmé, son comportement devra respecter les règles suivantes :

- ne lire que les données auxquelles l'utilisateur a droit ;
- indiquer le site, la période et les sources métier ;
- signaler les données manquantes, obsolètes ou non synchronisées ;
- distinguer faits enregistrés, estimations et prévisions ;
- expliquer les limites de confiance ;
- ne pas modifier seul prix, stock, vente, dépense, caisse, permission, abonnement ou commission ;
- demander confirmation et permission avant toute action proposée ;
- ne pas facturer au token, à la requête ou au crédit si les règles communes du portefeuille maintiennent l'inclusion IA dans l'abonnement.

Les fonctions nécessitant un service distant peuvent être indisponibles hors connexion ; l'interface doit l'indiquer clairement.

## 11. Fonctionnement hors connexion [C/O]

V1.0 décrit un fonctionnement local étendu avec synchronisation différée, mais le détail n'est pas encore confirmé comme règle produit complète. Avant développement final, il faut décider quelles opérations sont autorisées hors ligne.

Si le mode est approuvé, le système doit prévoir :

- données de référence synchronisées et date de fraîcheur ;
- stockage local sécurisé ;
- identifiant local unique par opération ;
- états visibles : à synchroniser, en cours, synchronisé, échec, conflit ;
- mécanisme de reprise et backoff ;
- idempotence serveur pour ventes, paiements, dépenses et mouvements ;
- résolution de conflits propre à chaque type d'agrégat ;
- aucun écrasement silencieux d'une caisse ou d'un paiement ;
- rapports qui signalent les données non synchronisées ;
- journal des corrections et conflits ;
- politique claire après expiration d'abonnement.

Une opération locale en attente ne doit jamais être présentée comme confirmée par le serveur. L'idempotence d'une même opération ne doit pas être confondue avec la résolution d'un conflit entre deux opérations différentes.

## 12. Langues, notifications, support et sécurité vidéo [P/O]

Ces capacités sont proposées à l'échelle de la Famille NAXA, mais elles ne sont pas toutes validées ou opérationnelles pour GRILLAD.

### 12.1 Langues [O]

Le français et l'anglais peuvent constituer la base linguistique à confirmer. L'ajout du Fulfulde a été proposé, mais n'est pas figé dans la baseline GRILLAD. Une traduction complète doit être revue par des locuteurs compétents. Les noms commerciaux saisis par les établissements doivent être préservés.

### 12.2 Notifications [P/O]

Un service commun pourrait gérer centre interne, notifications locales, push et canaux externes autorisés. Événements potentiels : vente, caisse, stock faible, pointage, abonnement, parrainage, assistance. Les catégories transactionnelles et critiques doivent être séparées du marketing.

Ne pas déclarer FCM, WhatsApp, SMS ou les accusés de livraison disponibles sans tests de bout en bout.

### 12.3 Livechat [P/O]

Un service commun pourrait proposer FAQ, assistant automatisé et transfert vers un agent humain. L'assistance logicielle Famille NAXA doit rester distincte d'une éventuelle assistance concernant une commande ou un vendeur partenaire. Les conversations sont cloisonnées par application et organisation.

Un lien WhatsApp ne vaut pas Livechat complet.

### 12.4 NAXA SECURITY [P/O]

Une éventuelle passerelle vers NAXA SECURITY doit rester séparée du cœur GRILLAD. Aucun flux vidéo/audio, aucune caméra, aucun accès d'un site à un autre et aucun partage avec ZIPPLE ne sont activés par défaut. Les accès et durées de conservation sont définis et contrôlés séparément.

### 12.5 Confidentialité

Collecter uniquement les données nécessaires au fonctionnement. Toute extension qui traite la position du personnel, des images, de l'audio ou des conversations doit être soumise à une analyse de conformité, information et habilitation avant activation.

## 13. Modèle de données fonctionnel minimal

Le modèle logique devra au minimum couvrir les entités suivantes. Il s'agit d'un cadrage conceptuel, pas d'un schéma SQL approuvé.

| Entité | Données essentielles |
|---|---|
| Organisation / Promoteur | Identité, propriétaire, état, paramètres, abonnement |
| Point de vente | Organisation parente, nom, adresse, coordonnées, statut, mode, paramètres locaux |
| Affectation vendeur | Utilisateur, point(s) de vente autorisé(s), rôle, dates d'effet, statut |
| Utilisateur / membre | Identité applicative, statut, affectations et rôles par point de vente |
| Rôle / permission | Rôle, permission, portée organisation/site, action |
| Famille | Code parmi les cinq valeurs autorisées |
| Article | Famille, nom, unité, format, prix, état |
| Préparation | Site, service/date, article, quantité préparée |
| Ajustement | Site, article, quantité, sens, motif, auteur |
| Vente | Référence unique, site, vendeur, date, total, statut |
| Ligne de vente | Article, quantité, prix unitaire, remise autorisée |
| Paiement | Vente, moyen, montant, référence externe, état confirmé |
| Session de caisse | Site, ouverture, clôture, fonds initial éventuel, écarts |
| Mouvement de caisse | Session, type, montant, auteur, justificatif |
| Dépense | Site, catégorie, montant, date, statut, auteur |
| Fournisseur / achat | Fournisseur, intrants, site, lignes, réception |
| Composition / coût | Article, intrants, quantités et méthode de valorisation |
| Parrainage | Parrain, filleul, date, code, état, conversion [si confirmé] |
| Commission | Programme, déclencheur, montant, état, paiement [si confirmé] |
| Opération hors ligne | Identifiant local, appareil, charge utile, séquence, état [si confirmé] |
| Journal d'audit | Acteur, action, cible, site, horodatage, motif |

Chaque transaction métier est rattachée à l'organisation et au site. Les règles RLS et les contrôles API serveur doivent empêcher les lectures/écritures hors périmètre.

## 14. Exigences non fonctionnelles

1. Interface mobile prioritaire, lisible et rapide pour la vente.
2. Support Web responsive / PWA dans le cadre d'une application autonome.
3. Données isolées par application, organisation et site.
4. Permissions imposées côté serveur, et non seulement dans l'interface.
5. Aucun secret d'administration ou clé privilégiée dans le client.
6. Opérations financières et corrections auditables.
7. Sauvegarde, restauration, monitoring et procédures d'incident documentés avant production.
8. Affichage des erreurs, états en attente et données partielles.
9. Cohérence des dates, heures, fuseaux, unités et monnaie.
10. Accessibilité de base : contrastes, libellés et cibles tactiles adaptés.
11. Aucun doublon après reprise réseau ou répétition de requête.
12. Aucune fonctionnalité n'est qualifiée de terminée par la seule compilation.

## 15. Profils et écrans attendus

Les écrans ci-dessous forment un découpage UX proposé ; la navigation finale doit être validée avec les utilisateurs de terrain.

| Espace | Écrans / capacités |
|---|---|
| Accueil / synthèse | CA, ventes, préparations, restants, dépenses, caisses, alertes, état de sync |
| Organisation | profil Promoteur, établissements, modes, paramètres |
| Catalogue | cinq familles, articles, formats, unités, prix, activation |
| Service / préparation | quantités préparées, vendues, restantes par article |
| Vente | sélection rapide, panier interne de vente directe, total, remise autorisée, confirmation |
| Caisse | ouverture, opérations, paiements, clôture, écart, historique |
| Dépenses | liste, saisie, justificatifs, validation, paiement, rapport |
| Coûts / rentabilité | composition, intrants valorisés, coût estimé, marge, limites de calcul |
| Équipe | utilisateurs, rôles, permissions, affectations par point de vente, plusieurs vendeurs par point |
| Multisite | gestion indépendante ou centralisée, indicateurs ventilés |
| Rapports | ventes, familles, employés, dépenses, marges, caisses, données partielles |
| Parrainage | uniquement après confirmation de ce module |
| Assistant IA | uniquement après confirmation de son périmètre |
| Synchronisation | uniquement si le fonctionnement hors ligne est confirmé ; états et conflits |

Les écrans de fonctions non validées ne doivent pas être affichés comme fonctions commerciales disponibles.

## 16. Critères de recette fonctionnelle

Chaque recette doit être exécutée dans un environnement de test isolé avec des jeux de données contrôlés. Les résultats sont enregistrés avec date, version, appareil/environnement, résultat attendu, résultat observé, pièces de preuve et anomalie éventuelle.

| ID | Scénario | Résultat attendu |
|---|---|---|
| REC-01 | Créer un article dans chacune des cinq familles | Les cinq familles sont disponibles ; l'article appartient à une seule famille. |
| REC-02 | Créer une famille supplémentaire | L'opération est refusée. |
| REC-03 | Enregistrer une préparation puis plusieurs ventes directes | Le restant est recalculé exactement et ne devient pas négatif. |
| REC-04 | Tenter de vendre plus que le restant | La vente est bloquée, sauf dérogation expresse, autorisée et auditée. |
| REC-05 | Modifier un prix | L'historique conserve l'ancien prix, le nouveau prix, l'auteur et la date d'effet. |
| REC-06 | Annuler une vente avec un compte sans permission | L'action est refusée ; stock et caisse ne changent pas. |
| REC-07 | Annuler/corriger avec un compte autorisé | L'opération d'origine est conservée ; effets caisse/stock cohérents et auditables. |
| REC-08 | Ouvrir et clôturer une caisse | Montants théoriques, comptés et écarts sont calculés selon la règle approuvée. |
| REC-09 | Enregistrer et valider une dépense | Elle apparaît une seule fois dans le site et la période concernés. |
| REC-10 | Vérifier coût avec composition complète puis composition absente | Résultat correct avec données complètes ; statut incomplet explicite sinon. |
| REC-11 | Créer deux sites en mode indépendant | Aucun accès ou agrégat non autorisé entre sites. |
| REC-12 | Activer le mode centralisé | Le promoteur voit la consolidation autorisée ; les transactions sources restent ventilées par site. |
| REC-13 | Affecter un vendeur à un seul site | Il ne peut ni consulter ni modifier les données d'un autre site. |
| REC-14 | Répéter une requête de vente ou paiement | Aucun doublon n'est créé ; l'idempotence est démontrée côté serveur. |
| REC-15 | Utiliser GRILLAD hors connexion puis resynchroniser | À exécuter seulement après validation du périmètre offline ; aucune opération dupliquée ou perdue. |
| REC-16 | Provoquer un conflit de stock ou de caisse | Le conflit est signalé et traité sans écrasement silencieux. |
| REC-17 | Demander une synthèse de plusieurs sites avec un rôle local | Les données hors périmètre ne sont jamais divulguées. |
| REC-18 | Demander à l'IA de modifier un prix ou une dépense | À exécuter seulement si IA validée ; aucune modification sans permission et confirmation explicite. |
| REC-19 | Créer un code de parrainage et rattacher un filleul | À exécuter seulement si le programme est validé ; aucune commission avant événement serveur défini. |
| REC-20 | Enregistrer une vente dans le site A et consulter le site B | La séparation organisation/site est imposée côté serveur et en RLS. |
| REC-21 | Répéter une synchronisation après coupure et reprise | Aucune double vente, double dépense ou double encaissement. |
| REC-22 | Générer un rapport avec opérations en attente | Les chiffres partiels sont étiquetés et la fraîcheur des données affichée. |
| REC-23 | Créer un point de vente et y affecter trois vendeurs | Les trois vendeurs possèdent des comptes distincts, peuvent vendre dans le même point et chaque vente est attribuée au bon vendeur. |
| REC-24 | Créer plusieurs points de vente avec plusieurs vendeurs chacun | Les équipes, ventes, préparations, stocks, caisses et rapports restent rattachés au bon point. |
| REC-25 | Connecter un vendeur autorisé au point A puis tenter d'ouvrir le point B | L'accès à B est refusé si aucune affectation n'existe. |
| REC-26 | Faire vendre simultanément plusieurs vendeurs sur un même article | Les quantités disponibles sont décrémentées de façon cohérente, sans vente doublonnée ni dépassement silencieux. |
| REC-27 | Comparer le rapport d'un responsable local au rapport du Promoteur en mode centralisé | Le responsable ne voit que son périmètre ; le Promoteur voit uniquement la consolidation autorisée et la ventilation par point. |

## 17. Porte de livraison — définition stricte de « terminé »

Une fonctionnalité ne peut être déclarée **TERMINÉE** que si toutes les conditions applicables sont prouvées :

1. Tous les écrans du parcours sont reliés aux vraies règles métier.
2. La validation côté serveur et les permissions sont effectives.
3. Les données sont persistées et relisibles après redémarrage ou reconnexion.
4. Les erreurs, refus, annulations, répétitions et cas limites sont gérés.
5. Les flux financiers sont idempotents et rapprochables.
6. Les synchronisations et conflits sont traités lorsque la fonction est offline.
7. L'isolation RLS organisation/site/rôle est testée sur un moteur de base exécuté.
8. Les tests unitaires, intégration, API, sécurité et non-régression passent.
9. Les parcours principaux sont testés sur appareils physiques et plusieurs comptes/sites.
10. Les rapports, exports et états affichés correspondent aux données sources.
11. Le fonctionnement opérationnel et les procédures de reprise sont acceptés.
12. Les preuves sont attachées à la version et au commit exacts.

Un écran, une maquette, un contrat non déployé, une migration candidate, une compilation ou un workflow partiellement vert ne suffisent pas.

## 18. Arbitrages restants avant gel complet

| ID | Sujet | Statut |
|---|---|---|
| O-01 | Réconfirmer parrainage GRILLAD et paramètres de commission | [O] |
| O-02 | Réconfirmer le périmètre exact de l'assistant IA | [O] |
| O-03 | Réconfirmer opérations et durée de fonctionnement hors connexion | [O] |
| O-04 | Décider si les cinq familles doivent être simultanément actives sur le même site | [O] |
| O-05 | Définir méthode et données requises du coût de revient | [O] |
| O-06 | Définir moyens de paiement, remboursements et rapprochement | [O] |
| O-07 | Confirmer les tarifs mensuels ACCÈS/PREMIUM et leurs montants annuels (10 mensualités pour 12 mois) | [O] |
| O-08 | Décider l'exception éventuelle QR / GRILLAD Connect à la vente directe | [B] |
| O-09 | Décider du pointage GPS et de la preuve de présence | [O] |
| O-10 | Décider langues, Fulfulde, notifications, Livechat et NAXA SECURITY | [O] |
| O-11 | Fixer reçus, imprimantes, exports et conservation | [O] |
| O-12 | Finaliser rôles et permissions | [O] |
| O-13 | Définir les transferts intersites autorisés | [O] |
| O-14 | Confirmer les éventuels plafonds de points de vente PREMIUM et de vendeurs par point, s'ils existent | [O] |
| O-15 | Fixer le modèle de caisse d'un point employant plusieurs vendeurs (caisse commune ou sessions/tiroirs par vendeur) | [O] |

---

**Référence de continuité :** [GRILLAD — Document de continuité et de passation](../passations/GRILLAD_CONTINUITE_2026-11-21.md).  
**Important :** cette version consolide les exigences documentaires. Elle ne constitue pas une déclaration de fonctionnalités implémentées ou disponibles en production.
