# GRILLAD — Cahier des charges fonctionnel V1.1

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

## 3. Organisation des points de vente et du multisite

### 3.1 Trois configurations Manager historiques [V — FAM-009]

Ces trois configurations sont enregistrées dans le registre Famille NAXA et doivent être conservées :

1. Manager autonome sur un lieu, sans vendeur obligatoire.
2. Manager et un vendeur sur un lieu.
3. Manager supervisant plusieurs vendeurs sur plusieurs lieux physiques précis.

Elles définissent les configurations opérationnelles et humaines ; elles ne remplacent pas les modes de gestion des données ci-dessous.

### 3.2 Deux modes de gestion des données [V]

| Mode | Fonctionnement | Visibilité |
|---|---|---|
| Indépendant | Chaque établissement pilote son catalogue autorisé, ses prix, employés, préparations, stocks, ventes, caisse, dépenses et rapports. | Les consultations croisées sont limitées aux comptes explicitement autorisés. |
| Centralisé | Le promoteur partage certains paramètres et accède à des rapports consolidés. Chaque établissement conserve ses opérations et données sources. | La consolidation dépend des rôles et des droits ; un manager local ne voit pas automatiquement les autres sites. |

Le mode centralisé ne fusionne jamais les caisses, stocks ou recettes des sites.

### 3.3 Données rattachées à un lieu

Chaque vente, ligne de vente, encaissement, préparation, dépense, achat, mouvement de stock, session de caisse, affectation de personnel et rapport doit contenir une référence à l'organisation et au lieu concernés.

Les transferts entre sites ne sont pas autorisés implicitement par l'existence du multisite.

- Le transfert d'intrants est décrit dans V1.0 comme une possibilité [C].
- Le transfert de produits déjà préparés reste [O].
- Tout transfert validé doit avoir un site source, un site destinataire, une quantité, une date, un auteur et une preuve de réception.

### 3.4 Isolation et consolidation

- Un vendeur n'accède qu'aux sites qui lui sont affectés.
- Un responsable local ne voit que son site, sauf délégation explicite.
- Le promoteur peut consulter les agrégats et détails permis par ses rôles.
- Les données non synchronisées doivent être signalées comme partielles.
- Aucune consolidation ne doit supprimer la ventilation par site.

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

## 8. Abonnements et tarifs GRILLAD

### 8.1 Règles commerciales de référence [V]

Le registre Famille NAXA et la continuité générale fixent une seule souscription Promoteur couvrant tout son réseau GRILLAD. Le montant est global, pas multiplié par site, vendeur, salarié ou appareil.

Périodicités autorisées : mensuelle ou annuelle uniquement. Pour une souscription annuelle éligible, 12 mois de service coûtent 10 mensualités. Aucune offre de 3 ou 6 mois.

### 8.2 Grille mensuelle validée [V]

| Points de vente actifs du réseau | Formule | Montant mensuel global |
|---:|---|---:|
| 1 | ACCÈS | 1 500 FCFA |
| 2 à 5 | PREMIUM | 3 000 FCFA |
| 6 à 10 | PRO | 5 000 FCFA |
| 11 à 25 | PRO | 10 000 FCFA |
| 26 à 50 | PRO | 15 000 FCFA |
| 51 à 100 | PRO | 25 000 FCFA |
| Plus de 100 | Sur devis | Sur devis |

L'équivalent annuel calculé au tarif de 10 mensualités est respectivement 15 000, 30 000, 50 000, 100 000, 150 000 et 250 000 FCFA pour les paliers chiffrés. Plus de 100 points demeure sur devis.

Les points brouillon, archivés ou désactivés ne comptent pas comme points actifs. Le nombre retenu doit être calculé côté serveur sur la base des points actifs autorisés.

### 8.3 Règles de changement de palier [O]

Avant facturation automatisée, décider :

- effet immédiat ou à la prochaine échéance ;
- éventuel prorata ;
- traitement d'une diminution du nombre de sites ;
- remboursement ou absence de remboursement ;
- période de grâce en cas d'échec de paiement ;
- traitement des sites suspendus et archivés.

Aucun prorata ni remboursement ne doit être inventé. La formulation ancienne « PRO illimité » ne doit pas prévaloir sur le tableau plus récent §6.17.14, qui limite les paliers chiffrés à 100 points et prévoit un devis au-delà.

### 8.4 Modèle technique attendu

Le modèle de facturation à utiliser, sous réserve de compatibilité avec le service canonique Famille NAXA, est :

**Plan → Subscription → Payment → Entitlements**

Le serveur confirme le paiement et active les droits. Les droits commerciaux sont séparés des rôles et permissions. Aucun entitlement ne doit être accordé par un simple changement local d'écran ou de cache.

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
| Organisation | Identité, propriétaire, état, paramètres, abonnement |
| Établissement | Organisation, nom, adresse, coordonnées du lieu, statut, mode |
| Utilisateur / membre | Identité applicative, statut, affectations |
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
| Équipe | utilisateurs, rôles, permissions, affectations par site |
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
| O-07 | Définir l'effet du changement de palier d'abonnement en cours de période | [O] |
| O-08 | Décider l'exception éventuelle QR / GRILLAD Connect à la vente directe | [B] |
| O-09 | Décider du pointage GPS et de la preuve de présence | [O] |
| O-10 | Décider langues, Fulfulde, notifications, Livechat et NAXA SECURITY | [O] |
| O-11 | Fixer reçus, imprimantes, exports et conservation | [O] |
| O-12 | Finaliser rôles et permissions | [O] |
| O-13 | Définir les transferts intersites autorisés | [O] |
| O-14 | Confirmer l'unité de comptage des points de vente actifs du réseau | [O] |

---

**Référence de continuité :** [GRILLAD — Document de continuité et de passation](../passations/GRILLAD_CONTINUITE_2026-11-21.md).  
**Important :** cette version consolide les exigences documentaires. Elle ne constitue pas une déclaration de fonctionnalités implémentées ou disponibles en production.
