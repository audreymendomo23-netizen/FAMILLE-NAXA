# Continuité — Famille NAXA

> Mise à jour : 22 novembre 2026  
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
- Les migrations Supabase nécessaires au périmètre FAMILLE-NAXA sont autorisées par décision explicite du propriétaire du projet, sans demande d'autorisation répétée à chaque migration. Elles restent soumises à la procédure de contrôle définie en section 6.17. Une modification du projet NAXA indépendant, de son IA ou de ses données métier hors périmètre FAMILLE-NAXA n'est pas autorisée par cette décision.
- Les opérations suivent la séquence : **audit → contradictions → cause racine → correction → tests/preuves → documentation → état**.
- Toute décision doit être classée : validée [V], proposition [P], ouverte [O], constatée [C] ou bloquée [B].
- Ne jamais déclarer un composant opérationnel sur la seule base d'un document, d'un écran ou d'un build. Il faut des tests et des preuves.

## 3. État du dépôt au dernier contrôle

- Le dépôt contient les documents de cadrage initiaux ; le code applicatif complet des dix produits n'est pas établi par les contrôles réalisés.
- Le README et `docs/ARCHITECTURE_CIBLE.md` définissent dix APK Android autonomes, une expérience Web responsive/PWA lorsque pertinente, et une réutilisation conditionnelle du backend Supabase historique.
- Les packages envisagés (`auth`, `ui`, `domain`, `supabase`, `offline`, `observability`, `i18n`) sont des intentions d'architecture, pas des composants dont l'existence est démontrée.
- État de preuve au dernier audit documenté : code métier complet des dix applications NON ÉTABLI ; recette métier globale NON EXÉCUTÉE ; audit complet RLS inter-applications NON ACHEVÉ. L'autorisation générale d'exécuter les migrations Supabase du périmètre FAMILLE-NAXA est désormais accordée (section 6.17), mais aucune migration n'est déclarée exécutée par le seul fait de cette autorisation. Déploiements et publications restent soumis à leurs règles propres.

## 4. Sources documentaires des applications

### 4.1 Dossiers avec cahier Markdown et prompts retrouvés

Les documents historiques suivants ont été consultés dans le dépôt NAXA, branche `main` :

| Application | Cahier de référence | Dossier de prompts | Éléments structurants |
|---|---|---|---|
| KIOSKO | `7 famille naxa/01-cahiers-des-charges/01-kiosko.md` | `7 famille naxa/02-prompts/01-kiosko.md` | SMS Mobile Money, parseur versionné, transactions, float, commissions, alertes livreur, multi-points, parrainage et administration des abonnements |
| BOOTIK | `7 famille naxa/01-cahiers-des-charges/02-bootik.md` | `7 famille naxa/02-prompts/02-bootik.md` | Commerce multi-profils, ventes, stock, ardoise, fournisseurs, comptabilité, multi-boutiques et dépôt de gaz |
| ZIPPLE | `7 famille naxa/01-cahiers-des-charges/03-zipple.md` | `7 famille naxa/02-prompts/03-zipple.md` | Tables, tickets, carte, recettes, ingrédients, service, consignes, braiseur et rentabilité |
| NAXA SERVICES | `7 famille naxa/01-cahiers-des-charges/04-naxa-services.md` | `7 famille naxa/02-prompts/04-naxa-services.md` | Pressing, coiffure, dépôts/retraits, agenda, prestataires, commissions, fidélité et parrainage client |
| COTIZ | `7 famille naxa/01-cahiers-des-charges/05-cotiz.md` | `7 famille naxa/02-prompts/05-cotiz.md` | Groupes, membres, cotisations, tours, pénalités, séances, épargne, prêts internes et garanties |
| LOYABLE | `7 famille naxa/01-cahiers-des-charges/06-loyable.md` | `7 famille naxa/02-prompts/06-loyable.md` | Biens, contrats, locataires, calendrier des loyers, quittances, charges, travaux, cautions et multi-propriétaires |
| NAXA HOTEL | `7 famille naxa/01-cahiers-des-charges/07-naxa-hotel.md` | `7 famille naxa/02-prompts/07-naxa-hotel.md` | Chambres, réservations, check-in/out, folio, ménage, maintenance, économat, postes et multi-hôtels |
| GRILLAD | `7 famille naxa/01-cahiers-des-charges/08-grillad.md` | `7 famille naxa/02-prompts/08-grillad.md` | ERP spécialisé grillades ; Promoteur, points de vente multiples, plusieurs vendeurs par point, préparation simple, ventes directes, caisse et rentabilité |

GRILLAD est une application autonome et non un module de ZIPPLE. Son catalogue métier est limité aux cinq familles validées : porc braisé, poulet braisé, poisson braisé, brochettes et omelettes. Les boissons, accompagnements, repas complets et desserts restent hors périmètre sauf décision expresse ultérieure.

**Architecture hiérarchique obligatoire : Promoteur / Organisation → plusieurs points de vente → plusieurs vendeurs par point de vente.** Un Promoteur peut exploiter plusieurs points ; chaque point peut affecter plusieurs vendeurs simultanément, chacun avec un compte individuel. Chaque vente est attribuée au vendeur connecté et au point de vente concerné.

Les configurations d'exploitation comprennent :
1. Manager autonome sur un point de vente, sans vendeur obligatoire.
2. Manager et plusieurs vendeurs sur un même point.
3. Manager réseau supervisant plusieurs points, chacun doté de plusieurs vendeurs et éventuellement d'un responsable local.

Deux modes de données restent distincts : indépendant (chaque point gère séparément ses opérations) et centralisé (le Promoteur partage certains paramètres et consulte une consolidation autorisée, sans fusion des caisses, stocks ou ventes). Chaque affectation, préparation, session, stock, caisse, vente et dépense est rattaché à un point de vente précis. Les droits d'un vendeur sont limités aux points qui lui sont attribués. Le pointage GPS du personnel reste non validé et ne doit pas être assimilé à la géolocalisation du point de vente.

Dans un point employant plusieurs vendeurs, les ventes concurrentes doivent être attribuées correctement. Le modèle de caisse (caisse commune du point ou sessions/tiroirs par vendeur) reste un arbitrage fonctionnel ouvert.

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
- GRILLAD est un ERP spécialisé pour les cinq familles validées, organisé en réseau de plusieurs points de vente avec plusieurs vendeurs par point ; les lieux sont localisés, mais aucun suivi GPS permanent du personnel n'est prévu.
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
- mesure interne de la consommation IA, protections de débit et mécanismes anti-abus, sans facturation supplémentaire au client.

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

**Règle commerciale transversale FAM-020 — décision du 21 novembre 2026 :** pour toutes les solutions du portefeuille, les seules périodicités d'abonnement sont mensuelle et annuelle. Le paiement annuel donne 12 mois de service pour l'équivalent de 10 mensualités, soit 2 mois offerts. Aucune solution ne peut proposer de formule de 3 mois ou de 6 mois, ni une promotion cumulée qui accorderait 3 ou 6 mois d'accès. Chaque cahier produit doit reprendre cette règle sans inventer de tarif annuel différent.

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
- Préparer et tester les migrations sur l'environnement Replay/recette, comparer les schémas et dépendances, puis appliquer les migrations FAMILLE-NAXA nécessaires aux environnements concernés sans redemander une autorisation par migration, conformément à la décision utilisateur de la section 6.17. Les migrations ne doivent pas altérer les tables, fonctions, politiques, données, configurations ou services IA propres au projet NAXA indépendant.
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


### 6.11 Matrice anti-doublon NAXA / JOBLY pour les dix applications

**Règle de priorité : NAXA est la source de vérité pour les produits, les processus métier, les identités, les données et les fonctions déjà définies dans FAMILLE-NAXA. JOBLY est uniquement une source d'inspiration technique complémentaire.** Une capacité ne sera ni copiée ni développée en parallèle si un équivalent existe déjà dans le socle NAXA ou dans une application.

| Domaine | Source propriétaire / existante à privilégier | Apport JOBLY autorisé | Décision anti-collision |
|---|---|---|---|
| Paiements et abonnements | Socle NAXA/KIOSKO et contrats propres à chaque produit | Patrons robustes de cycle de paiement, webhook, idempotence, rapprochement et modèle Plan/Subscription/Payment/Entitlements | Renforcer le parcours existant après audit ; un seul moteur de paiement/facturation, aucune seconde table ou API parallèle |
| Droits fonctionnels et quotas | RBAC, permissions et configuration NAXA | Modèle d'entitlements et quotas métier/IA dissociés du nom du plan | Compléter les droits existants sans remplacer RBAC/RLS ni créer un second système d'autorisations |
| Intelligence artificielle | Socle AI/IA NAXA et besoins propres à chaque application | Patterns AI Gateway multi-fournisseurs, fallback, journalisation, limitation des entrées, minimisation des données et mesure des coûts | Étendre le moteur IA NAXA s'il existe déjà ; ne pas créer un deuxième gateway ou deux registres de fournisseurs |
| Mémoire et contexte IA | Données opérationnelles NAXA, historique métier et permissions de chaque application | Patterns de contexte, mémoire de session et mémoire dérivée | Ajouter uniquement une couche dérivée et cloisonnée si un besoin non couvert est démontré ; la base métier NAXA reste la source de vérité |
| Notifications | Socle notifications NAXA | Idées de préférences, catégories et mesure de livraison/engagement | Réutiliser le service NAXA ; compléter seulement les fonctions réellement absentes, pas de second centre ni de second moteur d'envoi |
| Support et assistance | Stack Support NAXA déjà documentée (tickets, files, agents, chat, voix/vidéo, SLA) | Parcours FAQ/IA et transfert humain décrits par JOBLY | Pas de nouveau Helpdesk/Chat ; améliorer le support NAXA après audit de couverture |
| QR, codes-barres et partage | Capacités QR/barcode déjà prévues dans certains produits NAXA | Principes de sécurité du partage : jeton opaque, expiration, portée minimale, révocation, audit | Garder les flux QR existants ; renforcer leur sécurité dans leur module propriétaire, sans créer un service QR concurrent |
| Audit, événements et BI | Audit centralisé et BI/tableaux de bord NAXA | Patterns d'instrumentation d'événements et de coûts par fonction | Un registre d'audit et une chaîne analytique cohérente ; enrichir les événements existants sans dupliquer les journaux métier |
| Feature flags et configuration distante | Registre produits, feature flags et remote config déjà prévus dans l'architecture NAXA | Aucun module générique correspondant n'a été confirmé dans le ZIP JOBLY | NAXA reste propriétaire ; ne pas attribuer cette capacité au code JOBLY ni en importer un doublon |
| Géolocalisation et mobilité | Modèles de sites, lieux et opérations territoriales propres aux applications NAXA | Helpers GPS, calcul de distance et étapes de validation JOBLY | Réutilisation ponctuelle seulement après comparaison ; les règles de localisation de GRILLAD, SECURITY et des autres produits restent NAXA |
| Contenus et viralité | Identité visuelle et parcours commerciaux propres à chaque produit | Helpers de génération/partage de contenu JOBLY, si utiles | Pas de CMS marketing commun par défaut ; vérifier d'abord les outils NAXA existants et activer uniquement pour un besoin produit validé |
| Parrainage, Partner et commissions de referral JOBLY | Aucun transfert depuis JOBLY | **Aucun** | **EXCLU : ne pas reprendre, adapter, copier ou intégrer les modules, tables, API, interfaces, rôles, parcours KYC, codes de parrainage, attribution, commissions ou payout Partner de JOBLY.** |

#### Garde-fous communs aux dix applications

- Identités et espaces de données distincts par application ; aucun SSO ou mémoire globale inter-applications implicite.
- L'administration centrale FAMILLE-NAXA gère les métadonnées et configurations autorisées ; elle n'accède pas aux dossiers opérationnels ni aux données personnelles des clients.
- L'audit des opérations privilégiées reste centralisé selon les règles NAXA ; les opérations métier restent cloisonnées.
- Une capacité commune fournit un service technique ou une bibliothèque ; elle ne fusionne jamais les règles métier des produits.
- Les prix et règles JOBLY ne deviennent jamais des prix, contrats ou droits des applications NAXA.

## 6.12 Audit statique du code source JOBLY — ZIP complet

**Source examinée :** `Jobly-JIA-V5-20-20-21-09-2026.zip`, snapshot dont les entrées datent du 21/09/2026, environ 458 fichiers répartis dans 240 dossiers. L'audit a couvert le catalogue d'abonnements, les API de paiement, les droits/quota, l'orchestration IA, les migrations SQL, les rôles partenaires, le partage par lien/QR, les politiques RLS et les rapports de validation présents dans l'archive.

**Verdict :** JOBLY apporte de bonnes références d'architecture et plusieurs composants candidats, mais le code n'est pas un module prêt à copier dans FAMILLE-NAXA. Les parties métier JOBLY doivent être séparées des fondations réutilisables et plusieurs incohérences doivent être corrigées avant toute reprise.

**Périmètre explicitement exclu :** tout ce qui concerne le parrainage, JOBLY Partner, les partenaires, le KYC partenaire, les codes de referral, l'attribution de parrainage, les commissions et les payout. Aucun code, schéma, table, API, interface ou workflow de cette famille ne doit être repris de JOBLY.

### Briques JOBLY conservées comme références candidates

1. **Billing & abonnements :** séquence Plan → Subscription → Payment → Entitlements ; catalogue de formules ; états de paiement ; historique ; rapprochement ; webhook et clé d'idempotence. Ces patrons ne servent qu'à renforcer le dispositif NAXA existant : un seul moteur canonique après audit.
2. **Entitlements & quotas :** droits fonctionnels et limites de capacité par formule, séparés du nom du plan. À intégrer au modèle de droits NAXA sans créer de second RBAC, de seconde autorité de permission ou de tables concurrentes.
3. **Usage IA & coûts :** journal de consommation par fonction, utilisateur, modèle, fournisseur, durée et crédits ; réservation atomique des crédits ; seuils et alertes de budget. Reprendre le patron seulement après correction des compensations d'échec.
4. **AI Gateway :** registre d'adaptateurs de fournisseurs, orchestration, fallback déterministe, contrôle des entrées, minimisation de données, contexte contrôlé et validation humaine. À considérer comme extension éventuelle du socle AI NAXA, jamais comme un deuxième moteur IA.
5. **Contexte et mémoire IA :** patterns de mémoire/session et de contexte utilisateur. À utiliser uniquement comme couche dérivée, par application et par autorisation ; les données métier NAXA demeurent la source de vérité.
6. **Sécurité des liens et QR :** principes de jeton opaque, portée minimale, expiration, révocation et audit. À appliquer aux flux QR NAXA existants après audit, sans nouveau service QR concurrent.
7. **Instrumentation produit :** mesures d'usage, de durée, d'erreur et de coût par fonction. À brancher sur l'audit/BI NAXA existant plutôt que créer un second journal ou un entrepôt de données parallèle.
8. **Helpers GPS/mobilité et partage de contenus :** composants ponctuels à évaluer au besoin ; ne pas en faire automatiquement des services transverses ou modifier les règles de géolocalisation propres aux produits.

### Anomalies et limites bloquantes relevées dans le ZIP

- **Incohérence schéma/API abonnements :** le schéma Prisma et la migration initiale portent `Subscription.plan`; les API JOBLY lisent/écrivent `planCode`. La migration partenaire ajoute `productType`, mais le schéma Prisma livré n'est pas synchronisé. Aucune migration du ZIP examinée n'ajoute `Subscription.planCode`. À résoudre avant reprise ou exploitation.
- **Facturation Recruiter incomplète :** un catalogue séparé Recruiter existe, mais la route principale d'abonnement appelle le catalogue Talent ; la route Entitlements retourne également les droits Talent après avoir déterminé le type de profil. Le cycle B2B ne constitue donc pas une implémentation générique et complète.
- **Paiement non prêt pour production :** le fournisseur IClan pointe par défaut vers l'environnement de test et utilise des routes `/api/test/`. Le remboursement observé change le statut local du paiement et annule l'abonnement, sans appel de remboursement au fournisseur.
- **Idempotence à renforcer :** la clé est vérifiée avant création puis enregistrée après l'appel au fournisseur ; cette séquence ne réserve pas atomiquement la clé avant l'initiation et peut laisser un risque de double tentative concurrente.
- **Cycle d'abonnement incomplet :** le code fourni ne démontre pas le renouvellement automatique, la relance d'impayé, la période de grâce ou l'expiration automatique fondée sur `currentPeriodEnd`. Les droits dépendent surtout du statut enregistré.
- **Comptabilisation IA à corriger :** les crédits sont réservés avant l'appel au runtime ; les chemins d'échec du runtime ne libèrent pas systématiquement la réservation ni ne marquent la consommation en échec. Deux listes de coûts IA existent en parallèle.
- **Partage QR/lien non généralisable tel quel :** la table `QRShare` utilise un hash de token mais le QR Jobly ID construit une référence déterministe ; le flux CVShare stocke un token utilisable et ne définit pas d'expiration lors de sa création. Le principe de partage limité est intéressant, pas une implémentation de sécurité prête à mutualiser.
- **Capacités non trouvées comme modules génériques opérationnels :** feature flags/remote config, moteur complet de notifications push et préférences de notification globales, CMS de campagnes/bannières/publicités, centre de support/tickets, moteur SMS Mobile Money, noyau offline/synchronisation métier multi-applications. Ne pas les considérer comme livrés par JOBLY.
- **Architecture mono-produit :** les rôles Talent/Recruiter et le rôle Admin de JOBLY ne remplacent pas l'isolation des dix applications ni la règle FAMILLE-NAXA selon laquelle l'admin central gère les métadonnées sans accès aux dossiers opérationnels clients. Les rôles et modules Partner sont explicitement exclus du périmètre de reprise.

