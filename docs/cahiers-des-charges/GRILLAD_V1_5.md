# GRILLAD — Cahier des charges fonctionnel V1.5

**Date de référence :** 27 novembre 2026  
**Produit :** GRILLAD  
**Type :** application Android native autonome de gestion des grillades, légère, soignée, sans complexité ERP  
**Dépôt de référence :** audreymendomo23-netizen/FAMILLE-NAXA  
**Statut :** référentiel fonctionnel consolidé ; décisions métier et tarifs validés intégrés, décisions historiques conservées, compléments explicitement classés [C], [P] ou [O]  
**Document de continuité :** [GRILLAD — Continuité de construction](../grillad/GRILLAD_CONTINUITE.md)

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
3. Vente directe comme canal principal, avec exception limitée GRILLAD Connect depuis ZIPPLE Snack-Bar (§2.3). [V]
4. Le suivi de préparation est volontairement simple : quantités préparées, quantités vendues et quantités restantes. [V]
5. La gestion mono/multisite dispose des modes indépendant et centralisé, avec des droits configurables. [V]
6. Le périmètre financier comprend caisse, dépenses, coûts de revient et marges. [V]
7. Les données et les opérations de chaque site restent identifiables et séparées, y compris en mode centralisé. [V]
8. Prédiction des ventes, pilotage léger, CA, rapports, notifications et point journalier sont validés ; l'analyse reste assistive et ne valide pas seule une opération sensible. L'assistant IA étendu reste à cadrer. [V/O]
9. Une spécification écrite, une maquette ou un build ne constituent pas une preuve de livraison. La recette complète est obligatoire.

### 0.3 Ce que ce document ne certifie pas

Ce cahier décrit le produit attendu ; il ne certifie pas que les fonctions existent dans les applications Android ou Web, que le backend est déployé, que les politiques RLS sont actives, que les paiements sont configurés ou que les tests ont été exécutés.

## 1. Vision et objectifs produit

**Arbitrage de simplicité (27/11/2026) [V] :** récupérer uniquement les composants de base utiles des applications de la Famille NAXA. Interface courte et adaptée à la vente ; catalogue, préparé/vendu/restant, caisse, dépenses, marge indicative, rapports synthétiques, équipe et multisite. Pas de comptabilité générale, paie avancée, workflow industriel ni ERP généraliste. Les contrôles de sécurité, fiabilité et audit restent obligatoires, sans exposer leur complexité à l'utilisateur. Les achats/intrants et coûts restent simples et les arbitrages ouverts ne sont pas inventés.

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
- Commande à distance hors exception GRILLAD Connect du §2.3, ou canal de livraison.
- Gestion de livreurs et suivi de livraison.
- Marketplace, agrégateur ou prise de commande par un tiers hors partenariat ZIPPLE Snack-Bar défini au §2.3.
- Vente de boissons, desserts, accompagnements, repas complets ou autres familles de restauration.
- Fabrication d'un ERP générique de restaurant ou de snack-bar.

Ces exclusions doivent être contrôlées dans l'expérience utilisateur, les APIs et les règles serveur, et non uniquement par masquage d'écran.

### 2.3 GRILLAD Connect — ZIPPLE Snack-Bar [V]

L'intégration au Snack-Bar ZIPPLE est désormais une exigence validée (27/11/2026) et constitue la seule exception partenaire à la vente directe. Elle ne transforme pas GRILLAD en ERP de restauration, marketplace ou service de livraison.

Parcours cible : le client scanne le QR du Snack-Bar partenaire, accède à deux espaces distincts (bar ZIPPLE et grillades GRILLAD), sélectionne les grillades disponibles chez le partenaire associé et adresse une commande à GRILLAD. ZIPPLE conserve ses commandes bar ; GRILLAD conserve ses commandes, préparation, disponibilité, encaissement et historique. Aucun panier ou paiement fusionné. Les statuts utiles sont transmis via un contrat inter-applications limité (soumise, acceptée/refusée, en préparation, prête, remise, annulée), avec identifiant commun de corrélation, idempotence et autorisations serveur.

