# BOOTIK — Cahier des charges fonctionnel et technique V1.1

> **Date de référence :** 21 novembre 2026  
> **Statut :** périmètre métier validé pour conception et construction.  
> **Priorité de réalisation :** univers Détaillants.  
> **Univers suivant :** Distributeurs, avec interconnexion prévue dès le socle.  
> **Document de continuité associé :** [BOOTIK_CONTINUITE.md](BOOTIK_CONTINUITE.md).

## 0. Objet, portée et règles de lecture

BOOTIK est un ERP commercial de gestion des points de vente et de distribution. Il couvre deux univers métier distincts — **Détaillants** et **Distributeurs** — au sein d'un même produit et d'une même fondation technique.

Le présent cahier spécifie :
- les parcours Détaillants, à construire en premier ;
- l'ensemble des fonctions ERP et CRM Distributeurs, à construire dans la phase suivante ;
- les contrats de données et d'interconnexion qui doivent exister dès la conception initiale ;
- les exigences transversales de sécurité, offline, synchronisation, facturation, audit, sauvegarde, UX, rapports et IA ;
- les critères de recette qui empêcheront les régressions.

### 0.1 Statuts

- **[V] Validé :** décision ou exigence retenue.
- **[P] Proposition :** amélioration technique à confirmer lors du design détaillé, sans réduire le périmètre validé.
- **[O] Ouvert :** détail nécessitant une décision complémentaire.
- **[C] Constaté :** information observée dans un fichier ou un audit.
- **[B] Bloqué :** dépendance empêchant une livraison réelle.

Une exigence [V] ne peut être supprimée ou réduite par choix d'implémentation. Toute évolution doit être additive ou faire l'objet d'une décision de changement documentée.

## 1. Vision produit et séparation des univers

### 1.1 Univers Détaillants [V]

Destiné aux commerces de proximité, magasins spécialisés, boutiques, points de vente multi-caisses et réseaux de magasins. Le logiciel doit couvrir la vente, la caisse, le stock, les approvisionnements, les clients, le crédit, les dépenses, le personnel, la comptabilité de gestion et le pilotage.

### 1.2 Univers Distributeurs [V]

Destiné aux grossistes, importateurs, distributeurs de marques, réseaux de distribution et opérateurs multi-entrepôts. L'ERP et le CRM doivent être complets : achats, import, entrepôts, lots, stock, ventes B2B, portefeuille de détaillants, force de vente, contrats, tarification, commandes, livraisons, crédit, recouvrement, retours, finances et analyses.

### 1.3 Cloisonnement métier [V]

- Une organisation choisit son univers et son ou ses profils à l'onboarding.
- Une organisation peut exploiter plusieurs sites et plusieurs activités.
- Chaque activité conserve un profil, un catalogue spécialisé, ses unités, ses taxes paramétrables, ses fournisseurs, ses règles de stock, ses caisses et ses indicateurs.
- Les caisses et journaux de caisse restent indépendants par activité, site, caisse et session.
- Les stocks ne sont consolidés que dans des vues autorisées ; aucun mouvement ne mélange implicitement des activités ou des propriétaires.
- Les modules communs (authentification, notifications, audit, synchronisation, billing, exports) ne fusionnent pas les règles métier.

## 2. Périmètre des profils

### 2.1 Les 14 profils Détaillants [V]

| Profil | Capacités et données spécialisées obligatoires |
|---|---|
| **Boutique** | Caisse rapide, prix détail/gros, vente à l'unité ou au conditionnement, ardoise, crédit, réapprovisionnement, fournisseurs, suivi des dettes, ventes et marges journalières. |
| **Supérette** | Codes-barres, rayons, lots, dates limites, promotions, plusieurs caisses, inventaires rapides, commandes et réassort. |
| **Poissonnerie** | Espèces, poids réel, unités, arrivages, prix du jour, fraîcheur, conditions de conservation, lots, pertes, poids préparé et poids vendable, marge par espèce. |
| **Boulangerie** | Matières premières et produits finis séparés, fiches recettes, fabrication, fournées, consommation automatique des ingrédients, lots de production, ventes, invendus, pertes et rendements. |
| **Shopping** | Vêtements, chaussures, sacs, bijoux et accessoires ; tailles, couleurs, variantes, collections, saisons, photos, prix par variante, promotions, échanges et retours. |
| **Alimentation** | Vrac et conditionné, kilogrammes, litres, sacs, cartons, unités, conversions, lots, péremptions, prix par volume et coût de revient. |
| **Cave** | Boissons alcoolisées et non alcoolisées, bouteilles, cartons, packs, casiers, fûts, consignes, retours d'emballages, lots, péremption et prix par conditionnement. |
| **Quincaillerie** | Références techniques, dimensions, diamètres, matériaux, longueurs, unités de vente multiples, conversions contrôlées, devis, commandes clients, références fournisseurs et recherche rapide. |
| **Parfumerie** | Marques, formats, contenances, lots, coffrets, testeurs, produits de valeur, dates limites, variantes, coût moyen et fidélité. |
| **Boucherie** | Espèces, morceaux, poids réceptionné, poids préparé, poids commercialisable, rendement, pertes, lots d'origine, conservation et marge par morceau. |
| **Ferme** | Produits récoltés et productions (œufs, lait et autres produits), lots, dates/heures de récolte ou collecte, quantités, pertes, conditionnement, stockage et ventes. |
| **Dépôt de gaz** | Marque, capacité, bouteille pleine/vide, état, identifiant individuel si disponible, propriétaire/détenteur, consignes/cautions, bouteilles défectueuses, retours fournisseur et livraisons. |
| **Supermarché** | Départements, rayons, nombreuses caisses et équipes, entrepôts, inventaires tournants, transferts, gestion centralisée, tarifs, promotions et pilotage par département. |
| **Brocante** | Articles neufs, anciens ou d'occasion ; article unique ou quantité multiple, état (neuf, très bon, bon, à restaurer, défectueux), photos, provenance et preuve disponible, date d'acquisition, coût, estimation, prix demandé, prix négociable, réservation, historique de prix et vente. Les biens uniques sont sérialisés et ne peuvent être vendus deux fois. |

Le profil « Shopping » inclut expressément les sacs et bijoux. Le profil Brocante fait partie des 14 profils ; il ne constitue pas une catégorie de produit universelle qui serait ajoutée aux autres activités.

Le profil historique « petite pharmacie informelle » n'est pas inclus dans les 14 profils V1.1. Il ne doit pas être recréé implicitement. Une éventuelle reprise nécessiterait un cahier séparé et une validation juridique/réglementaire ; les officines relèvent de NAXA Pharmacie et non de BOOTIK.

### 2.2 Profils Distributeurs [V]

| Profil | Capacités métier dédiées |
|---|---|
| **Boissons et brasseries** | Bières, eaux, jus, boissons gazeuses et énergétiques, bouteilles, cartons, casiers, palettes, fûts, équipements de pression confiés, territoires, quotas, allocations, ristournes et retours de contenants. |
| **Gaz et énergie domestique** | Réseaux de dépôts, marques, capacités, propriété et détention des bouteilles, pleines/vides/défectueuses, consignes, retours par marque, dépôts, véhicules et livraisons. |
| **Alimentation FMCG** | Riz, sucre, farine, céréales, huiles, pâtes, conserves, lait en poudre et produits secs ; sacs, palettes, cartons, lots, péremption, volumes et prix par canal. |
| **Frais, réfrigérés et surgelés** | Produits frais, viande, poisson, volaille, produits laitiers et surgelés ; températures, espaces frigorifiques, lots, FEFO, pertes, avaries, rappel et preuve de conservation. |
| **Hygiène et entretien** | Savons, détergents, lessives, désinfectants, papier, produits ménagers ; formats, packs, palettes, lots, péremption et tarifs réseau. |
| **Beauté et soins personnels** | Cosmétiques, parfums, soins capillaires et corporels ; marques, gammes, formats, lots, péremptions, coffrets et campagnes commerciales. |
| **Importateurs et distributeurs de marques** | Fournisseurs étrangers, commandes, devises, conteneurs, transit, dédouanement documentaire, assurance, transport, certificats, coût rendu et distribution nationale. |
| **Agro-intrants et alimentation animale** | Engrais, semences, aliments pour bétail et intrants ; lots, dates, provenance, fiches techniques, documents de conformité, stockage, territoires et traçabilité propres à la catégorie. |

