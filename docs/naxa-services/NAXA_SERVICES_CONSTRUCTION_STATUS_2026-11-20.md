# NAXA SERVICES — état de construction au 20 novembre 2026

## 1. Point de reprise et périmètre de cette passe

- Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA`
- Base de reprise : `439fa4186b602c45e9958cc264c42b0c9ee6fbb4` — dernier état de `main) constaté avant cette passe.
- Branche de travail : `work/naxa-services-completion-20261120`.
- `main` n'a pas été modifiée par cette passe.
- Aucune migration n'a été exécutée sur une base réelle, aucune fonction Edge n'a été déployée et aucun APK de production n'a été distribué.
- Un APK **debug** a été généré et archivé par GitHub Actions pour recette technique, sans distribution aux utilisateurs.

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
- rendez-vous, avec contrôle des chevauchements par site, poste et prestataire ; les identifiants de poste sont vérifiés contre un poste actif de la même organisation et du même site ;
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
- Le menu, la navigation basse, le tableau de bord et les routes ERP appliquent un filtrage prudent par rôle : caisse, réception, opérateur pressing, stock et comptabilité ne voient que les modules prévus pour leurs fonctions ; les responsables conservent les espaces d'administration correspondant à leur niveau.
- Les portées « poste de travail uniquement » ne sont pas élargies en accès site complet. Le filtrage de données poste-par-poste n'étant pas encore implémenté dans tous les écrans, le formulaire de création de collaborateur n'expose pas cette affectation pour le moment.
- Le contrat pur de portée est séparé dans `scope_contract.ts` et des tests Deno couvrent les trois modèles, les périmètres de sites et l'interdiction d'élargir une portée poste en portée site.

## 3. Résultat des contrôles statiques effectués

Les contrôles statiques et la première validation CI ciblée ont donné les résultats suivants :

- 15 entités Room déclarées et 15 enregistrées dans la base ;
- aucun appel DAO ou dépôt local repéré sans méthode correspondante ;
- aucune requête opérationnelle Room repérée sans filtre d'organisation ;
- toutes les insertions outbox repérées fournissent un identifiant d'organisation ;
- aucune référence de chaîne Android actuellement utilisée par `MainActivity.kt` ne manque dans les ressources françaises ou anglaises ;
- aucune clé de chaîne FR/EN dupliquée ;
- écrans ERP Android dédiés et navigation par rôle compilés ;
- génération Room/KAPT et compilation Kotlin/Compose réussies ;
- `deno check` et les tests de contrat Auth/périmètres réussis ;
- `:naxa-services:assembleDebug` exécuté avec succès sur GitHub Actions.

**Preuve CI :** run [44730761819](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44730761819), commit `283e6cc902d4d0c05effda85f2a82c5ecdc53cf7`, résultat global `success`. L'artifact `naxa-services-debug-apk` (ID `14626501380`) contient l'APK debug généré.

La compilation et les tests de contrat ne remplacent pas les tests instrumentés, les essais sur appareils physiques, ni la recette fonctionnelle Auth/ERP sur un Supabase isolé.

## 4. Éléments encore ouverts — ne pas déclarer la version globalement verte

### Construction technique et recettes encore ouvertes

- compilation **Release** et signature avec un certificat de livraison contrôlé ; seul l'APK debug est actuellement construit ;
- tests instrumentés Android sur émulateur et appareils physiques ;
- vérification des rotations, reprises d'activité, perte réseau, restauration de session et déconnexion ;
- tests de non-régression de la base locale et du comportement après mise à jour ;
- test d'installation/mise à niveau, permissions, sauvegarde et effacement local ;
- tests de performance sur listes volumineuses et utilisation hors connexion prolongée.

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

- l'accès poste-par-poste n'est pas activé dans le client natif : il faut filtrer chaque consultation et chaque mutation par poste avant d'exposer ces comptes ; le rôle `workstation_manager` n'est donc pas proposé dans la création de collaborateurs et reste limité à l'accueil, l'assistance et aux paramètres ;
- les droits métier doivent être contrôlés à la fois dans les écrans Android et sur chaque API/RLS ; le filtrage Android par rôle est une protection d'interface, pas une barrière de sécurité ; les opérations locales doivent encore être alignées sur les mêmes capacités que les droits `can_read`, `can_operate` et `can_manage` du serveur ;
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

**Statut : APK Android debug compilé avec succès et tests Auth de contrat verts ; recette fonctionnelle Android et recette Supabase/RLS encore ouvertes.**

Cette branche franchit désormais la porte de compilation Android debug et de tests Auth de contrat, mais elle ne doit pas être qualifiée de « verte production » avant les tests instrumentés, la recette Auth/RLS sur Supabase isolé et les tests métier/synchronisation.

Ne pas fusionner, migrer ou déployer sans autorisation distincte et sans validation des éléments ci-dessus.


---

# Addendum — extension du périmètre fonctionnel et audit de continuité
**Mise à jour : 20 novembre 2026 — après génération de l'APK debug**

> Cet addendum complète le constat de construction ci-dessus. Il ne transforme pas les demandes ci-dessous en fonctions déjà livrées. Les nouvelles fonctions sont des exigences de produit et un backlog de réalisation. Les tarifs, durées et mécanismes hérités marqués [P] ou [O] restent à arbitrer.

## 7. État de référence Git et preuve de construction

