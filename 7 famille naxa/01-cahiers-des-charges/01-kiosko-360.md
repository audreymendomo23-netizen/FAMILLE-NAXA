# KIOSKO 2.0 — Cahier des charges fonctionnel et technique
## ERP Callbox 360° — The Complete Callbox Management System

| Métadonnée | Valeur |
|---|---|
| Produit | KIOSKO |
| Version | 2.0 — cadrage cible |
| Date de référence | 22 novembre 2026 |
| Marché de lancement | Cameroun |
| Écosystème NAXA Family | Fintech |
| Positionnement | ERP métier / Callbox Operating System |
| Statut | Baseline fonctionnelle approuvée pour le cadrage ; construction et conformité non encore certifiées |
| Document historique | [KIOSKO v1.0 — cahier source](01-kiosko.md) |
| Devise | Franc CFA (FCFA) |
| Langues cibles | Français et English |

> **Décision structurante :** KIOSKO évolue d'un outil de suivi Mobile Money vers un système d'exploitation complet des points de vente de proximité. Le périmètre KIOSKO 2.0 couvre l'activité financière, commerciale, humaine, logistique, administrative et sécuritaire du callbox, tout en restant utilisable par un exploitant indépendant.

---

## 0. Gouvernance du document et statut des décisions

### 0.1 Objet

Ce cahier des charges devient le référentiel fonctionnel cible de KIOSKO 2.0. Il reprend les décisions compatibles du cahier KIOSKO v1.0 du 31 octobre 2026 et de la base Kiosko v1.2, puis les étend au périmètre ERP Callbox 360° défini le 22 novembre 2026.

Le document historique 01-kiosko.md est conservé sans suppression afin de préserver la traçabilité de la version antérieure. En cas de contradiction sur le périmètre fonctionnel ou la tarification, la présente version 2.0 prévaut pour la cible produit, sous réserve des arbitrages explicitement signalés ci-dessous.

### 0.2 Légende

- **[V] Décision retenue :** élément intégré à la baseline de conception.
- **[P] Proposition de travail :** élément repris dans la cible, mais dont le montant, les modalités ou la faisabilité doivent encore être confirmés.
- **[O] Point ouvert :** décision ou information qui manque et qui doit être arbitrée avant la construction de la fonction concernée.
- **[G] Porte de validation :** contrôle juridique, contractuel, technique, sécurité ou terrain obligatoire avant activation ou commercialisation.

La validation d'un périmètre documentaire ne signifie pas que le logiciel est développé, testé, sécurisé, homologué ou conforme. Aucun statut de mise en production ne peut être déduit du présent cahier.

### 0.3 Décisions de cadrage retenues au 22 novembre 2026

1. [V] Positionnement : ERP Callbox 360°, également appelé Callbox Operating System.
2. [V] Cibles : callboxeur indépendant, propriétaire de plusieurs points de vente et gestionnaire d'un réseau d'agents.
3. [V] Les 18 modules métier décrits dans ce cahier constituent l'architecture fonctionnelle cible.
4. [V] La gestion multisite est structurante dès la conception ; elle n'est pas un ajout tardif.
5. [V] Les livres de caisse espèces, de float par réseau et de commerce doivent être distincts, rapprochables et consolidables.
6. [V] KIOSKO intègre un catalogue paramétrable de produits et de prestations, la gestion des stocks, les achats, les fournisseurs, les équipes, les clients et la rentabilité.
7. [V] Les composants réutilisables de NAXA Family sont intégrés par contrats et connecteurs ; les données et les règles métier restent cloisonnées.
8. [V] Les fonctions NAXA SECURITY sont intégrées par connecteur logiciel, sans vente de matériel ni prestation de surveillance humaine par KIOSKO.
9. [V] L'application est native Android en Kotlin et Jetpack Compose ; les espaces Web/PWA sont développés séparément sur le socle backend et les contrats métier partagés.
10. [V] Le fonctionnement hors connexion, la traçabilité et le rapprochement sont des exigences fondamentales.
11. [V] L'IA assiste et explique ; elle ne prend aucune décision financière sensible de façon autonome.
12. [V] Le prix plancher mensuel est fixé à **2 000 FCFA**. Aucun abonnement KIOSKO 2.0 n'est commercialisé à 1 000 FCFA.
13. [V] La grille mensuelle de travail est ESSENTIEL 2 000 FCFA, PLUS 2 500 FCFA, RÉSEAU 5 000 FCFA et ENTREPRISE 15 000 FCFA, avec les périmètres de la section 7.
14. [V] Les anciennes formules Essentiel 1 000 F / Services 1 500 F / Complet 3 000 F de la version historique sont abandonnées pour KIOSKO 2.0.
15. [V] Les obligations de sécurité SMS héritées de la V1 sont maintenues : aucun PIN ni OTP ne doit être extrait, conservé, affiché ou transmis.
16. [V] Le mode admin KIOSKO, historiquement utilisé pour la détection des paiements d'abonnement des applications de la famille, est conservé comme composant d'administration sécurisé tant que le parcours de paiement central n'a pas été remplacé et validé.
17. [V] L'identité visuelle KIOSKO existante reste la référence jusqu'à une décision formelle de rebranding.

### 0.4 Contradictions et héritages à traiter

- **Identité des applications :** le cahier historique évoque un compte client unique pour les sept applications. Les règles de gouvernance actuelles du monorepo imposent des applications autonomes, avec identités, parcours et permissions indépendants. [O] Le partage éventuel d'un fournisseur d'identité ou d'un SSO devra être arbitré au niveau NAXA Family. KIOSKO doit dès maintenant isoler les droits par application, organisation, site et utilisateur.
- **Console d'administration :** la V2 prévoit une console Web distincte, tandis que le cahier historique attribue à l'APK KIOSKO un mode admin de détection des paiements. Les deux peuvent coexister : la console Web pilote les opérations administratives ; le terminal Android admin sert de canal sécurisé de réception/rapprochement des SMS de paiement lorsque nécessaire.
- **Tarifs additionnels :** le prix plancher et les quatre prix de formules sont retenus. Les frais de site supplémentaire, de connecteur sécurité et les commissions partenaires sont des propositions commerciales de travail et restent à confirmer contractuellement.
- **Anciennes options :** Drive, paiements internationaux, fiscalité avancée et certaines fonctions promotionnelles restent soumises à disponibilité technique, contrat, conformité et arbitrage de packaging.

---

# 1. Vision, mission et positionnement

## 1.1 Vision

Faire de KIOSKO le système de gestion de référence des callboxes et points de services de proximité au Cameroun, puis dans les marchés africains où les opérateurs, moyens de paiement et règles locales pourront être intégrés.

KIOSKO ne sert pas uniquement à afficher un solde Orange Money ou MTN MoMo. Il donne au commerçant une vision fiable de son argent, de ses opérations, de ses produits, de ses services, de ses clients, de son personnel, de ses fournisseurs, de ses établissements et de sa rentabilité.

## 1.2 Positionnement commercial

**KIOSKO — The Complete Callbox Management System**

Promesse :

*« Ton point de vente, tes réseaux Mobile Money, tes services, tes équipes et tes finances sous contrôle, au même endroit. »*

## 1.3 Segments utilisateurs

### A. Callboxeur indépendant

Il exploite un seul point de vente. Il veut :
- suivre ses espèces et ses floats ;
- enregistrer automatiquement les opérations quand une source exploitable existe ;
- connaître ses commissions et ses marges ;
- gérer ses petits stocks et services additionnels ;
- suivre ses clients, crédits et dépenses ;
- fonctionner malgré les coupures Internet.

### B. Propriétaire de plusieurs points de vente

Il veut :
- superviser chaque site et les consolider ;
- comparer les résultats et les écarts ;
- contrôler ses équipes et les délégations ;
- déplacer des espèces, du float ou des produits entre sites ;
- définir des politiques communes ou laisser une autonomie locale ;
- accéder à ses chiffres depuis Android et Web.

### C. Gestionnaire de réseau ou d'agents

Il veut :
- standardiser les opérations ;
- organiser des responsables de zone et de site ;
- contrôler les performances et les risques ;
- suivre les approvisionnements et les fournisseurs ;
- gérer les droits, les budgets et les incidents ;
- obtenir des rapports consolidés et des alertes de pilotage.

## 1.4 Principes fondamentaux

1. **Centraliser :** un même environnement de gestion, des livres métier distincts.
2. **Tracer :** chaque opération et modification possède une source, un auteur, une date et un historique.
3. **Piloter :** consulter un point ou un réseau entier selon ses droits.
4. **Continuer hors connexion :** les opérations locales essentielles ne dépendent pas en permanence d'Internet.
5. **Rapprocher :** ne jamais confondre une donnée analysée, une donnée saisie et une opération confirmée.
6. **Automatiser avec contrôle :** les automatisations et l'IA proposent ; l'humain habilité valide les actions sensibles.
7. **Rester simple :** des parcours courts, des mots métier connus, de gros contrôles et une application légère.
8. **Séparer les métiers :** une cotisation COTIZ, un paiement de service KIOSKO et un transfert de float sont des événements métier différents, même s'ils utilisent des composants techniques communs.

---

# 2. Audit de départ et contexte concurrentiel

## 2.1 Base existante

La base documentaire antérieure est KIOSKO v1.0 du 31 octobre 2026, construite à partir de Kiosko v1.2. Elle couvre déjà le cœur Mobile Money : Orange Money, MTN MoMo, Wave selon disponibilité des SMS exploitables, transactions, espèces, float, commissions, alertes, offline, mode admin, compte mère, IA, notifications, abonnements, commerciaux et partenaires.

Le présent cahier ne constitue donc pas une reconstruction sans historique. Il étend ce socle à une gestion de commerce et de réseau complète.

## 2.2 Évaluation documentaire antérieure

Évaluation indicative du périmètre écrit, et non de la qualité d'un logiciel déployé :