Un distributeur peut activer plusieurs profils sous une même organisation. Les activités doivent toutefois rester séparables dans les droits, catalogues, stocks, coûts, documents, rapports et règles de conformité.

## 3. Organisation, sites et structure des données

### 3.1 Hiérarchie cible

Organisation → univers → activité/profil → région/zone → site ou point de vente → dépôt/entrepôt → zone de stockage → caisse/poste → session → utilisateur.

La hiérarchie peut être adaptée à la taille d'un client, mais les objets doivent être explicitement rattachés à leur organisation et à leur périmètre autorisé.

### 3.2 Multi-activité et multi-site [V]

- Plusieurs sites par organisation.
- Plusieurs activités par organisation, si autorisées au dossier.
- Plusieurs caisses par site.
- Plusieurs dépôts ou zones de stockage par site.
- Affectations des employés par site, activité, caisse et période.
- Vues consolidées uniquement pour les rôles ayant le droit de consolidation.
- Séparation des stocks, caisses et journaux ; transferts explicites avec origine, destination, articles, quantités, opérateur, approbateur et réceptionnaire.
- Les transferts sensibles exigent une confirmation de réception par le site destinataire.

### 3.3 Contrat de données extensible Distributeurs dès la phase Détaillants

La conception initiale doit prévoir les références stables suivantes, même si toutes les interfaces Distributeurs sont livrées ultérieurement :
- organisation, univers, profil métier et relations de compatibilité ;
- site, dépôt, emplacement et terminal ;
- tiers (client, détaillant, fournisseur, distributeur, transporteur) et rôles du tiers ;
- article, variante, unité, conditionnement, code-barres/GTIN, marque et catégorie ;
- lot, date, origine, propriétaire, détenteur et statut de qualité ;
- liste de prix, contrat, tarif et règle de remise ;
- stock, réservation, mouvement, transfert et inventaire ;
- devis, commande, ligne de commande, livraison, réception, retour, facture et paiement ;
- relation distributeur-détaillant et politique de commande ;
- événement d'audit et preuve documentaire.

Ne pas imposer prématurément des noms de tables ou packages qui ne correspondent pas au dépôt. Les schémas physiques seront définis après audit du code et du modèle existants.

## 4. Accueil, identité, rôles et permissions

### 4.1 Onboarding

- Le Promoteur crée ou fait créer le dossier de l'organisation selon le mécanisme d'administration retenu par Famille NAXA.
- Il choisit l'univers, le ou les profils, les sites initiaux et la formule.
- Le système applique l'essai de 72 heures et les droits côté serveur.
- Aucun changement de profil ne doit transformer silencieusement le catalogue ou réécrire des données historiques.
- Les salariés sont invités/créés par un responsable autorisé ; l'inscription publique libre des employés n'est pas autorisée.

### 4.2 Rôles Détaillants

Rôles de base configurables :
- Promoteur/propriétaire.
- Directeur ou gérant.
- Responsable de site.
- Responsable de stock.
- Responsable achats.
- Caissier/vendeur.
- Comptable/consultant en lecture limitée.
- Livreur.
- Auditeur/contrôleur selon autorisation.

Chaque rôle peut être affiné par activité, site, dépôt, caisse, fonction et seuil monétaire. Un utilisateur peut avoir des affectations multiples mais ses droits sont calculés par intersection du rôle, du périmètre et de l'état actif.

### 4.3 Rôles Distributeurs

- Promoteur/administrateur de l'organisation.
- Direction commerciale.
- Responsable régional/territorial.
- Responsable dépôt/entrepôt.
- Approvisionneur/acheteur.
- Gestionnaire de stock.
- Responsable comptes clients/CRM.
- Commercial terrain.
- Préparateur/picking.
- Chauffeur/livreur.
- Caissier/recouvrement.
- Comptable.
- Support et auditeur en lecture limitée.

Les rôles sont adaptés aux sites et territoires. Un commercial ne voit que son portefeuille, sauf permission de supervision.

### 4.4 Actions sensibles

Remise hors seuil, modification de prix, remboursement, annulation, stock négatif, correction d'inventaire, transfert, crédit client, paiement fournisseur, commande auto-soumise, validation commerciale, clôture de caisse, avoir et suppression logique de document exigent une permission et, selon le paramétrage, une approbation hiérarchique.

Aucune action financière ne peut être validée par la seule IA.

## 5. Socle commun fonctionnel

### 5.1 Authentification et sécurité locale

- Authentification conforme au socle Famille NAXA.
- Verrouillage local par code d'accès/PIN applicatif et biométrie lorsque supportée ; les secrets d'authentification ne sont jamais stockés en clair.
- Blocage et journalisation après tentatives anormales, révocation des appareils et sessions à distance.
- Registre des appareils autorisés par organisation/site/caisse ; notification au Promoteur lors d'un nouvel appareil, possibilité de déconnexion à distance et révocation immédiate. Le plafond d'appareils est configurable selon les droits souscrits et les besoins multi-caisses ; le repère historique de deux appareils actifs par point est conservé comme valeur initiale, sans bloquer l'extension autorisée du parc.
- Permissions serveur et RLS même si un écran est masqué.
- Aucun OTP/PIN reçu par SMS ne doit être lu, conservé, transmis ou affiché. Les SMS qui contiennent de tels secrets sont ignorés.

### 5.2 Hors connexion et synchronisation

- La caisse, la consultation de catalogue local, les ventes autorisées, les mouvements, la saisie de réception/inventaire et les tâches qui n'exigent pas d'arbitrage distant restent utilisables hors connexion.
- Stock local marqué avec heure de dernière synchronisation et niveau de fraîcheur.
- Synchronisation par lots/événements avec UUID stable, idempotence, reprise après échec et journal local.
- Détection des conflits : une correction crée un événement traçable ; elle n'écrase pas silencieusement l'historique.
- Les opérations sensibles ou dépendantes d'une validation serveur restent « en attente » jusqu'à confirmation.
- Une commande B2B en attente d'envoi n'est pas affichée comme transmise.
- Les politiques d'expiration offline doivent être configurables et alignées sur la décision de sécurité du socle ; ne pas reprendre automatiquement les anciennes durées proposées de 7/14 jours sans validation de sécurité.
- Les horodatages serveur et les reculs anormaux d'horloge sont contrôlés.

### 5.3 Notifications et WhatsApp

- Centre de notifications BOOTIK, historique, lu/non lu, préférences et anti-doublon.
- Notifications locales et push FCM pour alertes de stock, caisse, échéances, commandes, livraisons, crédit, sécurité, abonnement et erreurs de synchronisation.
- WhatsApp ouvre une conversation/message préparé que l'utilisateur relit et envoie. BOOTIK ne prétend jamais qu'un message a été envoyé si l'utilisateur ne l'a pas confirmé.
- Aucun PIN, OTP, mot de passe ou secret dans les notifications ou messages.
- Briefings du jour et rappels paramétrables.

### 5.4 Langues et apparence

- Français, anglais et Fulfulde (ff-CM).
- Mode clair, sombre, système et programmation horaire.
- Charte bleu nuit #052163 et orange #FC7820.
- Toutes les chaînes UI/rapports/reçus/notifications sont externalisées ; traductions métier et juridiques vérifiées par humain.
- Lisibilité soleil/écrans d'entrée de gamme, textes et actions accessibles, icône plus libellé pour les états, contraste visé au moins 4,5:1.

### 5.5 Audit

Toute action significative conserve auteur, rôle, date serveur, site, terminal, objet, opération, valeurs avant/après, motif, source (local/serveur/import/IA) et identifiant de corrélation. Les entrées de journal ne sont pas modifiables par un utilisateur métier.

## 6. Catalogue, unités et import des fiches de stock

### 6.1 Fiche article commune

Champs de base :
- Référence interne/SKU unique dans le périmètre approprié.
- Code-barres/GTIN, références alternatives.
- Désignation, description, catégorie, marque, fabricant.
- Photos compressées, statut actif/archivé, profil(s) compatible(s).
- Unité de base, unités d'achat et vente, conversions.
- Conditionnements et quantités par emballage.
- Coût d'achat, coûts attribuables, coût moyen/valorisation et historique.
- Prix détaillants, prix grossistes, prix contractuel, prix par volume.
- Seuil minimum, stock de sécurité, stock cible et quantité de réapprovisionnement.
- Fournisseur principal et fournisseurs alternatifs.
- Lot, fabrication, date limite, origine, documents et conditions de conservation si applicables.
- Emplacement physique.
- Notes, tags et métadonnées métier.

