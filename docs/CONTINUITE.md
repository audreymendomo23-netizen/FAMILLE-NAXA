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
| GRILLAD | Organisation, lieux de service, Manager, vendeurs et capacité des sessions, en préservant les trois modes de fonctionnement. |

### Niveau de confiance et prochaines étapes

- **Réutilisable après refonte :** concepts Billing/Entitlements, suivi de consommation, moteur IA abstrait, attribution partenaire, journal d'audit et préférences.
- **À reconstruire ou corriger avant intégration :** schéma et cycle Billing, adaptateurs de paiement, remboursements, idempotence concurrente, QR/liens sécurisés, quotas IA avec compensation.
- **Non démontré dans ce snapshot :** validation build/runtime complète. Le ZIP ne contient ni `node_modules` ni fichier lockfile ; les rapports embarqués signalent encore des parcours E2E à exécuter et une traduction FR/EN non certifiée. Cet audit est statique ; aucun build, test contre un fournisseur réel ou test de base de données n'a été exécuté ici.
- **Règles de reprise :** ne pas copier les prix JOBLY ; ne pas migrer la base JOBLY dans Supabase FAMILLE-NAXA ; ne pas fusionner les identités ; ne pas donner au central admin accès aux données opérationnelles ; ne pas modifier production, déployer ou publier d'APK sans autorisation explicite.


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

