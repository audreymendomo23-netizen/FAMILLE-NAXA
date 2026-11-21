# LOYABLE — Document de continuité produit et technique

> Version : 1.0  
> Date de mise à jour : 21 novembre 2026  
> Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA`  
> Branche documentaire : `main`  
> Statut : vision produit consolidée — conception détaillée à poursuivre  
> Référentiel : décisions utilisateur du 21 novembre 2026, cahier LOYABLE historique et audit de NAXA SERVICES.

Ce document est la référence de reprise spécifique à LOYABLE. Il distingue les décisions validées [V], les propositions d'architecture à confirmer [P], les points encore ouverts [O] et les constats vérifiés [C]. Une exigence inscrite ici n'est pas réputée développée ou testée.

---

## 1. Positionnement et périmètre

LOYABLE est une solution de gestion immobilière et locative qui réunit quatre espaces fonctionnels reposant sur un domaine métier et un backend LOYABLE communs :

1. **LOYABLE Gestion** — espace de gestion du bailleur partenaire.
2. **LOYABLE Locataire** — portail individuel accessible sur mobile sans installation.
3. **LOYABLE Immobilier** — vitrine et recherche publique de logements disponibles.
4. **LOYABLE Publication NAXA** — console interne de publication assistée pour les bailleurs non partenaires.

Le périmètre n'est pas limité à un ERP de loyers : il comprend le patrimoine immobilier, les contrats, les paiements déclarés, les services aux locataires, la maintenance, la rentabilité, la commercialisation des logements et un canal d'acquisition de bailleurs.

### 1.1 Principes structurants [V]

- Le bailleur partenaire gère son portefeuille et ses annonces dans LOYABLE.
- Le locataire accède à son espace sans devoir installer une application.
- Les annonces des bailleurs partenaires sont gratuites.
- Les annonces des bailleurs non partenaires sont publiées par le personnel NAXA, avec une déclaration interne des règlements reçus hors plateforme.
- Le paiement du loyer n'est pas collecté par LOYABLE dans le parcours validé : le locataire déclare son règlement et transmet une preuve ; le bailleur confirme humainement.
- L'IA assiste le bailleur, mais ne prend pas de décision contractuelle ou financière à sa place.
- Les états des lieux sont exclus du périmètre retenu, malgré leur présence dans le cahier historique du 31 octobre 2026.
- Le Centre de maintenance est inclus côté locataire et doit couvrir le suivi complet des interventions.

---

## 2. Les quatre espaces

### 2.1 LOYABLE Gestion — bailleur partenaire [V]

Fonctions :
- tableau de bord du patrimoine et des biens ;
- portefeuille, immeubles, sites, logements et unités ;
- fiches des locataires et historique locatif ;
- contrats, échéances, renouvellements, demandes de préavis et demandes de résiliation ;
- loyers attendus, retards, paiements partiels, avances et soldes ;
- examen des déclarations et preuves de paiement ;
- génération des reçus et quittances ;
- charges, dépenses, réparations et interventions ;
- centre de maintenance et affectation des demandes au concierge ou à un prestataire ;
- pilotage de rentabilité par bien, immeuble et portefeuille ;
- calendrier immobilier ;
- assistant IA du bailleur ;
- création, modification et suivi des annonces immobilières ;
- statistiques de vues des annonces.

Les opérations contractuelles du locataire (renouvellement, préavis, résiliation) sont des demandes soumises à décision/validation du bailleur, pas des modifications irréversibles déclenchées automatiquement.

### 2.2 LOYABLE Locataire [V]

Accès et fonctions :
- accès par QR code du site et identifiant locataire ;
- accès direct par lien personnel envoyé par le bailleur via WhatsApp ;
- consultation du contrat et téléchargement ;
- consultation du loyer, des échéances, des retards, des charges et de l'historique ;
- déclaration d'un paiement et dépôt d'une preuve (photo, capture ou document) ;
- téléchargement des reçus et quittances à tout moment ;
- demande de renouvellement, préavis ou résiliation, soumise au bailleur ;
- signalements et réclamations ;
- **Centre de maintenance** : déclaration d'une panne ou d'un problème, description, catégorie, urgence, photos/vidéos justificatives, suivi du traitement, échanges et consultation de la clôture.

Le locataire n'a pas besoin de créer un compte classique par inscription libre.

**Décision d'accès :** QR du site + identifiant locataire et lien personnel WhatsApp transmis par le bailleur, sans étape supplémentaire de vérification sécurisée de type OTP. Le lien devra néanmoins être opaque, non devinable, limité au locataire concerné et révocable ; cette précaution technique ne constitue pas une vérification d'identité supplémentaire.

### 2.3 LOYABLE Immobilier — vitrine publique [V]

- Accessible par QR code et lien partageable.
- Présente les logements disponibles des bailleurs partenaires.
- Recherche par ville, quartier dépendant de la ville, proximité, type de logement et prix.
- Affiche les caractéristiques, conditions, description et jusqu'à six photos par annonce.
- La géolocalisation publique est approximative ; la position exacte reste une donnée interne, sauf communication volontaire du bailleur selon le parcours retenu.
- Un logement occupé ne doit pas apparaître comme disponible.
- Le chercheur peut contacter le bailleur par WhatsApp via le numéro configuré pour l'annonce.
- Un appel marketing « Vous êtes bailleur ? Rejoignez LOYABLE » ouvre la conversation WhatsApp commerciale NAXA configurée à cet effet. Ce contact est distinct du WhatsApp du bailleur de l'annonce.

### 2.4 LOYABLE Publication — personnel NAXA [V]

- Réservé aux collaborateurs NAXA autorisés.
- Création/fiche des bailleurs non partenaires.
- Saisie des biens disponibles, caractéristiques, prix, conditions, coordonnées et photos reçues.
- Publication, renouvellement, retrait anticipé et historique.
- Déclaration des paiements reçus hors LOYABLE.
- Rapprochement des publications, renouvellements et montants déclarés.
- Identification du collaborateur ayant créé, modifié, renouvelé ou retiré une annonce.
- Conservation des justificatifs et références de paiement disponibles.

Un bailleur externe reste le propriétaire/donneur de mandat réel. Le compte ou collaborateur NAXA qui saisit l'annonce n'est jamais présenté comme propriétaire.

---

## 3. Paiements locatifs, reçus et quittances [V]

### 3.1 Cycle de confirmation

1. Le locataire effectue le règlement en dehors de LOYABLE.
2. Il déclare le paiement dans son espace et fournit une preuve.
3. La déclaration est en attente de contrôle.
4. Le bailleur vérifie et confirme ou rejette humainement.
5. Après confirmation, LOYABLE génère le reçu dans l'espace du bailleur.
6. Le bailleur transmet le reçu par WhatsApp ; le locataire peut aussi le télécharger à tout moment.

Statuts fonctionnels à utiliser : non réglé, déclaré, en vérification, confirmé, rejeté. Prévoir les paiements partiels, paiements cumulés, avances, doublons et rapprochements avec le montant exigible.

### 3.2 Documents

- Un reçu distinct pour chaque règlement confirmé, y compris partiel.
- Une quittance de loyer lorsque la totalité du montant exigible pour la période est réglée.
- Le document porte au minimum : numéro unique, bailleur, locataire, bien, période, montant reçu, date, moyen de paiement déclaré, référence disponible, montant exigible, solde restant éventuel et date de confirmation.

La preuve importée par le locataire est conservée dans un espace privé, avec contrôle des droits d'accès, limites de taille et journal de consultation. Une image de preuve ne confirme jamais automatiquement le paiement.

---

## 4. Centre de maintenance — périmètre validé et workflow cible [V]

Le Centre de maintenance est une fonctionnalité du portail locataire, pilotée depuis LOYABLE Gestion.

### 4.1 Parcours de bout en bout

1. **Signalement locataire** : choix du bien/unité, catégorie de problème, description, niveau d'urgence, photos/vidéos et disponibilité pour intervention.
2. **Qualification** : le bailleur ou le concierge examine la demande, demande des précisions si nécessaire et détermine si une intervention est requise.
3. **Affectation** : le bailleur affecte la demande au concierge, à un employé interne ou à un prestataire externe compatible.
4. **Prise en charge** : l'intervenant accepte, propose un créneau ou signale son indisponibilité.
5. **Diagnostic et devis** : description du diagnostic, pièces nécessaires, main-d'œuvre, frais de déplacement, estimation et validation préalable du bailleur lorsque nécessaire.
6. **Exécution** : étapes, horodatages, photos avant/pendant/après, commentaires, pièces utilisées et dépenses réelles.
7. **Contrôle** : le concierge ou bailleur vérifie le travail, demande une reprise si nécessaire ou valide la fin.
8. **Clôture** : compte rendu, justificatifs, montant final, responsable, date, preuve de clôture et information du locataire.

### 4.2 États proposés [P]

`new` → `qualified` → `assigned` → `accepted` → `scheduled` → `in_progress` → `awaiting_review` → `completed`

États alternatifs : `needs_information`, `quote_pending`, `quote_rejected`, `rework_requested`, `cancelled`, `rejected`.

Toute transition importante conserve auteur, date, ancien état, nouvel état et motif. Une intervention clôturée ne doit pas être modifiée silencieusement : une correction crée une nouvelle entrée d'historique.

### 4.3 Traçabilité financière [V]

Pour chaque intervention :
- devis initial et validation du bailleur ;
- coût main-d'œuvre ;
- pièces et consommables ;
- déplacement ;
- dépenses annexes ;
- justificatifs (facture, reçu, photo) ;
- montant effectivement payé et bénéficiaire ;
- part éventuellement refacturable au locataire, selon décision du bailleur et règles du bail ;
- écart devis/réel avec motif ;
- lien avec la charge du bien et le tableau de rentabilité.

LOYABLE suit les montants et justificatifs. Il ne doit pas transformer une estimation en dépense payée sans preuve ou validation humaine.

### 4.4 Rôles

- **Locataire** : signale, ajoute des éléments, suit l'avancement et consulte le compte rendu autorisé.
- **Bailleur** : qualifie, affecte, autorise les devis/dépenses, contrôle et clôture.
- **Concierge** : prend en charge les demandes que le bailleur lui délègue, suit les interventions et documente le travail.
- **Prestataire NAXA SERVICES** : reçoit uniquement les informations nécessaires à l'intervention assignée et renseigne les étapes, devis, pièces, photos, dépenses et compte rendu.
- **Personnel NAXA habilité** : administration du réseau de prestataires et support technique, sans accès général aux données locatives.

Les droits exacts du concierge et les seuils de dépense délégués restent à préciser [O].

---

## 5. Capitalisation sur le réseau de prestataires NAXA SERVICES

### 5.1 Principe d'intégration [P]

LOYABLE ne doit pas reconstruire un annuaire concurrent ni copier les comptes, équipes ou dossiers de NAXA SERVICES. NAXA SERVICES reste l'application métier dans laquelle le professionnel gère son activité et ses opérations. LOYABLE devient un canal d'origine de demandes immobilières.

Le principe proposé est :

**LOYABLE (demande de maintenance) → registre de compatibilité des prestataires → affectation/ordre d'intervention → NAXA SERVICES (prise en charge métier par le prestataire) → retour d'état et justificatifs vers LOYABLE.**

L'intégration doit s'appuyer sur des identifiants d'organisation et de prestataire, des contrats d'API et des événements idempotents. Pas de partage implicite de session ou d'identité entre les deux applications : les identités et autorisations restent séparées conformément aux principes Famille NAXA.

### 5.2 Sélection d'activité NAXA SERVICES — référence métier

Le parcours métier retenu antérieurement pour NAXA SERVICES prévoit une sélection initiale de l'activité par le Promoteur à la première connexion, puis le rattachement du profil à l'organisation. Le choix n'est pas modifiable par un simple collaborateur.

Catalogue de 13 activités/profils à conserver comme référence :
1. Pressing — blanchisserie et entretien textile.
2. Coiffure — salon et barber.
3. Couture — retouche et confection.
4. Beauté — esthétique et onglerie.
5. Parfumerie.
6. Réparation — téléphones, électronique et électroménager.
7. Menuiserie.
8. Garage — mécanique et lavage automobile.
9. Nettoyage.
10. Domicile.
11. Imprimerie.
12. Photographie.
13. Autre — activité personnalisable.

Parcours initial prévu : choix de langue → authentification et sélection d'activité → acceptation des CGU et de la politique de confidentialité en FR/EN → quatre cartes de découverte auto-défilantes → guide initial de cinq étapes, passable. L'activité est portée par l'organisation ; un collaborateur ne peut pas remplacer le choix du Promoteur. Le modèle d'organisation (PME autonome, établissement multi-postes, réseau multi-sites) reste indépendant de l'activité métier.

**Constat de code à ne pas masquer [C] :** le rapport de construction NAXA SERVICES du 20 novembre 2026 indique que l'inspection de la branche de travail n'a pas retrouvé l'écran de choix initial d'activité dans le parcours Auth inspecté ; après authentification, l'application arrivait au tableau de bord ou à l'écran de changement de mot de passe. Le catalogue de 13 activités et le parcours décrit ci-dessus sont donc à préserver comme décision produit, mais leur présence dans le code livré doit être re-vérifiée et complétée avant de les considérer opérationnels.

### 5.3 Activités pertinentes pour la maintenance immobilière

Les profils du catalogue qui peuvent alimenter le Centre de maintenance comprennent notamment :
- Réparation : téléphones, électronique et électroménager ;
- Menuiserie ;
- Garage : seulement pour les demandes liées à un équipement ou véhicule, si ce service est pertinent au site ;
- Nettoyage ;
- Domicile ;
- Autre personnalisable, après qualification et validation.

Le catalogue existant ne décrit pas encore explicitement les spécialités plomberie, électricité, climatisation, serrurerie ou maçonnerie. Ne pas les déclarer déjà disponibles. Elles pourront être ajoutées comme sous-spécialités ou capacités détaillées après inventaire et validation du réseau réel [O].

### 5.4 Extension nécessaire dans NAXA SERVICES [P]

Pour rendre le réseau réellement exploitable par LOYABLE, NAXA SERVICES devra exposer un profil de prestataire structuré :
- activité principale sélectionnée par l'organisation ;
- sous-spécialités réellement proposées ;
- prestations et compétences ;
- types d'intervention acceptés (domicile, atelier, sur site) ;
- zones desservies et rayon/limites géographiques ;
- horaires et disponibilités ;
- capacité/charge de travail ;
- statut actif, suspendu ou indisponible ;
- contacts professionnels ;
- documents et éléments de vérification requis ;
- historique et indicateurs de qualité autorisés.

La sélection d'activité à la première connexion est une classification initiale de l'organisation, pas une preuve de compétence individuelle. Le registre doit distinguer l'activité déclarée, les spécialités proposées, les qualifications vérifiées et les personnes effectivement habilitées à intervenir.

### 5.5 Intégration du workflow entre applications [P]

- LOYABLE crée une demande et un ordre d'intervention référencés.
- Le bailleur choisit un concierge ou un prestataire compatible ; aucune affectation automatique sans règle validée.
- NAXA SERVICES reçoit un ordre de travail externe dans l'organisation du prestataire, sans exposer le contrat complet ni les informations non nécessaires du locataire.
- Le prestataire accepte/refuse, propose un créneau, établit un devis et met à jour les étapes dans NAXA SERVICES.
- Les statuts, devis, photos et dépenses utiles sont renvoyés à LOYABLE via des événements signés/idempotents.
- Le bailleur valide le devis et les dépenses selon ses seuils, puis contrôle la clôture dans LOYABLE.
- Le locataire voit uniquement les informations de suivi qui lui sont destinées.
- Chaque application conserve son propre journal d'audit ; les références croisées permettent de reconstituer le dossier complet.

### 5.6 Ce qui existe déjà et ce qui n'est pas encore démontré [C]

Le rapport NAXA SERVICES du 20 novembre 2026 documente déjà des fondations locales : catalogue de prestations avec prix/durée/prestataire habilité, agenda par prestataire ou poste, rendez-vous, équipe/prestataires, commissions, clients, demandes d'assistance, dépenses et certains suivis de travaux dans les exigences métier.

Cependant, le même rapport indique que l'API ERP distante, le moteur de synchronisation de bout en bout, les accusés de réception, l'idempotence serveur complète et les workflows métier persistés côté serveur restent à construire/recetter. L'outbox locale n'est pas un moteur de synchronisation. La connexion LOYABLE ↔ NAXA SERVICES n'est donc pas considérée comme existante.

---

## 6. Annonces immobilières et règles de facturation

### 6.1 Bailleurs partenaires [V]

- Publication gratuite, sans frais de mise en ligne.
- Le bailleur crée et modifie ses annonces à tout moment.
- Statistiques de vues accessibles au bailleur.
- Le système retire une annonce lorsque le bien devient occupé selon l'état fiable du bien dans LOYABLE.
- Un bien vacant peut être publié à nouveau selon la décision du bailleur.
- Les annonces ne doivent jamais présenter comme disponible un logement déjà loué/occupé.

### 6.2 Bailleurs non partenaires — publications assistées par NAXA [V]

- NAXA réalise les publications ; le bailleur externe ne dispose pas d'un espace partenaire LOYABLE dans ce parcours.
- Le paiement se fait hors plateforme ; il est déclaré par NAXA, pas collecté par LOYABLE.
- Tarif de base : **2 000 FCFA pour un quota initial de six publications**.
- À partir de la septième publication : **500 FCFA par publication supplémentaire**.
- Exemple retenu : trois chambres distinctes = trois publications.
- Les annonces assistées expirent au bout de deux mois.
- À l'échéance, elles peuvent être renouvelées sous réserve du paiement applicable.
- Elles peuvent être retirées avant terme si un audit humain établit que le logement est loué.
- Le système conserve un rapprochement contrôlable entre nombre de publications/renouvellements et montants déclarés.

**Point de calcul restant ouvert [O] :** confirmer si les six publications sont comptées cumulativement sur la période de deux mois (recommandation de contrôle) ou simultanément actives. La grille de renouvellement du quota et des annonces supplémentaires devra être confirmée avant développement de la facturation.

### 6.3 Contrôle externe [V]

Journal minimal :
- bailleur externe et coordonnées de référence ;
- bien et annonce ;
- auteur NAXA de la saisie ;
- date de création, renouvellement et retrait ;
- numéro de publication ;
- montant déclaré, date et mode de règlement déclaré ;
- référence/justificatif disponible ;
- motif de retrait anticipé ;
- rapprochement par bailleur et par période.

Le système produit un export de contrôle par période et par bailleur. Il ne certifie pas un encaissement bancaire qu'il n'a pas vérifié : il conserve une déclaration interne et les justificatifs fournis.

---

## 7. Rentabilité, calendrier et assistant IA du bailleur [V]

### 7.1 Rentabilité

- Par bien : loyers encaissés, charges, maintenance, dépenses, revenu net d'exploitation.
- Par immeuble/site : recettes, dépenses, taux d'occupation, comparaison des unités.
- Par portefeuille : revenus, retards, vacance, dépenses et performance globale.
- Prix d'acquisition, rénovations et investissements initiaux facultatifs pour calculer un rendement du capital ; sans ces données, afficher seulement des indicateurs d'exploitation et ne pas prétendre calculer le rendement total.

### 7.2 Calendrier immobilier

Inclure :
- échéances de loyers et retards ;
- fins de contrats et renouvellements ;
- rendez-vous avec les locataires ;
- visites commerciales des biens disponibles ;
- interventions de maintenance ;
- tâches, rappels et engagements du bailleur.

Les états des lieux restent exclus.

### 7.3 Assistant IA

L'assistant peut analyser les données autorisées, répondre aux questions, détecter des anomalies, produire des synthèses, préparer des messages et proposer des actions. Chaque recommandation doit expliquer les éléments qui la motivent.

L'IA ne confirme jamais un paiement, ne change pas un solde, ne modifie pas un contrat, ne valide pas un devis ou une dépense, ne supprime pas une annonce et ne clôture pas une intervention sans validation humaine explicite.

---

## 8. Architecture fonctionnelle et technique cible

### 8.1 Surfaces

- Application Android native LOYABLE Gestion en Kotlin/Jetpack Compose.
- Portail Locataire responsive, accessible sans installation.
- LOYABLE Immobilier responsive et indexable selon les règles de confidentialité.
- Console Publication NAXA, avec droits internes dédiés.
- Contrats API et domaine métier LOYABLE partagés ; les interfaces Android et Web/PWA restent des surfaces distinctes.

### 8.2 Domaines de données à concevoir

- organisations/propriétaires, utilisateurs et rôles ;
- sites, immeubles, biens, unités et équipements ;
- locataires, liens d'accès et consentements ;
- contrats, clauses, périodes et échéanciers ;
- paiements déclarés, preuves, confirmations, reçus et quittances ;
- charges, dépenses, devis, interventions et pièces justificatives ;
- ordres de maintenance, affectations, prestataires, transitions et clôtures ;
- annonces, photos, disponibilité, vues et contacts ;
- publications externes, déclarations de paiement et rapprochements ;
- calendrier, rappels et notifications ;
- indicateurs de rentabilité ;
- propositions IA, validation humaine et journal d'audit.

### 8.3 Séparation et sécurité

- Isoler les données par organisation propriétaire et périmètre autorisé.
- Le concierge n'accède qu'aux sites/biens et interventions qui lui sont affectés.
- Le prestataire NAXA SERVICES ne reçoit que les données minimales de son ordre d'intervention.
- Les preuves de paiement, contrats et pièces d'intervention sont privées ; liens de partage à portée limitée et révocables.
- La position exacte du logement n'est pas publiée par défaut.
- Les actions de personnel NAXA sont journalisées et limitées par rôle.
- Pas de SSO ni de fusion automatique des comptes LOYABLE et NAXA SERVICES.
- Aucun accès central général aux dossiers personnels ou aux données locatives.
- Synchronisation offline, outbox, idempotence, gestion des conflits et accusés de réception doivent être conçus et testés avant qualification globale.

### 8.4 Réutilisation du socle Famille NAXA

Réutiliser les composants communs uniquement après audit de compatibilité : authentification, rôles, journal d'audit, stockage privé, notifications, offline/synchronisation, observabilité et contrats API. Ne pas reprendre directement des tables métier pharmacie ou des données NAXA indépendantes sans audit.

---

## 9. Décisions validées, propositions et arbitrages encore ouverts

### Validées [V]

- Quatre espaces : Gestion, Locataire, Immobilier, Publication NAXA.
- Centre de maintenance dans l'espace locataire, piloté par le bailleur.
- États des lieux exclus.
- Rentabilité, calendrier et assistant IA dans l'espace bailleur.
- QR code du site + identifiant locataire + lien personnel WhatsApp.
- Pas de vérification supplémentaire OTP dans le parcours locataire.
- LOYABLE Immobilier accessible par QR et lien.
- Contact annonce → WhatsApp du bailleur ; appel marketing → WhatsApp commercial NAXA.
- Publications partenaires gratuites, modifiables, statistiques de vues et retrait quand le bien devient occupé.
- Publications externes réalisées par NAXA, règlement hors plateforme déclaré par NAXA, tarif de base 2 000 FCFA pour six annonces puis 500 FCFA par annonce supplémentaire.
- Expiration des annonces assistées au bout de deux mois, renouvellement payant ou retrait anticipé après audit humain établissant l'occupation.
- Paiements locatifs déclarés avec preuve, validation humaine du bailleur, reçu généré côté bailleur et disponible au téléchargement du locataire.
- Reçu par règlement confirmé et quittance lorsque toute la période exigible est réglée.
- NAXA SERVICES est le réseau métier à étudier pour les interventions techniques, sans confondre les deux applications.

### Propositions à intégrer au cahier détaillé [P]

- Workflow complet de maintenance avec devis, affectation, exécution, preuves, dépenses, contrôle et clôture.
- Profil prestataire structuré avec spécialités, zone, disponibilité et capacité.
- Ordre de travail inter-applications LOYABLE → NAXA SERVICES.
- API événementielle idempotente, journal de transitions et transmission minimale des données.
- Compte rendu de clôture visible au locataire et au bailleur selon les droits.

### Points ouverts [O]

1. Quelles sous-spécialités techniques exactes sont présentes dans le réseau réel NAXA SERVICES (ex. plomberie, électricité, climatisation, serrurerie, maçonnerie) et lesquelles sont réellement vérifiées ?
2. Le quota externe de six publications est-il cumulatif sur les deux mois ou simultanément actif ?
3. Confirmer le calcul du renouvellement des publications externes après deux mois.
4. Définir les seuils de dépenses que le concierge peut engager sans approbation préalable du bailleur.
5. Définir si le locataire peut noter/signaliser la qualité d'une intervention et si cette évaluation est privée ou publique.
6. Définir les règles de refacturation au locataire selon le contrat et la responsabilité de la réparation.

---

## 10. Plan de réalisation proposé

1. Cartographie fonctionnelle complète des quatre espaces et des parcours.
2. Matrice rôles/droits et règles de confidentialité.
3. Modèle de données LOYABLE et dictionnaire des statuts.
4. Spécification du Centre de maintenance et du registre de prestataires.
5. Contrat d'intégration LOYABLE ↔ NAXA SERVICES (API, événements, identifiants, idempotence, consentement et journalisation).
6. Annonces immobilières et contrôle des publications externes.
7. Rentabilité, calendrier, assistant IA et notifications.
8. Architecture Android/Web, synchronisation et tests.
9. Recette fonctionnelle et sécurité avant toute qualification de mise en service.

---

## 11. Références et limites documentaires

- Cahier LOYABLE historique : `7 famille naxa/01-cahiers-des-charges/06-loyable.md`.
- Prompts LOYABLE historiques : `7 famille naxa/02-prompts/06-loyable.md`.
- Cahier NAXA SERVICES : `7 famille naxa/01-cahiers-des-charges/04-naxa-services.md`.
- Prompts NAXA SERVICES : `7 famille naxa/02-prompts/04-naxa-services.md`.
- État de construction NAXA SERVICES au 20 novembre 2026 : `docs/naxa-services/NAXA_SERVICES_CONSTRUCTION_STATUS_2026-11-20.md`.
- Continuité générale Famille NAXA : `docs/CONTINUITE.md`.

Le cahier LOYABLE historique contient des éléments désormais exclus (états des lieux) et ne couvre pas toute la vision validée du 21 novembre 2026. En cas de contradiction, les décisions utilisateur datées du 21 novembre 2026 consignées dans ce document prévalent pour la conception LOYABLE.

Le catalogue NAXA SERVICES de 13 activités et le parcours initial de sélection sont des décisions produit antérieures à préserver. Le rapport de construction du 20 novembre indique toutefois que l'écran de sélection n'était pas retrouvé dans le code inspecté : il faut donc vérifier/corriger l'implémentation NAXA SERVICES séparément, sans prétendre que cette fonction est déjà opérationnelle.

---

## 12. Règle de reprise

À la reprise, ne pas recommencer les décisions déjà validées. Commencer par la cartographie fonctionnelle LOYABLE et le workflow de maintenance inter-applications, en utilisant le catalogue d'activités NAXA SERVICES comme base de qualification des prestataires. Ne modifier ni déployer les environnements Supabase ou les applications sans suivre les règles de gouvernance Famille NAXA et les autorisations applicables.

**État de fin de cette mise à jour : document de continuité créé ; aucune fonctionnalité LOYABLE n'est déclarée développée ou testée par cette seule mise à jour documentaire.**