| Domaine de la spécification antérieure | Évaluation de départ |
|---|---:|
| Cœur Mobile Money et floats | 9/10 |
| Caisse et commissions | 8,5/10 |
| Fonctionnement hors connexion | 9/10 |
| Multisite | 7,5/10 |
| Gestion commerciale et stocks | 6/10 |
| CRM et ressources humaines | 5,5/10 |
| Support et assistance | 3/10 |
| Sécurité physique NAXA SECURITY | 1/10 |
| Intégration NAXA Family | 5,5/10 |
| **Évaluation globale de la spécification** | **7,4/10** |

Objectif : porter le périmètre fonctionnel visé à 10/10. Cette note cible reste un objectif de conception, pas une certification.

## 2.3 Benchmark concurrentiel fourni au 22 novembre 2026

Les informations suivantes constituent un relevé documentaire de départ. Les prix et fonctionnalités doivent être revérifiés directement avant communication commerciale ou décision de positionnement.

| Solution | Offre publiquement visible dans le relevé | Prix public relevé |
|---|---|---:|
| AXE Mobile Money | Float, opérations du jour, commissions, dettes clients, alertes, offline, sauvegarde | Dès 1 000 F/mois |
| My StandBiz | Lecture SMS OM/MTN, enregistrement, historique, traçabilité et gestion d'agents | Non publié |
| Orange Money Pro | Dépôts, retraits et encaissements marchands pour partenaires Orange | Pas d'abonnement logiciel affiché |
| MoMo Agent | Dépôts, retraits, vente de crédit et forfaits, clients et rapports | Pas d'abonnement logiciel affiché |
| Kiaboo | Paiements et services digitaux centralisés, frais scolaires et tickets | Non publié |
| Opesware Mobile Money | Float, caisse, caissiers, commissions, transferts entre kiosques et offline | Sur devis |
| WiCash | Paiement, cashpoints/callboxes, marketplace, support et FAQ | Non publié |