- Branche examinée : \`work/naxa-services-completion-20261120\`.
- HEAD vérifié : \`a78e9debd39731f1d79c63cff9a9bc5f6944f6ea\`.
- Base de la branche : \`439fa4186b602c45e9958cc264c42b0c9ee6fbb4\`, qui reste la référence de \`main\`.
- Comparaison GitHub : branche en avance de 70 commits, en retard de 0 commit par rapport à cette base.
- Le run GitHub Actions \`44730761819\` reste en succès sur le commit compilé \`283e6cc902d4d0c05effda85f2a82c5ecdc53cf7\`.
- L'artifact \`naxa-services-debug-apk\`, ID \`14626501380\`, est présent et non expiré au moment du contrôle.
- Aucun merge, aucune migration réelle, aucun déploiement et aucune publication de Release n'ont été réalisés dans cette mise à jour documentaire.

## 8. Audit du code Android réellement présent

### 8.1 Éléments déjà construits — ne pas recommencer

Inspection effectuée sur \`MainActivity.kt\`, \`ErpModules.kt\` et \`data/LocalErpStore.kt\`.

- Authentification interne, récupération administrée, changement de mot de passe temporaire, option « Rester connecté », coffre de session et révocation/déconnexion.
- Modèle d'organisation avec trois modes distincts : \`solo\`, \`single_site_multi_workstation\`, \`multi_site_network\`.
- Séparation locale par organisation et point de vente.
- Écrans et opérations locales déjà présents : pressing, agenda, caisse, catalogue de prestations, clients, équipe, stocks/consommables, rapports indicatifs, organisation, réseau, sites, postes, gestion des accès, assistance et paramètres.
- Les opérations pressing ont des statuts et un historique local ; les rendez-vous contrôlent localement les conflits de site/poste/prestataire ; la caisse gère ouverture, ventes, dépenses et clôture avec écart ; le stock interdit une quantité négative.
- Les rapports consultent localement les ventes, dépenses, rendez-vous et tickets pressing des sites autorisés reçus par la session.
- Le modèle Room examiné déclare 15 entités. La file locale d'événements est une outbox : elle ne constitue toujours pas un moteur de synchronisation serveur.

Ces éléments doivent être conservés et étendus par changements additifs. Toute refonte doit préserver les parcours existants et ajouter des tests de non-régression.

### 8.2 Écarts observés dans les écrans actuels

- Après authentification réussie, l'application arrive directement au tableau de bord (ou à l'écran de changement de mot de passe). Aucun choix initial d'activité, parcours de quatre cartes ou tutoriel guidé première connexion n'est présent.
- Aucun écran d'acceptation versionnée des Conditions générales et de la Politique de confidentialité n'a été trouvé dans le parcours d'authentification inspecté.
- Le choix de langue n'est pas un sélecteur opérationnel sur l'accueil : les paramètres indiquent que le français et l'anglais sont disponibles, mais ne permettent pas encore un vrai changement de langue persistant et immédiatement appliqué.
- Il n'existe pas encore de centre « Profil » unifié avec photo, informations personnelles, langue, historique, préférences, sessions et déconnexion.
- Le tableau de bord est une vue de base : salutation, carte « données non synchronisées », raccourcis et liens de navigation. Aucun carrousel d'images/KPI automatique à cinq secondes n'a été trouvé.
- L'écran « Sécurité » est actuellement raccordé à la gestion des accès. Il ne constitue pas encore un centre complet de sécurité des comptes, appareils, sessions, audits, sauvegardes et alertes.
- L'assistance actuelle permet de créer et consulter des demandes conservées localement. Elle n'est pas un Livechat connecté ; ni appel audio/vidéo ni partage d'écran n'est démontré.
- Les écrans qui n'ont pas de workflow métier raccordé affichent encore des actions génériques de préparation. Leur présence dans le menu ne signifie pas que leur fonction est livrée.
- Les écrans locaux ne démontrent pas encore la facturation, les factures, les avoirs, les crédits clients, les remboursements dus, la comptabilité complète, la paie, les abonnements transactionnels, les taxes, les sauvegardes Drive ou une livraison réelle de notifications push.

### 8.3 Écart de modèle de données

Le magasin Room actuel contient notamment tickets pressing, rendez-vous, ventes, dépenses, sessions de caisse, file locale, organisations, sites, postes, prestations, clients, articles/mouvements de stock et demandes d'assistance.

Les entités et workflows métier suivants restent à concevoir, relier à l'outbox et exposer dans des API sécurisées : factures et lignes, devis, avoirs, remboursements, crédits/avoirs client et échéanciers, paiements et rapprochements, fournisseurs et achats, valorisation des stocks, comptabilité/journaux, taxes, objectifs, pointage et horaires, commissions/avances/primes consolidées, abonnements/entitlements, parrainage PME, pièces jointes et reçus, préférences de notification, historique/profil utilisateur et sauvegardes/restaurations.

## 9. Référentiel fonctionnel à préserver du cahier NAXA SERVICES

Le cahier \`7 famille naxa/01-cahiers-des-charges/04-naxa-services.md\` et les prompts \`7 famille naxa/02-prompts/04-naxa-services.md\` restent les bases métier initiales. Les blocs suivants ne doivent pas être oubliés dans la refonte :

1. **Catalogue et tarification :** catégories, prestations, prix, durée, prestataire habilité, forfaits, formules et produits vendus au comptoir.
2. **Agenda :** créneaux, durée, ressources, prestataires, acomptes, annulations, absences, liste d'attente et rappels préparés.
3. **Pressing :** dépôt, ticket, pièces, tarifs, acompte, date promise, étiquette, statuts reçu/en cours/prêt/retiré, relances et vêtements non retirés.
4. **Équipe :** prestataires, affectations, commissions datées, avances, primes, pointage, présences, classements et défis.
5. **CRM/fidélité :** fiche et historique client, préférences, fidélité, QR, anniversaires, offres, parrainage client et relance d'inactivité.
6. **Caisse :** ouverture/clôture, recettes par moyen de paiement, dépenses, écarts par employé, justificatifs et journal d'audit.
7. **Stock léger :** produits de coiffure, lessive, consommables, seuils, mouvements, inventaire et alertes.
8. **Pilotage et comptabilité :** ventes, marges, prestations rentables, fréquentation, heures de pointe, taux de remplissage, objectifs, journal, trésorerie, compte de résultat simple, SYSCOHADA et TVA datée/paramétrable.
9. **IA et briefings :** prévisions, anomalies, coach du jour, santé de l'activité, relances et briefings matin/soir.
10. **Socle commun :** français/anglais, notifications, WhatsApp préparé et non automatique, hors connexion, audit, droits, exports PDF/Excel, sécurité des APK et distribution officielle.

Le cahier initial précède l'architecture actuelle à dix applications. Ses principes métier NAXA SERVICES sont conservés, mais les décisions globales doivent suivre les contrats et décisions Famille plus récents. Les anciens prix Essentiel 1 000 F, Pro 3 000 F et Réseau 6 000 F par mois, les forfaits, la tolérance offline 7/14 jours et les autres éléments [P] ne sont pas des tarifs ni des règles définitivement approuvés.

## 10. Parcours de première connexion — cible fonctionnelle

Ordre recommandé, à construire sans modifier le mécanisme d'identité déjà livré :

1. **Accueil / connexion :** sélection de la langue FR/EN disponible avant la saisie des identifiants ; la préférence est mémorisée localement puis synchronisée avec le profil autorisé.
2. **Première authentification réussie :** si changement de mot de passe temporaire requis, le terminer avant l'initialisation de l'organisation.
3. **Conditions légales :** présenter Conditions générales d'utilisation et Politique de confidentialité dans la langue choisie. Enregistrer version, date serveur, langue et compte ayant accepté ; demander séparément tout consentement facultatif. Ne pas ouvrir les fonctions opérationnelles avant l'acceptation requise.
4. **Choisir votre activité :** afficher une liste déroulante de profils métier, enregistrer l'activité primaire et la version du modèle dans l'organisation. Ne plus redemander à chaque connexion ; autoriser une modification ultérieure réservée au Promoteur, avec confirmation et conservation des données. Ce choix d'activité est indépendant du mode d'organisation solo/multi-emplacements/multi-sites.
5. **Découverte en quatre cartes :** quatre pages illustrées, texte court et bénéfice concret ; défilement horizontal manuel ou automatique toutes les cinq secondes ; boutons Suivant/Précédent/Passer, indicateur de progression ; arrêter l'automatisme dès que l'utilisateur interagit.
6. **Premier accès au tableau de bord :** afficher une visite guidée par surbrillance et assombrissement du reste de l'écran. Cinq étapes maximum ; l'utilisateur touche la zone expliquée pour poursuivre ; bouton Passer toujours visible. Mémoriser l'état terminé pour ne pas réafficher automatiquement ; proposer « Revoir le guide » depuis l'aide.

**Cinq points d'apprentissage recommandés :**
- Tableau de bord et indicateurs essentiels.
- Première opération (selon l'activité : ticket, rendez-vous, ordre de travail ou vente/caisse).
- Stocks, coûts et suivi de la marge.
- Abonnements, sécurité des accès et appareils.
- Assistance Livechat et escalade vers un agent.

Le tutoriel doit s'adapter au rôle : une personne à la caisse ne doit pas recevoir une visite de fonctions réservées au Promoteur. Les animations doivent rester accessibles, interruptibles, traduites et utilisables sur téléphone d'entrée de gamme.

## 11. Profils d'activité compatibles — catalogue à proposer

Le pressing et le salon de coiffure restent les profils initiaux prioritaires. Pour élargir NAXA SERVICES sans transformer l'application en ERP universel incohérent, adopter des **modèles d'activité configurables** qui activent les bons modules et écrans.

### Profils candidats

| Famille | Activités compatibles | Particularités à prévoir |
|---|---|---|
| Entretien textile | Pressing, blanchisserie, lavage/repassage, tapis et ameublement textile | Tickets, pièces, poids, délais, étapes atelier, livraison |
| Beauté et soins non médicaux | Salon de coiffure, barber shop, esthétique, onglerie, spa | Agenda, cabines/fauteuils, prestataires, durée, forfaits, commissions |
| Couture et textile | Couture, retouche, atelier de confection, broderie | Mensurations avec consentement, devis, matières, essayages, étapes de fabrication |
| Réparation | Téléphones, informatique, électronique, électroménager, horlogerie, cordonnerie | Diagnostic, numéro de série, pièces, devis, garantie, ordre de réparation |
| Ateliers et fabrication | Menuiserie, ébénisterie, soudure, métallerie, aluminium/vitrerie | Devis, matières premières, fabrication, étapes, livraison et coûts de chantier |
| Automobile et mobilité | Garage, mécanique moto/auto, lavage et detailing | Véhicule, diagnostic, pièces, temps d'intervention et ordre de service |
| Entretien de locaux | Nettoyage, désinfection, entretien d'immeubles et espaces | Contrats récurrents, équipes, sites clients, interventions et fournitures |
| Services à domicile | Plomberie, électricité, climatisation, jardinage, dépannage | Demande, rendez-vous, déplacement, devis, technicien et preuve d'intervention |
| Impression et création | Imprimerie, photocopie, sérigraphie, graphisme | Fichiers, devis, quantités, validation BAT, consommables et livraison |
| Services événementiels | Photographie, décoration, location de matériel, organisation | Réservation, calendrier des actifs, acompte, contrat, restitution et caution |
| Autre service | Profil générique configurable par le Promoteur | Catalogue, devis, ordre de travail, planning, caisse et clients |

**Recommandation de V1 :** Pressing, Coiffure/Barber, Couture/Retouche, Beauté/Esthétique, Réparation (téléphone/électronique/électroménager), Menuiserie/Atelier, Garage/Lavage auto, Nettoyage, Services à domicile, Impression/Photocopie, puis « Autre activité ». Le choix final de toutes les activités ouvertes au public reste à valider.

Ne pas afficher comme simples variantes d'écran les métiers qui nécessitent un workflow absent. La couture, la menuiserie et la réparation nécessitent notamment devis, ordres de travail, matières/pièces, étapes, coûts et livraison. Les activités médicales, pharmaceutiques ou réglementées ne doivent pas être ajoutées sans cahier spécialisé et validation juridique.

## 12. Tableau de bord, image et expérience visuelle

- Construire un carrousel horizontal de cartes illustrées, changement automatique toutes les cinq secondes, transition fluide et arrêt/pause après interaction.
- Les cartes combinent image d'activité en arrière-plan légèrement floutée, voile contrasté et informations lisibles : chiffre clé, tendance, objectif, alerte ou action à effectuer. Les images ne doivent jamais remplacer les chiffres ni rendre les indicateurs illisibles.
- Adapter les cartes à l'activité choisie : commandes/tickets et délais pour pressing ; réservations, prestations et commissions pour coiffure ; devis, travaux et matières pour les ateliers ; stocks et interventions pour les réparateurs.
- Prévoir les états chargement, absence de données, données locales non synchronisées, données serveur actualisées et erreur de synchronisation. Indiquer l'heure/source des chiffres.
- L'inventaire des ressources du dépôt de la branche a trouvé des visuels génériques de famille/Services sous \`7 famille naxa/Logo\` et \`7 famille naxa/Les logos\`. Le dossier drawable Android de NAXA SERVICES ne contient pour le moment que le monogramme vectoriel. Aucun ensemble de photographies dédiées pressing/coiffure n'a été identifié dans les ressources Android inspectées. Les visuels génériques ne doivent pas être utilisés comme photos de fond sans inspection de leur contenu, résolution et droits ; rechercher/valider une vraie bibliothèque d'images métier avant intégration.

## 13. Profil, paramètres, historique et assistance

Créer un onglet **Profil** distinct du profil de l'organisation, avec au minimum :
- photo/avatar, nom, identifiant d'accès, rôle, organisation et établissement actif ;
- langue, thème, préférences de notifications et paramètres d'accessibilité ;
- sécurité : mot de passe, appareils et sessions, révocation, connexions récentes, récupération, droits visibles et journal des actions accessibles ;
- historique filtrable des opérations permises : ventes, reçus, factures, tickets, rendez-vous, mouvements, connexions et modifications ; ne jamais révéler les opérations d'un site hors périmètre ;
- abonnements et paiements de l'organisation, factures NAXA, renouvellement et état des droits ;
- FAQ, aide, assistance, Livechat et déconnexion avec confirmation.

### Livechat, appel et partage d'écran

Le futur centre d'assistance doit couvrir FAQ/recherche, assistant IA d'aide, création de ticket, transfert vers agent humain, historique, priorité et statut. Les appels audio/vidéo et le partage d'écran sont des fonctions de session assistée :
- démarrage exclusivement à l'initiative de l'utilisateur ou sur invitation acceptée ;
- consentement explicite, indicateur permanent de partage et arrêt immédiat accessible ;
- jetons temporaires, durée/portée limitées, agent autorisé et journal d'accès ;
- partage Android via mécanisme système avec confirmation à chaque session ; aucune capture silencieuse ni contrôle à distance par défaut ;
- enregistrement désactivé par défaut ; toute éventuelle conservation doit être annoncée, justifiée et consentie ;
- choix technique du fournisseur et coûts à arbitrer avant intégration.

## 14. Sécurité — distinguer deux périmètres

Le module **Sécurité de NAXA SERVICES** est le centre de contrôle de l'accès à l'ERP : membres, rôles, permissions, appareils, sessions, révocation, récupération, traces d'accès, alertes, sauvegarde et restauration.

Il ne doit pas être confondu avec **NAXA SECURITY**, application autonome de sécurité vidéo/audio, passerelles et gestion d'équipements. NAXA SERVICES peut ultérieurement afficher un lien vers cette application, mais ne doit pas importer ses workflows de surveillance comme une simple fonctionnalité de profil.

Toute permission métier est vérifiée côté serveur et RLS, pas seulement par masquage des menus Android. Les actions sensibles (annulation, remise, remboursement, changement de prix, clôture, export, restauration, gestion des comptes) exigent une capacité explicite, un motif lorsque pertinent et une trace d'audit.

## 15. Facturation, caisse, crédits et remboursements

Construire un cycle cohérent et auditable, distinct de la simple ligne de vente actuelle :

- Devis → validation du devis → ordre de service → facture/vente → paiement(s) → reçu ; gérer acompte, paiement partiel, paiement mixte, solde restant, échéance et annulation par écriture corrective.
- Documents séparés selon leur nature : devis, proforma si nécessaire, facture, reçu d'encaissement, avoir/annulation et justificatif de remboursement. Numérotation contrôlée par organisation/site et règles comptables validées.
- Moyens de paiement paramétrables : espèces, Orange Money, MTN MoMo et autres moyens activés ; distinguer déclaré, en attente, confirmé, échoué, annulé et remboursé. Un SMS partagé ou une déclaration client ne vaut jamais confirmation automatique.
- Reçus téléchargeables en PDF, partageables via la feuille de partage Android/WhatsApp et imprimables avec imprimante compatible du client. Prévoir QR de vérification opaque, numéro unique, date, site, lignes, taxes, moyen et statut du paiement.
- Compte client : crédit commercial accordé, dette client, acompte, trop-perçu, avoir et remboursement que la PME doit au client doivent être des notions séparées et visibles. Gérer remboursement total/partiel, échéance, approbation, moyen et preuve. Ne jamais confondre un solde créditeur de la PME envers le client avec une somme que le client doit à la PME.
- Une opération validée n'est pas supprimée ou réécrite silencieusement : annulation et correction produisent des écritures liées à l'original, avec auteur, motif et horodatage serveur.
- À la caisse : ouverture avec fonds initial, opérations horodatées, paiements, dépenses, transferts autorisés, clôture, attendu/réel/écart, justification et validation éventuelle du responsable.

Le rapprochement Mobile Money, les règles de confirmation et tout connecteur marchand doivent être prouvés dans un environnement isolé. L'IA ne valide jamais un paiement, un remboursement ou un solde.

## 16. Pilotage, service, équipe et rapports day by day

Le module Pilotage doit dépasser le rapport journalier actuellement indicatif.

- Définir des objectifs par période (jour/semaine/mois), établissement, équipe, collaborateur, activité, prestation et chiffre d'affaires/marge lorsque les données le permettent.
- Afficher réalisé, objectif, écart, pourcentage d'atteinte, rythme nécessaire, jours écoulés et jours restants. Comparer aujourd'hui à hier, même jour semaine précédente, semaine/mois précédent et baseline approuvée.
- Conserver l'historique des objectifs : une modification produit un nouvel état daté, auteur et motif ; ne pas modifier rétroactivement la cible approuvée sans avenant.
- Suivre les horaires d'ouverture, prise de service, pauses, fin de service, retards et temps productif selon les règles et permissions. Une présence doit être corrigible uniquement par une écriture auditée.
- Rapports automatiques matin/soir : tâches, rendez-vous, commandes à livrer, caisse, dépenses, ventes, marges, commissions, stock bas, impayés, remboursements à effectuer, anomalies et échéances.
- Rapports PDF/Excel filtrables par période, activité, site et rôle ; agrégats réseau en lecture et détails limités aux sites autorisés.
- Ne pas appeler « bénéfice » le simple résultat ventes moins dépenses : calculer séparément chiffre d'affaires net, TVA/taxes collectées, coûts directs/consommations, commissions, charges, marge et résultat selon une comptabilité documentée.

## 17. Stocks, achats, comptabilité et fiscalité

Étendre le stock actuel (quantité, seuil, mouvement local) à une vision de gestion complète, par niveau de plan :
- fournisseurs, catalogue d'achats, commandes, réceptions, retours, prix d'achat, lots/dates si utiles, unités de mesure et conversions ;
- consommation de matière/produit par prestation ou ordre de travail, pertes, casse, inventaire et écarts ;
- valorisation du stock, coût unitaire, coût de revient, stock disponible/réservé et transferts autorisés entre sites ;
- seuils, réapprovisionnement, prévision de rupture et historique des coûts.

Le gestionnaire doit pouvoir répondre, à une date et sur un site précis : quantité détenue, quantité réservée, coût d'acquisition/valorisation retenu, valeur consommée, ventes associées, marge calculée et taxes correspondantes.

Le module financier/comptable doit couvrir progressivement plan comptable SYSCOHADA adapté, journaux, écritures équilibrées, grand livre, balance, résultat, trésorerie, clients/fournisseurs, dettes, créances, rapprochement caisse/mobile money, exports et clôture de période. Les écritures validées restent traçables ; les corrections sont compensatoires.

Prévoir une rubrique **Taxes & Impôts** : paramètres par type d'opération, taux et périodes d'effet, base imposable, taxe collectée/déductible selon le cas, échéances, obligations, déclarations préparatoires, justificatifs et historique des paiements. Les taux, régimes, obligations et déclarations applicables au Cameroun doivent être validés par un comptable/fiscaliste sur la réglementation à jour ; aucun taux n'est présumé ici. L'IA n'est pas un conseil fiscal et ne soumet pas de déclaration sans validation humaine.

## 18. Abonnements, paiement et parrainage PME

### 18.1 Contrat d'abonnement

S'inspirer du modèle fonctionnel JOBLY **Plan → Subscription → Payment → Entitlements**, déjà recommandé dans l'audit Famille, mais l'adapter à l'organisation NAXA SERVICES :
- le Promoteur de l'organisation mère est le payeur contractuel du réseau ;
- les établissements enfants et postes sont couverts par les droits de l'organisation selon le plan et les quotas souscrits ;
- les ajouts de sites, utilisateurs, volumes ou capacités sont des extensions tarifaires explicites, pas des abonnements indépendants cachés ;
- les capacités sont vérifiées côté serveur : sites, collaborateurs, postes, fonctions, exports, IA, stockage, sauvegarde et tolérance hors connexion ;
- les plans, prix, promotions et dates d'effet sont versionnés ; l'état de paiement ne donne pas à lui seul les permissions métier.

### 18.2 Échéance et accès limité

La règle cible à détailler et tester :
- tant que l'abonnement est valide, droits selon les entitlements ;
- hors connexion, continuer les opérations locales dans la durée de tolérance du plan, avec avertissements et synchronisation idempotente ; les durées historiques 7 jours Essentiel/Pro et 14 jours Réseau sont [P], à valider ;
- à la reconnexion, le serveur fait autorité. Si la souscription est échue, présenter l'écran Abonnement/Renouvellement et bloquer l'usage métier en ligne ;
- conserver les données locales et les événements en attente ; ne jamais effacer une opération offline non acquittée. Prévoir un processus contrôlé de synchronisation finale/export et accès au paiement, même lorsque l'accès métier est suspendu ;
- continuer les notifications indispensables (rappels déjà planifiés, sécurité et échéance) selon consentements et permissions du téléphone ; leur réception ne réactive jamais l'accès.

Cette proposition concilie le verrouillage demandé avec l'exigence historique de ne perdre aucune donnée après l'échéance. La règle exacte de synchronisation finale après expiration doit être verrouillée avant développement.

### 18.3 Paiement

Prévoir une couche d'adaptation de paiement (Orange Money, MTN MoMo et, si retenu, agrégateur) avec référence unique, montant/devise, organisation, période, statut vérifié, preuve, webhook signé ou validation administrée, idempotence, rapprochement, remboursements et journal. Les états \`initiated\`, \`pending\`, \`success\`, \`failed\`, \`refunded\` sont une base possible, pas une confirmation fournisseur déjà intégrée. Une saisie « J'ai payé » ouvre une demande de rapprochement ; elle ne donne jamais directement un entitlement.

### 18.4 Programme de recommandation de PME

Proposition spécifique à NAXA SERVICES [P], distincte du système de parrainage Partner/KYC/commission de JOBLY :
- chaque organisation reçoit un code ou lien opaque de recommandation ;
- une recommandation n'est attribuée qu'à une nouvelle organisation distincte, avant son premier paiement ;
- le Promoteur gagne un crédit équivalent à un mois de sa formule mensuelle courante lorsque cinq PME recommandées, distinctes et éligibles, ont chacune payé leur première souscription puis effectué une première reconduction payée ;
- le crédit est appliqué à la facture NAXA SERVICES suivante ; il n'est ni encaissable ni transférable en espèces ;
- contrôles anti-auto-parrainage, comptes dupliqués, mêmes moyens de paiement/appareils abusifs, annulations, remboursements et fausses souscriptions ; journal des PME référées et du statut de chaque reconduction.

Restent [O] : récompense unique ou répétable par groupe de cinq, définition exacte de « réabonnée », plan mensuel retenu si le Promoteur change de formule avant attribution, traitement d'un remboursement et durée de validité du crédit. Ne pas coder le calcul définitif avant verrouillage.

## 19. IA NAXA SERVICES — finance, comptabilité et gestion 360°

Ne pas prétendre « entraîner » un modèle financier sur des données non vérifiées. Construire un assistant métier avec outils de calcul déterministes, données autorisées et moteur d'analyse explicable. L'IA peut aider à :

- expliquer ventes, marge, trésorerie, dépenses, créances, dettes et performance par activité/site/prestataire ;
- prévoir ventes, fréquentation, charge de travail, rendez-vous, approvisionnement et ruptures, avec période, hypothèses et niveau de confiance ;
- comparer objectifs/réalisé, détecter anomalies (vente non encaissée, remise atypique, remboursement inhabituel, écart de caisse, consommation anormale) ;
- calculer des scénarios de prix, coûts, capacité, horaires, staffing, trésorerie et seuil de rentabilité ;
- proposer relances clients, achats, objectifs et actions de gestion ; générer briefs matin/soir et réponses vocales/texte FR/EN ;
- expliquer les écritures ou taxes préparatoires et signaler les données manquantes.

Garde-fous obligatoires : cloisonnement par organisation/site/rôle ; source et période affichées ; montants recalculables par le moteur métier ; incertitude explicite ; aucune statistique inventée ; pas d'apprentissage sur les données d'une PME au bénéfice d'une autre ; consentement/minimisation des données ; pas de validation de paiement, écriture comptable définitive, remboursement, transfert, déclaration fiscale ou mutation de stock par l'IA seule. Hors ligne, une aide locale simplifiée peut expliquer des données déjà présentes, sans promettre des prédictions cloud complètes.

## 20. Notifications et sauvegardes

### Notifications

Prévoir notification native et centre interne : opérations, rendez-vous, prêts/retraits, sécurité, appareils, abonnement/échéance, stock, clôture, objectifs, assistance et coaching. Maintenir anti-doublon, préférences, heures calmes, permissions Android 13+, état lu/non lu et actions sécurisées. FCM et la réception effective par appareil ne sont pas encore validés pour NAXA SERVICES ; ne pas promettre une livraison garantie.

### Sessions et sauvegardes

Distinguer deux sujets :
- **Session :** continuer la politique déjà construite « Rester connecté » avec jeton de renouvellement protégé par Android Keystore, révocation et durée maîtrisée. Ne jamais exporter les jetons d'accès/refresh dans une sauvegarde Google, un e-mail ou un fichier lisible.
- **Données métier :** sauvegarder/restaurer base locale, pièces jointes et documents, avec chiffrement, version, intégrité, date, périmètre et journal. Prévoir sauvegarde déclenchée après opérations/synchronisations et calendrier réglable, plus restauration explicitement autorisée et testée.

La demande de sauvegarder « via Gmail » doit être traduite techniquement en connexion Google et stockage Google Drive via autorisation OAuth limitée ; Gmail est une boîte de courrier et ne doit pas servir de coffre de sauvegarde ni recevoir une archive sensible en pièce jointe. Le mode, le compte, la fréquence, la rétention, le chiffrement et le coût éventuel restent à arbitrer. Ne pas inclure de secrets ni de clés de chiffrement dans le dépôt public.

## 21. Réutilisation NAXA / JOBLY — limites à respecter

### Patrimoine NAXA historique à auditer et adapter

- caisse/POS, ouverture/clôture, dépenses, reçus et contrôle de sessions ;
- registres de stock, mouvements, inventaires, achats et coûts ;
- comptabilité SYSCOHADA, journaux, mappings, trésorerie et exports ;
- rapports BI, agrégats par rôle et assistance IA encadrée ;
- notifications Push/centre, messagerie, tickets/support et modèles WhatsApp préparés ;
- profils, périmètres, appareils, sessions, récupération et journal d'audit ;
- fonctions de catalogue, rendez-vous, disponibilité, confirmations et rappels.

Ces actifs doivent être comparés aux règles NAXA SERVICES avant portage. Les schémas et autorisations spécifiques à la pharmacie (\`pharmacies\`, profils pharmacie, partenaires pharmacie, réservations pharmacie, caisse pharmacie, etc.) ne sont pas des tables génériques. Extraire les règles et composants compatibles ; ne pas importer les identités ou transactions pharmacie dans NAXA SERVICES.

Le chantier NAXA SECURITY historique reste un produit distinct, dépendant d'une validation de passerelle, caméra et matériel réels. Le menu sécurité de NAXA SERVICES décrit au §14 est la protection de l'ERP, pas le contrôle vidéo d'un établissement.

### Patterns JOBLY à utiliser après audit

- parcours d'accueil et de découverte visuel, animation des cartes et tutoriel progressif ;
- passerelle IA, contexte/mémoire isolés, recherche documentaire, quotas et mesure d'usage/coût ;
- séparation Plan/Subscription/Payment/Entitlements, états de paiement idempotents et contrôle des droits ;
- assistance FAQ/IA avec transfert humain ;
- notifications catégorisées et préférences.

Ne pas copier les domaines Talent/Recruiter/Partner de JOBLY. Le programme de cinq PME référées au §18.4 est une règle commerciale autonome NAXA SERVICES ; il ne doit pas réutiliser le programme Partner, ses KYC, commissions ou payout.

## 22. Compléments 360° à ne pas oublier

À prévoir dans le backlog métier selon la priorité et le modèle d'activité :
- devis, approbations et ordres de travail pour couture, réparation, menuiserie et services terrain ;
- achats, fournisseurs, comptes fournisseurs et réapprovisionnement ;
- retours, garanties et réclamations clients ;
- suivi des avances, primes, commissions, heures, absences et charges de personnel ;
- gestion de caisse par poste et site, rapprochements Mobile Money et dépôts ;
- gestion de documents, pièces jointes, consentements, QR et liens de partage expirables ;
- fidélité, campagnes, clients inactifs et historique relationnel ;
- inventaire d'équipements/actifs, maintenance et amortissement si le profil d'activité le justifie ;
- contrôle interne : séparation des rôles, double validation des actions sensibles, journal d'audit, alertes antifraude ;
- centre d'exports, restauration, santé de l'application, état réseau/synchronisation et contrôle de version APK ;
- accessibilité, faible consommation de données, mode clair/sombre, FR/EN et aide contextuelle.

## 23. Ordre de réalisation recommandé après cette mise à jour

1. **Jalon A — UX, profil et onboarding :** choix langue, acceptation légale versionnée, activité primaire, quatre cartes, tutoriel cinq étapes, profil, FAQ et dashboard illustré.
2. **Jalon B — fondations serveur :** modèle métier versionné, facturation/abonnements/entitlements, rôles RLS, factures, paiements, crédits, remboursements et journal append-only.
3. **Jalon C — exploitation :** achats/fournisseurs, stock valorisé, caisse/reçus imprimables, facturation, pointage, commissions, rapports et objectifs jour par jour.
4. **Jalon D — fiscalité et pilotage avancé :** comptabilité SYSCOHADA, taxes/impôts validés, indicateurs financiers, prévisions et assistant IA explicable.
5. **Jalon E — expérience assistée et continuité :** Livechat, appel/partage d'écran, push, sauvegardes Drive, restauration, synchronisation hors connexion et règles d'expiration.
6. **Jalon F — profils de métiers étendus :** ajouter Couture, Menuiserie, Réparation, Garage, Nettoyage, Services à domicile et Impression après validation de leurs workflows spécifiques.

Ne pas démarrer une implémentation massive en une seule passe. Pour chaque jalon : audit des composants existants → écarts → contrat de données → implémentation additive → tests Android/Room → tests Deno/API → tests PostgreSQL 17/RLS → preuve CI → mise à jour de continuité.

## 24. Décisions encore ouvertes avant de qualifier le périmètre complet

- Liste exacte des activités ouvertes au lancement et possibilité de plusieurs activités par organisation.
- Tarifs des formules, quotas, extensions de sites/utilisateurs et tolérance offline ; les anciens prix du cahier restent des propositions.
- Fournisseur(s) et circuit de confirmation des paiements Mobile Money ; aucun accès de production ni secret à intégrer sans validation.
- Politique précise de verrouillage après échéance et de synchronisation finale des événements créés hors ligne.
- Mécanique définitive du parrainage de cinq PME et répétabilité des récompenses.
- Taux, régimes, obligations fiscales, modèles de facture et conformité comptable à faire valider.
- Fournisseur de Livechat/voix/partage d'écran et coûts associés.
- Google Drive : consentement, chiffrement, sauvegardes temps réel/programmées, rétention et restauration.
- Domaine, DNS, hébergement du site officiel et URL de téléchargement NAXA SERVICES. **Aucun lien public définitif de l'application n'est confirmé dans le dépôt à ce stade.** Ne pas inventer une URL ; la page officielle de distribution APK devra être publiée seulement après choix du domaine, signature Release et procédure de vérification.
- Ressources photo spécifiques pressing/coiffure : confirmer les images, leurs droits et leur qualité avant intégration.

## 25. Statut après audit élargi

**Statut global : PARTIEL.** La compilation Android debug et les tests de contrat Auth sont prouvés. Les modules locaux existants sont à préserver. L'extension fonctionnelle décrite dans cet addendum est une cible de construction, pas une implémentation réalisée. Les recettes instrumentées, métier, synchronisation, RLS et paiements restent ouvertes. La production reste inchangée.

Aucun merge, aucune migration Supabase réelle, aucun déploiement, aucune publication Release et aucun transfert de données n'est autorisé par ce document.

---

# Addendum 2 — Parfumerie, accueil contextuel et mode nuit animé
**Mise à jour : 20 novembre 2026**

## 26. Nouveau profil d'activité : Parfumerie

Ajouter **Parfumerie** à la liste des activités proposées lors du premier paramétrage de l'organisation, au même niveau que les autres profils métier.

Le profil Parfumerie doit activer un modèle adapté à la vente de parfums et produits associés :
- catalogue de produits avec marque, gamme, référence/SKU, contenance/format, famille olfactive ou catégorie, prix d'achat et prix de vente ;
- gestion des variantes (contenance, format, coffret, recharge, produit individuel) sans dupliquer artificiellement les références ;
- stock par produit/variante, unité, emplacement et point de vente, avec entrées, sorties, inventaires, seuils et alertes ;
- achats et fournisseurs, coûts d'acquisition, remises, retours, pertes et traçabilité des mouvements ;
- ventes au comptoir, panier, facture/reçu, remises autorisées, paiements, avoirs et fidélité ;
- suivi des marges par produit, marque, famille et période ;
- gestion des lots et dates de péremption lorsque le type de produit le nécessite ; traçabilité renforcée pour les produits réglementés ou soumis à des obligations particulières ;
- alertes de stock faible, écarts d'inventaire, produits dormants et risques de rupture.

Ne pas présumer que toutes les parfumeries ont le même assortiment : permettre de désactiver les champs inutiles et de configurer les catégories. Les règles relatives à l'authenticité, à l'importation, à l'étiquetage et aux produits réglementés restent à vérifier selon la gamme vendue.

## 27. Accueil personnalisé selon l'heure

Le tableau de bord doit afficher un message d'accueil contextualisé, suivi du nom d'affichage de l'utilisateur :

- « Bonjour, [nom] » pendant la plage diurne ;
- « Bonsoir, [nom] » pendant la plage du soir et de la nuit.

Règles :
- utiliser l'heure locale du téléphone, avec le fuseau IANA du profil utilisateur/organisation lorsqu'il est défini ; pour le lancement au Cameroun, le fuseau par défaut est Africa/Douala ;
- prévoir une plage configurable et des seuils clairement définis, afin d'éviter les changements incohérents autour de minuit ;
- prendre le nom d'affichage de la session/profil, jamais l'identifiant technique ni le rôle ;
- si le nom est absent, afficher une salutation neutre sans espace réservé ;
- actualiser le message lorsque l'application revient au premier plan et au changement de plage horaire, sans recharger tout le tableau de bord ;
- traduire les salutations en français et en anglais.

La salutation reste un élément d'accueil : elle ne doit pas être annoncée comme une notification système ni déclencher de vibration ou de son.

## 28. Véritable mode nuit global et programmation

Construire un **mode nuit complet à l'échelle de toute l'application**, et non un simple changement de quelques couleurs ou d'un seul écran.

### 28.1 Contrôle utilisateur

Dans Profil / Paramètres / Apparence :
- bouton ou interrupteur immédiatement visible pour activer/désactiver le mode nuit ;
- choix entre mode clair, mode nuit manuel et mode automatique programmé ;
- heure de début d'activation automatique ;
- heure de fin et de désactivation automatique ;
- affichage de la prochaine transition programmée ;
- possibilité de désactiver temporairement le programme et de revenir au réglage manuel ;
- persistance locale immédiate, puis synchronisation de la préférence avec le profil lorsque le réseau et les droits le permettent.

Le comportement doit rester prévisible après fermeture de l'application, redémarrage du téléphone, changement de fuseau horaire et modification des heures. Si l'utilisateur choisit le mode automatique, l'application doit recalculer l'état attendu à chaque reprise et ne pas dépendre uniquement d'un minuteur exécuté en arrière-plan.

### 28.2 Couverture visuelle globale

Le mode nuit doit couvrir de façon cohérente :
- accueil, connexion lorsque le choix est pertinent, onboarding et cartes de découverte ;
- tableau de bord, navigation, menus, listes, formulaires, champs de saisie, claviers intégrés, boîtes de dialogue et menus déroulants ;
- agenda, pressing, coiffure, parfumerie, catalogue, clients, caisse, facturation, stocks, achats, équipe et pilotage ;
- sécurité, abonnements, paiements, taxes, rapports et exports ;
- profil, historique, FAQ, assistance, Livechat, écrans de partage et états vides/erreurs/chargement.

Toutes les surfaces, cartes, arrière-plans, bordures, icônes, graphiques, tableaux, menus, états de sélection, textes et composants doivent utiliser les mêmes tokens de thème. Aucun écran ne doit conserver par erreur un fond clair, un texte sombre illisible ou une couleur d'état non contrastée.

Préserver les couleurs de marque NAXA SERVICES (noir, rouge, blanc et nuances de surfaces) tout en respectant les contrastes. Les couleurs de succès, d'alerte et d'avertissement conservent leur sens et restent accompagnées d'une icône et d'un libellé. Le mode nuit ne doit pas simplement inverser les couleurs.

### 28.3 Animation originale : mini-lampe torche NAXA SERVICES

Créer une animation de **petite lampe torche graphique**, et non reprendre la luciole utilisée dans NAXA.

Direction artistique :
- mini-lampe torche reconnaissable, avec tête lumineuse, lentille et faisceau doux ;
- manche dans une couleur de la charte NAXA SERVICES, principalement le rouge de marque #DD3A33 avec finitions compatibles avec l'interface ;
- dessin élégant, discret et léger, cohérent avec le thème sombre ;
- faisceau lumineux doux, diffus et progressif, qui éclaire une petite zone autour de l'action en cours sans blanchir l'écran.

Comportement interactif :
1. La lampe est un élément visuel de l'interface, pas la lampe physique du téléphone : aucune permission caméra/flash n'est requise et le flash LED du téléphone ne doit jamais être activé.
2. Lorsqu'une personne touche un bouton, sélectionne un champ, valide une action ou interagit avec une zone, la torche se déplace visuellement vers cette zone et oriente son faisceau vers elle.
3. Le faisceau révèle légèrement le composant actif et les textes proches, avec un dégradé doux et un bord diffus ; il ne masque ni le contenu ni les contrôles.
4. Après l'interaction, la lampe peut effectuer un petit mouvement de stabilisation sur place, sans quitter la zone ciblée.
5. Si aucune nouvelle interaction n'a lieu pendant le délai d'inactivité défini, le faisceau s'atténue puis s'éteint ; la lampe reste discrète ou se met en veille.
6. À la prochaine interaction, elle se réactive et accompagne le nouvel emplacement de l'utilisateur.
7. Les animations ne doivent jamais déplacer les composants, modifier les zones cliquables, retarder un paiement, empêcher la saisie ou prendre le focus à la place de l'utilisateur.

### 28.4 Accessibilité, confort et performance

- Prévoir un réglage « Effet lampe torche » activé/désactivé indépendamment du thème nuit.
- Respecter la préférence système « Réduire les animations » et offrir une version statique sans mouvement.
- Limiter les déplacements continus, scintillements et variations rapides de luminosité ; ne produire aucun clignotement.
- Garder le faisceau suffisamment doux pour ne pas provoquer d'éblouissement, de fatigue visuelle ou de perte de contraste.
- Assurer un contraste lisible sur la zone éclairée comme sur les zones non éclairées.
- Ne pas assombrir les informations critiques, les erreurs, les confirmations, les reçus ou les formulaires de paiement au point de les rendre difficiles à lire.
- L'animation doit être optimisée pour les appareils Android d'entrée de gamme : pas de boucle coûteuse lorsque l'écran est immobile, pas de rendu vidéo, consommation GPU/batterie contrôlée et arrêt lorsque l'application passe en arrière-plan.
- Les captures d'écran de partage, les documents PDF et les reçus ne doivent pas intégrer le faisceau animé ; ils utilisent un thème statique lisible.

## 29. Critères de recette additionnels

1. Le profil Parfumerie apparaît dans le sélecteur d'activité et persiste après fermeture, reconnexion et synchronisation.
2. Les écrans Parfumerie permettent de gérer produit, variante, achat, stock, vente, reçu et marge sans affecter les données des autres activités.
3. Le tableau de bord affiche Bonjour/Bonsoir avec le bon nom selon l'heure et le fuseau configuré, en FR et EN.
4. Le bouton Mode nuit agit sur l'ensemble des écrans et composants recensés ; aucune page ne garde un thème incohérent.
5. La programmation active et désactive le mode nuit aux heures choisies, y compris après fermeture forcée et redémarrage du téléphone.
6. Les changements manuels, le mode automatique et le changement de fuseau ont un comportement défini et testé.
7. La mini-lampe utilise le manche rouge NAXA SERVICES, éclaire uniquement autour de la zone d'interaction et s'éteint après inactivité.
8. L'animation n'active jamais le flash matériel et ne demande aucune permission caméra/flash.
9. Les boutons restent immédiatement cliquables ; saisie, navigation, défilement, dialogue, paiement et accessibilité fonctionnent avec la lampe activée ou désactivée.
10. Les appareils configurés pour réduire les animations ou économiser la batterie reçoivent un rendu statique ou allégé.
11. Le mode nuit et la lampe sont vérifiés sur les écrans de connexion, onboarding, dashboard, caisse, facturation, stock, profil, assistance et paramètres, en petit écran et sur émulateur/appareil physique.

**Statut de ces exigences : [P] cible à construire.** Aucun changement Android, aucune animation ni aucun test instrumenté n'est prétendu réalisé par le présent addendum.

---

# Addendum 3 — Passe de construction Android et backlog de clôture
**Mise à jour : 20 novembre 2026**

## 30. Modules Android ajoutés ou raccordés dans cette passe

Les fichiers natifs Kotlin/Jetpack Compose suivants ont été ajoutés ou étendus dans la branche de travail :
- 'NaxaServicesPreferences.kt' : catalogue de 13 activités, cache organisation, préférences de thème, horaires nocturnes, lampe, langue et URI photo utilisateur.
- 'ExperienceScreens.kt' : sélecteur d’activité, acceptation distincte des documents légaux, découverte en quatre cartes, guide de première utilisation et carrousel du tableau de bord.
- 'MiniTorchOverlay.kt' : lampe graphique d’interface avec manche rouge et faisceau radial doux ; aucune permission caméra/flash et aucun accès au flash matériel.
- 'ManagementModules.kt' : facturation locale (devis, factures, avoirs, créances client, remboursements dus au client), PDF, partage de texte, abonnements en demande locale, achats/fournisseurs, brouillons fiscaux, objectifs, analyse locale, ordres de travail, profil/photo, FAQ et demandes de support.
- 'LocalErpStore.kt' : migration Room additive 1→2, registres locaux de gestion et valorisation du stock par coût unitaire/prix de vente, enregistrement des événements dans l'outbox.
- 'MainActivity.kt' : routes d'onboarding, activité par organisation, salutation Bonjour/Bonsoir, navigation adaptée au profil, mode nuit programmé, lampe qui suit les interactions, carrousel et tutoriel de première connexion.
- 'ErpModules.kt' : sélection du profil catalogue en fonction de l'activité, coûts/valorisation des articles, paramètres de notifications et états locaux.
- Les ressources FR/EN ont été étendues et dédoublonnées.

### 30.1 Profils métiers

Le sélecteur comprend : Pressing/Blanchisserie, Coiffure/Barber, Couture/Retouche, Beauté/Esthétique/Onglerie, Parfumerie, Réparation/Électronique, Menuiserie/Atelier, Garage/Lavage auto, Nettoyage/Entretien, Services à domicile, Imprimerie/Photocopie, Photographie/Événementiel et Autre activité.

Le profil choisi est porté par l'organisation. L'Edge Function prévue :
- accepte le choix uniquement du Promoteur disposant du droit de gestion de l'organisation ;
- n'accepte que les identifiants de la liste ;
- ne modifie pas un profil déjà renseigné ;
- journalise le premier choix ;
- renvoie le profil dans la session Auth.

Le mode 'solo', 'single_site_multi_workstation' ou 'multi_site_network' reste indépendant du métier choisi. Les écrans opérationnels restent attachés au site ; la vue Promoteur peut consolider selon les droits. Le rôle limité au poste demeure fermé tant que tous les accès transactionnels ne sont pas filtrés au niveau poste.

**Condition technique impérative :** la migration 'supabase/drafts/naxa_services_v2_activity_onboarding_management.sql' ajoute le champ et les contraintes nécessaires, mais reste un draft. L'API qui l'utilise ne sera pleinement fonctionnelle qu'après validation et application de cette migration sur un projet Supabase de recette isolé. Aucune migration n'a été appliquée.

### 30.2 Parcours et apparence

- Langue FR/EN proposée sur l'écran de connexion et préférence individualisée.
- Acceptation séparée des CGU et de la politique, par version, compte et horodatage côté serveur.
- Quatre cartes de découverte avec rotation de cinq secondes, navigation et passage.
- Guide première connexion en cinq étapes, skippable et mémorisé côté serveur.
- Salutation contextuelle selon l'heure et le nom d'affichage.
- Mode sombre par défaut, thème clair optionnel et mode programmé avec deux heures réglables.
- Mini-lampe d'interface rouge NAXA avec halo doux, extinction après inactivité et option de désactivation.
- Carrousel de tableau de bord qui charge les images du profil actif depuis 'assets/naxa-services/activities/<activité>/'.

Le guide actuel est un tutoriel visuel guidé en panneau assombri ; il ne réalise pas encore un cut-out/spotlight individualisé ancré sur cinq boutons réels. Cette amélioration reste à faire si l'on maintient le niveau d'exigence d'animation initial.

### 30.3 Images de chaque activité

Les dossiers sont préparés dans 'assets/naxa-services/activities/' avec un README par profil. Chaque dossier peut recevoir 6 à 10 images autorisées. Le Gradle Android embarque ce répertoire comme source d'assets, et le carrousel recherche automatiquement les fichiers WebP/JPG/JPEG/PNG dans le dossier de l'activité sélectionnée. Tant que les photos ne sont pas ajoutées, il utilise le rendu de repli avec icône et surface.

### 30.4 Finance, stock et équipe

- Facturation locale : devis, factures, avoirs, créances à recevoir du client et remboursements que la PME doit au client sont des types différents.
- Un document PDF peut être enregistré via le sélecteur Android ; le partage actuel transmet un récapitulatif texte. Le PDF n'est pas encore joint au message WhatsApp.
- Achats/fournisseurs, ordres de travail, brouillons de fiscalité et objectifs sont ajoutés comme registres locaux.
- Les stocks existants sont complétés par un coût unitaire et un prix de vente ; la marge brute unitaire est calculable.
- Les registres d'équipe prévoient prise/fin de service, pauses, commissions, avances et primes ; ils restent locaux et doivent encore recevoir le workflow de validation RH/paie complet.
- Les abonnements affichent les trois offres candidates, stockent une demande locale et précisent qu'aucun droit n'est activé par une saisie de référence.

### 30.5 Notifications et assistance

- Android déclare POST_NOTIFICATIONS et l'interface Paramètres peut demander la permission Android 13+.
- Des briefings locaux sont programmés à 07:00 et 19:00 par les composants WorkManager de la fondation NAXA.
- Les notifications FCM distantes, le centre serveur persistant et la gestion complète des jetons/appareils restent à raccorder et tester.
- Le Livechat livré est encore un espace FAQ + demande de support locale. Il n'y a pas encore de service conversationnel temps réel, d'appel audio/vidéo ni de partage d'écran. Ces fonctions exigent un fournisseur/session média, une signalisation, un consentement explicite et des jetons de courte durée.

## 31. Résultats et limites à ne pas confondre

### Construit dans le client Android
- Parcours d'accueil, sélection du profil, langues, thème programmé, lampe, tutoriel, carrousel photo.
- Écrans de gestion locale : facturation préparatoire, achats, fiscalité préparatoire, objectifs, ordres de travail, stock valorisé, équipe et profil.
- Reçus PDF exportables et partage récapitulatif texte.

### Non encore démontré / non livré côté serveur ou environnement réel
- La migration SQL v2 n'est pas appliquée ; les contrats légaux, profil activité et journal de consentement doivent être testés en Supabase isolé.
- Les nouveaux registres d'activité sont insérés dans Room et l'outbox, mais aucun transport générique de synchronisation vers les tables serveur, accusé durable, reprise idempotente et résolution de conflits n'est encore prouvé.
- Le paiement Mobile Money, les webhooks vérifiés, le rapprochement, les remboursements réels, les entitlements et le verrouillage à l'échéance ne sont pas encore intégrés.
- Les données locales de ventes/achats/taxes/objectifs ne constituent pas encore une comptabilité SYSCOHADA complète : journaux, grand livre, balance, états financiers, rapprochements et clôture restent à construire et tester.
- Les taux d'impôts et règles camerounaises ne sont pas préchargés comme obligations officielles. Le module actuel ne fait que préparer des estimations saisies par l'utilisateur ; un comptable doit valider le régime et les taux.
- L'analyse IA actuelle est une synthèse déterministe sur les données locales, pas un modèle entraîné ni un moteur de prédiction de vente validé.
- Les sauvegardes automatiques chiffrées Google Drive/restaurations ne sont pas encore implémentées. La protection de session Keystore reste distincte des archives métier.
- La photo de profil est conservée comme URI locale ; aucun service serveur d'avatar n'est encore branché.
- Les photos métier ne sont pas encore dans le repo ; les dossiers sont prêts.
- Les tests sur émulateur/appareils physiques, la migration Room depuis une version installée, la recette multi-sites/RLS et la recette Supabase restent à faire.
- Le contrôle CI le plus récent est le run [44745166818](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44745166818), résultat global `success`, sur le commit `5acd99136a72ba310052532e74e6049992175347`. Auth/Deno, vérification des 13 dossiers photos et des quatre documents légaux, compilation Kotlin/Compose/Room/KAPT et assemblage APK debug ont réussi. Artifact `naxa-services-debug-apk`, ID `14632951831`. APK extrait : 12 101 973 octets, SHA-256 `e2303edfb2801f7bd818ff152d4753efc95f7a9894ea5432870685851da1365e`. Le ZIP de l'artifact a été testé sans erreur ; le binaire reste un APK debug, non signé Release.

## 32. Décision de statut

**Porte de compilation Android debug : VERT** sur le commit `5acd99136a72ba310052532e74e6049992175347` (run 44745166818). **Statut fonctionnel global : PARTIEL / EN RECETTE.** La version ne sera pas « verte production » avant la migration et la recette RLS isolée, le transport de synchronisation idempotent, la validation des flux de paiement/abonnement, les essais sur appareil et la recette métier des trois modèles organisationnels.

Aucun merge, aucune migration Supabase réelle, aucun déploiement Edge Function, aucune publication Release et aucune mise en production ne sont couverts par cette passe documentaire.

## 33. Vérifications supplémentaires de reprise — 20 novembre 2026

- Le parcours de sélection d'activité ne donne plus le choix à un salarié lorsque l'organisation n'a pas encore de profil : un message l'oriente vers le Promoteur et lui laisse une sortie par déconnexion.
- Les routes d'écran sont désormais contrôlées par l'intersection du rôle et du profil métier, y compris en accès direct ; masquer une entrée de menu ne constitue plus l'unique protection d'interface.
- La lecture des CGU et de la politique utilise le contenu intégral bilingue embarqué dans les assets Android. L'acceptation reste distincte et versionnée. La validation contractuelle finale doit encore être faite par un juriste camerounais.
- L'Edge Function Auth possède un chemin de compatibilité de lecture avant l'application de la migration v2 ; les actions de sélection d'activité et d'acceptation nécessitent toujours la migration sur l'environnement de recette.
- Le workflow CI vérifie maintenant la présence des 13 dossiers photos et des quatre fichiers légaux avant Gradle.
- L'artifact CI 14630957608 a été téléchargé et inspecté : l'archive contient le fichier naxa-services-debug.apk (12 052 148 octets). Son SHA-256 calculé après extraction est c230f15227604169a48774220ff804ae951dc59590f67519e57370edc8fc71a4.

Ces vérifications ne remplacent pas l'installation sur un téléphone, l'essai des parcours par rôle, la migration sur Supabase isolé, les tests RLS et les essais de restauration/synchronisation hors connexion.

## 34. Clôture de la passe de construction et audit de cohérence — 20 novembre 2026

### 34.1 Dernier état Git et preuve CI

- Branche de travail : `work/naxa-services-completion-20261120`.
- Commit applicatif testé : `5acd99136a72ba310052532e74e6049992175347`.
- Run CI : [44745166818](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44745166818), conclusion `success`.
- Job Auth/Deno : réussi (type-check + tests contractuels).
- Job Android : réussi (contrôle des assets, SDK, Gradle, Kotlin/Compose, Room/KAPT, assembleDebug, upload artifact).
- Artifact : `naxa-services-debug-apk`, ID `14632951831`.
- APK extrait : `naxa-services-debug.apk`, 12 101 973 octets.
- SHA-256 : `e2303edfb2801f7bd818ff152d4753efc95f7a9894ea5432870685851da1365e`.
- Archive ZIP testée : aucune erreur d'intégrité.
- `main` est restée au commit de référence `439fa4186b602c45e9958cc264c42b0c9ee6fbb4`. Aucun merge.
- Aucune migration Supabase réelle, aucun déploiement Edge Function, aucune Release signée et aucune mise en production.

### 34.2 Fonctionnalités Android confirmées dans le dernier build

- Tableau de bord : sélecteur parmi les sites autorisés ; ventes locales du jour, dépenses saisies, flux simplifié, rendez-vous ou tickets pressing selon l'activité, articles sous seuil et opérations locales en attente. Les chiffres portent une mention explicite locale/non synchronisée et ne prétendent pas être une consolidation réseau.
- Stock : coût total estimatif, valeur de vente théorique, marge brute potentielle et nombre d'articles non valorisés, calculés par site sur les coûts/prix saisis. L'estimation exclut notamment taxes, pertes, frais indirects et opérations non synchronisées.
- Assistance : les demandes affichées dans Livechat sont maintenant filtrées par organisation **et par site sélectionné** ; un utilisateur sans site autorisé ne peut pas créer une demande.
- Caisse : après encaissement, ouverture du reçu PDF avec enregistrement, partage de fichier PDF via le sélecteur Android (WhatsApp inclus si installé) et impression Android. Les paiements Mobile Money en attente sont indiqués comme non confirmés.
- Facturation : créances clients distinctes des remboursements dus par la PME.
- Notifications locales : briefings matin/soir avec identifiants de travail et de notification distincts, évitant le remplacement mutuel des deux horaires.
- Dossiers et assets légaux : le workflow CI vérifie les 13 dossiers d'activité et les quatre documents légaux FR/EN embarqués.

### 34.3 Audit de cohérence avec les Prompts 0.1 à 0.6

| Référence | État réel de NAXA SERVICES après cette passe | Réserve de sortie |
|---|---|---|
| Prompt 0.1 — cadrage/stack | Projet Android natif compilé avec AGP 8.6.1, KGP 2.0.20, Gradle 8.7, compile/target SDK 35, Compose BOM 2024.10.01, Room 2.6.1. | Le document de référence Prompt 0.1 décrit une baseline plus récente (AGP 9.3.1, Gradle 9.5.0, KGP 2.4.21, SDK 37, Compose BOM 2026.09.00, Room 2.8.5, WorkManager 2.12.0). Écart confirmé ; aucune mise à niveau transversale n'a été tentée, afin de ne pas créer une régression sur les dix applications. Un chantier de modernisation contrôlé est requis. |
| Prompt 0.2 — schéma commun | Modèle métier NAXA Services et migration v2 préparatoire présents. | Le Prompt 0.2 clôt le cadrage, pas une autorisation de migration. La migration Services reste un draft dédié ; aucun DDL n'a été exécuté sur Replay ou Production. |
| Prompt 0.3 — RLS | Auth renvoie les sites actifs et l'interface filtre rôle + activité ; le rôle limité au poste reste fermé pour les opérations. | Les nouveaux modules métier n'ont pas encore de transport serveur/RPC et de policies RLS testés. L'isolation ne peut pas être certifiée par le seul filtrage Compose. Recette PostgreSQL/Supabase isolée nécessaire. |
| Prompt 0.4 — comptes administrés | Écran Auth, mot de passe temporaire, récupération administrée, provisioning/scopes et révocation sont présents dans les contrats/Edge Function source. | Alias GoTrue interne non prouvé avec le projet réel ; provisioning, récupération, rotation/révocation d'appareil et comportements de sessions doivent être testés sur environnement isolé. Edge Function non déployée. |
| Prompt 0.5 — offline/synchronisation | Room, registres locaux et outbox persistante sont en place ; les écrans continuent à créer des opérations locales. | Le moteur complet reste NON LIVRÉ : enveloppe d'événement encore incomplète (acteur/appareil/version de schéma/hash/attempts/ack), pas de worker de synchronisation métier idempotent prouvé, pas d'accusé durable par événement, pas de résolution de conflits par domaine. Les durées offline par entitlement ne sont pas appliquées. |
| Prompt 0.6 — notifications | Cinq canaux Android définis, permission POST_NOTIFICATIONS, briefings locaux matin/soir indépendants. | FCM, gestion des jetons, centre de notification persistant serveur, états livré/lu, actions idempotentes, préférences/heures calmes et tests Android réels ne sont pas terminés. |

### 34.4 Réserves fonctionnelles 360° restantes

1. **Abonnement et paiement** : les plans sont affichés et la demande de souscription est locale. Aucun agrément Mobile Money, webhook signé, rapprochement automatique, entitlements serveur, période de grâce ni blocage de l'application à l'échéance n'est encore prouvé. La règle demandée (« rappels autorisés, mais accès métier verrouillé après expiration ») reste à implémenter au niveau serveur et client.
2. **Parrainage de PME** : la récompense d'une formule mensuelle après cinq PME réellement abonnées et renouvelées n'est pas implémentée. Elle doit être calculée côté serveur sur des abonnements payés et non annulés, avec anti-auto-parrainage, unicité et audit.
3. **Comptabilité** : les registres de gestion, les flux de caisse, les dépenses, les créances et les estimations ne constituent pas un grand livre SYSCOHADA complet. Journaux, comptes, grand livre, balance, rapprochements, immobilisations, amortissements, clôture et états doivent être construits et validés par un expert-comptable.
4. **Fiscalité** : le module n'intègre pas de régime camerounais ni de taux officiels préchargés et validés. Il permet de préparer des estimations saisies par l'utilisateur ; aucune déclaration officielle n'est transmise.
5. **IA** : l'assistant est une synthèse déterministe sur les données locales disponibles. Il n'est ni entraîné sur une base comptable certifiée, ni connecté à un moteur prédictif de ventes validé. Les prévisions, scénarios, anomalies et explications de marges restent un chantier distinct avec provenance et validation humaine.
6. **Livechat média** : la FAQ et les demandes locales existent ; conversation temps réel, audio/vidéo, partage d'écran, consentement de session, signalisation et support agent restent à construire.
7. **Sauvegardes** : le Keystore conserve un jeton de session si « rester connecté » est choisi. Cela ne constitue pas une sauvegarde métier. Sauvegarde chiffrée, compte Google/Drive facultatif, planification, restauration contrôlée et vérification d'intégrité restent à faire.
8. **Images de métier** : les 13 dossiers sont prêts, mais le dépôt ne contient pas encore de photos pressing/coiffure/parfumerie/atelier exploitables comme fonds. L'inventaire de l'arbre Git trouvé pendant l'audit ne contenait que des logos de marques. Les cartes gardent un fallback sans images ; les 6 à 10 photos par activité restent à ajouter.
9. **Tutoriel spotlight** : le tutoriel de cinq étapes est skippable et mémorisé, mais il utilise encore un panneau assombri explicatif ; il ne découpe pas réellement l'écran autour de cinq contrôles UI successifs.
10. **Profil** : la photo est actuellement conservée comme URI locale sur l'appareil ; aucun stockage serveur/avatar synchronisé n'est branché.
11. **Réconciliation multi-sites** : chaque site conserve ses registres locaux. La sélection d'un site et les KPI locaux sont présents ; la consolidation réseau complète en lecture seule, les comparaisons temporelles et les transferts inter-sites explicites attendent le backend/RLS.
12. **Release et distribution** : l'APK archivé est une build debug, pas une Release signée. Aucun lien public d'application ou domaine Web NAXA Services n'est provisionné par cette passe. L'application Android a un identifiant de paquet ; un domaine public ne doit pas être inventé ou présenté comme actif.

### 34.5 Décision finale de la passe

- **Construction Android debug : VERT**, preuve CI 44745166818 et artifact 14632951831.
- **Auth/Deno contractuel : VERT**, pour les tests de contrat actuellement présents, pas pour l'intégration réelle à Supabase.
- **Parcours et modules locaux : CONSTRUITS À UN NIVEAU DE RECETTE**, avec les réserves listées en 34.4.
- **Backend/RLS/synchronisation/paiement/entitlements : NON VALIDÉS**.
- **Recette sur appareils réels et Release signée : NON EXÉCUTÉES**.
- **Production : inchangée**.

La suite logique est la recette fonctionnelle Android sur émulateur/appareils, puis l'application de la migration draft et les tests Auth/RLS sur un projet Supabase isolé. Les tests de synchronisation offline et de paiements doivent être validés avant de qualifier l'ERP de complet.

---

## 35. Mise à jour de continuité — 20 novembre 2026 (CRM, géolocalisation, Fulfulde et import stock)

Cette section complète les constats de la section 34. Elle décrit les changements effectivement ajoutés à la branche de travail après le point de reprise initial. Elle ne remplace pas les réserves de production de la section 34.

### 35.1 Baseline documentaire et commerciale

Le référentiel `docs/CONTINUITE.md` a été complété avec les sections 6.17.14 à 6.17.16 :
- tarifs mensuels de lancement et cibles à maturité des dix applications ;
- tarifs COTIZ dégressifs, LOYABLE progressif, nouveaux paliers GRILLAD ;
- nouveau modèle CAMPUS237 établissement payant + Parent Essentiel gratuit + Individuel+ 500 F + Famille 1 500 F ;
- règle annuelle de dix mensualités payées pour douze mois de service ;
- périmètre de pilotage central NAXA FAMILY, CSO, moteur d'abonnement et passerelle IA isolée ;
- périmètre de finalisation NAXA SERVICES.

Ces arbitrages sont des décisions commerciales documentées. Leur enregistrement ne signifie pas que le moteur de facturation ou les intégrations de toutes les applications sont déjà opérationnels.

### 35.2 Fulfulde — préférence de langue

La locale `ff-CM` est désormais acceptée dans les préférences locales et exposée dans les sélecteurs de langue de l'application, de la connexion et des paramètres d'organisation. Le contrat Auth Deno accepte désormais `fr`, `en` et `ff-CM`, et le handler de mise à jour du profil organisation utilise ce contrat.

La migration SQL draft autorise `ff-CM` dans `ns_members.preferred_locale`, mais **aucune migration Supabase n'a été exécutée**. Les textes juridiques restent acceptés en français ou anglais tant que leurs traductions Fulfulde n'ont pas été traduites et validées humainement. Les écrans non traduits utilisent provisoirement le français. Il ne faut donc pas déclarer l'application intégralement traduite en Fulfulde.

### 35.3 CRM client, routines de relance et localisation domicile

Room est passé de la version 2 à la version 3 avec une migration additive 2→3 enregistrée dans le builder Android. Les anciennes fiches clients sont conservées ; les champs suivants sont ajoutés : adresse, quartier, repère, latitude, longitude, précision, date de capture et date de consentement de géolocalisation.

L'écran Clients expose :
- création d'une fiche avec adresse de service/livraison, quartier et repère ;
- consentement de contact séparé du consentement de localisation ;
- demande de permissions Android de localisation au moment de l'action ;
- proposition d'une dernière position connue, uniquement si elle date de moins de quinze minutes, avec vérification par l'opérateur avant enregistrement ;
- saisie manuelle d'adresse lorsque le client refuse le GPS ou qu'aucune position récente n'est disponible ;
- sélection d'un client puis création d'une routine hebdomadaire ou mensuelle ;
- choix du canal (sur place, téléphone, WhatsApp), sous réserve du consentement pour les contacts à distance ;
- date de prochaine échéance, clôture d'une relance, recalcul de la prochaine occurrence et journal d'événements.

**Limite actuelle :** le CRM et les routines sont persistés dans Room et produisent des événements dans l'outbox locale. Il n'y a pas encore de planificateur serveur, de notifications FCM, d'envoi SMS/WhatsApp automatique, ni de synchronisation serveur/RLS vérifiée. La géolocalisation est une capture ponctuelle facultative ; aucun suivi continu n'est implémenté. L'édition d'une fiche existante et la révocation serveur du consentement devront être couvertes par les prochaines passes.

### 35.4 Import de stocks — template et import CSV

L'écran Stocks possède désormais les actions « Télécharger le template » et « Importer le fichier des stocks ». Le template CSV UTF-8 est configurable pour inclure ou non le seuil d'alerte, le coût d'achat et le prix de vente ; SKU, désignation, unité et quantité initiale restent obligatoires.

Le parcours d'import :
- reconnaît les en-têtes canoniques et plusieurs alias français/anglais ;
- accepte les champs entre guillemets, le BOM UTF-8 et, dans le dernier commit, la détection du séparateur virgule ou point-virgule ;
- limite le fichier à 20 Mo et le lot à 5 000 lignes ;
- valide les champs, les quantités et les montants ; bloque les SKU répétés dans un même fichier ;
- présente un aperçu et compte les SKU déjà présents ;
- bloque la confirmation d'un doublon tant que l'opérateur n'a pas activé explicitement « Mettre à jour les articles existants » ;
- applique le lot dans une transaction Room ; une erreur annule l'ensemble du lot ;
- crée des mouvements de stock initiaux ou des mouvements d'ajustement traçables et met à jour la valorisation lorsque les coûts/prix sont fournis.

**Limites actuelles :** seul le format CSV est pris en charge ; XLS/XLSX, correspondance manuelle de colonnes arbitraires, export d'un rapport détaillé d'erreurs, API d'import serveur, RLS et synchronisation distante restent à développer/tester. L'import actuel agit sur le stockage local de l'application et son outbox, pas sur une base serveur validée.

### 35.5 Preuves CI — builds confirmés

**Dernier build entièrement vérifié :**
- Workflow `44770034786` — terminé avec succès sur le commit de code `2dc2a85cd99828b9ab38389c6a5f646dea0f4cee`.
- Job Android : compilation et assemblage debug réussis ; artefact `naxa-services-debug-apk` archivé sous l'ID `14647006494` (11 335 054 octets ; SHA-256 `5347fa2e7f58c7501c1d2e25747917487e28734645e74ba77e449def7cd285dd`).
- Job Auth scope/business mode : succès.
- Le build précédent `44769339200` / commit `96bb9b2` avait également réussi avec l'artefact `14646801027`.

**Dernier commit de code validé :**
- `2dc2a85cd99828b9ab38389c6a5f646dea0f4cee`, incluant la détection CSV virgule/point-virgule et la limite de taille.
- Workflow `44770034786` : les deux jobs Android et Auth sont terminés avec succès. L'artefact `14647006494` correspond bien à ce commit.

**Aucune recette sur appareil physique, validation Supabase/RLS, synchronisation serveur, Release Android signée, déploiement ou mise en production n'est déclarée réalisée par ces builds.**

### 35.6 Chantiers restant à traiter ou non intégrés

1. CRM serveur : API, persistance distante, règles RLS, synchronisation offline, planificateur de relance, notifications, historique consolidé, préférences et désabonnement.
2. Géolocalisation : édition et révocation de la localisation d'un client, synchronisation sécurisée, affichage carte/itinéraire dans le parcours d'intervention, contrôles RLS et recette réelle des permissions.
3. Stocks : mapping manuel, XLS/XLSX éventuel, rapport d'erreurs téléchargeable, synchronisation serveur, contrôles d'idempotence et tests de volumes.
4. Paiement/abonnement : le catalogue commercial est documenté, mais les paiements réels, webhooks, entitlements et droits côté serveur ne sont pas validés.
5. Pilotage central NAXA FAMILY, comptes Customer Service Officer mutualisés et passerelle de services IA : architecture spécifiée dans CONTINUITE, mais intégration avec NAXA autonome non exécutée.
6. Sécurité applicative NAXA SERVICES et intégration fonctionnelle NAXA SECURITY : restent deux chantiers distincts ; les capacités vidéo/audio/alertes/IA de NAXA SECURITY ne sont pas intégrées par le lot présent.
7. API métier ERP, RLS, outbox/synchronisation, SYSCOHADA, fiscalité camerounaise, RH/paie, multi-sites consolidés, notifications FCM, sauvegarde Drive, appels/partage écran, tests instrumentés et appareils physiques, Release Android et Web/PWA restent ouverts selon la section 34.

### 35.7 Point de reprise technique courant

- Branche : `work/naxa-services-completion-20261120`.
- Dernier commit de code Android validé : `2dc2a85cd99828b9ab38389c6a5f646dea0f4cee`.
- Workflow `44770034786` : terminé avec succès ; jobs Android debug et Auth Deno verts ; artefact `14647006494`.
- Des commits documentaires ont ensuite synchronisé le rapport et `docs/CONTINUITE.md` sur la branche. Pour reprendre, lire le HEAD actuel de cette branche ; le dernier code Android vérifié demeure `2dc2a85`.
- Préserver les acquis et continuer par lots testés ; ne pas fusionner automatiquement la branche et ne pas toucher au projet NAXA autonome.

---

## 36. Finalisation fonctionnelle avancée — NAXA SERVICES (20 novembre 2026)

Cette section complète le lot 35. Elle atteste les changements réellement présents dans le code Android natif Kotlin/Jetpack Compose et dans le moteur commun de tarification. Elle ne vaut ni recette métier exhaustive sur appareils, ni mise en production.

### 36.1 Bascule des tarifs des dix applications — date et règles exécutables

- Date d'effet de maturité programmée : **1er mai 2027 à 00:00, heure du Cameroun** (`Africa/Douala`). Le délai de cinq mois à compter du 1er décembre 2026 est donc matérialisé par la date locale du 1er mai 2027.
- `packages/billing-core` expose désormais un manifeste explicite `NAXA_FAMILY_MATURITY_SCHEDULE` pour KIOSKO, BOOTIK, ZIPPLE, NAXA SERVICES, COTIZ, LOYABLE, NAXA HOTEL, NAXA SECURITY, GRILLAD et CAMPUS237.
- La résolution de prix utilise le début de chaque nouvelle période de service / renouvellement. Une période déjà payée n'est pas repricée rétroactivement. Une nouvelle souscription ou un renouvellement dont la période commence le 1er mai 2027 ou après utilise le catalogue maturité.
- Le calcul de date passe par `Africa/Douala`, et les tests vérifient la frontière à 23:00 UTC le 30 avril (minuit à Douala le 1er mai).
- NAXA SECURITY prend en compte +20 % par extension de capacité, avec validation du nombre d'extensions.
- CAMPUS237 dispose des durées de trial distinctes : 30 jours école, parent essentiel gratuit sans trial, autres packs parent payants 72 heures ; les autres applications gardent 72 heures.
- Les règles tarifaires existantes restent inchangées : 10 mensualités payées pour 12 mois de service lorsque l'annuel est applicable.

**Limite importante :** le moteur détermine le catalogue et calcule le montant attendu ; il ne prélève pas automatiquement un paiement réel. Les récurrences, webhooks prestataires, anti-doublon serveur et activation d'entitlements doivent encore être intégrés au service de cycle de vie serveur avant prélèvement. Aucun paiement automatique n'est déclenché par le seul passage de la date.

### 36.2 Stock, caisse et ventes liées au catalogue

- Une vente peut être libre (prestation) ou reliée à un article du stock.
- Pour un article lié, le formulaire récupère le prix de vente configuré, saisit la quantité et calcule le total.
- Vente espèces : confirmation locale, décrémentation de stock et mouvement de sortie dans la même transaction.
- Mobile Money : la quantité est réservée dans les ventes en attente ; aucun décrément réel avant confirmation serveur.
- Annulation d'une vente Mobile Money encore en attente : motif obligatoire, statut annulé, historique et libération de la réservation.
- Confirmation Mobile Money : méthode dédiée réservée à l'adaptateur serveur après vérification du webhook ; la vente déjà non pending ne peut pas être confirmée une seconde fois. La référence prestataire est conservée dans l'événement d'audit.
- Room version actuelle : **7** ; chaîne de migrations enregistrée dans le builder : `NS_SERVICES_MIGRATION_1_2, NS_SERVICES_MIGRATION_2_3, NS_SERVICES_MIGRATION_3_4, NS_SERVICES_MIGRATION_4_5, NS_SERVICES_MIGRATION_5_6, NS_SERVICES_MIGRATION_6_7`.

**Limite :** l'adaptateur réel de paiement Mobile Money, ses webhooks et le synchroniseur hors connexion ne sont pas encore branchés. Le code prépare le contrat et les règles locales ; il ne prétend pas qu'une confirmation de paiement fournisseur fonctionne déjà en production.

### 36.3 Transferts inter-sites audités

- Le Promoteur peut créer une demande entre deux points de vente actifs de sa propre organisation.
- La demande vérifie l'existence des deux sites, de l'article source et de la quantité disponible.
- Demande `open` puis approbation `approved` ne changent aucun stock.
- Réception `received` : dans une transaction unique, contrôle à nouveau la quantité source et l'unicité du SKU destination ; décrémente le stock source, crée ou incrémente l'article destination et enregistre deux mouvements liés (`transfer_out` / `transfer_in`).
- Une réception avec stock source insuffisant ou SKU ambigu au site destination est refusée sans mouvement partiel.
- Les transitions sont historisées avec auteur et motif ; l'interface native présente le site source, destination, article, quantité, statut et historique.

**Limite :** le transfert actuel est dans Room/outbox locale. Le contrôle concurrent entre appareils et le commit serveur transactionnel devront être validés via API/RLS avant de le traiter comme opération réseau multi-appareils.

### 36.4 Pointage, équipes et rémunération variable

- Le pointage suit une machine d'état par collaborateur et site : prise de service → pause → reprise → sortie.
- Double prise de service, fin de pause sans pause ouverte et sortie sans service actif sont refusées.
- Chaque événement horodaté est inscrit dans le journal local, l'outbox et l'historique de workflow ; il peut être lié à un poste.
- L'écran Android permet prise de service, début/fin de pause et sortie, puis consultation des événements récents.
- Commissions, avances et primes restent des mouvements distincts en attente de validation, avec approbation ou rejet accompagné d'un motif obligatoire.

**Limite :** l'identité RH doit encore être raccordée à un identifiant de membre serveur stable ; le nom/identifiant saisi localement ne remplace pas l'authentification RH. Les horaires, contrats, paie et cotisations sociales ne sont pas un moteur de paie réglementaire complet.

### 36.5 CRM — modification et retrait du consentement GPS

- Les fiches clients peuvent être modifiées sans créer de doublon.
- Adresse, quartier, repère, téléphone, notes privées et consentement de contact sont éditables.
- Si le consentement de localisation est retiré, latitude, longitude, précision, date de capture et date de consentement sont effacées localement.
- Si la position reste autorisée et inchangée, les métadonnées de capture existantes sont conservées ; une nouvelle position enregistre une nouvelle date.
- Les routines hebdomadaires et mensuelles conservent prochaine échéance et historique.

### 36.6 Modèle de déploiement fonctionnel et limites restantes

L'application Android demeure native Kotlin/Jetpack Compose. Les données métier ajoutées dans cette étape sont persistées dans Room et alimentent l'outbox. La finalité 360 exige encore :
- API métier serveur, synchroniseur outbox, idempotence, reprises, conflits, accusés de réception et tests de rejeu.
- RLS et isolation réelle par application, organisation, site, poste et rôle.
- Notifications FCM, SMS/WhatsApp, planificateur serveur pour les relances CRM et le linge prêt.
- Paiements serveur, webhooks, abonnements et entitlements réels.
- Recette instrumentée et appareils physiques, performance, non-régression et restauration.
- SYSCOHADA complet validé par expert-comptable et fiscalité camerounaise validée par professionnel.
- Release Android signée et distribution.
- Intégrations centrales documentées mais non codées : dashboard « Gérer NAXA FAMILY » dans NAXA, CSO réellement mutualisés, passerelle IA versionnée vers NAXA et fonctionnalités NAXA SECURITY vidéo/audio/alertes.
- Web/PWA distincte à réaliser sur contrats API et règles métier partagés.

### 36.7 Preuve de validation à la date de la présente mise à jour

- Dernier workflow constaté : `44780431451`, commit testé `fb4a464f4595d90b2d7523b50eb95b927a407273`, statut `completed` / conclusion `failure`.
- Jobs : NAXA FAMILY launch and maturity tariff tests=completed/success; Assemble NAXA SERVICES Android debug APK=completed/failure; Auth scope and business-mode contract tests=completed/success.
- Artefacts : aucun artefact publié pour ce workflow.

**État du gate : EN ATTENTE / NON VERT** pour ce dernier état. Ne pas transférer un succès d'un ancien SHA au code courant.

---

## 37. Clôture vérifiée après transferts inter-sites et audit tarifaire — 20 novembre 2026

Cette section remplace le statut « en attente / non vert » de la section 36.7 pour le dernier état de la branche. Elle conserve l'historique des échecs précédents ; elle ne signifie pas que les recettes externes ou la production sont terminées.

### 37.1 Référence Git et preuve CI finale

- Branche : `work/naxa-services-completion-20261120`.
- HEAD de code testé : `f90c82886d5ae33ce97e1966e73ac40bf8cfaca3`.
- Dernier commit documentaire de la branche après mise à jour du présent rapport : `96290c50a151977a1c8e1ebb9d4af5505580cf08` (aucune modification de code après le SHA testé).
- Code Android testé dans ce workflow, incluant le transfert inter-sites : commit `7a0729c7ea8d9a852385652a688f2abe27eca586` (le workflow final a reconstruit l'ensemble du module au HEAD suivant, sans changement Android entre ces deux commits).
- Correctif tarifaire additionnel testé : `fcc091a5d85acea517e48745393b0ddd0219b5a4`, test correspondant au commit final `f90c82886d5ae33ce97e1966e73ac40bf8cfaca3`.
- Workflow GitHub Actions : `44784781041`, conclusion `success`.
- Trois jobs terminés avec succès :
  - `Assemble NAXA SERVICES Android debug APK`
  - `Auth scope and business-mode contract tests`
  - `NAXA FAMILY launch and maturity tariff tests`
- Artefact : `naxa-services-debug-apk`, ID `14653536762`, taille `11 527 424` octets, empreinte SHA-256 `5b390da34b8202f78780c00bb73bf0bd58905767508994229187bf63e030b474`. Conservation par GitHub jusqu'au 27 novembre 2026.
- Résultat : compilation Kotlin, génération Room/KAPT, assemblage APK et archivage verts pour ce workflow ; les contrats Auth et les tests de tarifs sont verts.

### 37.2 Transferts inter-sites Promoteur — réalisation Android/Room

Le parcours est maintenant réellement raccordé à la couche de données, et pas seulement affiché :

1. Le Promoteur crée une demande depuis le site source vers un autre site actif de la même organisation.
2. La demande vérifie l'organisation, l'appartenance et l'état actif des deux sites, l'existence de l'article source, le stock disponible, le SKU destination et la compatibilité d'unité.
3. La création et l'approbation ne modifient aucune quantité.
4. La demande apparaît depuis les deux sites concernés ; l'approbation est proposée au site source, la réception physique au site destination.
5. À la réception, une transaction Room unique revalide la quantité source et le SKU destination, décrémente le stock source, crée ou incrémente l'article destination, écrit les mouvements `transfer_out` et `transfer_in`, met à jour le dossier et inscrit les événements d'audit source/destination.
6. Un SKU ambigu, une unité incompatible, un site inactif ou un stock devenu insuffisant fait échouer la réception sans mouvement partiel.
7. Les transitions exigent un motif et sont rattachées à l'auteur ; les événements alimentent l'outbox.

**Frontière restante :** la transaction est atomique dans la base locale Room d'un appareil. L'arbitrage concurrent entre appareils, la transaction côté serveur, l'idempotence de l'API et les politiques RLS doivent encore être testés avant usage multi-appareils en production.

### 37.3 Catalogue tarifaire — correctif de robustesse final

- Les dix applications continuent d'utiliser le manifeste effectif-daté et la date du 1er mai 2027 à 00:00, fuseau `Africa/Douala`.
- Le calcul CAMPUS237 « SCHOOL » accepte désormais explicitement zéro élève actif avec un montant nul et un détail de tranche neutre ; un test dédié empêche la régression.
- Aucun prix, palier ou remise n'a été modifié par ce correctif.

### 37.4 Langues — état exact du Fulfulde

- La préférence `ff-CM` est acceptée et mémorisée par les préférences Android.
- **Le pack de ressources Fulfulde n'est pas encore complet** : le projet contient actuellement les ressources françaises (`values`) et anglaises (`values-en`), mais pas de dossier `values-ff-rCM`.
- En sélectionnant Fulfulde, une partie des libellés et des textes Compose retombe donc sur le français. Ne pas présenter l'application comme intégralement traduite en Fulfulde.
- Le pack doit être traduit et relu dans la variante camerounaise par un locuteur qualifié, notamment pour les CGU, la confidentialité, les paiements, la fiscalité et les parcours métier.

### 37.5 Statut de construction et réserves externes

**Statut : VERT — construction Android et gates CI.**

La construction Android native Kotlin/Jetpack Compose du périmètre présent est verte sur le workflow final cité ci-dessus. Les écrans ERP et profils d'activité sont présents, les derniers parcours métier ajoutés compilent, le catalogue des dix abonnements passe ses tests et les contrats Auth passent leurs contrôles.

Cette validation ne transforme pas les réserves ci-dessous en fonctionnalités de production :

- API ERP distante, outbox serveur, synchronisation offline complète, idempotence, reprise, conflits, rejeu et accusés de réception.
- RLS et tests d'isolation réels entre applications, organisations, sites, postes, membres et rôles.
- Paiement automatique réel, récurrences, webhooks fournisseurs et activation d'entitlements. Le moteur choisit le bon catalogue de prix et la bonne période ; aucun débit n'est déclenché automatiquement par la seule date.
- FCM, WhatsApp/SMS, relances CRM planifiées côté serveur, alerte pressing « linge prêt » et centre de notifications distant.
- Recettes instrumentées Android, scénarios complets sur émulateur/appareils physiques, performance, restauration et non-régression sur données réalistes.
- SYSCOHADA complet, paie réglementaire et fiscalité camerounaise validés par les professionnels compétents.
- Appels/partage d'écran, sauvegarde Google Drive et publication Android Release signée.
- Ressources Fulfulde complètes et validées.
- Dashboard administrateur central NAXA FAMILY, mutualisation réelle CSO, passerelle IA versionnée vers NAXA et intégration NAXA SECURITY vidéo/audio/alertes.
- Application Web/PWA séparée sur contrats API et règles métier partagés.

### 37.6 Protection du périmètre

- Aucun déploiement Supabase ni migration de schéma Supabase n'a été exécuté dans cette passe.
- Le projet NAXA autonome n'a pas été modifié.
- La branche de travail n'a pas été fusionnée automatiquement dans `main`.
- Les intégrations NAXA, NAXA SECURITY, paiements et services externes restent isolées jusqu'à leurs contrats, secrets, contrôles et recettes dédiés.

**Point de reprise :** lire le HEAD de `work/naxa-services-completion-20261120`. Ne pas recommencer les écrans ou les parcours listés dans les sections 30 à 37 ; poursuivre uniquement les réserves identifiées, en lots isolés avec gate CI associé.



---

## 38. Parrainage PME — première implémentation raccordée au Profil (20 novembre 2026)

### 38.1 Référence et contenu du lot

- Commit : `c76b6680c84635368ae7abd6430018aa13876e40` — `feat(naxa-services): add SME referral program workflow`.
- Branche : `work/naxa-services-completion-20261120`. Aucun changement du code n'a été effectué sur `main`.
- Écran ajouté : `apps/android/naxa-services/src/main/java/cm/naxa/naxaservices/ReferralScreen.kt`.
- Point d'entrée : Profil → « Parrainage et suivi de mes gains ».
- API source : `supabase/functions/naxa-services-referrals/index.ts`.
- Contrats/tests : `referral_contract.ts`, `contract_test.ts`.
- Migration candidate : `supabase/drafts/naxa_services_referrals_v1.sql` (draft, non appliquée).

### 38.2 Règle métier implémentée dans les contrats

1. Une organisation PME possède au maximum un code actif unique, généré à la demande depuis le profil du Promoteur.
2. Le Promoteur d'une PME filleule peut enregistrer un code une seule fois. L'auto-parrainage et le changement ultérieur de parrain sont refusés.
3. Une PME filleule n'est qualifiée qu'à la confirmation serveur de son premier abonnement réellement payé. Une inscription, une période d'essai, un paiement pending ou un renouvellement ne doivent pas être comptés.
4. Les récompenses sont attribuées par vagues distinctes de cinq activations : 5, 10, 15, etc. Les identifiants d'événements fournisseur et d'abonnements sont uniques dans le registre ; la fonction SQL verrouille l'organisation marraine afin d'éviter deux récompenses lors d'activations concurrentes.
5. Au moment où le seuil est atteint, la cadence réelle de la PME marraine détermine l'avantage : formule mensuelle → un cycle mensuel gratuit ; formule annuelle → un mois d'accès supplémentaire placé à l'expiration de la période annuelle.
6. Les états de récompense distinguent `pending_entitlement`, `applied` et `failed`. Une récompense créée n'est pas réputée consommée tant que le service d'entitlements n'a pas confirmé son application.

### 38.3 Interface et suivi

- Le code est affiché et peut être copié ; un bouton permet de le générer si aucun code actif n'existe.
- Le Promoteur d'une PME filleule peut saisir et associer un code reçu.
- Le tableau de suivi expose les PME rattachées, leur date de rattachement, leur statut et la date de premier paiement qualifiant.
- Un indicateur présente le nombre d'inscriptions, le nombre d'activations payées et la progression de la vague en cours.
- Les récompenses par vague, leur cadence et leur état d'application sont listés.
- L'accès à la gestion est réservé au rôle `promoter`.

### 38.4 Limites d'activation — ne pas qualifier la fonctionnalité de production

Le code Android appelle une fonction Edge distincte ; le code ne devient actif qu'après configuration de l'URL `NS_REFERRALS_FUNCTION_URL` (ou de l'URL dérivée depuis l'endpoint Auth). La fonction Edge nécessite les variables serveur Supabase et `NS_REFERRAL_WEBHOOK_SECRET`. Son action `subscription_first_paid` exige une signature HMAC-SHA256 du corps brut et un indicateur `is_first_paid_subscription=true`.

**Non livré par ce commit :**
- Le draft SQL n'a pas été appliqué à une base Supabase de recette ou de production.
- La fonction Edge de parrainage n'a pas été déployée.
- Le webhook d'un opérateur de paiement n'est pas encore raccordé pour émettre l'événement après capture vérifiée. Il doit aussi lire la cadence effectivement active de l'organisation marraine au moment du franchissement du seuil.
- Le moteur d'entitlements ne planifie pas encore le cycle mensuel gratuit ni le mois annuel supplémentaire. Tant que cette intégration n'est pas exécutée et vérifiée, l'état reste `pending_entitlement`.
- Aucun code de parrainage de production n'est généré ni aucun gain attribué sur des comptes clients réels.

La fonction SQL de qualification est idempotente dans le ledger, mais cela ne remplace pas encore les tests d'intégration transactionnels sur une base isolée, ni les tests webhook du fournisseur de paiement.

### 38.5 CI du commit de parrainage — résultat final

- Premier workflow : `44791819448`, SHA `c76b6680c84635368ae7abd6430018aa13876e40`, échec Android dû à l'import explicite non nécessaire de `androidx.compose.foundation.layout.weight`.
- Correctif appliqué : suppression de cet import, commit `f9cb368dec3ac2e00ad7088b054cb30ec1e5badb`.
- Workflow de validation du correctif : `44792194242`, conclusion **SUCCESS**, 4 jobs sur 4 réussis.
- Résultats : build Android debug réussi ; test/type-check du contrat de parrainage réussi ; Auth scope/business-mode réussi ; catalogue de tarification réussi.
- Artefact : `naxa-services-debug-apk`, ID `14656354059`, taille 11 560 550 octets, SHA-256 `f26dd357c47d677fe5c456b936af28ad2fda89c092525ff31385fdfafd11ef42`, expiration `2026-11-27T18:25:06Z`.
- Ce succès certifie le commit applicatif `f9cb368...` sous CI. Il ne certifie ni déploiement Edge/Supabase, ni qualification de production de tous les lots listés à la section 38.6.

### 38.6 Point de reprise et backlog global inchangé

Le lot de parrainage est ajouté sans réécrire les écrans et modules métiers précédents. Les réserves antérieures de la section 37 restent ouvertes : API ERP distante et synchronisation offline complète, idempotence et résolution de conflits réseau, RLS vérifiée par tests d'isolation, paiement récurrent réel et webhooks, entitlements, FCM/SMS/WhatsApp et planificateur CRM, SYSCOHADA/fiscalité/paie validés par professionnels, essais physiques/performance/restauration, Release Android signée, Web/PWA séparée, Fulfulde complet relu, pilotage central des dix applications/CSO, passerelle IA versionnée et intégration fonctionnelle NAXA SECURITY.

**Règle de périmètre :** aucun déploiement Supabase, aucune migration réelle, aucune Release signée et aucune publication n'ont été effectués dans ce lot. Le projet NAXA autonome n'a pas été modifié. La branche de travail n'est pas fusionnée dans `main`.


### 38.7 Vérification du projet Supabase connecté — lecture seule

Un contrôle read-only a été réalisé sur le seul projet Supabase accessible dans la connexion :

- Projet affiché : `NAXA`, région `eu-west-3`, état `ACTIVE_HEALTHY`.
- 41 migrations enregistrées, dont les dernières concernent le schéma NAXA/pharmacies, le marketplace, les partenaires et le durcissement RPC.
- 37 tables dans `public`; aucune table `ns_*` ni table NAXA SERVICES n'a été relevée.
- 0 Edge Function déployée dans ce projet.
- Advisors sécurité du projet : RLS activée sans policy sur 2 tables, search_path mutable sur 2 fonctions, extensions dans public (2), fonctions SECURITY DEFINER exécutables par anon (22) et par authenticated (37).
- Advisors performance : 35 clés étrangères non indexées, 28 cas auth/RLS initplan, 36 index inutilisés et 33 groupes de policies permissives multiples.

Ces alertes concernent le projet Supabase NAXA actuellement connecté et ses applications/schémas existants. Elles ne constituent pas un audit de NAXA SERVICES. **Aucune correction de sécurité ni migration n'a été exécutée** : modifier globalement ce projet sans cartographier les applications qui l'utilisent pourrait affecter la plateforme existante. Le projet actuellement connecté ne constitue pas une base de recette isolée identifiable de NAXA SERVICES ; le draft de parrainage reste donc non appliqué et sa fonction Edge non déployée.


### 38.8 Contrôle de la frontière d'authentification au déploiement

Le dépôt ne contenait pas encore de `supabase/config.toml`. Le lot ajoute désormais :

```toml
[functions.naxa-services-referrals]
verify_jwt = false
```

Ce choix est limité à la fonction Referral : les actions Promoteur valident elles-mêmes le bearer auprès de Supabase Auth puis vérifient le compte, l'organisation et le rôle ; le webhook fournisseur exige le HMAC-SHA256 du corps brut. Sans cette exception, le contrôle JWT automatique à la passerelle pourrait rejeter le webhook du fournisseur avant l'exécution du contrôle HMAC. Le README précise les deux chemins et interdit de réutiliser ce réglage sans contrôles applicatifs équivalents.

- Commit de configuration : `34682dd53f45f42db7ca815df0af6c74291bc80d`.
- Workflow sur ce HEAD : `44792804538`. Les tests tarifaires, Auth et parrainage sont réussis ; le job Android était en cours au moment de cette mise à jour.
- La présence du fichier de configuration ne signifie pas que la fonction est déployée ni que les secrets sont configurés.


### 38.9 Validation finale du code et de la configuration Referral

Le commit `34682dd53f45f42db7ca815df0af6c74291bc80d` inclut la configuration de vérification JWT de la fonction. Son workflow `44792804538` est terminé avec **SUCCESS — 4/4 jobs** :
- compilation et APK Android debug ;
- type-check/tests API Referral ;
- tests scope Auth ;
- tests catalogue de tarification.

Artefact issu de ce workflow :
- ID : `14657621377`, nom `naxa-services-debug-apk` ;
- taille : 11 560 547 octets ;
- SHA-256 : `3dc0e3f3dae2921afe71384257e22b41be06f2365794a9e48b62920be66f27e1` ;
- expiration : `2026-11-27T18:28:39Z`.

### 38.10 Déclenchement des contrôles sur les changements de configuration

Le commit `c87bf03b436c03cf5a84dcc9e01885e369e6cbaf` étend les filtres CI pour déclencher les tests aussi sur les changements de `supabase/config.toml`, du service Referral, de sa migration candidate et des contrats tarifaires dans les événements push et pull request. Le workflow `44793189090` a été déclenché ; au dernier contrôle, ses trois jobs de contrats/tarifs étaient réussis et le job Android était encore en compilation. Ce commit ne modifie pas le code métier Android ni le service Referral ; le build et l'artefact du commit précédent restent la preuve complète terminée pour ces sources.



## 39. NAXA SERVICES — fournisseurs WhatsApp, charges, fidélité et validation finale (20 novembre 2026)

**Branche :** work/naxa-services-completion-20261120  
**HEAD validé :** 1117dac353d1cd3e0ef93b96430614e422d8d329  
**Workflow final :** [44802531739 — SUCCESS, 4/4 jobs](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44802531739)

### 39.1 Stock et réapprovisionnement fournisseur par WhatsApp

- Ajout du champ de contact WhatsApp par article, avec indicatif international et normalisation en chiffres.
- Le contact est visible sur la fiche de stock, modifiable depuis la fiche et pris en charge dans le modèle d'import CSV sous la colonne supplier_whatsapp.
- Lorsque le stock atteint ou passe sous le seuil configuré, l'article affiche une proposition de commande.
- La quantité suggérée vise deux fois le seuil (au minimum une unité), déduction faite du stock disponible.
- L'action ouvre WhatsApp avec le fournisseur et un texte préparé indiquant l'article, la référence, la quantité, le stock actuel et le seuil. Le Promoteur ou l'utilisateur autorisé confirme lui-même l'envoi ; aucun message n'est envoyé sans action humaine.

Cette fonction est actuellement locale à l'application et à l'article/site. Le contact et les opérations ne sont pas encore synchronisés par une API ERP distante entre appareils.

### 39.2 Charges récurrentes et échéancier de gestion

Une entrée « Charges et échéances de paiement » est disponible depuis le Profil du rôle promoter. La page permet de :

- créer et modifier une charge avec libellé/catégorie libre, montant FCFA, périodicité mensuelle, trimestrielle, annuelle ou unique ;
- fixer la prochaine échéance en nombre de jours et le délai de rappel de 0 à 30 jours ;
- consulter les échéances proches, en retard et les autres échéances actives ;
- enregistrer des règlements partiels ou complets, avec validation du solde restant ;
- désactiver une charge sans supprimer son historique ;
- consulter les règlements antérieurs.

Le calendrier local avance d'un seul cycle après règlement complet : il ne masque donc pas silencieusement les échéances antérieures impayées. Le même contrôle de périmètre organisation/site est appliqué dans les opérations locales.

### 39.3 Rappels Android et chiffres de gestion

- Ajout d'un RecurringChargeReminderWorker Android WorkManager, planifié à fréquence quotidienne et limité à l'organisation de la session.
- Le Worker relit la base Room existante naxa-services-local.db, tient compte du délai de rappel et évite les répétitions multiples le même jour.
- Sur Android 13+, la page demande l'autorisation runtime des notifications. En cas de refus, aucune notification système ne peut être garantie.
- Le tableau financier mensuel consolide sur les sites actifs autorisés le CA des ventes confirmées et les règlements de charges récurrentes. La somme des règlements utilise une agrégation SQL sans limite arbitraire de 200 lignes.

Définition comptable de l'indicateur : le CA reste le total des ventes confirmées ; le solde affiché soustrait uniquement les paiements de charges récurrentes enregistrés dans ce module. Ce solde est indicatif, pas un résultat net SYSCOHADA, un résultat fiscal ni une clôture comptable. Les autres dépenses, charges à payer et obligations fiscales doivent être rapprochées dans le futur moteur comptable.

Les rappels de cette passe sont locaux à l'appareil. Aucun planificateur serveur, FCM, SMS ou WhatsApp Business API n'a été déployé.

### 39.4 Quatre programmes de fidélité indépendants par activité

Une page « Programme de fidélité » est accessible au rôle promoter. À la première ouverture, quatre programmes sont initialisés indépendamment pour le profil d'activité choisi :

1. Club points — accumulation par tranches d'achat ; les reliquats sont conservés entre opérations (par exemple deux achats de 500 FCFA alimentent un point si le barème est 1 000 FCFA).
2. Carte de passages — un passage par visite/prestation validée, récompense au seuil.
3. Cercle privilège — récompense en fonction du montant d'achat cumulé.
4. Rendez-vous fidèle — fréquence de visite sur une fenêtre glissante (45 jours par défaut).

Le Promoteur peut modifier le nom, la présentation, l'indicateur, l'unité, le seuil, la récompense, la fenêtre glissante et l'état actif/inactif. Une activité client est enregistrable depuis la page ; l'historique conserve les événements, les vagues de récompenses et leur état disponible/utilisé.

Limite actuelle : l'enregistrement d'une activité fidélité est manuel depuis cette page. Il n'est pas encore déclenché automatiquement à chaque vente de caisse et ne se synchronise pas encore entre appareils. Cette connexion dépend du contrat API ERP, de l'identifiant client sur la vente et de la synchronisation idempotente.

### 39.5 Migration Room et compatibilité

- La base locale passe de la version 7 à la version 8.
- La migration NS_SERVICES_MIGRATION_7_8 ajoute le contact fournisseur et les tables charges, paiements, programmes et événements de fidélité avec leurs index.
- Le champ fournisseur déclare le même défaut SQL que celui ajouté par la migration, afin de conserver la validation de schéma Room.
- Le Worker et le démarrage principal utilisent la même base locale et la même chaîne de migrations.

Le gate CI compile et assemble le module Android ; il ne remplace pas une recette instrumentée de migration sur une copie de base de données d'un appareil existant.

### 39.6 Parrainage PME : règles durcies, activation réelle encore dépendante du serveur

Le parcours ajouté à la section 38 reste accessible au Promoteur : génération du code, rattachement des PME, suivi des dates de première activation payée, récompenses successives par vagues de cinq, et affichage du statut des gains.

Les contrats SQL Referral ont été durcis :
- rejet d'une cadence de souscription marraine nulle ;
- vérification que le même identifiant d'événement webhook correspond au même abonnement et à la même PME filleule ;
- refus d'un identifiant d'idempotence réutilisé avec un contenu différent ;
- une PME déjà qualifiée par un autre abonnement ne peut pas être recomptée.

La récompense attendue reste bien : un cycle mensuel gratuit pour une marraine au plan mensuel, ou un mois d'accès ajouté à la fin du plan annuel. L'application réelle de cette récompense demeure pending_entitlement tant que le moteur serveur d'entitlements et le fournisseur de paiement ne confirment pas l'opération. Le code de parrainage et l'écran ne prouvent pas qu'un abonnement réel a déjà été prolongé.

### 39.7 Schéma serveur candidat v3 — non appliqué

Le nouveau fichier supabase/drafts/naxa_services_v3_operations_rewards_sync.sql ajoute le modèle candidat pour :
- les charges récurrentes et leurs paiements idempotents ;
- les programmes et événements de fidélité ;
- les reçus de synchronisation, conflits et file d'attente de notifications ;
- les politiques RLS et fonctions transactionnelles associées ;
- le contact WhatsApp fournisseur.

Les contrats de paiement et de fidélité comparent le contenu rejoué à la clé d'idempotence ; un contenu différent avec la même clé est rejeté. Le barème de points conserve les achats sous seuil. Le script se termine par rollback; et reste un draft de revue : il n'a pas été exécuté ni validé sur un PostgreSQL isolé. Les filtres CI ont été étendus aux drafts v1, v2, Referral et v3.

### 39.8 Preuve CI finale

Le workflow 44802531739 sur le HEAD 1117dac353d1cd3e0ef93b96430614e422d8d329 est terminé SUCCESS — 4/4 jobs :

- assemblage Android debug ;
- contrats Referral ;
- Auth scope et business-mode ;
- tests du catalogue de maturité tarifaire.

Artefact produit :
- nom : naxa-services-debug-apk ;
- ID : 14661607933 ;
- taille : 11 682 565 octets ;
- SHA-256 : 233c24881277cac33e813b3352674d7392340fd4962308d9feeab8e70a7e44c9 ;
- expiration : 2026-11-27T19:31:23Z.

Cette preuve certifie la compilation et les contrôles CI ci-dessus. Elle ne certifie pas la migration exécutée sur un appareil, une API distante, un RLS de production, un fournisseur de paiement, ni les notifications externes.

### 39.9 Backlog obligatoire avant « VERT GLOBAL »

| Chantier | État après cette passe |
|---|---|
| ERP distant et synchronisation offline de bout en bout | Non livré ; schéma/structure candidats uniquement, pas d'API de synchronisation complète |
| Idempotence et résolution des conflits multi-appareils | Contrats SQL candidats ; aucun moteur de fusion et aucune recette réseau réelle |
| RLS org/site/poste/rôle | Policies candidates présentes dans les drafts ; non appliquées et non testées sur une base isolée |
| Paiements récurrents, webhooks et entitlements | Non activés ; aucun prélèvement réel, la récompense Referral reste en attente d'entitlement |
| FCM, CRM serveur, SMS et WhatsApp Business API | Non déployés ; seul le rappel Android local est ajouté |
| Comptabilité SYSCOHADA, impôts, taxes et paie | Non validés par expert-comptable/fiscaliste et non qualifiés réglementairement |
| Recettes instrumentées, appareils, performance et restauration | Non exécutées sur appareils physiques ni environnement de charge |
| Release Android signée | APK debug uniquement ; clé de signature et release non fournies |
| Web/PWA séparée | À finaliser et à tester indépendamment du natif Android |
| Fulfulde complet | Ressources complètes et relecture native encore nécessaires |
| Console centralisée des dix apps, CSO partagé, passerelle IA versionnée et NAXA SECURITY | Non livrés dans cette passe |

### 39.10 Environnement, coûts et règle de livraison

Le seul projet Supabase connecté est le projet existant NAXA, sans schéma ns_* ni Edge Functions NAXA SERVICES déployées. La création d'une branche Supabase de développement a demandé une confirmation de coût ; aucune dépense n'a été engagée. Aucune migration ou fonction n'a donc été déployée dans le mauvais projet.

Aucun secret de fournisseur de paiement, WhatsApp Business, SMS ou FCM, aucune clé de signature Android, aucun appareil physique de recette et aucune validation professionnelle comptable/fiscale n'étaient disponibles dans l'environnement. Ils restent des dépendances réelles, pas des tâches que la compilation debug peut simuler.

Conclusion honnête : le périmètre Android ajouté dans cette passe est vert au build CI (4/4) et le code reste sur la branche de travail. NAXA SERVICES n'est pas encore « VERT GLOBAL ». Aucune fusion dans main, aucun déploiement production, aucune migration Supabase réelle, aucune Release Android signée et aucune publication n'ont été effectués.


# Addendum 4 — Cycle comptable fournisseurs et pilotage financier comparatif (20 novembre 2026)

**Branche de travail :** `work/naxa-services-completion-20261120`  
**HEAD code au moment de cet addendum :** `5aac7763a8ef075a1e12d99b7160713a6cb7cf8b`  
**HEAD de `main) contrôlé avant cet addendum :** `65dfbcf29a5e9add1be79ef77ac930b3350eba9d`  
**Protection :** aucune fusion dans `main`, aucune migration réelle et aucun déploiement n'ont été exécutés.

