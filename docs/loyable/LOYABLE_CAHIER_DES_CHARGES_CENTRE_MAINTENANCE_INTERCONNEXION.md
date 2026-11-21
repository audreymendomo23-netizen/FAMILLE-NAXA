# Cahier des charges — Centre de maintenance LOYABLE et interconnexion NAXA SERVICES

> Version 1.0 — proposition consolidée du 21 novembre 2026  
> Statut : référentiel fonctionnel et technique de conception, non preuve d'implémentation.

## 0. Convention de lecture

| Marqueur | Signification |
|---|---|
| [V] | Décision utilisateur confirmée ou décision produit antérieure retenue |
| [C] | Constat documentaire ou technique vérifié |
| [P] | Proposition de conception à implémenter après validation des règles détaillées |
| [O] | Arbitrage restant ouvert |
| [X] | Exclu du périmètre de cette version |

Une exigence écrite dans ce document n'est pas réputée développée, testée ou déployée. Les statuts « local », « contrat API », « serveur intégré », « testé », « déployé » et « production » doivent rester distincts.

### 0.1 Décision complémentaire du 21 novembre 2026

[V] Pour l'interconnexion du Centre de maintenance LOYABLE, seules deux activités du catalogue NAXA SERVICES sont retenues comme catégories de prestataires compatibles :

1. **Réparation** ;
2. **Menuiserie**.

Le catalogue complet de NAXA SERVICES n'est pas supprimé ni réduit. Les autres activités continuent d'exister dans NAXA SERVICES, mais elles ne sont pas proposées comme catégories de prestataires intégrés au Centre de maintenance LOYABLE dans cette version.

[P] Les spécialités détaillées, prestations, zones, horaires, disponibilités, capacités et collaborateurs habilités complètent ces deux catégories. Ils ne créent pas de nouvelles catégories métier LOYABLE.

[X] Pressing, Coiffure, Couture, Beauté, Parfumerie, Garage, Nettoyage, Domicile, Imprimerie, Photographie et Autre ne sont pas des catégories de prestataires intégrés LOYABLE V1. Plomberie, électricité, climatisation, serrurerie et maçonnerie ne sont pas ajoutées implicitement à cette intégration. Elles nécessiteraient un arbitrage distinct et une preuve de capacité du réseau.

## 1. Objet, vision et périmètre

Le Centre de maintenance permet au locataire de signaler un problème dans son logement, au bailleur de qualifier et piloter la demande, puis d'affecter le travail à son concierge ou à un professionnel compatible du réseau NAXA SERVICES.

La chaîne cible est :

**Locataire → LOYABLE → qualification bailleur/concierge → sélection d'un intervenant → ordre de travail → NAXA SERVICES si prestataire intégré → devis et exécution → justificatifs → contrôle du bailleur → clôture LOYABLE → compte rendu locataire.**

LOYABLE reste le système de référence du dossier immobilier : demande initiale, logement, bailleur, locataire, autorisations financières, coûts imputés au bien, contrôle et clôture. NAXA SERVICES reste le système métier du prestataire : organisation, collaborateurs, agenda, prestations, ordre reçu, devis, exécution et pièces à remettre.

Le raccordement est une intégration entre deux applications autonomes, pas une fusion de produits ni une création de comptes communs.

### 1.1 Objectifs métier

- Donner au locataire un moyen simple de signaler et suivre une panne.
- Donner au bailleur une vision des demandes, affectations, délais, devis, dépenses et résultats.
- Réutiliser le réseau NAXA SERVICES sans constituer un deuxième annuaire indépendant.
- Afficher les compétences et disponibilités réellement déclarées ou vérifiées.
- Conserver l'historique des interventions par bien et l'historique privé de fiabilité du prestataire.
- Alimenter les charges et indicateurs de rentabilité LOYABLE avec des dépenses approuvées et justifiées.
- Limiter les données locataire et immobilier transmises au professionnel au strict nécessaire.

### 1.2 Hors périmètre

- Paiement de loyer collecté par LOYABLE : le parcours retenu reste une déclaration de paiement hors plateforme suivie d'une confirmation humaine du bailleur.
- États des lieux d'entrée/sortie : exclus du périmètre LOYABLE retenu, même s'ils figurent dans le cahier historique du 31 octobre 2026.
- Fourniture de matériel, caméras ou équipements par NAXA SERVICES.
- Télésurveillance ou surveillance humaine.
- Connexion automatique de NAXA SECURITY au Centre de maintenance.
- Nouvelle place de marché publique de prestataires indépendante de NAXA SERVICES.
- Réutilisation des comptes, contrats, données locatives ou historiques de paiement dans NAXA SERVICES.
- Paie ou commissions JOBLY pour les prestataires.
- Affectation irrévocable d'un prestataire par une IA.

## 2. Principes structurants

1. **LOYABLE est maître du dossier immobilier.** Tout ordre externe est rattaché à une demande et à un logement LOYABLE.
2. **NAXA SERVICES est maître du dossier professionnel.** L'organisation et ses collaborateurs travaillent dans leur environnement NAXA SERVICES.
3. **Pas de fusion des identités.** Un bailleur LOYABLE et un Promoteur NAXA SERVICES ne deviennent pas le même utilisateur par défaut. Pas de SSO implicite, de mot de passe partagé ou de fusion automatique de comptes.
4. **Le profil d'activité ne prouve pas une compétence.** L'activité principale classe l'organisation ; les spécialités et habilitations précisent les tâches réalisables.
5. **Deux catégories seulement dans le répertoire LOYABLE V1 : Réparation et Menuiserie.**
6. **L'humain garde les décisions sensibles.** Le bailleur qualifie, affecte, valide les devis et dépenses, demande une reprise et clôture.
7. **Pas de fuite immobilière.** Le prestataire n'accède ni au bail, ni aux loyers, ni aux retards, ni aux autres logements.
8. **Toute étape est traçable.** Auteur, horodatage serveur, origine, motif et référence de corrélation sont conservés.
9. **Pas de faux statut synchronisé.** Une opération n'est indiquée comme reçue par l'autre application qu'après accusé serveur valide.
10. **Pas d'activation par simple bouton.** Le contrat API, les droits, le stockage et les tests doivent être livrés avant l'activation.