- Partenariat bilatéral actif, droits et abonnement GRILLAD Premium actif selon règle Connect antérieure à confirmer contre le contrat ZIPPLE avant activation ; aucune nouvelle commission, surcharge ou droit tarifaire inventé.
- Sélection d'un point de vente GRILLAD habilité, catalogue publié et disponibilité réelle ; pas de sixième famille, pas de vente de boissons dans GRILLAD.
- Deux commerçants, références, paiements, reçus, stocks, caisses et chiffres d'affaires séparés.
- ZIPPLE n'accède pas aux coûts, marges, stocks internes, données RH ou photos de pointage GRILLAD.
- QR opaque/révocable, contrôle serveur du partenariat et droits, refus hors périmètre, traitement des expirations et commandes déjà engagées sans perte. Aucun accès aux autres sites.
- Contrat API, statuts définitifs, règles de disponibilité et annulation à qualifier conjointement ; aucune intégration opérationnelle présumée.


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

### 6.6 Pilotage léger, CA et rapports [V — 27/11/2026]

Un seul tableau de bord adapté au rôle : CA net des ventes confirmées, nombre de ventes, quantités préparées/vendues/restantes, encaissements, dépenses, marge et résultat indicatifs, écart de caisse, objectif de CA facultatif et progression. Afficher séparément CA et encaissements, coût inconnu et résultat estimé ; aucune comptabilité générale ni paie. Filtres simples jour/semaine/mois/année, famille, article, vendeur et site selon habilitation. Le Promoteur accède à la consolidation autorisée et à la comparaison des sites ; le vendeur voit son périmètre. Séparer les ventes directes et Connect dans les analyses sans double comptabilisation. Rapports consultables, historique et export PDF/Excel simple proposé à qualifier. Fraîcheur, période, périmètre et données partielles toujours visibles.

### 6.7 Point journalier [V — 27/11/2026]

Synthèse automatique quotidienne par point et, si autorisé, consolidée : CA net, ventes, encaissements, dépenses, marge indicative, préparé/vendu/restant, écarts de caisse, pointages manquants, alertes et comparaison à l'objectif facultatif. Proposer notification de disponibilité du rapport et consultation depuis accueil/historique. Calcul sur journée/service d'exploitation cohérent avec Africa/Douala ; l'heure de clôture et la gestion du service traversant minuit sont à paramétrer/valider (pas de clôture à minuit imposée). Synthèse provisoire si données non synchronisées, réédition versionnée après correction ; une même synthèse ne doit pas déclencher plusieurs notifications identiques. Pas de chiffres privés dans les aperçus de notifications d'écran verrouillé.

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

### 7.4 Pointage des heures, géolocalisation et photo [V — 27/11/2026]

Dans toute architecture à plusieurs niveaux de responsabilité, les collaborateurs disposent d'un pointage individuel d'arrivée et de départ, associé au point de vente et à leur compte. L'interprétation de construction proposée inclut Manager + vendeur(s) dans un point ACCÈS et réseau PREMIUM ; le Manager autonome sans personnel n'est pas soumis à un pointage obligatoire. Ce périmètre d'application précis pourra être ajusté sans changement tarifaire.

Chaque arrivée ET départ capture l'heure, une position GPS ponctuelle (latitude, longitude, précision et date de capture) et une photo prise sur le moment. Le serveur valide l'affectation, la cohérence des événements, l'heure de réception et le caractère récent des preuves ; la photo reste en stockage privé, accès limité au collaborateur et à l'encadrement habilité. Aucun GPS permanent, reconnaissance faciale ou suivi hors service. Aucune photographie accessible à ZIPPLE.

Historique individuel et par point : arrivée, départ, durée de présence calculée sur les paires validées, anomalies et pointage manquant. Un événement non confirmé n'est pas comptabilisé comme validé. Correction motivée, approuvée, historisée sans écraser l'original. Cas nuit/minuit, doublons, changement de site, absence de permission GPS/caméra ou connexion : état explicite, procédure de régularisation contrôlée ; seuil de distance/précision, rétention, exceptions et traitement offline à définir. Informer le personnel, limiter les données et vérifier la conformité avant activation. Pas de paie avancée.

Réemploi ciblé : NAXA SERVICES AttendanceProofPanel, AttendanceProofJournal, stockage privé ; ZIPPLE ZippleAttendance pour acquisition GPS ponctuelle et états de pointage. Adapter les contrats et tests à GRILLAD.

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

