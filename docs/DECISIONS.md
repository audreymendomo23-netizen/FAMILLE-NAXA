# Registre des décisions

| ID | Décision | État |
|---|---|---|
| FAM-001 | Dix applications autonomes dans un nouveau monorepo indépendant du dépôt NAXA historique | VALIDÉ |
| FAM-002 | Dépôt de référence audreymendomo23-netizen/FAMILLE-NAXA | VALIDÉ |
| FAM-003 | Branche main uniquement | VALIDÉ |
| FAM-004 | APK depuis le site NAXA, sans Play Store | VALIDÉ |
| FAM-005 | Backend Supabase NAXA partagé après audit, sans duplication inutile | VALIDÉ SOUS CONDITION |
| FAM-006 | Aucune migration Production, aucun déploiement ni APK publiée sans accord explicite | VALIDÉ |
| FAM-007 | Nom GrillaD retenu ; disponibilité de marque/domaine à vérifier | RETENU |
| FAM-008 | GrillaD : porc braisé, poulet braisé, poisson braisé, brochettes, omelettes uniquement | VALIDÉ |
| FAM-009 | GrillaD : Manager autonome, Manager + un vendeur, Manager + plusieurs vendeurs sur lieux précis | VALIDÉ |
| FAM-010 | Dix applications Android entièrement natives, chacune avec sa version Web responsive installable en PWA ; aucune WebView-wrapper | VALIDÉ |
| FAM-011 | Android : Kotlin 2.4.21, AGP 9.3.1, Gradle 9.5.0, JDK17, API37/min26, Compose BOM 2026.09.00, Room 2.8.5, DataStore, WorkManager, Keystore, Ktor 3.0.3 et supabase-kt 3.5.0 | VALIDÉ POUR LE CADRAGE ; PREUVE CI REQUISE |
| FAM-012 | Web : Next.js 16.4.6, React 19.3.0, TypeScript strict, Serwist 9.5.13 et pnpm 12.21.0 ; dix PWA autonomes | VALIDÉ POUR LE CADRAGE ; PREUVE CI REQUISE |
| FAM-013 | Monorepo : dix modules Android indépendants + dix apps Web indépendantes + packages communs limités | VALIDÉ |
| FAM-014 | Backend Supabase unique partagé ; comptes Auth utilisateurs distincts par plateforme ; Administrateur central sur un compte dédié ; autorisations et données métier cloisonnées par app/organisation/lieu, sans duplication des ressources canoniques NAXA | VALIDÉ COMME CIBLE ; INTÉGRATION À PROUVER |
| FAM-015 | Aucun schéma Famille exposé au Data API sans grants minimaux et RLS/policies testés | VALIDÉ COMME EXIGENCE |
| FAM-016 | AGP 9.3.1 : Kotlin intégré désactivé temporairement afin d'utiliser KGP 2.4.21 ; migration requise avant AGP 10 | TRANSITOIRE DOCUMENTÉ |
| FAM-017 | Un seul Administrateur central Famille pour les dix plateformes ; accès transversal limité aux métadonnées d'administration, comptes, états, abonnements, paramètres et agrégats autorisés ; aucune lecture des transactions métier détaillées | VALIDÉ |
| FAM-018 | Identités utilisateurs distinctes par plateforme : un compte Auth utilisateur ordinaire ne peut être rattaché qu'à une seule application ; l'Administrateur central dispose d'un compte dédié hors memberships applicatifs | VALIDÉ |
| FAM-019 | L'Administrateur central peut effectuer les opérations d'administration autorisées ; toute mutation doit être journalisée de façon append-only avec acteur, application, organisation/lieu si applicable, action, cible et horodatage | VALIDÉ |
| FAM-020 | Pour toutes les solutions du portefeuille, les abonnements sont proposés au mois ou à l'année uniquement ; l'annuel donne 12 mois de service contre 10 mensualités payées (2 mois offerts) ; aucune offre ni formule de 3 ou 6 mois | VALIDÉ — 21/11/2026 |
| FAM-021 | NAXA HOTEL : les clients hébergés accèdent sans application ni compte à un portail Web de séjour par QR de chambre, limité au catalogue hôtel, aux catalogues ZIPPLE/NAXA SERVICES pour les services absents de l'hôtel, au lien Marketplace LOYABLE et au lien pharmacie publique NAXA | VALIDÉ — 22/11/2026 |
| FAM-022 | LOYABLE : publication et accès à la réservation hôtelière gratuits pour un hôtel utilisateur NAXA HOTEL avec abonnement actif ; hôtel externe facturé 10 000 FCFA/mois et intégré/administré par l'administration centrale | VALIDÉ — 22/11/2026 |
| FAM-023 | NAXA HOTEL : lorsqu'un établissement exploite un restaurant et/ou un bar, les commandes client par QR sans application sont gérées via ZIPPLE ; commandes, caisses, stocks et domaines restent séparés, imputation au folio soumise à validation | VALIDÉ — 22/11/2026 |
| FAM-024 | NAXA HOTEL : le socle NAXA SECURITY est inclus dans l'abonnement unique, quelle que soit la présence d'un service de restauration ; les capacités additionnelles au-delà du socle contractuel sont chiffrées au besoin ; aucun matériel ni service humain de télésurveillance fourni par NAXA | VALIDÉ — 22/11/2026 ; clarification tarifaire FAM-025 |

