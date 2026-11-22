# COTIZ 360° — Cahier des charges fonctionnel
## Version 2.1 — Baseline fonctionnelle consolidée

> **Produit :** COTIZ  
> **Positionnement :** plateforme communautaire, Tontine Management System (TMS), réseau de confiance et outil de gouvernance des tontines  
> **Éditeur / opérateur :** NAXA (entité juridique porteuse à confirmer dans les contrats définitifs)  
> **Marché initial :** Cameroun — architecture extensible à la CEMAC et à d'autres marchés africains après validation locale  
> **Date :** 22 novembre 2026  
> **Statut :** baseline fonctionnelle issue des décisions explicites du porteur ; spécification documentaire, non preuve d'implémentation, de conformité juridique ou de disponibilité opérationnelle  
> **Référence historique :** Cahier des charges CotiZ V1.0 du 31 octobre 2026, 9 pages, archivé dans l'archive documentaire `New.zip`

---

# 0. Convention de lecture et statut des exigences

Ce document constitue la référence fonctionnelle COTIZ après intégration de la V1.0, des arbitrages COTIZ 360° et des extensions communautaires, sociales, de vérification, de découverte, de communication, de visioconférence et de monétisation.

Les statuts ci-dessous évitent de transformer une proposition technique ou un sujet réglementaire en décision déjà acquise :

- **[V] Validé** : orientation explicitement approuvée par le porteur.
- **[C] Conditionnel** : fonction prévue, mais activation interdite avant une validation juridique, réglementaire, contractuelle ou technique déterminée.
- **[P] Proposition de conception** : règle nécessaire pour rendre le système cohérent ; à confirmer lors de la conception détaillée ou de la recette.
- **[O] Ouvert** : paramètre qui exige une décision, une mesure technique, une estimation de coûts ou un avis professionnel avant mise en production.

Une exigence [V] décrit la cible fonctionnelle ; elle ne signifie pas que le code existe ni que le fonctionnement a été testé.

**Règle de priorité documentaire :** les décisions explicites prises dans le cadre COTIZ 360° V2.1 remplacent les hypothèses incompatibles de la V1.0 et les anciennes hypothèses tarifaires du business case. La V1.0 reste conservée comme historique, sans être effacée ni considérée comme la référence de construction actuelle.

# 1. Vision, ambition et proposition de valeur

## 1.1 Vision

COTIZ doit devenir une infrastructure numérique de confiance pour les tontines, associations, groupes d'initiatives, coopératives, fédérations et communautés partenaires au Cameroun.

COTIZ n'est pas uniquement un cahier de cotisations numérisé. Il combine six univers :

1. **COTIZ ID** — identité, vérification, profil communautaire et réputation explicable.
2. **COTIZ Network / Communities** — découverte, adhésion, associations, GIC, communautés et fédérations.
3. **COTIZ TMS** — gestion de bout en bout des tontines, cycles, cotisations, tours, trésorerie documentaire et gouvernance.
4. **COTIZ Social** — messagerie communautaire, annonces, messages vocaux et statuts institutionnels.
5. **COTIZ Meeting** — appels audio collectifs et visioconférences de groupe.
6. **COTIZ Intelligence** — assistant métier, prévention des anomalies, rapports, statistiques et expérience vocale multilingue.

La logique produit est : **une personne = un compte COTIZ ; plusieurs appartenances ; des règles autonomes par organisation et par tontine.**

## 1.2 Objectifs

- Remplacer les registres papier et tableurs fragiles par des événements métier traçables.
- Accompagner une tontine de sa demande de création à la clôture et à l'archivage de ses cycles.
- Donner aux membres une visibilité compréhensible sur leurs engagements et leurs historiques.
- Renforcer la discipline par des faits vérifiables, contextualisés et contestables.
- Créer un réseau de tontines et d'organisations partenaires avec candidature et admission humaine.
- Faciliter l'accès aux communautés, y compris pour les utilisateurs peu à l'aise avec le français ou l'anglais.
- Réduire les erreurs, doublons, contestations non documentées et concentrations de pouvoir.
- Permettre la croissance organique via les invitations, le partage de profils autorisés et la découverte locale.
- Monétiser les outils de gestion, les capacités et les services de visibilité, sans faire payer l'identité ou l'accès de base à la confiance.

## 1.3 Principes non négociables

1. COTIZ ne détient pas les fonds des tontines et ne réalise pas de transferts pour leur compte par défaut.
2. Une déclaration de paiement n'est jamais assimilée à un paiement confirmé.
3. Une opération confirmée ne peut être modifiée ou effacée silencieusement.
4. Les fonds et données d'une tontine restent séparés de ceux des autres tontines et de l'organisation mère.
5. Une personne non vérifiée peut consulter les surfaces publiques, mais ne peut pas intégrer une communauté, cotiser, participer aux espaces privés ni créer une tontine.
6. Seul un utilisateur vérifié peut soumettre une demande de création ; NAXA doit approuver chaque tontine avant son activation.
7. Les organisations associatives, GIC et communautés institutionnelles sont intégrées par NAXA après examen du partenariat et des représentants.
8. Les postes sont proposés et acceptés ; aucun membre ne reçoit un mandat sensible sans acceptation explicite.
9. La popularité, la publicité payante, la réputation et la vérification d'identité sont des notions distinctes.
10. Les décisions financières, disciplinaires, d'admission et de gouvernance restent humaines et traçables.
11. L'IA conseille et explique ; elle n'approuve pas seule une opération sensible.
12. Les données sensibles d'identité et de localisation du domicile ne sont jamais exposées dans les espaces publics ou aux autres membres.

## 1.4 Hors périmètre par défaut

Sauf évolution approuvée et validation réglementaire préalable, COTIZ ne doit pas :
- gérer un portefeuille électronique détenu par NAXA ;
- conserver ou mutualiser les fonds des membres ;
- encaisser les cotisations des tontines sur un compte de transit NAXA ;
- exécuter des transferts, paiements ou décaissements au nom des tontines ;
- exercer une activité de collecte d'épargne, de crédit ou de microfinance ;
- garantir un prêt, une tontine, un responsable ou le remboursement d'un membre ;
- délivrer une notation de solvabilité ou un avis de crédit ;
- publier les historiques financiers, les CNI, les domiciles ou les pièces privées des membres ;
- permettre aux comptes personnels de publier des statuts publics ;
- transformer automatiquement une conversation en preuve comptable ou en décision officielle.

# 2. Périmètre fonctionnel : les 18 domaines métier et les extensions

Les 18 domaines métier validés sont maintenus intégralement :

1. Identité et membres.
2. Groupes, tontines et adhésions.
3. Cotisations.
4. Tours et tirages.
5. Discipline et réputation.
6. Trésorerie et rapprochement.
7. Épargne et objectifs.
8. Prêts et garanties.
9. Solidarité et assistance.
10. Réunions et gouvernance.
11. Communication et rappels.
12. Litiges et médiation.
13. Annuaire des tontines.
14. Fédération et réseau.
15. Abonnements et parrainage.
16. Rapports et comptabilité de gestion.
17. IA et prévention des risques.
18. Administration et sécurité.

Les extensions approuvées s'ajoutent à ces domaines sans les remplacer :
- vérification d'identité COTIZ ID et coche bleue ;
- agrément NAXA des organisateurs et approbation de chaque tontine ;
- intégration contractuelle des associations, GIC, groupes d'initiatives et communautés ;
- messagerie de type réseau social communautaire ;
- statuts institutionnels photo/vidéo éphémères de 24 heures ;
- découverte géographique et recherche par nom, ville et proximité ;
- statistiques de vues, visiteurs uniques et cartes populaires animées ;
- campagnes de visibilité COTIZ Boost ;
- appels audio de groupe et visioconférences de groupe ;
- assistant vocal multilingue français, anglais, Fulfulde et extension progressive aux langues camerounaises ;
- gestion de modération et de signalements des contenus et comportements ;
- programme de formation des responsables et certificats de participation documentée.

# 3. Profils, identités et autorisations

## 3.1 Catégories de comptes

| Profil | Création | Accès principal | Restrictions |
|---|---|---|---|
| Visiteur inscrit non vérifié | Libre | Découverte publique, statuts publics, recherche et consultation des fiches publiques | Aucun accès communautaire privé, aucune adhésion, cotisation, discussion privée, candidature ou création |
| Membre COTIZ vérifié | Libre après dossier validé par NAXA | Demandes d'adhésion, invitations, communautés et tontines acceptées, fonctions autorisées par ses rôles | Pas de création/activation d'une tontine sans approbation NAXA |
| Organisateur agréé | Compte vérifié + contrôle d'habilitation | Soumettre des projets de tontine et administrer les tontines approuvées | Chaque tontine reste soumise à une approbation distincte |
| Responsable de tontine | Désignation acceptée par l'utilisateur et validée selon les règles du groupe | Fonctions de son mandat | Aucun accès implicite aux fonctions non accordées |
| Membre d'une association/communauté | Compte vérifié + admission | Espaces privés, activités, annonces et réunions autorisés | Pas d'accès automatique aux finances des sous-tontines |
| Organisation partenaire | Intégrée par NAXA après partenariat | Page institutionnelle, espace communautaire et administration contractuelle | Ne peut pas se déclarer partenaire seule |
| Administrateur NAXA | Compte administratif dédié, habilitations et MFA | Contrôle des dossiers, vérification, agréments, modération, contrats, support et facturation selon délégation | Accès limité au besoin d'en connaître ; aucune consultation générale des messages privés ou des finances métier |
| Auditeur / contrôleur autorisé | Invitation, mandat temporaire, périmètre explicite | Consultation limitée aux données autorisées | Lecture seule par défaut, accès expirant et révocable |

## 3.2 Compte unique COTIZ

[V] Un utilisateur ne crée qu'un compte COTIZ personnel, quel que soit le nombre de tontines ou de communautés auxquelles il appartient.

Ce compte contient :
- identifiant COTIZ unique ;
- numéro de téléphone vérifié ;
- nom et prénoms déclarés ;
- photo de profil publique facultative ;
- langue et préférences d'accessibilité ;
- statut de vérification ;
- QR personnel ;
- profils communautaires autorisés ;
- liste des appartenances et rôles ;
- invitations et demandes d'adhésion ;
- historique personnel des engagements documentés ;
- consentements et autorisations de partage ;
- paramètres de confidentialité et de sécurité.

**Frontière avec Famille NAXA :** l'identité COTIZ unique s'applique à l'intérieur de COTIZ et de ses groupes. Elle ne fusionne pas automatiquement les comptes d'authentification des autres applications NAXA Family. La règle familiale actuelle d'identités applicatives distinctes reste applicable jusqu'à décision transversale contraire.

## 3.3 Inscription et compte non vérifié

[V] Toute personne peut créer gratuitement un compte de base, sans devoir présenter sa CNI au moment de la simple inscription.

Le compte non vérifié peut :
- consulter les statuts publics publiés par des organisations autorisées ;
- rechercher des tontines publiques par nom, ville et proximité ;
- consulter les fiches publiques et les conditions de groupes publics ;
- consulter les pages publiques d'associations, GIC et communautés partenaires ;
- consulter les conditions de vérification et ouvrir un dossier de contrôle ;
- modifier ses informations de profil non sensibles.

Il ne peut pas :
- rejoindre une association, un GIC, une communauté ou une tontine ;
- accepter une invitation communautaire ;
- déposer une demande d'adhésion ;
- participer à des conversations privées ou appels de groupe ;
- enregistrer ou déclarer une cotisation ;
- participer aux votes ou activités réservées aux membres ;
- créer, proposer ou administrer une tontine ;
- publier un statut personnel ou institutionnel.

Les invitations envoyées à un compte non vérifié restent en attente ; leur acceptation effective est bloquée jusqu'à vérification.

## 3.4 Vérification COTIZ ID par NAXA

[V] La vérification personnelle est gratuite et effectuée par NAXA. Elle permet d'obtenir la coche bleue.

Dossier attendu conformément à la demande du porteur :
- CNI recto et verso ou document d'identité légalement accepté ;
- photographie de profil, distincte des images de preuve KYC ;
- adresse de résidence déclarée ;
- plan de localisation du domicile ;
- géolocalisation ponctuelle du domicile ;
- numéro de téléphone vérifié ;
- consentements et déclaration d'exactitude.

