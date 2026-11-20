# NAXA SERVICES — état de construction au 20 novembre 2026

## 1. Point de reprise et périmètre de cette passe

- Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA`
- Base de reprise : `439fa4186b602c45e9958cc264c42b0c9ee6fbb4` — dernier état de `main) constaté avant cette passe.
- Branche de travail : `work/naxa-services-completion-20261120`.
- `main` n'a pas été modifiée par cette passe.
- Aucune migration n'a été exécutée sur une base réelle, aucune fonction Edge n'a été déployée et aucun APK n'a été distribué.

L'objectif a été de poursuivre le code déjà présent, sans reprendre les audits documentaires, la charte, les choix d'authentification et les premiers workflows déjà réalisés.

## 2. Éléments construits ou complétés

### Android natif

Le module `apps/android/naxa-services` reste une application Android native Kotlin / Jetpack Compose.

Le parcours d'authentification existant a été conservé et raccordé aux évolutions de cette passe :

- identifiant NAXA interne ;
- affichage/masquage du mot de passe ;
- demande « Mot de passe oublié » transmise au circuit de récupération administrée ;
- pas d'OTP e-mail ajouté : la récupération reste contrôlée par un responsable ;
- changement obligatoire du mot de passe temporaire ;
- option « Rester connecté » ;
- conservation locale du jeton via le coffre Android Keystore lorsque l'utilisateur active cette option ;
- renouvellement du jeton qui conserve le choix « rester connecté » ;
- révocation/déconnexion et retour à l'écran de connexion.

Le monogramme N rouge du logo NAXA SERVICES est intégré comme ressource Android vectorielle ; le nom NAXA et la mention SERVICES sont rendus dans le wordmark. Le thème sombre reste le thème initial.

### Base locale et opérations ERP

Le fichier `data/LocalErpStore.kt` rétablit le socle Room qui était appelé depuis les écrans mais absent de l'arborescence à la reprise.

Il contient 15 entités Room, toutes enregistrées dans `NsServicesDatabase`, ainsi que le DAO et le dépôt local. Les données opérationnelles sont filtrées par identifiant d'organisation et identifiant du point de vente.

Les workflows locaux couverts sont :

- tickets pressing, progression des statuts et historique des transitions ;
- rendez-vous, avec contrôle des chevauchements par site, poste et prestataire ;
- ouverture, opérations et clôture de caisse, avec calcul de l'écart et justification obligatoire ;
- ventes espèces confirmées et paiements Mobile Money laissés en attente ;
- dépenses de caisse ;
- catalogue local de prestations pressing, coiffure et vente ;
- fiches clients et consentement de contact ;
- articles, seuils et mouvements de stock, sans autoriser un stock négatif ;
- brouillons de points de vente et de postes de travail ;
- demandes d'assistance locales ;
- file d'événements locale, isolée par organisation.

**Important :** la file locale est une outbox de suivi. Elle n'est pas encore un moteur de synchronisation : elle ne rejoue pas les opérations vers le serveur et ne garantit pas leur livraison distante.

### Écrans ERP Android

Les rubriques suivantes sont reliées à des écrans Compose dédiés et non plus à une simple page de présentation :

- pressing ;
- agenda ;
- caisse ;
- catalogue des prestations ;
- clients ;
- stocks et consommables ;
- rapports indicatifs du jour ;
- organisation et modèle d'exploitation ;
- réseau et points de vente ;
- postes/emplacements ;
- gestion des collaborateurs et récupération des accès ;
- assistance ;
- paramètres et état de la file locale.

Les écrans catalogue, clients, stocks, rapports et assistance manipulent des données locales. Les rapports affichent séparément chaque point de vente et une consolidation indicative limitée aux sites autorisés reçus à l'authentification. Ils ne remplacent pas un rapport comptable consolidé serveur.

### Trois modèles d'exploitation

Le modèle est maintenant porté par l'organisation, et non déduit du rôle de la personne connectée :

1. `solo` : PME autonome, un établissement ;
2. `single_site_multi_workstation` : responsable avec plusieurs postes/emplacements dans un même établissement ;
3. `multi_site_network` : Promoteur avec plusieurs points de vente autonomes.

Le profil de l'organisation et le modèle sont lus depuis `ns_organizations`. Une action Auth serveur permet au Promoteur ayant le périmètre Organisation avec droit de gestion de modifier le nom, le modèle et la langue. Les autres rôles voient ces paramètres en lecture seule.

La création de nouveaux sites et postes depuis Android reste un brouillon local. Elle ne les active pas dans le serveur.

### Accès, collaborateurs et séparation des données

- La session Auth retourne les sites actifs autorisés, avec nom, code, adresse et téléphone.
- Les données locales sont cloisonnées par `orgId` et `siteId`.
- Le Promoteur peut préparer un collaborateur avec plusieurs périmètres de sites autorisés.
- Les rôles proposés dans le formulaire sont restreints selon le rôle du responsable.
- Les portées « poste de travail uniquement » ne sont pas élargies en accès site complet. Le filtrage de données poste-par-poste n'étant pas encore implémenté dans tous les écrans, le formulaire de création de collaborateur n'expose pas cette affectation pour le moment.
- Le contrat pur de portée est séparé dans `scope_contract.ts` et des tests Deno couvrent les trois modèles, les périmètres de sites et l'interdiction d'élargir une portée poste en portée site.

