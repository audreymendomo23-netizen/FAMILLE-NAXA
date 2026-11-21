# Continuité dédiée — LOYABLE

> **Date de référence :** 21 novembre 2026  
> **Dépôt :** audreymendomo23-netizen/FAMILLE-NAXA  
> **Branche de travail :** work/loyable-continuity-20261121  
> **Statut :** baseline fonctionnelle consolidée ; conception détaillée à poursuivre ; aucun déploiement ni changement de base réalisé par ce document.

## 0. Règles de lecture et d'autorité

Les statuts employés dans ce document sont :

- **[V] Validé** : arbitrage explicite du propriétaire du projet ou décision antérieure déjà enregistrée comme validée.
- **[P] Proposition** : recommandation de conception utile, mais à confirmer avant de la rendre obligatoire.
- **[O] Ouvert** : décision métier ou commerciale nécessaire.
- **[C] Constat** : élément observé dans un document ou un dépôt ; cela ne prouve pas qu'il fonctionne en production.

Ce document est le point de continuité spécifique de LOYABLE. Il consolide les arbitrages les plus récents et prévaut sur toute formulation antérieure du cahier LOYABLE lorsqu'il existe une contradiction explicite. Le cahier source du 31 octobre 2026 reste conservé comme provenance historique ; il ne doit pas être réécrit silencieusement.

**Supersession importante :** le cahier LOYABLE v1.0 prévoyait des états des lieux d'entrée et de sortie. Le propriétaire du projet a depuis expressément décidé de ne pas inclure cette fonctionnalité dans LOYABLE. Elle est donc **exclue du périmètre cible**, même si elle demeure dans le cahier historique.

## 1. Vision produit et architecture fonctionnelle

LOYABLE n'est pas seulement un outil de suivi des loyers. La vision validée réunit la gestion immobilière, le libre-service des locataires, la découverte de logements et la maintenance opérationnelle.

### 1.1 Les quatre espaces

| Espace | Public | Responsabilité principale |
|---|---|---|
| **LOYABLE Gestion** | Bailleur partenaire et collaborateurs autorisés | Portefeuille, immeubles, biens, unités, locataires, contrats, loyers, paiements, reçus, charges, rentabilité, calendrier, annonces, maintenance et assistant IA |
| **LOYABLE Locataire** | Locataire d'un bien géré dans LOYABLE | Échéances, contrats, déclarations de paiement, preuves, reçus, demandes et suivi de maintenance, réclamations |
| **LOYABLE Immobilier** | Public et chercheurs de logement | Consultation des annonces disponibles par QR code ou lien, filtres de recherche, détail du bien et contact WhatsApp du bailleur |
| **LOYABLE Publication — NAXA** | Personnel NAXA habilité | Enregistrement des bailleurs non partenaires, collecte des informations, contrôle humain, déclaration des paiements hors plateforme, publication et rapprochement d'audit |

L'espace prestataire technique décrit dans la section 8 est une **surface de travail à l'intérieur du domaine LOYABLE**, adaptée au rôle du prestataire. Il n'est pas décidé comme une cinquième application Android indépendante.

### 1.2 Socle métier du bailleur [V]

Le bailleur dispose notamment de :

- portefeuille immobilier, sites, immeubles, biens et unités louables ;
- statut de chaque unité : occupée, disponible, réservée ou indisponible, avec historique ;
- fiches des locataires et liens vers les contrats correspondants ;
- contrats, dates, montant, périodicité, charges, caution/avance, conditions et échéances ;
- calendrier des loyers, avances, paiements partiels, arriérés et soldes ;
- déclarations de paiement soumises par les locataires et validation humaine ;
- reçus individuels et quittances de période ;
- dépenses et charges par unité, bien, immeuble et portefeuille ;
- travaux, maintenance, prestataires, devis, justificatifs et dépenses ;
- pilotage de la rentabilité et exports ;
- calendrier immobilier ;
- gestion des annonces et statistiques de consultation ;
- assistant IA qui analyse et recommande, sans exécuter seul les opérations sensibles.

### 1.3 Espace locataire [V]

Le locataire peut :

- consulter le bien concerné, le contrat et ses principales conditions ;
- voir les prochaines échéances, les montants exigibles, les retards et les paiements enregistrés ;
- déclarer un règlement et joindre une preuve ;
- télécharger les reçus et quittances confirmés ;
- demander un renouvellement, déclarer un préavis ou solliciter une résiliation, sous réserve de la validation du bailleur ;
- transmettre une réclamation ou une contestation ;
- utiliser le centre de maintenance pour signaler une panne, suivre l'intervention et consulter sa clôture.

Les opérations contractuelles qui ont un effet juridique ou financier restent des demandes à examiner et à valider ; une simple pression sur un bouton ne résilie, ne renouvelle et ne modifie pas automatiquement un bail.

### 1.4 Exclusions confirmées

