# GRILLAD — Document de continuité et de passation

**Référence :** GRILLAD / FAMILLE NAXA  
**Date de consolidation :** 21 novembre 2026  
**Dépôt :** audreymendomo23-netizen/FAMILLE-NAXA  
**Branche de référence :** main  
**Statut :** passation documentaire établie ; les points explicitement marqués ouverts restent à arbitrer  
**Cahier associé :** [GRILLAD — Cahier des charges fonctionnel V1.1](../cahiers-des-charges/GRILLAD_V1_1.md)

---

## 1. Objet et règle de lecture

Ce document permet de reprendre le projet GRILLAD sans recommencer les décisions déjà établies, sans transformer une proposition en validation et sans confondre une spécification écrite avec une fonctionnalité livrée.

Les statuts utilisés sont :

- **[V] Validé :** décision directement retrouvée dans un arbitrage utilisateur ou déjà enregistrée comme décision validée dans le registre officiel du dépôt.
- **[C] Constat documentaire :** élément retrouvé dans un document de référence, mais dont la validation primaire n'a pas pu être retrouvée indépendamment.
- **[P] Proposition :** recommandation d'enrichissement ou choix de conception qui n'est pas une décision approuvée.
- **[O] Ouvert :** décision nécessaire qui n'est pas encore suffisamment établie.
- **[B] Bloqué :** sujet qui ne doit pas être intégré au périmètre actif tant que la contradiction ou l'autorisation n'est pas levée.

**Règle impérative :** la mention [V] n'affirme jamais qu'une fonctionnalité est développée. La livraison logicielle est un état séparé, qui doit être établi par des preuves techniques et une recette opérationnelle.

## 2. Périmètre réel de l'audit documentaire

### 2.1 Sources examinées

La consolidation a confronté les sources accessibles suivantes :

1. Les arbitrages GRILLAD visibles dans les échanges récents, notamment les cinq décisions sur les familles d'activité, la vente directe, le suivi simple des quantités, les modes multisites et le périmètre financier.
2. Le document de 15 pages **GRILLAD_Cahier_des_charges_fonctionnel_v1.docx**, daté du 21 novembre 2026, retrouvé dans la bibliothèque documentaire et lu dans son intégralité textuelle.
3. Le registre [docs/DECISIONS.md](../DECISIONS.md), notamment FAM-007, FAM-008, FAM-009 et FAM-020.
4. La continuité générale [docs/CONTINUITE.md](../CONTINUITE.md), notamment la description historique de GRILLAD, les configurations Manager et la grille tarifaire du §6.17.14.
5. Les règles du dépôt AGENTS.md, le README et l'architecture cible.
6. Le texte de l'audit NAXA SERVICES du 21 novembre, uniquement pour établir les limites réelles des composants mutualisables cités dans les propositions ZIPPLE–GRILLAD.
7. L'analyse stratégique ZIPPLE–GRILLAD reproduite dans l'échange courant. Elle a été traitée comme une source de propositions, et non comme une preuve d'approbation de chacune de ses recommandations.

### 2.2 Limites de couverture — transparence

L'environnement de travail ne fournit pas un moteur permettant de rechercher et de relire automatiquement l'intégralité de tous les anciens journaux de conversation. L'audit a donc porté sur les échanges visibles, les résumés et éléments récents accessibles, les fichiers de la bibliothèque et les sources du dépôt consultées. **Je ne prétends pas avoir lu les transcriptions intégrales de toutes les conversations historiques.**

Le dépôt main référence les anciens chemins 7 famille naxa/01-cahiers-des-charges/08-grillad.md et 7 famille naxa/02-prompts/08-grillad.md dans sa continuité, mais le fichier de cahier 08-grillad.md n'a pas été retrouvé dans la liste actuelle du répertoire historique consulté. Le présent cahier constitue donc le premier référentiel GRILLAD consolidé retrouvé dans docs/cahiers-des-charges.

Les répertoires apps/android/grillad et apps/web/grillad existent sur main. Leur présence ne prouve pas que les parcours métier sont implémentés. Cette mission était un audit documentaire et une mise à jour de référentiel : elle n'a pas exécuté de build, de test métier, de test serveur, de test RLS, de recette sur appareil ni d'audit exhaustif du code GRILLAD. Aucun statut de livraison logicielle n'est attribué ici.