## 3. Acteurs et responsabilités

### 3.1 Locataire

Peut créer un signalement pour son logement, décrire la panne, indiquer son urgence ressentie, fournir des pièces pertinentes, communiquer ses disponibilités, répondre à une demande de précision, suivre les états et consulter le compte rendu destiné au locataire.

Ne peut pas engager financièrement le bailleur, approuver un devis, choisir seul un prestataire, accéder à l'annuaire professionnel complet ou consulter les données d'autres locataires.

### 3.2 Bailleur / gestionnaire habilité

Peut consulter les demandes de son périmètre, qualifier, demander des précisions, prioriser, affecter, choisir un prestataire, examiner les disponibilités, approuver/refuser/réviser les devis, autoriser les dépenses additionnelles, demander une reprise, valider la fin et clôturer.

Un gestionnaire délégué n'agit que dans les biens, sites, rôles et plafonds qui lui sont attribués. Les seuils de délégation sont ouverts [O].

### 3.3 Concierge

Peut consulter les demandes des sites affectés, qualifier les informations pratiques, documenter une visite, prendre en charge une mission interne et suivre une mission externe si le bailleur l'y autorise.

Ne peut pas, par défaut, engager une dépense au-delà de son plafond, confirmer un paiement, modifier un bail ou clôturer définitivement un dossier réservé au bailleur.

### 3.4 Promoteur / responsable de l'organisation prestataire NAXA SERVICES

Gère le profil professionnel, les spécialités et prestations, les zones, horaires, capacités et collaborateurs habilités. Il reçoit les ordres transmis à son organisation, accepte/refuse, affecte un membre de l'équipe, transmet devis, calendrier, étapes, preuves et compte rendu.

### 3.5 Collaborateur / technicien NAXA SERVICES

Accède uniquement aux missions qui lui sont affectées et aux renseignements nécessaires à leur exécution. Il ne voit pas le portefeuille du bailleur, les autres locataires, les loyers ou les dossiers non affectés.

### 3.6 Personnel NAXA autorisé

Peut administrer le statut professionnel, traiter les erreurs d'intégration et assurer le support technique dans une portée autorisée. Le support ne dispose pas d'un accès général aux contrats locatifs ni aux preuves privées.

## 4. Catégories et profil des prestataires

### 4.1 Catégories autorisées [V]

| Catégorie | Référence métier actuelle | Sous-spécialités proposées à confirmer [P] |
|---|---|---|
| Réparation | Réparation de téléphones, électronique et électroménager dans le catalogue NAXA SERVICES | Diagnostic, électronique, petit électroménager, gros électroménager, remplacement de composants |
| Menuiserie | Menuiserie, portes, fenêtres, meubles et installations | Bois, ajustement de portes, mobilier, montage, pose et ajustement de fenêtres |

Les sous-spécialités sont une proposition de structuration, pas une affirmation que tous les prestataires actuels les maîtrisent. Elles doivent être confirmées par inventaire du réseau et vérification adaptée.

### 4.2 Profil professionnel enrichi [P]

Chaque organisation prestataire expose :
- identifiant immuable NAXA SERVICES ;
- activité principale sélectionnée par le Promoteur dans NAXA SERVICES ;
- catégorie LOYABLE compatible : Réparation ou Menuiserie ;
- sous-spécialités déclarées, sous-spécialités vérifiées et prestations réellement proposées ;
- description, conditions, prix indicatifs et durées usuelles si renseignés ;
- modes d'intervention acceptés : sur site immobilier et, si utile, atelier ;
- zones desservies : villes, quartiers ou périmètres paramétrés ;
- horaires, jours d'indisponibilité et créneaux ouverts ;
- capacité actuelle ou nombre de missions possibles par période ;
- délai indicatif de réponse ;
- contacts professionnels ;
- collaborateurs autorisés à recevoir/exécuter des missions ;
- documents ou qualifications éventuellement vérifiés ;
- statut actif, temporairement indisponible, suspendu ou à vérifier ;
- date de dernière mise à jour et origine de la vérification.

Une organisation n'est pas présentée comme candidate intégrée tant que sa catégorie, ses zones et son statut opérationnel ne sont pas suffisamment renseignés. L'absence de preuve ne doit jamais devenir un badge « vérifié ».

### 4.3 Niveaux de confiance séparés

Le système distingue :
- activité déclarée ;
- spécialité déclarée ;
- spécialité vérifiée ;
- collaborateur habilité ;
- disponibilité déclarée ;
- capacité confirmée au moment de l'affectation.

Le contrôle d'identité d'une organisation ne certifie pas sa compétence technique. Une qualification, un contrôle humain ou une référence peut être géré comme preuve distincte.

### 4.4 Sélection initiale NAXA SERVICES

Le catalogue historique de 13 activités reste propre à NAXA SERVICES. LOYABLE ne reprend que Réparation et Menuiserie. Le parcours initial de sélection d'activité par le Promoteur est une décision produit à préserver, mais le rapport de construction indique que l'écran n'était pas retrouvé dans le parcours Android inspecté. Sa présence dans le code livré doit donc être vérifiée séparément.

## 5. Parcours fonctionnel de bout en bout

### 5.1 Signalement locataire

1. Le locataire ouvre Centre de maintenance.
2. LOYABLE rattache le signalement à son logement autorisé ; le locataire ne peut pas sélectionner un autre bail.
3. Le formulaire recueille titre, description, nature du problème, urgence ressentie, date/heure de constat, disponibilités d'accès et pièces éventuelles.
4. Photos/vidéos sont facultatives et limitées au diagnostic.
5. Le locataire confirme ; LOYABLE attribue un numéro et affiche « reçu ».
6. Une confirmation est affichée et notifiée par les canaux activés.

LOYABLE signale un doublon probable (même logement, catégorie semblable, demande encore ouverte), sans supprimer automatiquement la nouvelle demande. Le locataire peut confirmer qu'il s'agit d'un incident distinct.

### 5.2 Qualification et triage