Les prix, coûts et marges sont soumis aux permissions ; ils ne sont pas visibles à tous les utilisateurs ni à tous les partenaires.

### 6.2 Modèles Excel/CSV par profil [V]

Dans le menu Stock :
- action **Télécharger le modèle de fiche de stock** ;
- action **Importer une fiche de stock**.

Le Promoteur choisit un profil, puis obtient un modèle adapté avec :
1. feuille d'instructions ;
2. feuille d'import ;
3. exemples réalistes ;
4. listes de valeurs autorisées ;
5. unités et conversions attendues ;
6. colonnes communes ;
7. colonnes spécifiques au profil ;
8. format de date, devise et séparateurs documentés.

L'import passe par les étapes obligatoires :
- upload et contrôle du format ;
- analyse et normalisation ;
- détection des doublons internes et codes-barres déjà associés ;
- validation unités, prix, valeurs, lots et dates ;
- aperçu des créations/modifications/rejets ;
- rapport des lignes invalides avec raison ;
- confirmation par utilisateur autorisé ;
- exécution traçable et rapport final.

**Une importation ne modifie jamais silencieusement une quantité existante.** Toute quantité initiale, correction ou inventaire devient un mouvement identifié, justifié et audité. L'import peut être annulé selon une procédure compensatoire si les mouvements n'ont pas déjà été consommés ; aucune suppression arbitraire de mouvements comptables.

### 6.3 Unités et conversions

- Unité de base canonique pour le calcul.
- Unités d'achat, de stockage et de vente explicites.
- Conversions configurées et datées, avec historique.
- Gestion des fractions uniquement lorsque le profil et l'unité l'autorisent (ex. poids, longueur, volume).
- Une conversion incompatible ou ambiguë bloque la vente/réception jusqu'à correction.
- Les conditionnements non divisibles sont protégés.

### 6.4 Localisation physique

Chemin adaptable : organisation → site → zone → département → allée → rayon → étagère/rack → niveau → bac → position/comptoir.

Chaque produit ou lot peut avoir un emplacement principal et des emplacements secondaires autorisés. Recherche par désignation, SKU, code-barres ou emplacement. Les QR/barcodes d'emplacement identifient une zone et non une permission d'accès.

Exemples :
- Poissonnerie : vitrine réfrigérée, bac, chambre froide.
- Boucherie : chambre froide, vitrine, zone de découpe.
- Boulangerie : zone matières premières, production, présentoir.
- Supermarché : département, allée, rayon, niveau.
- Quincaillerie : allée, casier, rack, position.
- Gaz : zone, rangée, emplacement, marque et état de la bouteille.

## 7. Stocks et opérations d'inventaire Détaillants

- Stock disponible, réservé, en transit, endommagé, bloqué, périmé et en quarantaine distincts.
- Réception fournisseur, inventaire initial, inventaire tournant, comptage par scan, transfert, ajustement, vente, consommation de recette, retour, perte, casse, destruction et rappel sont des mouvements distincts.
- Traçabilité par lot lorsque nécessaire.
- Coût moyen pondéré et valorisation avec règles datées ; conservation du coût historique.
- FEFO pour lots périssables, FIFO ou autre stratégie justifiée selon profil.
- Seuils minimum, stock de sécurité, stock cible, rupture imminente, rupture effective, surstock et dormance.
- Alertes paramétrables et anti-doublon.
- Transfert inter-sites : préparation, expédition, transit, réception partielle/complète, litige ; le stock destination n'augmente qu'à réception.
- Inventaire négatif interdit par défaut ; dérogation par permission et motif.
- Historique exportable par article, lot, site, activité et période.

### 7.1 Cas Boulangerie

- Stock matières premières distinct des produits finis.
- Recettes versionnées par quantité/unité de production.
- Ordre/fiche de fabrication, numéro de fournée, opérateur, date et quantités produites.
- Consommation calculée des ingrédients et emballages.
- Ajustement validé si consommation réelle diffère de la recette.
- Lot de production lié aux ingrédients lorsque traçabilité nécessaire.
- Vente, invendus, pertes, dons et destruction enregistrés séparément.
- Rendement et coût théorique/réel analysables.

### 7.2 Cas Poissonnerie et Boucherie

- Réception : poids brut, espèce/type, provenance, lot, date/heure et conditions.
- Préparation : poids nettoyé/découpé, parties commercialisables, sous-produits si gérés et déchets/pertes.
- Unités et prix au poids réel.
- Calcul rendement et coût commercialisable, sans traiter le poids reçu comme intégralement vendable.
- Lots et conservation, alertes d'échéance configurables.
- Pertes et destructions justifiées.

### 7.3 Cas Quincaillerie

- Un même produit peut être acheté en carton/paquet et vendu à la pièce, au mètre, au rouleau ou au conditionnement.
- Conversions versionnées avec contrôle de cohérence.
- Devis et commandes client, références techniques et attributs dimensionnels.
- Recherche performante sur grand catalogue, y compris hors connexion.

### 7.4 Cas Dépôt de gaz

- Catalogue par marque et capacité (ex. 6 kg, 12,5 kg, 35 kg selon gamme).
- Stock séparé : bouteilles pleines, vides, en transit, défectueuses, fuyantes, quarantaine.
- Distinguer propriétaire de la bouteille, détenteur, dépôt, client et distributeur de la marque.
- Identifiant bouteille individuel lorsqu'il existe ; sinon suivi par lot/groupe contrôlé.
- Échange vide contre pleine, vente avec consigne, caution, remboursement de consigne, bouteille perdue, retour fournisseur.
- Les consignes et cautions sont des passifs/engagements séparés du chiffre d'affaires gaz.
- Livraisons, livreurs, tournées, frais, preuve de réception et retour des vides.
- Aucun mélange de bouteilles incompatibles ou de propriété non autorisée.

### 7.5 Cas Brocante

- Fiche détaillée avec photos, description, état, provenance déclarée, coût/acquisition, estimation, prix affiché, prix plancher, négociabilité et date d'entrée.
- Article unique ou stock quantifié ; numéro d'inventaire interne obligatoire.
- Historique des estimations, modifications de prix, réservations, négociations, ventes et retours.
- Réservation avec échéance et acompte si autorisé.
- Blocage atomique d'un article unique pendant finalisation de vente afin d'empêcher la double vente sur plusieurs appareils.
- Justificatifs de provenance facultatifs/obligatoires selon catégorie et niveau de risque configuré.
- Alertes internes lorsqu'un article est bloqué, en litige ou signalé.
- Aucun mécanisme ne doit encourager le commerce de biens volés, contrefaits ou légalement interdits ; procédures de vérification adaptées aux catégories sensibles.

## 7.6 Mini-catalogue partageable

- Le Promoteur choisit les articles publiables, les prix publics, les photos et la disponibilité indicative.
- BOOTIK génère une page catalogue partageable par lien/WhatsApp, légère et actualisable à partir des données autorisées.
- Les prix internes, coûts, marges, quantités exactes sensibles et données des clients ne sont jamais publiés.
- Le lien peut être désactivé/révoqué ; les articles épuisés ou désactivés ne sont plus proposés comme disponibles.
- La consultation du mini-catalogue ne donne pas accès à l'espace privé BOOTIK.

## 8. Caisse et ventes Détaillants

### 8.1 Parcours standard

1. Ouverture de session par l'employé autorisé et déclaration du fonds initial.
2. Recherche ou scan d'article ; affichage du prix autorisé, variante, stock, lot et emplacement.
3. Ajout panier, quantité, prix applicable, taxes/remises et contrôle des droits.
4. Sélection du client ou mode comptoir.
5. Choix du moyen de paiement : espèces, Mobile Money, carte/TPE, virement, crédit client ou paiement mixte.
6. Validation, génération du document de vente, mouvement de stock, reçu et journal.
7. Partage/impression selon les canaux autorisés.

### 8.2 Caisses et sessions

- Plusieurs caisses indépendantes par site, département ou point de vente.
- Fonds initial, entrées/sorties de caisse justifiées, ventes, remboursements, annulations autorisées et clôture.
- Comptage physique par moyen de paiement.
- Comparaison du solde théorique au montant compté et gestion des écarts.
- Ouverture/clôture horodatées et signées par utilisateur.
- Suivi séparé des espèces et des encaissements Mobile Money marchand, avec rapprochement par moyen de paiement ; le Mobile Money n'est pas artificiellement représenté comme un tiroir physique.
- Rapports par session, caisse, utilisateur, site, activité et jour.
- Aucun effacement de vente : annulation, avoir ou correction avec motif et autorisation.

