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
| GRILLAD | Organisation, lieux de service, Manager, vendeurs et capacité des sessions, en préservant les trois modes de fonctionnement. |

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

Le catalogue commercial ne doit plus être organisé autour de trois paliers. **La formule PRO est supprimée du référentiel Famille : aucun pack Pro, aucun prix Pro et aucun entitlement Pro ne doit être créé ou conservé.**

Deux noms de formule sont utilisés uniquement lorsque l'application possède réellement deux niveaux d'architecture commerciale :

- **ACCÈS — architecture à compte unique :** un compte principal exploite une entité ou unité opérationnelle selon le modèle métier du produit. Il bénéficie de toutes les fonctionnalités nécessaires à l'exploitation complète de cette architecture. ACCÈS n'est pas une version bridée du produit et ne perd aucun module métier essentiel au fonctionnement d'un compte unique.
- **PREMIUM — architecture multiniveau :** une organisation peut structurer plusieurs niveaux de comptes, rôles, collaborateurs, responsables, établissements, sites ou unités subordonnées selon le produit. PREMIUM inclut intégralement toutes les fonctions et tous les droits d'ACCÈS, auxquels s'ajoutent les capacités d'organisation, de délégation, de supervision et de consolidation correspondant à l'architecture multiniveau.

La règle d'inclusion est impérative :
- `ENTITLEMENTS(ACCÈS) ⊆ ENTITLEMENTS(PREMIUM)` ;
- une souscription PREMIUM ne peut retirer, dégrader ou rendre indisponible aucun droit accordé par ACCÈS ;
- les écarts entre les deux formules doivent principalement refléter la structure de comptes et de responsabilités prise en charge, et non une découpe artificielle des fonctionnalités métier.

La notion de « compte unique » et celle d'« architecture multiniveau » doivent être décrites précisément pour chaque application : entité facturée, compte propriétaire, nombre et nature des sous-comptes, rôles, sites, délégations et droits de consolidation. Ne pas assimiler automatiquement plusieurs employés à plusieurs niveaux d'architecture si le cahier métier distingue compte, utilisateur, poste, rôle et établissement.

**Application avec une seule tarification :** conserver un seul produit commercial affiché sous l'intitulé générique **« Abonnement »** (ou la tarification à l'unité déjà définie). Ne pas créer ACCÈS et PREMIUM artificiellement, même si le produit possède techniquement plusieurs rôles ou entités.

Les fonctionnalités de sécurité, confidentialité, authentification, protection des données, journalisation de sécurité, continuité et récupération/export des données ne constituent jamais des options payantes réservées à PREMIUM.

Le vocabulaire, l'architecture et la matrice de droits doivent être validés par application à partir de son cahier des charges et de son modèle réel avant de configurer le catalogue serveur.

### 6.17.2 Catalogue tarifaire de référence — ACCÈS / PREMIUM / ABONNEMENT et offres spéciales

Les montants sont exprimés en FCFA. Les prix ACCÈS et PREMIUM des applications à deux niveaux sont conservés comme précédemment décidés. Les tarifs supprimés ne doivent pas subsister dans les catalogues actifs, les interfaces, les API ou les migrations de données commerciales.

| Application | Formule / tarif à conserver |
|---|---|
| KIOSKO | ACCÈS : 2 000 ; PREMIUM : 4 000. |
| BOOTIK | ACCÈS : 4 000 ; PREMIUM : 10 000. |
| ZIPPLE | ACCÈS : 5 000 ; PREMIUM : 15 000. |
| NAXA SERVICES | ACCÈS : 3 000 ; PREMIUM : 7 000. |
| COTIZ | **Abonnement individuel par membre** : chaque membre d'une même cotisation souscrit et règle individuellement 500 par membre et par cotisation. Ce n'est pas un abonnement unique payé au nom du groupe. Le compte Président reste gratuit jusqu'à 100 membres, conformément à la règle déjà décidée. Ne créer ni ACCÈS ni PREMIUM. |
| LOYABLE | **Abonnement unique : 1 000 par chambre, accès complet.** Aucun pack PREMIUM séparé, aucun tarif à 4 000 et aucun supplément de formule pour la caméra ou le multisite. |
| NAXA HOTEL | **Abonnement unique : 2 000 par chambre, accès complet.** Aucun pack PREMIUM séparé, aucun tarif à 5 000 et aucun supplément de formule pour la caméra ou le multisite. |
| NAXA SECURITY | ACCÈS : 5 000 ; PREMIUM : 15 000. Conserver les deux niveaux et les règles d'extensions de capacité déjà arbitrées (+20 % par extension selon la décision existante). |
| GRILLAD | ACCÈS : 1 500 ; PREMIUM : 3 000. Conserver les deux montants et mapper les architectures d'exploitation réelles sur les capacités de compte unique ou multiniveau. |
| CAMPUS237 | Établissement gratuit. Abonnements facturés individuellement à chaque parent : **Pack Individuel : 1 000 par parent pour suivre 1 élève d'une école ; Pack Famille : 3 000 par parent pour suivre jusqu'à 5 élèves**, inscrits dans la même école ou dans plusieurs écoles différentes. Ne pas créer de troisième pack et ne pas facturer les établissements. |

#### Règles spécifiques COTIZ

