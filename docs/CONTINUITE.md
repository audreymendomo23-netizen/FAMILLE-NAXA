# Continuité — Famille NAXA

> Mise à jour : 20 novembre 2026  
> Référence de continuité pour l'audit documentaire, l'architecture et la construction du monorepo.

## 1. Périmètre officiel

Le projet comprend **10 applications autonomes** :

| Écosystème | Applications |
|---|---|
| Fintech | KIOSKO, COTIZ |
| ERP | BOOTIK, ZIPPLE, LOYABLE, GRILLAD |
| Business | NAXA SERVICES, NAXA HOTEL, NAXA SECURITY |
| Edtech | CAMPUS237 |

Ce périmètre correspond aux neuf applications initialement retenues hors JOBLY et NAXA Pharmacie, auxquelles GRILLAD a été ajouté explicitement.

**JOBLY et NAXA Pharmacie ne sont pas des applications à construire dans ce monorepo.** Elles peuvent servir de références documentaires et techniques après audit, sans importer aveuglément leurs modèles métier ou leurs droits d'accès.

## 2. Dépôt et règles de gouvernance

- Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA`.
- Branche de travail : `main`, conformément aux instructions du dépôt.
- Le dépôt est public : aucun secret, jeton, mot de passe, OTP, export de données personnelles ou donnée client réelle ne doit y être ajouté.
- Aucun déploiement, aucune migration Supabase Production et aucune publication APK sans autorisation explicite distincte.
- Les opérations suivent la séquence : **audit → contradictions → cause racine → correction → tests/preuves → documentation → état**.
- Toute décision doit être classée : validée [V], proposition [P], ouverte [O], constatée [C] ou bloquée [B].
- Ne jamais déclarer un composant opérationnel sur la seule base d'un document, d'un écran ou d'un build. Il faut des tests et des preuves.

## 3. État du dépôt au dernier contrôle

- Le dépôt contient les documents de cadrage initiaux ; le code applicatif complet des dix produits n'est pas établi par les contrôles réalisés.
- Le README et `docs/ARCHITECTURE_CIBLE.md` définissent dix APK Android autonomes, une expérience Web responsive/PWA lorsque pertinente, et une réutilisation conditionnelle du backend Supabase historique.
- Les packages envisagés (`auth`, `ui`, `domain`, `supabase`, `offline`, `observability`, `i18n`) sont des intentions d'architecture, pas des composants dont l'existence est démontrée.
- État de preuve : code métier des dix applications NON ÉTABLI ; recette métier globale NON EXÉCUTÉE ; audit complet RLS inter-applications NON ACHEVÉ ; migration Production NON AUTORISÉE ; déploiement NON AUTORISÉ.

## 4. Sources documentaires des applications

### 4.1 Dossiers avec cahier Markdown et prompts retrouvés

Les documents historiques suivants ont été consultés dans le dépôt NAXA, branche `main` :

| Application | Cahier de référence | Dossier de prompts | Éléments structurants |
|---|---|---|---|
| KIOSKO | `7 famille naxa/01-cahiers-des-charges/01-kiosko.md` | `7 famille naxa/02-prompts/01-kiosko.md` | SMS Mobile Money, parseur versionné, transactions, float, commissions, alertes livreur, multi-points, parrainage et administration des abonnements |
| BOOTIK | `7 famille naxa/01-cahiers-des-charges/02-bootik.md` | `7 famille naxa/02-prompts/02-bootik.md` | Commerce multi-profils, ventes, stock, ardoise, fournisseurs, comptabilité, multi-boutiques et dépôt de gaz |
| ZIPPLE | `7 famille naxa/01-cahiers-des-charges/03-zipple.md` | `7 famille naxa/02-prompts/03-zipple.md` | Tables, tickets, carte, recettes, ingrédients, service, consignes, braiseur et rentabilité |
| NAXA SERVICES | `7 famille naxa/01-cahiers-des-charges/04-naxa-services.md` | `7 famille naxa/02-prompts/04-naxa-services.md` | Pressing, coiffure, dépôts/retraits, agenda, prestataires, commissions et consommables |
| COTIZ | `7 famille naxa/01-cahiers-des-charges/05-cotiz.md` | `7 famille naxa/02-prompts/05-cotiz.md` | Groupes, membres, cotisations, tours, pénalités, séances, épargne, prêts internes et garanties |
| LOYABLE | `7 famille naxa/01-cahiers-des-charges/06-loyable.md` | `7 famille naxa/02-prompts/06-loyable.md` | Biens, contrats, locataires, calendrier des loyers, quittances, charges, travaux, cautions et multi-propriétaires |
| NAXA HOTEL | `7 famille naxa/01-cahiers-des-charges/07-naxa-hotel.md` | `7 famille naxa/02-prompts/07-naxa-hotel.md` | Chambres, réservations, check-in/out, folio, ménage, maintenance, économat, postes et multi-hôtels |
| GRILLAD | `7 famille naxa/01-cahiers-des-charges/08-grillad.md` | `7 famille naxa/02-prompts/08-grillad.md` | ERP strictement consacré aux grillades, trois modes Manager, lieux physiques précis, préparation, cuisson, rendement, ventes et clôture de soirée |

GRILLAD est une application autonome et non un module de ZIPPLE. Son catalogue métier est limité aux cinq familles validées : porc braisé, poulet braisé, poisson braisé, brochettes et omelettes. Les boissons, accompagnements, repas complets et desserts restent hors périmètre sauf décision expresse ultérieure.

Les trois modes GRILLAD sont obligatoires :
1. Manager autonome sur un lieu, sans vendeur obligatoire.
2. Manager et un vendeur sur un lieu.
3. Manager supervisant plusieurs vendeurs sur plusieurs lieux précis.

Chaque lieu, affectation, session, stock, caisse, vente et dépense doit être rattaché à un lieu autorisé. La géolocalisation de présence est limitée au service ; elle ne doit pas devenir une surveillance hors service. Les stocks et caisses de lieux distincts ne se mélangent jamais.

### 4.2 Documents à compléter avant validation finale

- **CAMPUS237** : le PDF `Cahier_des_charges_08_Campus237.pdf` a été localisé à la racine du dépôt historique. Son contenu intégral et son dossier de prompts dédié ne sont pas encore vérifiés dans la présente reprise. Ne pas compléter son périmètre par supposition.
- **NAXA SECURITY** : le PDF `Cahier_des_charges_09_NAXA_Security.pdf` a été localisé à la racine du dépôt historique. Sa direction générale est documentée dans les dossiers de cadrage et techniques, mais la lecture intégrale du cahier PDF et le dossier complet de prompts doivent encore être vérifiés.
- Pour ces deux applications, récupérer les textes intégraux, versions, annexes et décisions [V]/[P]/[O], puis les intégrer dans le référentiel documentaire du monorepo sans effacer leur provenance.

## 5. Principes métier à ne pas uniformiser

- KIOSKO est un système de gestion Mobile Money, avec un parseur SMS et un pilotage de float ; ce n'est pas une caisse générique.
- BOOTIK possède plusieurs profils de commerce et un profil dépôt de gaz avec bouteilles pleines/vides, consignes, échanges et livraisons.
- ZIPPLE gère la restauration, le service et les recettes ; son profil braiseur ne remplace pas GRILLAD.
- NAXA SERVICES gère des prestations de pressing et de coiffure ; son stock est volontairement léger.
- COTIZ tient les registres et calculs d'un groupe ; il ne détient ni ne transfère les fonds des membres.
- LOYABLE suit les biens, contrats, loyers, cautions, travaux et revenus locatifs.
- NAXA HOTEL est un PMS avec réservations, risques de double réservation hors connexion, folios, ménage, maintenance et clôture de nuit.
- NAXA SECURITY est un ERP logiciel de sécurité vidéo/audio et d'alertes ; l'entreprise ne fournit pas les caméras ou équipements et n'assure pas la surveillance humaine.
- GRILLAD est un ERP spécialisé pour les cinq familles de grillades validées, avec trois modes d'organisation et des lieux physiques géolocalisés.
- CAMPUS237 doit être cadré à partir de son cahier complet, avec protection renforcée des données concernant les mineurs et les représentants légaux.

## 6. Références JOBLY — éléments à étudier pour enrichir les dix applications

### 6.1 Sources réellement consultées et limite de l'audit

Les documents JOBLY accessibles dans la bibliothèque comprennent notamment :
- `03_JOBLY_Dossier_Technique_Complet.pdf` ;
- `Pack_Documentaire_JOBLY_2026.pdf` ;
- `00_ECOSYSTEME_JOBLY_DOCUMENT_MAITRE_V2.pdf`.

**Le ZIP du projet JOBLY annoncé par l'utilisateur n'était pas présent dans les pièces jointes accessibles lors de cette mise à jour, et aucun ZIP Jobly correspondant n'a été retrouvé dans la bibliothèque interrogée.** Le code source du ZIP n'a donc pas été audité. Les éléments ci-dessous sont des inspirations tirées des documents JOBLY, pas des affirmations que le code ZIP les implémente déjà.

### 6.2 Inspiration prioritaire : Billing, Abonnements et Entitlements

Le modèle JOBLY à étudier est :

**Plan → Subscription → Payment → Entitlements**

La fonction métier ne doit pas seulement lire le nom commercial du plan. Elle doit vérifier des droits explicites, par exemple l'accès à une fonction, une limite d'utilisation, un quota ou l'absence de publicité.

Les spécifications JOBLY consultées mentionnent :
- abstraction du fournisseur de paiement ;
- webhooks vérifiés et idempotents ;
- clé d'idempotence pour éviter les doubles crédits ;
- états documentés : `initiated`, `pending`, `success`, `failed`, `refunded` ;
- réconciliation périodique des paiements ;
- tarifs et devises configurables ;
- différenciation entre offre gratuite limitée et offre payante avec droits supplémentaires ;
- quotas IA attachés à un plan.

**Orientation proposée pour Famille NAXA : créer un module Billing & Entitlements nettement défini et réutilisable**, puis l'adapter aux unités facturables propres à chaque application.

Le module devra au minimum distinguer :
1. Catalogue des offres et versions tarifaires datées.
2. Plans et périodicités (mensuel, annuel, période d'essai ou gratuit si le produit le prévoit).
3. Souscription d'une organisation ou de l'unité facturable définie par l'application.
4. Paiements, preuves, statuts et rapprochements.
5. Droits d'accès activés par plan et période.
6. Quotas et limites (utilisateurs, membres, sites, chambres, appareils, opérations, stockage ou usages IA selon le produit).
7. Historique, renouvellement, échéance, suspension et réactivation selon des règles à arbitrer.
8. Journal d'audit des validations et changements tarifaires.

Les unités facturables restent propres aux produits : point de vente pour KIOSKO, boutique pour BOOTIK, établissement pour ZIPPLE, membres pour COTIZ, biens ou unités contractuelles pour LOYABLE, établissement/prestataires pour NAXA SERVICES, chambres ou établissement pour NAXA HOTEL, organisation/sites/capacités pour NAXA SECURITY, parents ou unité retenue pour CAMPUS237, et unité validée pour GRILLAD.

**Ne pas copier les prix JOBLY dans les autres applications.** Chaque produit conserve son catalogue, ses prix, ses limites et ses règles de renouvellement. Les tarifs et unités de chaque application doivent être validés séparément.

### 6.3 Contrôle d'accès par fonctionnalité

À privilégier :
- vérifier un droit technique explicite (`ENTITLEMENT_CODE`) plutôt que coder en dur des conditions du type « si plan = Premium » ;
- centraliser les définitions de droits, tout en conservant leur attribution par application ;
- appliquer les contrôles côté serveur et dans les règles RLS lorsque les données sont concernées ;
- afficher clairement à l'utilisateur pourquoi une fonction ou une limite est indisponible ;
- tester les cas offre gratuite, abonnement actif, échu, paiement en attente, paiement échoué et remboursement ;
- éviter qu'un simple changement d'écran, de téléphone ou de cache accorde un droit non validé.

### 6.4 Feature flags et configuration à distance

S'inspirer du back-office JOBLY et prévoir une gestion administrable des fonctions activées :
- activation/désactivation d'une fonction par application ;
- configuration par environnement, organisation, plan ou segment autorisé ;
- activation progressive et retour arrière ;
- date d'effet, motif, auteur et journal d'audit ;
- séparation claire entre droit commercial (entitlement) et expérimentation/configuration (feature flag).

Un feature flag ne doit jamais remplacer une permission métier ou une règle de sécurité. Une fonction masquée visuellement doit aussi être refusée côté serveur si l'utilisateur n'a pas le droit correspondant.

### 6.5 Engagement, contenu et campagnes

Éléments JOBLY à étudier comme capacités optionnelles :
- gestion de bannières avec liens d'action (CTA) ;
- annonces et messages d'information administrables sans nouvelle APK ;
- campagnes programmées, dates de début/fin, ciblage et fréquence d'affichage ;
- bibliothèque de contenus ou vidéos courtes avec catégories, miniatures, modération et statistiques, uniquement pour les produits où ce format a une utilité ;
- espaces sponsorisés clairement identifiés, activables uniquement si le modèle commercial de l'application le prévoit.

Ne pas imposer la publicité à toutes les applications. Les politiques FREE/PREMIUM ou avec/sans publicité restent une décision de chaque produit et doivent respecter les engagements tarifaires faits aux clients.

### 6.6 Notifications et préférences utilisateur

S'inspirer du centre de notifications JOBLY :
- catégories transactionnelles, sécurité, abonnement, opérations, rappels, information et marketing ;
- préférences configurables par l'utilisateur et par canal ;
- historique, statut lu/non lu et anti-doublon par événement ;
- suivi envoyé/livré/ouvert lorsqu'il est disponible ;
- plages de silence et règles de priorité ;
- aucun message sensible ne doit contenir de PIN, OTP ou secret.

Les notifications indispensables à la sécurité ou à une opération contractuelle doivent être distinguées des messages marketing désactivables.

### 6.7 Assistance conversationnelle et escalade humaine

JOBLY décrit un parcours : application → chat → FAQ/IA → résolution ou transfert vers WhatsApp Business/agent humain.

Cette capacité peut être étudiée pour les dix applications, mais il faut d'abord auditer le centre d'assistance déjà documenté dans NAXA : tickets, boîte support, files, agents, chat, voix/vidéo, partage d'écran et SLA. Ne pas reconstruire un module déjà présent sans vérifier sa couverture, son état réel, ses limites et sa compatibilité.

Les échanges doivent respecter les consentements, la confidentialité, les règles des canaux officiels et la conservation minimale nécessaire. Les secrets restent côté serveur.

### 6.8 Partage sécurisé par QR ou lien temporaire

Le modèle JOBLY de partage contrôlé est une inspiration intéressante pour certains parcours :
- identifiant opaque, sans données sensibles directement encodées dans le QR ;
- portée limitée (document, reçu, profil, quittance, preuve ou rapport) ;
- expiration configurable ;
- révocation immédiate ;
- permissions explicites et journalisation des consultations.

Candidats d'usage : quittances LOYABLE, reçus COTIZ, tickets BOOTIK/ZIPPLE, documents CAMPUS237, rapports GRILLAD ou accès temporaires à certains éléments. Chaque usage doit être validé par le cahier du produit et par les exigences de confidentialité. Ce mécanisme ne remplace pas l'authentification de l'espace privé.

### 6.9 Mesure des coûts, quotas et observabilité

JOBLY prévoit des mesures par domaine : latence/erreurs API, coût et durée IA, files de tâches, paiements, notifications, campagnes et activation/rétention produit.

À étudier pour Famille NAXA :
- coût IA par fonctionnalité, utilisateur et application ;
- quotas d'IA/OCR et limites d'usage selon offre ;
- budgets et alertes de dépenses ;
- métriques de notifications et campagnes ;
- taux de succès/échec/remboursement des paiements ;
- consommation et rétention du stockage ;
- suivi des erreurs, latences, files et synchronisations ;
- tableaux de bord d'exploitation et d'usage.

Les indicateurs transversaux doivent être limités à des métadonnées ou agrégats autorisés. Ils ne doivent pas ouvrir à l'administration centrale l'accès aux opérations métier ou aux dossiers personnels des clients.

### 6.10 Réseau de partenaires et parrainage

JOBLY documente le parcours partenaire : KYC, code de parrainage, attribution, commission, validation et paiement. Ce modèle peut inspirer un moteur d'attribution et de suivi pour les canaux commerciaux de la Famille NAXA.

À ne pas généraliser automatiquement :
- le KYC doit être adapté au type de partenaire et à la réglementation ;
- les commissions doivent être définies par contrat et application ;
- les paiements/payouts ne doivent pas être activés sans validation juridique, financière et opérationnelle ;
- la logique de partenariat JOBLY n'est pas une autorisation de créer un portefeuille financier dans les applications.

## 7. Architecture et garde-fous familiaux

### 7.1 Trois couches

1. **Family Control Plane** : registre des applications, métadonnées, versions, catalogue et configurations globales strictement nécessaires.
2. **Shared Technical Foundation** : composants techniques mutualisés après audit de compatibilité (authentification, sécurité, RBAC, audit, offline/sync, notifications, Billing/Entitlements, feature flags, observabilité, stockage, localisation et tests).
3. **Application Domains** : données, parcours, règles métier, écrans et permissions propres à chacune des dix applications.

### 7.2 Identités et administration

Les identités restent séparées par application. Aucun SSO ni partage de compte utilisateur transversal n'est introduit par défaut.

L'administration centrale conserve un accès limité aux métadonnées, au catalogue des produits, aux licences et aux paramètres autorisés. Elle ne reçoit pas un accès général aux données métier des clients ou aux dossiers personnels. Les opérations privilégiées sont toutes auditées et soumises au moindre privilège.

Les fonctions de facturation peuvent partager un contrat technique et des références de paiement, sans fusionner les grands livres, caisses et opérations des applications.

### 7.3 Supabase et sécurité des données

- Réutiliser les ressources du backend NAXA uniquement après inventaire et audit de compatibilité.
- Distinguer Production `eouwtuusnsuxaejsxknf` et Replay `pwfftcsjyeibxxqhwysw`.
- Avant toute migration : inventorier tables, colonnes, contraintes, index, fonctions/RPC, triggers, vues, extensions, RLS, GRANT, SECURITY DEFINER, search_path, Storage et dépendances.
- Comparer Replay et Production ; classer chaque ressource : réutiliser, adapter, créer ou écarter.
- Préparer et tester des migrations additives sur Replay ; ne rien appliquer en Production sans autorisation.
- RLS et contrôles serveur obligatoires ; aucune clé `service_role` côté client.
- Un backend partagé ne crée aucun droit d'accès transversal implicite.

## 8. Priorités de travail mises à jour

1. Obtenir le ZIP du projet JOBLY annoncé par l'utilisateur et en auditer le code réel : structure, modules, abonnements, entitlements, paiements, configuration, back-office, sécurité, tests et dépendances.
2. Compléter la lecture documentaire intégrale CAMPUS237 et NAXA SECURITY, avec leurs prompts, annexes et décisions.
3. Construire la matrice officielle des dix applications et de leurs capacités métier, en indiquant source, statut [V]/[P]/[O], module réutilisable, dépendances, données, API et tests.
4. Construire la matrice comparative « Famille NAXA existant / apports JOBLY / à construire / à adapter / non retenu », avec preuves de code et non simples affirmations documentaires.
5. Spécifier le module Billing & Entitlements : plans, subscriptions, paiements, droits, quotas, unités facturables, cycle de vie, audit et tests.
6. Auditer et définir les feature flags, le back-office de contenu/campagnes, les préférences de notifications, le suivi des coûts IA et le partage QR sécurisé.
7. Auditer les ressources Supabase Replay/Production sans appliquer de migration.
8. Valider l'architecture et le plan de livraison par application avant le développement métier.

## 9. Points ouverts à arbitrer

- ZIP Jobly : à recevoir et inspecter ; aucune conclusion de code n'est possible avant accès au fichier.
- CAMPUS237 : périmètre complet, prompts et règles fonctionnelles à relire.
- NAXA SECURITY : cahier complet, prompts, limites matérielles et lots réellement opérationnels à confirmer.
- Billing : entité facturée, unités, durée, prorata, essai, échéance, grâce, suspension, remboursement et réactivation à définir application par application.
- Tarification : aucun tarif JOBLY ne doit être copié dans l'une quelconque des dix applications Famille NAXA ; conserver les arbitrages propres à chaque produit.
- Engagement : décider pour chaque produit quels contenus, campagnes, publicités, chat et QR ont une utilité réelle.
- Support : comparer l'existant documenté NAXA avec le besoin de chaque application avant de développer.
- Partenaires : règles de commission, KYC, validation et paiement à définir par canal et par produit.
- Les éléments [P] et [O] des cahiers restent à arbitrer et ne deviennent pas des règles par simple présence dans un document.

## 10. État de continuité et reprise

**État actuel : audit documentaire enrichi, architecture non verrouillée, construction métier non établie.**

À la reprise, commencer par récupérer le ZIP Jobly, établir les preuves du code correspondant aux apports documentés, puis mettre à jour la matrice comparative et le module Billing & Entitlements. Ne pas lancer de migration Production, déploiement ou publication APK dans le cadre de cette reprise.


### 6.11 Matrice d'application des inspirations JOBLY aux dix produits

Cette matrice est une **proposition de portabilité fonctionnelle**, pas un engagement de construire toutes les fonctions dans chaque application. Chaque activation doit être confrontée au cahier métier, au modèle économique et aux contraintes légales du produit.

| Capacité inspirée de JOBLY | Applications candidates | Décision d'orientation |
|---|---|---|
| Billing & Entitlements | Les 10 applications | Socle commun prioritaire ; règles, unités facturables, tarifs, quotas et droits propres à chaque application |
| Feature flags / configuration à distance | Les 10 applications | Socle commun ; configuration auditable, sans remplacer RBAC/RLS ni les contrôles serveur |
| Centre de notifications et préférences | Les 10 applications | Socle commun ; catégories propres au produit, préférences marketing séparées des alertes opérationnelles |
| Bannières / annonces administrables | Les 10 applications, selon pertinence | Module optionnel ; informations, campagnes, CTA, dates et ciblage par application |
| Publicité sponsorisée | Seulement produits dont le modèle commercial le justifie | Option commerciale distincte, jamais imposée ni présentée comme déjà validée |
| Chat / FAQ / IA / handoff humain | Les 10 applications, selon charge de support | Parcours d'assistance réutilisable ; auditer le service Support NAXA déjà documenté avant tout développement |
| QR ou lien de partage temporaire | KIOSKO, BOOTIK, ZIPPLE, COTIZ, LOYABLE, NAXA SERVICES, NAXA HOTEL, CAMPUS237, NAXA SECURITY, GRILLAD | Bibliothèque de partage sécurisé optionnelle ; portée minimale, expiration, révocation et audit |
| Quotas et mesure du coût IA | Toutes les applications qui utilisent l'IA ou OCR | Socle d'observabilité ; quotas par entitlement, mesure par fonction et alertes de budget |
| Referral / partenaires / attribution | KIOSKO d'abord ; autres produits B2B selon leurs canaux | Moteur d'attribution réutilisable ; commissions, KYC et paiements activés uniquement après validation métier et juridique |

#### Exemples d'adaptation métier

- **KIOSKO :** droits liés aux fonctions de caisse/float, nombre de points, appareils ou options activés ; annonces de service et alertes ; QR/lien de reçu à accès limité si utile. La surveillance des paiements d'abonnement doit rester distincte des transactions Mobile Money des clients.
- **BOOTIK :** droits par boutique, utilisateurs, volume d'articles ou fonctions avancées ; campagnes promotionnelles de produits ; partage temporaire de factures ou reçus. Les limites doivent tenir compte des profils commerce et dépôt de gaz.
- **ZIPPLE :** droits par établissement ou capacité convenue ; annonces de menus, événements et offres ; QR de commande, ticket ou partage de facture selon le parcours choisi.
- **NAXA SERVICES :** droits par salon/pressing, prestataires ou fonctionnalités ; rappels et campagnes de fidélité ; lien limité pour ticket de dépôt, reçu ou statut de linge.
- **COTIZ :** droits par groupe ou membre selon la tarification validée ; notifications de séance et échéances ; reçus ou relevés partageables sous contrôle. Aucune publicité intrusive dans les échanges d'un groupe et aucune commission de parrainage ne doit être supposée.
- **LOYABLE :** droits par portefeuille, bien ou unité convenue ; annonces et rappels de loyers ; liens temporaires pour quittances ou états des lieux avec consentement et journalisation.
- **NAXA HOTEL :** droits par établissement, chambre ou capacité contractuelle ; campagnes et annonces hôtelières ; QR/lien de réservation ou de facture avec durée et portée contrôlées. Les règles de réservation et de chambre restent dans le PMS.
- **CAMPUS237 :** droits selon le modèle par parent, établissement ou autre unité validée ; annonces ciblées par établissement/classe/parent ; QR temporaires pour documents ou opérations scolaires, avec protection renforcée des données des mineurs.
- **NAXA SECURITY :** droits par organisation, site, équipement ou capacité convenue ; notifications et alertes de service ; liens d'accès à des preuves/événements soumis à permissions renforcées, expiration et audit. Aucune publicité ne doit perturber une alerte de sécurité.
- **GRILLAD :** droits selon organisation, Manager, vendeurs, lieux ou capacité convenue ; annonces d'exploitation et informations d'activité ; QR/lien temporaire pour reçu ou rapport. Les trois modes Manager et les cloisonnements par lieu restent inchangés.

#### Comparatif préliminaire avec les capacités historiques de NAXA

- **Déjà documenté dans l'écosystème NAXA :** authentification et permissions, audit, offline/synchronisation, notifications, abonnements/paiements, tableaux de bord/BI et une plateforme d'assistance avec tickets, agents, files et fonctions de communication.
- **À approfondir avec l'apport JOBLY :** séparation formelle Plan/Subscription/Payment/Entitlement, webhooks idempotents et réconciliation, droits de fonction/quotas indépendants du nom du plan, préférences de notification, gestion de campagnes/contenus depuis un back-office, mesure détaillée des coûts IA par fonction, et partage QR à jeton opaque avec expiration/révocation.
- **À prouver avant de classer comme réutilisable :** état de code, couverture des tests, compatibilité des schémas, sécurité RLS, séparation des applications et intégration réelle de chaque capacité.
- **À ne pas reconstruire sans audit :** le support client NAXA, les notifications, les paiements, le BI et les fonctions QR/barcode déjà existantes dans certains domaines. Leur présence dans un cahier ou une architecture ne prouve toutefois pas qu'elles sont complètes ni prêtes à être mutualisées.