## 40.1 Cycle achats fournisseurs déjà présent et consolidé

Le parcours Android local comprend les fiches fournisseurs, les commandes multi-lignes, les types de lignes Stock / Charge d'exploitation / Immobilisation, les réceptions partielles et complètes, l'historique des réceptions, la dette fournisseur, les paiements partiels ou complets et le journal de gestion débit/crédit.

Règles de comptabilisation retenues :

- Une commande seule n'augmente ni le chiffre d'affaires, ni le stock, ni les charges : l'engagement n'est pas une réception.
- À la réception d'une ligne de stock : débit de l'actif stock / crédit de la dette fournisseur. Les coûts d'acquisition imputables (part de frais de livraison et coûts non récupérables) entrent dans la valorisation moyenne pondérée.
- À la réception d'un consommable ou service d'exploitation : débit d'une charge d'exploitation / crédit de la dette fournisseur.
- À la réception d'une immobilisation : débit immobilisation / crédit dette fournisseur.
- La taxe récupérable est isolée dans un compte de créance fiscale préparatoire.
- Le règlement fournisseur : débit dette fournisseur / crédit caisse, banque, Mobile Money ou autre trésorerie. Il éteint la dette ; il ne crée pas une seconde charge.
- Le chiffre d'affaires n'est constitué que par les ventes confirmées. Un achat fournisseur n'est jamais ajouté au CA.
- Le coût des marchandises vendues est rattaché à la vente au moment de la sortie du stock, à partir du coût documenté. Les ventes dont le coût direct n'est pas fiable sont signalées et exclues du calcul de marge certifiable.