- **État des lieux d'entrée/sortie : exclu [V].**
- Gestion de caméras, fourniture de matériel ou surveillance humaine : hors du périmètre LOYABLE.
- Paiement du loyer encaissé par LOYABLE : non prévu par la vision validée ; le paiement est déclaré par le locataire, puis vérifié par le bailleur.
- L'IA ne confirme pas les paiements, ne modifie pas seule les contrats, ne clôture pas seule les travaux et ne publie/supprime pas seule une annonce sensible.

## 2. Accès par QR code et lien personnel

### 2.1 QR code du site [V]

Chaque site ou ensemble immobilier géré peut disposer d'un QR code public. Le scan ouvre la page LOYABLE du site et oriente vers les actions disponibles :

1. « Je suis locataire » : accès à l'espace locataire ;
2. « Je cherche un logement » : consultation des annonces disponibles rattachées au site ou à la zone ;
3. « Vous êtes bailleur ? Rejoignez LOYABLE » : conversation WhatsApp commerciale NAXA.

Le QR code public ne doit contenir aucune donnée personnelle du locataire ni aucun secret d'accès à son espace.

### 2.2 Identifiant locataire [V]

Le locataire peut utiliser le QR code du site avec son identifiant locataire, lequel figure notamment sur son contrat. Le propriétaire a expressément demandé de ne pas ajouter une vérification supplémentaire de type OTP ou validation sécurisée de seconde étape.

**Risque à conserver visible :** un identifiant inscrit sur un contrat n'est pas un secret. Toute personne qui connaît l'identifiant et le QR du site pourrait tenter d'accéder au dossier. La décision de ne pas ajouter de vérification est enregistrée, mais ne doit pas être présentée comme une authentification forte.

### 2.3 Lien personnel WhatsApp [V]

Le bailleur peut envoyer au locataire un lien personnel par WhatsApp. Ce lien ouvre directement le dossier locataire correspondant, sans code OTP ni étape supplémentaire de vérification.

**Mesures techniques recommandées [P] :**

- jeton à forte entropie, non prévisible et non séquentiel ;
- conservation d'une empreinte du jeton côté serveur plutôt que de sa valeur en clair ;
- révocation immédiate par le bailleur ;
- journalisation des accès et des changements de lien ;
- possibilité de réémettre le lien si le téléphone est perdu ou si le message a été transféré ;
- ne jamais inclure l'identifiant locataire, le numéro de téléphone, le montant du loyer ou une adresse dans l'URL.

La durée d'expiration du lien et les règles de réémission restent à arbitrer [O]. Tant que ces règles ne sont pas décidées, ne pas inventer une durée dans le produit.

### 2.4 Contacts WhatsApp distincts [V]

Deux destinations doivent rester séparées :

- **Contact bailleur** : depuis une annonce, ouvre WhatsApp avec le numéro communiqué par le bailleur concerné.
- **Contact commercial NAXA** : depuis le CTA « Vous êtes bailleur ? Rejoignez LOYABLE », ouvre la conversation WhatsApp Business NAXA configurée.

Le lien et le numéro sont paramétrés et contrôlés ; aucune coordonnée n'est inventée par le système.

## 3. Paiements de loyers, preuves et documents

### 3.1 Cycle de paiement [V]

Le paiement est effectué hors de LOYABLE sur le canal indiqué par le bailleur : Orange Money, MTN Mobile Money ou coordonnées bancaires/RIB. LOYABLE ne collecte pas les fonds dans ce parcours.

1. Le locataire déclare le paiement, le montant, la date et le moyen utilisé.
2. Le locataire ajoute une preuve disponible : photo, capture ou document.
3. Le bailleur examine la déclaration et la preuve.
4. Le bailleur confirme ou rejette manuellement la déclaration.
5. Après confirmation, un reçu est généré dans l'espace du bailleur.
6. Le bailleur transmet le reçu par WhatsApp ; le locataire peut aussi le télécharger à tout moment.

Statuts métier recommandés : **non réglé**, **déclaré**, **en vérification**, **confirmé**, **rejeté**. Les paiements partiels, avances, règlements cumulés et corrections doivent être gérés sans doublon et avec historique.

### 3.2 Reçu et quittance [V]

Un reçu est produit pour chaque règlement confirmé, même partiel. Une quittance de période est disponible lorsque la totalité du montant exigible pour la période est réglée.

Le document doit contenir au minimum :

- référence unique du document ;
- identité et coordonnées professionnelles du bailleur ;
- identité du locataire ;
- désignation du site, immeuble et bien/unité ;
- période locative concernée ;
- montant reçu et devise ;
- date déclarée et date de confirmation ;
- moyen de paiement déclaré et référence disponible ;
- ventilation éventuelle entre loyer, charges, avance ou arriéré ;
- solde restant dû, le cas échéant ;
- auteur de la validation et date d'émission.

Une preuve de paiement téléversée ne vaut pas confirmation : seule la validation humaine du bailleur permet l'émission du reçu confirmé.

## 4. LOYABLE Immobilier — annonces et distribution

### 4.1 Annonces des bailleurs partenaires [V]