### 8.3 Tarifs et périodicités [V]

Les deux périodicités commerciales autorisées sont mensuelle et annuelle. Les tarifs validés sont les suivants :

| Formule | Architecture | Tarif mensuel | Tarif annuel pour 12 mois |
|---|---|---:|---:|
| ACCÈS | 1 point de vente ; plusieurs vendeurs possibles sur ce point | **2 000 FCFA** | **24 000 FCFA** |
| PREMIUM | Plusieurs points de vente ; plusieurs vendeurs possibles sur chaque point | **6 000 FCFA** | **60 000 FCFA** |

**Règle annuelle spécifique à chaque formule :**
- **ACCÈS :** 24 000 FCFA pour 12 mois, soit 12 mensualités de 2 000 FCFA. Aucun mois gratuit ni remise annuelle supplémentaire n'est inclus.
- **PREMIUM :** 60 000 FCFA pour 12 mois, soit 10 mensualités de 6 000 FCFA. Deux mois de service sont offerts.

La remise annuelle de deux mois s'applique donc à PREMIUM, mais pas à ACCÈS. Ces montants et périodicités remplacent toute grille ou règle antérieure relative aux abonnements GRILLAD.

Aucune formule de trois ou six mois n'est autorisée. Aucun supplément par vendeur, par compte utilisateur ou par point de vente ne doit être ajouté sans décision tarifaire explicite. La souscription reste rattachée au Promoteur / à l'organisation, et les droits multi-vendeurs et multisites sont contrôlés par les entitlements.

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

## 10. Prédiction et aide au pilotage [V] ; assistant étendu [C/O]

### 10.1 Prédiction des ventes et recommandations simples [V — 27/11/2026]

Prévisions du CA et des quantités vendues par jour/service, article/famille et site, avec estimation des quantités utiles à préparer et signalement des risques de rupture ou d'invendus. Prévisions de fin de journée et prochain service ; vues semaine/mois synthétiques proposées. Réemploi prioritaire de statistiques déterministes légères (historique de ventes confirmées, jours comparables, tendance, rythme courant, disponibilité) avant IA lourde. Afficher distinctement réalisé, objectif, estimation, période de référence et confiance/qualité ; si historique insuffisant, afficher « données insuffisantes », jamais une précision inventée. Tenir compte des ruptures et jours incomplets sans confondre ventes observées et demande réelle. Aucun achat, changement de prix, préparation, annulation ni engagement automatique. Aucune nouvelle tarification IA décidée.

### 10.2 Assistant étendu [C/O]

L'assistant conversationnel complet de V1.0 reste à confirmer ; le pilotage et la prédiction légère de §10.1 sont validés. Toute fonction d'analyse doit respecter les règles suivantes :

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

## 12. Langues, notifications, support et sécurité vidéo [V/O]

Notifications et vidéosurveillance multiniveau sont validées en V1.5 ; langues et Livechat restent ouverts. Aucune disponibilité opérationnelle n'est présumée.

### 12.1 Langues [O]

Le français et l'anglais peuvent constituer la base linguistique à confirmer. L'ajout du Fulfulde a été proposé, mais n'est pas figé dans la baseline GRILLAD. Une traduction complète doit être revue par des locuteurs compétents. Les noms commerciaux saisis par les établissements doivent être préservés.

### 12.2 Notifications [V — 27/11/2026]

Centre interne avec lues/non lues et accès à l'événement autorisé ; alertes pertinentes de vente/Connect, stock faible ou restant, caisse/clôture/écart, pointage manquant, objectif CA, point journalier disponible, abonnement et sécurité pour sites habilités. Notifications locales et push via le socle commun à qualifier ; WhatsApp/SMS et autres canaux externes restent à arbitrer. Préférences par catégorie, déduplication, portée site/rôle, état réel d'envoi, pas de donnée financière ou photo sensible dans l'aperçu. Pas de notification marketing sans autorisation. Aucune promesse de livraison distante avant recettes.

### 12.3 Livechat [P/O]

Un service commun pourrait proposer FAQ, assistant automatisé et transfert vers un agent humain. L'assistance logicielle Famille NAXA doit rester distincte d'une éventuelle assistance concernant une commande ou un vendeur partenaire. Les conversations sont cloisonnées par application et organisation.