### 8.3 Prix et promotions

- Prix au détail et prix de gros.
- Tarifs par client, groupe, volume, période, canal ou contrat.
- Remises en pourcentage ou montant, plafonds par rôle et validation au-delà du seuil.
- Promotions programmées, bundles et remises fidélité.
- Le prix appliqué et sa source sont conservés dans la ligne de vente.
- L'IA peut proposer un prix ou une promotion, jamais l'appliquer sans règle/autorisation.

### 8.4 Documents et retours

- Reçu, ticket, facture, devis, bon d'avoir et justificatif de remboursement.
- Numérotation sans doublon et séquence conservée.
- PDF, impression thermique Bluetooth et partage via WhatsApp préparé.
- Retours partiels ou complets, motifs, état du produit retourné, remise en stock/quarantaine/destruction et remboursement/avoir.
- Retours et remboursements liés à la vente d'origine.

### 8.5 Paiements

- Encaissements par moyen et rapprochement.
- Paiement mixte ventilé exactement au franc près.
- Paiement en attente, confirmé, échoué, remboursé ou contesté selon les preuves disponibles.
- Confirmation Mobile Money via le circuit canonique et les intégrations qualifiées ; l'ancien rapprochement SMS facultatif est conservé uniquement dans les limites de confidentialité et de sécurité du socle.
- Un SMS partagé/saisi par l'utilisateur peut créer une preuve à vérifier ; il n'active pas à lui seul un abonnement ni un droit.
- Aucun double encaissement dû à un webhook, SMS ou événement rejoué.

## 9. Clients, CRM et fidélité Détaillants

### 9.1 Dossier client

- Identité/raison sociale selon le type.
- Téléphone, e-mail et adresses nécessaires.
- Sites ou contacts associés.
- Historique achats, panier moyen, fréquence, produits préférés et retours.
- Consentements et préférences de communication.
- Notes internes et réclamations.
- Segments : nouveau, actif, fidèle, inactif, à risque, professionnel, etc.

### 9.2 Ardoise et crédit client

- Plafond de crédit configurable.
- Crédit initial, ventes à crédit, acomptes, paiements partiels, échéances, soldes et retards.
- Blocage ou validation hiérarchique en cas de dépassement.
- Relances préparées pour WhatsApp, historique des rappels.
- Relevé de compte exportable.
- Le montant vendu à crédit n'est jamais présenté comme encaissé.

### 9.3 Fidélité et animation

- Points d'achat selon règles configurables.
- Parrainage client (distinct de tout programme Partner JOBLY).
- QR client avec identifiant opaque, données minimales, révocation et droits.
- Anniversaires et offres ciblées selon consentements.
- Roue promotionnelle facultative : lots disponibles, probabilité/règles transparentes et plafonnées, période, éligibilité, journal d'audit et protection contre les abus.
- Historique complet des points attribués, utilisés, expirés ou corrigés.

## 10. Fournisseurs, achats et approvisionnement Détaillants

- Fiche fournisseur, contacts, conditions de paiement, catalogues, références, prix et délais.
- Demande de devis, comparaison des prix, commande d'achat, réception partielle/complète et litiges.
- Dettes fournisseurs séparées des dettes clients ; avances, avoirs, paiements partiels et échéances.
- Factures/photo/PDF en pièce jointe ; OCR si disponible pour préremplir, avec vérification humaine avant comptabilisation.
- Commandes préparées via WhatsApp pour les fournisseurs non connectés.
- Lorsqu'un fournisseur est un Distributeur BOOTIK connecté, utiliser le flux B2B structuré décrit en section 21.
- Quantités reçues rapprochées de la commande ; écarts et dommages documentés.
- Coût d'achat et frais attribuables actualisés selon méthode retenue.

### 10.1 Alertes et suggestion de réapprovisionnement

Le moteur calcule la proposition à partir :
- du stock disponible vendable ;
- du stock réservé et engagé ;
- des ventes historiques et de la saisonnalité ;
- du délai d'approvisionnement ;
- du stock de sécurité et de la cible ;
- des unités et multiples de conditionnement ;
- des commandes déjà émises/en transit ;
- des dates de péremption et de la capacité de stockage.

Il distingue stock faible, rupture imminente, rupture effective, surstock, produit dormant et risque de péremption. Toute recommandation affiche ses facteurs et son niveau de confiance.

## 11. Dépenses, trésorerie et comptabilité de gestion

### 11.1 Charges

- Dépenses ponctuelles ou récurrentes : loyer, eau/électricité, internet, taxes, transport, carburant, entretien, salaires, frais bancaires, nettoyage et administration.
- Montant prévu/réel, fréquence, date d'échéance, responsable, centre de coût et justificatif photo/PDF.
- Paiements partiels, retards, échéances, rappels et historique.
- Catégorisation et ventilation analytique par activité/site lorsque autorisé.

### 11.2 Distinguer les flux

Le tableau de bord sépare :
- chiffre d'affaires brut/net ;
- ventes au comptant et ventes à crédit ;
- encaissements par date et moyen ;
- remboursements, remises et avoirs ;
- coût des marchandises vendues ;
- marge brute ;
- pertes, casse, invendus et coût des pertes ;
- charges d'exploitation ;
- résultat de gestion estimé ;
- trésorerie et mouvements non liés à une vente ;
- créances clients et dettes fournisseurs ;
- cautions/consignes et fonds détenus pour compte de tiers.

Une entrée de trésorerie n'est pas nécessairement une vente ; une vente à crédit n'est pas une somme encaissée.

### 11.3 SYSCOHADA et fiscalité

Journaux, états de gestion, plan de comptes paramétrable, TVA et exports sont prévus. Les états ne sont qualifiés de déclaratifs ou certifiés qu'après validation professionnelle des mappings, règles, versions, taux et obligations en vigueur. BOOTIK ne remplace pas un expert-comptable ni les autorités fiscales.

### 11.4 Accès comptable externe

Lien temporaire en lecture seule, limité à une organisation, une activité, un site et une période autorisés ; expiration, révocation et journalisation obligatoires. Aucun accès global par simple partage de lien.

## 12. Équipe, présence et performance

- Fiches employés, rôles, coordonnées utiles, affectation par site/activité/caisse/dépôt.
- Heures d'arrivée/départ, pauses, retards, heures supplémentaires et validation hiérarchique selon politique.
- Preuve de présence par appareil, QR ou position ponctuelle autorisée.
- Pas de géolocalisation continue hors service.
- Commissions, objectifs, primes et avances lorsque paramétrés.
- Indicateurs de vente, panier moyen, écarts de caisse, ponctualité et tâches.
- Classements/challenges avec règles transparentes, sans sanction automatique de l'IA.
- Modification de rémunération ou sanction soumise à décision humaine et à la réglementation applicable.

## 13. Mobile Money accessoire

BOOTIK peut enregistrer une activité accessoire de dépôt/retrait ou vente de crédit téléphonique, séparée de la caisse marchandises.

Registre par opérateur et journée :
- solde initial de float ;
- dépôts/retraits ;
- vente de crédit ;
- commission déclarée ;
- fonds de tiers ;
- frais ;
- références des opérations ;
- solde théorique et constaté ;
- écarts et rapprochement.

Ne jamais compter les fonds de tiers comme chiffre d'affaires ou trésorerie libre de la boutique. Pour une exploitation principale ou importante, orienter vers KIOSKO, le produit spécialisé. BOOTIK ne fournit pas de service de paiement et ne détient pas les fonds des clients.

## 14. Pilotage Détaillants et rapports

Tableau de bord Promoteur :
- CA du jour/semaine/mois ;
- encaissé, crédité, dû et remboursé ;
- marge brute, coût des ventes, charges et résultat estimé ;
- valeur du stock, ruptures, surstocks, péremptions et produits dormants ;
- top/flop produits, panier moyen, heures de pointe ;
- dettes clients, fournisseurs, échéances ;
- dépenses récurrentes et échues ;
- performance employés, écarts de caisse ;
- comparaison entre sites et activités autorisés.

Exports PDF/Excel : ventes, session de caisse, reçu, stock, inventaire, mouvements, lots, commandes, fournisseurs, dettes clients/fournisseurs, charges, marge, résultat, employés, transferts, production et pertes. Filtres date, site, activité, caisse, produit, catégorie, fournisseur et rôle. Les exports portent organisation/site/période et date de génération, avec filigrane ou métadonnées de traçabilité selon les règles du socle.

## 15. Intelligence artificielle Détaillants