- Publication gratuite, sans frais de mise en ligne pour les bailleurs partenaires.
- Création, modification et retrait par le bailleur partenaire depuis son espace.
- Statistiques de vues de chaque annonce accessibles au bailleur.
- Les annonces ne montrent que les biens disponibles et effectivement publiés.
- Lorsqu'une unité devient occupée (par exemple à la suite de l'activation d'un bail dans LOYABLE ou d'une mise à jour explicite de son statut), son annonce est automatiquement retirée de la diffusion publique.
- Si le bien redevient disponible, le bailleur décide de le publier à nouveau ; la vacance ne déclenche pas, à elle seule, une publication automatique.

Chaque chambre ou unité louable distincte correspond à une publication distincte lorsqu'elle est commercialisée séparément.

Le bailleur peut ajuster prix, description, conditions, disponibilité et photos en fonction du marché. Le système conserve l'historique des versions et dates de modification.

### 4.2 Annonces des bailleurs non partenaires [V]

- NAXA peut réaliser une publication pour un bailleur non partenaire.
- Le bailleur externe fournit les informations et médias ; un agent NAXA saisit et contrôle l'annonce.
- Le paiement est réalisé hors de LOYABLE. NAXA enregistre une déclaration de paiement, pas une transaction électronique.
- Une publication assistée expire au bout de deux mois, sauf retrait anticipé après audit humain établissant que le logement a été loué.
- À l'expiration, elle peut être renouvelée sur déclaration du paiement de renouvellement prévu.
- Le bailleur non partenaire ne dispose pas du tableau de bord de gestion partenaire ; les modifications passent par NAXA.

### 4.3 Tarif des publications externes : interprétation à confirmer

Les montants et règles explicitement indiqués par le propriétaire sont :

- tarif de référence de **2 000 FCFA** pour la publication ou le renouvellement ;
- droit initial de **six publications au maximum** ;
- supplément de **500 FCFA par publication au-delà de six** ;
- durée d'une annonce NAXA assistée : deux mois ;
- renouvellement à l'échéance sous réserve du paiement de 2 000 FCFA ;
- une chambre commercialisée séparément représente une publication.

**Point ouvert avant automatisation [O] :** il faut encore confirmer l'unité exacte des 2 000 FCFA. La lecture de travail proposée est « 2 000 FCFA pour un lot allant jusqu'à six annonces pendant une période de deux mois, puis 500 FCFA par annonce supplémentaire, avec paiement de renouvellement à chaque nouvelle période de deux mois ». Cette interprétation n'est pas codée comme tarif définitif tant qu'elle n'a pas été confirmée.

**Point ouvert [O] :** le quota de six doit-il compter les annonces simultanément actives ou toutes les annonces créées/renouvelées pendant le cycle de deux mois ? Recommandation : compter les publications créées ou renouvelées dans le cycle, pour éviter qu'une annonce retirée puis remplacée échappe au suivi financier.

### 4.4 Contrôle et rapprochement externe [V]

Chaque opération de publication/renouvellement doit conserver :

- bailleur externe et coordonnées de référence ;
- annonce, bien et unité concernés ;
- date de création, publication, expiration, retrait ou renouvellement ;
- nombre d'annonces imputées au quota ;
- montant déclaré par NAXA ;
- date, mode et référence de règlement disponibles ;
- agent NAXA ayant saisi et validé la déclaration ;
- motif et preuve d'un retrait anticipé ;
- historique des corrections.

Un export de rapprochement par bailleur et par période doit permettre à un contrôleur externe de comparer nombre de publications, renouvellements, annonces retirées et montants déclarés. Le journal est append-only pour les déclarations financières : une correction ajoute une écriture compensatrice et un motif, elle ne réécrit pas silencieusement l'historique.

### 4.5 Recherche publique et protection des biens

La recherche publique comprend au minimum type de bien, ville, quartier dépendant de la ville, proximité et budget. La fiche détaille description, prix, conditions, équipements, photos et contact bailleur.

Mesures recommandées :

- position publique approximative par défaut ; adresse et géolocalisation précise réservées aux échanges autorisés ;
- suppression des métadonnées EXIF/GPS des photos ;
- preuve que le bailleur possède le bien ou dispose d'un mandat de publication ;
- contrôle de cohérence des photos, prix, statut et coordonnées ;
- modération des annonces, signalement et retrait en cas de fraude ;
- maximum de six photos par annonce, comme prévu dans la vision initiale ;
- interdiction de laisser apparaître une annonce après occupation confirmée.

## 5. Charges, travaux et pilotage de rentabilité

### 5.1 Charges et travaux [V]

Les dépenses restent associées au bon niveau : unité, bien, immeuble ou portefeuille. Les catégories peuvent inclure les frais d'entretien, consommables, réparations, main-d'œuvre, déplacement, remplacement d'équipement et autres dépenses autorisées.

Chaque dépense rattachée à une intervention doit pointer vers le dossier de maintenance correspondant et comporter son justificatif lorsqu'il existe.

### 5.2 Pilotage bailleur [V]

Le bailleur dispose de trois vues :