La collecte du domicile et du GPS doit être soumise à une analyse de nécessité et de proportionnalité avant activation. Une solution assistée (repère, quartier, carte manuelle ou justificatif approprié) doit être proposée lorsque le GPS est indisponible ou imprécis. Il n'est pas prévu de suivre continuellement la position d'un utilisateur.

### Cycle de vérification

`Brouillon → Soumis → En examen → Complément demandé → Approuvé / Refusé → Recours éventuel`

États supplémentaires : expiré, suspendu, réexamen nécessaire, document remplacé.

Contrôles attendus :
- complétude et lisibilité des documents ;
- cohérence des informations ;
- détection de doublons de compte et d'identité ;
- vérification humaine en cas de doute ;
- comparaison photo/document uniquement avec un procédé autorisé et proportionné ;
- décision motivée ;
- journal de l'agent, date, méthode, version de procédure et résultat ;
- mécanisme de contestation ;
- revue périodique lorsque le document expire ou qu'un événement de risque le justifie.

### Confidentialité KYC

- Les CNI, images de preuve, plans et coordonnées GPS exactes sont stockés dans un espace privé séparé.
- Aucun fichier KYC n'est accessible par un lien public.
- Les membres, dirigeants de tontine, associations et partenaires n'accèdent jamais aux pièces KYC.
- Le partage de preuve de vérification se limite au statut et aux attributs expressément consentis.
- Accès des agents NAXA selon rôle, périmètre et motif.
- MFA pour les agents KYC ; journal de consultation et d'export.
- Liens de téléchargement temporaires si un accès à distance est autorisé.
- Politique de conservation, purge, archivage légal et réponse aux demandes des personnes à approuver avec le juriste.
- Pas de copie de CNI dans les pièces jointes de discussion.
- Aucune utilisation des documents d'identité pour entraîner une IA.

### Sens de la coche bleue

La coche bleue signifie uniquement : **identité contrôlée selon le processus NAXA défini**. Elle ne signifie pas :
- que la personne est solvable ;
- qu'elle est honnête en toutes circonstances ;
- que NAXA garantit ses obligations ;
- qu'un prêt est sécurisé ;
- qu'une tontine ou une transaction est assurée.

## 3.5 Trois statuts de confiance à ne pas confondre

| Marque / statut | Objet vérifié | Ne prouve pas |
|---|---|---|
| Bleu — personne vérifiée | Identité et dossier personnel | Solvabilité ou bonne conduite future |
| Vert — organisation partenaire | Existence/identité organisationnelle, représentants et partenariat | Garantie de ses fonds ou de ses actes financiers |
| Violet — tontine approuvée | Dossier de création, responsable, règlement et conditions d'exploitation de la tontine dans COTIZ | Garantie financière, assurance, agrément microfinance ou détention sûre des fonds |

L'apparence finale des badges, leur texte d'explication et les critères de renouvellement doivent être définis dans le design system.

# 4. Création et gestion des tontines

## 4.1 Condition de création

[V] Seul un compte personnel vérifié peut soumettre une demande de création de tontine.

[V] Toute tontine nouvelle est soumise à l'approbation de NAXA avant activation, avant ouverture des adhésions opérationnelles et avant démarrage d'un cycle.

La coche bleue n'accorde pas automatiquement le droit d'activer un groupe. La vérification personnelle et l'approbation de chaque tontine sont deux procédures indépendantes.

## 4.2 Dossier de création

Informations minimales :
- nom du groupe ;
- logo ou image facultative ;
- description, finalité et objectifs ;
- catégorie de tontine ;
- ville, région et zone de réunion ;
- point de localisation public approximatif ;
- responsable créateur et justificatif d'habilitation si applicable ;
- effectif minimal, maximal et cible ;
- règlement intérieur ;
- nature des engagements financiers prévus ;
- type de cotisation, périodicité et nombre de parts ;
- méthode d'attribution des bénéficiaires ;
- règles de retard et pénalité ;
- calendrier et date de lancement ;
- règles d'admission, d'exclusion et de recours ;
- politique de visibilité : privée, sur invitation ou publique ;
- rôles et responsabilités proposés ;
- règles de réunion et de vote ;
- déclaration de non-détention de fonds par COTIZ ;
- acceptation des conditions et politique de traitement de données.

### Cycle NAXA

`Brouillon → Soumis → Contrôle de complétude → Analyse → Complément demandé / Refusé / Approuvé → Activation`

Le contrôle doit comporter :
- identité bleue valide du créateur ;
- habilitation à représenter le groupe lorsque la situation le requiert ;
- clarté du règlement ;
- cohérence des paramètres et du calendrier ;
- conformité de la description avec le périmètre autorisé de COTIZ ;
- absence d'activité financière interdite par le paramétrage ;
- acceptation des conditions COTIZ ;
- approbation explicite par un agent autorisé ;
- journal de décision, motifs, conditions et version approuvée.

Un refus doit être motivé et pouvoir faire l'objet d'un recours selon une procédure publiée.

## 4.3 Types de groupes pris en charge

- tontine rotative classique ;
- tontine à ordre fixe ;
- tontine à tirage ;
- tontine à plusieurs parts ;
- tontine journalière, hebdomadaire, bimensuelle, mensuelle ou saisonnière ;
- tontine professionnelle ;
- tontine familiale ;
- tontine de commerçants/commerçantes ;
- tontine de salariés ;
- tontine associative ;
- groupe d'épargne collective (suivi documentaire sous condition légale) ;
- cagnotte événementielle ;
- groupe de solidarité ;
- tontine à objectif ;
- tontine avec plusieurs bénéficiaires par cycle ;
- tontine avec ordre conditionnel.

Chaque type doit disposer d'un modèle de paramètres et de règles ; les types ne doivent pas masquer la nature réglementaire réelle de l'activité.

## 4.4 Paramètres d'une tontine

| Paramètre | Règle |
|---|---|
| Identité | Nom, description, code, image, propriétaire et contacts |
| Visibilité | Privée, sur invitation ou publique |
| Effectif | Minimum, maximum, effectif actif |
| Périodicité | Journalière à annuelle, selon le type |
| Calendrier | Échéances, fuseau Africa/Douala au Cameroun, exceptions et jours fériés |
| Cotisation | Fixe ou variable, avec règles explicites |
| Parts | Une ou plusieurs par membre, avec droits et obligations séparés |
| Grâce | Délai de grâce et règles de retard |
| Pénalités | Type, base, montant, plafond, circonstances et recours |
| Tours | Méthode, ordre, éligibilité, remplacements et preuve |
| Admission | Invitation, candidature, recommandation, liste d'attente |
| Gouvernance | Quorum, majorité, secret/nominatif, mandat |
| Documents | Règlement versionné, procès-verbaux, preuves, contrats |
| Devise | FCFA au lancement ; autres devises uniquement après décision et validation locale |
| Abonnement | Plan, nombre de membres actifs, échéance et état |

## 4.5 Membres, invitations et postes

Un organisateur peut inviter :
- un utilisateur COTIZ existant ;
- une personne qui ne possède pas encore de compte, via un lien ou une invitation téléphone ;
- plusieurs personnes, par liste ou QR d'invitation.

Parcours :

`Invitation envoyée → Compte requis ou retrouvé → Vérification bleue requise → Règlement consulté → Acceptation de l'invitation → Adhésion active`

La personne doit accepter explicitement :
- son adhésion ;
- le règlement et ses versions applicables ;
- le rôle qui lui est proposé ;
- les obligations et autorisations associées.

### Catalogue de rôles préconfigurés

- Président(e) ;
- Vice-président(e) ;
- Secrétaire ;
- Trésorier(ère) ;
- Contrôleur financier ;
- Responsable des cotisations ;
- Responsable discipline ;
- Responsable communication ;
- Médiateur ;
- Responsable des réunions ;
- Membre ;
- Auditeur/observateur temporaire.

Le groupe peut définir des rôles personnalisés avec des permissions explicites.

### Règles de gouvernance des postes

- Un poste proposé n'est pas actif tant qu'il n'est pas accepté.
- Le rôle est propre à la tontine et ne donne pas les mêmes droits dans une autre organisation.
- Les nominations, refus, délégations, renouvellements et révocations sont historisés.
- Une durée de mandat peut être définie.
- Les droits sensibles exigent une séparation de tâches.
- Le trésorier ne peut pas être l'unique initiateur, approbateur et contrôleur de la même opération.
- Les changements de rôle n'effacent pas l'historique d'un ancien mandat.
- Une personne peut avoir plusieurs rôles si le règlement le permet, sauf incompatibilités configurées.

## 4.6 Parts multiples et droits

Le moteur doit distinguer :
- nombre de parts ;
- obligation de cotisation par part ;
- droit éventuel à un ou plusieurs tours ;
- part bénéficiaire ;
- part dans un objectif collectif ;
- droit de vote ;
- droit de représentation.

**Aucune règle implicite ne doit supposer qu'une part supplémentaire donne automatiquement une voix supplémentaire.** Le mode de vote est défini dans le règlement et soumis à la validation juridique du modèle de groupement lorsqu'elle est requise.

## 4.7 Cycle de vie d'une tontine

`Projet → Approuvée → Active → Cycle ouvert → Cycle clôturé → Archivée`

États alternatifs : suspendue, en litige, en restructuration, clôture anticipée, dissoute.

Aucune clôture ne doit supprimer :
- membres et mandats historiques ;
- cotisations et corrections ;
- bénéficiaires et tirages ;
- pièces justificatives ;
- procès-verbaux ;
- incidents et litiges ;
- rapports de rapprochement ;
- historique d'abonnement.

Toute réouverture d'un cycle clôturé doit être exceptionnelle, autorisée et journalisée.

# 5. COTIZ Communities — Associations, GIC et réseaux partenaires

## 5.1 Intégration par NAXA

[V] Les associations, groupes d'initiatives, GIC, coopératives, communautés professionnelles, éducatives, territoriales ou solidaires sont intégrés dans l'application par NAXA après partenariat et validation des représentants.

Un utilisateur ne peut pas s'auto-déclarer organisation partenaire.

Le dossier partenaire peut inclure selon le statut juridique et le risque :
- nom et objet de l'organisation ;
- documents d'existence ou d'enregistrement lorsque requis ;
- identité des représentants ;
- preuve de pouvoir ou de mandat ;
- adresse et zones d'activité ;
- convention de partenariat ;
- responsable principal et administrateurs ;
- règles de confidentialité et d'utilisation de COTIZ ;
- engagements de modération ;
- procédure de retrait ou résiliation du partenariat.

La nécessité de documents d'enregistrement doit être appréciée selon le statut réel de l'organisation et le droit applicable ; ne pas imposer artificiellement le même régime à un groupe informel et à une personne morale.

## 5.2 Espace institutionnel

Une organisation partenaire peut disposer :
- d'une page officielle ;
- d'une présentation et d'une identité visuelle ;
- de son statut de partenariat ;
- de ses responsables ;
- de catégories et sous-communautés ;
- de ses membres ;
- d'un calendrier d'activités ;
- d'annonces ;
- de statuts photo/vidéo ;
- d'une messagerie communautaire ;
- de réunions audio/vidéo ;
- de formulaires d'adhésion ;
- de documents publics et privés ;
- d'indicateurs d'activité autorisés ;
- de plusieurs tontines affiliées mais autonomes.

## 5.3 Autonomie des tontines affiliées

L'association mère n'accède pas automatiquement :
- aux montants individuels des cotisations ;
- aux soldes de trésorerie détaillés ;
- aux prêts, garanties et aides ;
- aux justificatifs privés ;
- aux conversations privées ;
- aux scores internes des tontines.

Elle peut recevoir des données consolidées uniquement lorsque le règlement, les consentements et les délégations l'autorisent. Les permissions sont explicites, documentées, limitées et révocables.

## 5.4 Parcours d'adhésion à une organisation

Un membre vérifié peut :
- découvrir l'organisation ;
- lire ses conditions et son règlement ;
- déposer une candidature ;
- joindre les éléments demandés ;
- suivre le statut ;
- répondre à une demande d'information ;
- accepter les conditions après approbation ;
- participer aux espaces ouverts à son rôle.

Décisions d'admission : acceptée, refusée avec motif, complément demandé, liste d'attente, retirée par candidat, expirée.

La décision reste humaine et contestable selon les règles du groupe.

# 6. Cotisations et engagements documentaires