| FAM-025 | NAXA HOTEL : un abonnement unique mensuel sans paiement annuel ; prix dynamique selon le nombre de chambres et l'exploitation d'un service de restauration ; barèmes publics pour 1–49 chambres, devis mensuel négocié dès 50 chambres et pour les groupes multi-hôtels ; quantité de chambres arrêtée à chaque renouvellement sans rétroactivité. Cette règle est une exception propre à NAXA HOTEL au régime général FAM-020 ; détail au cahier, section 24. | VALIDÉ — 22/11/2026 |

## Décisions GRILLAD consolidées — 21 novembre 2026

| ID | Décision | État |
|---|---|---|
| GRD-001 | GRILLAD commercialise strictement cinq familles : porc, poulet, poisson, brochettes et omelettes ; aucune sixième famille de restauration | VALIDÉ — 21/11/2026 ; complément de FAM-008 |
| GRD-002 | Le canal de vente retenu dans la baseline GRILLAD est la vente directe uniquement ; pas de réservation, précommande, marketplace, prise de commande par tiers ou livraison | VALIDÉ — 21/11/2026 |
| GRD-003 | Le suivi des préparations reste simple : quantités préparées, vendues et restantes ; pas de traçabilité avancée de cuisson | VALIDÉ — 21/11/2026 |
| GRD-004 | Gestion multisite GRILLAD avec deux modes de données : indépendant et centralisé, avec droits paramétrables et conservation de la ventilation par établissement | VALIDÉ — 21/11/2026 |
| GRD-005 | Le périmètre financier métier GRILLAD comprend caisse, dépenses, coûts de revient et marges ; les indicateurs de gestion ne constituent pas une comptabilité certifiée | VALIDÉ — 21/11/2026 |
| GRD-006 | Les formules commerciales GRILLAD sont exclusivement ACCÈS et PREMIUM ; la souscription est rattachée à l'organisation/Promoteur. Aucun abonnement séparé par vendeur n'est créé. La portée exacte d'une souscription et ses capacités sont définies par les entitlements des deux formules. | VALIDÉ — correction du 21/11/2026 |
| GRD-007 | ACCÈS correspond à un point de vente pouvant compter plusieurs vendeurs ; PREMIUM correspond à plusieurs points de vente pouvant compter chacun plusieurs vendeurs. Aucun palier PRO ni tarification automatique en fonction du nombre de points n'est retenu. | VALIDÉ — correction du 21/11/2026 |
| GRD-008 | Pour GRILLAD, la périodicité annuelle est différenciée par formule : ACCÈS est facturé 12 mensualités pour 12 mois ; PREMIUM est facturé 10 mensualités pour 12 mois (2 mois offerts). Aucune formule de 3 ou 6 mois. | VALIDÉ — tarifs spécifiques GRILLAD du 21/11/2026 |
| GRD-009 | Parrainage QR/commissions, assistant IA complet et fonctionnement offline étendu sont mentionnés comme validés dans GRILLAD V1.0, mais leur preuve primaire n'a pas été retrouvée dans les sources conversationnelles accessibles ; confirmation requise avant gel définitif | À RECONFIRMER — ne pas présumer leur livraison |
| GRD-010 | QR GRILLAD Connect via ZIPPLE, pointage GPS du personnel, Fulfulde, Livechat, notifications distantes et intégration NAXA SECURITY ne sont pas inclus dans la baseline confirmée ; ce sont des propositions ou points ouverts | PROPOSÉ / OUVERT / BLOQUÉ SELON SUJET |
| GRD-011 | Architecture GRILLAD : un Promoteur peut gérer plusieurs points de vente ; chaque point peut employer plusieurs vendeurs simultanément, chacun avec son propre compte et des ventes attribuées au vendeur et au point. | VALIDÉ — 21/11/2026 |
| GRD-012 | Les architectures ACCÈS/PREMIUM sont définies comme mono-point avec plusieurs vendeurs possibles pour ACCÈS, et multi-points avec plusieurs vendeurs possibles par point pour PREMIUM. Aucun plafond numérique de vendeurs ou de points Premium n'est inventé à ce stade. | VALIDÉ — 21/11/2026 ; quotas non définis |
| GRD-013 | Tarifs GRILLAD validés : ACCÈS = 2 000 FCFA/mois et 24 000 FCFA/an ; PREMIUM = 6 000 FCFA/mois et 60 000 FCFA/an. | VALIDÉ — 21/11/2026 |
| GRD-014 | Tarification annuelle différenciée : ACCÈS = 12 mensualités pour 12 mois sans mois offert ; PREMIUM = 10 mensualités pour 12 mois avec 2 mois offerts. Cette règle est une exception GRILLAD au mécanisme annuel générique et doit être encodée au niveau du plan. | VALIDÉ — 21/11/2026 |