1. **Par unité/bien :** loyer théorique, loyer confirmé, charges, travaux, vacance, dépenses, revenu net d'exploitation.
2. **Par immeuble/site :** recettes, dépenses, occupation, impayés, réparations et comparaison des unités.
3. **Portefeuille :** revenus attendus et confirmés, arriérés, charges, dépenses de maintenance, taux d'occupation et tendances.

Le bailleur peut saisir, facultativement, prix d'acquisition, frais initiaux, rénovation ou investissements. Sans ces données, LOYABLE mesure le revenu et la rentabilité d'exploitation ; il ne prétend pas calculer un rendement total du capital investi.

## 6. Calendrier immobilier et assistant IA

### 6.1 Calendrier bailleur [V]

Le calendrier regroupe :

- échéances de loyer, retards et rappels ;
- dates de début, fin et renouvellement des baux ;
- échéances de charges et contrats de service ;
- visites commerciales pour des unités disponibles ;
- rendez-vous locataires et concierge ;
- interventions de maintenance planifiées ;
- devis à valider, travaux en attente, pièces attendues et clôtures à vérifier.

Les inspections assimilables à des états des lieux d'entrée/sortie ne sont pas ajoutées au calendrier, car la fonction d'état des lieux est exclue.

### 6.2 Assistant IA bailleur [V pour le principe, [P] pour la première version]

L'assistant répond sur les données autorisées : « Quels biens ont le plus de dépenses de maintenance ? », « Quelles interventions sont en retard ? », « Quelles unités sont les moins rentables ? », « Quels loyers restent à confirmer ? ».

Il peut :

- résumer les retards et échéances ;
- signaler des dépenses inhabituelles ou répétées ;
- proposer des prestataires selon spécialité, zone et disponibilité ;
- comparer les devis et dépenses historiques ;
- rédiger un message au locataire, concierge ou prestataire ;
- préparer un briefing ou un rapport.

L'IA explique ses sources et ses limites. Elle ne confirme jamais un loyer, n'engage jamais une dépense, ne choisit pas définitivement un prestataire, ne modifie pas un contrat et ne clôture pas seule une intervention.

## 7. Rôles à prévoir

| Rôle | Accès principal |
|---|---|
| Bailleur / propriétaire | Tous les biens et données de son portefeuille ; validation des paiements, devis, dépenses, contrats et clôtures |
| Gestionnaire | Périmètre des biens délégués par le bailleur ; droits configurables |
| Concierge | Sites et unités affectés ; réception/tri des demandes, planification et suivi, sans accès indu aux comptes financiers ou contrats complets |
| Comptable | Documents et agrégats financiers autorisés ; idéalement accès temporaire en lecture seule |
| Locataire | Son propre contrat, son unité, ses déclarations, reçus, réclamations et demandes de maintenance |
| Prestataire technique | Uniquement les interventions qui lui sont affectées et les informations nécessaires à leur exécution |
| Agent de publication NAXA | Annonces de bailleurs non partenaires, déclaration des paiements, contrôles et historique des publications |
| Contrôle/audit NAXA | États de rapprochement et traces nécessaires ; pas d'accès général aux contrats ou dossiers personnels sans habilitation spécifique |

Les comptes d'un prestataire externe ne reçoivent aucun accès implicite au portefeuille du bailleur. Un concierge ne devient pas propriétaire ou administrateur général de l'organisation par le seul fait d'être affecté à un site.

## 8. Centre de maintenance — capitaliser sur le réseau de prestataires

### 8.1 Objectif fonctionnel [V]

Un locataire signale un problème. Le bailleur ou un collaborateur habilité trie le signalement et l'affecte au concierge, à une équipe interne ou à un prestataire technique spécialisé. Le travail est suivi jusqu'à sa clôture avec justificatifs, photos, décisions et dépenses de bout en bout.

Le Centre de maintenance est intégré au portail Locataire pour la déclaration et le suivi, et à LOYABLE Gestion pour le triage, l'affectation, l'approbation et le pilotage.

### 8.2 Patrimoine NAXA réutilisable — constats [C]

L'audit du dépôt NAXA historique a retrouvé un dispositif de prestations à domicile comprenant notamment :

- un catalogue client de prestations et une RPC de lecture du catalogue ;
- des offres rattachées à un partenaire, avec nom, catégorie, spécialité, description, zone de service et prix indicatif ;
- des demandes de service, avec préférence horaire du client et créneau effectivement confirmé distinct ;
- des profils Partenaire et membres avec rôles propriétaire/manager/opérateur ;
- une disponibilité hebdomadaire, une position de référence et une position professionnelle lorsqu'elle est autorisée ;
- des coordonnées exactes du demandeur séparées de la fiche de catalogue et masquées au professionnel avant confirmation ;
- un statut de demande, une confirmation avec horaire retenu, puis une clôture ;
- des préférences et files de rappels, ainsi que des notifications in-app/Push et une file d'envoi.

Le code source contient les entités historiques suivantes, utiles comme références de conception : **home_service_offers**, **home_service_requests**, **home_service_request_addresses**, **home_service_reminder_preferences**, **home_service_reminder_dispatches**, **partners**, **partner_members**, **partner_weekly_availability** et **partner_independent_agreements**.