Le bailleur ou concierge habilité peut accepter la demande pour traitement, demander des précisions, reclasser avec motif, relier à un dossier existant, définir une priorité ou décider qu'aucune intervention n'est requise.

Les priorités proposées sont faible, normale, urgente et critique [P]. Les délais cibles et le traitement des urgences restent à arbitrer [O]. Le produit ne doit pas promettre une intervention 24/7 sans service contractuellement établi.

### 5.3 Affectation interne

Le bailleur peut affecter le concierge, un collaborateur de gestion ou une équipe interne. Le destinataire reçoit uniquement le dossier et les coordonnées nécessaires. Les dépenses restent soumises à approbation.

### 5.4 Recherche d'un prestataire

Le moteur filtre le registre professionnel partagé selon :
1. catégorie Réparation ou Menuiserie ;
2. sous-spécialité requise et statut de vérification ;
3. zone de déplacement ;
4. disponibilité déclarée ;
5. capacité déclarée/confirmée ;
6. statut actif et non suspendu ;
7. historique de missions et retours privés autorisés ;
8. prix indicatifs, si disponibles.

La recherche n'expose pas l'adresse exacte ni les coordonnées du locataire à tous les prestataires. Le bailleur sélectionne explicitement. Le classement peut expliquer les critères, mais ne décide pas à sa place.

### 5.5 Ordre de travail

Après sélection, LOYABLE crée un ordre lié au signalement, avec :
- numéro de mission et référence LOYABLE ;
- catégorie et spécialité ;
- description utile et diagnostic initial ;
- photos/vidéos retenues ;
- localisation strictement nécessaire à la mission ;
- consignes d'accès et disponibilités ;
- coordonnées utiles, selon partage autorisé ;
- échéance souhaitée si définie ;
- contraintes particulières autorisées ;
- autorité de validation du devis et des dépenses ;
- version du dossier transmise.

L'envoi produit un accusé technique. Tant que NAXA SERVICES n'a pas accusé réception, LOYABLE conserve « en attente de transmission » et n'annonce pas que le professionnel a reçu l'ordre.

### 5.6 Acceptation / refus

Dans NAXA SERVICES, le Promoteur ou le collaborateur habilité peut accepter, refuser avec motif, demander des informations, proposer une visite ou signaler une indisponibilité. Un refus retourne au bailleur avec le motif ; il n'efface pas le dossier. Le bailleur peut rechercher un autre prestataire.

### 5.7 Diagnostic, devis et approbation

Le prestataire documente diagnostic, travaux envisagés, main-d'œuvre, pièces/consommables, déplacement, quantités, prix unitaires, total, délai, garantie proposée et durée de validité.

LOYABLE présente le devis au bailleur. Celui-ci approuve, refuse ou demande une révision. Les travaux payants ne commencent pas avant approbation explicite du devis, sauf règle d'urgence distincte, à définir et approuver [O].

Le devis approuvé est versionné et figé. Toute hausse, pièce supplémentaire ou tâche différente crée un avenant ou une nouvelle version qui doit être approuvée. Une approbation de devis ne prouve pas le paiement.

### 5.8 Planification et exécution

Après approbation :
- le prestataire confirme le rendez-vous ;
- il affecte un collaborateur habilité ;
- il enregistre les étapes et horodatages utiles ;
- il décrit le travail réalisé ;
- il ajoute photos avant/pendant/après lorsque pertinentes ;
- il documente les pièces utilisées et frais réels ;
- il signale toute différence ou tâche supplémentaire ;
- il transmet les justificatifs.

Le bailleur/concierge suit l'avancement dans LOYABLE. Le locataire voit uniquement les informations de suivi qui lui sont destinées.

### 5.9 Contrôle et clôture

À la soumission du compte rendu final :
1. le bailleur ou concierge habilité contrôle le résultat ;
2. il peut demander une reprise motivée ;
3. sinon, le bailleur valide la fin ;
4. LOYABLE consolide le coût final et les justificatifs ;
5. le dossier est clôturé ;
6. le locataire reçoit le compte rendu filtré ;
7. le dossier reste consultable dans l'historique du logement.

Une intervention clôturée ne peut pas être réécrite silencieusement. Une rectification ou réouverture crée un événement distinct, motivé et audité.

### 5.10 Exceptions

- **Aucun prestataire compatible :** prévenir le bailleur et conserver le dossier en attente ; ne pas inventer un professionnel.
- **Refus/indisponibilité :** retourner au bailleur avec historique.
- **Absence de réponse :** relance selon délai qui sera arbitré ; pas de réaffectation automatique sans règle validée.
- **Perte réseau :** garder le brouillon local et signaler que la transmission n'est pas effectuée.
- **Désaccord sur le devis :** négociation ou refus explicite, aucun démarrage payant implicite.
- **Dépense imprévue :** suspendre l'étape concernée et demander approbation.
- **Annulation :** conserver motif, acteur, frais éventuels validés et état dans les deux systèmes.
- **Incident hors Réparation/Menuiserie :** gérer le dossier dans LOYABLE, sans le router artificiellement vers un prestataire NAXA SERVICES incompatible V1.

## 6. Statuts et transitions

Les codes ci-dessous sont des états proposés à implémenter comme machine à états explicite.

| Code | Libellé | Déclencheur |
|---|---|---|
| new | Nouveau signalement | Locataire |
| received | Reçu par LOYABLE | Enregistrement |
| needs_information | Informations complémentaires requises | Bailleur/concierge |
| qualified | Qualifié | Bailleur/concierge |
| assigned_internal | Affecté au concierge/interne | Bailleur |
| searching_provider | Recherche prestataire | Bailleur |
| assigned_provider | Affecté au prestataire | Bailleur |
| awaiting_provider_ack | En attente d'accusé NAXA SERVICES | Transmission |
| accepted | Accepté | Prestataire |
| declined | Refusé | Prestataire |
| visit_proposed | Visite proposée | Prestataire |
| scheduled | Rendez-vous confirmé | Parties autorisées |
| diagnosis_submitted | Diagnostic transmis | Prestataire |
| quote_submitted | Devis transmis | Prestataire |
| quote_revision_requested | Révision demandée | Bailleur |
| quote_approved | Devis approuvé | Bailleur |
| quote_rejected | Devis refusé | Bailleur |
| in_progress | Intervention en cours | Prestataire |
| paused | Intervention suspendue | Prestataire/bailleur |
| completion_submitted | Compte rendu soumis | Prestataire |
| review_pending | Contrôle en attente | LOYABLE |
| rework_requested | Reprise demandée | Bailleur/concierge habilité |
| completed | Travail validé | Bailleur |
| closed | Dossier clôturé | Bailleur |
| cancelled | Annulé | Acteur autorisé |
| blocked | Bloqué / arbitrage requis | Système/bailleur |