### Pistes de facturation à étudier par application

Ces dimensions sont des unités de mesure candidates, pas des tarifs ni des arbitrages commerciaux approuvés :

| Application | Unités/capacités à étudier dans les Entitlements |
|---|---|
| KIOSKO | Point de vente, opérateurs, appareils et options. Abonnement KIOSKO strictement séparé des opérations Mobile Money des clients. |
| COTIZ | Groupe, membres actifs et fonctionnalités de gestion. L'abonnement ne doit jamais transformer COTIZ en détenteur ou opérateur des fonds des membres. |
| BOOTIK | Boutique, point de vente, utilisateurs, capacité catalogue et options propres au profil commerce/dépôt de gaz. |
| ZIPPLE | Établissement, sites, utilisateurs et modules opérationnels restauration/bar/braiseur. |
| LOYABLE | Portefeuille, biens/unités locatives et comptes propriétaires/gestionnaires. |
| NAXA SERVICES | Établissement pressing/salon, personnel et capacité des rendez-vous/tickets. |
| NAXA HOTEL | Hôtel, chambres, utilisateurs et modules PMS activés. |
| NAXA SECURITY | Organisation, sites, capacité d'équipements/flux et conservation ; respecter les extensions de capacité déjà décidées et la séparation des données de sécurité. |
| CAMPUS237 | Conserver le modèle commercial déjà arbitré par parent ; étudier les droits par parent/établissement sans remplacer le tarif validé. |
| GRILLAD | Organisation Promoteur, points de vente multiples, plusieurs vendeurs par point, responsables locaux, caisse par point et capacités ACCÈS/PREMIUM. |

### Niveau de confiance et prochaines étapes

- **Réutilisable après refonte :** concepts Billing/Entitlements, suivi de consommation, moteur IA abstrait, attribution partenaire, journal d'audit et préférences.
- **À reconstruire ou corriger avant intégration :** schéma et cycle Billing, adaptateurs de paiement, remboursements, idempotence concurrente, QR/liens sécurisés, mécanismes internes de mesure et de compensation des appels IA échoués, sans facturation d'usage au client.
- **Non démontré dans ce snapshot :** validation build/runtime complète. Le ZIP ne contient ni `node_modules` ni fichier lockfile ; les rapports embarqués signalent encore des parcours E2E à exécuter et une traduction FR/EN non certifiée. Cet audit est statique ; aucun build, test contre un fournisseur réel ou test de base de données n'a été exécuté ici.
- **Règles de reprise :** ne pas copier les prix JOBLY ; ne pas migrer la base JOBLY dans Supabase FAMILLE-NAXA ; ne pas fusionner les identités ; ne pas donner au central admin accès aux données opérationnelles ; appliquer les migrations Supabase du périmètre FAMILLE-NAXA selon l'autorisation et les contrôles de la section 6.17 ; ne pas altérer le projet NAXA indépendant ou son IA ; les déploiements applicatifs et publications APK restent soumis à une autorisation distincte.


## 6.13 Directive de non-collision et registre d'intégration NAXA / JOBLY

Cette directive est obligatoire pour toute conception, modification du monorepo ou récupération de code JOBLY.

### Ordre de priorité des sources

1. **Cahiers des charges et arbitrages NAXA approuvés :** autorité sur les besoins, règles métier, modèles d'accès, unités de gestion, données et résultats attendus de chaque application.
2. **Code, schémas, migrations et tests NAXA existants :** autorité sur toute capacité déjà présente techniquement. Son niveau réel doit être vérifié ; une fonctionnalité seulement documentée ne doit pas être déclarée opérationnelle.
3. **JOBLY :** source secondaire de patrons techniques seulement, sans priorité sur une décision NAXA et sans importation de domaine métier JOBLY.

### Procédure obligatoire avant d'ajouter un composant JOBLY

Pour chaque capacité candidate :
- rechercher le composant NAXA correspondant dans le code, les packages, les API, les schémas et les migrations ;
- vérifier les cahiers des charges et les arbitrages de l'application concernée ;
- classifier la capacité NAXA : opérationnelle, partielle, seulement documentée, absente ou à remplacer ;
- identifier un seul module propriétaire, un seul contrat d'API canonique et une seule autorité de données ;
- si NAXA possède déjà le module, conserver son propriétaire et n'utiliser JOBLY que pour combler un défaut précis, via une extension ou un adaptateur ;
- si aucune capacité NAXA n'existe, proposer un nouveau module seulement après validation de son périmètre, de ses dépendances et de ses règles d'isolation ;
- documenter les tests de non-régression, droits/RLS, séparation des applications, mode hors ligne si pertinent et journalisation avant intégration.

### Règles anti-collision techniques

- Interdiction de créer deux tables ayant la même responsabilité métier, deux services concurrents ou deux systèmes de permissions pour une même capacité.
- Interdiction de dupliquer les notifications, paiements, QR, support, audit, BI, configuration distante ou moteur IA sans preuve d'un besoin distinct et décision écrite.
- Une bibliothèque commune peut mutualiser des algorithmes ou adaptateurs ; elle ne peut pas fusionner les bases opérationnelles, les identités ou les politiques métier.
- Les noms, schémas, API et événements existants NAXA sont conservés comme contrats canoniques, sauf décision de refonte explicite.
- Toute fonction inspirée de JOBLY doit être étiquetée comme candidate, adaptée, testée et validée ; jamais réputée approuvée du seul fait qu'elle apparaît dans le ZIP.
- Le parrainage et JOBLY Partner restent hors périmètre, même s'ils apparaissent dans l'archive ou dans une ancienne proposition de matrice.

### Registre initial des propriétaires de capacités

| Capacité | Propriétaire à privilégier | Rôle autorisé de JOBLY |
|---|---|---|
| Identités, organisations, RBAC/RLS | Fondation NAXA | Aucun remplacement ; référence secondaire uniquement si un défaut concret est démontré |
| Paiements et abonnements | Contrat Billing NAXA, avec KIOSKO pour les flux de validation qui lui sont assignés | Amélioration technique après audit |
| Notifications | Service NAXA | Idées de préférences/mesures si manquantes |
| Support et assistance | Service Support NAXA | Patterns FAQ/IA/handoff si non couverts |
| QR et codes-barres métier | Modules NAXA propriétaires par application | Renforcement de sécurité uniquement |
| Audit et BI | Fondation NAXA | Instrumentation complémentaire |
| Feature flags et remote config | Administration plateforme NAXA | Aucun module JOBLY confirmé dans le ZIP |
| IA, fournisseurs et mesure des coûts | Socle AI NAXA | Adaptateur/patron multi-fournisseur et observabilité après vérification du socle existant |
| Mémoire et contexte IA | Données métier de chaque application NAXA | Couche dérivée, cloisonnée et limitée |
| GPS et mobilité | Modèles de lieux et workflows propres à NAXA | Helpers ponctuels uniquement |
| Parrainage / Partner / referral | Exclu | Aucun usage autorisé |



## 6.14 Audit global des deux dépôts et choix de la première application — 20/11/2026

L'audit global couvre désormais :
- le monorepo cible `FAMILLE-NAXA` (dix shells Android/Web-PWA, packages, contrats, design system, offline partiel, sécurité/RLS et limites des fondations) ;
- le dépôt source historique `NAXA` (authentification, permissions, paiements/SMS, caisse/POS, stock, notifications/Push, messagerie, comptabilité, BI/IA, prestations et NAXA SECURITY) ;
- le ZIP complet JOBLY comme référence technique secondaire, avec exclusion absolue de JOBLY Partner/parrainage/KYC/referral/commissions/payout.

**Décision de séquencement recommandée : commencer par NAXA SERVICES**, en raison des actifs réutilisables déjà présents pour catalogue/demandes de prestations, créneaux/rendez-vous, disponibilités, rappels, notifications, caisse, comptabilité et reporting. Ce choix ne signifie pas que ces modules sont copiables en bloc : leurs tables, identités et autorisations actuelles sont liées à l'ancien produit NAXA et notamment à `partners/partner_members` pour les prestations à domicile. NAXA Services doit posséder son propre modèle d'établissement, employés, clients, prestations, dépôts, rendez-vous et caisse dans le périmètre Famille.

**NAXA SECURITY est documenté comme patrimoine logiciel substantiel existant**, avec gateway local, ONVIF, MediaMTX/RTSPS/WHEP, événements, enregistrement local, horodatage et haute surveillance. Les lots restent partiels pour plusieurs dépendances matérielles et le pilote physique ; cette application n'est donc pas l'option la plus rapide à clôturer opérationnellement. Les PDF spécifiques Security restent à lire page par page avant sa phase de construction.

Aucun module JOBLY Partner/referral n'est autorisé. Aucune fonction NAXA existante ne doit être dupliquée sans audit et désignation d'un propriétaire canonique.

**Rapport complet :** `docs/audits/AUDIT_GLOBAL_SOURCES_NAXA_FAMILLE_ET_PRIORISATION_2026-11-20.md`. Il contient le comparatif des dix applications, l'architecture Security, les attentes fonctionnelles NAXA Services, la matrice de réemploi, les garde-fous anti-collision et les jalons J0–J3.

**État : audit et recommandation uniquement.** Aucun code métier, schéma réel, migration, déploiement ou APK n'a été modifié.


## 6.15 Démarrage NAXA SERVICES — authentification interne sans OTP ni boîte mail (20/11/2026)

Le premier chantier applicatif retenu est **NAXA SERVICES**. Son J0 doit commencer par le cycle de vie des comptes et des appareils afin d'éviter de construire les écrans métier sur un parcours de connexion non validé.

### Réponse au besoin
Un parcours visible entièrement interne est possible sans SMTP, boîte mail, SMS, OTP, magic link ni inscription libre, tout en conservant Supabase Auth comme moteur de vérification du mot de passe et des sessions. Cela ne supprime pas la dépendance au service Supabase Auth ; cela supprime la dépendance aux canaux de communication e-mail/SMS. Un fournisseur OIDC autohébergé est possible, mais ajoute un service d'identité supplémentaire à opérer et n'est pas recommandé pour le MVP.

### Option recommandée, sous réserve de preuve locale
- Identifiant d'accès NAXA généré et propre à l'application, + mot de passe personnel.
- Alias Auth technique, opaque, propre à l'application et au compte ; aucune vraie boîte mail et aucune fonction e-mail utilisée.
- Création et confirmation du compte par un backend autorisé via l'API Admin ; l'API de création directe Supabase permet une confirmation admin sans envoyer d'invitation. Le login par mot de passe utilise le flux Auth officiel.
- Activation initiale remise par un parcours interne maîtrisé, puis changement obligatoire du mot de passe.
- Récupération par vérification manuelle par l'administration, reset côté serveur, révocation des sessions à risque et changement obligatoire au prochain accès.
- Téléphone conservé comme coordonnée de contact ; pas utilisé comme identité Auth primaire si l'on maintient des comptes séparés par application.
- Aucune inscription publique, aucun SSO transversal par défaut. Chaque app conserve ses comptes/identifiants d'accès et ses droits propres.
- Verrouillage biométrique/PIN local facultatif ; ce code n'est jamais le mot de passe Auth ni une autorisation serveur.

### Réserves techniques
Supabase Auth natif accepte le mot de passe avec e-mail ou téléphone, pas avec un username arbitraire. L'alias technique constitue donc un mécanisme de résolution à valider en local : création Admin avec confirmation, acceptation de la syntaxe d'alias, login par mot de passe, absence de message envoyé, séparation des identités par application et résistance à l'énumération. Supabase avertit également du risque de recyclage du numéro de téléphone lorsqu'il sert d'identifiant. La documentation passkeys est actuellement expérimentale ; elle ne doit pas devenir une dépendance du MVP.

### Écart documentaire à traiter
Le cahier NAXA Services indique actuellement téléphone + mot de passe et récupération par e-mail/WhatsApp. Le Prompt Famille 0.4 propose aussi e-mail ou WhatsApp. Le modèle 0.2 mentionne une identité Auth partagée, alors que l'arbitrage ultérieur exige une identité utilisateur séparée. Ces documents seront harmonisés après le test technique, sans écraser l'arbitrage de séparation des identités.

**Prochaine étape J0 :** preuve locale de l'Option A, puis finalisation de l'architecture identité/appareil/session/récupération et des tests négatifs. Aucun changement des paramètres Auth d'un projet Supabase réel, aucune migration réelle, aucune modification de code métier ni aucun déploiement n'ont été effectués.

**Document détaillé :** `docs/architecture-360/DECISION_AUTHENTIFICATION_INTERNE_SANS_OTP_EMAIL.md`.


## 6.16 Première passe de construction NAXA SERVICES — 20/11/2026

### Réalisé et versionné
- Architecture multi-entités : PME autonome ; responsable avec plusieurs emplacements dans un même point de vente ; Promoteur avec plusieurs points de vente autonomes.
- Auth Android : identifiant interne + mot de passe, récupération administrée, changement initial obligatoire, option « rester connecté » (décochée par défaut) et jetons chiffrés via Android Keystore.
- Navigation Android Kotlin/Compose : accueil, agenda, pressing, caisse, catalogue, clients, équipe/commissions, consommables, rapports, organisation, réseau, sites, emplacements, sécurité/appareils, paramètres et assistance.
- Web/PWA : 16 espaces ERP, pages responsive, structure PME/multi-emplacements/réseau et formulaires d'aperçu en mémoire de session ; aucune vente ou opération métier réelle n'est créée par l'aperçu.
- Charte : sombre par défaut, noir #111111, rouge #DD3A33 et déclinaison claire ; SVG de marque reconstruit depuis la spécification écrite.
- Contrat API Auth, source Edge Function préparatoire, draft SQL et contrat de tests RLS présents.
- Le draft SQL comprend organisations, sites, postes, comptes/scopes, services, clients, rendez-vous, tickets pressing, caisse, ventes, paiements, dépenses, commissions, consommables, recovery, audit, appareils et rate limit. Transaction terminée par ROLLBACK ; aucune base n'est modifiée.

### Réserves — ne pas déclarer VERT complet
- Build Android/Gradle et build Web non exécutés localement : le clone Git a échoué sur la résolution réseau. Aucun workflow CI lancé.
- URL de la fonction Auth et clé anon à configurer localement via propriétés Gradle non versionnées ; variables Vite équivalentes absentes.
- Alias Supabase/GoTrue non prouvé. Edge Function = source non déployée ; domaine d'alias non configuré. Draft SQL (tables + helpers + policies RLS) non appliqué.
- La source Edge Function inclut désormais provisioning des membres, reset avec contrôle d'identité et révocation d'appareil ; ces opérations n'ont pas été déployées ni exécutées et l'interface Admin/Support dédiée reste à construire et tester.
- Les helpers et policies RLS de tenant/site/poste sont maintenant écrits dans le draft SQL, avec liaison session/appareil ; le draft reste non appliqué et aucun test PostgreSQL n'a été exécuté.
- Modules ERP = pages et parcours UI de construction ; opérations à connecter aux repositories, transactions atomiques, synchronisation offline, adaptateurs et recettes.
- Le SVG est une reconstruction de la spécification écrite ; l'original binaire spécifique n'a pas été récupéré de façon fiable par le connecteur pendant cette passe.

### État officiel
**UI / navigation : CONSTRUITE EN SOURCE, build non prouvé. Architecture : DOCUMENTÉE. Auth serveur : PARTIELLE / non déployée. SQL/RLS : DRAFT. Opérations métier : À CONNECTER. Recettes : NON EXÉCUTÉES. Production : INCHANGÉE. APK : NON PUBLIÉE.**

Fichiers principaux :
- apps/android/naxa-services/src/main/java/cm/naxa/naxaservices/MainActivity.kt
- apps/android/naxa-services/src/main/java/cm/naxa/naxaservices/auth/AuthApi.kt
- apps/android/naxa-services/src/main/java/cm/naxa/naxaservices/auth/SessionVault.kt
- apps/android/naxa-services/src/main/java/cm/naxa/naxaservices/NaxaServicesTheme.kt
- apps/web/naxa-services/src/main.tsx et src/naxa-services.css
- apps/web/naxa-services/public/naxa-services-logo.svg
- docs/architecture-360/NAXA_SERVICES_ARCHITECTURE_MULTI_ENTITES.md
- docs/architecture-360/NAXA_SERVICES_AUTH_API_CONTRACT.md
- supabase/functions/naxa-services-auth/ (source non déployée)
- supabase/drafts/naxa_services_v1.sql et supabase/tests/drafts/naxa_services_rls_contract.sql

## 6.17 Décisions complémentaires validées — formules, services mutualisés et autorisation Supabase (20/11/2026)