L'unité facturable est le membre, et non le groupe de tontine ou l'ensemble de la cotisation. Chaque membre rattaché à une même cotisation possède son propre abonnement individuel à 500 FCFA par cotisation. Le statut gratuit du compte Président jusqu'à 100 membres est conservé. La gestion des cotisations par COTIZ ne signifie pas que COTIZ détient ou transfère les fonds des membres.

#### Règles spécifiques LOYABLE et NAXA HOTEL

Chaque application possède un seul abonnement à accès complet, exprimé par chambre au tarif indiqué. Il n'existe pas de distinction commerciale ACCÈS/PREMIUM pour ces deux produits dans le catalogue actuel. La suppression des anciens tarifs renforcés ne doit pas désactiver les fonctions métier, la sécurité ou les capacités multisites incluses dans le périmètre complet de chaque application. Les coûts éventuels d'équipements physiques, d'installation ou de services externes ne sont pas assimilés à un supplément de formule logiciel et nécessitent un traitement distinct s'ils existent.

#### Règles spécifiques CAMPUS237

- Le **Pack Individuel** est attaché à un compte parent et autorise le suivi d'un élève dans une école.
- Le **Pack Famille** est attaché à un compte parent et autorise le suivi d'un maximum de cinq élèves ; ces élèves peuvent être inscrits dans la même école ou dans plusieurs écoles différentes.
- La souscription est individuelle par parent. Le fait que deux parents suivent le même élève ne fusionne pas leurs comptes ou abonnements.
- L'établissement scolaire ne paie aucun abonnement CAMPUS237.
- Les deux packs parentaux sont les seules offres prévues à ce stade. Aucun pack PRO ou troisième niveau ne doit être ajouté.

Pour toute autre application ou tout autre modèle qui ne possède qu'un seul prix, afficher **« Abonnement »** sans créer de formule supplémentaire. Les prix unitaires, par membre, par cotisation, par chambre ou par parent ne doivent pas être transformés artificiellement en forfaits à plusieurs paliers.

Les périodicités qui ne sont pas explicitement confirmées restent à vérifier avant activation commerciale ; ne pas supposer qu'une tarification par cotisation ou par unité est mensuelle.

### 6.17.3 Règles d'abonnement déjà communiquées

- À l'installation/activation initiale, toutes les fonctionnalités sont disponibles pendant **72 heures**. Cette période est contrôlée côté serveur, attribuée une seule fois à l'unité facturable définie par l'application et ne doit pas être réinitialisable par réinstallation ou changement d'appareil.
- Pour une formule mensuelle récurrente éligible, le prix annuel est égal à dix mensualités : deux mois sont offerts. Cette remise s'applique aux abonnements mensuels concernés, et non automatiquement aux paiements par acte, par cotisation ou aux autres tarifications unitaires dont la périodicité n'est pas établie.
- La période d'essai, le statut de paiement, les dates d'effet et les droits sont établis par le serveur. Une déclaration locale ou une référence de paiement saisie par l'utilisateur ne suffit pas à activer des entitlements.
- Conserver les données et les fonctions nécessaires à la consultation du compte, au renouvellement et à la récupération des données en cas d'expiration. Le verrouillage concerne les opérations payantes selon les règles contractuelles validées.
- Les prix et règles propres à une application restent sous le contrôle de son catalogue versionné. Une modification tarifaire ne change pas rétroactivement un abonnement déjà payé.
- Aucune formule Pro n'est proposée, tarifée, activée ou présente dans les interfaces du catalogue.

### 6.17.4 Modèle de droits et administration des catalogues

Conserver le modèle de référence **Plan → Subscription → Payment → Entitlements** et l'adapter aux contrats NAXA déjà présents. Il ne faut ni créer un second moteur de paiement ni remplacer le RBAC/RLS existant.

- Les droits de formule sont des entitlements explicites, versionnés et rattachés à une application, un plan et une période.
- Les permissions déterminent ce qu'un utilisateur peut faire ; les entitlements déterminent l'architecture et les capacités souscrites par l'organisation. Les deux contrôles doivent être satisfaits.
- ACCÈS correspond à l'architecture à compte unique et donne accès à toutes ses fonctionnalités métier. PREMIUM comprend tous les droits d'ACCÈS et ajoute les capacités multiniveaux prévues pour l'application.
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

### 6.17.11 Priorité de réemploi

Pour construire les fonctions manquantes, appliquer l'ordre suivant :

1. Cahiers des charges et arbitrages validés de l'application FAMILLE-NAXA concernée.
2. Patrimoine NAXA existant : tables, API, fonctions, services de paiement, notifications, support, IA, BI, géolocalisation et outils d'import, après audit de propriété, compatibilité, sécurité et dépendances.
3. Fondations et contrats déjà construits dans le monorepo FAMILLE-NAXA.
4. JOBLY comme référence de conception pour les patterns utiles — catalogue, souscription, entitlements, quotas, UX et cycle de paiement — sans copie aveugle de code, de schéma ou de règles métier.

Pour chaque fonction, désigner un propriétaire canonique, réutiliser ou adapter l'actif existant lorsqu'il est valide, et construire uniquement le manque démontré. Ne jamais créer deux moteurs concurrents de paiement, notification, IA, support, audit ou synchronisation.