Règles :
- une transition est autorisée selon l'acteur et le statut courant ;
- les transitions sensibles sont contrôlées côté serveur ;
- chaque transition conserve ancien/nouvel état, auteur, date serveur, motif et version ;
- un événement reçu deux fois ne crée pas deux transitions ;
- un événement hors séquence est rejeté ou placé en revue, jamais appliqué par écrasement ;
- statut du travail, statut financier et statut de synchronisation sont trois dimensions distinctes.

## 7. Devis, dépenses et rentabilité

### 7.1 Devis

Chaque ligne comprend libellé, type, quantité, unité, prix unitaire, total et commentaire. Les totaux sont recalculés côté serveur, au franc CFA près. Chaque version conserve son auteur, sa date et son statut.

### 7.2 Dépenses réelles

LOYABLE conserve devis retenu, approbation, lignes exécutées, montant final, dépenses additionnelles approuvées, factures/reçus, preuve de règlement si saisie, bénéficiaire, moyen de paiement déclaré, écart devis/réel et motif.

LOYABLE distingue impérativement :
- montant estimé ;
- montant approuvé ;
- montant facturé ;
- montant déclaré payé ;
- montant confirmé payé, si une preuve adaptée existe.

Une photo de facture, un devis ou une déclaration du prestataire ne confirme pas automatiquement un paiement.

### 7.3 Imputation immobilière

Une dépense validée est rattachée au bien, à l'immeuble et à la période avec catégorie de charge. Les tableaux de rentabilité utilisent les dépenses selon le statut d'approbation et les règles comptables définies.

La part éventuellement refacturable au locataire dépend du bail, de la cause de panne et de la décision du bailleur. Aucune règle juridique automatique n'est créée ici. Toute imputation locataire est un workflow séparé, documenté et validé humainement [O].

## 8. Écrans attendus

### 8.1 LOYABLE — locataire
- Centre de maintenance et liste des demandes ;
- formulaire de signalement, logement pré-rattaché ;
- détail, pièces, messages et historique filtré ;
- réponse à une demande de précision ;
- compte rendu final et demande de réexamen si prévue.

### 8.2 LOYABLE — bailleur / gestionnaire
- tableau de bord : nouvelles demandes, urgences, affectations, devis à approuver, interventions en cours et contrôles en attente ;
- liste filtrable par bien, immeuble, statut, date, catégorie, concierge et prestataire ;
- qualification et affectation interne ;
- recherche du registre Réparation/Menuiserie ;
- fiche prestataire et preuves disponibles ;
- suivi de l'ordre de travail ;
- approbation/refus/révision des devis ;
- suivi d'exécution et pièces ;
- contrôle, reprise et clôture ;
- historique par bien et vue privée de la qualité ;
- coûts, écarts devis/réel et charges imputées.

### 8.3 NAXA SERVICES — prestataire
- profil professionnel ;
- catégorie compatible Réparation ou Menuiserie ;
- spécialités et catalogue ;
- zones, disponibilités et capacité ;
- collaborateurs et habilitations ;
- boîte de réception des ordres LOYABLE ;
- détail, acceptation/refus et motif ;
- proposition de visite et calendrier ;
- diagnostic, devis versionné ;
- affectation à un collaborateur ;
- suivi d'étapes, justificatifs et frais ;
- compte rendu final et réponse aux reprises ;
- historique des missions provenant de LOYABLE.

Les ordres LOYABLE doivent être séparés des tickets pressing, rendez-vous clients et autres objets NAXA SERVICES. Ils peuvent réutiliser certains composants, mais ne deviennent pas des tickets pressing.

### 8.4 Administration NAXA
- validation/suspension d'une organisation prestataire ;
- suivi d'intégrité des liaisons et événements en échec ;
- correction de références et spécialités ;
- journal des opérations ;
- métriques réseau agrégées sans accès généralisé aux dossiers locatifs.

## 9. Matrice des droits de haut niveau

| Action | Locataire | Bailleur | Concierge | Promoteur prestataire | Technicien prestataire | NAXA support |
|---|---:|---:|---:|---:|---:|---:|
| Créer un signalement | Oui | Son parc | Selon délégation | Non | Non | Non |
| Lire le dossier complet | Son dossier filtré | Son périmètre | Dossiers affectés | Ordres transmis | Missions affectées | Aucun accès par défaut |
| Qualifier | Non | Oui | Selon délégation | Non | Non | Non |
| Choisir prestataire | Non | Oui | Selon délégation | Non | Non | Non |
| Accepter/refuser mission | Non | Non | Non | Oui | Si autorisé | Non |
| Soumettre devis | Non | Non | Non | Oui | Si habilité | Non |
| Approuver devis | Non | Oui | Sous plafond futur | Non | Non | Non |
| Mettre à jour exécution | Non | Contrôle | Selon délégation | Oui | Mission affectée | Non |
| Demander une reprise | Signaler problème | Oui | Selon délégation | Répondre | Répondre | Non |
| Clôturer LOYABLE | Non | Oui | Délégation future | Non | Non | Non |
| Gérer profil prestataire | Non | Non | Non | Oui | Limitée | Selon habilitation |
| Voir contrat/loyers | Son bail | Son parc | Non par défaut | Non | Non | Non |

Les permissions réelles doivent être atomiques et vérifiées dans l'API et la base, pas seulement masquées dans l'interface.

## 10. Modèle de données logique proposé

Les concepts ci-dessous ne sont pas des noms de tables déjà présents ni des migrations existantes.