Le SQL candidat v4 ajoute le modèle serveur fournisseurs, documents d'achat, lignes, réceptions, paiements, écritures comptables, objectifs versionnés, lectures de performance journalières/mensuelles/annuelles et fonctions transactionnelles protégées. Ce fichier reste un draft avec rollback final : sa présence ne prouve pas son application sur une base.

## 40.2 Idempotence et rapprochement de caisse

- La base Room passe à la version 11 avec la migration non destructive `10 → 11`.
- Chaque réception locale possède une clé d'idempotence unique au niveau organisation ; une reprise identique ne doit pas créer une seconde entrée de stock, dette ou écriture.
- L'écran de règlement fournisseur produit une clé stable à partir de la pièce, du solde antérieur, du montant et des paramètres du paiement afin de rendre les double-clics / reprises identiques idempotents.
- Un paiement fournisseur en espèces demeure une sortie de trésorerie pour le calcul de clôture de la caisse.
- Dans les rapports de gestion, les paiements fournisseur sont séparés des charges d'exploitation. Les dépenses opérationnelles sont lues depuis le journal comptable (`OPERATING_EXPENSE*`) et les règlements fournisseurs sont affichés comme extinction de dette, sans double déduction.

## 40.3 Assistant de pilotage et séries comparatives

Le moteur présent est un moteur statistique local déterministe et explicable ; ce n'est pas une connexion à un modèle génératif distant. Il utilise les ventes confirmées et les objectifs enregistrés pour :