## 3. Décisions GRILLAD confirmées

Les cinq décisions suivantes ont été retrouvées dans les arbitrages récents de l'utilisateur. Elles constituent la baseline métier à ne pas modifier sans nouvelle décision.

| ID | Décision | Conséquence obligatoire |
|---|---|---|
| GRD-001 | **Cinq familles strictes : porc, poulet, poisson, brochettes, omelettes.** [V] | Aucun sixième métier ou famille de vente dans le catalogue GRILLAD. Référence complémentaire FAM-008. |
| GRD-002 | **Vente directe uniquement.** [V] | Pas de réservation, précommande, vente à distance, marketplace, agrégateur, livraison ou prise de commande par un tiers dans la baseline. |
| GRD-003 | **Suivi simple des quantités préparées et vendues.** [V] | Afficher le préparé, le vendu et le restant. Pas de chaîne avancée de cuisson, de traçabilité de lots ou de rendement de production complexe. |
| GRD-004 | **Gestion mono/multisite avec deux modes : indépendant et centralisé, et des droits configurables.** [V] | Les accès et rapports sont contrôlés ; les opérations sources restent rattachées au site concerné. |
| GRD-005 | **Périmètre financier : caisse, dépenses, coûts de revient et marges.** [V] | Les données sources doivent permettre le suivi de l'encaissement et l'estimation explicable de la rentabilité. Ce n'est pas une validation d'une comptabilité certifiée. |

Le choix du nom GRILLAD est retenu dans FAM-007 [V]. La disponibilité juridique de la marque et du domaine n'est pas prouvée par le présent audit.

## 4. Décisions historiques conservées dans le dépôt

Les décisions suivantes sont déjà portées par le registre et la continuité Famille NAXA. Elles doivent être conservées jusqu'à éventuelle modification explicite.

### 4.1 Trois configurations opérationnelles Manager — FAM-009 [V]

La continuité générale décrit trois configurations d'organisation du travail :

1. **Manager autonome sur un lieu :** pas de vendeur obligatoire.
2. **Manager et un vendeur sur un lieu.**
3. **Manager supervisant plusieurs vendeurs sur plusieurs lieux physiques précis.**

Chaque affectation, session, stock, caisse, vente et dépense doit être rattaché à un lieu autorisé. Les stocks et caisses de lieux distincts ne se mélangent jamais.

Cette décision n'est pas contradictoire avec GRD-004. Les trois configurations décrivent l'organisation humaine et opérationnelle ; les deux modes indépendant/centralisé décrivent la manière de gérer et consolider les données. Ce sont deux axes différents. Le cahier associé les conserve séparément.

La continuité historique parle de lieux physiques géolocalisés. Cela désigne l'identification et la localisation des établissements, et ne vaut pas approbation d'un suivi GPS permanent du personnel.

### 4.2 Abonnement global Promoteur et périodicité — FAM-020 [V]

La règle tarifaire commune du portefeuille est :

- abonnements mensuels ou annuels uniquement ;
- un abonnement annuel récurrent donne 12 mois de service pour le prix de 10 mensualités ;
- aucun forfait de 3 ou 6 mois ;
- une modification commerciale ne doit pas être appliquée rétroactivement à une période déjà payée.

Pour GRILLAD, la continuité générale précise qu'une seule souscription Promoteur couvre le réseau GRILLAD. Aucun deuxième abonnement ne doit être facturé automatiquement par point de vente, employé, appareil ou site.

### 4.3 Grille tarifaire GRILLAD — continuité générale, §6.17.14 [V]

La grille mensuelle inscrite dans la continuité comme arbitrage tarifaire validé est la suivante :

| Points de vente actifs du réseau Promoteur | Formule | Montant mensuel global |
|---:|---|---:|
| 1 | ACCÈS | 1 500 FCFA |
| 2 à 5 | PREMIUM | 3 000 FCFA |
| 6 à 10 | PRO | 5 000 FCFA |
| 11 à 25 | PRO | 10 000 FCFA |
| 26 à 50 | PRO | 15 000 FCFA |
| 51 à 100 | PRO | 25 000 FCFA |
| Plus de 100 | Sur devis | Sur devis |