Un lien WhatsApp ne vaut pas Livechat complet.

### 12.4 Vidéosurveillance multiniveau via NAXA SECURITY [V — 27/11/2026]

Module de consultation simple réservé aux architectures à plusieurs niveaux de responsabilité (interprétation cohérente avec §7.4 : Manager + vendeur(s), même mono-point ACCÈS, ou réseau PREMIUM ; accès effectif selon habilitations et droits NAXA SECURITY). Sélection du point, liste des caméras associées, direct autorisé, état connecté/hors ligne/indisponible, alertes de sécurité, historique d'incidents et accès aux extraits disponibles si autorisé. Promoteur sur ses sites autorisés, responsable sur ses sites, aucun droit vidéo vendeur par défaut. Réutiliser la passerelle NAXA SECURITY, sans reconstruire une infrastructure de vidéo ni exposer identifiants caméras, URL permanentes ou secrets au client. Liaison explicite des sites, jetons temporaires, journal d'accès, révocation et contrôle serveur de chaque flux/extrait. Aucun flux ou lien partagé avec ZIPPLE.

Caméras visibles et limitées aux zones professionnelles appropriées ; informer les personnes, exclure lieux privés/sanitaires, aucun enregistrement audio, reconnaissance faciale, analyse biométrique ou surveillance cachée ajoutés par défaut. Rétention, accès aux enregistrements, matériel compatible, coût du stockage/bande passante, conditions d'abonnement et éventuelles extensions à vérifier avant activation ; aucun quota, coût ou offre gratuite inventé. La présence du module n'implique ni installation matérielle ni service NAXA SECURITY actif. Mode hors réseau : indisponibilité explicite, pas d'image ancienne présentée comme direct.

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

1. Android natif Kotlin + Jetpack Compose, application autonome cm.naxa.grillad et APK propre ; expérience mobile principale, lisible, rapide et visuellement soignée. Aucun wrapper WebView.
2. Web responsive / PWA complémentaire conservé sans remplacer Android natif ; interfaces QR ZIPPLE et services autorisés indépendants.
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

**Directive Android native [V — 27/11/2026] :** identité propre, simplicité et excellence visuelle. Navigation compacte adaptée au rôle, opérations fréquentes accessibles immédiatement, états réseau explicites, cibles tactiles confortables. La proposition UX (non design final) et la porte de qualification Android sont précisées dans le document de continuité, §12. Aucun module validé ne disparaît ; la complexité reste derrière les services, pas dans les écrans.

Les écrans ci-dessous forment un découpage UX proposé ; la navigation finale doit être validée avec les utilisateurs de terrain.

| Espace | Écrans / capacités |
|---|---|
| Accueil / synthèse | CA, ventes, préparations, restants, dépenses, caisses, objectifs, prévisions, point journalier, alertes, état de sync |
| Organisation | profil Promoteur, établissements, modes, paramètres |
| Catalogue | cinq familles, articles, formats, unités, prix, activation |
| Service / préparation | quantités préparées, vendues, restantes par article |
| Vente | sélection rapide, panier interne de vente directe, total, remise autorisée, confirmation |
| Caisse | ouverture, opérations, paiements, clôture, écart, historique |
| Dépenses | liste, saisie, justificatifs, validation, paiement, rapport |
| Coûts / rentabilité | composition, intrants valorisés, coût estimé, marge, limites de calcul |
| Équipe | utilisateurs, rôles, permissions, affectations, pointage arrivée/départ avec GPS et photo, heures et anomalies |
| ZIPPLE Connect | association Snack-Bar, commandes grillades reçues, préparation/remise, historique distinct |
| Multisite | gestion indépendante ou centralisée, indicateurs ventilés |
| Rapports | jour/semaine/mois/année, ventes, familles, employés, dépenses, marges, caisses, données partielles |
| Prévisions et pilotage | CA prévu, quantités conseillées, objectifs et alertes simples |
| Notifications | centre interne, état lu/non lu, point journalier et événements autorisés |
| Vidéosurveillance multiniveau | sélection de site, caméras autorisées via NAXA SECURITY, direct, état et incidents |
| Parrainage | uniquement après confirmation de ce module |
| Assistant IA étendu | uniquement après confirmation de son périmètre ; prévisions et pilotage léger déjà validés |
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
| REC-28 | Vérifier les tarifs mensuels et annuels ACCÈS/PREMIUM | ACCÈS = 2 000 FCFA/mois ou 24 000 FCFA/12 mois, sans remise ; PREMIUM = 6 000 FCFA/mois ou 60 000 FCFA/12 mois, avec deux mois offerts. |
| REC-29 | Arrivée puis départ d'un vendeur affecté avec heure, GPS et photo | Deux preuves distinctes validées, durée correcte, accès privé et attribution site/vendeur. |
| REC-30 | Pointage incomplet, doublon, site non autorisé, passage de minuit | Aucun faux pointage confirmé ; anomalies/corrections tracées et durée correcte. |
| REC-31 | Scanner QR d'un Snack-Bar partenaire actif | Deux espaces distincts ; commande grillades reçue uniquement par GRILLAD habilité et statuts cohérents. |
| REC-32 | Partenaire inactif, accès inter-site, replay, deux paniers/paiements | Refus des accès non autorisés, aucun doublon, caisses/recettes/stock séparés. |
| REC-33 | Vérifier le parcours vente et préparation sur les cinq familles | Parcours léger unique, pas de module ERP complexe imposé. |