### 15.1 Fonctions

- Prévision de ventes et demande, par produit, jour, activité et saison.
- Prédiction de rupture, surstock et risque de péremption.
- Détection d'écarts de caisse, marges anormales, pertes et mouvements inhabituels.
- Suggestion de réapprovisionnement et comparaison de fournisseurs.
- Conseils de promotion, ventes complémentaires et assortiments.
- Résumé de journée, tâches prioritaires et explication d'écarts.
- Questions/réponses sur les données accessibles à l'utilisateur.

### 15.2 Limites

L'IA explique ses données et ses raisons, indique l'incertitude et ne présente pas une estimation comme une certitude. Elle ne peut pas seule :
- confirmer un paiement ;
- engager ou accepter une commande ;
- modifier un prix ou une remise hors règle ;
- valider un remboursement ;
- modifier un solde, une dette ou une écriture ;
- autoriser une vente interdite ;
- sanctionner un employé ;
- ouvrir des données d'un autre tenant.

L'IA doit utiliser la passerelle NAXA après audit, respecter permissions, minimisation des données, coûts et mode dégradé. Les calculs financiers doivent être exécutés par du code déterministe, pas par génération de texte.

## 16. Univers Distributeurs — ERP complet

### 16.1 Achats et fournisseurs

- Fichier fournisseurs locaux et étrangers ; contacts, contrats, devises et conditions.
- Demandes de cotation, comparaison, commande, acomptes, facture et réception.
- Planning d'approvisionnement, délai, reliquats, réclamations et évaluation fournisseur.
- Historique des prix d'achat, qualité, ponctualité et litiges.

### 16.2 Importations et coût rendu

- Dossier par commande/conteneur/expédition.
- Fournisseur, origine, devise, incoterm si géré, quantité, produits et lots.
- Factures, packing list, documents de transport, assurance, transit, douane, certificats et justificatifs en pièces jointes.
- Frais attribuables : fret, assurance, transit, frais portuaires, droits/taxes et autres frais configurés.
- Méthode de répartition explicite (valeur, poids, volume, quantité ou méthode spécifique) et versionnée.
- Calcul du coût de revient rendu par référence/lot.
- Réconciliation coût prévisionnel/réel et historique de taux de change.
- Alertes de documents manquants/échéances.
- BOOTIK suit les dossiers et preuves ; il ne remplace pas les douanes, autorités de conformité, transitaires ou certificats délivrés par une autorité.

### 16.3 Entrepôts et gestion de stock (WMS)

- Plusieurs entrepôts, dépôts, zones, quais et emplacements.
- Réception, contrôle quantitatif/qualitatif, mise en quarantaine, rangement, réapprovisionnement de picking.
- Lots, numéros de série, palettes, cartons, unités, dates de fabrication/péremption et origine.
- Inventaires tournants et complets.
- Picking, packing, préparation, contrôle de commande, chargement et expédition.
- Transferts inter-entrepôts et inter-sites.
- Retours clients, retours fournisseur, avaries, pertes, rappel de lot et destruction.
- Disponibilité, stock réservé, stock libre, stock bloqué, stock en transit et stock en consignation séparés.
- FEFO/FIFO ou stratégie par produit.
- Traçabilité du fournisseur au détaillant.

### 16.4 Tarification B2B et contrats

- Prix d'achat, prix de revient et prix de vente par canal.
- Tarifs grossiste, semi-grossiste, détaillant, réseau, zone, volume ou contrat.
- Validité datée, devise, conditionnement, quantité minimale, paliers et unités.
- Remises, ristournes, primes de volume, objectifs et bonus de distribution.
- Promotions et offres de lancement.
- Prix visibles uniquement par les clients autorisés ; coût/marge internes protégés.
- Contrat client, conditions de paiement, délai, plafond de crédit et zone de service.
- Historique de prix appliqué à chaque commande.

### 16.5 Commandes et ventes B2B

- Commande saisie par détaillant connecté, commercial, portail ou service interne.
- Devis, brouillon, validation de crédit, confirmation, préparation, livraison, facture et recouvrement.
- Lignes avec quantité demandée, acceptée, substituée, reliquat et quantité livrée.
- Disponibilité réelle ou indicative selon la fraîcheur des données.
- Blocage si crédit dépassé, compte suspendu, tarif invalide ou produit indisponible, avec motif et circuit d'exception.
- Commande partielle, annulation et litige tracés.
- Facture et avoir liés à la commande/livraison.
- Pas de modification silencieuse de commande après acceptation.

### 16.6 Force de vente

- Fiche commercial, équipe, supérieur, territoire et portefeuille.
- Objectifs par période, chiffre d'affaires, volume, marge, nouveaux détaillants et recouvrement.
- Plan de tournée et visites, rendez-vous, check-in ponctuel autorisé, compte rendu et preuve.
- Prospection, qualification, opportunité, devis et commandes.
- Prise de commande hors ligne en brouillon, synchronisation au retour du réseau.
- Commissions selon règles datées, transparence de calcul et validation.
- Reporting par commercial, équipe, zone, marque, catégorie et période.

### 16.7 Territoires et couverture

- Pays/région/ville/quartier, secteurs et routes commerciales.
- Règles d'affectation des détaillants et commerciaux.
- Couverture effective, fréquence des visites et clients non servis.
- Territoires exclusifs contractuels si le distributeur le configure et en possède le droit.
- Éviter les doubles affectations et conflits ; historique des changements.
- Les droits territoriaux contractuels ne sont pas inventés par le logiciel.

### 16.8 Livraison et flotte

- Véhicules, capacité, conducteur, équipe et disponibilité.
- Tournée, ordre de chargement, itinéraire, lots/quantités chargés et documents.
- Bon de livraison et preuve de livraison (signature, nom, photo ou code à usage limité selon consentement).
- Livraison partielle, refus, absence, retour, casse et litige.
- Encaissement à la livraison si configuré, sans confondre preuve de livraison et preuve de paiement.
- Retour d'emballages consignés, palettes, casiers, bouteilles et fûts.
- Coût de tournée et rentabilité, sans inventer une précision de géolocalisation indisponible.

### 16.9 Crédit commercial et recouvrement

- Plafond de crédit par détaillant, conditions contractuelles et période de validité.
- Encours : factures, échéances, paiements, avoirs, retards et litiges.
- Blocage/alerte/autorisation hiérarchique.
- Promesses de paiement et suivi de recouvrement.
- Relevé client, balance âgée et exposition par zone/commercial.
- Encaissements et rapprochements intégrés au journal financier.

### 16.10 ERP financier et contrôle

- Journaux de vente, achats, stock, encaissements, décaissements, charges et écritures de gestion.
- Comptes clients/fournisseurs, avances, avoirs et échéances.
- Coût des marchandises, marge brute, coûts import, coûts logistiques, ristournes et commissions.
- Trésorerie et rapprochement par compte et moyen de paiement.
- Budgets, prévisions et centres de coûts.
- États SYSCOHADA/fiscaux paramétrables sous réserve de validation professionnelle.
- Contrôle de marge par marque, SKU, détaillant, commercial, territoire, dépôt et tournée.
- Audit des corrections, validations et opérations sensibles.

## 17. CRM Distributeurs complet

Le CRM B2B n'est pas un simple carnet de contacts. Il doit gérer le cycle commercial de bout en bout.

### 17.1 Compte détaillant

- Fiche d'entreprise et identité commerciale.
- Forme/type de commerce, profil métier, secteur, taille et potentiel.
- Plusieurs points de vente et adresses de livraison.
- Contacts et fonctions (dirigeant, acheteur, comptable, réceptionnaire).
- Zone, commercial responsable et statut de connexion BOOTIK.
- Documents et contrats, tarifs, limites de crédit et conditions.
- Historique commandes, factures, livraisons, paiements, réclamations et visites.
- Consentements de contact et canaux autorisés.

### 17.2 Cycle de vie commercial

- Prospect, identifié, qualifié, contacté, rendez-vous, négociation, client actif, inactif, perdu ou suspendu.
- Source du prospect et historique de chaque interaction.
- Opportunités, produits/familles intéressés, volume estimé, échéance et probabilité indicative.
- Tâches, relances, rendez-vous, notes, pièces jointes et responsable.
- Devis, proposition, contrat, conditions, acceptation et renouvellement.
- Motifs de perte/inactivité et plan de reconquête.

### 17.3 Segmentation et relation