### 10.1 Domaine LOYABLE
- MaintenanceRequest : signalement, logement, description, catégorie de problème, priorité et statut.
- MaintenanceRequestAttachment : pièce privée, type, taille, hash, auteur et conservation.
- MaintenanceAssignment : concierge, intervenant interne ou organisation prestataire.
- ProviderReference : identifiant NAXA SERVICES, catégorie, statut de vérification et instantané autorisé.
- WorkOrder : ordre de travail lié à une demande LOYABLE, version et statut de transmission.
- WorkOrderStatusHistory : transitions immuables.
- WorkOrderQuote et WorkOrderQuoteLine : devis versionné et lignes.
- WorkOrderSchedule : proposition et confirmation du rendez-vous.
- WorkOrderExecutionLog : étapes, intervenant, dates et commentaires.
- WorkOrderExpense : dépense réelle, validation, catégorie et justificatif.
- WorkOrderAttachment : photo/document, auteur et portée.
- WorkOrderReview : contrôle, décision et reprise.
- ProviderQualityRecord : faits d'exécution, retards, reprises, annulations et retours privés.
- ExternalIntegrationEvent : événement entrant/sortant, tentative, accusé et erreur.
- NotificationReference : événement notifié et état connu.

### 10.2 Domaine NAXA SERVICES

NAXA SERVICES conserve ses entités d'organisation, membres, sites, postes, catalogue et agenda. Les ordres externes sont ajoutés comme objets distincts.

Concepts proposés : ExternalWorkOrder, ExternalWorkOrderAssignment, ExternalWorkOrderQuote, ExternalWorkOrderStatusHistory, ProviderServiceProfile, ProviderSpecialty, ProviderServiceArea, ProviderAvailability, ProviderCapacity et ProviderMemberQualification.

Ces concepts ne sont pas réputés présents dans Room ni dans Supabase. Modèle, contraintes, RLS, migrations locales et endpoints sont à concevoir.

### 10.3 Identifiants

Chaque organisation, membre, site, logement, demande et ordre possède un identifiant stable. La clé de liaison externe ne remplace pas la clé primaire métier locale. Le mapping du prestataire repose sur l'identifiant stable de l'organisation, jamais sur son seul nom affiché. Les références croisées sont explicites et révocables.

## 11. Contrat d'intégration LOYABLE ↔ NAXA SERVICES

### 11.1 Capacités API requises

| Capacité | Sens | Résultat attendu |
|---|---|---|
| Découverte prestataires | LOYABLE → NAXA SERVICES | Résultats Réparation/Menuiserie filtrés |
| Lecture profil autorisé | LOYABLE → NAXA SERVICES | Données professionnelles minimales |
| Création ordre externe | LOYABLE → NAXA SERVICES | Référence et accusé serveur |
| Acceptation/refus | NAXA SERVICES → LOYABLE | Décision et motif corrélés |
| Proposition/confirmation créneau | Bidirectionnel | Dates et décisions horodatées |
| Diagnostic/devis | NAXA SERVICES → LOYABLE | Version, lignes, total, pièces |
| Approbation/refus devis | LOYABLE → NAXA SERVICES | Décision du bailleur |
| Progression | NAXA SERVICES → LOYABLE | Étapes, auteur et date |
| Justificatifs | NAXA SERVICES → stockage contrôlé/LOYABLE | Références sécurisées |
| Compte rendu final | NAXA SERVICES → LOYABLE | Résultat, coûts et demande de clôture |
| Reprise/clôture | LOYABLE → NAXA SERVICES | Décision de contrôle |

Ces capacités sont un contrat cible, pas des endpoints existants confirmés.

### 11.2 Événements métier proposés

- loyable.maintenance_request.created
- loyable.maintenance_request.qualified
- loyable.work_order.created
- loyable.work_order.assigned
- loyable.work_order.cancelled
- naxa_services.work_order.received
- naxa_services.work_order.accepted
- naxa_services.work_order.declined
- naxa_services.work_order.visit_proposed
- naxa_services.work_order.scheduled
- naxa_services.work_order.diagnosis_submitted
- naxa_services.work_order.quote_submitted
- loyable.work_order.quote_approved
- loyable.work_order.quote_rejected
- naxa_services.work_order.progress_updated
- naxa_services.work_order.completion_submitted
- loyable.work_order.rework_requested
- loyable.work_order.completed
- loyable.work_order.closed

### 11.3 Enveloppe, idempotence et reprise

Chaque événement porte au minimum event_id, idempotency_key, correlation_id, application source/destination, organisation source, acteur, aggregate_type, aggregate_id, aggregate_version, event_type, schema_version, horodatage source, horodatage de réception serveur et payload validé.

Règles :
- origine/signature vérifiées pour les échanges serveur à serveur ;
- secrets exclusivement côté serveur ;
- idempotence par événement et opération métier ;
- outbox transactionnelle côté émetteur et inbox côté destinataire ;
- accusé seulement après validation et persistance ;
- retry avec backoff pour erreurs transitoires ;
- quarantaine/revue manuelle des erreurs permanentes ;
- événements hors ordre et versions d'agrégat traités explicitement ;
- réconciliation des états local et distant ;
- versionnement du contrat et compatibilité ascendante ;
- aucun statut synchronisé sans accusé de traitement valide.

Une mise en file locale, un timeout ou une réponse réseau générique ne constitue pas un accusé de livraison.

### 11.4 Données transmises au prestataire

Envoyer : référence mission, catégorie, spécialité, description utile, pièces sélectionnées, localisation nécessaire après affectation, créneau, consignes d'accès, contact utile et limites d'approbation.

Ne pas envoyer : contrat de bail, montant du loyer, arriérés, quittances, historique locatif, données d'autres logements, pièce d'identité non nécessaire ou historique privé du bailleur.

Le contact locataire doit de préférence transiter par LOYABLE ou par un mécanisme limité. Le partage direct du téléphone ou du nom complet reste à définir [O].

### 11.5 Pièces jointes

Les fichiers restent dans un stockage privé. L'API transmet des identifiants ou URL signées de courte durée, jamais des liens publics permanents. Contrôler type MIME, taille, auteur, date, appartenance au dossier et permission. Les preuves de paiement locatif et contrats ne sont jamais visibles du prestataire.