| REC-34 | Consulter caméras d'un site autorisé et tenter accès hors site/org | Flux temporaire autorisé seulement ; refus croisé, révocation, état hors ligne exact et audit. |
| REC-35 | Générer rapport jour/semaine/mois/année et comparer consolidé aux sources | CA, encaissements, dépenses et marges concordants, filtres et données partielles corrects ; pas de doublon Connect. |
| REC-36 | Déclencher événements de caisse, stock, pointage, Connect et sécurité | Notifications dédupliquées et cloisonnées ; états réels et contenu privé protégé. |
| REC-37 | Prévoir les ventes avec historique suffisant puis insuffisant/rupture | Estimations explicables, données insuffisantes signalées, aucune action automatique ni fausse certitude. |
| REC-38 | Suivre objectif et comparer CA par vendeur/site/article/famille | Réalisé, objectif et prévision distingués ; permissions et ventilation correctes. |
| REC-39 | Générer point journalier sur service traversant minuit, rejouer et corriger | Une synthèse par période/périmètre, notification non dupliquée, version corrigée et statut provisoire visibles. |

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
| O-02 | Assistant IA étendu ; paramètres de prévision à qualifier | [O] ; prédiction légère validée |
| O-03 | Réconfirmer opérations et durée de fonctionnement hors connexion | [O] |
| O-04 | Décider si les cinq familles doivent être simultanément actives sur le même site | [O] |
| O-05 | Définir méthode et données requises du coût de revient | [O] |
| O-06 | Définir moyens de paiement, remboursements et rapprochement | [O] |
| O-07 | Tarifs mensuels et annuels ACCÈS/PREMIUM | **CLOS — tarifs validés et intégrés en V1.3 / GRD-013–014** |
| O-08 | Exception ZIPPLE Snack-Bar / GRILLAD Connect | CLOS sur le principe [V] ; contrat et modalités à qualifier |
| O-09 | Pointage arrivée/départ, GPS et photo en multiniveau | CLOS sur le principe [V] ; seuils/rétention/exception à cadrer |
| O-10 | Langues, Fulfulde, Livechat ; canaux externes et modalités NAXA SECURITY | [O] ; notifications et vidéo multiniveau validées |
| O-11 | Fixer reçus, imprimantes, exports et conservation | [O] |
| O-12 | Finaliser rôles et permissions | [O] |
| O-13 | Définir les transferts intersites autorisés | [O] |
| O-14 | Confirmer les éventuels plafonds de points de vente PREMIUM et de vendeurs par point, s'ils existent | [O] |
| O-15 | Fixer le modèle de caisse d'un point employant plusieurs vendeurs (caisse commune ou sessions/tiroirs par vendeur) | [O] |

---

**Référence de continuité :** [GRILLAD — Continuité de construction](../grillad/GRILLAD_CONTINUITE.md).  
**Important :** cette version consolide les exigences documentaires. Elle ne constitue pas une déclaration de fonctionnalités implémentées ou disponibles en production.