## 6.1 Types d'opérations

- cotisation ordinaire ;
- cotisation exceptionnelle ;
- cotisation de solidarité ;
- cotisation spéciale ;
- cotisation anticipée ;
- cotisation variable ;
- paiement partiel ;
- paiement groupé ;
- avance ou régularisation ;
- arriéré et retard ;
- cotisation par part ;
- déclaration de paiement en espèces ;
- déclaration de paiement Mobile Money ou bancaire ;
- correction comptable documentée ;
- remboursement ou restitution documentaire, lorsque légalement et opérationnellement applicable.

## 6.2 États d'une cotisation

`Attendue → Déclarée → Justificatif reçu → À vérifier → Confirmée`

États complémentaires : partiellement réglée, contestée, rejetée, annulée par écriture corrective, en rapprochement, expirée.

Les états ne doivent jamais être fusionnés :
- **attendue** : obligation calculée ;
- **déclarée** : membre ou responsable affirme avoir payé ;
- **justifiée** : une preuve est jointe ;
- **confirmée manuellement** : un responsable autorisé a vérifié selon une procédure définie ;
- **confirmée par partenaire** : le fournisseur autorisé confirme par API/webhook ou relevé authentique ;
- **rapprochée** : l'événement correspond au relevé ou à la caisse contrôlée.

Une capture d'écran ou un SMS seul n'est pas une preuve irréfutable. Les preuves sont enregistrées avec source, date, auteur, montant, référence partiellement masquée et état de vérification.

## 6.3 Reçus et justificatifs

Chaque enregistrement produit :
- identifiant unique ;
- groupe et cycle ;
- membre et part concernée ;
- montant et devise ;
- date/heure serveur ;
- mode déclaré ;
- initiateur ;
- justificatif privé ;
- vérificateur ;
- état ;
- historique des corrections ;
- reçu téléchargeable selon les permissions.

## 6.4 Mobile Money et paiements

[V] Les paiements de la tontine ne transitent pas par les comptes COTIZ/NAXA par défaut.

Le produit peut :
- enregistrer une déclaration ;
- collecter une preuve ;
- vérifier l'opération à partir d'une API de partenaire autorisé lorsque cela est légalement permis ;
- rapprocher des états ou des relevés fournis par les partenaires ;
- signaler les incohérences ;
- produire un reçu documentaire.

COTIZ ne doit pas :
- demander un code PIN Mobile Money ;
- stocker un OTP ;
- se connecter aux comptes personnels du membre ;
- lire par défaut les SMS du téléphone ;
- accepter un SMS comme source de vérité automatique ;
- utiliser un compte personnel NAXA comme compte de transit ;
- simuler une confirmation quand le réseau est hors connexion.

Une intégration Mobile Money doit préciser l'entité qui reçoit l'argent, le prestataire habilité, l'identifiant transactionnel, les responsabilités, la gestion des remboursements et les règles de rapprochement.

Le règlement de l'abonnement COTIZ à NAXA est une transaction commerciale distincte des contributions de la tontine.

# 7. Tours, bénéficiaires et tirages

## 7.1 Cinq modes de détermination

| Mode | Règle |
|---|---|
| Ordre prédéfini | Séquence approuvée au démarrage du cycle |
| Tirage au sort | Attribution aléatoire avec preuve vérifiable |
| Vote collectif | Choix soumis au quorum et à la majorité du règlement |
| Ordre négocié | Échange ou permutation acceptés par toutes les parties requises et tracés |
| Ordre conditionnel | Éligibilité dépendant de critères publiés dans le règlement |

Le mode est choisi et approuvé avant le cycle ; toute modification ultérieure passe par la procédure de gouvernance.

## 7.2 Éligibilité

Le calcul prend en compte les règles du groupe :
- membres actifs à la date de gel ;
- nombre de parts ;
- bénéficiaires déjà servis ;
- exclusions temporaires décidées selon le règlement ;
- retards ou arriérés uniquement si leur effet a été préalablement défini ;
- démissions, décès et remplacements ;
- demandes ou contestations pendantes ;
- règles de substitution.

Les critères doivent être connus avant le cycle et non modifiés rétroactivement pour favoriser un membre.

## 7.3 Tirage vérifiable (COTIZ Draw)

1. Figer la liste des membres et parts éligibles.
2. Publier les paramètres du tirage et la règle d'éligibilité.
3. Générer un engagement cryptographique avant le tirage (hash des paramètres et engagement sur la graine).
4. Utiliser un générateur aléatoire cryptographiquement sûr, exécuté côté serveur.
5. Enregistrer algorithme, version, paramètres, horodatage serveur, acteur et preuve.
6. Publier au moment approprié la graine ou les éléments de vérification permettant de reproduire le résultat sans permettre une manipulation préalable.
7. Générer un procès-verbal et un certificat du tirage.
8. Permettre à chaque membre de vérifier le résultat et de déposer une contestation.
9. Interdire les relances silencieuses ou répétitions sans procédure exceptionnelle, motif, autorisation et conservation du résultat précédent.

Le protocole cryptographique doit faire l'objet d'une revue spécialisée avant implémentation. Le document définit l'exigence de vérifiabilité, pas un algorithme technique déjà certifié.

## 7.4 Gestion des changements

- échange de tour ;
- report ;
- remplacement ;
- bénéficiaire indisponible ;
- décès ou incapacité ;
- non-respect de l'obligation du bénéficiaire ;
- annulation exceptionnelle ;
- correction d'erreur ;
- contestation du tirage ;
- accusé de réception de la remise des fonds.

Le statut « bénéficiaire désigné » ne prouve pas que le bénéficiaire a reçu l'argent. La remise est enregistrée séparément, avec les preuves et confirmations prévues par le règlement.

# 8. Discipline, COTIZ Trust et certificats

## 8.1 Deux scores, deux finalités

1. **Indice personnel COTIZ** : indicateur partageable de faits documentés dans plusieurs groupes, avec consentement.
2. **Indice interne du groupe** : indicateur propre au règlement d'une tontine, non visible aux autres groupes sans autorisation explicite.

Les données de deux tontines ne sont pas fusionnées dans un score interne universel.

## 8.2 Indice personnel sur 1 000

Le score personnel est envisagé sur 1 000 points, mais sa formule exacte et ses coefficients doivent être versionnés et testés avant lancement.

Dimensions possibles :
- régularité des cotisations ;
- respect des échéances ;
- engagements de bénéficiaire honorés ;
- participation et présence ;
- respect du règlement, après procédure contradictoire ;
- fiabilité des engagements documentés.

Règles obligatoires :
- le nouveau membre commence par « historique insuffisant », et non par 0 ;
- seuls des événements vérifiés et attribuables sont pris en compte ;
- une déclaration contestée ne vaut pas automatiquement défaut ;
- une plainte ne constitue pas un fait prouvé ;
- les sanctions ne sont prises en compte que lorsqu'elles sont définitivement établies selon les règles ;
- un mécanisme de rectification et de recours est disponible ;
- les faits anciens peuvent perdre du poids selon une formule transparente et versionnée ;
- le membre peut consulter les éléments qui expliquent son score ;
- le membre choisit les informations qu'il partage ;
- accès de partage limité dans le temps et révocable pour les consultations futures ;
- le score ne peut pas être acheté, sponsorisé, boosté ou modifié par paiement ;
- aucun critère de richesse, origine, ethnie, religion, opinion politique, santé, vie privée ou relation sociale ne doit intervenir ;
- le score n'est ni une note de crédit, ni une garantie, ni une recommandation financière.

Un exemple de profil à 920/1 000 est seulement une illustration de maquette ; il ne constitue pas un barème final.

## 8.3 Admission et réputation

Une tontine peut configurer des critères d'admission et, si elle le souhaite, un seuil de discipline. Le seuil n'est pas universel et ne doit jamais être imposé par COTIZ à tous les groupes.

Le candidat :
- voit les critères avant sa candidature ;
- choisit s'il partage son passeport de discipline ;
- peut fournir des références ;
- peut demander une rectification de données inexactes ;
- peut contester une décision selon la procédure prévue.

Un utilisateur sans historique COTIZ peut être admis sur la base d'autres critères humains.

## 8.4 Certificats

À la clôture d'un cycle, la tontine peut générer un certificat qui atteste uniquement des faits documentés, par exemple :
- nombre de cycles terminés ;
- taux de cotisations à temps, calculé selon les règles affichées ;
- tours honorés ;
- participation aux réunions ;
- date et version du règlement ;
- identité de l'émetteur ;
- empreinte ou signature de vérification.

Le certificat n'est pas un titre financier ni une garantie de solvabilité.

# 9. Trésorerie, rapprochement et clôture

## 9.1 Registres

- encaissements attendus ;
- paiements déclarés ;
- paiements confirmés ;
- paiements rapprochés ;
- fonds physiques remis et déclarés ;
- décaissements ;
- bénéficiaires ;
- dépenses ;
- caisse de solidarité ;
- pénalités enregistrées ;
- avances, régularisations et écarts ;
- pièces justificatives ;
- soldes documentaires par caisse et par responsable.

Le tableau doit distinguer systématiquement :
1. ce qui est attendu ;
2. ce qui a été déclaré ;
3. ce qui a été vérifié ;
4. ce qui a été remis à une personne ;
5. ce qui reste à rapprocher.

Le solde affiché est un **solde documentaire issu des écritures** ; il ne prouve pas que COTIZ détient ou contrôle les fonds.

## 9.2 Contrôle interne et séparation de tâches

- double validation des opérations sensibles, selon les seuils du groupe ;
- approbateur distinct de l'initiateur lorsque possible ;
- inventaire périodique de caisse ;
- confirmation de remise à bénéficiaire ;
- contrôle par le président ou contrôleur financier ;
- pièces obligatoires selon les règles ;
- registre des écarts ;
- plan de correction et commentaires ;
- clôtures journalières, hebdomadaires, mensuelles et par cycle ;
- journal append-only ;
- écritures de contrepassation plutôt que modification de lignes confirmées.

## 9.3 Rapprochement

Le rapprochement compare les écritures COTIZ avec :
- caisse déclarée ;
- reçus ou remises ;
- relevés transmis ;
- informations de prestataires habilités ;
- attestations des responsables.

Chaque écart porte un état, une gravité, un responsable de résolution, une échéance et une preuve de clôture. Aucun écart ne disparaît automatiquement.

## 9.4 Clôture de cycle

La clôture vérifie :
- toutes les cotisations attendues ;
- les restes dus ;
- les paiements partiels ;
- les tours prévus et effectués ;
- les remises de fonds attestées ;
- les pénalités ;
- la solidarité ;
- les dépenses ;
- les prêts/garanties éventuellement autorisés ;
- les litiges ouverts ;
- les écarts de rapprochement ;
- les votes ou résolutions nécessaires.

Un rapport de clôture est généré, validé par les personnes désignées et archivé. Une clôture peut être conditionnelle si le règlement l'autorise ; les anomalies non résolues doivent rester visibles.

# 10. Épargne et objectifs

Le module est prévu dans la conception, mais ses fonctions de collecte, de conservation, de mutualisation ou de restitution de fonds ne peuvent être activées qu'après avis juridique et validation du modèle.

Objectifs à suivre :
- épargne scolaire ;
- logement ;
- équipement ;
- investissement ;
- projet collectif ;
- événement ;
- précaution ;
- objectif familial ;
- objectif individuel ;
- objectifs saisonniers.

Chaque objectif comporte :
- cible et devise ;
- bénéficiaires ou contributeurs ;
- calendrier ;
- règles d'accès et retrait ;
- contribution attendue/déclarée/confirmée ;
- progression documentaire ;
- justificatifs ;
- clôture et bilan.

Par défaut, le module est un outil de suivi documentaire. Il ne crée pas un compte d'épargne COTIZ ni un droit de retrait contre NAXA.

# 11. Prêts, garanties et engagements de crédit

Le module documentaire comprend :
- demande de prêt ;
- objet ;
- montant ;
- durée ;
- calendrier ;
- conditions proposées ;
- coût/intérêt éventuel ;
- commission de crédit ;
- garanties et cautions proposées ;
- identité des garants ;
- consentement explicite de chaque garant ;
- décision du comité ou vote requis ;
- contrat et version ;
- échéancier ;
- remboursements déclarés et confirmés ;
- paiements partiels ;
- échéances et retards ;
- procédures de recouvrement prévues par le règlement ;
- libération de garantie ;
- clôture du prêt.