**Note de gouvernance GRILLAD :** les trois configurations Manager de FAM-009 (Manager seul ; Manager + un vendeur ; Manager et plusieurs vendeurs sur plusieurs lieux) sont conservées. Elles décrivent l'organisation humaine et opérationnelle, distincte des deux modes de gestion des données de GRD-004 (indépendant / centralisé). Les cinq arbitrages GRD-001 à GRD-005 sont retrouvés dans les échanges récents ; les points GRD-009 restent explicitement à reconfirmer. Les statuts validés concernent les décisions produit, pas l'état d'implémentation logicielle.


## Décisions COTIZ 360° — baseline fonctionnelle V2.1 du 22 novembre 2026

| ID | Décision | État |
|---|---|---|
| COT-001 | Un compte personnel COTIZ unique par personne, réutilisable dans plusieurs tontines et communautés COTIZ ; pas de fusion automatique avec les identités des autres applications Famille NAXA | VALIDÉ |
| COT-002 | Inscription personnelle gratuite ; compte non vérifié limité à Discover, fiches publiques et statuts publics ; aucune adhésion, cotisation, conversation privée ou création | VALIDÉ |
| COT-003 | Vérification COTIZ ID gratuite par NAXA, avec dossier CNI, photo, plan et localisation ; documents et GPS strictement privés, nécessité/proportionnalité et rétention à valider juridiquement | VALIDÉ SOUS RÉSERVE JURIDIQUE |
| COT-004 | Coche bleue = identité contrôlée, sans garantie de solvabilité ou de comportement | VALIDÉ |
| COT-005 | Seul un utilisateur vérifié peut soumettre une création ; chaque tontine nécessite une approbation NAXA distincte avant activation | VALIDÉ |
| COT-006 | Associations, GIC, groupes d'initiatives et communautés institutionnelles intégrés par NAXA après validation du partenariat et des représentants | VALIDÉ |
| COT-007 | Invitation, adhésion et attribution d'un rôle sont séparées ; le membre accepte explicitement son poste et ses permissions | VALIDÉ |
| COT-008 | Les membres d'une tontine peuvent utiliser une messagerie sociale ; les conversations ne remplacent jamais le ledger, les votes ou les décisions métier | VALIDÉ |
| COT-009 | Les statuts éphémères sont réservés aux tontines et organisations autorisées, visibles aux utilisateurs COTIZ, photos/vidéos, expiration publique après 24 heures | VALIDÉ |
| COT-010 | Recherche publique par nom, ville et proximité ; aucune exposition de l'adresse ou des coordonnées GPS exactes du domicile | VALIDÉ |
| COT-011 | Statistiques de vues et visiteurs uniques ; cartes populaires animées avec contrôle des animations ; popularité séparée de Trust | VALIDÉ |
| COT-012 | COTIZ Boost facultatif, publicité étiquetée ; les paiements publicitaires n'altèrent pas la réputation ni le classement organique | VALIDÉ |
| COT-013 | Appels audio de groupe et visioconférences de groupe prévus ; fournisseur, quotas, coûts et règles d'enregistrement à valider | VALIDÉ POUR LA CIBLE |
| COT-014 | Français et anglais pour l'interface initiale ; Fulfulde prioritaire pour la voix puis extension progressive aux autres langues camerounaises après tests natifs | VALIDÉ |
| COT-015 | Double réputation : score personnel COTIZ partageable avec consentement et score interne par groupe ; formule exacte à versionner et à arbitrer avant production | VALIDÉ POUR LE PRINCIPE |
| COT-016 | Cinq modes de détermination des tours : ordre fixe, tirage auditable, vote, ordre négocié et ordre conditionnel | VALIDÉ |
| COT-017 | Suivi documentaire des cotisations, trésoreries, objectifs, prêts, garanties et solidarité ; aucune détention/transmission de fonds par défaut | VALIDÉ |
| COT-018 | Collecte d'épargne, crédit, intérêts, cautions, garanties et services de paiement restent conditionnels à un avis juridique écrit et aux autorisations/partenariats nécessaires | CONDITIONNEL |
| COT-019 | Abonnement standard par groupe et effectif ; membre non facturé individuellement ; grilles Découverte à Fédération définies dans le cahier V2.1 | VALIDÉ COMME BASELINE COMMERCIALE DE TRAVAIL |
| COT-020 | Remise annuelle COTIZ de 15 %, exception explicite à FAM-020 (10 mensualités pour 12 mois) | VALIDÉ COMME EXCEPTION PRODUIT |
| COT-021 | Parrainage membres, groupes et partenaires, récompense liée à une activation réelle et contrôles antifraude | VALIDÉ POUR LE PRINCIPE |
| COT-022 | Fédération conçue dès le départ, avec facturation centralisée possible et autonomie/permissions propres aux tontines filles | VALIDÉ |
| COT-023 | COTIZ Android natif Kotlin/Compose et Web/PWA séparée ; réutilisation des composants NAXA Family uniquement après audit de compatibilité, données et permissions | VALIDÉ COMME CIBLE |
| COT-024 | Aucun changement code, migration Supabase Production, déploiement ou publication APK sans autorisation explicite distincte | VALIDÉ — RÈGLE DE DÉPÔT |

Les détails, états, critères d'acceptation et réserves sont définis dans `docs/cahiers-des-charges/COTIZ_360_V2_1.md` et `docs/audits/COTIZ_AUDIT_CONTRADICTIONS_V2_1.md`. Les statuts VALIDÉ concernent les orientations produit, pas leur implémentation technique ni la conformité réglementaire.