Cette section consigne les décisions explicites du propriétaire du projet. En cas de contradiction avec une formulation antérieure de ce document, la présente section prévaut pour le périmètre qu'elle couvre. Elle complète les cahiers des charges propres aux dix applications sans remplacer leurs règles métier.

### 6.17.1 Référentiel des formules fondé sur l'architecture des comptes

Les formules sont définies à partir de l'architecture de comptes et de l'unité d'exploitation réellement gérée par chaque application, et non par une segmentation artificielle de ses fonctionnalités.

- **ACCÈS — architecture à compte unique :** un Promoteur/compte principal exploite une entité ou un point d'exploitation. Toutes les fonctionnalités métier nécessaires à cette architecture sont incluses.
- **PREMIUM — architecture multiniveau :** le Promoteur organise et pilote plusieurs niveaux de comptes, responsables, collaborateurs, établissements, sites ou unités subordonnées, selon le métier de l'application. PREMIUM inclut intégralement ACCÈS et ajoute les capacités de structuration, délégation, supervision et consolidation propres au multiniveau.


La règle d'inclusion pour les applications ACCÈS/PREMIUM est impérative :
- `ENTITLEMENTS(ACCÈS) ⊆ ENTITLEMENTS(PREMIUM)` ;
- PREMIUM ne peut retirer, dégrader ou rendre indisponible aucun droit accordé par ACCÈS ;
- les écarts concernent principalement l'architecture et les capacités de pilotage, pas la suppression de fonctions métier essentielles.

Pour GRILLAD, deux formules seulement sont retenues : ACCÈS = un point de vente avec plusieurs vendeurs possibles sur ce point ; PREMIUM = plusieurs points de vente, chacun pouvant employer plusieurs vendeurs. Aucun plafond numérique ni palier PRO n'est retenu à ce stade. La distinction entre formules et les entitlements doivent respecter cette architecture, sans inventer de quotas non arbitrés.

La notion de compte unique, de multiniveau, de réseau et d'unité facturable doit être documentée pour chaque application : Promoteur propriétaire, organisation, sous-comptes, rôles, sites, points de vente, quantités facturées et droits de consolidation. Un salarié, un poste ou un appareil n'est pas automatiquement un compte ou un site facturable.

**Application à tarif unique :** afficher **« Abonnement »** sans créer ACCÈS ou PREMIUM artificiellement. Les tarifications à l'unité ou individuelles gardent leurs règles dédiées.

Les fonctions de sécurité, confidentialité, authentification, protection des données, journalisation de sécurité, continuité et récupération/export des données restent incluses et ne peuvent être réservées à une formule supérieure.

Le catalogue final et les droits doivent être vérifiés contre le cahier des charges et le modèle d'organisation de chaque application avant activation commerciale.

### 6.17.2 Catalogue tarifaire de référence — abonnements Promoteur, unités individuelles et capacités

Les montants sont exprimés en FCFA. Les unités et périodicités sont définies par produit ; les montants ci-dessous ne doivent pas être convertis en mensualités tant que la périodicité correspondante n'a pas été confirmée dans les décisions commerciales.

| Application | Formule / tarif à conserver |
|---|---|
| KIOSKO | ACCÈS : 2 000 ; PREMIUM : **5 000**. |
| BOOTIK | ACCÈS : 4 000 ; PREMIUM : 10 000. |
| ZIPPLE | ACCÈS : 5 000 ; PREMIUM : 15 000. |
| NAXA SERVICES | ACCÈS : 3 000 ; PREMIUM : **10 000**. |
| COTIZ | **Abonnement individuel par membre et par cotisation : 500**. Chaque membre paie son propre abonnement pour chaque cotisation à laquelle il participe. Le compte Président reste gratuit jusqu'à 100 membres. |
| LOYABLE | **Abonnement unique à accès complet : 1 000 FCFA × nombre de chambres actives/en gestion** dans le portefeuille du Promoteur. Montant dynamique selon la quantité de chambres ; aucun palier PREMIUM distinct. |
| NAXA HOTEL | **Abonnement unique à accès complet : 2 000 FCFA × nombre de chambres actives** rattachées à l'hôtel/réseau du Promoteur. Montant dynamique selon la quantité de chambres ; aucun palier PREMIUM distinct. |
| NAXA SECURITY | ACCÈS : 5 000 ; PREMIUM : 15 000. Conserver les règles d'extension de capacité déjà arbitrées (+20 % par extension), et appliquer l'abonnement Promoteur à tout son réseau dans les limites des capacités souscrites. |
| GRILLAD | **ACCÈS : 2 000 FCFA/mois et 24 000 FCFA/an (12 mensualités, sans mois offert). PREMIUM : 6 000 FCFA/mois et 60 000 FCFA/an (10 mensualités, deux mois offerts).** ACCÈS : un point avec plusieurs vendeurs ; PREMIUM : plusieurs points avec plusieurs vendeurs par point. Aucun tarif par paliers de points et aucun PRO. |
| CAMPUS237 | Établissement gratuit. Abonnements individuels par parent : **Pack Individuel : 1 000 pour suivre 1 élève dans une école ; Pack Famille : 3 000 pour suivre jusqu'à 5 élèves**, dans la même école ou dans plusieurs écoles différentes. |

#### Règle de souscription du Promoteur et couverture de son réseau

Pour KIOSKO, BOOTIK, ZIPPLE, NAXA SERVICES et NAXA SECURITY, un abonnement Promoteur couvre le réseau selon les capacités de la formule validée. Pour GRILLAD, une seule souscription est rattachée au Promoteur : ACCÈS autorise un point de vente ; PREMIUM autorise plusieurs points de vente, chacun pouvant compter plusieurs vendeurs. Il n'est pas créé d'abonnement par vendeur ; les éventuelles capacités de chaque formule sont contrôlées par entitlements.

Les capacités ou plafonds propres à la formule restent applicables à l'ensemble du réseau :
- GRILLAD : seuls les plans ACCÈS (un point de vente) et PREMIUM (plusieurs points de vente) sont retenus. Plusieurs vendeurs peuvent être affectés à chaque point. Les montants et les éventuels plafonds d'entitlements doivent être explicitement configurés ; aucun changement automatique de prix en fonction du nombre de points n'est approuvé.
- NAXA SECURITY : conserver les capacités d'équipement/flux souscrites et les extensions prévues (+20 % par extension).
- Pour les autres applications, aucun plafond de sites supplémentaire n'est inventé par cette règle ; appliquer les capacités définies dans leur cahier et catalogue approuvés.

Les cas facturés selon une unité ou un compte non Promoteur restent des exceptions : COTIZ (chaque membre pour chaque cotisation), LOYABLE (quantité de chambres/unités locatives), NAXA HOTEL (quantité de chambres) et CAMPUS237 (chaque parent et son pack). Une souscription unique peut porter une quantité de chambres/unités ; il ne faut pas générer plusieurs abonnements identiques pour un même Promoteur uniquement parce qu'il possède plusieurs chambres.

#### Règle d'unicité d'un pack par Promoteur et par application

Un même Promoteur ne peut détenir ni utiliser simultanément plusieurs souscriptions identiques ou plusieurs exemplaires du même pack pour une même application.

- Pour les applications à abonnement Promoteur, une seule souscription active (ou en essai, renouvellement en attente ou période de grâce) est autorisée par couple **Promoteur + application**. La portée effective de la souscription dépend des entitlements de la formule. Pour GRILLAD, ACCÈS autorise un point et PREMIUM plusieurs points ; ne pas étendre ACCÈS à tout le réseau par défaut.
- Le Promoteur dispose d'une seule souscription active par application. Pour GRILLAD, la formule ACCÈS ou PREMIUM détermine l'architecture autorisée ; aucun palier automatique ou recalcul du prix selon le nombre de points ne s'applique.
- Une souscription expirée, résiliée ou remplacée reste dans l'historique ; elle ne constitue pas une seconde souscription active.
- La règle d'unicité est appliquée côté serveur et en base de données, avec contrainte/transaction empêchant les créations concurrentes et journalisant les tentatives de doublon.
- Les exceptions COTIZ et CAMPUS237 s'appliquent à leur véritable payeur et unité : membre × cotisation pour COTIZ ; parent × application pour CAMPUS237. Un parent ne peut avoir qu'un seul pack CAMPUS237 actif à la fois ; le passage d'Individuel à Famille remplace le pack courant.
- Pour LOYABLE et NAXA HOTEL, conserver une seule souscription Promoteur par application et tout le réseau ; la quantité de chambres est portée par cette souscription et son montant est recalculé dynamiquement (1 000 FCFA/chambre LOYABLE ; 2 000 FCFA/chambre NAXA HOTEL), sans souscription distincte par chambre.

#### Règles spécifiques GRILLAD — formules ACCÈS et PREMIUM

GRILLAD ne dispose que de deux formules :

- **ACCÈS :** un point de vente ; plusieurs vendeurs peuvent y être affectés.
- **PREMIUM :** plusieurs points de vente ; chaque point peut employer plusieurs vendeurs.

Une seule souscription est rattachée au Promoteur pour GRILLAD. La formule choisie détermine la portée de l'architecture et les entitlements associés. Aucun abonnement séparé n'est créé par vendeur. Aucun tarif progressif par nombre de points, aucune limite « un / cinq / illimité » et aucun niveau PRO ne sont retenus.

Les montants mensuels validés sont ACCÈS à 2 000 FCFA et PREMIUM à 6 000 FCFA. Pour 12 mois, ACCÈS coûte 24 000 FCFA (12 mensualités, sans remise) ; PREMIUM coûte 60 000 FCFA (10 mensualités, deux mois offerts). Les plafonds numériques éventuels de points Premium ou de vendeurs par point restent à arbitrer et ne doivent pas être inventés. Les opérations de changement de formule sont historisées et protégées contre les modifications concurrentes.

#### Règles spécifiques COTIZ

L'unité facturable est chaque membre pour chaque cotisation, et non le groupe ou le Promoteur du groupe. Chaque membre paie individuellement 500 FCFA par cotisation à laquelle il participe. Le compte Président reste gratuit jusqu'à 100 membres. COTIZ conserve son rôle de registre et de gestion ; il ne devient pas détenteur ou opérateur des fonds des membres.

#### Règles spécifiques LOYABLE et NAXA HOTEL — abonnement dynamique au nombre de chambres

LOYABLE et NAXA HOTEL ont chacun un seul abonnement à accès complet, sans distinction ACCÈS/PREMIUM. Le prix unitaire est multiplié par le nombre de chambres rattachées au périmètre du Promoteur :

- **LOYABLE : montant de l'abonnement = nombre de chambres actives/en gestion × 1 000 FCFA.**
- **NAXA HOTEL : montant de l'abonnement = nombre de chambres actives × 2 000 FCFA.**

Le calcul est dynamique : le back-office et l'application récupèrent le nombre de chambres enregistré et activé dans le réseau du Promoteur, calculent le montant correspondant et affichent le détail de quantité, prix unitaire et total. Exemple : 12 chambres LOYABLE = 12 000 FCFA ; 20 chambres NAXA HOTEL = 40 000 FCFA.

Le Promoteur conserve **une seule souscription par application** pour tout son réseau. Les chambres sont comptabilisées comme une quantité rattachée à cette souscription ; elles ne génèrent pas des abonnements séparés par chambre. L'ajout, la désactivation ou la suppression d'une chambre met à jour la quantité facturable et le montant calculé, avec journal de l'ancienne quantité, de la nouvelle quantité, de la date d'effet et de l'auteur de la modification.

Le relevé de facturation doit rendre visibles le nombre de chambres retenues, le prix unitaire, la période couverte et le total. Toute modification de quantité est historisée et ne doit pas entraîner une facturation rétroactive non annoncée. La règle de prise d'effet d'un ajout ou d'un retrait en cours de période (immédiatement avec prorata, ou à la prochaine échéance) reste un paramètre commercial à confirmer avant l'activation de la facturation automatique ; aucun prorata ne doit être inventé.

Les capacités métier, la sécurité et le multisite nécessaires au fonctionnement complet sont inclus. Aucun ancien tarif supérieur ou supplément de formule à 4 000 F ou 5 000 F ne doit être réintroduit. Les coûts éventuels de matériel, d'installation ou de services externes, s'ils existent, sont des postes distincts et ne changent pas le prix unitaire logiciel.

#### Règles spécifiques CAMPUS237

- Le **Pack Individuel** est attaché à un compte parent et autorise le suivi d'un élève dans une école.
- Le **Pack Famille** est attaché à un compte parent et autorise le suivi de cinq élèves au maximum ; ils peuvent fréquenter la même école ou des écoles différentes.
- Chaque parent souscrit en son propre nom. Deux parents d'un même élève gardent des comptes et abonnements indépendants.
- L'établissement scolaire ne paie aucun abonnement.
- Le parent ne détient qu'un pack actif à la fois ; une évolution entre les deux packs modifie la souscription existante.

Pour toute autre application à tarif unique, afficher **« Abonnement »** sans créer de formules artificielles.

### 6.17.3 Règles d'abonnement déjà communiquées

- À l'installation/activation initiale, toutes les fonctionnalités sont disponibles pendant **72 heures**. Cette période est contrôlée côté serveur, attribuée une seule fois à l'unité facturable définie par l'application et ne doit pas être réinitialisable par réinstallation ou changement d'appareil.
- Pour une formule mensuelle récurrente éligible à la remise annuelle, le prix annuel est égal à dix mensualités : deux mois sont offerts. Les exceptions propres aux plans prévalent : pour GRILLAD ACCÈS, l'annuel est égal à douze mensualités sans remise ; pour GRILLAD PREMIUM, deux mensualités sont offertes. Cette remise ne s'applique pas automatiquement aux paiements par acte, par cotisation ou aux autres tarifications unitaires dont la périodicité n'est pas établie.
- La période d'essai, le statut de paiement, les dates d'effet et les droits sont établis par le serveur. Une déclaration locale ou une référence de paiement saisie par l'utilisateur ne suffit pas à activer des entitlements.
- Conserver les données et les fonctions nécessaires à la consultation du compte, au renouvellement et à la récupération des données en cas d'expiration. Le verrouillage concerne les opérations payantes selon les règles contractuelles validées.
- Les prix et règles propres à une application restent sous le contrôle de son catalogue versionné. Une modification tarifaire ne change pas rétroactivement un abonnement déjà payé.
- Aucun niveau PRO n'est proposé pour GRILLAD. Les seules formules sont ACCÈS (2 000 FCFA/mois ; 24 000 FCFA/an sans remise) et PREMIUM (6 000 FCFA/mois ; 60 000 FCFA/an avec deux mois offerts).

### 6.17.4 Modèle de droits et administration des catalogues

Conserver le modèle de référence **Plan → Subscription → Payment → Entitlements** et l'adapter aux contrats NAXA déjà présents. Il ne faut ni créer un second moteur de paiement ni remplacer le RBAC/RLS existant.

- Les droits de formule sont des entitlements explicites, versionnés et rattachés à une application, un plan et une période.
- Les permissions déterminent ce qu'un utilisateur peut faire ; les entitlements déterminent l'architecture et les capacités souscrites par l'organisation. Les deux contrôles doivent être satisfaits.
- ACCÈS correspond à l'architecture à compte unique / point de vente unique et donne accès à toutes les fonctionnalités métier, avec plusieurs vendeurs possibles sur ce point. PREMIUM inclut intégralement ACCÈS et permet l'architecture multiniveau GRILLAD : plusieurs points de vente, chacun avec plusieurs vendeurs possibles. Le nombre maximal de points Premium et de vendeurs par point reste à définir ; aucun PRO n'existe pour GRILLAD. Le Promoteur est le souscripteur ; la portée et les éventuelles limites exactes sont portées par les entitlements validés.
- Pour un produit à tarif unique, le catalogue expose uniquement « Abonnement » et la règle de facturation existante. Ne pas générer automatiquement un plan ACCÈS ou PREMIUM.
- Les limites de sites, chambres, membres, appareils, utilisateurs et stockage ne sont configurées que lorsqu'elles découlent de l'architecture et du modèle métier approuvés.
- Les fonctionnalités IA sont incluses dans l'abonnement et ne génèrent aucune facturation à l'appel, au token, au crédit ou au dépassement. La consommation IA reste mesurée en interne pour la sécurité, la capacité et le contrôle des coûts ; les mécanismes de fair use peuvent protéger le service, mais ne doivent déclencher aucun supplément facturé au client.
- Les prix, périodicités, architectures, capacités, dates d'effet et historiques sont administrables dans le back-office central avec traçabilité.
- Les tests doivent prouver l'inclusion complète ACCÈS → PREMIUM, l'absence de formule supplémentaire pour les produits à tarif unique, les 72 heures d'essai, les paiements en attente/échoués/confirmés, les remboursements, l'échéance et le renouvellement.

### 6.17.5 Pilotage central NAXA FAMILY

Le tableau de bord de l'administrateur central doit présenter une entrée **« Gérer NAXA FAMILY »**. Au clic, les dix applications sont présentées en cartes ; l'administrateur sélectionne une application puis accède à son pilotage dédié. Il peut revenir au tableau central et changer d'application.

Le pilotage global présente uniquement les métadonnées et agrégats autorisés : état technique, versions, disponibilité, volumes agrégés, catalogue, abonnements, paiements de souscription, support, quotas, consommation IA et indicateurs de service. Il ne confère pas un accès général aux transactions, dossiers clients ou données personnelles des organisations.