- projeter le jour à partir du rythme réalisé et d'une référence glissante de 14 jours ;
- projeter la clôture du mois sur une moyenne glissante de 28 jours ;
- projeter la clôture annuelle sur une moyenne glissante de 90 jours ;
- comparer réalisé, projection, objectifs, écart prévisionnel, taux d'atteinte et effort quotidien restant ;
- générer des actions de redressement explicables : ventes additionnelles estimées au ticket moyen récent, relance commerciale, protection de marge, prévention de rupture et maîtrise des dettes fournisseurs ;
- suivre 14 jours, 12 mois et 5 exercices, avec comparaison au jour / mois comparable / même période de l'exercice précédent ;
- présenter pour ces séries le CA, le coût des ventes connu, les charges d'exploitation, la marge brute, le résultat opérationnel indicatif et les flux fournisseurs (stock capitalisé, achats consommables, immobilisations et paiements).

La marge et le résultat opérationnel restent volontairement non calculables lorsqu'au moins une vente de la période n'a pas de coût direct documenté. Le chargement de six années d'historique permet d'avoir une base annuelle antérieure complète pour les cinq exercices affichés.

Le rapport quotidien par site utilise le fuseau `Africa/Douala`, distingue CA confirmé, coût des ventes connu, charges journalisées, règlements fournisseurs et ventes sans coût fiable. Il ne transforme pas un indicateur de gestion en résultat SYSCOHADA certifié.