Sources de départ :
- [AXE Mobile Money](https://axedigital.ink/metiers/mobile-money/)
- [My StandBiz — Google Play](https://play.google.com/store/apps/details?id=com.lefindex.mystandbiz)
- [Orange Money Pro — Google Play](https://play.google.com/store/apps/details?id=com.orange.money.cm.pro)
- [MoMo Agent — Google Play](https://play.google.com/store/apps/details?id=mtnft.momo.agent)
- [Kiaboo — Google Play](https://play.google.com/store/apps/details?id=net.example.kiaboo)
- [Opesware Mobile Money](https://opesware.com/solutions/mobile-money-agent-software-cameroon.html)
- [WiCash — Google Play](https://play.google.com/store/apps/details?id=com.wicash.banking)

### Enseignements

- AXE Digital rend visible un prix d'entrée à 1 000 FCFA dans le relevé historique ; KIOSKO 2.0 adopte désormais un plancher à 2 000 FCFA et doit justifier l'écart par la couverture ERP.
- My StandBiz constitue une référence concurrentielle sur la lecture des SMS et l'automatisation des saisies.
- Orange Money Pro et MoMo Agent sont des applications d'opérateur ou de réseau ; elles ne remplacent pas nécessairement le pilotage global et multi-opérateurs du propriétaire.
- Opesware confirme l'importance du float, des caissiers, des commissions et des transferts entre points.
- WiCash et les solutions voisines montrent que l'assistance et la FAQ sont également des facteurs de différenciation.

## 2.4 Références de logiciels de gestion commerciale

| Logiciel | Prix de référence fourni | Positionnement |
|---|---:|---|
| Logesco | Dès 8 000 F/mois | Ventes, stocks, caisse, clients, fournisseurs, rapports |
| Duka360 | 11 150 F/mois | Gestion commerciale intégrée |
| BelloPOS Pro | 15 700 F/mois | Caisse et gestion de commerces |
| Opesware | À partir de 9 900 F/mois sur certains produits | Logiciels spécialisés et ERP |

Références :
- [Logesco](https://logesco.com/)
- [Duka360](https://duka360.com/)
- [BelloPOS](https://bello-pos.com/)
- [Opesware](https://opesware.com/)

**Conclusion de positionnement :** KIOSKO doit rester accessible à un petit callbox, tout en offrant beaucoup plus qu'un simple suivi de float. La différenciation doit porter sur l'étendue métier, l'offline, le contrôle, le multisite, la sécurité et l'assistance, pas uniquement sur le prix.

---

# 3. Périmètre fonctionnel KIOSKO 360°

KIOSKO couvre les 18 modules ci-dessous. Les modules peuvent être livrés par jalons, mais les contrats de données, les rôles, les identifiants et les règles d'isolation doivent être prévus dès l'architecture initiale.

## MODULE 1 — Organisation, comptes et configuration

### Objectif

Créer et configurer l'activité, ses établissements, ses comptes opérateurs, ses services et ses règles de gestion.

### Fonctions

- Création de l'organisation ou de l'activité individuelle.
- Fiche du propriétaire et identité commerciale.
- Création, modification, suspension et archivage des établissements.
- Adresse, quartier, ville, région, coordonnées et géolocalisation du point.
- Identifiants et références des comptes agents par réseau.
- Numéros SIM associés, sans collecte de PIN ou code secret.
- Devise, langue, fuseau horaire et formats.
- Catalogue initial de produits, prestations et catégories.
- Paramètres des commissions, frais de service et marges.
- Paramètres financiers, seuils, plafonds et validations.
- Modèles de reçus, documents et rapports.
- Import de données depuis Excel avec prévisualisation et contrôle.
- Historique des modifications de configuration.
- Paramétrage indépendant, centralisé ou hybride.

### Règles

- Chaque organisation possède un identifiant unique.
- Chaque établissement est rattaché à une seule organisation.
- Un utilisateur ne reçoit que les droits explicitement accordés.
- Les modifications de paramètres sensibles sont tracées.
- Les importations sont validées avant intégration et doivent être annulables par écritures correctives, sans effacement de l'historique.

## MODULE 2 — Réseaux Mobile Money et opérateurs

### Réseaux prioritaires

- Orange Money.
- MTN Mobile Money.
- Wave, lorsque les conditions de lecture, d'importation ou d'intégration sont réunies.

### Réseaux et services configurables

Camtel, Nexttel, YooMee, Express Union, CAMPOST Money et autres fournisseurs ou opérateurs compatibles, selon les services effectivement accessibles et autorisés.

### Paramètres par réseau

| Champ | Description |
|---|---|
| Nom et code | Libellé et identifiant métier |
| Identifiant agent | Référence du compte ou de la SIM agent |
| Float | Solde électronique associé au réseau |
| Grille de commission | Barème applicable et date d'effet |
| Seuil minimum | Seuil d'alerte |
| Seuil cible | Niveau de float souhaité |
| Source de données | API autorisée, SMS, import ou saisie |
| État | Actif, suspendu, en attente ou indisponible |
| Dernière mise à jour | Date, heure et provenance |
| Fiabilité | État de rapprochement des données |

### Exigences

- Le moteur doit permettre d'ajouter un réseau sans reconstruire les écrans et les règles génériques de l'application.
- Les règles spécifiques à un opérateur sont configurables et versionnées.
- Les services d'un réseau indisponible ne doivent pas apparaître comme exécutables.
- KIOSKO ne prétend pas exécuter à la place d'un opérateur une opération réservée à son application ou à son canal officiel.
- Tout connecteur direct dépend d'un accès et d'un contrat réellement obtenus.

## MODULE 3 — Transactions et moteur de reconnaissance

### Familles d'opérations

| Famille | Opérations |
|---|---|
| Mobile Money | Dépôt, retrait |
| Approvisionnement | Achat et réception de float |
| Déstockage | Sortie ou vente de float selon le sens métier défini |
| Inter-callbox | C2C et transferts entre points |
| Télécoms | Achat et vente de crédit |
| Forfaits | Achat et vente de forfaits |
| Paiements | Factures et services distribués par un canal autorisé |
| Commerce | Vente de produits et prestations |
| Ajustements | Correction documentée et soumise à validation |
| Abonnements KIOSKO | Paiement du logiciel, séparé de l'exploitation agent |

### Provenance d'une opération

Chaque transaction conserve une source explicite :
- SMS détecté automatiquement ;
- SMS partagé vers KIOSKO ;
- import de fichier ;
- saisie manuelle ;
- connecteur/API autorisé ;
- confirmation issue d'un rapprochement.

### États de fiabilité

- Nouvelle / à classer.
- Analysée.
- À vérifier.
- En attente de rapprochement.
- Rapprochée.
- Contestée.
- Rejetée avec motif.
- Corrigée par une écriture compensatoire.

Une donnée automatiquement analysée n'est pas, par défaut, une opération authentifiée par l'opérateur. Une confirmation ne peut être déclarée qu'à partir d'une source ou d'un rapprochement défini.

### Chaîne de lecture SMS

1. Réception d'un SMS sur un appareil et une permission acceptés par le système.
2. Filtrage à partir des expéditeurs autorisés et des règles connues.
3. Élimination des messages classés comme contenant un PIN ou un OTP : aucun code n'est extrait, stocké, synchronisé, affiché ou transmis.
4. Analyse par règles versionnées selon le réseau et la nature du message.
5. Extraction limitée aux champs métier utiles : réseau, nature, montant, frais/commission, solde après opération, identifiant de transaction, date/heure et contrepartie masquée lorsque nécessaire.
6. Contrôle de cohérence entre ancien solde, montant et nouveau solde.
7. Dédoublonnage par identifiant de transaction et clés de secours contrôlées.
8. Enregistrement local, mise à jour des livres concernés, notification et mise en file de synchronisation.
9. Rapprochement ultérieur avec un solde, un relevé ou une confirmation officielle disponible.

### Solutions de secours

- Partage manuel d'un SMS vers KIOSKO.
- Saisie guidée.
- Import d'un relevé exploitable.
- File « À classer » pour les formats non reconnus.
- Alerte lorsqu'un trou apparaît dans la chaîne des soldes.
- Téléphone de dépannage en cas de déplacement de SIM, avec réimportation sans doublon.
- Statistiques de formats non reconnus, sans envoyer de SMS brut ni de PIN/OTP à un service externe.

### Règles financières

- Les transactions originales ne sont pas supprimées.
- Toute correction crée une écriture nouvelle, liée à l'écriture d'origine, avec motif, auteur et date.
- Un identifiant transaction opérateur ne peut pas être utilisé deux fois.
- Les opérations en attente de vérification sont visuellement distinctes.
- Un SMS partagé n'active jamais un abonnement.
- KIOSKO ne collecte ni PIN opérateur ni OTP.

### Contrôle des natures

Les effets sur caisse et float doivent être définis par type d'opération, réseau et sens :
- un dépôt client augmente les espèces et diminue le float correspondant ;
- un retrait client diminue les espèces et augmente le float correspondant ;
- un approvisionnement en float augmente le float et diminue les espèces remises au fournisseur ;
- un déstockage produit l'effet inverse selon le mouvement réellement effectué ;
- un C2C est un mouvement entre deux agents ou deux points et doit être présenté avec sa contrepartie ;
- les ventes de crédit téléphonique et de forfaits mettent à jour le stock de crédit ou le compte de distribution distinct du float Mobile Money.

Les définitions finales de déstockage et C2C doivent être documentées dans le dictionnaire métier avant leur implémentation complète. [O]

## MODULE 4 — Caisse, trésorerie et gestion des floats

### Caisse espèces

- Ouverture et clôture de journée.
- Ouverture et clôture de chaque shift.
- Fonds initial et fonds de caisse.
- Entrées, sorties, dépenses, remboursements.
- Dépôt d'espèces en banque et retrait.
- Transfert de caisse entre personnes ou sites.
- Comptage réel et solde théorique.
- Écart de caisse, commentaire et validation.
- Historique par employé et par période.
- Verrouillage logique de la clôture et écriture corrective pour toute rectification.

### Floats

- Portefeuille séparé par opérateur et par compte agent.
- Solde initial, entrées, sorties et solde théorique.
- Historique des approvisionnements et déstockages.
- Demandes, livraisons et réceptions.
- Seuil minimum, cible et prévision de rupture.
- Transferts et mouvements inter-sites.
- Commission attendue, commission constatée et écart.
- Comparaison des performances par réseau et par site.

### Tableau de trésorerie consolidé

Affiche au minimum :
- espèces disponibles ;
- float Orange Money ;
- float MTN MoMo ;
- float Wave si configuré ;
- autres floats autorisés ;
- stock de crédit téléphonique si ce stock est géré ;
- liquidité globale calculée sans additionner deux fois les mouvements internes.

Exemple illustratif non contractuel : 650 000 F d'espèces, 950 000 F Orange Money, 750 000 F MTN MoMo et 150 000 F Wave donnent une liquidité suivie de 2 500 000 F.

### Règle de séparation comptable

La caisse espèces, chaque float opérateur et la caisse commerciale constituent des livres de mouvements distincts. Le tableau de bord peut les consolider, mais ne doit jamais les confondre ni masquer les transferts internes.

## MODULE 5 — Caisse commerciale et catalogue universel

### Catalogue de prestations

**Télécommunications :** crédit, forfaits, cartes SIM, services d'identification autorisés.

**Paiements et factures :** ENEO, CAMWATER, Canal+, DStv, StarTimes et autres fournisseurs uniquement si KIOSKO dispose d'un canal de distribution ou d'une intégration autorisée.

**Services de proximité :** photocopie, impression, plastification, scan, téléchargement, saisie documentaire et assistance numérique.

**Produits :** accessoires téléphoniques, chargeurs, écouteurs, câbles, petits articles et marchandises diverses.

**Billetterie et démarches :** billets de transport, frais scolaires ou de concours et services administratifs accessibles via un partenariat autorisé.

### Fiche article/prestation

Chaque élément comprend :
- nom, description, catégorie et unité ;
- prix de vente ;
- coût d'acquisition, si applicable ;
- commission reçue, le cas échéant ;
- marge calculée ;
- mode d'encaissement ;
- statut actif/inactif ;
- fournisseur et stock, si applicable ;
- taxes ou frais paramétrables ;
- historique de prix et de ventes.

Le propriétaire peut ajouter ses propres produits et services sans modification du code de l'application.

## MODULE 6 — Stocks, achats et fournisseurs

### Gestion des produits

- Référentiel, catégories et unités.
- Références internes, codes-barres et QR si supportés.
- Numéros de série pour les articles concernés.
- Lots et dates de validité lorsque pertinents.
- Stock disponible, réservé, défectueux et en transit.
- Stock par site.
- Inventaires complets ou tournants.
- Écarts et validations.
- Alertes de seuil et rupture.
- Transferts entre sites.
- Retours, pertes, casse et articles défectueux.
- Valorisation et historique des coûts.

### Achats

- Fiches fournisseurs.
- Demandes et bons de commande.
- Réceptions totales et partielles.
- Factures et pièces justificatives.
- Coûts d'acquisition et frais annexes.
- Dettes fournisseurs et échéances.
- Retours fournisseur et litiges.
- Comparaison des fournisseurs.

Les achats centralisés doivent pouvoir être répartis entre les sites tout en conservant le coût et la provenance des marchandises.

## MODULE 7 — Clients, CRM, crédits et fidélité

### CRM

- Fiche client minimale : nom ou alias, téléphone si nécessaire, consentement et statut.
- Historique des achats et prestations.
- Historique des interactions utiles au service.
- Segmentation : nouveau, régulier, VIP ou inactif.
- Réclamations et demandes.
- Préférences de contact et historique des consentements.
- Recherche et dédoublonnage.
- Export et suppression/rectification selon les règles légales applicables.

### Crédits clients

- Crédit accordé, échéance et motif.
- Montant dû, paiement partiel et remboursement.
- Historique des relances.
- Validation des plafonds de crédit.
- Blocage ou limitation selon les règles de l'exploitant.
- Journal des modifications et litiges.

### Fidélité — intégration LOYABLE

- Moteur de points et de récompenses configurable.
- Règles par produit, prestation, période ou segment.
- Bons de réduction et avantages.
- Historique des points acquis et consommés.
- Conditions d'expiration.
- Détection des abus.

Les dépôts et retraits Mobile Money ne doivent pas générer automatiquement des points calculés sur les montants bruts. Les récompenses privilégient les ventes et prestations éligibles, selon les règles validées.

## MODULE 8 — Équipes, employés et gestion RH

### Profils fonctionnels

- Propriétaire.
- Administrateur de l'organisation.
- Responsable de site.
- Responsable régional ou superviseur.
- Caissier.
- Agent Mobile Money.
- Vendeur.
- Gestionnaire de stock.
- Comptable ou contrôleur.
- Auditeur en lecture seule.
- Support ou intervenant autorisé.

### Dossier employé

- Identité professionnelle et coordonnées nécessaires.
- Documents professionnels.
- Fonction, statut, contrat et dates.
- Organisation et établissement d'affectation.
- Rôles et permissions.
- Historique des formations.
- Objectifs et évaluations.
- Incidents professionnels avec accès restreint.

### Planification et présence

- Plannings et horaires.
- Shifts.
- Pointage entrée/sortie.
- Présences, absences, retards.
- Congés et permissions.
- Remplacements et affectations temporaires.
- Validation de feuille de temps.
- Journal des changements.

### Rémunération et motivation

- Avances.
- Primes.
- Commissions commerciales.
- Objectifs de vente.
- Historique des montants préparés et validés.
- Exports pour traitement de paie.

Le calcul complet de paie et des obligations sociales ne sera pas présenté comme certifié sans paramétrage et validation par un professionnel compétent.

### Réutilisation JOBLY

Réutiliser, selon disponibilité et compatibilité, les profils professionnels, le recrutement, l'intégration de nouveaux employés, les parcours de formation et les évaluations. KIOSKO ne devient pas un logiciel généraliste de recrutement.

La géolocalisation du pointage est facultative, justifiée par le besoin, limitée dans le temps et soumise à information et validation juridique.

## MODULE 9 — Finance, comptabilité de gestion et rentabilité

### Pilotage

- Revenus par activité, réseau, service, produit, employé et site.
- Commissions attendues et commissions réellement reçues.
- Écarts et commissions non perçues.
- Coûts d'achat et marges.
- Charges fixes et variables.
- Loyers, eau, électricité, Internet, transport, salaires, entretien et frais divers.
- Dépenses exceptionnelles.
- Budgets périodiques.
- Trésorerie actuelle et prévisionnelle.
- Résultat d'exploitation estimatif.
- Seuil de rentabilité et tendances.
- Comparaison entre prévu et réalisé.
- Consolidation multi-sites.

### Comptabilité de gestion

- Journaux d'opérations.
- Catégories de charges et produits.
- Plan de comptes compatible avec une structuration SYSCOHADA.
- Paramètres fiscaux et TVA selon les règles applicables.
- Exports PDF et Excel.
- Accès temporaire en lecture seule pour le comptable, limité à l'organisation et aux établissements autorisés.

KIOSKO est un outil de gestion et de préparation des données comptables. Il ne remplace pas, par défaut, un expert-comptable, une déclaration fiscale officielle ou un logiciel comptable certifié.

### Séparation des revenus

Les commissions d'agent Mobile Money, les commissions d'autres distributeurs, les marges commerciales et les abonnements KIOSKO sont des sources de revenu distinctes. KIOSKO ne prélève pas automatiquement une commission sur les dépôts ou retraits des clients de l'agent.

## MODULE 10 — Fournisseurs et logistique de float

Module distinct des achats de marchandises.

### Fonctions

- Répertoire des livreurs et fournisseurs de float.
- Références et contacts des chefs de secteur, selon les autorisations.
- Historique des demandes de float.
- Demande d'approvisionnement avec réseau, montant, site et urgence.
- Affectation d'un livreur.
- Montant demandé, livré et reçu.
- Heures de demande et livraison.
- Confirmation de réception.
- Écart, refus et litige.
- Historique de fiabilité du fournisseur.
- Planification des besoins.
- Alertes et message WhatsApp préparé.

Le livreur peut être un contact externe sans compte KIOSKO. Le partage d'informations est limité au nécessaire et ne donne pas accès à la comptabilité complète du site.

### Transferts inter-sites

Tout transfert d'espèces, de float ou de marchandises entre deux sites doit comporter :
- initiateur et site source ;
- destinataire et site cible ;
- montant ou quantité ;
- date, heure et motif ;
- confirmation de départ ;
- confirmation de réception ;
- écarts documentés ;
- journal d'audit.

Un transfert n'est pas considéré comme reçu uniquement parce qu'il a été déclaré expédié.

## MODULE 11 — Multisite et réseau de points de vente

### Architecture hiérarchique

Organisation / Compte mère → régions ou zones → établissements → équipes, caisses, floats, stocks et appareils.

Chaque établissement possède ses propres :
- utilisateurs et équipes ;
- caisses et shifts ;
- floats et comptes agent ;
- SIM et appareils autorisés ;
- stocks et fournisseurs locaux ;
- clients, crédits et réclamations ;
- dépenses et budgets locaux ;
- rapports et alertes.

### Trois modes d'exploitation

**Mode indépendant**
- paramétrage autonome ;
- responsables locaux ;
- consolidation consultative du propriétaire ;
- catalogue et règles locales si autorisés.

**Mode centralisé**
- tarifs et catalogue communs ;
- fournisseurs et politiques définis au siège ;
- seuils, plafonds et règles de caisse centralisés ;
- consolidation et contrôle renforcés.

**Mode hybride**
- règles et standards définis au siège ;
- marges de manœuvre locales ;
- seuils et délégations paramétrables ;
- validations distantes sur les actions sensibles.

### Fonctions multisites

- Compte mère et tableau de bord consolidé.
- Résultats par site et par période.
- Transferts d'espèces, float et stock.
- Approvisionnement centralisé.
- Budgets par site et région.
- Comparaison des performances.
- Détection de sites déficitaires ou inactifs.
- Alertes d'écarts récurrents.
- Responsables régionaux.
- Délégation temporaire et révocation.
- Historique des opérations sensibles.

Un responsable local ne voit jamais les autres établissements sans permission explicite. Les politiques RLS et les vérifications serveur doivent garantir l'isolation ; masquer un menu ne constitue pas une mesure de sécurité.

## MODULE 12 — Notifications, communication et messagerie

### Catégories

- Caisse et clôture.
- Float et ruptures.
- Commissions et rapprochements.
- Stocks, achats et commandes.
- Crédits clients et échéances.
- Dépenses et budgets.
- Personnel et shifts.
- Fournisseurs et livraisons.
- Synchronisation et sécurité.
- Abonnements et paiements.
- Support et tickets.
- Performance et coaching.

### Canaux

- Notifications locales Android.
- Notifications push via FCM.
- Centre de notifications persistant.
- WhatsApp via lien et message préparé.
- E-mail si configuré.

L'envoi automatique WhatsApp ne sera pas promis comme gratuit. Il dépend de l'API, des conditions d'accès, du consentement et des coûts éventuels.

### Briefings

- Briefing de début de journée.
- Résumé de fin de journée.
- Résumé hebdomadaire.
- Échéances et tâches.
- Alertes prioritaires non résolues.
- État de synchronisation et de sauvegarde.

Les messages suivent la langue choisie par l'utilisateur ; les canaux disposent de préférences et d'heures calmes.

## MODULE 13 — Centre d'assistance : FAQ, assistant, livechat et tickets

### FAQ

Accessible depuis l'application, avec une base locale des sujets essentiels :
- premiers pas ;
- installation et permissions Android ;
- lecture et partage des SMS ;
- dépôts et retraits ;
- caisse et floats ;
- clôtures ;
- commissions ;
- stocks et ventes ;
- employés et multisite ;
- abonnement et paiements ;
- sécurité et synchronisation.

Articles texte, illustrations, étapes et vidéos lorsque la connexion le permet.

### Assistant virtuel

- Réponses aux questions d'utilisation.
- Aide contextuelle selon l'écran.
- Orientation vers l'article pertinent.
- Explication des erreurs courantes.
- Ouverture d'un ticket si la réponse est insuffisante.
- Indication explicite lorsqu'il ne sait pas répondre.

L'assistant ne consulte pas automatiquement les transactions confidentielles pour répondre à une question générale.

### Livechat

- Accessible à partir de PLUS.
- Choix de sujet et description de la demande.
- Première orientation automatisée.
- Transfert vers un agent humain disponible.
- Historique de conversation.
- Pièces jointes autorisées.
- Numéro de ticket et suivi.
- Évaluation après résolution.

### Tickets

Statuts :
- Nouveau.
- En attente d'affectation.
- En cours.
- En attente du client.
- Transmis au service technique.
- Résolu.
- Fermé.

Catégories : abonnement non reconnu, transaction à vérifier, écart de float, perte ou restauration de données, compte bloqué, installation, synchronisation, sécurité, stock et autres demandes.

### Assistance à distance

- Diagnostic technique limité.
- Autorisation explicite et temporaire du client.
- Portée d'accès affichée avant consentement.
- Possibilité de révoquer l'accès.
- Journal des accès et actions.
- Aucun accès automatique aux détails financiers du client.
- Pas de contrôle à distance opaque du téléphone.

Les plages horaires et objectifs de réponse sont publiés selon les moyens réellement disponibles. Aucune promesse de support humain 24 h/24 n'est faite par défaut.

## MODULE 14 — Intégration NAXA SECURITY

### Objectif

Permettre au point de vente d'exploiter les alertes et événements de sécurité issus d'équipements ou d'installations compatibles déjà possédés ou gérés par le client.

### Fonctions par connecteur

- Connexion aux caméras IP et enregistreurs compatibles.
- État de fonctionnement des équipements.
- Remontée d'événements autorisés.
- Alertes de mouvement ou d'ouverture selon les capteurs disponibles.
- Consultation distante des événements autorisés.
- Déclaration d'agression, tentative d'effraction ou incident.
- Notification au propriétaire.
- Historique des incidents et mesures prises.
- Protection numérique : appareils, connexions inhabituelles, révocation et journal d'accès.
- Bouton d'alerte ou capteur compatible, si matériel et service tiers disponibles.

### Limites contractuelles

- KIOSKO/NAXA fournit le logiciel, l'intégration, la formation et le support prévus.
- KIOSKO ne vend pas de caméras, capteurs ou autres équipements.
- KIOSKO ne fournit pas de service de surveillance humaine.
- La compatibilité de chaque équipement doit être vérifiée ; aucun événement ne doit être inventé pour un équipement non compatible.
- Le connecteur KIOSKO Secure Lite ne comprend pas les équipements et ne remplace pas l'offre commerciale autonome NAXA SECURITY.

### Audio, vidéo et données personnelles

- Le traitement audio est désactivé par défaut.
- Toute activation audio, vidéo ou localisation nécessite une analyse juridique et une information adaptée.
- Les durées de conservation, personnes autorisées, accès aux enregistrements et modalités d'export sont définis et journalisés.
- Le traitement local ou hybride suit les capacités de NAXA SECURITY et les validations applicables.
- Les événements de sécurité sont cloisonnés des données commerciales et financières.

## MODULE 15 — Parrainage, partenaires et croissance

Deux programmes distincts sont prévus.

### A. Parrainage entre callboxeurs

- Code personnel.
- QR code.
- Lien de partage WhatsApp.
- Suivi du filleul.
- Statut d'activation et premier paiement.
- Historique des récompenses.
- Notifications.

Récompense de travail retenue :
- un mois offert au parrain après le premier paiement réel du filleul ;
- un mois offert au filleul ;
- plafond proposé de trois mois de récompenses par an et par parrain ;
- aucune récompense pour une simple inscription ou un essai non payé.

Les règles de cumul, de plafond, d'expiration et de fraude doivent être paramétrées et publiées.

### B. Programme Partenaire KIOSKO

Public : démarcheurs, commerciaux indépendants, apporteurs d'affaires et responsables de réseaux.

Fonctions :
- inscription et vérification du partenaire ;
- code, QR et liens d'acquisition ;
- tableau de bord ;
- liste des clients apportés et statuts d'abonnement ;
- commissions acquises, en attente et payées ;
- historique de paiement et de retrait ;
- gestion administrative des litiges.

**Commission proposée : 15 % des abonnements réellement encaissés pendant les six premiers mois payants de chaque client apporté.** Les essais gratuits et mois gratuits ne génèrent pas de commission ; une remise réduit la base réellement encaissée. Cette commission reste une proposition commerciale à confirmer dans les contrats partenaires et le modèle financier.

Protection anti-fraude :
- auto-parrainage interdit ;
- contrôles de doublons et de comptes ;
- traçabilité du partenaire d'origine ;
- détection des appareils et numéros anormalement réutilisés ;
- suspension et revue manuelle des cas suspects ;
- aucun accès du partenaire aux transactions financières détaillées de son filleul.

### C. Commerciaux et visites terrain

- fiches commerciaux ;
- rattachement à une zone ;
- objectifs et résultats ;
- visites de prospection ;
- géolocalisation du point visité lorsque nécessaire et autorisée ;
- prospects, statuts et compte-rendu ;
- historique de conversion ;
- commissions et primes selon règles approuvées.

### D. Promotions

Le moteur promotionnel hérité de la V1 comprend codes promotionnels, offres de bienvenue et roue de la chance avec lots, probabilités, stocks et journal des tirages. Le concept est conservé dans la cible ; son activation est conditionnée à l'analyse juridique, à des règles publiques, à l'anti-fraude et à une traçabilité vérifiable.

## MODULE 16 — IA et assistant de pilotage

L'IA est un outil d'aide à la décision, et non un substitut au gérant.

### IA trésorerie

- prévision de l'épuisement du float ;
- besoins de réapprovisionnement ;
- prévision de trésorerie ;
- heures de pointe ;
- propositions de répartition des floats ;
- comparaisons des besoins entre sites.

### IA de contrôle

- anomalies de caisse ;
- doublons ;
- SMS suspects ou non reconnus ;
- variations inhabituelles de commissions ;
- écarts par employé ou établissement ;
- risques de rupture de stock.

### IA commerciale

- services et produits les plus rentables ;
- prévision des ventes ;
- heures faibles ;
- suggestions de services ;
- comportement de fidélité et de réachat.

### IA multisite

- comparaison et classement des établissements ;
- sites sous-performants ;
- analyse des marges ;
- anomalies récurrentes ;
- recommandations d'optimisation.

### IA administrative

- résumé quotidien et hebdomadaire ;
- préparation de rapports ;
- explication d'écarts ;
- question en langage naturel, écrit ou vocal, lorsque le canal est disponible.

### Garde-fous

- chaque recommandation explique ses raisons et son niveau de confiance ;
- priorité au calcul local lorsque possible ;
- aucune donnée brute SMS ni PIN/OTP envoyée à un fournisseur IA externe ;
- aucune annulation, validation de paiement, modification de solde, changement de rôle ou dépense sans action humaine habilitée ;
- mode dégradé lorsque l'IA en ligne est indisponible ;
- journalisation des recommandations importantes et de leur acceptation ou rejet.

## MODULE 17 — Administration centrale KIOSKO

### Console Web d'administration

- organisations et établissements ;
- comptes et accès ;
- utilisateurs, rôles et appareils ;
- formules, abonnements et échéances ;
- paiements et rapprochement ;
- validation manuelle des paiements ;
- promotions et codes ;
- partenaires et commissions ;
- commerciaux et visites ;
- tickets et FAQ ;
- notifications ;
- versions minimales des applications ;
- règles de lecture SMS versionnées ;
- statistiques techniques et formats non reconnus ;
- tableaux de bord BI ;
- audit des actions administratives.

L'administration ne doit pas disposer par défaut des transactions détaillées des clients. Les accès au support et au diagnostic sont limités au besoin, consentis et journalisés.

### Mode admin KIOSKO hérité

Le téléphone admin, exécutant KIOSKO dans un mode sécurisé distinct du mode point de vente, demeure le canal de réception et de rapprochement des paiements d'abonnement des applications NAXA Family tant que cette architecture est requise.

Le système doit :
- vérifier expéditeur officiel, montant attendu, identifiant unique et date ;
- éviter la réutilisation d'un identifiant de transaction ;
- orienter les cas ambigus vers une validation manuelle ;
- permettre un second terminal admin de secours si l'architecture le confirme ;
- tracer quel administrateur a validé, quand et sur quelle preuve ;
- ne jamais considérer un SMS partagé par un client comme une preuve d'activation.

### Paiement et abonnement

Le parcours historique par Orange Money ou MTN MoMo sur un code marchand administratif peut être conservé sous réserve de validation des contrats et des canaux réellement disponibles. Le client transmet l'identifiant de transaction ; le terminal admin et/ou un relevé autorisé rapprochent l'identifiant et le montant. Un cas non concordant est soumis à contrôle manuel et n'active pas automatiquement le service.

### Console propriétaire

- résultats et alertes de tous les sites autorisés ;
- budgets et comparatifs ;
- gestion des délégations ;
- validation à distance des actions sensibles ;
- suivi des employés et des stocks ;
- rapports consolidés.

### Console support

- tickets et conversations ;
- guides et FAQ ;
- diagnostic technique autorisé ;
- statut de synchronisation et de version ;
- accès temporaire sous consentement ;
- aucune extraction non autorisée des données financières.

## MODULE 18 — Documents, reçus, rapports et exportation

Documents générés :
- reçus et tickets de vente ;
- rapports d'ouverture et de clôture ;
- états de caisse ;
- états de float par réseau ;
- rapprochements et commissions ;
- dépenses et budgets ;
- rapports de stock et achats ;
- état des crédits clients ;
- rapports RH et shifts ;
- rapports par site et consolidés ;
- compte de résultat de gestion ;
- rapports de rentabilité ;
- journaux d'audit exportables selon autorisations.

Formats :
- consultation dans l'application ;
- PDF ;
- Excel.

Chaque document indique la période, l'organisation, le site, l'utilisateur ou le responsable de génération, la date/heure et l'état de synchronisation. Les exports sont filtrés par droits ; un filigrane de nom du point et de date est conservé pour les exports appropriés.

---

# 4. Réutilisation des modules NAXA Family

KIOSKO réutilise des composants génériques après audit de compatibilité ; il ne copie pas aveuglément les modèles métier d'une autre application.

| Application source | Composants réutilisables | Adaptation KIOSKO |
|---|---|---|
| NAXA Pharmacie | Caisse, transactions, stocks, CRM, rapports, droits, notifications | Paramètres callbox, floats et opérateurs |
| NAXA Hotel | Multisite, shifts, clôtures, personnel, incidents, maintenance | Gestion des points de vente et équipes |
| COTIZ | Registres, échéances, paiements récurrents, historiques | Seulement les mécanismes génériques ; aucune opération tontine n'est convertie en transaction KIOSKO |
| NAXA SERVICES | Clients, prestations, tickets, fournisseurs, équipes, planning, commissions, support | Prestations et services de proximité |
| JOBLY | Profils professionnels, recrutement, onboarding, formation, évaluation | Cycle d'intégration des employés |
| LOYABLE | Échéances, quittances, relances, contrats, charges récurrentes | CRM, fidélité et suivi des charges éligibles |
| GRILLAD | POS, caisse, stocks, coûts, marges, dépenses, rentabilité, multisite, IA, parrainage | Caisse commerciale et pilotage du callbox |
| ZIPPLE | Catalogue, ventes, tickets, prestations, mouvements, reçus | Catalogue et vente rapide |
| CAMPUS237 | Formation, parcours d'apprentissage, communication, paiements de frais autorisés | Formation courte du personnel et apprentissage |
| NAXA SECURITY | Équipements compatibles, événements, alertes, incidents | Connecteur d'événements et sécurité |

### Règles d'intégration

1. Contrats API explicites, versionnés et documentés.
2. Identifiants de corrélation et journalisation des événements inter-applications.
3. Cloisonnement strict des données métier.
4. Permission contrôlée par application, organisation, établissement et utilisateur.
5. Une transaction COTIZ ne devient jamais une opération financière KIOSKO du seul fait qu'un registre commun existe.
6. Les services communs ne contournent pas les droits d'une application.
7. Une dépendance à une application externe ne doit pas empêcher le fonctionnement local essentiel de KIOSKO.
8. Chaque connecteur a un statut : disponible, expérimental, contractuel, suspendu ou non compatible.

---

# 5. Architecture technique cible

## 5.1 Vue d'ensemble

**Applications Android natives** : KIOSKO et les autres produits, chacune avec son identité, ses parcours et ses permissions.

**Services backend partagés** : authentification/identité selon gouvernance, autorisations, abonnements, notifications, synchronisation, audit, support et contrats d'intégration.

**Domaine métier KIOSKO** : transactions, réseaux, caisses, floats, POS, stocks, CRM, employés, multisite, rentabilité et administration.

**Interfaces Web/PWA distinctes** : console propriétaire, direction, support, commercial, partenaire et administration.

**Services externes** : opérateurs, fournisseurs, partenaires, paiements et connecteurs de sécurité autorisés.

## 5.2 Technologies recommandées

| Couche | Référence technique |
|---|---|
| Android | Kotlin natif et Jetpack Compose |
| Base locale | Room / SQLite |
| Tâches différées | WorkManager |
| Backend | Supabase / PostgreSQL |
| Sécurité serveur | RLS, fonctions serveur et vérifications de droits |
| Synchronisation | File d'événements, reprise et idempotence |
| Notifications | FCM et notifications locales |
| Web | Application responsive indépendante |
| PWA | Projet Web distinct avec service worker et cache adapté |
| Exports | Génération PDF et Excel contrôlée |
| Dépôt | GitHub, branche main selon la gouvernance du monorepo |
| Distribution Android | APK officielle signée depuis le canal officiel NAXA, sans Play Store selon la gouvernance de dépôt |

Le code Kotlin n'est pas directement convertible en Web/PWA. Les applications Web et PWA partagent le backend, les contrats API et les règles métier, mais disposent de leur propre code et de leurs propres tests.

## 5.3 Fonctionnement hors connexion

- Base locale sécurisée.
- Enregistrement local des opérations.
- File de synchronisation.
- Identifiants stables et idempotence.
- Reprise automatique au retour du réseau.
- Résolution des conflits selon règles métier.
- Indicateur de dernière synchronisation.
- Mode lecture/écriture limité selon l'état d'abonnement et la période hors ligne autorisée.
- Export local maintenu selon les règles d'accès.
- Aucune synchronisation d'un SMS brut contenant des secrets.

Tolérance de travail :
- ESSENTIEL : 7 jours ;
- PLUS : 14 jours ;
- RÉSEAU : 14 jours ;
- ENTREPRISE : 14 jours.

Ces durées devront être confirmées par les tests de sécurité, la stratégie serveur et la politique de conservation.

## 5.4 Sécurité applicative et des données

- Isolation des organisations et des sites.
- Contrôle serveur des droits ; RLS en défense complémentaire.
- Refus par défaut des accès non explicitement autorisés.
- Aucune clé privilégiée dans le client.
- Chiffrement des données sensibles en transit et au repos selon les capacités de la plateforme.
- Journal d'audit des actions sensibles.
- Authentification renforcée pour les administrateurs.
- Gestion des appareils autorisés et révocation à distance.
- Détection de recul d'horloge et d'appareil incohérent.
- Sauvegardes et restauration testées.
- Séparation des données support, sécurité, finance et CRM.
- Politique de conservation et de suppression.
- Journalisation de consentement pour les permissions sensibles.
- Signature APK, vérification de l'empreinte et obfuscation selon le pipeline.
- Mise à jour contrôlée et version minimale supportée.

Héritage de la V1 à préserver ou à confirmer par la recette : deux appareils actifs maximum par point ; à l'arrivée d'un troisième, fermeture du plus ancien et notification au propriétaire. Le modèle exact d'appareils doit être vérifié avec les besoins multisites.

## 5.5 Lecture SMS et distribution Android

Les permissions SMS sont strictement encadrées par Android et les règles de distribution. La distribution directe APK officielle est la stratégie documentaire actuelle du dépôt ; elle impose une page officielle, une empreinte vérifiable, une signature conservée en sécurité, un guide d'installation, une procédure de mise à jour et des avertissements clairs.

[G] Avant d'activer la lecture automatique, effectuer une revue des règles Android applicables, des permissions restreintes, des exigences d'installation et des contrats des opérateurs. La possibilité technique d'analyser un SMS n'est pas une autorisation de traiter n'importe quelle donnée.

## 5.6 Performance et accessibilité

- Téléphones Android d'entrée de gamme.
- Démarrage et ouverture des écrans clés rapides.
- Trois actions au plus pour atteindre les fonctions principales.
- Gros boutons, textes courts, faible consommation de données et batterie.
- États visuels toujours associés à un libellé et une icône.
- Contraste texte d'au moins 4,5:1.
- Mode clair par défaut, mode sombre si prévu par la charte.
- Français et anglais dès la V1.
- Montants FCFA formatés avec séparateurs et calculs exacts au franc près.

---

# 6. Rôles, autorisations et contrôles

| Rôle | Accès attendu |
|---|---|
| Propriétaire | Pilotage global de son organisation et de ses sites |
| Administrateur organisation | Configuration et gestion déléguées |
| Responsable régional | Sites et indicateurs de sa zone |
| Responsable de site | Opérations et équipe de son site |
| Caissier | Caisse, shifts et ventes autorisées |
| Agent Mobile Money | Opérations et suivi de float selon son rôle |
| Vendeur | Catalogue, ventes et clients autorisés |
| Gestionnaire de stock | Produits, réceptions, inventaires et transferts |
| Comptable | Rapports financiers et rapprochements autorisés |
| Auditeur | Consultation, contrôles et historique en lecture seule |
| Superviseur | Contrôle des sites qui lui sont affectés |
| Commercial | Prospects, visites et statut de conversion |
| Partenaire | Uniquement ses filleuls et ses commissions |
| Support | Tickets et diagnostic autorisé, limité et journalisé |
| Admin NAXA | Administration du service, sans accès automatique à la comptabilité détaillée du client |

Chaque action sensible peut nécessiter une validation renforcée : annulation/contre-écriture, changement de droits, transfert intersite, correction de caisse, changement de seuil, remboursement, clôture, modification d'abonnement ou accès support distant.

Aucune permission ne doit être attribuée uniquement parce qu'un utilisateur possède un rôle générique. Les droits effectifs doivent être contrôlés sur le serveur.

---

# 7. Modèle commercial et tarification KIOSKO 2.0

## 7.1 Décision de prix plancher

Le tarif plancher KIOSKO 2.0 est **2 000 FCFA par mois**. L'ancien prix de 1 000 FCFA est abandonné. Il ne doit pas rester affiché dans les interfaces, pages de paiement, devis ou documents commerciaux KIOSKO 2.0.

## 7.2 Grille de formules

| Formule | Prix mensuel | Cible |
|---|---:|---|
| **KIOSKO ESSENTIEL** | **2 000 FCFA** | Callboxeur individuel |
| **KIOSKO PLUS** | **2 500 FCFA** | Callbox diversifié, vente et services annexes |
| **KIOSKO RÉSEAU** | **5 000 FCFA** | Propriétaire de plusieurs points |
| **KIOSKO ENTREPRISE** | **15 000 FCFA** | Réseau structuré et régionalisé |

Les quatre prix ci-dessus constituent la grille de travail retenue. Les obligations fiscales, les coûts réels de support, d'infrastructure et de paiement devront être intégrés au modèle financier avant le lancement commercial.

## 7.3 Contenu par formule

### KIOSKO ESSENTIEL — 2 000 FCFA/mois

Pour les callboxeurs individuels.

- 1 établissement.
- 2 utilisateurs maximum.
- Orange Money et MTN MoMo.
- Lecture SMS lorsque autorisée et saisie manuelle.
- Caisse espèces, float et commissions.
- Alertes essentielles.
- Rapports simples et exports.
- Fonctionnement hors ligne cible : 7 jours.
- FAQ hors ligne essentielle.
- Support par ticket.
- Accès aux fonctions fondamentales de sécurité et de synchronisation.

### KIOSKO PLUS — 2 500 FCFA/mois

Pour les callboxeurs qui diversifient leurs activités.

- 1 établissement.
- Jusqu'à 5 utilisateurs.
- Services additionnels configurables.
- Wave lorsque techniquement et contractuellement compatible.
- Catalogue commercial et caisse de vente.
- Stocks, achats et fournisseurs.
- CRM, crédits clients et fidélité.
- Planning et gestion des shifts.
- Rapports détaillés.
- Sauvegarde Cloud selon politique de stockage.
- Fonctionnement hors ligne cible : 14 jours.
- Livechat pendant les plages de support publiées.

L'écart de 500 FCFA entre ESSENTIEL et PLUS doit être justifié par l'activation du POS, du stock, des fournisseurs, du CRM et des outils d'équipe.

### KIOSKO RÉSEAU — 5 000 FCFA/mois

Pour les propriétaires de plusieurs points de vente.

- Jusqu'à 3 établissements inclus.
- Jusqu'à 5 utilisateurs par établissement.
- Compte mère.
- Pilotage consolidé.
- Transferts intersites.
- Contrôle des équipes et caisses.
- Budgets et comparaisons.
- BI et analyses avancées.
- Support prioritaire.
- Alertes multisites.
- Gestion centralisée ou hybride.
- Fonctionnement hors ligne cible : 14 jours.
- Assistant de pilotage selon disponibilité et quotas.

**Site supplémentaire : 500 FCFA/mois — [P] tarif additionnel à confirmer.**

### KIOSKO ENTREPRISE — 15 000 FCFA/mois

Pour les réseaux structurés.

- Jusqu'à 10 établissements.
- Utilisateurs étendus, selon capacité et contrat.
- Gestion régionale.
- Contrôle avancé des délégations.
- Rapports et exports consolidés.
- API et intégrations selon les contrats disponibles.
- Assistance prioritaire renforcée.
- Rapports personnalisables.
- Gestion avancée des incidents.
- Gouvernance multisite et budgets.
- Fonctionnement hors ligne cible : 14 jours.

**Site supplémentaire : 500 FCFA/mois — [P] tarif additionnel à confirmer.**

Les limites d'utilisateurs au-delà des forfaits explicitement chiffrés doivent être finalisées avant publication d'une grille contractuelle.

## 7.4 Options complémentaires

| Option | Prix de travail | Statut |
|---|---:|---|
| Connecteur KIOSKO Secure Lite, par site | 3 000 FCFA/mois | [P] à confirmer |
| Accompagnement avancé sur site | Sur devis | [P] |
| Migration complexe de données | Sur devis | [P] |
| Intégration spécifique avec un opérateur | Sur devis | [P] selon contrat |
| Fonction personnalisée | Sur devis | [P] |
| Formation avancée | Sur devis | [P] |

Secure Lite est limité à la connexion logicielle d'événements compatibles. Aucun matériel, intervention humaine de surveillance ou service de sécurité autonome n'est inclus.

## 7.5 Engagements de durée et réductions

Politique commerciale proposée à intégrer au moteur de facturation :

| Durée | Avantage |
|---|---|
| 1 mois | Tarif normal |
| 3 mois | 10 % de réduction |
| 6 mois | 1 mois offert |
| 12 mois | 2 mois offerts |

Le moteur doit calculer le montant avant paiement, afficher la durée couverte et l'échéance suivante. Les règles de cumul entre réduction, parrainage, code promo et offre de bienvenue doivent être explicites et non ambiguës. [O] La règle exacte de cumul reste à confirmer avant activation des promotions.

## 7.6 Essai et assistance

- 14 jours d'essai gratuit accordés par l'administration.
- Aucun moyen de paiement exigé pour démarrer l'essai.
- Onboarding à distance inclus dans le démarrage standard.
- Tutoriels et FAQ dans toutes les formules.
- Livechat à partir de PLUS.
- Support prioritaire pour RÉSEAU et ENTREPRISE.
- Aucune promesse de support humain 24 h/24 sans dispositif réellement dimensionné.
- Expiration et suspension clairement annoncées ; les données de l'utilisateur ne sont pas détruites du seul fait de l'échéance.
- Les opérations locales et exports pendant une période de suspension suivent une politique publiée et une sécurité serveur validée.

## 7.7 Changements de formule et paiement

Héritage à conserver sous réserve de validation du nouveau moteur de facturation :
- montée de formule avec calcul au prorata ;
- descente de formule à l'échéance ;
- renouvellement explicite et information claire sur le montant ;
- rapprochement des paiements par identifiant unique et montant ;
- validation manuelle des cas ambigus ;
- un SMS partagé par un client n'active jamais son abonnement.

---

# 8. Modèle économique

Les sources de revenus envisagées sont :

1. Abonnements ESSENTIEL, PLUS, RÉSEAU et ENTREPRISE.
2. Établissements supplémentaires.
3. Connecteurs et modules complémentaires.
4. Intégrations contractuelles.
5. Onboarding, formation et migration.
6. Accompagnement professionnel.
7. Partenariats de distribution.
8. Services personnalisés sur devis.

KIOSKO ne perçoit pas automatiquement une part des commissions opérateur de ses clients et ne prélève pas de commission sur les dépôts ou retraits simplement parce qu'ils sont enregistrés dans le logiciel.

Les commissions des partenaires commerciaux sont calculées sur les montants d'abonnement effectivement encaissés, selon les contrats et les règles antifraude retenus.

---

# 9. Parcours métier essentiels

## 9.1 Ouverture d'une journée

1. L'employé s'identifie.
2. Il sélectionne son site et son shift.
3. Il vérifie le fonds initial en espèces.
4. Il vérifie les soldes float disponibles ou leur dernière mise à jour.
5. Il confirme les écarts connus.
6. Le système ouvre le shift avec heure, utilisateur et appareil.

## 9.2 Opération Mobile Money reçue par SMS

1. Le système reçoit le message.
2. Le filtre exclut les messages secrets ou non autorisés.
3. Le parseur identifie la nature et les champs métier.
4. Les contrôles de cohérence et de doublon s'exécutent.
5. L'opération apparaît avec son niveau de fiabilité.
6. Les livres espèces/float sont mis à jour selon la règle confirmée.
7. Une opération douteuse reste dans la file de vérification.
8. La synchronisation a lieu lorsque le réseau revient.

## 9.3 Approvisionnement de float

1. L'employé consulte le seuil et la prévision.
2. Il prépare la demande avec réseau, montant et site.
3. Le gérant valide si le seuil de délégation l'exige.
4. Le message au fournisseur peut être préparé dans WhatsApp.
5. Le livreur livre le float.
6. L'employé confirme la somme et le mouvement d'espèces.
7. Un écart ouvre un litige.
8. Les soldes et l'historique sont mis à jour.

## 9.4 Vente commerciale et sortie de stock

1. L'utilisateur sélectionne un article ou service.
2. Le prix et le stock disponible sont contrôlés.
3. Le mode d'encaissement est choisi.
4. Le reçu est généré.
5. Le stock diminue si la vente concerne un produit stocké.
6. Le coût, le revenu et la marge sont calculés.
7. Le rapport commercial est actualisé.

## 9.5 Clôture d'un shift

1. Le caissier compte les espèces.
2. Le système calcule le montant théorique.
3. Les écarts sont affichés.
4. Le caissier indique le motif.
5. Le responsable valide lorsque nécessaire.
6. Le shift est clôturé et verrouillé.
7. Toute correction ultérieure passe par une écriture compensatoire.

## 9.6 Paiement d'abonnement

1. Le client choisit sa formule et sa durée.
2. Le montant et la période couverte sont affichés.
3. Le client effectue le paiement par le canal disponible.
4. Il saisit la référence ou l'identifiant de paiement.
5. Le système rapproche la référence, le montant et la source.
6. Le cas concordant est confirmé selon le mécanisme approuvé.
7. Les cas incertains sont transmis à l'administration.
8. L'abonnement n'est activé qu'après confirmation prévue par la politique de facturation.

---

# 10. Données et modèle métier indicatif

Les entités exactes seront normalisées au cours de la conception technique. Le socle doit couvrir au minimum les domaines suivants :

| Domaine | Entités indicatives |
|---|---|
| Organisation | organizations, outlets, regions, outlet_settings |
| Identité et accès | app_users, memberships, roles, permissions, devices, sessions |
| Réseaux | networks, agent_accounts, network_rules, commission_rules |
| Transactions | transactions, transaction_sources, transaction_matches, transaction_reversals |
| SMS | parser_rules, parser_versions, sms_processing_events ; contenu brut conservé localement uniquement si une validation de sécurité l'autorise, jamais de PIN/OTP |
| Trésorerie | cash_accounts, cash_sessions, cash_movements, wallets, float_movements |
| Approvisionnements | float_orders, float_deliveries, float_transfers, supplier_disputes |
| Catalogue | products, services, categories, price_lists |
| Stock | stock_items, stock_lots, stock_movements, inventories, purchase_orders, purchase_receipts |
| CRM | customers, customer_consents, customer_interactions, customer_credits, complaints |
| Fidélité | loyalty_accounts, loyalty_rules, loyalty_entries, rewards, vouchers |
| RH | employees, assignments, shifts, time_entries, leave_requests, incentives, evaluations |
| Finance | expense_categories, expenses, budgets, financial_periods, management_entries |
| Multisite | inter_outlet_transfers, delegations, regional_assignments |
| Notifications | notifications, notification_preferences, message_templates |
| Support | support_tickets, conversations, attachments, support_access_grants |
| Sécurité | security_devices, security_events, access_logs, incident_reports |
| Partenaires | partners, referrals, partner_commissions, partner_payouts |
| Promotions | promo_codes, promo_rules, wheel_prizes, wheel_spins |
| IA | ai_insights, forecasts, anomaly_events, recommendation_feedback |
| Abonnements | plans, subscriptions, payments, payment_matches, app_versions |
| Audit | audit_log, sync_queue, conflict_events, backup_jobs |

### Règles de données

- Toutes les tables métier sont contextualisées par organisation ; les données de site sont contextualisées par établissement lorsqu'elles s'y appliquent.
- Les clés composites ou contrôles serveur empêchent les références croisées entre organisations.
- Les événements financiers sont idempotents.
- Les opérations d'origine sont immuables ; corrections par écritures compensatoires.
- Les montants sont stockés en entiers FCFA ou selon une représentation exacte définie ; aucune imprécision flottante.
- Les heures sont stockées avec une référence temporelle fiable et affichées dans le fuseau local.
- Les données personnelles sont minimisées ; les champs optionnels ne deviennent pas obligatoires sans justification.
- Les SMS contenant PIN/OTP ne sont pas sauvegardés ni envoyés au backend.
- Les exports et sauvegardes respectent les permissions, la rétention et le chiffrement.

---

# 11. Conformité, sécurité juridique et limites opérationnelles

## 11.1 Données personnelles

[G] La conception et l'exploitation doivent intégrer une revue de conformité à la loi camerounaise n° 2024/017 du 23 décembre 2024 relative à la protection des données personnelles, ainsi qu'aux textes applicables. Il faut faire valider les bases de traitement, l'information, les consentements, les durées de conservation, les droits des personnes, les sous-traitants et les transferts éventuels.

## 11.2 Relations avec les opérateurs

[G] Avant l'activation d'une intégration directe ou du traitement de SMS d'un compte agent, vérifier les contrats d'agent, les règles de l'opérateur et les autorisations requises. KIOSKO est un logiciel de gestion et de rapprochement ; il ne se substitue pas à l'opérateur, à l'agent agréé, à un établissement financier ou à une autorisation réglementaire.

## 11.3 PIN, OTP et authentification

- Aucun PIN opérateur n'est demandé ou stocké.
- Aucun OTP n'est demandé, extrait, stocké, affiché ou transmis.
- Aucun message préparé ne contient ces codes.
- Le code d'accès KIOSKO est distinct du PIN opérateur.
- Les secrets d'authentification ne figurent pas dans les journaux ni dans les exports.

## 11.4 Caméras, audio et sécurité physique

[G] Toute fonction vidéo, audio, localisation ou suivi du personnel exige une validation de proportionnalité, d'information, de consentement ou base juridique, d'accès, de conservation et de sécurité. L'audio reste désactivé par défaut.

## 11.5 Jeux promotionnels et commissions

[G] Vérifier le cadre applicable aux promotions, tirages, cadeaux, commissions partenaires et mécanismes de parrainage avant activation publique.

## 11.6 Comptabilité et fiscalité

KIOSKO prépare des données de gestion et des exports. Les obligations fiscales et comptables applicables doivent être configurées et validées par un professionnel compétent ; aucune conformité automatique n'est revendiquée.

## 11.7 Installation APK

La distribution directe impose :
- page de téléchargement officielle ;
- signature et empreinte vérifiables ;
- conservation sécurisée du keystore hors du dépôt ;
- guide illustré ;
- vérification de l'intégrité ;
- mises à jour signées ;
- procédure de révocation et de version minimale ;
- transparence sur les paramètres Android sensibles.

---

# 12. Plan de réalisation — jalons J0 à J6

| Jalon | Périmètre | Condition de sortie |
|---|---|---|
| **J0 — Socle** | Architecture, organisations, accès, rôles, RLS, audit, synchronisation, abonnements et administration de base | Isolation et droits vérifiés |
| **J1 — Cœur financier** | Réseaux, SMS, transactions, caisse, floats, commissions et rapprochement | Exactitude, anti-doublon et tests hors ligne démontrés |
| **J2 — Commerce** | POS, services, catalogue, stocks, achats, fournisseurs, clients et crédits | Vente complète, stock et encaissement rapprochés |
| **J3 — Exploitation** | Employés, shifts, dépenses, finance, multisite et transferts | Clôtures, délégations et consolidation vérifiées |
| **J4 — Relation client** | FAQ, assistant, livechat, tickets, notifications et console support | Ticket et assistance de bout en bout |
| **J5 — Extensions** | Connecteur NAXA SECURITY, IA avancée, partenaires, parrainage et promotions | Connecteurs, sécurité et conformité validés |
| **J6 — Industrialisation** | BI, exports, performance, recette, documentation, distribution et support | Recette fonctionnelle, sécurité et exploitation terminées |

Les offres commerciales ne sont activées que lorsque les fonctions annoncées dans la formule sont effectivement disponibles et testées. La présence d'un écran ou d'un bouton ne prouve pas la disponibilité d'un service.

---

# 13. Critères de recette obligatoires

## 13.1 Transactions et SMS

1. Un même SMS reçu deux fois ne génère qu'une seule transaction.
2. Un SMS reçu hors connexion est traité localement et synchronisé sans doublon.
3. Un message contenant un PIN ou un OTP n'est ni persisté ni synchronisé ni affiché.
4. Un SMS non reconnu arrive dans la file « À classer ».
5. Un SMS partagé deux fois ne crée qu'une opération.
6. Un SMS partagé n'active jamais un abonnement.
7. Une opération incohérente est marquée « à vérifier ».
8. Une transaction corrigée conserve l'opération initiale et ajoute une écriture compensatoire.
9. Un identifiant opérateur déjà utilisé ne peut pas être rapproché une seconde fois.
10. Les opérations reçues dans le désordre ne créent pas de fausse rupture de solde.

## 13.2 Caisse, float et POS

11. Les soldes espèces et floats sont tenus dans des livres distincts.
12. Une clôture compare le théorique et le réel et trace le motif de tout écart.
13. Un employé ne peut pas supprimer librement une opération financière.
14. Une vente d'article décrémente le stock du bon site.
15. Une réception partielle d'achat ne crédite que la quantité réellement reçue.
16. Une dépense est rattachée au site et à une catégorie.
17. La marge d'une prestation et d'un produit est calculée à partir des coûts disponibles.
18. Les transferts intersites sont confirmés par l'expéditeur et le destinataire.

## 13.3 Accès et multisite

19. Un responsable ne consulte pas les établissements non autorisés.
20. Le compte mère consolide correctement les établissements de son organisation.
21. Une organisation ne peut jamais consulter les données d'une autre organisation.
22. La révocation d'un appareil bloque ses accès serveur lors de la prochaine communication.
23. Une délégation expirée ne donne plus accès aux ressources.
24. Un changement de rôle est journalisé et effectif côté serveur.

## 13.4 Offline et synchronisation

25. Une panne réseau ne bloque pas les fonctions locales prévues.
26. Une synchronisation répétée ne crée pas de doublons.
27. Un conflit est présenté et résolu selon la règle métier ; aucune écriture financière n'est écrasée silencieusement.
28. La dernière synchronisation et le nombre d'opérations en attente sont visibles.
29. Les sauvegardes sont restaurables sur un nouvel appareil.

## 13.5 Support, sécurité et IA

30. Un ticket suit son cycle complet de création à fermeture.
31. Un accès support distant n'est possible qu'après autorisation explicite et traçable.
32. Une caméra non compatible ne produit aucune fausse alerte.
33. Les événements de sécurité ne donnent pas accès aux livres financiers.
34. L'audio est désactivé par défaut.
35. L'IA ne valide pas de paiement, ne modifie pas un solde et ne change pas les droits seule.
36. Chaque recommandation importante expose son motif.
37. Aucun SMS brut ni PIN/OTP ne doit être envoyé au fournisseur IA.

## 13.6 Abonnements, documents et distribution

38. Un abonnement n'est activé qu'après rapprochement confirmé.
39. Un paiement ambigu est soumis à validation manuelle.
40. Un paiement déjà utilisé ne peut pas activer un second abonnement.
41. Les exports PDF et Excel portent le nom du site et la date.
42. Les droits d'export sont contrôlés.
43. Une version APK inférieure à la version minimale est bloquée après information et procédure de mise à jour.
44. Une APK dont la signature n'est pas reconnue ne peut pas synchroniser et déclenche une alerte.
45. Les contrats et consentements requis sont disponibles avant les fonctions qui les nécessitent.

Les tests devront être réalisés sur plusieurs téléphones Android courants, notamment pour la réception SMS écran éteint, la reprise après redémarrage, l'économie de batterie, les interruptions réseau et les volumes élevés de messages. Le corpus de test doit être anonymisé et ne contenir aucun PIN/OTP.

---

# 14. Risques principaux et mesures de maîtrise

| Risque | Mesure prévue |
|---|---|
| SMS non documentés ou modifiés par l'opérateur | Corpus réel anonymisé, règles versionnées, file « À classer », rapprochement |
| SMS falsifié ou incomplet | Source et niveau de fiabilité, contrôle de solde, validation manuelle |
| Restrictions Android sur SMS | Revue de permissions, installation officielle, consentement et alternatives manuelles |
| Panne Internet | Base locale, file de synchronisation, idempotence |
| Conflit de solde | Journaux distincts, rapprochement et écritures correctives |
| Fraude interne | Rôles, séparation des tâches, validation et audit |
| Fraude de parrainage | Identifiants uniques, contrôles des appareils, suspension manuelle |
| Rupture de float | Prévision, seuils, demandes et suivi des livraisons |
| Écarts entre sites | Confirmations bilatérales et mouvements audités |
| Mauvaise isolation des données | RLS et tests serveur multi-organisations |
| Dépendance au terminal admin | Validation manuelle Web et dispositif de secours à définir |
| Dépassement du coût infrastructure | Surveillance des volumes, sauvegardes et plan de montée en charge |
| Données personnelles et vidéos | Minimisation, revue juridique, rétention et contrôles |
| Support sous-dimensionné | SLA réalistes, priorités par formule, FAQ et assistance automatisée |

---

# 15. Points ouverts à arbitrer avant construction ou commercialisation

1. [O] Corpus anonymisé de SMS réels Orange Money, MTN MoMo, Wave et autres réseaux retenus ; expéditeurs exacts et formats autorisés.
2. [O] Définitions métier finales de déstockage, C2C et transfert inter-sites.
3. [O] Accords, contrats et permissions de traitement applicables aux opérateurs et fournisseurs.
4. [O] Identité/SSO : arbitrage entre compte commun historique et identités indépendantes prévues dans la gouvernance actuelle du monorepo.
5. [O] Architecture définitive du mode admin et du terminal de secours pour les abonnements NAXA Family.
6. [O] Vérification juridique du traitement des données, SMS, géolocalisation, vidéos, audio, parrainage et promotions.
7. [O] Disponibilité des intégrations de factures, paiements, billetterie, Wave et fournisseurs divers.
8. [O] Nombre maximum d'utilisateurs ENTREPRISE et politique d'appareils par site.
9. [O] Confirmation commerciale des 500 FCFA par site supplémentaire, du connecteur Secure Lite à 3 000 FCFA/mois et du prix des services professionnels.
10. [O] Validation contractuelle de la commission partenaire proposée à 15 % sur six mois payants.
11. [O] Règles de cumul entre réductions trimestrielles, mois gratuits, parrainage et codes promo.
12. [O] Montant minimum de retrait des commissions partenaire et calendrier de règlement.
13. [O] SLA et horaires du livechat selon les effectifs réellement disponibles.
14. [O] Fournisseur, capacité, fréquence, chiffrement et conservation des sauvegardes.
15. [O] Test terrain des prix et de la volonté de payer sur un échantillon de callboxes, sans revenir en dessous du prix plancher de 2 000 FCFA.
16. [O] Disponibilité du nom, domaine, réseaux sociaux et antériorité de marque auprès de l'OAPI.
17. [O] Stratégie d'évolution d'infrastructure lorsque l'offre gratuite ne suffit plus ; les quotas ne doivent pas être considérés comme illimités.
18. [O] Limites du mode offline après suspension d'un abonnement et durée de conservation locale des opérations.

---

# 16. Historique des tarifs et règles qui prévalent

| Référence | Grille / règle | Statut pour KIOSKO 2.0 |
|---|---|---|
| KIOSKO v1.0 / v1.2 | Essentiel 1 000 F, Services 1 500 F, Complet 3 000 F | Abandonnée ; conservée uniquement dans l'historique |
| Modèle financier historique | Basic 2 000 F, Premium 4 000 F, Pro 5 000 F | Référence historique à ne pas reprendre comme grille active |
| KIOSKO 2.0 — 22/11/2026 | ESSENTIEL 2 000 F, PLUS 2 500 F, RÉSEAU 5 000 F, ENTREPRISE 15 000 F | Grille mensuelle de référence retenue |
| KIOSKO 2.0 | Prix plancher 2 000 F/mois | Décision ferme de cadrage |
| KIOSKO 2.0 | Site supplémentaire 500 F/mois | Proposition commerciale à confirmer |
| KIOSKO 2.0 | Connecteur Secure Lite 3 000 F/mois/site | Proposition commerciale à confirmer |

---

# 17. Livrables de conception attendus pour la phase suivante

Avant développement complet, produire :
1. Cartographie détaillée des écrans Android et Web.
2. Matrice rôles × permissions × organisation × site × action.
3. Dictionnaire des données et diagramme entité-relation.
4. Contrats API et événements métier.
5. Spécification du moteur de transactions et du rapprochement.
6. Matrice des règles de calcul espèces, floats, commissions et marges.
7. Spécification d'offline, synchronisation et résolution de conflits.
8. Spécification de l'abonnement, du prorata, des promotions et des partenaires.
9. Matrice de conformité et de conservation des données.
10. Plans de tests fonctionnels, sécurité, performance et terrain.
11. Guide d'installation et d'exploitation en français et en anglais.
12. Plan de migration depuis les données KIOSKO historiques, si elles existent.

---

# 18. État de la baseline

**KIOSKO 2.0 — ERP Callbox 360°**

- [V] Le positionnement Callbox Operating System est retenu.
- [V] Les 18 modules métier constituent le périmètre cible.
- [V] Les réutilisations NAXA Family sont cadrées.
- [V] Le modèle Android natif + Web/PWA séparés + backend commun contractuel est retenu.
- [V] Les principes de traçabilité, offline, sécurité SMS et IA sous contrôle humain sont maintenus.
- [V] Le prix plancher est de 2 000 FCFA/mois.
- [V] La grille ESSENTIEL / PLUS / RÉSEAU / ENTREPRISE est fixée comme référence mensuelle de travail.
- [P] Les tarifs d'extensions et certaines commissions restent soumis à confirmation commerciale.
- [O] Les points listés en section 15 doivent être tranchés avant les modules concernés.
- [G] Les validations juridiques, opérateurs, sécurité et terrain sont obligatoires avant activation réelle.

**Objectif de conception : 10/10 sur le périmètre fonctionnel visé.** Cela ne constitue ni une preuve de développement, ni une recette technique, ni une certification de conformité.

---

## Références internes

- Cahier historique : [KIOSKO v1.0 — 31 octobre 2026](01-kiosko.md).
- Cahier de référence KIOSKO 2.0 : présent document.
- Prompts de construction historiques : [Dossier de prompts KIOSKO](../02-prompts/01-kiosko.md). Ces prompts doivent être revus et réalignés sur la présente V2 avant réutilisation pour une construction.
- Gouvernance du monorepo : AGENTS.md à la racine du dépôt.