La migration de rappel consultée ajoute notamment un horaire confirmé, des préférences de rappels par membre et partenaire, une file avec déduplication et reprise de tâches abandonnées, et une fonction de confirmation qui impose un créneau réel. Le dispositif distingue le moment souhaité par le client de celui que le professionnel confirme réellement.

**Limite majeure :** le rapport d'audit NAXA du 11 novembre qualifie le dispositif comme partiel et non « au vert ». L'invitation professionnelle, le profil/médias complets, certains parcours de réabonnement, les tests complets et la recette Android figuraient parmi les points ouverts. Ces composants sont donc des actifs de référence et des accélérateurs, pas une preuve qu'un réseau prêt à être connecté à LOYABLE existe déjà en production.

**Vigilance de classification :** l'ancienne vitrine NAXA consultée est intitulée « Soins à domicile » et le partenaire historique porte le type technique professionnel_domicile. Le modèle contient aussi des qualifications médicales distinctes. Il ne faut donc pas traiter tous les profils de cet univers comme des techniciens du bâtiment ni importer des agréments médicaux dans LOYABLE. La liste exacte des spécialités techniques doit être extraite du catalogue réel puis validée par NAXA et le propriétaire du projet avant toute migration.

### 8.3 Stratégie de capitalisation recommandée [P]

Créer un **répertoire de prestataires techniques éligibles à LOYABLE**, alimenté par les partenaires déjà connus de NAXA après vérification et consentement.

Ne pas accorder au prestataire les anciennes permissions NAXA dans LOYABLE. Le profil utile est réinscrit dans un contexte LOYABLE propre, avec une référence externe facultative à son dossier source pour la traçabilité.

Par prestataire, LOYABLE doit pouvoir stocker :

- personne ou entreprise, représentant et moyens de contact professionnels ;
- spécialités et sous-spécialités réellement validées ;
- zone d'intervention : villes, quartiers, rayon ou secteurs ;
- disponibilité et créneaux de service ;
- capacité : seul, équipe, nombre d'interventions simultanées ;
- tarif indicatif, frais de déplacement, mode de devis et éventuelles urgences ;
- pièces justificatives ou certifications pertinentes pour le métier, dates de vérification et expiration ;
- statut d'activation, suspension, disponibilité et motifs ;
- acceptation des conditions de service, confidentialité et règles d'accès aux logements ;
- historique des missions LOYABLE, ponctualité, devis, coûts et réclamations.

Le catalogue ne doit pas inventer des spécialités. Les exemples possibles (à confirmer après inventaire) incluent plomberie, électricité, climatisation, serrurerie, menuiserie, peinture, étanchéité/toiture, maçonnerie et réparation d'équipements. Seules les catégories présentes ou nouvellement approuvées doivent être activées.

### 8.4 Séquence complète d'une demande de maintenance [V pour le parcours ; [P] pour les états techniques]

**Étape 1 — Signalement locataire**

Le locataire choisit une catégorie, décrit le problème, précise son urgence, ajoute des photos/vidéo si utile et propose des plages de disponibilité. Le dossier est automatiquement rattaché à son unité et au bon site. Il indique si le logement peut être ouvert et dans quelles conditions.

**Étape 2 — Triage**

Le bailleur ou le concierge examine la demande, demande des précisions si nécessaire, classe la priorité, distingue urgence, panne simple, entretien programmé ou dommage potentiellement imputable. La priorité ne doit pas être déterminée uniquement par l'IA.

**Étape 3 — Affectation**

Le bailleur choisit :
- le concierge ou un employé interne ;
- un technicien déjà connu du bailleur ;
- un partenaire technique du réseau NAXA éligible.

Le moteur peut proposer une liste selon spécialité, zone, disponibilité, délai de réponse et historique. La décision finale reste humaine.

**Étape 4 — Acceptation et planification**

Le prestataire accepte ou refuse la mission, indique le premier créneau possible et, si nécessaire, demande des précisions. L'horaire confirmé est distinct de la préférence du locataire. Le locataire reçoit la date, la plage et le nom du contact autorisé.

**Étape 5 — Diagnostic et devis**

Le prestataire peut réaliser un diagnostic. Il propose un devis détaillé : main-d'œuvre, pièces, consommables, déplacement, taxes ou autres frais applicables, délai et durée de validité. Le bailleur valide, refuse ou demande une révision. Aucune dépense dépassant le plafond autorisé n'est engagée sans nouvelle validation, sauf urgence couverte par une règle écrite préalablement approuvée.

**Étape 6 — Exécution et preuves**

Le technicien met à jour l'avancement, ajoute photos avant/pendant/après, pièces utilisées, temps passé, compte rendu et justificatifs. Le concierge et le bailleur voient l'évolution selon leurs droits. Toute modification de devis, dépense ou périmètre est versionnée et soumise à approbation si elle augmente le coût.

**Étape 7 — Fin des travaux et validation**