## 3. Résultat des contrôles statiques effectués

Les contrôles statiques faits à partir des fichiers de la branche ont donné les résultats suivants :

- 15 entités Room déclarées et 15 enregistrées dans la base ;
- aucun appel DAO ou dépôt local repéré sans méthode correspondante ;
- aucune requête opérationnelle Room repérée sans filtre d'organisation ;
- toutes les insertions outbox repérées fournissent un identifiant d'organisation ;
- aucune référence de chaîne Android actuellement utilisée par `MainActivity.kt` ne manque dans les ressources françaises ou anglaises ;
- aucune clé de chaîne FR/EN dupliquée ;
- présence des écrans ERP Android dédiés et de leur branchement dans la navigation ;
- présence du contrat serveur d'organisation, du retour des métadonnées de sites et des tests de contrat de périmètre.

Ces vérifications sont des contrôles de cohérence du code source ; elles ne constituent pas une preuve de compilation ni une recette fonctionnelle.

## 4. Éléments encore ouverts — ne pas déclarer la version globalement verte

### Construction technique à exécuter

- compilation Gradle de l'application Android et de ses modules dépendants ;
- génération Room/KAPT et résolution réelle des requêtes SQL Room ;
- exécution des tests Deno de `naxa-services-auth` ;
- tests instrumentés Android sur émulateur et appareils physiques ;
- vérification des rotations, reprises d'activité, perte réseau, restauration de session et déconnexion ;
- tests de non-régression de la base locale et du comportement après mise à jour.

### Recette Supabase isolée

Avant toute mise en production, il faut une base Supabase de recette dédiée pour :

- appliquer le SQL draft `supabase/drafts/naxa_services_v1.sql` ;
- exécuter `supabase/tests/drafts/naxa_services_rls_contract.sql` ;
- vérifier les RLS avec les rôles Promoteur, Network Manager, Site Manager et collaborateurs opérationnels ;
- exécuter les tests d'intégration de la fonction Auth avec des comptes de test et l'alias interne NAXA ;
- valider les secrets et le domaine d'alias côté serveur.

La fonction Edge est du code source uniquement dans cette branche : elle n'a pas été déployée.

### Fonctions métier serveur encore à construire

La plupart des opérations ERP ne sont pas encore persistées côté serveur. Les contrats, tables et règles de sécurité existent en partie dans les ressources documentaires/SQL, mais il faut créer et tester les API métier pour les prestations, clients, rendez-vous, tickets pressing, caisses, ventes, paiements, dépenses, stocks, mouvements, transferts et rapports.

Il faut ensuite construire le moteur de synchronisation : identifiants idempotents, ordre des événements, reprise après erreur, conflits, accusés de réception, journal serveur et mécanisme de rejeu.

### Autres limites fonctionnelles et sécurité

- l'accès poste-par-poste n'est pas activé dans le client natif : il faut filtrer chaque consultation et chaque mutation par poste avant d'exposer ces comptes ;
- les droits métier doivent être contrôlés à la fois dans les écrans Android et sur chaque API/RLS ; l'interface locale seule ne constitue pas une barrière de sécurité ;
- la base Room locale n'est pas encore chiffrée au repos ; les règles de sauvegarde Android, d'effacement à la déconnexion et de conservation des données personnelles doivent être validées ;
- les mouvements Mobile Money sont enregistrés en attente, mais aucun agrégateur ou rapprochement de paiement n'est raccordé ;
- présence/pointage, commissions, paie, transferts inter-sites, exports comptables et abonnements ne sont pas encore livrés comme workflows transactionnels complets ;
- le Web/PWA NAXA SERVICES n'a pas été porté au même niveau que l'application Android dans cette passe ; son point d'entrée actuel reste un aperçu et non une application ERP de production.

## 5. Configuration et secrets attendus

Pour une compilation Android configurée :

- propriété Gradle `NS_AUTH_FUNCTION_URL` ;
- propriété Gradle `NS_SUPABASE_ANON_KEY`.

Pour la fonction serveur, les secrets restent exclusivement dans l'environnement Edge :

- `SUPABASE_URL` ;
- `SUPABASE_ANON_KEY` ;
- `SUPABASE_SERVICE_ROLE_KEY` ;
- configuration du domaine d'alias interne NAXA ;
- origines autorisées de l'application.

La clé `SUPABASE_SERVICE_ROLE_KEY` ne doit jamais être embarquée dans Android ou dans le code Web.

## 6. Décision de statut

**Statut : construction Android avancée, cohérence statique contrôlée, recette technique et serveur encore ouverte.**

Cette branche constitue une base de construction bien plus complète que l'état de reprise, mais elle ne doit pas être qualifiée de « verte production » avant compilation Android, tests Deno, tests RLS, recette Auth et tests métier/synchronisation.

Ne pas fusionner, migrer ou déployer sans autorisation distincte et sans validation des éléments ci-dessus.