- Segmentation par profil métier, territoire, potentiel, volume, fréquence, marge, crédit, fidélité et niveau de service.
- Communication commerciale ciblée avec consentement et fréquence contrôlée.
- Promotions, objectifs, campagnes et mesure de réponse.
- Réclamations, incidents de livraison, litiges et SLA.
- Tableau de bord du portefeuille et activités du commercial.

### 17.4 Portail détaillant

Le détaillant connecté accède à son espace B2B :
- catalogue du distributeur et familles autorisées ;
- prix contractuels et offres ;
- disponibilité avec date/heure de fraîcheur ;
- commande, historique, reliquats, factures et livraisons ;
- solde autorisé, échéances et relevés ;
- messages et réclamations ;
- connexion ou demande de connexion à d'autres distributeurs compatibles.

Le détaillant ne voit jamais les coûts internes, les marges, les autres clients ou les données privées du distributeur.

## 18. Interconnexion par profil métier

### 18.1 Moteur de compatibilité [V]

Un référentiel versionné relie :
- le profil Détaillant ;
- ses familles de produits et besoins ;
- les profils Distributeurs compatibles ;
- les sous-catégories effectivement fournies ;
- la zone desservie ;
- les conditions de conservation et de transport ;
- les capacités/agréments documentés lorsque requis ;
- l'état de la relation et les conditions commerciales.

La compatibilité ne doit pas se limiter au nom du profil. Elle est décidée par une matrice métier configurable et validée par l'administration du référentiel. Un distributeur ne peut pas se déclarer compatible avec n'importe quel secteur sans catalogue et zone correspondants.

### 18.2 Exemples initiaux de correspondance

| Détaillant | Distributeur(s) correspondant(s) |
|---|---|
| Cave | Boissons et brasseries |
| Dépôt de gaz | Gaz et énergie domestique |
| Boutique / Supérette / Alimentation / Supermarché | FMCG, boissons, hygiène, frais, beauté selon assortiment |
| Poissonnerie | Produits frais, réfrigérés et surgelés |
| Boucherie | Produits frais, réfrigérés et surgelés |
| Boulangerie | FMCG et fournisseurs spécialisés d'ingrédients/emballages selon catalogue |
| Parfumerie / Shopping | Beauté et soins personnels, importateurs et distributeurs de marques selon assortiment |
| Ferme | Distributeurs agro-intrants ; distributeurs alimentaires peuvent être acheteurs potentiels selon la relation commerciale |
| Quincaillerie | Importateurs et distributeurs de marques uniquement si les catégories techniques sont référencées et validées ; un profil vertical dédié pourra être proposé plus tard |
| Brocante | Relation au cas par cas avec distributeur ou opérateur de reprise qualifié ; pas de correspondance automatique par défaut |

Ces lignes sont les correspondances de départ. La liste des produits réellement vendus, les territoires et la qualification priment sur l'étiquette du profil.

### 18.3 Découverte et création de relation

- Recherche d'un distributeur par profil, famille de produits, ville/zone, marques et disponibilité.
- Fiche publique minimale ou fiche accessible après consentement.
- Demande de connexion du détaillant, invitation distributeur par QR/lien opaque ou création administrative.
- Acceptation/refus par le distributeur ; éventuellement validation des conditions par le détaillant.
- Statuts : invitation envoyée, en attente, active, suspendue, refusée, clôturée.
- Définition des produits et sites couverts, conditions, tarifs, crédits et contacts.
- Un détaillant peut connecter plusieurs distributeurs ; un distributeur peut servir plusieurs détaillants.
- Un distributeur préféré peut être défini par famille de produits, sans exclusivité forcée.
- Révocation/fin de relation avec conservation de l'historique commercial et des factures dues.
- Les relations commerciales ne donnent pas accès aux données non nécessaires.

## 19. Réapprovisionnement intelligent et commandes avec validation humaine

### 19.1 Déclencheurs

- Seuil minimum atteint.
- Prévision de rupture.
- Ventes accélérées ou demande saisonnière.
- Stock cible non atteint après réapprovisionnement.
- Alerte sur produit critique défini par le Promoteur.

### 19.2 Politique de réapprovisionnement

Pour chaque site, produit ou famille, le Promoteur peut définir :
- fournisseur/distributeur préféré ;
- stock de sécurité et cible ;
- quantité minimale et multiple de commande ;
- montant/plafond d'une demande ;
- fenêtre horaire/jours d'envoi ;
- produits exclus ;
- comportement : simple alerte, brouillon automatique ou transmission automatique en attente de validation du distributeur ;
- conditions de crédit et seuils d'arrêt.

La politique est inactive par défaut jusqu'à activation explicite par une personne autorisée. Le mode de transmission automatique est optionnel et borné.

### 19.3 Parcours de commande automatisée

1. Événement de stock créé une seule fois par seuil/période.
2. Le moteur calcule quantité proposée et explique le calcul.
3. Il vérifie stock disponible, lots, commandes ouvertes, réception attendue, prix, unité, contrat, disponibilité déclarée et plafond.
4. Si le mode automatique n'est pas activé : brouillon + notification au détaillant.
5. Si activé : création d'une commande proposée et envoi au distributeur connecté, état **En attente de validation distributeur**.
6. Le distributeur voit la demande dans sa file de validation, peut accepter, refuser ou proposer une modification avec motif.
7. Une modification des termes essentiels requiert acceptation du détaillant.
8. Une commande acceptée devient préparation à faire et réserve le stock distributeur selon la politique.
9. Picking, expédition, livraison, réception partielle/complète et facture sont suivis.
10. Les paiements et crédits sont rapprochés séparément ; la réception ne vaut pas encaissement.

### 19.4 États minimum de la commande B2B

Brouillon → Prête à soumettre → En attente de transmission → Transmise / En attente de validation distributeur → Acceptée / Refusée / Modification proposée → En attente d'accord détaillant → Confirmée → En préparation → Partiellement expédiée → Expédiée → Partiellement livrée → Livrée → Facturée → Partiellement réglée / Réglée.

États alternatifs et finaux : annulée, en litige, retour demandé, retour partiel, retournée, clôturée.

Une commande hors ligne reste un brouillon local/en attente de synchronisation. Un statut distant n'est affiché qu'après réponse serveur réelle.

### 19.5 Garde-fous

- Validation humaine du distributeur toujours obligatoire avant engagement ferme.
- Acceptation détaillant requise si prix, quantité, substitution, date ou frais changent.
- Limites de crédit et comptes suspendus contrôlés.
- Un événement de seuil ne génère pas de commande dupliquée.
- Journal des déclencheurs, politiques, calculs, décisions humaines et changements.
- Le Promoteur peut suspendre immédiatement l'automatisation.
- Les notifications sont informatives ; elles ne remplacent pas la validation.
- Pas de paiement ou transfert de fonds déclenché directement par l'algorithme.

## 20. Verticales Distributeurs : règles particulières

### 20.1 Boissons et brasseries

- Marques, formats, caisses/cartons, bouteilles, casiers, palettes, fûts.
- Casiers/bouteilles/fûts consignés, retours et état.
- Équipements de pression confiés : propriétaire, dépôt, détaillant, emplacement, date de remise, maintenance et retour.
- Allocation/quotas par territoire, remises, ristournes, primes de volume.
- Ventes, volumes et marges par marque, produit, détaillant, commercial et zone.

### 20.2 Gaz et énergie domestique

- Propriétaire de marque, distributeur, sous-distributeur, dépôt et détaillant.
- Bouteille par capacité, marque et identifiant quand disponible.
- Statuts pleine, vide, détenue par client, en transit, défectueuse, fuyante, quarantaine.
- Consigne/caution à chaque remise et retour.
- Traçabilité de la propriété distincte de la détention.
- Réconciliation par marque, dépôt, véhicule et partenaire.
- Pas de mélange de marques/circuits incompatibles.
- Livraison et retour de vides.

### 20.3 Alimentaire FMCG

- Achats par conteneur, palette, sac, carton et unité.
- Conversion d'unités contrôlée.
- Lots, dates, origine, coût rendu et fournisseurs.
- Tarifs par volume, détaillant, semi-grossiste et réseau.
- Promotions, ruptures, réassorts, rappels de lots et analyse des stocks dormants.

### 20.4 Frais, réfrigérés et surgelés

- Enregistrement des températures et conditions par espace ou lot selon équipement et procédures.
- Réception avec contrôle qualité.
- Dates de production/expiration et FEFO.
- Alerte chaîne du froid et incident avec responsable, temps, preuve et impact.
- Pertes, avaries, retour et destruction.
- Traçabilité fournisseur → entrepôt → tournée → détaillant.