Le prestataire soumet la mission comme terminée, avec compte rendu, photos finales, facture/reçu et éventuelle garantie. Le locataire peut signaler que le problème persiste ; le bailleur ou le concierge valide la clôture ou rouvre le dossier en motivant sa décision.

**Étape 8 — Comptabilisation et historique**

Les dépenses sont enregistrées sur la bonne unité/bien, reliées à la mission et ventilées par catégorie. Le coût réellement payé, le coût restant, le payeur et toute somme éventuellement refacturable sont distingués. Le tableau de rentabilité est mis à jour.

### 8.5 Cycle de statut proposé [P]

| Statut | Sens |
|---|---|
| Signalée | Demande envoyée par le locataire |
| À qualifier | Triage par bailleur/concierge |
| Affectée | Conciergerie ou prestataire désigné |
| Acceptée / refusée | Réponse du responsable affecté |
| Planifiée | Créneau convenu |
| Diagnostic / devis | Évaluation et chiffrage en cours |
| En attente d'approbation | Décision du bailleur requise |
| En cours | Intervention engagée |
| En attente de pièce | Travail suspendu avec motif |
| Terminée à vérifier | Prestataire a soumis ses preuves de fin |
| Clôturée | Validation finale et enregistrement des coûts |
| Contestée / rouverte | Problème non résolu ou preuve insuffisante |
| Annulée | Annulation motivée |

Les transitions doivent être contrôlées côté serveur, horodatées et attribuées à un auteur. Une mission clôturée ne doit pas être effacée ; une correction passe par une réouverture ou un événement correctif audité.

### 8.6 Affectation des dépenses et responsabilité [O]

LOYABLE doit conserver séparément :

- le coût des travaux réellement supporté ;
- la personne qui règle le prestataire ;
- l'entité qui supporte finalement la charge (bailleur, locataire ou partage) ;
- le montant éventuellement refacturé au locataire ;
- le fondement contractuel et la validation du bailleur.

**Règle de prudence :** l'application ne décide pas automatiquement qu'une réparation est à la charge du locataire. Toute refacturation doit être examinée au regard du bail, de la nature du dommage et des règles applicables, puis validée par le bailleur. Cette décision est ouverte et nécessite une règle contractuelle et juridique avant automatisation.

### 8.7 Confidentialité et sécurité des prestataires

Le prestataire ne voit que les missions qui lui sont affectées et les informations indispensables : type de panne, localisation utile, créneau, consignes d'accès, contact autorisé et pièces nécessaires.

Il ne peut pas consulter :

- le contrat complet du locataire ;
- ses loyers, arriérés, preuves de paiement ou reçus ;
- les autres unités du portefeuille ;
- les coordonnées d'autres locataires ;
- les données de rentabilité du bailleur ;
- les missions d'autres prestataires.

L'adresse exacte et le téléphone sont divulgués seulement après affectation autorisée et selon le besoin d'exécution. Les photos et documents sont stockés dans un espace privé, avec contrôle d'accès, liens temporaires et historique de consultation.

### 8.8 Valeur créée par le réseau NAXA

Pour LOYABLE :
- accès plus rapide à un réseau de spécialistes déjà identifiés ;
- meilleure réactivité dans les réparations ;
- comparaison des devis et dépenses par métier ;
- traçabilité des délais, reprises, coûts et qualité ;
- réduction du travail de recherche du bailleur ;
- données réelles pour le pilotage de rentabilité.

Pour les partenaires techniques NAXA :
- nouvelles demandes qualifiées provenant de portefeuilles immobiliers ;
- missions récurrentes plutôt que demandes isolées ;
- historique de leurs interventions et de leur qualité ;
- meilleure planification géographique et regroupement des déplacements ;
- possibilité de développer des relations avec des bailleurs partenaires.

Pour NAXA :
- valorisation croisée des actifs et relations existants ;
- acquisition de bailleurs partenaires par une promesse de maintenance structurée ;
- suivi auditable des interventions sans que NAXA devienne elle-même réparateur, assureur ou entreprise de surveillance ;
- possibilité ultérieure de mesurer les revenus d'intermédiation si un modèle commercial distinct est approuvé. Aucun frais de mise en relation ou commission n'est fixé dans la présente baseline.

### 8.9 Ordre de mise en œuvre recommandé [P]

**Lot M0 — Inventaire et qualification du réseau**
1. Export contrôlé du catalogue existant et de la liste des partenaires.
2. Classification technique / médical / autre ; exclusion des comptes non pertinents.
3. Vérification du titulaire, du contact, de la spécialité, de la ville/zone, du statut, de la disponibilité et des autorisations.
4. Invitation et consentement à recevoir des missions LOYABLE.
5. Création du profil prestataire LOYABLE distinct, relié à une référence source non autorisante.

**Lot M1 — Centre de maintenance piloté par bailleur**
- Signalement locataire.
- Triage bailleur/concierge.
- Affectation manuelle à un technicien interne ou externe.
- Rendez-vous, devis, approbation, photos, justificatifs et clôture.
- Enregistrement des dépenses et mise à jour de la rentabilité.
- Notifications in-app et liens WhatsApp préparés lorsque l'envoi automatique n'est pas autorisé.