## 40.4 Tests ajoutés et état des contrôles

Les tests unitaires Android ajoutés couvrent :
- l'absence d'augmentation du CA lors d'une réception ou d'un règlement fournisseur ;
- la séparation entre stock capitalisé, achat consommable, immobilisation et règlement de dette ;
- l'absence de double déduction d'un règlement fournisseur dans les charges d'exploitation ;
- les comparaisons financières quotidiennes, mensuelles et annuelles ;
- le changement de date locale `Africa/Douala` autour de minuit UTC.

Le workflow `44835057217` a terminé en succès (5/5) pour le moteur de prévision avant l'ajout de l'écran comparatif. Les runs ultérieurs ont mis en évidence puis permis de corriger une erreur de double annotation Compose dans l'écran financier. Le run `44835604400` sur le commit `419583adac3268c22d3035ba46ab8aac695014f1` avait ses quatre contrats serveur / tarifs / parrainage / Auth en succès ; son job Android exécutait encore les tests unitaires au moment du constat. Le commit `5aac7763a8ef075a1e12d99b7160713a6cb7cf8b` ajoute ensuite la lecture des charges directement depuis le journal ; son résultat de CI doit être vérifié séparément.

## 40.5 Limite d'activation à ne pas masquer

Les écrans Achats et Pilotage restent explicitement en mode local Room. L'outbox existe, mais il ne constitue pas un moteur de synchronisation ERP multi-appareils de bout en bout. Le SQL v4 et la fonction Edge comptable sont candidats/non déployés ; aucun client Android ne démontre encore la synchronisation complète de ces commandes, réceptions, paiements, journaux et vues de performance avec un environnement Supabase isolé.