Le montant est global pour le réseau Promoteur et n'est pas multiplié par le nombre de sites. Les points brouillon, archivés ou désactivés ne sont pas comptés comme actifs.

Sur la base de FAM-020, les équivalents annuels sont calculés à 10 mensualités pour 12 mois de service : 15 000, 30 000, 50 000, 100 000, 150 000 et 250 000 FCFA pour les tranches tarifées ci-dessus. Le palier supérieur à 100 reste sur devis.

**Contradiction à retenir et non à masquer :** une formulation plus ancienne du §6.17.5 présente PRO comme une capacité illimitée de points de vente, alors que le tableau plus récent du §6.17.14 borne les paliers à 100 points et prévoit un devis au-delà. Le §6.17.14 est daté du 20 novembre 2026 et indique expressément remplacer les anciennes grilles. Il prévaut donc pour les montants et tranches. La capacité « illimitée » ne doit pas être codée comme une promesse commerciale en contradiction avec le plafond tarifaire sans nouvel arbitrage.

**Ouvert :** date d'effet d'un changement de palier en cours de période, application immédiate ou prochaine échéance, prorata et remboursement. Aucun calcul de prorata ne doit être inventé.

## 5. Éléments écrits comme validés dans GRILLAD V1.0, mais à confirmer

Le document V1.0 du 21 novembre énonce huit arbitrages comme validés. Les cinq décisions GRD-001 à GRD-005 ci-dessus sont confirmées par les échanges récents accessibles. Les trois éléments ci-dessous figurent dans V1.0, mais la preuve primaire d'un arbitrage utilisateur distinct n'a pas pu être retrouvée dans les échanges et pièces actuellement accessibles.

Ils sont donc conservés comme **[C] consignés dans V1.0 / [O] validation primaire à confirmer**, et non supprimés ni transformés abusivement en décisions irrévocables :

1. **Parrainage par QR code, suivi des filleuls et commissions.** Le mécanisme générique est décrit dans V1.0, mais les bénéficiaires éligibles, l'événement déclencheur, les taux ou montants, seuils, délais, paiement et règles de renouvellement restent ouverts.
2. **Assistant IA GRILLAD complet.** V1.0 décrit un assistant d'analyse et d'aide au pilotage. Les cas d'usage, données exploitables, profils habilités, capacités hors connexion et fournisseurs ne sont pas fixés dans une décision primaire retrouvée.
3. **Fonctionnement hors connexion étendu et synchronisation différée.** V1.0 le mentionne comme arbitrage validé, mais le périmètre exact des opérations autorisées hors ligne, les conflits, les durées de tolérance et le verrouillage après expiration ne sont pas arbitrés.

La confirmation de ces trois sujets doit être obtenue avant de les qualifier de baseline définitivement gelée. En attendant, les règles de sécurité, d'idempotence et de traçabilité figurant dans V1.0 restent des exigences de conception prudentes, pas une preuve de service opérationnel.

## 6. Contradictions et arbitrages à ne pas perdre