## 12. Réutilisation des briques NAXA, NAXA SERVICES et JOBLY

### 12.1 Socle Famille NAXA / NAXA [P]

Réutilisations à étudier après audit de compatibilité :
- authentification et gestion de sessions, dans les frontières de chaque application ;
- modèle organisation/site/poste et contrôles de périmètre ;
- rôles et permissions atomiques ;
- journal d'audit avant/après ;
- stockage privé, liens temporaires et métadonnées des pièces ;
- centre de notifications et préférences ;
- modèles WhatsApp préparés, sans envoi automatique implicite ;
- contrats API, idempotence, outbox/inbox et reprise ;
- observabilité et support ;
- génération de documents et exports si les composants sont génériques.

**Réserve :** NAXA contient des domaines propres à la pharmacie. Les tables pharmacies, produits pharmaceutiques, réservations, caisses et transactions pharmacie ne sont pas génériques. Ne pas les importer dans LOYABLE et ne pas réutiliser les données pharmacie. Chaque composant doit faire l'objet d'un audit de code, dépendances et autorisations.

### 12.2 NAXA SERVICES [C]

Le rapport de construction consulté documente déjà dans le client Android et la base locale :
- authentification interne et gestion des sessions ;
- organisations avec modes solo, multi-postes sur un site et réseau multi-sites ;
- séparation locale par organisation/site ;
- catalogue de prestations et prestataires ;
- agenda et rendez-vous, avec contrôle local de conflits site/poste/prestataire ;
- équipe, clients/CRM, stocks/consommables, caisse, dépenses et rapports locaux ;
- tickets pressing avec statuts et historique ;
- écrans d'organisation, accès, assistance et paramètres.

Réutilisation recommandée :
- conserver le modèle organisation/site et les contrôles de périmètre ;
- réutiliser le pattern catalogue « prestation – durée – prix – prestataire habilité » ;
- réutiliser les composants de calendrier et disponibilité après audit ;
- réutiliser l'attribution à un collaborateur et les contrôles d'accès ;
- ajouter un type d'objet distinct « ordre de travail immobilier externe » ;
- réutiliser upload privé et notifications après validation du contrat serveur.

Ne pas réutiliser directement :
- les tickets pressing comme ordres de réparation ;
- les ventes, caisses ou créances prestataire comme dépenses immobilières ;
- le CRM prestataire comme répertoire locataire ;
- les commissions de salon ou fidélité comme rémunération d'ordre LOYABLE ;
- un écran de menu comme preuve de workflow opérationnel.

**Limite technique vérifiée :** le rapport indique que l'outbox locale n'est pas une synchronisation globale. Le protocole ERP, l'idempotence, les conflits, les reçus serveur et le multi-appareils ne sont pas qualifiés pour tous les domaines. Le coordinateur documenté est limité à certains flux fournisseur en synchronisation manuelle. Aucun contrat complet LOYABLE ↔ NAXA SERVICES n'est constaté.

### 12.3 JOBLY [P]

Les documents JOBLY décrivent le domaine Partner avec profil, KYC, code, referral, commission et payout ; un Jobly ID/QR partageable et révocable ; l'attribution des conversions ; des états idempotents ; un onboarding visuel ; des notifications catégorisées et de l'assistance avec transfert humain.

Patterns réutilisables :
- onboarding progressif du Promoteur prestataire ;
- états déclarés, à vérifier, vérifiés et suspendus ;
- QR ou référence opaque et révocable ;
- provenance et attribution des actions ;
- traitements idempotents et auditables ;
- notifications catégorisées ;
- escalade vers un humain.

Ne pas copier Partner JOBLY tel quel. Un partenaire d'acquisition n'est pas un prestataire technique. Ne pas réutiliser portefeuille de commissions, paiements, récompenses ou referral JOBLY. Un KYC d'identité ne certifie pas une qualification métier.

### 12.4 Règle pour chaque composant réutilisé

Documenter source, code, dépendances, licence, tests disponibles, données manipulées, autorisations, compatibilité, adaptations et tests de non-régression. Sans ces preuves, le composant demeure une référence d'architecture et non une réutilisation technique confirmée.

## 13. Sécurité, confidentialité et conformité

Exigences :
- isolation par organisation, propriétaire, site, bien, locataire, prestataire et mission ;
- contrôles d'accès côté serveur et base, en plus de l'interface ;
- vérification de la propriété et de l'affectation pour chaque identifiant ;
- jetons opaques, limités, révocables et de courte durée ;
- politiques RLS testées avec plusieurs organisations et rôles ;
- secrets et clés privilégiées exclusivement côté serveur ;
- chiffrement en transit et protection des données sensibles au repos selon l'infrastructure ;
- journal immuable/append-only des événements sensibles ;
- finalité, durée de conservation et suppression contrôlée des données ;
- consentement/information adaptés aux données et canaux ;
- aucune photo publique par défaut ;
- aucun accès transversal d'un prestataire à plusieurs bailleurs sans mission ;
- aucune décision contractuelle/financière irréversible par l'IA.

Une revue juridique locale doit valider clauses prestataires, responsabilité des interventions, données partagées, conservation, recours et refacturation avant commercialisation.

## 14. Hors connexion, notifications et expérience

### 14.1 Hors connexion

- Le locataire peut préparer un brouillon local.
- LOYABLE affiche « enregistré sur cet appareil — transmission en attente ».
- Un ordre externe ne devient reçu/accepté qu'après accusé valide du serveur destinataire.
- Les validations sensibles nécessitent confirmation serveur ou mécanisme sécurisé spécifié.
- Les événements sont dédupliqués et rejoués de façon déterministe.
- Les conflits financiers ne sont jamais résolus par écrasement automatique.
- L'état actuel NAXA SERVICES interdit de promettre une synchronisation de bout en bout avant lot dédié et recette.

### 14.2 Notifications

Événements candidats : signalement reçu, précision requise, qualification, prestataire sélectionné, ordre transmis/reçu, acceptation/refus, rendez-vous proposé/confirmé, devis soumis/à approuver/approuvé/refusé, travaux démarrés/suspendus, compte rendu soumis, reprise demandée et clôture.