En conséquence, cet addendum confirme des développements et contrats dans la branche de travail, mais ne lève pas le backlog du §39.9 : RLS/recette serveur, synchronisation offline et résolution de conflits, abonnements et paiements réels, validation SYSCOHADA/fiscale, tests instrumentés et restauration, Release signée, Web/PWA, Fulfulde complet et console centrale. Aucun de ces éléments ne doit être réputé livré par la seule compilation Android.


# Addendum 5 — Validation de la comptabilité fournisseurs et du cockpit financier (21 novembre 2026)

**Code Android validé :** `edb75ba714ba1a2ffb24cb0f8e23019553970fe4`  
**Workflow :** [44836031127 — SUCCESS, 5/5 jobs](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44836031127)  
**APK technique :** `naxa-services-debug-apk`, artifact ID `14678138586`, taille `11 834 979` octets. Il s'agit d'un APK **debug**, non signé pour la distribution publique.  
**Branche de travail :** `work/naxa-services-completion-20261120`. Aucun merge dans `main`.

## 41.1 Cycle fournisseurs : règles comptables appliquées côté Android local

Le lot comprend désormais la continuité du cycle suivant : fournisseur → commande multi-lignes → réception partielle/complète → entrée de stock ou charge/immobilisation → dette fournisseur → règlement → journal → rapport/pilotage.