**Verrou réglementaire [C] :** la saisie de dossiers et l'archivage n'autorisent pas COTIZ/NAXA à octroyer des crédits, percevoir des intérêts, collecter l'épargne ou exercer une activité assimilable à la microfinance. Le paramétrage de production doit séparer « suivi documentaire » et « activité financière activée ». Aucune opération de crédit avec intérêt, caution ou garantie n'est commercialisée avant avis écrit d'un conseil spécialisé CEMAC/Cameroun et validation des autorisations éventuellement nécessaires.

# 12. Caisse de solidarité et assistance

Cas d'usage :
- décès d'un membre ou d'un proche ;
- maladie ou hospitalisation ;
- accident ;
- naissance ;
- mariage ;
- sinistre ;
- difficulté exceptionnelle ;
- assistance familiale ;
- soutien d'un membre en difficulté.

Une demande comprend :
- motif et catégorie ;
- description minimisée ;
- montant demandé, le cas échéant ;
- pièces facultatives et accès restreint ;
- personnes autorisées à examiner ;
- décision collective ;
- montant/document de l'aide attribuée ;
- preuve de remise ;
- clôture et recours éventuel.

Les informations de santé, de famille ou de vulnérabilité doivent être limitées au strict nécessaire. Elles ne sont pas diffusées dans le fil social général ni utilisées dans le score de discipline.

# 13. Réunions, assemblées et gouvernance

Fonctions :
- assemblées générales ;
- réunions ordinaires et extraordinaires ;
- convocations ;
- ordre du jour ;
- date, lieu ou lien de réunion ;
- participants, présences, absences et motifs ;
- quorum ;
- compte rendu ;
- procès-verbal ;
- résolution ;
- élection ;
- renouvellement de mandat ;
- révocation ;
- délégation ;
- modification du règlement ;
- vote secret ou nominatif ;
- gestion des conflits d'intérêts ;
- registre des décisions.

Chaque vote précise :
- qui peut voter ;
- règle de représentation ;
- quorum et majorité ;
- période d'ouverture ;
- possibilité de vote secret ;
- éventuelle pondération des parts ;
- procédure de contestation ;
- résultat, preuve et version de la résolution.

Le système n'invente pas le régime juridique du groupe. Il applique le règlement adopté et validé.

# 14. Litiges, contestations et médiation

Catégories :
- contestation d'une cotisation ;
- paiement non reconnu ;
- montant ou part incorrect ;
- contestation d'un tour ou tirage ;
- contestation de pénalité ;
- conflit sur rôle ou mandat ;
- prêt ou garantie ;
- solidarité ;
- comportement abusif ;
- exclusion ou admission ;
- fraude présumée ;
- modération d'un contenu.

Parcours :
`Signalement → Enregistrement → Triage → Réponse des parties → Médiation → Décision → Appel → Clôture`

Règles :
- une accusation ne vaut pas preuve ;
- les parties sont entendues ;
- la preuve est privée et limitée aux personnes habilitées ;
- l'agent médiateur déclare les conflits d'intérêts ;
- la décision est motivée et historisée ;
- l'appel est possible selon le règlement ;
- une affaire pendante ne provoque pas automatiquement une sanction ni une baisse de score ;
- l'accès aux pièces est limité et journalisé ;
- les représailles et la publication de données personnelles sont interdites.

# 15. COTIZ Discover — Annuaire, recherche et mise en relation

## 15.1 Surfaces

- tontines publiques ;
- tontines visibles sur invitation ;
- tontines privées non indexées ;
- associations partenaires ;
- GIC et groupes d'initiatives partenaires ;
- communautés professionnelles et territoriales ;
- unions et fédérations.

La visibilité d'un groupe ne change pas ses règles d'admission.

## 15.2 Recherche et filtres

Filtres obligatoires :
- nom de la tontine ou organisation ;
- région ;
- ville ;
- proximité ;
- type de tontine/organisation ;
- effectif ;
- places disponibles ;
- montant et fréquence de contribution lorsqu'ils sont publiables ;
- date de démarrage ;
- modalités d'admission ;
- statut de vérification/partenariat ;
- critères de discipline communiqués volontairement.

Les résultats de proximité utilisent une localisation autorisée ou un emplacement de recherche fourni par l'utilisateur. La géolocalisation du domicile collectée pour le KYC ne doit jamais être exposée dans les résultats ou fiches publiques. L'adresse précise des membres ne figure pas dans les cartes.

Les groupes privés sont accessibles uniquement via invitation ou lien contrôlé.

## 15.3 Candidature et admission

Seuls les comptes vérifiés peuvent déposer une demande d'adhésion.

Le candidat :
1. consulte le règlement et les critères ;
2. vérifie la capacité et les disponibilités ;
3. partage uniquement les attributs de profil nécessaires ;
4. choisit éventuellement les éléments de son passeport de discipline ;
5. soumet ;
6. suit le traitement ;
7. accepte le règlement final en cas d'admission.

La tontine peut accepter, refuser avec motif, demander un complément, ou placer en liste d'attente. Une personne sans historique peut être admise. Les décisions sont humaines, explicables et contestables.

## 15.4 COTIZ Match

Le moteur peut suggérer des groupes compatibles selon :
- ville/proximité choisie ;
- type de groupe ;
- rythme ;
- capacité et places ;
- montant et règles publiés ;
- préférences exprimées ;
- critères d'admission explicités.

Il ne transmet pas de données privées aux groupes sans consentement et ne décide pas de l'admission.

# 16. COTIZ Status — Statuts institutionnels de 24 heures

## 16.1 Émetteurs autorisés

[V] Les statuts sont réservés aux pages de :
- tontines approuvées ;
- associations partenaires ;
- GIC et groupes d'initiatives intégrés ;
- communautés et fédérations partenaires.

Les comptes personnels ne disposent pas d'une fonction « Mon statut » public.

## 16.2 Contenus

- photos ;
- vidéos ;
- annonces ;
- activités et événements ;
- actions communautaires ;
- appels à adhésion ;
- campagnes ;
- témoignages autorisés ;
- informations sur les tontines et services de la communauté.

## 16.3 Durée et visibilité

- durée de visibilité publique : 24 heures à compter de la publication ;
- audience : tous les utilisateurs COTIZ, y compris les comptes non vérifiés ;
- les statuts expirés ne sont plus consultables comme contenus publics ;
- toute prolongation doit être une nouvelle publication ;
- les médias sont soumis à politique de taille, durée, format, sécurité et quota ;
- les contenus signalés peuvent être préservés dans un dossier de modération à accès restreint, pendant la durée légalement justifiée.

## 16.4 Contrôle éditorial

- seuls les responsables disposant de la permission « publier un statut » peuvent poster ;
- chaque publication conserve l'auteur, la date et l'organisation ;
- modération, signalement, retrait, appel et blocage ;
- droits d'image et consentement des personnes filmées ;
- pas de publication de documents KYC, coordonnées du domicile, données financières individuelles ou informations sensibles ;
- réponse à un statut par réaction ou ouverture d'une conversation autorisée ; pas de commentaires publics ouverts par défaut [P].

## 16.5 Vues

Les organisations peuvent consulter :
- vues totales ;
- visiteurs uniques ;
- vues sur 24 heures, 7 jours et 30 jours ;
- progression d'audience ;
- clics vers la page ou formulaire d'adhésion lorsque l'utilisateur a consenti à l'action mesurée.

Le système déduplique les vues selon des règles antifraude et ne doit pas transformer le rafraîchissement répété par un même compte en popularité artificielle. Les données d'audience sont agrégées et ne révèlent pas inutilement l'identité individuelle des lecteurs.

# 17. COTIZ Discover Popular — Cartes animées et classement

[V] Les tontines les plus consultées peuvent être présentées dans des cartes qui alternent avec une animation.

Comportement cible :
- carrousel de cartes ;
- transition douce, non agressive ;
- nom, ville, type, membres, places et statut de vérification ;
- nombre de vues sur période choisie ;
- accès rapide à la fiche ;
- arrêt ou pause de l'animation ;
- prise en charge des préférences « réduire les animations » ;
- navigation accessible au clavier et aux lecteurs d'écran sur Web ;
- aucune information personnelle ou financière privée dans la carte.

Trois surfaces doivent rester distinctes :
1. **Populaires organiques** : calculées à partir des vues qualifiées et d'autres signaux de qualité d'usage explicites.
2. **À proximité** : calculées selon la recherche géographique consentie.
3. **Sponsorisé** : affichage commercial acheté via COTIZ Boost, toujours identifié comme tel.

La popularité n'est pas la confiance. Le score Trust n'est pas calculé à partir des vues. Un paiement publicitaire ne change ni le score personnel, ni le score de groupe, ni les critères de vérification.

# 18. COTIZ Boost — Visibilité sponsorisée

La promotion est facultative et séparée de l'abonnement de gestion.

Formats possibles :
- mise en avant locale ;
- mise en avant dans une ville ;
- campagne régionale ;
- campagne nationale ;
- mise en avant d'un événement ou d'une période de recrutement ;
- promotion d'un statut ou d'une page partenaire, sous règles de diffusion.

Tarifs pilotes proposés lors du cadrage, à mesurer avant adoption publique :

| Campagne | Durée | Tarif indicatif |
|---|---:|---:|
| Local | 7 jours | 1 000 FCFA |
| Ville | 7 jours | 2 500 FCFA |
| Région | 7 jours | 5 000 FCFA |
| National | 7 jours | 10 000 FCFA |

Ces tarifs restent des prix pilotes à tester et ne constituent pas une garantie de vues ou de recrutement.

Règles :
- mention « Sponsorisé » lisible ;
- période, zone, budget, cible et résultat documentés ;
- pas de promotion de contenu interdit ou d'activité financière non approuvée ;
- pas d'achat de coche bleue, de badge partenaire ou de score ;
- pas d'achat du classement organique ;
- plafonds de fréquence ;
- facturation distincte de l'abonnement ;
- contrôle anti-fraude et remboursement selon conditions contractuelles.

# 19. COTIZ Social — Messagerie communautaire

## 19.1 Fonctions

- conversations individuelles consenties ;
- discussions de groupe réservées aux membres ;
- messages texte ;
- messages vocaux ;
- photos et vidéos ;
- pièces et documents autorisés ;
- réactions ;
- réponses et citations ;
- mentions ;
- sondages ;
- annonces officielles ;
- notifications ;
- épinglage de messages ;
- recherche dans les conversations autorisées ;
- blocage, mise en sourdine et signalement ;
- outils de modération des espaces communautaires.

## 19.2 Contrôle de confidentialité

- les messages privés ne sont pas visibles par tous les responsables ;
- l'accès d'administration aux discussions n'existe pas par défaut ;
- les procédures de signalement doivent révéler uniquement les éléments nécessaires à la revue ;
- droits d'accès, export et conservation sont définis par type de conversation ;
- pièces jointes en stockage privé ;
- aucun partage automatique vers d'autres tontines ;
- blocage et contrôle des invitations ;
- limitation anti-spam et anti-harcèlement.

La portée exacte du chiffrement de bout en bout est un choix d'architecture [O] à trancher avant la production ; aucune promesse de chiffrement E2EE ne doit figurer dans la communication tant que le protocole n'est pas choisi, audité et testé.

## 19.3 Séparation conversation / système métier

La conversation peut organiser le débat, mais ne vaut pas preuve comptable ou décision d'entreprise.

Les actions suivantes doivent être faites dans un module métier :
- confirmation d'une cotisation ;
- approbation d'un décaissement ;
- validation d'un tirage ;
- adoption d'un règlement ;
- résultat d'une assemblée ;
- approbation d'un prêt ;
- nomination ou révocation d'un responsable ;
- clôture de cycle.

Un lien vers l'objet métier peut être partagé dans le chat, mais les autorisations et les journaux métiers restent la référence.

# 20. COTIZ Meeting — Appels audio et visioconférences

## 20.1 Modes

- appel audio de groupe ;
- visioconférence de groupe ;
- réunion programmée ;
- salle de réunion liée à une tontine ou communauté ;
- assemblée générale à distance.

Les appels sont réservés aux participants autorisés par la communauté, l'organisateur ou l'invitation.

## 20.2 Fonctions