Chaque espace applicatif conserve ses règles métier, son identité, son périmètre de données et son autorité d'accès. Les actions administratives privilégiées sont limitées, justifiées et auditées.

### 6.17.6 Support central et Customer Services Officers

Réutiliser le service Support NAXA existant après audit de ses contrats et de ses permissions. Ne pas construire un helpdesk concurrent si le service canonique peut être adapté.

Les comptes Customer Services Officer doivent pouvoir traiter, depuis une file centrale, les tickets des dix applications. Chaque ticket est étiqueté par application, organisation, catégorie, priorité, canal, statut et SLA. L'accès à une donnée métier sous-jacente n'est jamais automatique : il doit être limité au dossier, autorisé, traçable et révocable. Le support central ne fusionne pas les identités des clients ni leurs comptes applicatifs.

### 6.17.7 Réutilisation des services IA NAXA sans régression

NAXA reste propriétaire de son moteur IA, de ses modèles, prompts système, fournisseurs, configurations, mémoires et règles d'exploitation. FAMILLE-NAXA doit consommer les capacités autorisées par une passerelle/adaptateur contrôlé, avec identification de l'application et de l'organisation, permissions, limites techniques de débit, minimisation des données, mesure interne des coûts et mécanisme de coupure. L'IA est incluse dans les abonnements : aucune facturation à l'utilisation, au token, au crédit ou aucun supplément IA ne doit être présenté au client.

La connexion des dix applications ne doit pas modifier les modèles, prompts, fournisseurs, paramètres, mémoires, données ou tests E2E de l'IA du projet NAXA indépendant. Les contextes et historiques IA de chaque application sont séparés. Les coûts IA sont absorbés par l'économie globale des abonnements et sont suivis uniquement en interne ; aucun usage IA n'est facturé en supplément. Des limites techniques de fair use, anti-abus et protection de capacité peuvent être appliquées sans transformer l'IA en option payante. En cas d'indisponibilité IA, les opérations métier essentielles doivent continuer selon un mode de repli déterministe ; l'IA ne valide pas seule les actes financiers, sanctions ou actions sensibles de sécurité.

### 6.17.8 CRM, relances, géolocalisation et imports de stock

**CRM et relances :** chaque application concernée doit pouvoir planifier les suivis selon une routine hebdomadaire, mensuelle ou personnalisée, ou selon un événement métier (prestation réalisée, rendez-vous manqué, échéance, inactivité). La fiche conserve la prochaine relance, l'historique, le résultat, les préférences et le consentement du client. Les tâches sont dédupliquées, journalisées et respectent les heures de silence et les canaux autorisés. Le service de planification/notification NAXA est réutilisé après audit ; les données clients restent cloisonnées par application.

**Prestations ou livraisons à domicile :** pour les applications concernées, le formulaire d'enrôlement client permet, avec information et autorisation, de capturer les coordonnées GPS ou de placer manuellement un repère, et d'enregistrer adresse, quartier, point de repère et consignes d'accès. Les coordonnées sont utilisées pour la prestation ou la livraison demandée, pas pour suivre continuellement le client. Prévoir correction, mise à jour, révocation du consentement et durée de conservation définie.

**Stock :** à côté de « Importer le fichier de stock », ajouter « Télécharger le template ». Chaque application dotée d'un stock possède un modèle propre à son vocabulaire et à ses unités. Le modèle permet la configuration et correspondance des colonnes. L'import comprend validation, détection des doublons, contrôle des unités et quantités, prévisualisation, rapport d'erreurs, confirmation explicite et journal d'import. Une importation ne doit pas modifier silencieusement les quantités existantes ; les stocks initiaux créent des mouvements d'inventaire traçables.

### 6.17.9 Langue Fulfulde

Ajouter le Fulfulde au socle de localisation, en complément du français et de l'anglais, avec le code de locale cible `ff-CM` à confirmer avec les outils de traduction retenus. Le sélecteur de langue, les chaînes, les notifications et les aides doivent gérer cette locale. Les traductions, en particulier les textes juridiques, sont soumises à une validation humaine. Ne pas déclarer la traduction complète avant inventaire des chaînes et recette dans chaque application.

### 6.17.10 Autorisation d'exécuter les migrations Supabase

**Décision explicite du propriétaire : les migrations Supabase nécessaires à la construction et à l'évolution de FAMILLE-NAXA peuvent être exécutées librement, sans solliciter une nouvelle autorisation pour chaque migration.** Cette autorisation couvre les migrations de schéma, fonctions, policies/RLS, index, triggers et autres éléments de base nécessaires au périmètre Famille, dans les environnements Supabase concernés.

Cette liberté d'exécution ne supprime pas les contrôles d'ingénierie obligatoires :

1. Identifier précisément le projet, l'environnement, le schéma et le propriétaire de chaque ressource visée.
2. Examiner les dépendances et comparer l'état réel des environnements avant modification.
3. Privilégier les migrations additives, versionnées, reproductibles et compatibles avec les versions applicatives en circulation.
4. Tester d'abord sur Replay/recette avec données non sensibles, y compris les tests positifs et négatifs RLS, les rôles, les limites inter-applications et les fonctions dépendantes.
5. Vérifier sauvegarde/restauration ou stratégie de retour arrière, verrouillage, durée, impact et possibilité de reprise avant une migration risquée.
6. Exécuter la migration, contrôler le résultat réel, rejouer les tests d'intégration et non-régression, puis documenter le numéro, le hash, l'environnement, l'heure, le résultat et les écarts.
7. Ne jamais embarquer une clé `service_role` dans Android, Web ou PWA ; les mutations privilégiées restent côté serveur.

**Limite de périmètre essentielle :** cette autorisation concerne les migrations requises par FAMILLE-NAXA. Elle n'autorise pas à modifier le moteur IA ou le fonctionnement autonome du projet NAXA, ses prompts, modèles, fournisseurs, configurations, mémoires, données ou parcours E2E. Si un backend ou schéma est partagé, toute migration Famille doit être isolée par un espace/namespace et des objets explicitement propriétaires de FAMILLE-NAXA, additive et testée pour démontrer l'absence de régression NAXA. Toute migration qui exige de modifier un objet propriétaire de NAXA ou un service IA indépendant sort de ce périmètre et doit être traitée comme un changement distinct.

L'autorisation de migration ne vaut pas autorisation automatique de déployer une Edge Function, de modifier des secrets/projets externes, de publier une APK ou de déployer une application. Ces opérations restent soumises à leurs contrôles et autorisations propres.

**État de cette mise à jour :** seule la présente règle documentaire est enregistrée par cette modification. Aucune migration Supabase n'est exécutée par le seul fait de l'actualisation du document.

### 6.17.11 Dossier d'identification et KYC des Promoteurs

Avant l'activation commerciale d'un compte Promoteur des applications FAMILLE-NAXA, le dossier Promoteur doit être constitué et vérifié. Les pièces requises sont :

1. **Pièce d'identité :** copie de la CNI ou récépissé d'identification en cours de validité, selon le document légal disponible et accepté.
2. **Formulaire KYC (Know Your Customer) :** informations d'identification du Promoteur, coordonnées vérifiées, activité déclarée, qualité/relation avec l'entreprise et informations de vérification requises.
3. **Plan de localisation :** plan permettant de localiser l'entreprise ou le siège d'exploitation, avec adresse, quartier, repères et, lorsque pertinent, coordonnées GPS du site.
4. **Preuve d'activité :** document ou élément vérifiable démontrant l'existence et l'exercice de l'activité déclarée (ex. autorisation, registre, patente, facture professionnelle, enseigne ou justificatif pertinent selon le statut et le secteur).

Le contrôle suit un cycle explicite : dossier incomplet, soumis, en vérification, validé ou rejeté avec motif ; les mises à jour et renouvellements des pièces sont tracés. Aucun Promoteur n'est activé définitivement sur la seule base d'un formulaire non vérifié.

Le même dossier d'identification vérifié peut être référencé pour les différentes applications utilisées par un même Promoteur afin d'éviter les demandes répétitives, sous réserve de la validité des pièces et de l'autorisation appropriée. Cette mutualisation documentaire ne fusionne pas les identités, les comptes Auth, les organisations, les permissions ou les données opérationnelles des applications.

Les pièces KYC sont des données personnelles sensibles du point de vue opérationnel : elles sont stockées dans un espace privé sécurisé, chiffré lorsque le service le permet, accessibles uniquement aux agents habilités, avec accès temporaire et journalisé. Aucun scan de CNI, récépissé ou justificatif KYC ne doit être ajouté au dépôt Git public, aux logs applicatifs ou aux prompts IA. La durée de conservation, les motifs de collecte et les droits de consultation/correction/suppression doivent être définis dans la politique de confidentialité et validés juridiquement.

Cette exigence vise les comptes Promoteurs et représentants des organisations. Elle ne doit pas être appliquée automatiquement à chaque membre COTIZ, parent CAMPUS237 ou client final, sauf obligation légale ou règle spécifique du produit validée séparément.

### 6.17.12 Priorité de réemploi

Pour construire les fonctions manquantes, appliquer l'ordre suivant :

1. Cahiers des charges et arbitrages validés de l'application FAMILLE-NAXA concernée.
2. Patrimoine NAXA existant : tables, API, fonctions, services de paiement, notifications, support, IA, BI, géolocalisation et outils d'import, après audit de propriété, compatibilité, sécurité et dépendances.
3. Fondations et contrats déjà construits dans le monorepo FAMILLE-NAXA.
4. JOBLY comme référence de conception pour les patterns utiles — catalogue, souscription, entitlements, quotas, UX et cycle de paiement — sans copie aveugle de code, de schéma ou de règles métier.

Pour chaque fonction, désigner un propriétaire canonique, réutiliser ou adapter l'actif existant lorsqu'il est valide, et construire uniquement le manque démontré. Ne jamais créer deux moteurs concurrents de paiement, notification, IA, support, audit ou synchronisation.

### 6.17.13 Point de reprise — finalisation NAXA SERVICES

Après validation du présent référentiel commercial, reprendre la branche de travail `work/naxa-services-completion-20261120` au dernier état vérifié, sans recommencer les écrans, modèles Room, parcours Auth ou contrôles CI déjà construits. Le rapport de référence est `docs/naxa-services/NAXA_SERVICES_CONSTRUCTION_STATUS_2026-11-20.md`.

État connu au dernier audit : APK Android debug compilé et tests Auth de contrat réussis ; recette instrumentée Android, tests sur appareils, validation Supabase isolée/RLS, API métier serveur et moteur de synchronisation restent ouverts. La prochaine passe de finalisation doit commencer par la reprise exacte de la branche et la vérification du HEAD/CI, puis traiter les parcours métier prioritaires sans régression. Ne pas déclarer NAXA SERVICES prêt pour production sur la seule base d'une compilation verte.

Les règles corrigées d'abonnement GRILLAD ACCÈS/PREMIUM et d'architecture multisite/multivendeurs, ainsi que les règles de quantités LOYABLE/NAXA HOTEL, doivent être intégrées au catalogue central partagé, mais ne doivent pas provoquer de modification du projet NAXA autonome ni de déploiement sur ses environnements. Les tests E2E NAXA SERVICES doivent utiliser des données et environnements isolés.

---

## 6.17.14 Arbitrages tarifaires validés — catalogue NAXA FAMILY (20 novembre 2026)

**Statut : VALIDÉ PAR LE PROPRIÉTAIRE.** Le présent addendum remplace, pour les tarifs et règles qu'il couvre, les montants antérieurs figurant dans la section 6.17.2 et dans les anciennes grilles de travail. Il devient la baseline commerciale de référence pour les dix applications NAXA FAMILY. Tous les montants sont en FCFA et les prix indiqués dans les colonnes mensuelles sont des prix par mois.

### Principes communs

1. Positionnement hybride : prix d'entrée accessibles aux petites structures, puis progression selon l'architecture multiniveau, le volume et les capacités réellement consommées.
2. Les tarifs de lancement sont les montants à afficher à l'ouverture commerciale. Les tarifs « à maturité » sont approuvés comme cibles, mais ne deviennent pas actifs automatiquement : leur activation exige un jalon fonctionnel et économique vérifié, une date d'effet, une version du catalogue et une communication préalable aux clients concernés.
3. Pour les abonnements mensuels récurrents éligibles, la règle annuelle générique est **10 mensualités pour 12 mois de service** (deux mois offerts), sauf exception explicitement définie au niveau du produit ou du plan. **Exception GRILLAD ACCÈS :** l'annuel est de 24 000 FCFA, soit 12 mensualités de 2 000 FCFA, sans mois offert. **GRILLAD PREMIUM :** l'annuel est de 60 000 FCFA, soit 10 mensualités de 6 000 FCFA, avec deux mois offerts. Les exceptions explicites du catalogue produit prévalent sur le mécanisme générique. La règle ne s'applique pas aux frais ponctuels, transactions isolées ou actes unitaires sans abonnement récurrent.
4. Les prix déjà payés ne changent pas rétroactivement. Toute évolution de tarif est versionnée et datée ; le client est informé avant l'application du nouveau prix.
5. Les prix restent exprimés en FCFA. Le traitement HT/TTC, la fiscalité et les mentions de facture doivent être validés par le conseil comptable/fiscal ; aucune hypothèse fiscale n'est créée par le présent addendum.
6. Une souscription Promoteur unique couvre le réseau selon la formule et les capacités définies pour KIOSKO, BOOTIK, ZIPPLE, NAXA SERVICES et NAXA SECURITY. Pour GRILLAD, une seule souscription Promoteur existe : ACCÈS autorise un point de vente ; PREMIUM autorise plusieurs points. Aucun abonnement distinct par vendeur n'est facturé ; aucun supplément ou plafond par site/vendeur ne doit être inventé hors entitlements explicitement validés.
7. Le modèle d'entitlements reste **Plan → Subscription → Payment → Entitlements**, avec catalogue versionné par application. Le paiement doit être confirmé côté serveur avant d'activer les droits. Les fonctions de sécurité, confidentialité et protection des données ne deviennent jamais des options tarifaires.
8. Les fonctions IA sont incluses dans les abonnements et ne sont jamais facturées à l'appel, au token, au crédit ou à l'usage. La mesure des coûts reste interne.

### Catalogue mensuel et tarifs cibles

| Application | Tarif de lancement mensuel | Tarif cible à maturité | Unité / règle |
|---|---:|---:|---|
| KIOSKO | ACCÈS 2 000 ; PREMIUM 5 000 | ACCÈS 2 000 ; PREMIUM 7 500 | Une souscription Promoteur pour tout le réseau |
| BOOTIK | ACCÈS 4 000 ; PREMIUM 10 000 | ACCÈS 6 000 ; PREMIUM 15 000 | Une souscription Promoteur pour tout le réseau |
| ZIPPLE | ACCÈS 5 000 ; PREMIUM 15 000 | ACCÈS 6 000 ; PREMIUM 18 000 | Une souscription Promoteur pour tout le réseau |
| NAXA SERVICES | ACCÈS 3 000 ; PREMIUM 10 000 | ACCÈS 5 000 ; PREMIUM 15 000 | Une souscription Promoteur pour tout le réseau |
| COTIZ | 150 / 120 / 90 / 75 par membre | Identique | Prix unitaire mensuel par membre et par cotisation, dégressif selon effectif |
| LOYABLE | Voir tranches ci-dessous | Identique | Une souscription Promoteur ; calcul progressif par chambre/unité active en gestion |
| NAXA HOTEL | 2 000 par chambre active | Identique | Une souscription Promoteur ; quantité de chambres actives |
| NAXA SECURITY | ACCÈS 5 000 ; PREMIUM 15 000 | ACCÈS 7 500 ; PREMIUM 20 000 | Une souscription Promoteur ; capacité incluse et extensions contrôlées |
| GRILLAD | ACCÈS 2 000 F ; PREMIUM 6 000 F | ACCÈS 24 000 F (12 mensualités, sans remise) ; PREMIUM 60 000 F (10 mensualités, 2 mois offerts) | ACCÈS : 1 point ; PREMIUM : plusieurs points, plusieurs vendeurs possibles par point ; pas de PRO ni de paliers |
| CAMPUS237 | Voir tarifs établissement et parents ci-dessous | Identique | Établissement + abonnement parent facultatif et indépendant |

#### COTIZ — prix unitaire mensuel dégressif

Le prix unitaire dépend du nombre de membres actifs de la cotisation concernée. Le même prix unitaire de tranche est appliqué à tous les membres payants de cette cotisation pour la période de facturation :

| Membres actifs dans la cotisation | Prix mensuel par membre |
|---:|---:|
| 1 à 30 | 150 F |
| 31 à 100 | 120 F |
| 101 à 300 | 90 F |
| Plus de 300 | 75 F |

Exemples : 30 membres = 4 500 F/mois ; 100 membres = 12 000 F/mois ; 300 membres = 27 000 F/mois. Le compte Président reste gratuit dans la limite de 100 membres, selon les règles de compte déjà définies.