Canaux : centre de notifications, push/local si raccordés et message WhatsApp préparé. Une notification ne remplace ni une décision ni un accusé API. Les messages WhatsApp préparés ne sont pas envoyés sans action utilisateur.

### 14.3 Ergonomie

- mobile-first, vocabulaire simple et actions principales en peu d'étapes ;
- formulaire utilisable sur connexion faible ;
- compression médias et reprise d'envoi ;
- chaque statut associe icône, libellé et couleur ;
- français et anglais, sans texte métier bloquant en dur ;
- mode dégradé réseau avec indication claire de ce qui n'a pas encore été partagé.

## 15. Exigences fonctionnelles et critères de recette

| ID | Priorité | Exigence | Critère de recette |
|---|---|---|---|
| CM-001 | P0 | Signalement lié au logement du locataire | Refus si le logement n'est pas autorisé |
| CM-002 | P0 | Numéro unique et historique | Double envoi ne crée pas deux demandes |
| CM-003 | P0 | Pièces jointes privées | Un autre locataire ne peut pas les ouvrir |
| CM-004 | P0 | Qualification/demande de précision | Auteur et horodatage conservés |
| CM-005 | P0 | Portée concierge | Accès inter-site non autorisé refusé |
| CM-006 | P0 | Filtre catégorie | Uniquement Réparation et Menuiserie |
| CM-007 | P0 | Spécialité séparée de l'activité | Activité seule ne donne pas badge vérifié |
| CM-008 | P0 | Recherche zone/disponibilité/capacité/statut | Prestataire suspendu/hors zone non affectable |
| CM-009 | P0 | Choix explicite du prestataire | Pas d'affectation automatique non autorisée |
| CM-010 | P0 | Transmission et accusé serveur | Pas de statut « reçu » sans accusé valide |
| CM-011 | P0 | Acceptation/refus avec motif | Refus restitué au bailleur |
| CM-012 | P0 | Proposition de visite | Date et acteur conservés |
| CM-013 | P0 | Devis détaillé versionné | Total recalculé côté serveur |
| CM-014 | P0 | Approbation du devis | Aucun travail payant avant approbation |
| CM-015 | P0 | Avenant pour tout dépassement | Nouvelle approbation requise |
| CM-016 | P0 | Suivi d'exécution | Chaque étape a auteur et date |
| CM-017 | P0 | Preuves finales | Accès réservé aux rôles autorisés |
| CM-018 | P0 | Reprise ou validation | Décision et motif historisés |
| CM-019 | P0 | Clôture bailleur | Prestataire ne peut pas clôturer LOYABLE |
| CM-020 | P0 | Dépenses distinctes du paiement | Dépense déclarée jamais payée automatiquement |
| CM-021 | P0 | Imputation au bien | Seules dépenses approuvées alimentent l'agrégat validé |
| CM-022 | P0 | Minimisation des données | Prestataire ne voit ni bail, ni loyers, ni arriérés |
| CM-023 | P0 | Comptes séparés | Jeton LOYABLE ne donne pas accès à NAXA SERVICES |
| CM-024 | P0 | Idempotence | Rejeu ne duplique ni ordre ni devis |
| CM-025 | P0 | Synchronisation observable | Échec non marqué synchronisé, corrélation possible |
| CM-026 | P1 | Historique qualité privé | Consultation limitée au bailleur autorisé |
| CM-027 | P1 | Compte rendu locataire | Notes internes masquées |
| CM-028 | P1 | Notifications dédupliquées | Rejeu ne duplique pas la notification |
| CM-029 | P1 | Absence de prestataire | Dossier reste au bailleur, sans prestataire inventé |
| CM-030 | P1 | Supervision intégration | Erreur liée à l'ordre et à la tentative |
| CM-031 | P1 | Suspension prestataire | Prestataire indisponible non sélectionnable |
| CM-032 | P1 | Export selon droits | Export est journalisé |
| CM-033 | P2 | Indicateurs qualité/délais | Source, période et données manquantes indiquées |

## 16. Tests de sécurité et d'intégration obligatoires

1. Locataire A tente de lire le dossier du locataire B : refus serveur.
2. Bailleur A tente de lire un dossier du bailleur B : refus.
3. Concierge du site 1 tente de lire le site 2 : refus.
4. Prestataire non affecté tente d'ouvrir l'ordre : refus.
5. Prestataire d'une activité non retenue tente d'apparaître : absent du registre LOYABLE V1.
6. Prestataire Réparation sans spécialité nécessaire : non éligible à la mission.
7. Prestataire suspendu : non sélectionnable pour nouvelle affectation.
8. Ordre transmis puis réponse perdue : retry idempotent sans duplication.
9. Événement reçu deux fois : une seule transition métier.
10. Événement hors ordre : attente/quarantaine ou rejet contrôlé, jamais écrasement.
11. Devis modifié après approbation : nouvelle version et approbation requises.
12. Dépense additionnelle sans approbation : exclue du coût approuvé.
13. Fichier MIME interdit ou trop volumineux : rejet.
14. Lien signé expiré/révoqué : accès refusé.
15. Prestataire tente d'ouvrir bail ou quittance : refus.
16. Perte réseau après création locale : état en attente jusqu'à accusé.
17. Clôture : locataire reçoit un compte rendu filtré, prestataire ne modifie plus l'ordre clos.
18. Reprise : historique conservé et état rouvert selon transition prévue.
19. Correction de dépense : écriture corrective et motif, pas d'effacement silencieux.
20. Organisation prestataire A ne voit jamais les données de l'organisation B.

Tests sur environnement isolé avec comptes et organisations synthétiques. Le projet Supabase historique NAXA ne doit pas servir de base de recette à cette intégration.

## 17. Lots de réalisation et portes de sortie

### Lot 0 — Inventaire et décisions métier
Inventorier les organisations NAXA SERVICES réellement actives ; confirmer celles relevant de Réparation/Menuiserie ; vérifier spécialités, collaborateurs, zones et capacité ; définir partage coordonnées/photos, plafonds et SLA.

**Sortie :** registre prestataire de référence validé, sans liaison activée.