- planification ;
- invitations et rappels ;
- lien et code de réunion ;
- salle d'attente ;
- admission/refus par hôte ;
- liste des participants ;
- microphone/caméra ;
- couper le micro ;
- lever la main ;
- prise de parole ;
- désignation de modérateur ;
- partage d'écran si autorisé ;
- quitter et terminer la réunion ;
- état de connexion ;
- compte rendu et présence ;
- notifications après la réunion.

## 20.3 Enregistrement

L'enregistrement est désactivé par défaut. Toute activation doit :
- être annoncée avant démarrage ;
- recueillir les consentements/autorisation requis ;
- indiquer qui peut accéder à l'enregistrement ;
- définir durée et lieu de conservation ;
- tracer les téléchargements et suppressions ;
- permettre de refuser l'enregistrement selon la politique applicable.

## 20.4 Conditions techniques

- qualité adaptative ;
- mode audio prioritaire ;
- faible consommation de données ;
- reconnexion ;
- test de qualité réseau ;
- signal de caméra/micro ;
- limites de durée et participants par abonnement ;
- fournisseur de visioconférence évalué pour la sécurité, les coûts, la disponibilité, les transferts internationaux et la localisation de données.

Aucun fournisseur ou plafond de visioconférence n'est réputé déjà choisi.

# 21. Notifications et rappels

Canaux :
- notifications Android ;
- notifications Web/PWA ;
- centre de notifications interne ;
- e-mail selon disponibilité et consentement ;
- liens WhatsApp préparés ;
- intégration officielle WhatsApp lorsque l'API, les modèles, le consentement et les coûts sont validés.

Événements :
- invitation et candidature ;
- vérification et dossier KYC ;
- approbation/refus de tontine ;
- adhésion, rôle et changement de mandat ;
- échéance et retard de cotisation ;
- cotisation déclarée, vérifiée ou contestée ;
- tour et tirage ;
- réunion, vote et procès-verbal ;
- prêt/échéance lorsque module autorisé ;
- litige et médiation ;
- statut publié/expiré ;
- appel de groupe ;
- abonnement, facture, renouvellement et dépassement de palier ;
- parrainage et récompense ;
- modération et sécurité.

Règles :
- priorité selon criticité ;
- langue préférée ;
- préférences de fréquence et horaires silencieux ;
- déduplication et idempotence ;
- statut d'envoi, de livraison et de lecture uniquement si techniquement confirmé ;
- pas de promesse de livraison si le canal ne fournit pas de preuve.

WhatsApp préparé n'est pas un envoi automatique. L'utilisateur conserve le contrôle lorsqu'un lien ouvre WhatsApp.

# 22. COTIZ Intelligence — Assistant IA et prévention des risques

## 22.1 Assistant métier

Questions attendues :
- combien le groupe a-t-il déclaré ou confirmé ce mois-ci ?
- quels paiements restent à vérifier ?
- qui est en retard selon le règlement ?
- quel est le prochain bénéficiaire prévu ?
- quels prêts documentés arrivent à échéance ?
- quels rapprochements présentent des écarts ?
- quand est prévue la prochaine réunion ?
- quel est le bilan du dernier cycle ?
- quelles tontines publiques correspondent à mes critères ?
- quelles décisions ont été prises en assemblée ?

L'assistant doit vérifier les permissions avant de consulter toute donnée. Il ne doit pas révéler les données d'une autre tontine ou d'un membre non autorisé.

## 22.2 Fonctions

- rapports automatiques ;
- synthèse de réunion ;
- projet de procès-verbal soumis à validation ;
- rappels contextualisés ;
- analyse de retards ;
- détection de doublons ;
- rapprochement assisté ;
- anomalies de déclaration ou de vue ;
- simulation documentaire de trésorerie ;
- aide à la rédaction de règlements ;
- explication des règles ;
- recherche de communautés ;
- traduction et explication linguistique.

## 22.3 Actions interdites à l'IA sans confirmation humaine explicite

- confirmer ou annuler une cotisation ;
- modifier le ledger ;
- lancer ou relancer un tirage ;
- prononcer une sanction ;
- approuver une candidature ;
- approuver un prêt ;
- engager une garantie ;
- modifier une règle de vote ;
- changer les postes et permissions ;
- confirmer une remise de fonds ;
- déclencher un transfert ou paiement.

Chaque proposition IA doit exposer les données utilisées, la période, les limites et un niveau de confiance compréhensible. Une fonction IA ne peut pas être présentée comme ayant effectué une opération si le serveur n'a pas confirmé l'opération.

# 23. Langues camerounaises et COTIZ Voix

## 23.1 Langues de produit

- interface initiale : français et anglais ;
- priorité de développement vocal : Fulfulde ;
- extension progressive : Ewondo, Duala, Bassa'a, Bulu, Ghomala', Medumba, Bamoun, Pidgin et autres langues nationales selon faisabilité, disponibilité de ressources et validation par des locuteurs natifs.

L'architecture doit accueillir d'autres langues camerounaises sans refonte du modèle de données. Les langues ne sont pas déclarées disponibles tant qu'elles n'ont pas été testées à un niveau de qualité acceptable.

## 23.2 Chaîne vocale

1. détection/choix de la langue ;
2. reconnaissance vocale ASR ;
3. compréhension de la demande ;
4. interrogation du moteur métier avec les autorisations de l'utilisateur ;
5. génération de réponse contrôlée ;
6. synthèse vocale TTS ;
7. retour texte/audio et possibilité de correction.

## 23.3 Fonctions vocales

- demander le montant restant dû ;
- écouter l'historique autorisé ;
- consulter les dates de réunion ;
- comprendre une règle ;
- dicter une candidature ;
- écouter une annonce ;
- demander le résumé d'un cycle ;
- comprendre un rappel ;
- envoyer un message vocal ;
- naviguer dans les fonctions de base.

## 23.4 Exigences linguistiques

- traductions relues par des personnes compétentes ;
- vocabulaire des tontines validé localement ;
- prise en compte des variantes régionales et accents ;
- corpus obtenus avec autorisation et licences compatibles ;
- consentement à l'enregistrement et à l'utilisation de la voix ;
- suppression/retention contrôlées ;
- aucune voix personnelle clonée sans consentement spécifique ;
- comparaison qualité/latence/coût par langue ;
- repli vers français ou anglais si une langue est insuffisamment prise en charge ;
- messages audio courts et mode faible bande passante ;
- aide humaine pour les erreurs de compréhension.

Aucune promesse de maîtrise immédiate de toutes les langues camerounaises ne doit être faite.

# 24. Rapports, exports et comptabilité de gestion

Rapports :
- situation du membre ;
- situation du groupe ;
- situation du cycle ;
- cotisations attendues/déclarées/confirmées ;
- retards et pénalités ;
- historique des parts ;
- tours et bénéficiaires ;
- trésorerie documentaire ;
- rapprochement ;
- dépenses ;
- solidarité ;
- prêts et garanties lorsque légalement activés ;
- réunions, votes et présence ;
- litiges ;
- discipline et certificats ;
- abonnement et facturation ;
- vues/statistiques de visibilité.

Formats : PDF, XLSX et CSV, avec :
- période et périmètre ;
- date de génération ;
- auteur et filtre ;
- fuseau horaire ;
- version de rapport ;
- statut de synchronisation ;
- distinction des montants déclarés et confirmés.

Le « grand livre » COTIZ est un registre de gestion communautaire, pas une comptabilité certifiée ou réglementaire. La structure comptable est un outil de suivi, à faire confirmer par un professionnel pour chaque activité concernée.

Un expert-comptable peut recevoir un lien de consultation temporaire, limité à un groupe, une période et un périmètre, révocable et sans droit de modification.

# 25. Abonnements, plans et facturation

## 25.1 Principes commerciaux

[V] Le modèle standard est l'abonnement **par tontine/groupe et selon l'effectif actif**.

- un membre ne paie pas personnellement COTIZ pour être vérifié ;
- l'inscription individuelle est gratuite ;
- la vérification COTIZ ID est gratuite ;
- consulter le répertoire et les statuts publics est gratuit ;
- l'adhésion à une communauté n'est pas facturée individuellement par COTIZ ;
- le groupe paie les outils de gestion et les capacités de son abonnement ;
- les contributions de tontine restent distinctes des abonnements logiciels ;
- une fédération peut avoir un contrat central qui couvre plusieurs groupes autonomes.

## 25.2 Grille mensuelle de travail retenue pour les tests commerciaux

| Offre | Effectif actif maximal | Tarif mensuel |
|---|---:|---:|
| Découverte | 5 | Gratuit |
| Essentiel | 10 | 1 000 FCFA |
| Standard | 25 | 2 000 FCFA |
| Confort | 50 | 3 500 FCFA |
| Premium | 100 | 6 000 FCFA |
| Association | 250 | 10 000 FCFA |
| Fédération | Plus de 250 ou multi-groupes | Sur devis |

Cette grille est la baseline commerciale de travail validée pour cadrer le produit et tester le marché. Elle ne remplace pas le calcul du coût de revient, de marge et de support par plan.

## 25.3 Tarifs annuels proposés

Remise annuelle : 15 % sur 12 mensualités, soit 10,2 mensualités payées pour 12 mois de service.

| Offre | Mensuel | Annuel |
|---|---:|---:|
| Essentiel | 1 000 | 10 200 FCFA |
| Standard | 2 000 | 20 400 FCFA |
| Confort | 3 500 | 35 700 FCFA |
| Premium | 6 000 | 61 200 FCFA |
| Association | 10 000 | 102 000 FCFA |

Pas de formule de 3 ou 6 mois. Le plan Découverte reste gratuit.

**Exception de cohérence portefeuille :** le régime général Famille NAXA prévoit 10 mensualités payées pour 12 mois (16,67 % de réduction). COTIZ conserve, conformément à l'arbitrage produit formulé ici, une remise spécifique de 15 %. Cette exception doit être inscrite au registre des décisions commerciales avant la publication des tarifs et dans la configuration serveur des plans.

## 25.4 Capacités fonctionnelles

Les fonctions de sécurité, d'audit, de correction, d'historique et de protection des membres sont disponibles dans tous les plans. Les différences portent sur effectif, capacité de stockage, volume de médias, ressources d'appel/vidéo, exports avancés, IA et outils analytiques.

| Fonction | Découverte | Essentiel | Standard | Confort | Premium |
|---|---|---|---|---|---|
| Membres actifs | 5 | 10 | 25 | 50 | 100 |
| Registre cotisations | Oui | Oui | Oui | Oui | Oui |
| Parts et tours | Base | Oui | Oui | Oui | Avancé |
| Tirage audit-able | Oui, base | Oui | Oui | Oui | Avancé |
| Pénalités et discipline | Base | Oui | Oui | Oui | Avancé |
| Réunions/gouvernance | Base | Oui | Oui | Oui | Avancé |
| Messagerie de groupe | Quota limité | Quota | Quota étendu | Étendu | Étendu |
| Statuts média | Quota réduit | Quota | Quota | Étendu | Étendu |
| Appels audio | Quota réduit | Quota | Quota | Étendu | Étendu |
| Visioconférence | Non ou démonstration limitée | Limitée | Oui | Plus élevée | Plus élevée |
| Exports | Basique | PDF | PDF/Excel | Avancés | Avancés |
| Analytique | Basique | Basique | Standard | Avancée | Avancée |
| COTIZ IA | Non | Basique/quota | Standard/quota | Avancée/quota | Complète/quota |
| Discover organique | Oui | Oui | Oui | Oui | Oui |
| COTIZ Boost | Option payante séparée | Option | Option | Option | Option |

Les quotas exacts de stockage, durée vidéo, appels, participants, minutes IA et exports intensifs sont [O] et doivent être déterminés à partir de mesures de coûts, tests de charge et objectifs de marge. Ils ne peuvent pas être inventés au moment du développement.

## 25.5 Comptage, palier et renouvellement

- membres facturables = adhésions actives à la date de référence ;
- invitations non acceptées exclues ;
- candidatures en attente exclues ;
- membres suspendus exclus du comptage actif mais conservés dans l'historique ;
- changement de plan avec simulation et prorata affiché ;
- dépassement d'effectif : alerte et proposition de palier ; pas de blocage silencieux d'une opération critique ;
- données et historiques conservés à expiration ;
- période de grâce à définir dans la politique commerciale ;
- restrictions après expiration appliquées côté serveur ;
- parcours de renouvellement accessible ;
- consultation/export des données historiques selon politique légale et contractuelle ;
- aucun effacement des registres financiers à la suite d'un impayé.