**Lot M2 — Espace prestataire mobile**
- Connexion prestataire propre à LOYABLE.
- Liste de missions affectées, acceptation/refus, créneaux, devis, avancement, photos, factures et demande de clôture.
- Accès Web/PWA mobile initial ; aucune APK dédiée n'est requise pour le MVP.

**Lot M3 — Matching et pilotage**
- Suggestions de prestataires par métier, couverture, disponibilité et historique ;
- alertes de délai et missions en souffrance ;
- comparaison de devis et dépenses ;
- performance par prestataire, spécialité, site et bailleur.

### 8.10 Critères de recette du Centre de maintenance

- Un locataire ne peut créer et consulter que des demandes rattachées à son propre dossier/unité.
- Le bailleur et le concierge ne voient que les sites et unités qui leur sont attribués.
- Un prestataire ne voit que les interventions qui lui sont affectées.
- L'adresse exacte et les coordonnées du locataire ne sont pas accessibles avant l'étape autorisée.
- Un devis doit être validé avant exécution, sauf politique d'urgence définie et approuvée.
- Les dépassements de budget nécessitent une nouvelle validation.
- Les photos, pièces, factures et décisions sont liées à la même mission.
- Les coûts sont enregistrés une seule fois malgré les synchronisations et reprises réseau.
- Une mission ne peut être clôturée sans compte rendu et décision de validation.
- Une contestation peut rouvrir la mission sans supprimer les preuves précédentes.
- Les opérations offline sont synchronisées de façon idempotente et les conflits sont visibles.
- Les notifications sont dédupliquées et reprenables ; les erreurs de livraison sont suivies.
- Les tests RLS prouvent l'isolation entre bailleurs, locataires, concierges et prestataires.
- Le rapport de maintenance est consultable et exportable par le bailleur.

## 9. Architecture de données et intégration

### 9.1 Principe

Le backend LOYABLE est l'autorité sur les contrats, les unités, les demandes locataires, les ordres de travail et les dépenses immobilières.

Les mécanismes historiques NAXA sont étudiés et adaptés ; les tables et permissions héritées ne doivent pas être réutilisées comme si elles étaient déjà le modèle LOYABLE.

### 9.2 Entités LOYABLE à concevoir

Les noms ci-dessous sont des noms de domaine indicatifs, pas des migrations validées :

- portefeuille, organisation et membres ;
- sites, immeubles, biens et unités ;
- locataires, liens d'accès, contrats et échéanciers ;
- déclarations de paiement, preuves, validations, reçus et quittances ;
- charges, catégories de dépenses et écritures de maintenance ;
- annonces, médias, compteurs de consultation et historique de publication ;
- concierge et affectations de sites ;
- profil prestataire, spécialités, qualifications, zones, disponibilité et consentements ;
- demande de maintenance, ordre de travail, affectation, créneaux, devis, approbations, étapes, dépenses, pièces, photos et clôture ;
- événements d'audit, notifications, journaux de synchronisation et exports.

### 9.3 Interopérabilité NAXA — frontières impératives

- Ne pas faire dépendre LOYABLE d'une jointure permanente sur les anciennes tables partenaires de NAXA.
- Ne pas réutiliser directement les profils, rôles ou permissions médicales pour autoriser une intervention technique.
- Ne pas partager automatiquement l'identité ou la session d'un utilisateur d'une application à l'autre.
- Une correspondance éventuelle avec un partenaire historique doit être établie après vérification et consentement, puis stockée comme référence externe traçable ; elle ne vaut pas autorisation LOYABLE.
- Les données métier du bailleur, du locataire et du patrimoine restent cloisonnées dans LOYABLE.
- Les notifications et rappels peuvent réutiliser les patterns/outils communs après audit, avec des événements LOYABLE propres.
- Les appels à l'ancien NAXA doivent passer par un contrat d'intégration limité, versionné et révocable si une intégration directe est retenue.

## 10. Stratégie de livraison LOYABLE

### Phase L0 — Cartographie et conception
- Cartographier écrans, parcours, profils et droits des quatre espaces.
- Inventorier les données existantes et établir le modèle LOYABLE.
- Définir les statuts des unités, baux, paiements, annonces et maintenance.
- Inventorier le catalogue technique réel et les partenaires NAXA éligibles.
- Décider les ambiguïtés tarifaires et les règles de sécurité.

### Phase L1 — Cœur de gestion immobilière
- Portefeuille, sites, immeubles, biens et unités.
- Locataires et contrats.
- Échéanciers, charges, paiements déclarés, validation humaine, reçus.
- Droits et audit.
- Tableau de bord bailleur et calendrier de base.

### Phase L2 — Portail locataire
- QR site, identifiant, lien personnel WhatsApp.
- Consultation du bail, échéances et documents.
- Déclaration de paiement, preuves et téléchargements.
- Réclamations et centre de maintenance pour signaler/suivre les demandes.