| Sujet | Constat | Traitement retenu |
|---|---|---|
| Cinq familles et vente simultanée dans un même site | Les cinq familles sont validées. L'affirmation « les cinq doivent être actives simultanément sur tout point de vente » vient d'une recommandation, et non d'un arbitrage utilisateur distinct retrouvé. | Catalogue limité aux cinq familles [V] ; activation simultanée des cinq sur un même site [O]. |
| Trois configurations Manager vs deux modes multisites | Les notions sont différentes. | Conserver les trois configurations humaines FAM-009 et les deux modes de données GRD-004. |
| Suivi de préparation vs production avancée | L'arbitrage récent demande un suivi simple. V1.0 exclut la chaîne avancée. | Quantité préparée, vendue, ajustements justifiés et restant seulement. |
| Ventes directes vs QR GRILLAD Connect depuis ZIPPLE | Le QR partenaire et la prise de commande distante/tiers peuvent contredire les exclusions de GRD-002. | Intégration ZIPPLE–GRILLAD bloquée [B] comme périmètre de livraison jusqu'à validation d'une exception explicite. |
| « Premium GRILLAD » pour le QR | La proposition stratégique propose un droit Premium pour activer les commandes partenaires, mais la grille tarifaire GRILLAD existante n'explique pas complètement les capacités incluses de chaque formule. | Ne pas créer un droit ni un supplément d'abonnement par supposition. |
| Parrainage GRILLAD et parrainage NAXA SERVICES | Les règles plus précises de NAXA SERVICES ne constituent pas des décisions GRILLAD. | Ne pas copier les récompenses NAXA SERVICES. Faire arbitrer le programme GRILLAD. |
| Localisation d'un établissement vs GPS du personnel | La localisation du lieu est présente dans la continuité historique ; le pointage GPS du personnel est explicitement ouvert dans V1.0. | Ne pas assimiler les deux. Aucun suivi permanent du personnel. |
| Modules transversaux | L'audit NAXA SERVICES constate que le chat humain, les notifications distantes complètes, le Fulfulde et les webhooks ne sont pas tous opérationnels de bout en bout. | Mutualiser des composants après audit, mais ne jamais les déclarer livrés ou disponibles à GRILLAD sans preuve. |

## 7. Propositions ZIPPLE–GRILLAD conservées hors baseline

L'analyse stratégique fournie dans l'échange propose des enrichissements pertinents. Ils sont conservés comme pistes de conception et non comme fonctionnalités validées.

### 7.1 Services partenaires / GRILLAD Connect — [P]/[B]

Proposition : l'Espace Bar de ZIPPLE présenterait une entrée « Services partenaires », avec GRILLAD comme premier partenaire. Un QR de table pourrait présenter la carte du bar et les grillades partenaires.

En cas d'approbation ultérieure, les frontières suivantes devront être garanties :

- ZIPPLE et GRILLAD restent deux applications et deux commerçants autonomes.
- Deux catalogues, deux paniers, deux références, deux commandes, deux stocks et deux historiques.
- Le vendeur GRILLAD reste propriétaire de son catalogue, de sa commande et de sa préparation.
- Chaque entreprise encaisse directement sa propre vente ; aucune commission ni caisse commune n'est créée sans accord commercial distinct.
- L'association entre un bar et un vendeur exige l'accord des deux organisations.
- L'accès partenaire est contrôlé par un entitlement GRILLAD serveur et par les droits ZIPPLE du bar.
- Les données financières internes, marges, stocks détaillés et coûts de GRILLAD ne sont pas visibles depuis ZIPPLE.

**Blocage préalable :** le parcours QR ne sera pas intégré dans la baseline active tant que le commanditaire n'aura pas clarifié si une commande envoyée depuis une table est considérée comme une vente directe sur place ou comme une prise de commande par un tiers / à distance. Cette clarification doit modifier explicitement GRD-002 ou définir une exception contrôlée.

### 7.2 Pointage, GPS et preuve d'arrivée/départ — [O]

Le pointage géolocalisé du personnel est explicitement non validé dans GRILLAD V1.0. La proposition à étudier est un pointage à l'arrivée et au départ, avec horodatage et preuve de présence, sans suivi continu. Elle exige une décision de périmètre, une analyse de conformité et une définition des données conservées avant développement.

### 7.3 Langues, notifications et Livechat — [P]

Le français et l'anglais, l'ajout du Fulfulde, un centre de notifications commun, les notifications push / WhatsApp et un Livechat avec transfert humain sont des propositions d'enrichissement. Ils ne sont pas présentés comme déjà disponibles dans GRILLAD.

L'audit NAXA SERVICES du 21 novembre indique que plusieurs composants transversaux — dont les notifications distantes FCM, le Livechat humain, les ressources Fulfulde et les webhooks de paiement — n'étaient pas livrés de bout en bout dans ce produit. Ces constats interdisent de supposer leur disponibilité dans GRILLAD.

### 7.4 NAXA SECURITY — [P]

L'intégration aux alertes ou aux caméras NAXA SECURITY peut être étudiée ultérieurement. Elle ne crée aucun accès automatique entre le bar et le vendeur GRILLAD, et ne fait pas partie du périmètre de GRILLAD V1.0. Les habilitations, finalités, consentements, rétention et journaux doivent être définis avant tout partage. GRILLAD n'est pas un système de vidéosurveillance.