## 25.6 Associations et fédérations

Les organisations partenaires peuvent bénéficier d'une convention et d'un espace institutionnel. Si elles utilisent le TMS, elles souscrivent à une offre selon effectif ou contrat institutionnel.

Une fédération peut obtenir :
- compte central ;
- plusieurs sous-groupes ;
- administration centrale et responsables locaux ;
- facturation centralisée ;
- tableau de bord agrégé autorisé ;
- tarifs dégressifs ;
- permissions cloisonnées par groupe.

Le tarif dégressif exact est [O] : il doit être établi par calcul de capacité, volume de support et marge ; aucune remise arbitraire n'est codée.

## 25.7 Paiement de l'abonnement

Le règlement de COTIZ est un paiement B2B de logiciel à NAXA. Les moyens, agrégateurs, confirmations serveur, remboursements et factures sont à intégrer après sélection contractuelle. Le statut « payé » doit provenir d'une confirmation serveur vérifiable, pas d'une simple référence saisie.

# 26. Parrainage et croissance organique

## 26.1 Parrainage membre

Chaque utilisateur peut disposer :
- code ;
- lien ;
- QR ;
- invitations ;
- tableau de suivi des filleuls.

La récompense ne doit pas être versée au simple enregistrement d'un compte. Déclencheurs possibles :
- compte vérifié ;
- activité réelle et anti-fraude ;
- adhésion acceptée ;
- groupe réellement créé et abonnement payé, selon programme.

Récompenses possibles :
- badge ambassadeur ;
- points de fidélité ;
- avantages non monétaires ;
- mois d'abonnement offert au groupe parrain, selon conditions contractuelles.

## 26.2 Parrainage de groupe

Parcours :
1. groupe parrain invite une organisation ;
2. celle-ci crée ou fait intégrer son dossier ;
3. identité et représentants sont vérifiés ;
4. convention/partenariat ou dossier de tontine est approuvé ;
5. groupe devient actif ;
6. abonnement payant confirmé lorsque requis ;
7. récompense créditée selon règle publiée.

## 26.3 Contrôles

- anti-auto-parrainage ;
- unicité du bénéficiaire ;
- détection de fermes de comptes ;
- pas de récompense pour faux comptes ;
- exclusion des paiements en attente/annulés/remboursés ;
- journal de récompenses ;
- conditions et plafonds visibles ;
- pas de rémunération assimilable à une activité réglementée sans examen.

# 27. Expérience utilisateur et interfaces

## 27.1 Espaces principaux

1. **Accueil personnel** : tontines, échéances, invitations, alertes et indicateurs de mes groupes.
2. **Communautés** : associations, GIC, réseaux et discussions.
3. **Mes tontines** : espace opérationnel de chaque groupe.
4. **Découvrir** : recherche, proximité, cartes populaires, statuts et candidatures.
5. **Profil COTIZ** : ID, vérification, consentements, réputation, historique, QR et langues.
6. **COTIZ IA** : conversation écrite et audio.
7. **Administration NAXA** : KYC, approbation, partenaires, modération, abonnements, risques et statistiques.

## 27.2 Règles d'interface

- Android natif, ergonomie tactile ;
- Web responsive/PWA autonome ;
- français et anglais dès le lancement ;
- chemin de vérification visible et explicable ;
- badges accompagnés d'un sens exact ;
- séparation nette des espaces public et privé ;
- filtres rapides nom/ville/proximité ;
- cartes de statut à navigation simple ;
- animation désactivable ;
- mode faible bande passante ;
- contrastes accessibles et libellés explicites ;
- messages d'erreur utiles ;
- état hors connexion clairement visible ;
- aucune action financière critique sans confirmation explicite.

## 27.3 Identité visuelle historique à réconcilier

La V1.0 mentionnait un symbole circulaire/monétaire et une palette de travail : bleu marine `#012952`, vert `#018A44`, rouge `#D81224`, jaune `#FDCC1D`, or `#B4840C`, fond clair `#E8F5EC`, avec Poppins comme piste typographique.

Cette palette est une référence historique, pas une charte graphique validée pour V2.1. Le contraste doit être recalculé : texte courant d'au moins 4,5:1 selon le référentiel WCAG usuel ; ne pas utiliser le jaune seul comme texte sur blanc ; associer couleur, icône et libellé. Le logo vectoriel et la disponibilité de la marque doivent être vérifiés avant gel graphique.

# 28. Administration NAXA et opérations de confiance

## 28.1 Console centrale

Espaces :
- utilisateurs et vérification ;
- dossiers KYC ;
- organisateurs ;
- demandes de tontine ;
- organisations partenaires ;
- modération ;
- appels à revue ;
- abonnements et factures ;
- COTIZ Boost ;
- gestion des langues et contenus ;
- gestion des templates de notification ;
- incidents ;
- support ;
- configuration des plans et quotas ;
- indicateurs et rapports ;
- audits et exports autorisés.

## 28.2 Séparation des fonctions d'administration

Les rôles internes peuvent inclure :
- agent KYC ;
- superviseur KYC ;
- analyste d'organisations ;
- approbateur de tontine ;
- responsable conformité ;
- modérateur ;
- support ;
- responsable facturation ;
- administrateur technique ;
- auditeur.

Une même personne ne doit pas approuver seule toutes les étapes sensibles lorsque la séparation est nécessaire. Les accès administratifs sont soumis au MFA, à une justification et à des journaux.

## 28.3 Journal d'audit

Journal append-only pour :
- accès KYC ;
- vérification et décisions ;
- création/approbation/suspension de groupe ;
- rôle et permissions ;
- opérations financières documentaires ;
- tirages ;
- votes ;
- exports ;
- abonnements et changements de prix ;
- modération ;
- actions d'administration.

Chaque entrée contient acteur, date serveur, type, cible, organisation/groupe, motif, source et identifiant de corrélation. Les événements ne peuvent pas être réécrits par un administrateur ordinaire.

# 29. Sécurité, confidentialité, conformité et gestion des risques

## 29.1 Protection des données

Concevoir les flux en respectant la loi camerounaise n° 2024/017 du 23 décembre 2024 relative à la protection des données à caractère personnel, sous réserve de l'analyse juridique du texte et de ses mesures d'application.

Exigences :
- finalités documentées ;
- collecte minimisée ;
- base juridique et consentement lorsque requis ;
- information compréhensible ;
- accès, rectification et autres droits applicables ;
- conservation limitée et justifiée ;
- sécurité au repos et en transit ;
- contrôle des accès ;
- journalisation ;
- gestion des sous-traitants ;
- transferts internationaux à examiner ;
- procédure de violation de données ;
- politique de sauvegarde et de purge ;
- évaluation d'impact si nécessaire avant les fonctions à risque élevé.

Le KYC, la localisation du domicile, la réputation et les conversations exigent une analyse spécifique.

## 29.2 Réglementation financière

Les textes CEMAC relatifs aux services de paiement (notamment le Règlement N°04/18/CEMAC/UMAC/COBAC du 21 décembre 2018) et le corpus réglementaire de la microfinance publié par la BEAC/COBAC doivent être examinés avec un juriste spécialisé.

Avant commercialisation, analyser séparément :
- tenue d'un registre logiciel ;
- collecte d'épargne ;
- mutualisation ou conservation de fonds ;
- prêt entre membres ;
- prêt avec intérêt ;
- caution et garantie ;
- activité d'intermédiation ;
- prestation de paiement ;
- encaissement centralisé et décaissement.

**Décision de conception :** le niveau 1 — ERP de gestion documentaire sans détention de fonds — est le périmètre de lancement recommandé. Les fonctions assimilables à l'activité financière sont inactives tant qu'un avis juridique écrit n'a pas confirmé le modèle autorisé et les éventuelles autorisations/partenariats requis.

## 29.3 Sécurité applicative

- authentification sécurisée ;
- MFA pour les opérations et comptes privilégiés ;
- protection du téléphone et des sessions ;
- révocation à distance ;
- limitation de tentatives ;
- séparation des rôles ;
- RLS stricte ;
- contrôle serveur, jamais uniquement UI ;
- stockage privé ;
- liens de téléchargement temporaires ;
- chiffrement des secrets et données sensibles ;
- gestion des clés hors client ;
- tests d'accès inter-groupes et inter-organisations ;
- détection des sessions anormales ;
- sauvegardes et tests de restauration ;
- journal d'incident ;
- stratégie de réponse aux fuites.

Aucune clé Supabase `service_role`, aucun secret de paiement, clé de signature ou jeton privilégié ne doit être inclus dans l'application ou le dépôt public.

## 29.4 Prévention des fraudes

Détecter et signaler :
- comptes en doublon ;
- faux documents ;
- usurpation ;
- faux justificatifs de paiement ;
- répétition de références ;
- manipulation des vues ;
- tirage manipulé ;
- concentration de rôles ;
- opérations sans double contrôle ;
- écarts de caisse ;
- conflits d'intérêts ;
- invitations massives abusives ;
- faux avis et campagnes coordonnées ;
- tentative de contournement d'abonnement ;
- accès inter-tenant.

Une alerte n'est pas une condamnation. Les décisions de sanction sont soumises à la procédure contradictoire.

## 29.5 Modération sociale

- signalement de contenu ;
- signalement de compte ;
- blocage et restriction ;
- retrait provisoire et définitif ;
- conservation minimale des preuves ;
- appel ;
- traitement des contenus illicites ;
- prévention des menaces, fraudes, harcèlement et divulgations d'identité ;
- règles dédiées aux médias et appels enregistrés ;
- politique de modération publique.

# 30. Architecture technique cible et mutualisation NAXA Family

## 30.1 Cibles technologiques du dépôt

- Android : application autonome native Kotlin et Jetpack Compose.
- Persistance locale Android : Room, cache et file d'opérations.
- Web : application séparée responsive/PWA ; pas de WebView qui encapsule le site dans l'APK.
- Backend : Supabase/PostgreSQL partagé selon les décisions de Famille NAXA, après audit de compatibilité et d'isolation.
- Authentification : parcours COTIZ conforme aux identités applicatives distinctes.
- RLS : cloisonnement par application, organisation, tontine et appartenance.
- Stockage : espaces privés séparés pour KYC, justificatifs, médias, documents et archives.
- Temps réel : messagerie et notifications, après contrôle des permissions.
- Notifications : FCM et centre interne.
- Appels audio/vidéo : fournisseur WebRTC/SFU à sélectionner et auditer.
- IA/voix : services modulaires interchangeables et quota par usage.
- Paiements : agrégateur ou prestataire habilité, si autorisé.
- Observabilité : journaux, métriques, traces et alertes.
- Fonctionnement hors connexion : opérations admissibles mises en file et synchronisées de façon idempotente.

## 30.2 Isolation des données

Toute ressource métier doit être rattachée à :
- application COTIZ ;
- organisation ;
- tontine ou sous-groupe ;
- cycle ;
- membre ou acteur autorisé.

Les droits sont évalués côté serveur et par RLS. L'appartenance à une association ne donne pas accès à une tontine enfant. Un utilisateur ne voit que ses données et celles de ses groupes autorisés. Les fonctions d'administration NAXA doivent être étroitement limitées.

## 30.3 Réutilisation de composants NAXA Family

La mutualisation est réelle seulement après audit du code, du contrat, de la sécurité et de la compatibilité du comportement.

| Source | Composants candidats |
|---|---|
| NAXA | tableaux de bord, rôles, audit, statistiques, rapprochement, assistant |
| NAXA HOTEL | calendrier, événements, responsables, multi-organisation |
| NAXA SERVICES | agenda, notifications, CRM, suivi de dossiers et tâches |
| JOBLY (référence documentaire/technique uniquement selon dépôt) | identité portable, QR, partage sélectif, réputation explicable |
| LOYABLE | échéanciers, rappels, documents, historiques, engagements |
| GRILLAD | caisse documentaire, opérations, dépenses, clôture, offline et synchronisation |
| ZIPPLE | événements, calendrier, encaissements documentaires et reporting |
| NAXA SECURITY | contrôle d'accès, appareils, alertes et journalisation de sécurité |

Aucune importation de tables, packages, secrets ou logique métier ne doit être faite sans audit. Le socle partagé ne permet pas la circulation automatique des données.