L'unité facturable est l'accès mensuel d'un membre à une cotisation donnée. Un membre n'est pas facturé plusieurs fois au cours du même cycle mensuel parce qu'il effectue plusieurs versements ou participe à plusieurs échéances de contribution au sein de cette même cotisation. Chaque cotisation distincte à laquelle le membre adhère constitue toutefois une relation d'abonnement distincte. L'annuel ne peut être proposé que pour un cycle d'accès de douze mois clairement défini ; il coûte alors dix mensualités, sans appliquer la remise à des paiements isolés ou à une cotisation de durée plus courte.

COTIZ reste un outil de registre et de gestion : la SAS ne détient pas les fonds des membres et ne fournit pas un service de paiement réglementé par simple effet de cet abonnement.

#### LOYABLE — abonnement unique et progressif par chambre

Une seule souscription Promoteur couvre toutes les unités locatives actives/en gestion de son portefeuille. Le calcul est progressif par tranche (les taux ne sont pas rétroactifs sur les premières chambres) :

| Tranche | Prix marginal mensuel |
|---|---:|
| Chambres 1 à 20 | 1 000 F par chambre |
| Chambres 21 à 80 | 650 F par chambre supplémentaire |
| À partir de la chambre 81 | 500 F par chambre supplémentaire |

Exemples : 5 chambres = 5 000 F ; 20 chambres = 20 000 F ; 80 chambres = 59 000 F ; 100 chambres = 69 000 F. Les chambres brouillon, archivées ou désactivées ne sont pas comptabilisées comme actives/en gestion. Le relevé doit indiquer quantité par tranche, prix marginal et total.

#### NAXA HOTEL — abonnement unique par chambre active

Le montant mensuel est égal au nombre de chambres actives rattachées au Promoteur multiplié par 2 000 F. Exemple : 10 chambres = 20 000 F ; 20 chambres = 40 000 F. Les fonctions métier et capacités multisites incluses restent couvertes par cette souscription unique ; aucun supplément de pack ACCÈS/PREMIUM n'est ajouté.

#### GRILLAD — tarifs et architectures validés (21 novembre 2026)

Le Promoteur choisit exclusivement entre **ACCÈS** et **PREMIUM** :

| Formule | Architecture | Tarif mensuel | Tarif annuel pour 12 mois |
|---|---|---:|---:|
|---|---|---:|---:|
| ACCÈS | 1 point de vente ; plusieurs vendeurs possibles sur ce point | **2 000 F** | **24 000 F** — 12 mensualités, sans remise |
| PREMIUM | Plusieurs points de vente ; plusieurs vendeurs possibles sur chaque point | **6 000 F** | **60 000 F** — 10 mensualités, 2 mois offerts |

Les deux formules sont disponibles au mois ou à l'année. Aucun forfait de trois ou six mois n'est proposé. La règle de deux mois offerts s'applique à PREMIUM, pas à ACCÈS.

Cette décision remplace les anciennes grilles GRILLAD par nombre de points de vente, ainsi que tout niveau PRO et toute ancienne règle uniforme de remise annuelle. Les éventuels plafonds numériques de points PREMIUM et de vendeurs par point restent à arbitrer. Aucun changement automatique de prix par nombre de points, aucun supplément par vendeur et aucun pack PRO ne sont appliqués sans décision écrite ultérieure.

#### NAXA SECURITY — capacité et extensions

Les tarifs ACCÈS/PREMIUM de lancement restent 5 000 F et 15 000 F ; les prix cibles à maturité deviennent 7 500 F et 20 000 F après validation des capacités fonctionnelles et coûts d'exploitation. Les extensions de capacité déjà arbitrées à +20 % par extension sont conservées. Le catalogue doit spécifier avant vente les unités de capacité concernées (par exemple flux, appareils, stockage ou autre limite effectivement supportée) et la base du calcul des +20 %. Les abonnements ne comprennent pas la fourniture de matériel ni une prestation humaine de télésurveillance.

### CAMPUS237 — double marché établissement et parent

CAMPUS237 adopte un modèle **B2B établissement + B2C parent facultatif**. L'ancienne gratuité générale des établissements et l'ancienne grille parent Individuel 1 000 F / Famille 3 000 F sont remplacées par les règles ci-dessous.

**Abonnement établissement (mensuel)** — l'effectif facturable est le nombre d'élèves inscrits et actifs :

| Effectif | Mensuel | Annuel (10 mensualités) |
|---:|---:|---:|
| 1 à 200 élèves | 3 000 F | 30 000 F |
| 201 à 500 élèves | 5 000 F | 50 000 F |
| 501 à 1 000 élèves | 10 000 F | 100 000 F |
| 1 001 à 1 500 élèves | 15 000 F | 150 000 F |
| Plus de 1 500 | Sur devis | Sur devis |

L'abonnement couvre le logiciel de gestion de l'établissement, les comptes du personnel nécessaires, les comptes parents de base, les communications scolaires et les fonctions institutionnelles prévues. Aucun supplément n'est facturé simplement par enseignant ou par compte parent. L'onboarding standard, le paramétrage courant et la formation initiale à distance sont inclus ; les migrations complexes, formations sur site et intégrations spécifiques peuvent faire l'objet d'un devis distinct communiqué à l'avance.

**Abonnement parent (facultatif)** :

| Pack | Droits | Mensuel | Annuel |
|---|---|---:|---:|
| Parent Essentiel | Accès gratuit aux informations scolaires essentielles d'un enfant dans son espace parent | Gratuit | Gratuit |
| Parent Individuel+ | Services familiaux avancés pour un enfant suivi dans une école | 500 F | 5 000 F |
| Parent Famille | Jusqu'à 5 enfants, dans une ou plusieurs écoles, tableau de bord familial consolidé | 1 500 F | 15 000 F |

Le Parent Essentiel conserve notamment l'accès aux notes, bulletins, absences/retards, horaires, annonces et communications scolaires que l'établissement a décidé de communiquer. Un établissement ne doit pas pouvoir imposer le pack payant aux parents. L'absence de paiement parental ne peut pas bloquer l'accès aux informations scolaires essentielles.

La distinction de valeur est obligatoire : l'établissement paie pour administrer et faire fonctionner son établissement ; le parent paie facultativement pour les fonctions personnelles et familiales avancées. Aucune fonctionnalité essentielle ne doit être facturée deux fois au parent et à l'école. Les comptes, factures, paiements, renouvellements et historiques de l'établissement et du parent sont distincts. Le parent garde un compte indépendant même si plusieurs de ses enfants fréquentent des établissements différents. Deux parents d'un même enfant conservent leurs abonnements et comptes indépendants.

**Essai spécifique :** l'établissement CAMPUS237 bénéficie d'un essai institutionnel de 30 jours, qui remplace pour cette unité facturable l'essai générique de 72 heures (il ne s'y ajoute pas). Le Parent Essentiel est gratuit sans limite d'essai ; les packs parent payants suivent l'essai de 72 heures lorsqu'il est applicable. Aucun établissement ou parent ne doit obtenir un deuxième essai par réinstallation, changement d'appareil ou création d'un compte doublon.

### Mise en œuvre et contrôle des tarifs

- Conserver les états de paiement serveur, l'unicité de souscription, les périodes d'essai, les renouvellements, périodes de grâce, reçus, historique et entitlements.
- Pour les changements de quantité des souscriptions LOYABLE et NAXA HOTEL, la date d'effet, le prorata éventuel et les éventuels remboursements restent des paramètres contractuels à fixer avant facturation automatique. Ne pas calculer de prorata arbitraire.
- Les tarifs cibles à maturité de KIOSKO, BOOTIK, ZIPPLE, NAXA SERVICES et NAXA SECURITY ne deviennent actifs qu'après jalon d'activation, décision datée et nouvelle version du catalogue. Les tarifs GRILLAD sont validés : ACCÈS 2 000 F/mois et 24 000 F/an ; PREMIUM 6 000 F/mois et 60 000 F/an. Le catalogue et les tests doivent conserver les règles annuelles différenciées de ces deux plans.
- Les catalogues tarifaires sont testés sur les montants, périodes, changements de formule, renouvellements, doublons et paiements échoués/confirmés ; aucune ancienne tranche tarifaire GRILLAD ne doit subsister.
- Les comptes et souscriptions des établissements et parents CAMPUS237 sont deux unités de facturation distinctes ; un même parent peut être associé à plusieurs écoles sans payer plusieurs fois son pack parent.

### Addendum GRILLAD du 21 novembre 2026 — correction faisant foi

Pour GRILLAD, la présente correction prévaut sur toute mention antérieure de PRO, de tarifs par tranche, de limites « un / cinq / illimité » et de remise annuelle uniforme. Les seuls plans sont ACCÈS et PREMIUM. ACCÈS couvre un point de vente avec plusieurs vendeurs possibles, à 2 000 F/mois et 24 000 F/an (12 mensualités, sans remise). PREMIUM couvre plusieurs points de vente, chacun pouvant comporter plusieurs vendeurs, à 6 000 F/mois et 60 000 F/an (10 mensualités, deux mois offerts). Aucun plafond de points Premium ni de vendeurs par point ne doit être codé en dur avant arbitrage.

## 6.17.15 Périmètre d'intégration central NAXA FAMILY — administration, support, abonnements et IA

### Administration centrale depuis le tableau de bord Administrateur NAXA

Ajouter au tableau de bord de l'Administrateur central un bouton visible **« Gérer NAXA FAMILY »**. À son activation, afficher les dix applications sous forme de cartes, puis ouvrir le tableau de pilotage de l'application sélectionnée. L'administrateur peut revenir au portefeuille et changer d'application.

Applications couvertes : KIOSKO, BOOTIK, ZIPPLE, NAXA SERVICES, COTIZ, LOYABLE, NAXA HOTEL, NAXA SECURITY, GRILLAD et CAMPUS237.

Le tableau central peut agréger, dans les limites autorisées, état de disponibilité, versions, santé technique, nombre d'organisations, abonnements, paiements de souscription, support, indicateurs d'activité, quotas, consommation IA interne et alertes. L'ouverture du tableau dédié n'accorde pas un accès universel aux transactions, documents, conversations ou données personnelles des organisations. Les permissions sont séparées par application, organisation et action, avec MFA pour les rôles sensibles, journal d'audit, justification des accès exceptionnels et révocation.

### Support central — Customer Service Officers

Auditer et réutiliser le support existant de NAXA et les comptes Customer Service Officer lorsqu'ils sont compatibles. Construire une file globale où les tickets des dix applications sont triés par application, organisation, catégorie, priorité, SLA, statut et canal. Les CSO peuvent traiter un ticket selon une matrice d'habilitation centrale et des périmètres explicites.

Cette mutualisation ne fusionne pas les identités, organisations, Auth, rôles ou données métier des applications. Un CSO peut consulter les informations strictement nécessaires à la résolution d'un ticket ; l'accès à un dossier ou à une donnée métier sous-jacente exige un droit distinct, limité dans le temps, justifié et journalisé. Les conversations et pièces jointes restent cloisonnées par application et organisation.

### Abonnements — expérience JOBLY, moteur canonique NAXA

Reprendre de JOBLY les principes de parcours, présentation des offres, comparaison des packs, checkout, états d'abonnement et expérience utilisateur. Réutiliser le service de paiement/abonnement NAXA existant après audit de compatibilité, sans créer un second moteur concurrent. Le contrat commun reste Plan → Subscription → Payment → Entitlements, avec catalogue versionné par application, paiement serveur confirmé, états pending/success/failed/refunded, idempotence, reçus, renouvellement, période de grâce et contrôle des droits. Les règles tarifaires et les unités facturables propres à chaque application du §6.17.14 prévalent.

L'essai générique de 72 heures reste en vigueur, sauf exception institutionnelle CAMPUS237 à 30 jours décrite au §6.17.14. Pour une formule annuelle éligible à la remise, deux mois sont offerts (10 mensualités pour 12 mois), sauf exception propre au plan. GRILLAD ACCÈS ne bénéficie pas de cette remise ; GRILLAD PREMIUM en bénéficie. Ne jamais activer un entitlement à partir d'une simple déclaration locale de paiement ou d'un justificatif non vérifié.

### Réutilisation des services IA NAXA — cloisonnement et absence de régression

La réutilisation des services IA NAXA est autorisée comme objectif d'architecture, sous réserve d'une passerelle/API versionnée, d'une authentification de service à service et d'un contexte obligatoire application + organisation + utilisateur + permissions. Les dix applications ne doivent pas accéder directement aux bases, mémoires, prompts privés ou configurations d'une autre application.

Garde-fous impératifs :
- NAXA autonome conserve ses modèles, fournisseurs, prompts, mémoires, paramètres, données, secrets, workflows et tests E2E inchangés.
- FAMILLE-NAXA consomme uniquement des capacités explicitement exposées par un adaptateur documenté et versionné ; aucun couplage direct aux tables ou composants internes non contractuels.
- Chaque requête IA est autorisée, minimisée, cloisonnée par organisation et journalisée sans conserver inutilement les données personnelles.
- Les historiques et contextes IA des dix applications sont séparés. Aucune donnée d'une PME/école/client ne sert à produire une réponse pour une autre organisation.
- Prévoir limites techniques, anti-abus, contrôle de capacité, mesure interne du coût, interrupteur d'urgence et mode de repli déterministe ; aucune facturation IA à l'utilisateur.
- Les tests de non-régression NAXA autonome sont exécutés sans modification de ses jeux de données, prompts, paramètres ou scénarios E2E. Les recettes FAMILLE-NAXA utilisent des identités, données et espaces de test isolés.
- Toute évolution qui exige de modifier un objet ou un service propriétaire de NAXA autonome constitue un changement distinct, avec analyse d'impact et autorisation spécifique ; elle ne doit pas être introduite indirectement par une migration Famille.

## 6.17.16 Exigences de finalisation NAXA SERVICES — backlog enrichi et reprise sans régression

Le périmètre ci-dessous complète les constats du rapport docs/naxa-services/NAXA_SERVICES_CONSTRUCTION_STATUS_2026-11-20.md. Les écrans, modèles Room, parcours Auth, ressources légales, navigation par rôle, reçus PDF et opérations locales déjà construits sont des acquis à préserver. Une présence dans un menu ou un écran local ne signifie pas qu'un workflow serveur/production est terminé.

### CRM, suivi client et relances

Créer un module CRM utilisable par toutes les activités de NAXA SERVICES, sans mélanger les données des organisations ou des sites. La fiche client contient coordonnées, statut, activité, consentements et préférences de contact, historique des prestations/commandes, rendez-vous, incidents, paiements autorisés, fidélité, parrainage client, dernière interaction, prochaine action et responsable interne.

Le client ou un collaborateur autorisé peut configurer une routine de relance : hebdomadaire, mensuelle, fréquence personnalisée, date fixe, échéance métier ou événement (prestation terminée, rendez-vous manqué, livraison à effectuer, vêtement non retiré, renouvellement, inactivité). Chaque tâche conserve date prévue, canal, modèle, responsable, statut, résultat, prochaine occurrence et historique. Le système évite les doublons, respecte consentements, préférences, heures silencieuses et désabonnement, et journalise les envois/échecs. Prévoir campagnes manuelles, listes filtrées, clients inactifs, anniversaires si consentis, fidélité et programme de parrainage client, distinct du parrainage de cinq PME.

### Prestations et livraisons à domicile — géolocalisation client

À l'enrôlement ou à la modification d'un client, proposer une capture GPS facultative et consentie, ainsi qu'un placement manuel du repère sur carte. Enregistrer latitude/longitude, précision et date de capture, adresse, quartier, point de repère, consignes d'accès et statut de vérification. Le client peut corriger ou retirer l'autorisation. N'utiliser les coordonnées que pour la prestation ou la livraison demandée ; aucune géolocalisation continue ou surveillance du client. Accès limité aux personnels chargés de l'intervention/livraison et journalisé. Prévoir affichage itinéraire, ouverture dans une application cartographique et contrôle d'accès par organisation/site/rôle. Un refus GPS ne doit pas empêcher l'enrôlement : l'adresse manuelle reste possible.

### Langue Fulfulde

Ajouter le Fulfulde au sélecteur de langue, aux ressources de l'application, aux notifications, aux aides et aux écrans accessibles. Code de locale cible : ff-CM, à confirmer avec les outils et locuteurs retenus. Ne pas déclarer la traduction achevée avant inventaire de toutes les chaînes, traduction humaine et recette complète ; les CGU, politique de confidentialité et textes sensibles nécessitent une validation humaine/juridique. Conserver français et anglais et ne pas casser les préférences existantes.

### Import de stock et template configurable