## 8. Ce qui n'est pas établi comme livré

À la date de la présente passation :

- La présence des répertoires Android et Web n'est pas une preuve de parcours fonctionnels complets.
- Aucun build GRILLAD n'a été exécuté dans cette passe.
- Aucun test métier, test multi-sites, test hors connexion, test RLS, test de paiement ou test sur appareil physique n'a été exécuté dans cette passe.
- Le fonctionnement de l'abonnement GRILLAD et l'activation des entitlements côté serveur ne sont pas qualifiés par ce document.
- Aucun module partagé (Livechat, Fulfulde, FCM, paiement, NAXA SECURITY) n'est certifié disponible de bout en bout pour GRILLAD.
- La validation documentaire d'une fonction ne signifie ni présence dans le code, ni persistance serveur, ni disponibilité en production.

L'état logiciel reste donc **NON AUDITÉ PAR CETTE MISSION DOCUMENTAIRE**. Il ne doit pas être converti en « partiel » ou « vert » sans inspection du code et preuves correspondantes.

## 9. Ordre de reprise recommandé

1. **Geler la référence documentaire** : utiliser le cahier GRILLAD V1.1 associé à cette passation ; ne pas importer les fonctions proposées comme des décisions.
2. **Fermer les arbitrages** : confirmer les sujets listés en section 10.
3. **Auditer le code existant** : Android, Web, contrats, données locales, APIs, RLS, tests et CI ; identifier chaque fonction déjà construite avant toute correction.
4. **Construire la matrice exigences → code → test → preuve** : une ligne par exigence, avec fichier, test, résultat et lien de preuve.
5. **Traiter les lacunes par parcours complet** : ne pas livrer un écran isolé ou une fonction locale non connectée au cycle réel.
6. **Exécuter les tests d'intégration et de sécurité**, puis les recettes multi-utilisateurs, multi-sites, multi-appareils et sur appareils physiques.
7. **Mettre à jour cette passation uniquement sur preuves** ; aucune affirmation « terminé » sur la base d'une compilation seule.

## 10. Arbitrages restant à demander

| ID | Sujet | État actuel |
|---|---|---|
| O-01 | Confirmer parrainage, règles d'éligibilité et récompenses GRILLAD | [O] |
| O-02 | Confirmer les capacités et limites exactes de l'assistant IA | [O] |
| O-03 | Confirmer l'étendue réelle des opérations hors connexion | [O] |
| O-04 | Confirmer si les cinq familles doivent toutes pouvoir être actives simultanément sur le même point | [O] |
| O-05 | Fixer la méthode de calcul du coût de revient et les éléments inclus | [O] |
| O-06 | Fixer moyens de paiement, règles de caisse, fonds initial, paiements mixtes et remboursements | [O] |
| O-07 | Fixer la règle d'effet des changements de palier d'abonnement en cours de période | [O] |
| O-08 | Définir l'exception éventuelle à la vente directe pour GRILLAD Connect depuis un QR ZIPPLE | [B] |
| O-09 | Valider ou exclure le pointage GPS et la preuve d'arrivée/départ du personnel | [O] |
| O-10 | Valider langues, notifications, Livechat et éventuelle intégration NAXA SECURITY | [O] |
| O-11 | Définir reçus, impressions, conservation des données et exports | [O] |
| O-12 | Définir l'unité et le périmètre de facturation réseau Promoteur, sans contredire la grille globale | [O] |

## 11. Références du dépôt

- [Registre des décisions](../DECISIONS.md)
- [Continuité générale Famille NAXA](../CONTINUITE.md)
- [Architecture cible](../ARCHITECTURE_CIBLE.md)
- [Index documentaire](../INDEX.md)
- [Cahier GRILLAD V1.1](../cahiers-des-charges/GRILLAD_V1_1.md)

---

**Règle de reprise finale : aucun avancement de projet ne doit être annoncé comme une livraison fonctionnelle tant que le parcours complet, ses règles serveur, ses données persistées, ses permissions, ses erreurs, sa synchronisation éventuelle, ses tests automatisés et sa recette opérationnelle ne sont pas démontrés.**