### Phase L3 — Centre de maintenance
- Triage concierge/bailleur.
- Répertoire LOYABLE des prestataires et import qualifié du réseau.
- Affectations, acceptation, devis et validation.
- Suivi de travail, médias, dépenses, clôture et rentabilité.
- Recette avec un petit réseau pilote de techniciens.

### Phase L4 — Immobilier et Publication NAXA
- QR et lien public, recherche et filtres.
- Annonces gratuites des bailleurs partenaires.
- Dépublication automatique à l'occupation.
- Publication assistée NAXA pour bailleurs externes.
- Déclaration des montants et rapprochement externe.
- Statistiques de vues et outil de modération.

### Phase L5 — Fonctions avancées
- Assistant IA, analyses de rentabilité, prévisions et briefings.
- Matching des prestataires, délais et statistiques qualité.
- Exports avancés et intégrations supplémentaires après validation.

L'ordre peut être ajusté par l'utilisateur, mais le modèle de données et les droits doivent précéder la réalisation visuelle définitive.

## 11. Points ouverts à arbitrer avant automatisation complète

| ID | Sujet | Proposition de référence | Statut |
|---|---|---|---|
| O-01 | Unité tarifaire des 2 000 FCFA externes | 2 000 FCFA par lot jusqu'à six annonces et par cycle de deux mois | À confirmer |
| O-02 | Comptage des six publications | Compter les annonces créées/renouvelées pendant le cycle | À confirmer |
| O-03 | Liens locataires | Jeton non devinable et révocable ; durée à définir | À confirmer |
| O-04 | Détection d'occupation | Retrait automatique après bail actif ou changement de statut validé | Critères techniques à préciser |
| O-05 | Quota de photos | Six photos maximum par annonce | Validé dans la vision initiale |
| O-06 | Prestataires techniques | Inventaire des spécialités exactes et qualification du réseau | À réaliser |
| O-07 | Accès prestataire | Espace mobile Web/PWA minimal dans LOYABLE | Proposition |
| O-08 | Urgences et budget | Plafond et procédure d'urgence préautorisés par le bailleur | À arbitrer |
| O-09 | Facturation/refacturation des travaux | Règles de responsabilité par bail, catégorie et validation humaine | À définir avec revue juridique |
| O-10 | Confirmation de clôture | Validation bailleur/concierge et canal de contestation locataire | À confirmer |
| O-11 | Rémunération NAXA/commission prestataire | Aucun frais ni commission décidé dans cette baseline | À arbitrer avant monétisation |
| O-12 | Notifications WhatsApp automatiques | Les liens wa.me préparés sont possibles ; l'envoi automatique nécessite une intégration autorisée distincte | À décider si requis |

## 12. Références documentaires et techniques examinées

### FAMILLE-NAXA
- Cahier LOYABLE : **7 famille naxa/01-cahiers-des-charges/06-loyable.md** (version source v1.0 du 31 octobre 2026).
- Cahier NAXA Services : **7 famille naxa/01-cahiers-des-charges/04-naxa-services.md**.
- Continuité générale : **docs/CONTINUITE.md**, notamment les sections 6.15 à 6.17, qui consignent le chantier NAXA SERVICES, les frontières d'applications et le catalogue tarifaire de référence.
- Architecture cible : **docs/ARCHITECTURE_CIBLE.md**.
- Audit source : **docs/audits/AUDIT_GLOBAL_SOURCES_NAXA_FAMILLE_ET_PRIORISATION_2026-11-20.md**.

### NAXA historique
- Audit 360° « NAXA Prestations et soins à domicile » daté du 11 novembre 2026.
- Fichier de migration **supabase/migrations/20261111160000_home_services_appointments_reminders.sql**.
- Routes consultées : **src/app/prestations/page.tsx**, **src/app/partenaire/prestations/page.tsx**, **src/app/partenaire/prestations/actions.ts** et **src/app/admin/creation-univers-actions.ts**.

### Limites de preuve

- L'existence de fichiers, d'écrans et de migrations ne prouve pas qu'ils sont déployés ou opérationnels en production.
- L'audit du réseau de prestations à domicile signale plusieurs points incomplets et une recette globale non terminée.
- La liste exacte des partenaires techniques et de leurs spécialités n'a pas encore été exportée et qualifiée dans ce document.
- Aucun prestataire réel n'a été importé ou contacté.
- Aucune migration LOYABLE, modification de données, modification Auth, déploiement ni publication APK n'a été effectuée lors de la création de ce document.

## 13. Prochaine étape immédiate

Avant de développer les écrans, réaliser deux inventaires liés :

1. **Inventaire LOYABLE :** écrans, rôles, droits, parcours, données et statuts de chaque espace.
2. **Inventaire NAXA Prestations à domicile :** catégories et spécialités réelles, partenaires actifs, couverture géographique, profils, conditions, consentements et limites de maturité.

Le résultat doit identifier, ligne par ligne, ce qui peut être réutilisé comme pattern, ce qui peut être importé après consentement, ce qui doit être recréé dans le domaine LOYABLE et ce qui doit être exclu.