## 30.4 Mode hors connexion et synchronisation

Fonctions pouvant être préparées hors connexion :
- consultation du cache autorisé ;
- brouillons de formulaires ;
- préparation de réunions ;
- saisie d'une déclaration à synchroniser ;
- rédaction de messages en attente ;
- consultation des documents déjà disponibles.

Fonctions exigeant une connexion ou une confirmation serveur :
- vérification NAXA ;
- approbation/activation de groupe ;
- décision finale d'admission ;
- tirage officiel ;
- validation distante d'une transaction ;
- abonnement payé ;
- statut public publié ;
- début d'appel/visioconférence.

Règles :
- UUID/idempotency key sur chaque événement ;
- horodatage serveur de référence ;
- statut « en attente de synchronisation » ;
- pas de confirmation financière hors connexion ;
- résolution de conflit selon domaine ;
- aucune écriture confirmée remplacée silencieusement ;
- journal de synchronisation et possibilité de reprise.

## 30.5 Entités métier conceptuelles

Le modèle de données devra au minimum couvrir :
- `cotiz_profiles`, `kyc_cases`, `kyc_documents`, `consents`, `verification_events` ;
- `organizers`, `organizations`, `partnerships`, `organization_memberships` ;
- `tontines`, `tontine_applications`, `tontine_approvals`, `tontine_rules_versions` ;
- `memberships`, `invitations`, `roles`, `permissions`, `mandates` ;
- `cycles`, `shares`, `contribution_obligations`, `contribution_events`, `payment_evidence` ;
- `turns`, `draws`, `draw_evidence`, `beneficiary_receipts` ;
- `penalties`, `attendance`, `meetings`, `votes`, `resolutions` ;
- `treasury_accounts_registers`, `ledger_entries`, `reconciliation_sessions`, `discrepancies` ;
- `savings_goals`, `loan_cases`, `guarantees`, `solidarity_cases` (fonctions sensibles désactivées par défaut) ;
- `disputes`, `mediation_events`, `appeals` ;
- `personal_discipline_events`, `group_discipline_scores`, `score_versions`, `score_shares`, `certificates` ;
- `community_conversations`, `conversation_members`, `messages`, `attachments`, `moderation_reports` ;
- `organization_statuses`, `status_views`, `discover_impressions`, `boost_campaigns` ;
- `group_calls`, `meeting_sessions`, `participant_sessions` ;
- `plans`, `subscriptions`, `invoices`, `subscription_events`, `referrals`, `rewards` ;
- `notifications`, `audit_events`, `risk_alerts`, `support_cases`.

Ces noms sont une carte conceptuelle, pas un schéma SQL approuvé. Le design physique dépend de l'audit du backend et de la modélisation des politiques RLS.

# 31. Critères non fonctionnels

- disponibilité, performance et quotas établis par tests et coûts réels ;
- application résistante aux réseaux intermittents ;
- authentification et autorisations testées côté serveur ;
- isolation complète entre groupes ;
- intégrité financière et historique append-only ;
- idempotence des opérations ;
- sauvegarde et restauration testées ;
- chiffrement adapté ;
- accessibilité et réduction des animations ;
- faible consommation de données ;
- suivi des coûts médias, vidéo, IA et stockage ;
- internationalisation avec repli linguistique ;
- journalisation et observabilité ;
- tests de charge ;
- tests de pénétration ;
- plan de gestion d'incident ;
- gestion des versions et compatibilité ;
- politiques d'export et de suppression.

Les objectifs chiffrés de disponibilité, temps de réponse, RPO/RTO, volume vidéo et limites de participants sont [O] ; ils doivent être définis après mesure et ne sont pas inventés dans cette baseline.

# 32. Plan de réalisation et portes de validation

La réalisation suit une progression qui respecte les dépendances métier. Les chantiers peuvent être préparés en parallèle lorsque leurs fondations sont validées.

| Jalon | Chantier | Conditions de sortie |
|---|---|---|
| J0 | Audit du socle NAXA Family et du backend | Inventaire des composants réutilisables, architecture, données et permissions ; aucun partage implicite |
| J1 | Identité, KYC, rôles et Console NAXA | Parcours non vérifié/vérifié, coffre KYC, badge, audit, MFA et tests de confidentialité |
| J2 | Organisations partenaires et approbation des tontines | Onboarding NAXA, conventions, états, approbations et recours |
| J3 | Cœur TMS | membres, parts, contributions, cycles, tours, tirages, pénalités, présence, reçus |
| J4 | Trésorerie et rapprochement documentaire | ledger, correction, double contrôle, clôture et preuves |
| J5 | Gouvernance, litiges, solidarité | assemblées, votes, médiation et accès confidentiels |
| J6 | COTIZ Social et Status | conversations, pièces privées, modération, statuts 24 h, vues et Discover |
| J7 | COTIZ Meeting | audio/vidéo, faible débit, contrôle des participants et consentement |
| J8 | Discipline et COTIZ Trust | formule versionnée, consentement, explication, recours et certificats |
| J9 | Réseau, candidatures et fédérations | recherche, Match, admissions humaines, organisations hiérarchisées |
| J10 | Épargne, prêts et garanties | uniquement après avis juridique écrit et autorisations/partenaires requis |
| J11 | IA, voix multilingue et automatisation | langues testées, précision mesurée, garde-fous et contrôle des coûts |
| J12 | Abonnements, Boost, parrainage et industrialisation | facturation, quotas, renouvellement, antifraude, tests complets |

## 32.1 Règles go/no-go

- Aucun groupe n'est activé sans approbation NAXA.
- Aucun compte non vérifié n'accède aux espaces privés.
- Aucun statut ne peut être publié par un compte personnel.
- Aucun module financier sensible n'est activé sans avis juridique.
- Aucun tirage officiel n'est lancé sans protocole reproductible et audité.
- Aucun score n'est publié sans formule expliquée, consentement et recours.
- Aucun appel/recording n'est présenté comme opérationnel sans fournisseur validé et politique de consentement.
- Aucun paiement n'est marqué confirmé sans source vérifiable.
- Aucun déploiement n'est effectué sans autorisation explicite.

# 33. Plan de recette et critères d'acceptation

La recette doit couvrir les scénarios suivants au minimum. Une fonctionnalité n'est pas terminée parce qu'un écran existe : le parcours complet, les permissions, la donnée, les états d'erreur, l'audit et la preuve de test doivent être validés.

## 33.1 Identité et KYC

- **KYC-01** : un visiteur peut créer un compte sans CNI.
- **KYC-02** : un compte non vérifié ne peut pas rejoindre un groupe, cotiser, demander une adhésion, communiquer en privé ou créer une tontine.
- **KYC-03** : un compte non vérifié peut consulter les statuts publics et les fiches publiques.
- **KYC-04** : le dossier permet CNI recto/verso, portrait, plan et localisation.
- **KYC-05** : les documents ne sont pas accessibles par un compte membre ni par une URL publique.
- **KYC-06** : une décision de NAXA génère un état, un agent, une date et une trace.
- **KYC-07** : un refus ou complément demandé est notifié et contestable.
- **KYC-08** : la coche bleue n'est pas confondue avec solvabilité ou garantie financière.
- **KYC-09** : l'accès d'un agent à un document est journalisé.
- **KYC-10** : l'utilisateur peut corriger les données qui le concernent selon les règles de conservation.

## 33.2 Création et adhésion

- **GRP-01** : seul un utilisateur vérifié peut envoyer une demande de création.
- **GRP-02** : toute tontine reste inactive avant approbation NAXA.
- **GRP-03** : l'approbation est distincte de la vérification du créateur.
- **GRP-04** : la tontine ne peut pas publier comme approuvée avant décision.
- **GRP-05** : une invitation à un non-vérifié reste bloquée avant KYC.
- **GRP-06** : un rôle proposé exige acceptation explicite.
- **GRP-07** : une personne peut appartenir à plusieurs tontines avec rôles indépendants.
- **GRP-08** : le retrait/révocation d'un mandat conserve l'historique.
- **GRP-09** : un groupe privé ne figure pas dans la recherche publique.
- **GRP-10** : une décision d'admission est humaine, horodatée et motivée.

## 33.3 Organisations et fédérations

- **ORG-01** : une association ne peut être créée comme partenaire que par NAXA.
- **ORG-02** : les représentants et leurs mandats sont enregistrés.
- **ORG-03** : l'organisation peut héberger plusieurs tontines autonomes.
- **ORG-04** : l'administrateur parent ne voit pas les opérations financières détaillées sans délégation.
- **ORG-05** : le statut partenaire et le badge d'une tontine approuvée sont distincts.
- **ORG-06** : la résiliation du partenariat retire les privilèges sans effacer les historiques légitimes.

## 33.4 TMS et finance documentaire

- **FIN-01** : obligation et déclaration de cotisation sont deux événements distincts.
- **FIN-02** : paiement partiel et arriéré sont correctement calculés.
- **FIN-03** : une même référence ne crée pas deux opérations.
- **FIN-04** : un paiement contesté n'est pas marqué confirmé.
- **FIN-05** : un événement hors connexion affiche « en attente de synchronisation ».
- **FIN-06** : une opération confirmée est corrigée par une écriture traçable.
- **FIN-07** : les soldes déclarés et confirmés sont séparés.
- **FIN-08** : l'application n'affiche pas un solde comme fonds détenus par COTIZ.
- **FIN-09** : l'accès financier respecte les rôles et l'isolation.
- **FIN-10** : l'abonnement COTIZ est distinct des cotisations de tontine.
- **FIN-11** : une remise de fonds à un bénéficiaire exige un événement séparé et une preuve.
- **FIN-12** : l'export conserve les états réels et les dates.

## 33.5 Tirages, tours et discipline

- **DRAW-01** : les cinq méthodes sont disponibles selon le type de cycle.
- **DRAW-02** : la liste des éligibles est figée et archivée.
- **DRAW-03** : le tirage est reproductible à partir des preuves publiées.
- **DRAW-04** : un administrateur ne peut pas relancer silencieusement un tirage.
- **DRAW-05** : un échange d'ordre est accepté par les parties requises et historisé.
- **TRUST-01** : absence d'historique = statut insuffisant, pas score négatif.
- **TRUST-02** : une contestation pendante ne crée pas automatiquement un défaut.
- **TRUST-03** : les composantes du score sont consultables et versionnées.
- **TRUST-04** : le partage est explicite, limité et révocable.
- **TRUST-05** : le paiement d'un Boost n'influence aucun score.
- **TRUST-06** : le certificat ne déclare que des faits vérifiés.

## 33.6 Social, statuts et Discover

- **SOC-01** : une personne ne peut pas publier de statut personnel.
- **SOC-02** : seuls les responsables autorisés d'organisations/tontines publient les statuts.
- **SOC-03** : le statut est visible publiquement aux utilisateurs COTIZ y compris non vérifiés.
- **SOC-04** : le statut expire à 24 heures.
- **SOC-05** : l'expiration retire le contenu de l'accès public.
- **SOC-06** : les vues sont dédupliquées et séparées des visiteurs uniques.
- **SOC-07** : un classement organique ne peut être acheté.
- **SOC-08** : une carte sponsorisée porte la mention correspondante.
- **SOC-09** : les cartes animées peuvent être mises en pause ou réduites.
- **SOC-10** : le filtre de proximité n'expose jamais le domicile exact.
- **SOC-11** : les conversations privées restent accessibles uniquement aux participants et contrôles légitimes.
- **SOC-12** : une conversation ne confirme pas une cotisation ou un vote officiel.

## 33.7 Réunions, audio/vidéo et IA

- **MEET-01** : une réunion est limitée aux personnes autorisées.
- **MEET-02** : les fonctions micro/caméra/modérateur fonctionnent selon les droits.
- **MEET-03** : le mode audio reste utilisable en faible bande passante.
- **MEET-04** : un enregistrement est désactivé par défaut et exige information/autorisation.
- **AI-01** : l'assistant ne lit pas les données d'une autre organisation.
- **AI-02** : l'assistant distingue déclaré, vérifié et confirmé.
- **AI-03** : l'assistant ne confirme aucune opération sensible sans action humaine.
- **AI-04** : les langues supportées affichent un niveau de disponibilité fondé sur des tests.
- **AI-05** : le repli linguistique est clair et ne simule pas une compréhension.

## 33.8 Abonnements et gestion