- Une commande seule constitue un engagement, pas une réception : aucune variation du stock, du CA ni du résultat n'est comptabilisée à ce stade.
- La réception d'un article de stock augmente la quantité disponible et la valeur du stock, avec coût moyen pondéré incluant les coûts imputables non récupérables répartis sur les réceptions.
- Les achats consommables/services sont débités en charges d'exploitation à la réception ; les immobilisations sont reconnues à part ; les taxes récupérables sont isolées.
- Le règlement solde la dette fournisseur contre la trésorerie. Il reste une sortie de caisse si payé en espèces, mais n'est jamais re-déduit comme charge.
- Le CA est composé uniquement des ventes confirmées. Le coût des marchandises vendues est reconnu à la sortie du stock au moment de la vente ; un coût direct absent ou non fiable rend la marge et le résultat non calculables au lieu d'être estimés arbitrairement.
- Room v11 conserve une clé d'idempotence unique des réceptions via la migration non destructive 10→11. Les clés stables côté écran protègent les reprises/double-clics de réception et de paiement.

Les écritures restent un journal de gestion à comptes symboliques, non un grand livre SYSCOHADA certifié.

## 41.2 Rapport quotidien, tableau d'accueil et assistant de pilotage

- Les rapports quotidiens par site lisent désormais les charges d'exploitation depuis le journal comptable, et non depuis les sorties brutes de caisse.
- Les paiements fournisseur sont présentés séparément comme règlements de dette. Ils restent comptés dans le rapprochement de caisse espèces, mais ne sont pas déduits une deuxième fois du résultat.
- Les rapports exposent le CA confirmé, le coût des ventes connu, les charges d'exploitation, le calcul de marge brute si tous les coûts directs sont disponibles, le résultat opérationnel indicatif uniquement dans ce cas, et les règlements fournisseurs.
- Le DAO `observeExpensesTotal` conserve un alias de compatibilité pour l'ancien tableau d'accueil, mais lit désormais le journal `OPERATING_EXPENSE*`; le nom historique ne signifie donc plus que les paiements de fournisseurs sont confondus avec les charges.
- Les calculs quotidiens de l'accueil et des rapports utilisent `Africa/Douala`.
- L'assistant de pilotage suit le jour, le mois et l'année, et fournit les séries comparatives détaillées 14 jours / 12 mois / 5 exercices. Les projections sont statistiques et explicables (moyennes glissantes de 14/28/90 jours) et non une IA générative distante.
- Les actions de redressement s'appuient sur les écarts prévisionnels aux objectifs et le ticket moyen récent ; les recommandations de marge, de rupture et de dettes fournisseurs sont distinctes.

## 41.3 Résultat du contrôle technique

Le run `44836031127` a terminé **SUCCESS — 5/5 jobs** :
1. tests Auth/périmètres ;
2. tests du catalogue tarifaire Famille NAXA ;
3. contrats Referral ;
4. contrats comptabilité fournisseurs et prévisions ;
5. tests unitaires Android, compilation et assemblage du debug APK.

Le run démontre que le code du commit `edb75ba` compile et que les tests présents passent. Il ne démontre pas les tests instrumentés sur appareils, le comportement multi-appareils, la synchronisation ERP réelle, le RLS appliqué sur une base isolée ni une Release signée.

Un échec plus ancien `44835968285` concernait la résolution réseau de `kotlinx-coroutines-android:1.8.1` avant compilation ; le workflow ci-dessus a depuis achevé avec succès sur le code final concerné. Les échecs de compilation antérieurs sur le double `@Composable` et l'ancien nom DAO ont également été corrigés puis couverts par le dernier build.

## 41.4 Portée non activée et réserves de qualification

Les écrans Achats, Rapports et Pilotage utilisent encore la base Room locale. Le draft SQL v4 et sa passerelle Edge comptable restent non déployés ; aucune API Android de synchronisation ERP complète ni résolution des conflits multi-appareils n'a été validée. Le schéma/les fonctions SQL candidats ne sont donc pas une base de production.

Les autres réserves des §39.9 et §40.5 restent ouvertes : application et tests RLS, synchronisation offline complète, paiements récurrents/webhooks/entitlements, fournisseurs FCM/SMS/WhatsApp Business, validation comptable/fiscale/paie SYSCOHADA, inventaires/retours/transferts complets, essais instrumentés/performance/restauration, Release signée, Web/PWA, Fulfulde complet relu, console centrale des dix applications, mutualisation opérationnelle des CSO et intégration fonctionnelle NAXA SECURITY.

**Décision :** le lot financier et le code Android du commit `edb75ba` sont validés par le CI debug. Ce résultat ne qualifie pas NAXA SERVICES « VERT GLOBAL » et n'autorise ni migration Supabase, ni déploiement Edge, ni distribution publique, ni fusion dans `main`.


# Addendum 6 — Renforcement statique de la frontière RLS NAXA SERVICES (21 novembre 2026)

**Branche :** `work/naxa-services-completion-20261120`  
**Commit de base :** `0b5afbee39daad4881e70987555c2d42a68ac3e9`  
**Périmètre :** drafts SQL NAXA SERVICES, contrôles CI statiques et documentation. Aucun schéma n'a été appliqué à une base.

## 42.1 Contradiction et cause racine

La revue des scripts v1 à v4 confirme que toutes les tables créées activent RLS. Les tables internes sans politique client — comptes, tentatives Auth, demandes de récupération, appareils, acceptations légales, reçus de synchronisation, conflits et file de notifications — sont réservées au serveur.

Plusieurs révocations v1/v2 ne citaient cependant que `anon` et `authenticated`, sans révoquer explicitement le rôle PostgreSQL `PUBLIC`. Le draft v1 ne déclarait pas non plus explicitement l'octroi `service_role` sur les tables internes.

## 42.2 Corrections apportées

- v1 : révocation explicite de `PUBLIC`, `anon` et `authenticated` sur `ns_accounts`, `ns_auth_attempts`, `ns_auth_recovery_requests`, `ns_devices` et `ns_audit_events` ; accès explicite accordé à `service_role`.
- v2 : révocation explicite des mêmes rôles sur `ns_legal_acceptances`, réservée à `service_role`.
- v3 : les tables de synchronisation et de notifications conservent leur accès réservé au serveur.
- v4 : les reçus, règlements fournisseurs et écritures restent en lecture selon RLS ; leurs mutations passent par les RPC contrôlées.

## 42.3 Garde-fous CI

Le nouveau test `supabase/tests/drafts/naxa_services_static_security_test.ts` contrôle :
1. l'activation RLS de chaque table créée ;
2. la classification explicite des tables sans policy ;
3. le recours des politiques à des helpers de périmètre `ns_*`, sans policy inconditionnelle `USING (true)` / `WITH CHECK (true)` ;
4. la révocation `PUBLIC` / `anon` / `authenticated` et l'octroi `service_role` sur chaque table restreinte ;
5. l'absence de privilèges directs client sur ces tables ;
6. `search_path = ''` pour chaque fonction `SECURITY DEFINER` ;
7. le caractère transactionnel et explicitement non-production des scripts.

Le job CI indépendant `sql-static-security` exécute ce contrôle Deno. Les filtres push et pull request surveillent désormais aussi `supabase/tests/drafts/**`.

## 42.4 Portée de la preuve et limites

Ces assertions examinent le texte SQL versionné ; elles ne remplacent pas l'exécution PostgreSQL, les tests positifs/négatifs des rôles, ni les scénarios d'isolation entre organisations, sites, appareils et membres. Les drafts v1-v4 demeurent non appliqués. La sécurité RLS n'est donc pas qualifiée en environnement d'exécution.

**Statut :** correctifs SQL et contrôles CI ajoutés sur la branche de travail ; validation du job CI requise après commit. Aucun déploiement, aucune migration, aucune modification du projet Supabase historique et aucune fusion dans `main`.