### Lot 1 — Conception LOYABLE
Cartographier écrans locataire/bailleur/concierge, permissions, données, transitions, règles devis/dépenses et compte rendu ; tester les prototypes avec bailleurs et locataires.

**Sortie :** spécification fonctionnelle approuvée.

### Lot 2 — Profil NAXA SERVICES
Enrichir le profil sans casser le catalogue de 13 activités ; ajouter catégorie compatible, spécialités, zones, disponibilités, capacité et habilitations ; vérifier la sélection d'activité initiale ; préserver les parcours existants par changements additifs.

**Sortie :** profil professionnel exposable par contrat interne autorisé, sans production LOYABLE.

### Lot 3 — API et synchronisation
Définir endpoints, événements, identifiants stables, idempotence, outbox/inbox et erreurs ; implémenter handlers et policies ; tester signatures, RLS, rejeu, conflits et pièces.

**Sortie :** tests intégration verts en base isolée ; aucun déploiement implicite.

### Lot 4 — Parcours vertical pilote
Effectuer un dossier test complet : signalement, qualification, affectation, acceptation, créneau, devis, approbation, exécution, preuve, contrôle et clôture.

**Sortie :** dossier reconstituable de bout en bout et droits validés.

### Lot 5 — Pré-production
Pilote limité, formation, support, mesure des délais/refus/écarts/reprises/satisfaction, audit juridique et sécurité.

**Sortie :** procès-verbal de recette et décision de mise en service séparée.

## 18. Arbitrages encore ouverts [O]

1. Quels plafonds le concierge peut-il engager sans approbation ?
2. Quel délai de réponse est attendu du prestataire ?
3. Quels niveaux d'urgence et délais cibles afficher ?
4. Comment traiter les urgences hors horaires et qui assume l'astreinte ?
5. Quelles sous-spécialités Réparation/Menuiserie existent réellement dans le réseau ?
6. Quelles preuves de qualification exiger et qui les vérifie ?
7. Le téléphone du locataire est-il partagé directement ou via LOYABLE ?
8. Quelle durée de conservation pour photos, vidéos et justificatifs ?
9. Le locataire peut-il évaluer l'intervention ? Évaluation privée au bailleur ou partagée ?
10. Quels critères composent l'historique fiabilité : ponctualité, conformité devis, reprises, réclamations, satisfaction ?
11. Comment traiter frais d'annulation/déplacement en cas d'absence ?
12. Quelle règle contractuelle/juridique régit l'éventuelle refacturation au locataire ?
13. Le bailleur peut-il autoriser des travaux urgents avant devis, sous quelles limites ?
14. Quelles données de localisation partager, à quel moment et pour combien de temps ?
15. Quels critères de classement restent internes et lesquels peuvent être communiqués ?

## 19. Risques et garde-fous

| Risque | Garde-fou |
|---|---|
| Catégorie trop large déduite de l'activité | Limiter à Réparation/Menuiserie et séparer les spécialités |
| Fausse disponibilité | Confirmation au moment de l'affectation |
| Fausse qualification | États déclaré/vérifié distincts |
| Fuite du bail ou des loyers | Payload minimal et permissions par mission |
| Faux statut synchronisé | Accusé serveur persistant obligatoire |
| Ordre ou devis dupliqué | Identifiants stables/idempotence |
| Dépassement de devis | Avenant approuvé |
| Dépense non prouvée | États financiers distincts |
| Intervention mal réalisée | Contrôle, reprise et clôture bailleur |
| Dépendance à une fonction locale | Recette API/RLS isolée avant activation |
| Confusion JOBLY Partner | Réutiliser des patterns, pas comptes/commissions |
| Réemploi de tables pharmacie | Audit de portabilité ; aucune donnée métier pharmacie |

## 20. Références auditées

### LOYABLE
- Cahier historique : 7 famille naxa/01-cahiers-des-charges/06-loyable.md.
- Prompts : 7 famille naxa/02-prompts/06-loyable.md.
- Continuité : docs/loyable/LOYABLE_CONTINUITE.md.

Les décisions LOYABLE du 21 novembre prévalent sur les formulations historiques, notamment l'exclusion des états des lieux et les règles actuelles du Centre de maintenance.

### NAXA SERVICES et socle NAXA
- Cahier : 7 famille naxa/01-cahiers-des-charges/04-naxa-services.md.
- Prompts métier : 7 famille naxa/02-prompts/04-naxa-services.md.
- Prompts socle commun : 7 famille naxa/02-prompts/00-socle-commun.md.
- Rapport de construction : docs/naxa-services/NAXA_SERVICES_CONSTRUCTION_STATUS_2026-11-20.md, consulté sur la branche work/naxa-services-completion-20261120. Cette branche de travail ne prouve pas que tous les éléments sont intégrés dans main ou en production.

### JOBLY
- Pack_Documentaire_JOBLY_2026.pdf.
- 00_ECOSYSTEME_JOBLY_DOCUMENT_MAITRE_V2.pdf.

Les éléments JOBLY sont des références de conception ; aucun module Partner JOBLY n'est déclaré connecté à LOYABLE.

## 21. État de livraison de ce cahier

- [C] Les cahiers LOYABLE et NAXA SERVICES historiques ont été consultés.
- [C] Le document de continuité LOYABLE existant a été relu.
- [C] Le rapport NAXA SERVICES de la branche de travail a été consulté, y compris l'audit du code, les profils, les composants NAXA/JOBLY et les limites de synchronisation.
- [C] Les documents JOBLY ont été consultés pour le domaine Partner/KYC/QR/referral.
- [V] La compatibilité LOYABLE est limitée à Réparation et Menuiserie.
- [P] Profil enrichi et contrat d'interconnexion sont définis comme cibles de conception.
- [O] Les arbitrages de la section 18 restent ouverts.
- Aucune fonctionnalité n'est déclarée développée ou testée par la création de ce cahier.
- Aucune migration Supabase, fonction serveur, intégration API ou déploiement n'a été effectué dans cette passe.

**Ce document constitue la base proposée pour valider le Centre de maintenance LOYABLE et le chantier d'interconnexion.**