### 20.5 Hygiène, beauté et soins personnels

- Marques, gammes, formats, contenances, unités et lots.
- Péremption et rappel.
- Catalogues segmentés, prix réseau, promotions, bundles et lancements.
- Rotation, produits dormants, saisonnalité et marges.
- Conditions de stockage et documents requis selon catégorie.

### 20.6 Importateurs et distributeurs de marques

- Fournisseurs étrangers, commandes, expéditions, devises et coût rendu.
- Documents d'importation, de conformité et échéances.
- Historique des taux et écarts de coût.
- Catalogue par marque, gamme et territoire.
- Réseau national et contrats de distribution.

### 20.7 Agro-intrants et alimentation animale

- Produits, lot, origine, conditionnement, date, fiche technique et conditions de conservation.
- Gestion des dates et règles de stockage propres à chaque référence.
- Documents et autorisations applicables suivis en pièces jointes et rappels.
- Séparation des familles pouvant présenter des exigences de stockage différentes.
- Traçabilité et rappel par lot.

## 21. Livraison, véhicules et preuve de service

- Fiche véhicule, capacité, statut, entretien, assurance et affectations documentaires.
- Tournée par date, territoire, conducteur, points à livrer et séquence.
- Chargement avec contrôle quantités/lots et document de départ.
- Confirmation livraison par signature, identité du réceptionnaire, photo ou code opaque à durée limitée selon configuration.
- Livraison complète/partielle, refus, absence, casse, retour et litige.
- Retours de consignes et emballages rapprochés.
- Les preuves de livraison ne constituent pas une preuve de paiement.
- Une géolocalisation ponctuelle liée à une tournée ne devient pas une surveillance continue hors service.

## 22. Pilotage Distributeurs et rapports

Tableaux de bord :
- ventes, volume, marge et coût rendu par produit/marque ;
- performance par détaillant, commercial, équipe, territoire et dépôt ;
- couverture et nombre de détaillants actifs/nouveaux/inactifs ;
- portefeuille, devis et opportunités ;
- commandes en attente/acceptées/refusées ;
- retards, reliquats, préparation et livraisons ;
- ruptures et disponibilité par entrepôt ;
- stock immobilisé, rotation, péremption, pertes et avaries ;
- encours, balance âgée, plafond et risque de crédit ;
- coût logistique, coût de tournée et rentabilité ;
- consignes/emballages/bouteilles en circulation ;
- paiements, rapprochements et trésorerie.

Rapports PDF/Excel : ventes, clients, tournée, picking, stock, lots, inventaires, commandes, livraisons, factures, recouvrement, remises/ristournes, commissions, importations, coûts rendus, performance territoriale, rentabilité et journal d'audit.

## 23. Abonnements et facturation BOOTIK

### 23.1 Grille officielle [V]

| Univers | ACCÈS mensuel | PREMIUM mensuel |
|---|---:|---:|
| Détaillants | 4 000 FCFA | 10 000 FCFA |
| Distributeurs | 10 000 FCFA | 25 000 FCFA |

Aucun palier Pro générique. Tous les modules fondamentaux sont présents en ACCÈS ; PREMIUM ajoute l'échelle, les capacités multiniveaux et le pilotage avancé.

### 23.2 Périodicités exclusives [V — 26 novembre 2026]

Uniquement mensuel (1 mois) et annuel (12 mois). Annuel : 12 mois au prix de 10, soit deux mensualités offertes (16,67 % de ristourne). Les offres 3 et 6 mois sont supprimées et doivent être refusées côté serveur, Android, Web et PWA.

| Univers | ACCÈS annuel | PREMIUM annuel |
|---|---:|---:|
| Détaillants | 40 000 FCFA | 100 000 FCFA |
| Distributeurs | 100 000 FCFA | 250 000 FCFA |

Le moteur partagé peut être utilisé uniquement derrière une politique BOOTIK restrictive ; aucune modification des autres produits.

### 23.3 Essai, paiement et droits

- 72 heures d'utilisation gratuite par organisation, à compter de l'activation initiale côté serveur, sans paiement préalable, non réinitialisables par réinstallation. Accès aux fonctions de la formule choisie durant l'essai ; à expiration, aucun droit payant sans paiement confirmé. Conservation des données.
- Parcours : création dossier → choix univers/formule → essai ou paiement → vérification canonique → attribution d'entitlements → reçu et période active → rappels.
- L'identifiant de transaction seul ne vaut pas paiement.
- Paiements idempotents, webhooks vérifiés, rapprochement et gestion des états pending/success/failed/refunded.
- Paiement en attente ou échoué n'accorde pas de nouveaux droits payants.
- Données du client conservées selon politique ; aucun verrouillage de compte ne doit provoquer une suppression de données.
- Un abonnement Promoteur couvre le réseau de sites dans le même univers ; ne pas multiplier les abonnements par boutique, caisse ou dépôt.
- L'IA est incluse, sans prix par usage.
- Une organisation mixte exploitant les deux univers sous le même compte de facturation exige une décision de facturation [O] avant commercialisation ; aucun forfait combiné n'est inventé.

### 23.4 Capacités par formule

ACCÈS inclut le noyau opérationnel complet de l'univers choisi :
- toutes les opérations courantes de vente/achat/stock/CRM ;
- les dossiers clients et fournisseurs ;
- les dettes, commandes, factures et livraisons de base ;
- les exports fondamentaux, audit et sécurité ;
- les fonctions spécialisées par profil.

PREMIUM renforce selon l'univers :
- consolidation organisationnelle et hiérarchies multi-niveaux avancées ;
- délégation et approbations avancées ;
- capacité étendue multi-sites/entrepôts/équipes/territoires ;
- analyses comparatives, prévisions et planification avancées ;
- automatisation bornée des réapprovisionnements et workflow avancés ;
- tableaux de bord consolidés et contrôles renforcés.

La grille d'entitlements doit être explicite, côté serveur, versionnée et testée. La séparation ACCÈS/PREMIUM ne peut pas retirer une fonction métier essentielle d'ACCÈS.

## 24. Intégrations et périmètres des autres produits

### 24.1 KIOSKO

KIOSKO reste propriétaire des fonctions spécialisées Mobile Money. BOOTIK peut appeler des contrats de paiement autorisés et afficher les statuts vérifiés, sans créer de registre de fonds tiers concurrent ou un opérateur de paiement dans BOOTIK.

### 24.2 NAXA SECURITY

Intégration via API/contrat autorisé pour alertes et liens/événements caméra. BOOTIK ne fournit ni matériel, ni caméra, ni installation matérielle, ni opérateur de surveillance humaine. Les permissions et journaux de sécurité restent sous le contrôle des services propriétaires.

### 24.3 Support, IA, notifications et Billing Famille NAXA

Réutiliser après audit les services communs réellement disponibles : support, passerelle IA, notifications, paiements, entitlements, stockage, audit et observabilité. Ne pas déclarer leur production opérationnelle sur simple mention documentaire ; vérifier code, tests et disponibilité.

## 25. Exigences non fonctionnelles, sécurité et continuité

### 25.1 Isolation et RLS

- Toutes les données possèdent une portée d'organisation et, quand nécessaire, d'activité/site/dépôt/caisse.
- Les relations B2B n'accordent que des accès explicitement prévus.
- Tests négatifs inter-tenant obligatoires : un détaillant ne lit pas un autre détaillant ; un distributeur ne lit pas les commandes de ses concurrents ; un site n'accède pas à une autre activité sans permission.
- Vérifications côté serveur et RLS pour chaque accès.
- Aucun accès client par clé privilégiée.
- Les pièces jointes suivent les mêmes règles que leurs dossiers.

### 25.2 Sécurité des données et documents

- Chiffrement en transit et stockage protégé selon capacités de la plateforme.
- Documents photo/PDF : taille, type, antivirus/contrôle, permissions, durée et audit.
- QR/lien partageable : jeton opaque, portée limitée, expiration, révocation, journalisation, aucun secret ou donnée sensible en clair.
- Les données des clients ne sont pas envoyées à l'IA sans nécessité, permission et minimisation.
- Exports sensibles protégés et tracés.

### 25.3 Sauvegarde et restauration