- **SUB-01** : l'inscription individuelle, le KYC, l'annuaire et les statuts publics sont gratuits.
- **SUB-02** : seul le groupe est facturé pour l'usage TMS selon son effectif.
- **SUB-03** : les adhésions en attente ne sont pas facturées.
- **SUB-04** : les membres suspendus restent historiquement présents et ne sont pas comptés comme actifs.
- **SUB-05** : les prix mensuels et annuels correspondent à la grille de référence.
- **SUB-06** : le tarif annuel COTIZ applique l'exception de remise de 15 %.
- **SUB-07** : le dépassement du plafond est signalé et traité selon les règles de palier.
- **SUB-08** : l'expiration n'efface aucune donnée.
- **SUB-09** : le statut payé vient d'une confirmation serveur vérifiable.
- **SUB-10** : les Boosts sont séparés de l'abonnement et du classement de confiance.

## 33.9 Sécurité, conformité et exploitation

- **SEC-01** : aucun accès inter-tontines non autorisé.
- **SEC-02** : aucune donnée KYC n'est publique.
- **SEC-03** : les journaux sont append-only pour les opérations critiques.
- **SEC-04** : les permissions sont contrôlées côté serveur.
- **SEC-05** : aucun secret privilégié dans l'APK/PWA.
- **SEC-06** : restauration de sauvegarde testée.
- **SEC-07** : les demandes d'accès/rectification et incidents de données sont traitables.
- **SEC-08** : les fonctions financières conditionnelles restent désactivées tant que le go juridique n'est pas accordé.
- **SEC-09** : les droits de modération sont limités et audités.
- **SEC-10** : les actions sensibles nécessitent confirmation et preuve.

# 34. Indicateurs de pilotage

## Produit et réseau
- comptes créés ;
- comptes vérifiés ;
- délai de vérification ;
- taux de complétion KYC ;
- tontines soumises, approuvées, refusées et actives ;
- partenaires intégrés ;
- membres actifs ;
- invitations envoyées/acceptées ;
- demandes d'adhésion et conversion ;
- communautés actives ;
- rétention à 7/30/90 jours.

## TMS et confiance
- cycles ouverts/clôturés ;
- cotisations attendues, déclarées, confirmées ;
- écarts de rapprochement ;
- paiements contestés ;
- tirages vérifiés ;
- litiges ouverts/résolus ;
- certificats émis ;
- demandes de rectification de score ;
- alertes antifraude et faux positifs.

## Social et Discover
- statuts publiés et consultés ;
- vues totales et uniques ;
- clics vers candidature ;
- taux de conversion d'une vue en candidature ;
- messages actifs ;
- réunions audio/vidéo ;
- coûts de stockage et de média ;
- campagnes Boost et rendement.

## Commercial
- MRR ;
- ARR ;
- revenu moyen par groupe payant ;
- taux gratuit/payeur ;
- renouvellement ;
- résiliation ;
- utilisation et coût par plan ;
- ARPA/ARPG ;
- CAC ;
- marge par plan ;
- revenu Boost ;
- revenu contrats institutionnels.

Aucun objectif numérique de croissance ou de rentabilité n'est inventé dans ce cahier ; les volumes seront définis dans le business case après collecte des coûts et hypothèses commerciales.

# 35. Risques majeurs et réponses de conception

| Risque | Réponse prévue |
|---|---|
| Vol ou fuite de CNI/GPS | Coffre séparé, chiffrement, accès besoin d'en connaître, MFA, audit et rétention limitée |
| Utilisateur usurpé malgré la coche | Procédure de contestation, réexamen, suspension contrôlée |
| Fausse impression de garantie | Badge explicite, avertissement et séparation vérification/solvabilité |
| Fraude sur paiements | Déclaration distincte, confirmation partenaire ou double contrôle et idempotence |
| Manipulation de tirage | Engagement cryptographique, preuve vérifiable et impossibilité de relancer silencieusement |
| Score injuste | Explicabilité, recours, versionnage, pas de défaut automatique en litige |
| Groupe frauduleux | Vérification NAXA, règles, signalement et suspension encadrée |
| Violation des données parent/enfant | Isolation RLS et délégations par périmètre |
| Abus social | Modération, blocage, signalement et restriction |
| Coût vidéo/IA non maîtrisé | Quotas, audio-first, mesure par plan et fournisseur interchangeable |
| Langue vocale mal comprise | Test natif, repli linguistique, confirmation humaine |
| Activité réglementée non autorisée | Modules financiers verrouillés et avis juridique écrit préalable |
| Popularité achetée | séparation organique/sponsorisé/Trust et mention sponsorisé |
| Perte réseau | cache, files offline, états en attente et synchronisation idempotente |
| Abonnement impayé | restrictions serveur graduées, historique conservé et export selon droits |

# 36. Sources réglementaires à examiner avec le conseil juridique

Les références ci-dessous sont des points de départ pour l'avis juridique ; elles ne constituent pas une interprétation juridique définitive ni une preuve que le modèle COTIZ est conforme.

1. **Cameroun — Loi n° 2024/017 du 23 décembre 2024 relative à la protection des données à caractère personnel** — source officielle de la Présidence : https://www.prc.cm/fr/actualites/actes/lois/7588
2. **CEMAC — Règlement n°04/18/CEMAC/UMAC/COBAC du 21 décembre 2018 relatif aux services de paiement** — document BEAC : https://www.beac.int/wp-content/uploads/2019/07/REGLEMENT-N-04-18-CEMAC-UMAC-COBAC-du-21-d%C3%A9cembre-2018.pdf
3. **BEAC/COBAC — corpus des règlements de microfinance** : https://www.beac.int/supervision-bancaire/microfinance/reglements-de-microfinance/
4. **BEAC — présentation et cadre de la microfinance CEMAC** : https://www.beac.int/supervision-bancaire/microfinance/presentation-de-microfinance/
5. Les textes complémentaires sur taux effectifs, usure, crédit, garanties, consommation, associations, GIC, signature électronique, preuve et conservation doivent être recensés par le juriste avant lancement.

Avis écrit requis sur : collecte d'épargne, fonctionnement des tontines à plusieurs bénéficiaires, prêts avec intérêt, garanties/cautions, solidarité mutualisée, services de paiement, rôle des prestataires, conservation et transferts de données.

# 37. Traçabilité par rapport à la V1.0

Les éléments suivants de la V1 sont conservés et enrichis :
- gestion de groupes ;
- membres et parts ;
- cotisations fixes/variables, partielles et anticipées ;
- tours à ordre fixe ou tirage ;
- pénalités ;
- séances, présence et absence ;
- reçus et justificatifs ;
- Mobile Money comme moyen de paiement externe/documenté ;
- épargne par objectifs ;
- prêts et garanties, sous verrou juridique ;
- caisse de solidarité ;
- clôture des cycles ;
- rappels WhatsApp préparés ;
- fonctionnement hors connexion ;
- synchronisation idempotente ;
- journal append-only et corrections tracées ;
- exports PDF/Excel ;
- tableau de bord et rapports ;
- IA assistive ;
- français/anglais ;
- gestion d'abonnement et APK indépendante.

Les hypothèses V1 remplacées :
- comptes uniquement créés par l'administration : remplacés par inscription individuelle libre et vérification progressive ;
- aucun accès d'un compte non vérifié : remplacé par accès public de consultation des statuts et fiches ;
- abonnement 500/1 500/3 000 FCFA en trois anciens niveaux : remplacé par la grille groupe/effectif de la section 25 ;
- tarification à 500 FCFA par membre et par mois du business case antérieur : remplacée par le modèle groupe ;
- anciennes formules de 3/6/12 mois : remplacées par mensuel ou annuel seulement, avec remise COTIZ de 15 % ;
- lecture SMS comme scénario de preuve : désactivée par défaut et non source de vérité ;
- création de groupe sans processus partenaire/approbation complet : remplacée par KYC organisateur + approbation NAXA de chaque tontine ;
- COTIZ limité à un outil de gestion : remplacé par la plateforme réseau + TMS + social + réputation + voix ;
- statuts personnels ou flux social générique : exclus ; seuls les organismes autorisés publient des statuts de 24 h.

# 38. Points ouverts à fermer avant le gel technique et le lancement

Ces points ne sont pas des omissions : ils sont volontairement déclarés ouverts afin de ne pas inventer une règle qui n'a pas été validée.

| ID | Sujet | Action de clôture |
|---|---|---|
| O-01 | Proportionnalité CNI, plan et GPS domicile | Avis juridique, DPIA/étude d'impact si requise, finalités, conservation et alternative GPS |
| O-02 | Procédure de vérification bleue | Procédure opérationnelle NAXA, outils et délais de traitement |
| O-03 | Conditions d'agrément organisateur | Critères, durée, renouvellement et recours |
| O-04 | Critères d'approbation de tontine | Checklist officielle et délégations de décision |
| O-05 | Statut juridique des partenaires (association/GIC/informel) | Matrice des pièces selon nature et pays |
| O-06 | Formule et pondération Trust | Version, tests d'équité, durée d'obsolescence et revue externe |
| O-07 | Mode de partage du score | Consentement, accès temporaire, révocation et journaux |
| O-08 | Détails des droits de vote par parts | Paramètres de règlement et validation juridique |
| O-09 | Règlement de chaque famille de tontine | Modèles et clauses types à faire valider |
| O-10 | Quotas par abonnement | Modèle de coûts, volume d'utilisateurs, minutes et stockage |
| O-11 | Période de grâce après expiration | Politique commerciale et droits de consultation/export |
| O-12 | Fournisseur de paiement abonnement | Contrat, webhook, rapprochement et traitement des remboursements |
| O-13 | Prestataire vidéo/voix | Comparatif coût, résilience, sécurité et transfert des données |
| O-14 | Politique de conservation des messages | Rétention par nature de donnée et finalité |
| O-15 | Chiffrement de bout en bout | Choix de protocole et audit avant toute promesse |
| O-16 | Capacité audio/vidéo par plan | Tests de charge et coût marginal |
| O-17 | Langues vocales disponibles | Jeux d'essais natifs, qualité par variante et consentement corpus |
| O-18 | Boost et tarification pilote | Test commercial et confirmation des prix avant vente publique |
| O-19 | Barème du parrainage | Déclencheur, montant/avantage, plafond et traitement fiscal |
| O-20 | Quotas de statut photo/vidéo | Coût stockage/transcodage, modération et limites par plan |
| O-21 | SLA support | Horaires, niveaux d'incident, responsabilités et coûts |
| O-22 | Logo, marque et domaine | Vérification de disponibilité et validation graphique |
| O-23 | Objectifs de disponibilité et restauration | SLO, RPO/RTO et tests de reprise |
| O-24 | Contrats et politiques | CGU, politique de confidentialité, modération, partenariats et abonnement |

# 39. Définition de « terminé » pour une fonctionnalité

Une fonction n'est déclarée terminée que si :
1. les parcours positifs et négatifs sont développés ;
2. les autorisations ont été testées côté serveur ;
3. les données sont isolées ;
4. les états d'erreur et d'attente sont gérés ;
5. le fonctionnement hors connexion est défini ;
6. les actions sont journalisées ;
7. les tests automatisés et manuels sont exécutés ;
8. les preuves de recette sont conservées ;
9. la documentation et les procédures support sont à jour ;
10. aucun sujet juridique conditionnel n'est activé sans autorisation.

Un écran, une maquette ou un build ne suffit pas à déclarer une fonction opérationnelle.

# 40. État documentaire et portée de la livraison

Ce document définit la **cible fonctionnelle COTIZ 360° V2.1**. Il ne prétend pas prouver l'existence d'une application complète.

Au moment de sa rédaction, le dépôt Famille NAXA contient un emplacement `apps/cotiz` avec un README d'orientation, mais pas une implémentation fonctionnelle dont les parcours pourraient être déclarés testés. Le présent cahier est donc une baseline pour la suite du chantier.

Aucun changement de code applicatif, schéma SQL, migration Supabase, configuration de production, déploiement, APK ou service externe n'est inclus par le présent document.

**Référence de construction :** utiliser ce cahier V2.1 avec son audit contradictoire compagnon. La V1.0 du 31 octobre 2026 reste une source historique ; les décisions plus récentes de V2.1 priment en cas de contradiction explicite.

---

**Fin du cahier des charges fonctionnel COTIZ 360° V2.1.**