À côté de « Importer le fichier des stocks », afficher « Télécharger le template ». Produire un modèle téléchargeable propre au profil d'activité et à l'organisation, avec colonnes et champs documentés (SKU/code-barres, désignation, catégorie, variante, unité, quantité, coût d'achat, prix de vente, seuil, emplacement, lot/date si pertinent). L'administrateur peut choisir/configurer les colonnes nécessaires et leur ordre, les unités et les champs obligatoires ; le moteur d'import utilise le schéma versionné et le mapping correspondant.

Le parcours comprend sélection du fichier, détection du format/version, correspondance des colonnes, aperçu avant import, validations de types et unités, détection des doublons, erreurs ligne par ligne, choix explicite entre création et mise à jour, confirmation, transaction contrôlée, rapport téléchargeable et journal d'import. Ne jamais écraser silencieusement un stock existant ; les quantités initiales créent des mouvements d'inventaire traçables. Un import incomplet ou invalide ne doit pas laisser une partie incohérente des données.

### Autres domaines métier et ERP à terminer

- Backend métier/API et persistance serveur réelle pour clients, catalogue, prestations, rendez-vous, pressing, ventes, caisses, factures, paiements, dépenses, achats, fournisseurs, stocks, mouvements, transferts et rapports.
- Catalogue : prestations, tarifs, durées, forfaits, ressources, qualifications des prestataires, variantes et règles par activité.
- Agenda : acomptes, annulations, absences/no-show, listes d'attente, rappels, disponibilité des postes et prestataires.
- Pressing : étiquettes/QR par vêtement ou lot, reçu, suivi étape par étape, notifications, vêtements non retirés, relances et réclamations.
- Autres activités : workflows réellement adaptés aux profils (coiffure, beauté, couture, réparation, menuiserie, garage, nettoyage, impression, photo/événementiel, parfumerie, domicile et autres profils approuvés).
- Achats/fournisseurs : demandes, commandes, réceptions, retours, factures fournisseurs, échéances et rapprochement.
- Équipe/RH : horaires, pointage, pauses, retards, absences, commissions, avances, primes, objectifs, classements, challenges et validation RH/paie.
- Ordres de travail : création, affectation, étapes, pièces/consommables, échéance, preuve, contrôle qualité, clôture et historique.
- Fiscalité camerounaise : régimes, taux, obligations, déclarations préparatoires et justificatifs uniquement après validation par un professionnel sur la réglementation en vigueur.
- Comptabilité SYSCOHADA : journaux, plan comptable, écritures équilibrées, grand livre, balance, rapprochements, immobilisations, amortissements, clôtures et états financiers ; validation expert-comptable.
- Reporting : résultats par site/activité/prestataire/période, objectifs vs réalisé, indicateurs, marges calculées et consolidation réseau serveur.
- Multi-sites/postes : affectations et autorisations transactionnelles par site/poste, transferts inter-sites, gestion des réservations, consolidation réseau.
- Historique global : journal d'activité serveur, recherche/filtrage selon rôle, auteur, date, site, objet et action ; corrections tracées, jamais de suppression silencieuse.
- Profil utilisateur : photo/avatar synchronisé, langue, préférences, sessions/appareils, historique autorisé, récupération et révocation.
- Notifications : centre serveur persistant, FCM, préférences, heures silencieuses, lecture/non-lecture, actions sécurisées et anti-doublon.
- Sauvegardes : Google Drive via OAuth et autorisation explicite, chiffrement, intégrité, version, rétention, restauration et tests ; Gmail n'est pas un espace de sauvegarde.
- Appels et partage d'écran : fournisseur média, consentement explicite, signalisation sécurisée, jetons temporaires et journal de session.
- Parrainage PME : appliquer la règle approuvée de cinq PME distinctes payantes et réabonnées, avec anti-fraude ; ne pas confondre avec parrainage client ou parrainage JOBLY.
- IA prédictive : assistant explicable sur données autorisées, analyses sourcées, prévisions et anomalies testées ; l'IA ne valide jamais seule paiements, écritures, remboursements, transferts, mouvements sensibles ni déclarations fiscales.
- Images métier : ajouter de vraies images autorisées par activité ; ne pas utiliser des images factices comme preuves de fonctionnalités.
- Tutoriel : véritables spotlight successifs sur les contrôles UI concernés, avec étapes skippables et état mémorisé.

### Deux chantiers de sécurité à traiter séparément

1. **Sécurité applicative NAXA SERVICES** : Auth, MFA selon risque, gestion des appareils/sessions, révocation, secrets, RLS, cloisonnement organisation/site/poste, permissions serveur, audit append-only, anti-rejeu, chiffrement local/transport/stockage, sauvegardes, tests négatifs et réponse aux incidents.
2. **Intégration fonctionnelle NAXA SECURITY** : connecter, après validation des contrats et équipements, les flux vidéo/audio, alertes à distance, règles d'événement, assistance IA, multi-sites/multi-comptes et vues de supervision autorisées. Ce produit ne doit pas être confondu avec la protection de l'ERP. NAXA SECURITY ne fournit pas automatiquement le matériel ni une prestation humaine de surveillance.

### Recettes, qualité et livrables techniques

- Tests instrumentés Android sur émulateur et appareils physiques, navigation, rotation, reprise, permissions, perte de réseau et restauration de session.
- Base Supabase de recette dédiée ; appliquer les migrations draft uniquement après identification du projet et preuve d'isolation ; tests RLS positifs/négatifs par rôle, application, organisation, site et poste.
- Synchronisation offline complète : outbox, version de schéma, identifiants idempotents, ordre, reprises, accusés de réception durables, conflits, anti-rejeu et rejeu testé.
- Tests de non-régression Room, migrations locales, mise à jour APK, performances, volumes de données, longues périodes offline et sauvegarde/restauration.
- Release Android signée, signature contrôlée, génération reproductible, distribution et procédure de mise à jour ; ne pas confondre APK debug et Release.
- Web/PWA à développer séparément avec backend, contrats API et règles métier partagés ; l'application Android Kotlin/Compose n'est pas convertie automatiquement en Web/PWA.
- Modernisation contrôlée de la stack selon le Prompt 0.1, sans mise à niveau massive risquant de casser les dix applications.
- Tests E2E NAXA autonome : garder son projet, ses données, sa configuration IA, ses prompts et ses scénarios séparés. Aucun déploiement NAXA autonome par effet de bord.

### Ordre de reprise

Reprendre la branche work/naxa-services-completion-20261120 à son HEAD vérifié, auditer les écarts entre cette branche et main, puis intégrer prudemment les neuf commits documentaires de main qui la précèdent. Ne pas fusionner automatiquement et ne pas écraser les fichiers de rapport de cette branche. Une fois la divergence documentaire réconciliée, avancer par lots verticaux : modèle/API → RLS → persistance → synchronisation → écrans → tests → preuve CI. Préserver les écrans et fonctions déjà construits ; toute évolution doit être additive ou accompagnée de tests de non-régression.

**Point de reprise vérifié le 20 novembre 2026 :** HEAD de la branche de travail 58fba9e9f19d809436b114b31434c4a3b2f174fd (commit documentaire) ; parent applicatif 5acd99136a72ba310052532e74e6049992175347. Le workflow 44745166818 est terminé avec succès sur le commit applicatif 5acd99136a72ba310052532e74e6049992175347 : assemblage APK Android debug et tests de contrat Auth réussis. La branche est en avance de 107 commits et en retard de 9 commits par rapport à main au moment du contrôle ; les neuf commits de retard sont documentaires et doivent être intégrés de manière contrôlée. L'APK debug n'est pas une Release. Aucune migration réelle, aucun déploiement de fonction Edge, aucune Release signée et aucune mise en production ne sont réputés accomplis.

**Règle de sécurité opérationnelle :** ne pas toucher au projet NAXA autonome, à son moteur IA, à ses secrets, à ses données ou à ses workflows E2E. Les migrations autorisées pour FAMILLE-NAXA restent limitées à des ressources explicitement propriétaires de Famille et à un environnement isolé ; l'autorisation de migration ne vaut pas autorisation de déploiement ni de publication.

### 6.17.17 État de reprise effectif — NAXA SERVICES, lot du 20 novembre 2026

Cette section actualise le point de reprise antérieur du §6.17.16. En cas de différence sur l'état d'avancement technique, cette section et le rapport `docs/naxa-services/NAXA_SERVICES_CONSTRUCTION_STATUS_2026-11-20.md` font foi pour le lot CRM/GPS/Fulfulde/CSV.

**Branche active :** `work/naxa-services-completion-20261120`.

**État fonctionnel ajouté à la branche :**
- Sélecteur Fulfulde `ff-CM` aux préférences, à la connexion et au paramétrage de langue organisation ; contrats Auth mis à jour. La traduction complète reste à faire ; les CGU et la politique acceptées restent en français/anglais jusqu'à validation de traductions humaines.
- Room version 3 et migration additive 2→3 pour l'adresse, le quartier, les repères et les coordonnées GPS facultatives des clients, avec précision, date de capture et date de consentement.
- Écran CRM client avec routines de relance hebdomadaires/mensuelles, canaux, prochaine échéance, clôture/reprogrammation et historique des événements.
- Capture GPS ponctuelle après consentement et permissions Android ; seule une dernière position disponible de moins de quinze minutes est proposée, avec saisie manuelle d'adresse comme alternative. Aucun suivi continu.
- Template configurable de stock et import CSV UTF-8 avec aperçu, validation, détection des doublons, mise à jour explicitement confirmée, transaction locale et mouvements de stock audités. Le dernier code ajoute la détection du séparateur virgule/point-virgule.

**Limites :** CRM, routines, clients, stocks et mouvements de ce lot sont encore locaux/Room et alimentent l'outbox préparatoire. Le planificateur serveur, l'envoi automatique SMS/WhatsApp, FCM, l'API CRM/GPS, les politiques RLS et la synchronisation distante restent ouverts. L'import ne prend pas encore XLS/XLSX, mapping manuel de colonnes arbitraires ni rapport d'erreurs téléchargeable. Les services ne doivent pas être décrits comme entièrement opérationnels en production.

**Preuves de build :**
- Le commit de code `2dc2a85cd99828b9ab38389c6a5f646dea0f4cee` a passé le workflow `44770034786` : les jobs Android debug et Auth Deno sont tous deux terminés avec succès.
- Artefact correspondant au commit `2dc2a85` : `naxa-services-debug-apk`, ID `14647006494`, SHA-256 `5347fa2e7f58c7501c1d2e25747917487e28734645e74ba77e449def7cd285dd`.
- Le build précédent `44769339200` / commit `96bb9b2` avait également réussi avec l'artefact `14646801027`.
- L'artefact reste une build **debug**, pas une Release signée.

**Périmètre non livré par ce lot :** administration centrale des dix applications depuis NAXA, mutualisation réelle des comptes Customer Service Officer, paiement/abonnement réel et entitlements, passerelle IA vers NAXA, intégration fonctionnelle NAXA SECURITY, backend ERP/RLS, comptabilité SYSCOHADA, fiscalité, notifications serveur, sauvegarde Drive, appels/partage écran, Web/PWA, tests physiques et Release signée. Ces sujets restent au backlog du §6.17.15–6.17.16.

Le rapport détaillé, ses commits et les réserves de recette sont maintenus dans `docs/naxa-services/NAXA_SERVICES_CONSTRUCTION_STATUS_2026-11-20.md`. Aucune migration Supabase réelle, aucun déploiement Edge, aucune publication APK Release et aucun changement du projet NAXA autonome n'ont été réalisés par ce lot.

### 6.17.18 Mise à jour de finalisation fonctionnelle — NAXA SERVICES (20 novembre 2026)

Le rapport de construction comporte désormais la section 36. Le code Android natif a été étendu sur les axes suivants :
- Catalogue tarifaire exécutable et manifeste de maturité pour les dix apps, effet au 1er mai 2027 à minuit heure de Douala ; application au début des nouvelles périodes et renouvellements, sans repricer les périodes déjà payées.
- Trial par unité CAMPUS237 (école 30 jours, Parent Essentiel gratuit, autres packs parent payants 72h), +20 % par extension de capacité NAXA SECURITY.
- Vente caisse reliée optionnellement au stock, sortie espèces atomique, réservation Mobile Money pending, annulation auditée, méthode de confirmation réservée à un webhook serveur vérifié.
- Transfert inter-sites Promoteur, demande/approbation sans effet stock et réception transactionnelle avec deux mouvements liés.
- Pointage par séquence, poste facultatif, mouvements variables RH soumis à approbation avec motif.
- Modification de fiche client et effacement des coordonnées GPS lors du retrait du consentement.
- Pressing avec date de retrait promise et historique de transitions avec motif.

- Dernier workflow constaté : `44780431451`, commit testé `fb4a464f4595d90b2d7523b50eb95b927a407273`, statut `completed` / conclusion `failure`.
- Jobs : NAXA FAMILY launch and maturity tariff tests=completed/success; Assemble NAXA SERVICES Android debug APK=completed/failure; Auth scope and business-mode contract tests=completed/success.
- Artefacts : aucun artefact publié pour ce workflow.

La CI du dernier état n'est pas entièrement verte/terminée. Le succès d'un SHA précédent ne doit pas être réutilisé comme preuve du HEAD courant.

Ces fonctionnalités sont encore fondées sur Room/outbox locale lorsque précisé dans le rapport. Aucune mise en production, aucune migration Supabase, aucun déploiement Edge et aucun changement du projet NAXA autonome n'est déclaré. La passerelle paiement/webhook, le backend/RLS/synchroniseur, FCM/SMS/WhatsApp, la Release signée, les tests sur appareils physiques, l'admin 10 apps/CSO, l'IA mutualisée et l'intégration NAXA SECURITY restent ouverts.

## 6.17.19 Reprise confirmée — construction NAXA SERVICES et CI verte (20 novembre 2026)

Cette section actualise le statut des sections 6.17.17–6.17.18. Les décisions tarifaires, la date de maturité et les règles métier précédentes restent inchangées.

### Référence de code et preuve de construction

- Branche de travail : `work/naxa-services-completion-20261120`.
- Dernier commit de code Android soumis aux trois gates : `7a0729c7ea8d9a852385652a688f2abe27eca586`.
- Dernier commit de tarification et tests : `f90c82886d5ae33ce97e1966e73ac40bf8cfaca3`.
- Workflow final : `44784781041`, commit testé `f90c82886d5ae33ce97e1966e73ac40bf8cfaca3`, conclusion `success`.
- Trois jobs réussis : APK Android debug, contrats Auth scope/business-mode et tests du catalogue de maturité des dix applications.
- Artefact : `naxa-services-debug-apk`, ID `14653536762`, SHA-256 `5b390da34b8202f78780c00bb73bf0bd58905767508994229187bf63e030b474`. Il s'agit d'un APK **debug**, pas d'une Release signée.
- Dernier commit documentaire de la branche après mise à jour du rapport : `4f1e2d7256829a897ffb2adfb7558a7b2dff5dd4`. Aucun changement de code n'a été apporté après le commit testé.

### Fonctions natives ajoutées ou consolidées dans le lot

- Moteur tarifaire effectif-daté pour les dix applications, avec bascule le **1er mai 2027 à 00:00, heure de Douala**. Les nouveaux cycles ou renouvellements commencent sur le catalogue maturité à cette date ; les périodes déjà payées ne sont pas repricées.
- Règles NAXA SECURITY : +20 % par extension de capacité ; essais CAMPUS237 spécifiques (30 jours école, accès Parent Essentiel gratuit, 72 heures pour les autres packs parent payants).
- Caisse liée au stock : vente espèces avec mouvement de sortie atomique ; réservation locale pour Mobile Money pending, annulation auditée et libération de la réservation. La confirmation réelle demeure réservée à un webhook serveur vérifié.
- Transfert inter-sites Promoteur : demande et approbation sans mouvement ; réception depuis le site destination avec revalidation du stock, incrément/décrément dans une transaction Room, mouvements source/destination et historique d'audit.
- Pointage d'équipe séquentiel, affectation facultative à un poste, commissions/avances/primes sous validation motivée.
- Work orders différenciés par profil métier, catalogue de prestations modifiable, pressing avec retrait promis et historique, agenda avec reprogrammation et liste d'attente convertible.
- CRM local avec modification des fiches et retrait du consentement GPS ; suppression des coordonnées et métadonnées de capture lors de la révocation.

### Langue Fulfulde — distinction importante

Le code de préférence `ff-CM` est accepté et mémorisé. Toutefois, le dépôt Android contient encore les ressources françaises (`values`) et anglaises (`values-en`) uniquement : aucun pack complet `values-ff-rCM` n'est livré. Les écrans peuvent donc retomber sur le français lorsque Fulfulde est choisi. Ne pas qualifier la traduction Fulfulde de terminée avant création et relecture du pack complet par un locuteur camerounais compétent.

### Réserves techniques et fonctionnelles

Le build vert confirme la compilation Android, les contrats Auth et le calcul tarifaire. Il ne vaut pas recette de production. Restent à intégrer et tester : API ERP distante, synchroniseur/outbox/idempotence, RLS réelle, paiements et webhooks, entitlements, FCM/WhatsApp/SMS, planificateur serveur de relances CRM, validation distante des transferts multi-appareils, SYSCOHADA, fiscalité/paie avec experts, appels/partage écran, sauvegarde Drive, tests instrumentés et appareils physiques, Release signée et Web/PWA séparée.

Les intégrations centrales documentées restent des lots distincts : pilotage central des dix applications depuis NAXA, comptes Customer Service Officer réellement mutualisés, passerelle IA versionnée et intégration vidéo/audio/alertes NAXA SECURITY. La sécurité applicative NAXA SERVICES reste également un chantier distinct de NAXA SECURITY.

### Protection du périmètre

Aucun déploiement Supabase ni migration réelle Supabase n'a été exécuté dans cette passe. Le projet NAXA autonome n'a pas été modifié. La branche de travail n'a pas été fusionnée automatiquement dans `main`. Le rapport technique exhaustif demeure dans `docs/naxa-services/NAXA_SERVICES_CONSTRUCTION_STATUS_2026-11-20.md`, section 37.



### 6.17.20 Lot de parrainage PME et reprise globale — 20 novembre 2026

Ce point complète la section 6.17.19 sans invalider les preuves Android/CI du commit précédent. Le code de ce lot reste sur la branche de travail ; seule cette mise à jour de continuité est écrite sur `main`.

#### Référence de reprise

- Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA`.
- Branche de travail : `work/naxa-services-completion-20261120`.
- Commit de code final testé : `f9cb368dec3ac2e00ad7088b054cb30ec1e5badb`.
- Workflow : `44792194242`, résultat final **SUCCESS — 4/4 jobs** (Android debug, Auth contracts, referral API contract, billing catalog).
- Artefact Android debug : ID `14656354059`, 11 560 550 octets, SHA-256 `f26dd357c47d677fe5c456b936af28ad2fda89c092525ff31385fdfafd11ef42`, valable jusqu'au 27 novembre 2026 à 18:25:06 UTC.
- Rapport détaillé : `docs/naxa-services/NAXA_SERVICES_CONSTRUCTION_STATUS_2026-11-20.md`, sections 38.5 à 38.7.
- Le statut CI vert vaut pour ce périmètre de compilation/tests automatisés ; il n'est pas un vert Production global.

#### Parrainage — règles et interface ajoutées

- Entrée depuis Profil → « Parrainage et suivi de mes gains ».
- Le Promoteur peut générer et copier le code unique de son organisation.
- Le Promoteur d'une PME filleule peut associer le code reçu une seule fois ; auto-parrainage et transfert de parrain sont refusés.
- L'écran présente les PME rattachées, dates de rattachement et d'activation, activations payées, progression par vagues de cinq, et les récompenses acquises.
- La qualification se fait au premier abonnement réellement payé confirmé côté serveur, et non au simple enregistrement, essai, renouvellement ou statut pending.
- Chaque groupe complet de cinq déclenche une récompense : cadence mensuelle de la PME marraine → un cycle mensuel gratuit ; cadence annuelle → un mois additionnel à appliquer à l'expiration annuelle.
- Les récompenses ont un état distinct `pending_entitlement` / `applied` / `failed`. Aucune récompense n'est annoncée comme consommée avant confirmation du service d'entitlements.

#### Limites de mise en service du parrainage

L'interface et les contrats source sont ajoutés, mais le service n'est pas encore en production : la migration SQL reste dans `supabase/drafts/naxa_services_referrals_v1.sql`, la fonction Edge reste à déployer, le secret `NS_REFERRAL_WEBHOOK_SECRET` reste à configurer, et aucun webhook de fournisseur de paiement ni adaptateur d'entitlements n'a encore été raccordé. L'événement signé doit provenir du système de facturation après capture du premier paiement et doit transmettre la cadence active réelle du parrain au moment du seuil. Les gains resteront `pending_entitlement` tant que l'avantage n'aura pas été appliqué et vérifié côté serveur.

#### Chantiers globaux — statut non vert production

La réussite du build Android debug et des tests de contrat ne doit pas être assimilée à une qualification globale. Les points suivants demeurent à fermer avec preuves propres : API ERP distante, synchronisation offline complète, idempotence et conflits inter-appareils ; RLS réellement testée par organisation/site/poste/rôle ; paiement récurrent, webhooks, entitlements et prélèvements ; notifications FCM, SMS/WhatsApp et planificateur CRM ; SYSCOHADA, fiscalité et paie validées par les professionnels compétents ; appareils physiques, tests instrumentés, charge et restauration ; Release Android signée ; Web/PWA séparée ; Fulfulde complet traduit et relu ; pilotage central des dix applications, mutualisation effective des CSO, passerelle IA versionnée et intégration fonctionnelle NAXA SECURITY.



#### Audit Supabase connecté — lecture seule

Le seul projet Supabase exposé par la connexion est le projet `NAXA` (région `eu-west-3`, état `ACTIVE_HEALTHY`). Son état courant comporte 41 migrations, 37 tables `public`, aucune table `ns_*`/NAXA SERVICES identifiée et aucune Edge Function déployée. Les advisors signalent notamment 2 tables RLS sans policy, 2 fonctions à search_path mutable, 22 fonctions SECURITY DEFINER exécutables par `anon`, 37 accessibles à `authenticated`, ainsi que plusieurs alertes de performance.

Ces observations concernent l'environnement NAXA connecté, pas un environnement NAXA SERVICES isolé. Aucune migration ni correction n'a été exécutée sur ce projet. Ne pas le modifier pour y installer NAXA SERVICES avant création/identification d'un environnement de recette dédié et cartographie de ses consommateurs existants.
#### Protection du périmètre et consigne de reprise

- Aucune migration ou fonction Supabase n'a été déployée dans cette étape.
- Le projet NAXA autonome n'a pas été modifié.
- Aucun commit de code n'a été fusionné dans `main`.
- Reprendre depuis le HEAD courant de `work/naxa-services-completion-20261120`, conserver les écrans existants et poursuivre les intégrations restantes en lots verticaux avec tests et preuves distincts.


#### Dernière configuration du service de parrainage

La configuration Supabase du dépôt contient désormais `[functions.naxa-services-referrals] verify_jwt = false`, uniquement pour laisser la fonction vérifier les actions Promoteur par Supabase Auth et le webhook fournisseur par HMAC. Le README encadre explicitement ces contrôles. Commit de configuration : `34682dd53f45f42db7ca815df0af6c74291bc80d`. Workflow `44792804538` : contrôles contrats/tarifs réussis ; job Android encore en cours lors de cette note. La fonction n'est toujours pas déployée.


#### Preuve finale Android/CI du service Referral

Le commit de code/configuration `34682dd53f45f42db7ca815df0af6c74291bc80d` a son workflow `44792804538` en **SUCCESS 4/4**. L'APK debug associé est l'artefact `14657621377`, 11 560 547 octets, SHA-256 `3dc0e3f3dae2921afe71384257e22b41be06f2365794a9e48b62920be66f27e1`, expiration le 27 novembre 2026 à 18:28:39 UTC.

Le commit `c87bf03b436c03cf5a84dcc9e01885e369e6cbaf` ne change que les filtres de déclenchement du workflow afin de surveiller les changements de fonction Referral, migration candidate, configuration Supabase et catalogue. Le workflow `44793189090` est un contrôle supplémentaire : trois jobs non Android ont réussi ; le job Android était encore en compilation au dernier relevé. La preuve fonctionnelle/Android terminée reste le workflow `44792804538`.



## 6.17.21 — NAXA SERVICES : stocks fournisseurs, charges récurrentes et fidélité (20 novembre 2026)

Poursuite sur la branche `work/naxa-services-completion-20261120`, sans fusion du code vers `main`.

### Parcours ajoutés au code Android

- **Stock et fournisseurs :** contact WhatsApp international enregistré par article, repris dans le modèle CSV, consultable et modifiable dans la fiche de stock. Quand le stock atteint le seuil de réapprovisionnement, l'application propose une quantité cible et ouvre WhatsApp avec un message de commande prérempli. L'utilisateur doit confirmer l'envoi ; l'application n'envoie rien automatiquement.
- **Charges et échéances :** nouvelle page accessible depuis Profil, avec libellé/catégorie libre, montant, périodicité (mensuelle, trimestrielle, annuelle ou unique), prochaine échéance, délai de rappel, paiements partiels ou complets et historique des règlements. Un Worker Android quotidien prépare des notifications locales, limitées à l'organisation connectée.
- **Pilotage financier :** l'écran affiche le chiffre d'affaires issu des ventes confirmées, les règlements des charges récurrentes et un solde indicatif. Ce solde ne représente pas le résultat SYSCOHADA, ne calcule pas les impôts et ne remplace pas une validation comptable.
- **Fidélité :** nouvelle entrée Profil et quatre modèles par profil d'activité : points, passages/visites, dépenses cumulées et fréquence de visite. Les règles, seuils, fenêtres, avantages, activation et historique sont configurables. Les activités et récompenses sont persistées localement ; leur alimentation automatique depuis les ventes et le CRM attend l'API ERP synchronisée.
- **Migration locale :** Room passe de la version 7 à 8 ; la migration ajoute les données fournisseur, charges, règlements, programmes et événements de fidélité, sans supprimer les données existantes.

### Parrainage PME

Le parcours de parrainage déjà ajouté au Profil conserve le code organisation, le suivi des PME inscrites et de la première activation payée, avec récompenses par blocs successifs de cinq. La migration candidate distingue le cycle mensuel gratuit de l'extension annuelle d'un mois. La correction du 20 novembre renforce l'idempotence des webhooks et rejette une cadence nulle ou un identifiant d'événement réutilisé pour un autre abonnement.

**Limite à ne pas masquer :** l'attribution du gain est encore au statut d'avantage à appliquer. L'abonnement gratuit / le mois additionnel ne sera réel qu'après connexion au moteur d'entitlements et au fournisseur de paiement, avec webhooks signés et secrets configurés.

### Contrats serveur candidats et limites d'environnement

Le fichier `supabase/drafts/naxa_services_v3_operations_rewards_sync.sql` ajoute des candidats de tables pour les charges, paiements, programmes et événements de fidélité, reçus de synchronisation idempotents, conflits et file de notifications, avec contrôles de portée organisation/site. Le fichier reste explicitement en transaction de retour arrière (`rollback`) : il n'a pas été appliqué.

Le seul projet Supabase connecté est le projet existant **NAXA** ; il ne contient ni tables `ns_*` NAXA SERVICES ni Edge Function NAXA SERVICES déployée. La création d'une branche de base dédiée demande une validation de coût ; aucune dépense n'a été engagée. Aucune migration, aucun secret, webhook, prélèvement, livraison FCM/SMS/WhatsApp côté serveur ni déploiement n'a été exécuté.

### État des validations

- Les tests de contrat Auth, Referral et tarifs ont réussi sur la tentative GitHub Actions `44800815315`.
- Le job Android était encore en cours lors de cette mise à jour ; ne pas considérer la nouvelle version APK comme validée tant que ce job n'a pas fini avec succès.
- La compilation Android antérieure du parrainage et du noyau NAXA SERVICES reste validée sur le workflow `44792804538`, mais ne couvre pas ces nouveaux modules.

### Qualification globale non acquise

Les points suivants restent à fermer avant de déclarer NAXA SERVICES « VERT GLOBAL » : API ERP distante et synchronisation offline de bout en bout ; application et tests réels du RLS ; intégration de paiement récurrent, webhooks et entitlements ; synchronisation serveur des rappels/CRM et fournisseurs push/SMS/WhatsApp ; interconnexion réelle fidélité-caisse ; rapprochement complet SYSCOHADA/fiscalité/paie validé par des professionnels ; essais instrumentés sur appareils, charge et restauration ; release Android signée ; Web/PWA séparée ; traduction Fulfulde complète et relue ; console centrale des dix applications, mutualisation effective des Customer Service Officers, passerelle IA versionnée et intégration fonctionnelle NAXA SECURITY.

Ces travaux exigent notamment un projet Supabase isolé autorisé, secrets de prestataires, règles opérationnelles validées, clés de signature, appareils de recette et validations professionnelles. Le code reste sur la branche de travail ; le présent ajout de continuité ne vaut ni fusion, ni mise en production.


## 6.17.22 — Clôture de la passe NAXA SERVICES : CI Android verte, global non qualifié (20 novembre 2026)

La branche de travail NAXA SERVICES a reçu les parcours réapprovisionnement fournisseur WhatsApp, charges/échéances, rappels Android locaux, pilotage CA indicatif, quatre programmes de fidélité par profil d'activité et le durcissement idempotent du parrainage. Les entrées Profil de gestion (parrainage, fidélité et charges) sont réservées au rôle promoter.

### Preuve finale de construction

- Branche : work/naxa-services-completion-20261120
- HEAD : 1117dac353d1cd3e0ef93b96430614e422d8d329
- GitHub Actions : 44802531739 — SUCCESS, 4/4 jobs (Android debug, Auth, Referral, catalogue tarifs).
- APK debug : artefact 14661607933, 11 682 565 octets, SHA-256 233c24881277cac33e813b3352674d7392340fd4962308d9feeab8e70a7e44c9, expiration 27 novembre 2026 à 19:31:23 UTC.
- Rapport technique section 39 : docs/naxa-services/NAXA_SERVICES_CONSTRUCTION_STATUS_2026-11-20.md sur la branche de travail.

### Fonctions locales ajoutées

- Stock : contact WhatsApp par article, CSV fournisseur et message de commande prérempli au seuil ; validation de l'envoi laissée à l'utilisateur.
- Charges : échéances récurrentes, paiements partiels/complets, historique, désactivation, notification WorkManager quotidienne et permission runtime Android 13+.
- Gestion : CA des ventes confirmées consolidé sur les sites actifs et paiements de charges récurrentes ; solde explicitement indicatif, non SYSCOHADA.
- Fidélité : quatre programmes configurables (points, passages, dépenses, fréquence), seuils/vagues, reliquats de points, événements et historique local.
- Parrainage : génération/suivi et contrats de gains par vagues de cinq ; contrôles d'idempotence du webhook améliorés.

### Limites bloquantes au vert global

Ces parcours ne sont pas encore intégrés à une API ERP distante ni synchronisés de bout en bout entre appareils. Les activités de fidélité restent enregistrées manuellement et ne sont pas encore déclenchées automatiquement par la caisse. Les notifications de charges sont locales, pas FCM/SMS/WhatsApp serveur. Le gain de parrainage est enregistré en attente d'entitlement : aucun abonnement n'est offert/prolongé tant que le fournisseur de paiement et le moteur d'entitlements ne sont pas connectés.

Les scripts Supabase v1/v2/Referral/v3 sont des drafts ; le v3 reste rollback-only. Le projet Supabase connecté est le projet existant NAXA, sans schéma ns_* ni Edge Functions NAXA SERVICES. Aucune migration, aucun secret, aucun paiement ni aucune fonction serveur n'a été déployé. La création d'une branche de base dédiée a nécessité une validation de coût qui n'a pas été donnée ; aucune dépense n'a été engagée.

Restent également : RLS réel appliqué et testé, API/synchronisation/idempotence/conflits complets, paiements récurrents réels et webhooks, services FCM/SMS/WhatsApp Business, certification comptable/fiscale/paie, recette instrumentée et restauration, release Android signée, Web/PWA séparée, Fulfulde relu, centralisation des dix apps, Customer Service Officers partagés, passerelle IA versionnée et intégration fonctionnelle NAXA SECURITY.

**Statut à conserver :** le code Android de cette passe et les 4 jobs CI sont verts sur la branche. NAXA SERVICES n'est pas qualifié « VERT GLOBAL ». Le code n'a pas été fusionné dans main et aucun déploiement production n'a été effectué.

## 6.17.23 — Clôture N2 et validation complète de la chaîne CI NAXA SERVICES (22 novembre 2026)

Cette section actualise la section 6.17.22 à partir des preuves GitHub Actions du 22 novembre. Elle clôt le lot N2 et la construction Android Debug, mais **ne qualifie pas NAXA SERVICES VERT GLOBAL ni prêt pour la production**.

### N1 et N2 — statuts figés

- **N1 : VERT COMPLET — 55/55 points d'émission `enqueue()` qualifiés** dans le registre canonique du 22 novembre. Ne pas rouvrir sans changement du code source.
- **N2 : VERT COMPLET — 44/44 mutations distantes** (REMOTE_MUTATION) couvertes par le contrat de passerelle atomique. Les 92 codes d'action associés sont présents dans l'allowlist TypeScript et le dispatcher SQL.
- OBX-023 est clos : l'acompte pressing espèces nécessite une session de caisse ouverte du même site ; les autres moyens restent pending sans confirmation serveur ; l'avance client est enregistrée sans la confondre avec du chiffre d'affaires.

### Preuves PostgreSQL 17 / Runtime RLS

Le run CI de référence applique les drafts uniquement à une base PostgreSQL 17 jetable et vérifie les frontières Runtime RLS. Les scénarios confirmés comprennent :

- création puis annulation d'une vente Mobile Money sans confirmation fictive ;
- mise à jour client avec rejet d'une version périmée ;
- création et transition d'un dossier de gestion ;
- conversion atomique d'une liste d'attente en rendez-vous ;
- séquence de pointage RH avec rejet d'une transition invalide ;
- transfert multisite par un compte Promoteur, avec mouvements source et destination et rejeu idempotent.

Les contrôles SQL statiques, les contrats Deno, les contrôles métier, la qualification N1, les contrats Auth/Referral/notifications/paiements/tarifs/accounting et le build Web sont également en succès sur le run de référence. Le build Web et les tests Auth ne constituent pas une preuve de parité ERP Web/PWA.

### Clôture de la chaîne Android et artefact Debug

- Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA`.
- Branche de code : `work/naxa-services-completion-20261120`.
- Commit testé : `42809f58b88e3c0a43408eb09d630994e2fd0aed`.
- Run GitHub Actions : [44986586497 — SUCCESS](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44986586497).
- **11/11 jobs SUCCESS**, aucun job en attente ou en échec.
- Android : tests comptables/performance, tests PIN/Keystore, compilation, assemblage APK Debug et téléversement réussis.
- Artefact `naxa-services-debug-apk` : ID `14739498340`, taille 13 590 875 octets, archive SHA-256 `cd2ad8ec0b8c6b1c891ffd3c40dbccfd8cd0854fd2cf0d4e3c57eba6d6aaa0e0`, expiration 29 novembre 2026 à 04:53:19 UTC.
- Ce livrable est un **APK Debug**. Il ne constitue pas une Release Android signée.

### Frontières conservées

- Aucun code applicatif n'a été fusionné dans `main`.
- Le document global de continuité est mis à jour sur `main` ; le code demeure sur sa branche de travail.
- Les tests RLS/runtime sont des tests laboratoire sur PostgreSQL jetable ; aucun draft n'a été appliqué à un Supabase hébergé.
- Le projet NAXA/pharmacie historique reste explicitement hors périmètre.
- Aucun déploiement Edge, FCM, Mobile Money marchand, ni mise en production n'est déclaré.

### Prochain lot obligatoire : N3 — orchestration Android universelle

N3 est le prochain point de travail, N1 et N2 étant clos. Son critère de mise au vert est une synchronisation Android réellement universelle, et non l'extension cosmétique du coordinateur fournisseur actuel.

Le lot N3 doit démontrer au minimum :

1. snapshots versionnés et validés pour les mutations métier à synchroniser, sans envoyer comme mutations indépendantes les effets composites, ledgers dérivés ou miroirs serveur ;
2. identité d'installation/appareil et séquence monotone liées au dispositif enregistré, avec identité d'acteur dérivée de la session ;
3. coordinateur commun consommant les handlers N2, couvrant l'ensemble des familles de mutations retenues et leurs dépendances inter-agrégats ;
4. déclenchement automatique WorkManager et action manuelle, avec leases, backoff/jitter, reprise après arrêt/crash et conservation des événements bloqués ;
5. ordre déterministe par appareil/agrégat, sans fausse hypothèse d'ordre global entre appareils indépendants ;
6. reçu serveur authentique avant l'état local `synced` ; rejeu identique idempotent et rejeu divergent rejeté ;
7. tests instrumentés réseau instable, multi-appareils, doublons, dépendances manquantes, conflits de versions et périmètres organisation/site/poste.

Le coordinateur `SupplierSyncCoordinator` reste borné au cycle fournisseur, manuel/opt-in et non universel. Jusqu'à la réussite de tous les critères N3 et de leurs preuves CI, le statut N3 reste **NON VERT**. N4 (Web/PWA métier) ne commence qu'après la clôture documentée de N3, conformément à l'ordre de fermeture.

---
 
## 8. Dossier de continuité dédié — LOYABLE (21 novembre 2026)

Le référentiel produit LOYABLE a été séparé dans **`docs/loyable/LOYABLE_CONTINUITE.md`** afin de conserver ses décisions, son périmètre fonctionnel, son Centre de maintenance et ses dépendances inter-applications sans alourdir ni mélanger les cahiers des autres produits.

Ce document dédié devient la référence de reprise LOYABLE pour :
- les quatre espaces Gestion, Locataire, Immobilier et Publication NAXA ;
- les décisions validées sur les accès QR/lien, les loyers, les reçus, les annonces, les tarifs et les fonctions du bailleur ;
- le Centre de maintenance de bout en bout ;
- la capitalisation du catalogue et du réseau de prestataires NAXA SERVICES ;
- le contrat d'intégration à concevoir entre LOYABLE et NAXA SERVICES ;
- les points ouverts et l'ordre des prochains travaux.

**Règle de cohérence :** les décisions spécifiques LOYABLE du 21 novembre 2026 consignées dans ce document dédié prévalent sur les formulations plus anciennes du cahier LOYABLE, notamment pour les états des lieux (désormais exclus). Les statuts de développement doivent toujours être vérifiés séparément ; une exigence documentée n'est pas une preuve d'implémentation.

## 9. Mise à jour LOYABLE — Centre de maintenance et interconnexion NAXA SERVICES (21 novembre 2026)

Le cahier des charges détaillé du Centre de maintenance LOYABLE et de son interconnexion avec NAXA SERVICES est créé à :

- **docs/loyable/LOYABLE_CAHIER_DES_CHARGES_CENTRE_MAINTENANCE_INTERCONNEXION.md**
- Continuité LOYABLE mise à jour : **docs/loyable/LOYABLE_CONTINUITE.md**

### Décision utilisateur intégrée au référentiel

Le registre des prestataires compatibles avec LOYABLE V1 ne retient que les activités **Réparation** et **Menuiserie** du catalogue NAXA SERVICES. Le catalogue complet NAXA SERVICES reste inchangé ; les autres catégories ne sont pas proposées dans le registre LOYABLE V1. Les sous-spécialités, zones, disponibilités, capacités, collaborateurs habilités et niveaux de vérification complètent les deux catégories, sans présumer des compétences non vérifiées.

### Réutilisation inter-applications — statut exact

- **NAXA :** composants transverses potentiellement réutilisables après audit de compatibilité (organisations/périmètres, rôles, audit, stockage privé, notifications, contrats et synchronisation). Les schémas et données spécifiques à la pharmacie ne sont pas repris.
- **NAXA SERVICES :** le rapport de construction consulté documente des fondations Android locales pour organisations/sites, catalogue, agenda, prestataires/équipe et certains workflows. La synchronisation ERP est encore partielle ; aucun ordre de maintenance LOYABLE ni contrat inter-applications complet n'est déclaré opérationnel.
- **JOBLY :** seuls les patterns de profil partenaire, vérification/KYC, QR/code révocable, attribution, états et idempotence sont des références à adapter. Les comptes, wallets, commissions et règles commerciales JOBLY Partner ne sont pas réutilisés pour les prestataires.

### Portée documentaire et technique

Cette mise à jour est documentaire. Elle n'a créé ni modifié de code applicatif, ni migration Supabase, ni fonction serveur, ni endpoint, ni secret, ni déploiement. La présence d'une exigence dans le cahier n'est pas une preuve d'implémentation. Les arbitrages opérationnels encore ouverts sont listés dans le cahier détaillé, notamment plafonds de dépense, SLA/urgences, sous-spécialités réellement vérifiées, partage des coordonnées, conservation des médias, qualité et refacturation locataire.

**Règle de reprise :** démarrer par l'inventaire réel des organisations NAXA SERVICES Réparation/Menuiserie, puis finaliser les décisions métier et le contrat d'intégration avant tout développement du parcours vertical.

## 10. Addendum LOYABLE — abonnement, Marketplace, réseau prestataires, messagerie et sécurité (21 novembre 2026)

Références mises à jour :
- Cahier détaillé : `docs/loyable/LOYABLE_CAHIER_DES_CHARGES_CENTRE_MAINTENANCE_INTERCONNEXION.md` (version 1.1).
- Continuité produit : `docs/loyable/LOYABLE_CONTINUITE.md` (version 1.2).

### 10.1 Abonnement dynamique LOYABLE — règle déjà approuvée conservée

LOYABLE garde une souscription unique à accès complet, sans paliers ACCÈS/PREMIUM, calculée sur **1 000 FCFA × nombre de chambres actives/en gestion** du portefeuille du Promoteur. La quantité est versionnée et recalculée ; la prise d'effet et le prorata lors d'une modification en cours de période restent à arbitrer.

### 10.2 Expiration, rappel et verrouillage — nouvelle décision utilisateur

- Notification au Promoteur 72 heures avant la date/heure d'expiration, sur événement serveur idempotent.
- À l'échéance sans paiement confirmé, le compte opérationnel du bailleur est verrouillé : accès aux fonctions de gestion LOYABLE refusé côté serveur, pas seulement masqué dans l'interface.
- Un paiement pending, une référence saisie ou une preuve non vérifiée ne déverrouille pas l'espace.
- Un parcours restreint et séparé de renouvellement/paiement doit rester accessible pour réactiver la souscription.
- Les données et historiques ne sont pas supprimés.
- L'accès strict du locataire à ses propres documents et au signalement de maintenance pendant la suspension est une proposition à confirmer ; il ne doit pas ouvrir l'espace bailleur.

Cette règle est une exception spécifique LOYABLE aux formulations génériques de maintien d'un accès de consultation après expiration. Elle ne modifie pas automatiquement les règles des autres applications.

### 10.3 Marketplace

Les annonces partenaires dépendantes de la souscription sont masquées de toutes les surfaces publiques (recherche, URL directe, détail et indexation) dès l'expiration non payée. Elles sont conservées et peuvent être réactivées automatiquement après paiement serveur confirmé, seulement si le logement et l'annonce restent éligibles. Les publications assistées des bailleurs non partenaires conservent leur facturation et leur échéancier propres.

### 10.4 Parrainage LOYABLE — règle validée [V]

Chaque groupe de trois nouveaux bailleurs dont le premier abonnement est effectivement payé et confirmé côté serveur donne au parrain un mois LOYABLE offert. Mensuel : un cycle ajouté à la prochaine échéance ; annuel : un mois calendaire ajouté en fin de période. Le crédit est non monétaire, non transférable et non retirable ; les groupes sont cumulatifs par séries de trois. Anti-auto-parrainage, anti-doublon, exclusion des essais/paiements en attente/annulés/remboursés et ledger idempotent obligatoires.

Le code QR et le lien de parrainage sont utilisables uniquement lorsque le bailleur est actif. Ils sont désactivés pendant l'inactivité, l'expiration ou la suspension, puis réactivés automatiquement avec le même code après confirmation du retour à l'état actif. Les filleuls déjà rattachés lorsque le code était actif conservent leur attribution.

### 10.5 Répertoire des demandes et géolocalisation prestataire — diffusion volontaire [V]

Le tableau des missions LOYABLE destinées aux prestataires NAXA SERVICES reste disponible pour les catégories Réparation/Menuiserie, avec filtres catégorie, ville et proximité ; le GPS reste facultatif et l'adresse/identité du locataire restent masquées avant affectation. **La diffusion automatique est annulée** : chaque mission n'apparaît dans le tableau qu'après action volontaire « Publier aux prestataires » du bailleur. L'invitation directe reste possible. Le prestataire manifeste son intérêt et le bailleur décide de l'affectation.

### 10.6 Messagerie bailleur-prestataire

Messagerie dans LOYABLE et NAXA SERVICES, attachée à la demande/mission, avec texte, pièces privées, notifications, historique et états réellement vérifiés (envoyé, reçu, distribué, lu). Droits limités à l'organisation et à la mission ; la messagerie n'est ni le compte partagé ni le support client central.

### 10.7 Vidéosurveillance via le module NAXA SECURITY [V/P]

LOYABLE se raccorde au module NAXA SECURITY. Le bailleur connecte son propre matériel à LOYABLE via ce module et accède à toutes les caméras effectivement connectées, compatibles et autorisées pour son organisation. SECURITY gère l'appairage, les identifiants techniques, les flux, les droits, alertes et journaux ; LOYABLE affiche les vues autorisées. Le direct multi-caméras et l'accès aux enregistrements dépendent des capacités du matériel et du connecteur. L'inventaire des matériels/protocoles compatibles reste à auditer ; aucune compatibilité universelle n'est présumée. Droits vidéo séparés des droits locatifs, priorité aux espaces communs, audio désactivé par défaut. NAXA ne fournit pas le matériel et n'opère pas de surveillance humaine.

**Portée de l'audit :** le fichier Android NAXA SECURITY examiné dans main ne démontrait qu'un écran socle ; l'intégration caméra décrite ici est une cible, pas une fonctionnalité déjà opérationnelle.

### 10.8 Service client et proposition de SLA [P — validation utilisateur requise]

Le support LOYABLE s'inspire de NAXA SERVICES et doit réutiliser le Support/CSO central après audit de compatibilité. Proposition d'horaires : lundi–vendredi 08 h–18 h et samedi 09 h–13 h (Africa/Douala), fermé dimanche/jours fériés. P1 : réponse humaine ≤1 h ouvrée, confinement/contournement ≤4 h et résolution cible ≤1 jour ouvré ; P2 : réponse ≤4 h ouvrées, contournement ≤1 jour et résolution cible ≤2 jours ouvrés ; P3 : réponse ≤1 jour ouvré et résolution cible ≤5 jours ouvrés ; P4 : réponse ≤2 jours ouvrés et qualification/orientation ≤10 jours ouvrés. Les compteurs sont suspendus dans l'attente d'informations client ou d'un fournisseur externe. Pas de promesse 24/7. Ces délais restent une proposition à valider, pas un engagement contractuel.

### 10.9 Sauvegarde personnelle Google Drive et sessions NAXA [V/P]

Le client connecte son propre Google Drive depuis Profil → Sauvegarde, conserve ses archives dans son compte et déclenche lui-même sauvegarde/restauration dans LOYABLE. OAuth limité, espace dédié, vérification d'intégrité et restauration avec aperçu/confirmation ; le client gère son compte, son quota et la conservation. Les sauvegardes d'exploitation des services NAXA restent une responsabilité centrale distincte.

La persistance de session suit le modèle prévu dans NAXA ; les jetons ne sont jamais placés dans les archives Drive. Le parcours d'authentification reprend le modèle NAXA SERVICES, après audit des composants exacts et sans fusion des comptes.

### 10.10 Référentiel de statut

| Domaine | Niveau documentaire |
|---|---|
| Prix dynamique LOYABLE 1 000 F/chambre active/en gestion | Décision existante [V] |
| Rappel H−72, verrouillage bailleur et continuité limitée du locataire | Décisions utilisateur [V] |
| Masquage et réactivation des annonces Marketplace après paiement | Décision utilisateur [V] |
| Parrainage : 1 mois par 3 filleuls payants, QR actif avec le bailleur | Décision utilisateur [V] |
| Missions prestataires et filtres catégorie/ville/proximité | Décision utilisateur [V] ; publication volontaire [V] |
| Messagerie bailleur-prestataire | Décision utilisateur [V], contrats/droits à concevoir [P] |
| Module vidéo NAXA SECURITY | Orientation utilisateur [V], intégration caméra non constatée [P/C] |
| Service client et SLA P1–P4 | Modèle à valider par l'utilisateur [P] |
| Contrat locataire par photo/PDF | Décision utilisateur [V] |
| Google Drive client depuis Profil | Décision utilisateur [V], intégration OAuth/restauration non démontrées [P/C] |
| Session NAXA et parcours Auth NAXA SERVICES | Orientation validée [V], audit de réutilisation requis [P] |

Aucun code LOYABLE, endpoint, table, migration Supabase, fonction serveur, secret, déploiement ou test de production n'a été ajouté ou exécuté dans cette mise à jour documentaire.

## 11. Addendum LOYABLE — validations complémentaires du 21 novembre 2026

Le cahier détaillé et le document de continuité LOYABLE intègrent les décisions suivantes :

- **Parrainage validé :** un mois offert par groupe de trois filleuls bailleurs dont le premier abonnement a été payé et confirmé côté serveur. Le code/QR et le lien ne sont utilisables que lorsque le bailleur parrain est actif ; ils sont désactivés pendant l'inactivité et réactivés avec le même code après réactivation. Les filleuls déjà rattachés conservent leur attribution.
- **Dossier locataire :** le bailleur peut joindre le contrat de chaque locataire par photo(s) ou PDF ; le document est privé, versionné et limité au locataire concerné et aux rôles autorisés.
- **Accès pendant la suspension :** l'espace du bailleur est bloqué à expiration non payée, mais le locataire conserve l'accès à son propre dossier, au contrat et documents autorisés, aux reçus/quittances et à la déclaration de maintenance. Les nouvelles demandes sont enregistrées en attente de réactivation ; aucun prestataire ni engagement de dépense n'est lancé pendant la suspension.
- **Missions prestataires :** le tableau filtrable par catégorie, ville et proximité demeure. La diffusion automatique est annulée : le bailleur doit publier volontairement chaque demande. Les données privées du locataire restent masquées avant affectation.
- **Vidéosurveillance :** LOYABLE se raccorde au module NAXA SECURITY. Le bailleur connecte son matériel et visualise les caméras compatibles/autorisées de son organisation depuis LOYABLE, sous réserve de l'audit de compatibilité et des capacités du module.
- **Support :** une proposition de SLA (horaires et niveaux P1–P4) est inscrite au cahier ; elle reste en attente de validation utilisateur et n'est pas un engagement contractuel.
- **Sauvegarde client :** le client connecte son propre Google Drive depuis Profil et déclenche lui-même ses sauvegardes/restaurations dans LOYABLE. Les sauvegardes d'exploitation NAXA restent distinctes.
- **Session et authentification :** persistance de session selon le modèle NAXA ; parcours d'authentification selon le modèle NAXA SERVICES, après audit et sans fusion des identités entre applications.

Références :
- `docs/loyable/LOYABLE_CONTINUITE.md`
- `docs/loyable/LOYABLE_CAHIER_DES_CHARGES_CENTRE_MAINTENANCE_INTERCONNEXION.md`

Cette consolidation est documentaire uniquement : elle ne démontre aucune implémentation, migration, intégration caméra, connexion Google OAuth, test de sécurité ou déploiement applicatif.