- Base locale protégée et sauvegarde serveur chiffrée.
- Copie indépendante du stockage opérationnel.
- Politique de rétention et chiffrement documentés.
- Export récupérable des données de l'organisation.
- Vérification d'intégrité, inventaire de sauvegardes et alertes d'échec.
- Test régulier de restauration dans un environnement isolé.
- Test de cohérence après restauration : ventes, caisses, mouvements, dettes, commandes, pièces jointes, relations B2B et audit.
- Pas de statut VERT sans preuve de restauration.

### 25.4 Performance et résilience

- Recherche locale performante sur catalogue étendu.
- Pagination/filtrage côté serveur et index adaptés.
- Compression images/PDF, synchronisation incrémentale et tolérance réseau instable.
- Pas de double commande, double vente, double mouvement ou double activation d'entitlement après répétition/reprise d'événement.
- Gestion explicite des conflits multi-appareils et multi-caisses.
- Journal de synchronisation consultable par support autorisé.

### 25.5 Compatibilité

- Android natif Kotlin/Jetpack Compose, téléphones d'entrée de gamme.
- Scanners caméra, imprimantes thermiques Bluetooth et lecteurs compatibles via interfaces prises en charge.
- Tests sur appareils réels/émulateur, petites tailles d'écran, réseau lent et absence de réseau.
- Une éventuelle application Web/PWA est un client distinct utilisant les contrats backend/API partagés ; aucune conversion automatique du code Android n'est présumée.

## 26. Critères de recette et non-régression

La recette doit être réalisée par lots et au niveau transversal. Chaque test possède un résultat attendu, des données de test non réelles, une preuve et une version.

### 26.1 Caisse

- vente cash, crédit, Mobile Money et paiement mixte ;
- remise autorisée et refus hors permission ;
- retour partiel, avoir, remboursement et annulation avec motif ;
- ouverture/clôture, écart théorique/réel et réconciliation ;
- absence de double vente après synchronisation ou événement rejoué ;
- reçu PDF, WhatsApp préparé et impression compatible.

### 26.2 Stock et catalogue

- import Excel correct, doublon, ligne invalide, conversion invalide ;
- aperçu avant import et confirmation requise ;
- import initial crée des mouvements ;
- inventaire scanné et correction auditée ;
- vente décrémente le bon lot et le bon site ;
- transfert avec validation du réceptionnaire ;
- alertes de stock sans doublon ;
- emplacement retrouvé par recherche ;
- recherche locale fluide sur au moins 5 000 fiches et scan code-barres hors connexion ;
- FEFO, péremption, lot rappelé et produit bloqué.

### 26.3 Profils métiers

- Boulangerie : recette → consommation → lot produit → vente → invendu/perte.
- Poissonnerie/boucherie : poids réceptionné → préparation → poids vendable → perte → marge réelle.
- Shopping : taille/couleur/sac/bijou, variantes, retour/échange.
- Quincaillerie : achat carton → conversion → vente au mètre/pièce.
- Cave : carton/casier/bouteille/fût et consignes.
- Dépôt gaz : échange, consigne, propriété/détention, défaut et retour.
- Ferme : lot récolte/collecte et perte.
- Supérette/supermarché : multi-caisses, rayons, inventaire et péremption.
- Brocante : article unique, réservation concurrente et prévention de double vente.

### 26.4 CRM et finances

- crédit plafonné, acompte, paiement partiel, retard et relance ;
- dettes clients distinctes des dettes fournisseurs ;
- charges récurrentes et justificatif ;
- rapprochement trésorerie ;
- rapport CA versus encaissé ;
- marge et pertes ;
- accès comptable à portée limitée, expiration/révocation.

### 26.5 Distributeurs et réseau

- création d'un compte détaillant et demande de connexion ;
- rejet d'une relation incompatible ou hors zone ;
- connexion acceptée et fin/révocation ;
- prix privés visibles uniquement au détaillant concerné ;
- commande manuelle et commande auto-soumise à validation ;
- le distributeur accepte/refuse/propose modification ;
- modification de prix/quantité requiert validation détaillant ;
- plafond de crédit dépassé bloque ou exige approbation ;
- disponibilité en retard clairement identifiée ;
- picking, expédition, preuve de livraison, réception partielle ;
- facture, paiement partiel, recouvrement et retour ;
- aucun doublon lors de la répétition d'un événement de stock ;
- isolation RLS entre distributeurs/détaillants/sites.

### 26.6 Abonnement

- essai 72h unique et non réinitialisable ;
- montants des quatre offres mensuelles/annuelles, ristourne de deux mensualités et refus des durées 3/6 mois ;
- paiement pending ne donne pas les droits success ;
- webhook dupliqué n'active pas deux fois ;
- remboursement/révocation et historique ;
- sites multiples couverts par une seule souscription organisationnelle ;
- ACCÈS conserve les modules métier fondamentaux ;
- aucun plan Pro générique.

### 26.7 Offline, sécurité et restauration

- ventes et mouvements offline, reconnexion et idempotence ;
- perte réseau pendant soumission de commande ;
- conflit multi-appareils ;
- refus RLS inter-tenant ;
- utilisateur révoqué ;
- sauvegarde chiffrée et restauration complète ;
- notification unique par événement ;
- journal d'audit complet.

**Règle de sortie :** une phase n'est déclarée VERT qu'après réussite des tests applicables et présence des preuves. Un écran, une compilation ou un test isolé ne suffisent pas.

## 27. Plan de réalisation

| Phase | Priorité | Livrables attendus |
|---|---|---|
| 1. Fondations et contrats | Immédiate | Organisation, activités, profils, sites, rôles, audit, offline/sync, sauvegarde, billing, catalogue extensible et contrats B2B. |
| 2. Catalogue, stocks et caisse | Détaillant | Articles, unités, modèles Excel, emplacements, inventaires, ventes, caisses, reçus, retours et synchronisation. |
| 3. Achats, CRM et finance | Détaillant | Fournisseurs, commandes, clients, ardoise, fidélité, charges, dettes, trésorerie, rapports. |
| 4. Verticaux Détaillants | Détaillant | Quatorze profils, règles métier, écrans, données et tests dédiés. |
| 5. Pilotage et services | Détaillant | IA, notifications, WhatsApp préparé, support, intégrations, exports et tableau de bord. |
| 6. ERP Distributeurs | Deuxième univers | Fournisseurs, import, WMS, prix, ventes B2B, crédit, flotte, livraisons, finance. |
| 7. CRM et réseau | Deuxième univers | Comptes détaillants, compatibilité, connexion, catalogue partagé, commandes et validation. |
| 8. Automatisation et recette globale | Transversal | Auto-réapprovisionnement borné, validations humaines, tests complets, sécurité et restauration. |

## 28. Décisions ouvertes, strictement limitées

Les points ci-dessous sont des paramètres de conception détaillée, ils ne remettent pas en cause les univers, profils, modules ou tarifs validés :
1. Matrice détaillée de compatibilité métier et qualification des partenaires par zone.
2. Valeurs par défaut des seuils et plafonds d'auto-soumission ; chaque organisation les configure.
3. Traitement de la facturation d'une organisation exploitant simultanément Détaillant et Distributeur sous le même compte.
4. Validation professionnelle des sorties fiscales/SYSCOHADA et documents réglementaires par secteur.
5. Sélection des dispositifs et intégrations matérielles réellement supportés.

Toute question non tranchée doit être traitée comme paramètre ouvert, sans bloquer le socle ni réinterpréter les décisions validées.

## 29. Règle de changement et de non-régression

- Toute demande de modification indique la décision antérieure, la nouvelle décision, la date, le motif, les écrans/modules/données affectés et les tests de régression.
- Une amélioration doit préserver les fonctionnalités listées dans ce cahier.
- Aucune migration destructive ou suppression d'une donnée historique sans stratégie de migration, sauvegarde vérifiée et autorisation.
- Aucun déploiement, publication APK, changement de Production, migration Supabase partagée ou push sur branche protégée sans l'accord explicite requis.
- Les livraisons documentaires peuvent être isolées dans une branche dédiée et revues avant intégration.


## 30. Complément validé le 26 novembre 2026 — Security et communication
Intégrer NAXA SECURITY par contrats BOOTIK autorisés : caméras, visualisation en direct, alertes, incidents, journal, multisite, pointage et révocation des accès. Support : livechat, tickets, appels audio, visioconférence bidirectionnelle, partage d’écran sur consentement explicite et révocable, sans contrôle distant implicite. Sessions bornées au tenant/site/permission et expirables ; aucun flux ni secret de caméra dans les logs, aucun enregistrement implicite. Adaptation RTC NAXA après audit et tests, sans réutiliser les comptes pharmacie. Traitement en bulk multi-niveaux.
