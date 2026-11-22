# CAHIER DES CHARGES MAÎTRE — CAMPUS237
## ERP scolaire, plateforme familiale, protection des élèves et écosystème éducatif à 360°

**Version :** 3.0.2 — baseline enrichie et décisions pédagogiques/économiques verrouillées  
**Date de référence :** 22 novembre 2026  
**Produit :** Campus237  
**Dépôt :** Famille NAXA  
**Document précédent :** Cahier_des_charges_08_Campus237.pdf — V2.0 du 5 novembre 2026  
**Nature :** spécification fonctionnelle, métier, opérationnelle, économique, technique et de conformité  
**Statut :** baseline V3.0 consolidée et amendée par les addenda V3.0.1 et V3.0.2 du 22 novembre 2026 ; les décisions approuvées sont verrouillées et les seuls arbitrages résiduels sont identifiés.

---

# 0. CONTRÔLE DU DOCUMENT ET RÈGLES DE GEL

## 0.1 Objet

Le présent document est le cahier des charges maître de CAMPUS237. Il consolide :
- toutes les exigences et décisions marquées [V] dans le cahier V2.0 du 5 novembre 2026 ;
- les décisions et précisions complémentaires exprimées dans les échanges de cadrage postérieurs à la V2.0 ;
- les nouveaux parcours d'inscription, de paiement et d'identification ;
- les nouveaux parcours de notation par scan des copies et de diffusion des résultats ;
- le compte enseignant et le système d'affectation des enseignants par le chef d'établissement ;
- le suivi du programme de cours, les préparations filmées par les enseignants et le suivi réel des cours par les parents ;
- le contrôle des entrées et sorties par QR code sur le badge de l'élève ;
- l'intégration NAXA SECURITY et l'analyse IA d'événements dangereux détectés par les caméras compatibles de l'établissement ;
- la communauté privée de chaque établissement ;
- CAMPUS237 KNOWLEDGE et CAMPUS237 OPPORTUNITIES ;
- les exigences métier, financières, techniques, de sécurité, de conformité, de recette et d'exploitation.

La V2.0 demeure conservée comme document historique. La V3.0.2 devient le document de référence pour les nouvelles spécifications, sous réserve des arbitrages explicitement indiqués dans ce document. La V3.0 ne signifie pas que le logiciel est déjà développé, testé, certifié ou mis en production.

## 0.2 Légende des statuts

| Marque | Signification | Règle de traitement |
|---|---|---|
| 🔒 VALIDÉE / VERROUILLÉE | Décision explicitement validée dans la V2.0 ou confirmée directement par le porteur du projet | À conserver ; toute modification ultérieure doit être tracée |
| 🔵 PROPOSITION V3 | Amélioration recommandée pour atteindre le niveau cible 10/10 | À intégrer dans la conception, puis à valider si elle modifie une décision métier |
| 🟡 IDÉE | Piste non arbitrée | Ne pas développer comme exigence ferme sans validation |
| ⚠️ ARBITRAGE | Donnée contradictoire, incomplète ou décision manquante | Ne pas inventer de valeur ; bloquer uniquement le sous-parcours concerné |
| 🛡️ GATE DE CONFORMITÉ / SÉCURITÉ | Condition obligatoire avant activation d'un traitement sensible ou mise en service | Aucune mise en production du traitement concerné avant preuve de conformité |

## 0.3 Règles de gel

1. Une exigence 🔒 ne peut être modifiée que par une décision écrite et datée du porteur du projet.
2. Une décision nouvelle ne remplace une décision antérieure que si le conflit est explicitement indiqué dans le registre de décisions.
3. Une proposition IA n'est jamais présentée comme une décision du porteur.
4. Une valeur tarifaire absente n'est jamais inventée.
5. Une exigence réglementaire ou de sécurité ne peut pas être contournée pour accélérer une livraison.
6. Toute exigence fonctionnelle possède un identifiant, un acteur, une règle, des exceptions et au moins un critère de recette.
7. La conformité juridique et la sécurité des enfants sont des conditions de mise en service, pas des améliorations facultatives.
8. Le développement par jalons est autorisé ; la mise en service d'un périmètre incomplet ne l'est pas. Le projet conserve l'orientation de lancement direct, sans pilote public, mais impose une recette interne complète avant ouverture aux utilisateurs.
9. Le document n'autorise à lui seul aucune modification de code, exécution SQL, déploiement ou changement d'infrastructure.
10. Le dépôt de référence de la famille est FAMILLE-NAXA ; toute écriture documentaire doit respecter les règles de travail du dépôt.

## 0.4 Historique documentaire

| Version | Date | Description |
|---|---|---|
| V2.0 | 05/11/2026 | Cahier initial de 13 pages : ERP scolaire, paiements, gestion parent, sécurité, bibliothèque, RH, finance, IA et jalons |
| V3.0 | 22/11/2026 | Consolidation maître : SMART ENROLL, SMART GRADING, TEACHER SPACE, cours réels et préparations filmées, QR d'arrivée/sortie, NAXA SECURITY avec détection IA d'événements dangereux, COMMUNITY, KNOWLEDGE, OPPORTUNITIES et clarification des arbitrages |
| V3.0.1 | 22/11/2026 | Addendum : compte APE et réunions/visioconférences, convocations scolaires hybrides, livret scolaire unique portable et non modifiable en place, offres de rentrée et recherche conversationnelle d'établissements avec rendez-vous en présentiel |
| V3.0.2 | 22/11/2026 | Bulletin vivant, ACADEMIC RADAR et rang parental avant bulletin, modèle de licence établissement par élève, ACCESS gratuit et PREMIUM familial, continuité pédagogique, compétences, remédiation, tableau familial, réunification, GPS bus et menus cantine |

---

# 1. VISION, POSITIONNEMENT ET PÉRIMÈTRE

## 1.1 Vision

🔒 CAMPUS237 est une plateforme éducative et un ERP scolaire à 360° permettant à un établissement unique ou à un groupe scolaire de gérer ses activités administratives, financières, pédagogiques, humaines, matérielles et opérationnelles, tout en donnant aux parents un suivi fiable de la scolarité et de la sécurité de leurs enfants.

La plateforme couvre les établissements publics et privés, les groupes scolaires et les centres de formation professionnelle, de la maternelle à la formation professionnelle.

CAMPUS237 doit devenir une infrastructure numérique qui relie :
- promoteurs et groupes scolaires ;
- directions d'établissement ;
- secrétariats et services administratifs ;
- enseignants et professeurs principaux ;
- élèves, lorsque l'établissement active leur accès ;
- parents et tuteurs ;
- personnels de surveillance et de sécurité ;
- APEE et associations de parents ;
- prestataires de services ;
- organismes de formation et entreprises partenaires.

## 1.2 Principes non négociables

🔒 Un même outil doit couvrir l'essentiel de la vie de l'établissement, sans multiplier les applications incompatibles.

🔒 Les opérations de l'école doivent fonctionner hors connexion autant que possible et se synchroniser sans doublon.

🔒 L'IA assiste, signale, extrait, calcule et recommande ; l'humain reste responsable des décisions scolaires, pédagogiques, disciplinaires et financières.

🔒 Aucun PIN ni OTP d'opérateur ou de banque ne doit être lu, enregistré, demandé ou transmis par CAMPUS237.

🔒 La protection des mineurs, la minimisation des données et les accès par rôle sont prioritaires.

🔒 Les fonctions de sécurité de l'élève (présence, arrivée, sortie, retrait autorisé, alertes) ne sont jamais conditionnées au paiement d'un abonnement Premium parent.

🔒 Les parents ne créent pas librement un accès complet à un dossier élève : leur lien avec l'enfant est établi et vérifié par l'établissement.

🔒 Les écoles ne fournissent pas nécessairement de matériel informatique ou de caméras via CAMPUS237. Les intégrations matérielles utilisent les équipements compatibles de l'école ou de ses prestataires.

## 1.3 Périmètre produit

La plateforme comprend les surfaces suivantes :

| Surface | Utilisateurs | Rôle |
|---|---|---|
| CAMPUS237 SCHOOL | Direction, secrétariat, économat, censeur, personnel, enseignants, vigiles et services | Application Android de l'établissement, une application avec permissions selon les rôles |
| CAMPUS237 FAMILY | Parents et tuteurs | Application Android parent légère, multi-enfants et multi-écoles |
| CAMPUS237 DIRECTION | Directeurs et promoteurs | Espace web responsive de direction, administration et consolidation |
| CAMPUS237 PLATFORM ADMIN | Équipe d'administration CAMPUS237 | Création des établissements, comptes, abonnements, support et paramètres globaux |
| CAMPUS237 PARTNERS | Entreprises, centres de formation, tuteurs et partenaires | Espace partenaire et publication d'opportunités |
| CAMPUS237 KNOWLEDGE | Parents et élèves selon les droits | Bibliothèque, encyclopédie, vidéos et annales |
| CAMPUS237 COMMUNITY | Parents vérifiés et représentants de l'école | Communauté privée propre à chaque établissement |

Le professeur utilise le compte enseignant dans CAMPUS237 SCHOOL. Il n'est pas nécessaire de créer une application enseignante indépendante pour la V1, sauf arbitrage ultérieur.

## 1.4 Public et secteurs couverts

🔒 Types d'établissements :
- maternelles et préscolaires ;
- écoles primaires ;
- collèges et lycées francophones ;
- collèges et lycées anglophones ;
- établissements bilingues ;
- établissements et sections arabophones, chinoises ou autres ;
- établissements publics, privés et confessionnels ;
- centres de formation professionnelle ;
- instituts et écoles techniques ;
- structures avec internat.

Les différences entre établissements publics et privés, notamment les droits exigibles, les frais, les validations et les rapports officiels, doivent être paramétrables. Les circuits officiels restent prioritaires sur toute gestion parallèle.

---

# 2. ACTEURS, COMPTES ET MATRICE DES RESPONSABILITÉS

## 2.1 Règles de création des comptes

🔒 Les accès du personnel sont créés par l'administration de la plateforme ou par le chef d'établissement selon les délégations accordées. Le chef d'établissement crée et affecte les comptes de son personnel.

🔒 Chaque professeur dispose d'un compte personnel. Ses affectations déterminent exactement les classes, matières, établissements et périodes qu'il peut consulter ou modifier.

🔒 Le parent ne dispose pas d'une inscription libre lui donnant accès à un enfant. Son compte est lié au dossier par l'établissement, avec QR d'activation, code parent ou procédure de vérification.

🔵 Un même compte parent doit pouvoir regrouper plusieurs enfants et plusieurs établissements partenaires, avec des droits distincts par enfant et par établissement.

## 2.2 Rôles de l'établissement

| Rôle | Accès et responsabilités |
|---|---|
| Promoteur | Consolidation de ses écoles : effectifs, revenus, recouvrement, trésorerie, résultats agrégés, comparatifs, budgets et validation des dépenses selon seuils |
| Chef d'établissement | Pilotage de son école, inscriptions, personnel, affectations, validations, bulletins, discipline, sécurité, communication et rapports |
| Censeur / surveillant général | Emplois du temps, appels, absences, discipline, conseils de classe, suivi des cours, retards, remplacements et vie scolaire |
| Économe / comptable | Rubriques, factures, paiements, rapprochements, relances, comptabilité, paie, achats et contrôle de caisse |
| Caissier | Encaissements autorisés sur son poste, reçus, clôture de caisse et opérations de caisse déléguées |
| Secrétariat / scolarité | Admissions, matricules, dossiers, cartes, certificats, transferts et documents |
| Enseignant | Ses classes et matières affectées : préparation de cours, vidéo pédagogique de préparation, appel si autorisé, devoirs, notes, scan, validation et diffusion |
| Professeur principal | Suivi global de sa classe, coordination des enseignants, préparation des conseils, bulletins et communication encadrée |
| Agent d'entrée / vigile | Scan des badges, contrôle visuel, visiteurs, événements d'entrée et de sortie, retrait autorisé ; aucun accès financier ou pédagogique |
| Cantine | Menus, repas, allergènes utiles, présences aux repas et stocks de son service |
| Transport | Circuits, arrêts, véhicules, conducteurs, accompagnateurs et événements de montée/descente |
| Infirmerie | Dossier de santé strictement limité aux personnels de santé autorisés |
| Bibliothèque | Catalogue, prêts, retours et retards |
| RH | Personnel, contrats, congés, planning et paie selon permissions spécifiques |
| Responsable sécurité | Caméras autorisées, événements NAXA SECURITY, alertes et suivi humain ; aucun accès automatique à tous les dossiers scolaires |
| Modérateur COMMUNITY | Publications, signalements et décisions de modération selon mandat |
| Auditeur / inspecteur | Lecture seule, temporaire, limitée à un établissement et aux données explicitement autorisées |
| Administration plateforme | Comptes, établissements, support, abonnements, configuration ; chiffres agrégés et accès exceptionnel tracé pour support |

## 2.3 Rôles parents et élèves

Le parent ou tuteur accède uniquement aux enfants qui lui sont légalement et administrativement rattachés.

Les droits d'un second tuteur, d'un parent séparé ou d'une personne disposant d'une garde ou délégation doivent être déterminés par l'école sur la base de pièces et d'une décision documentée. Un parent ne peut pas retirer à lui seul les droits d'un autre responsable légal.

L'accès élève est facultatif et paramétré selon son âge, le type d'établissement et les règles de l'école. Il ne donne jamais accès aux dossiers financiers, médicaux ou disciplinaires confidentiels d'autres personnes.

## 2.4 Affectation des enseignants

🔒 Le chef d'établissement affecte chaque professeur aux établissements, sections, cycles, classes, matières et périodes de cours.

Les affectations incluent :
- année scolaire ;
- établissement et campus ;
- section et cycle ;
- niveau et classe ;
- matière ;
- volume horaire ;
- période d'effet ;
- statut actif, suspendu ou terminé ;
- rôle de professeur principal, le cas échéant ;
- remplaçant désigné, si applicable.

Un professeur peut enseigner plusieurs matières et plusieurs classes. Il conserve un compte unique et un historique de ses affectations.

Un changement d'affectation n'efface ni les notes, ni les cours, ni les publications antérieures. Les opérations restent attribuées à l'enseignant qui les a réalisées.

---

# 3. ORGANISATION MULTI-ÉCOLES ET ARCHITECTURE MÉTIER

## 3.1 Établissement unique

🔒 Un établissement unique possède sa direction, son personnel, ses classes, ses élèves, ses parents et ses finances, cloisonnés dans son espace.

## 3.2 Groupe scolaire / promoteur

🔒 Un promoteur possède plusieurs établissements. Chaque établissement a ses propres données opérationnelles et sa direction.

Le promoteur voit :
- les effectifs consolidés ;
- le recouvrement consolidé ;
- les budgets et dépenses consolidés ;
- les résultats agrégés ;
- les comparaisons entre écoles ;
- les indicateurs de trésorerie et d'activité ;
- les validations de dépenses importantes selon les seuils définis.

Les données sensibles individuelles, en particulier santé, discipline, messages privés, situations familiales et dossiers RH, ne deviennent pas automatiquement accessibles au promoteur. Les permissions doivent être expressément définies.

🔵 Les tarifs, calendriers, barèmes, modèles de document et règles communes peuvent être hérités du groupe puis surchargés par chaque établissement, avec historique des changements.

🔵 Les transferts d'élèves ou d'employés au sein du groupe conservent un historique et une trace de validation.

## 3.3 Cloisonnement

Un directeur ne consulte que son établissement. Un promoteur ne consulte que les établissements rattachés à son organisation. Un parent ne voit que ses enfants. Un professeur ne voit que ses affectations. Un partenaire ne voit que ses annonces et candidatures autorisées.

Aucune appartenance à un groupe ne donne un droit général sur toutes les données individuelles de toutes les écoles.

---

# 4. SECTIONS, CYCLES, PROGRAMMES ET LANGUES

## 4.1 Structure pédagogique paramétrable

🔒 La hiérarchie est paramétrable :
- établissement ;
- section / sous-système ;
- cycle ;
- niveau ;
- série ou filière ;
- classe ;
- matière ;
- salle ;
- enseignant ;
- période pédagogique.

Sections possibles : francophone, anglophone, bilingue, arabe, chinois ou autre.

Cycles : maternelle, primaire, secondaire premier cycle, secondaire second cycle et formation professionnelle.

Rien ne doit être figé dans le code métier pour les niveaux, séries, matières, coefficients ou calendriers.

## 4.2 Programmes officiels et référentiels de cours

🔵 CAMPUS237 doit disposer d'un référentiel de programmes pédagogiques par :
- ministère / organisme de référence ;
- sous-système ;
- cycle et niveau ;
- série ou filière ;
- matière ;
- année/version du programme ;
- chapitre, unité, compétence ou objectif ;
- volume horaire indicatif ;
- ressources pédagogiques autorisées ;
- examen ou certification associé.

L'administration autorisée charge les programmes et documents de référence. Une école peut ajouter ses progressions, séquences, plans de cours et supports internes sans écraser le référentiel national.

Le système conserve la version du programme réellement utilisée pour une année scolaire donnée.

## 4.3 Calendriers et évaluations

Le moteur doit prendre en charge :
- séquences et trimestres du système francophone ;
- terms du système anglophone ;
- sessions, modules et semestres de formation professionnelle ;
- calendriers personnalisés par établissement ;
- barèmes, coefficients et règles de moyenne ;
- sessions de rattrapage, devoirs, interrogations, compositions, examens pratiques et examens blancs.

Les examens officiels à référencer comprennent notamment CEP/FSLC, BEPC, Probatoire, Baccalauréat, GCE O-Level et A-Level, BTS et certifications professionnelles, sous réserve de validation de la nomenclature officielle applicable.

## 4.4 Langues

🔒 Interface française et anglaise dès le départ.

🔵 L'arabe avec prise en charge RTL, le chinois et les autres langues peuvent être ajoutés selon calendrier validé. Les documents imprimés doivent être testés avec les polices et règles typographiques correspondantes.

---

# 5. SMART ENROLL — ADMISSION, INSCRIPTION ET RÉINSCRIPTION

## 5.1 Principe

🔵 Le parcours cible est numérique, guidé et traçable : le parent ouvre le dossier, l'enfant est identifié, ses informations sont saisies, les justificatifs sont chargés, le bordereau est émis, le paiement est audité, l'inscription est confirmée et les justificatifs sont délivrés.

Le parent peut être autonome, accompagné au guichet ou pris en charge en traitement de masse par l'école.

Le parcours doit éviter la ressaisie multiple et limiter les déplacements au guichet.

## 5.2 Parcours détaillé

1. Le parent arrive à l'école ou ouvre une préinscription à distance.
2. L'agent lui présente un QR d'accueil ou crée une session d'inscription assistée.
3. Le parent choisit nouvelle inscription, réinscription ou transfert.
4. Le système recherche d'abord l'enfant par matricule officiel lorsqu'il existe, puis par les critères d'identité nécessaires afin de détecter un doublon.
5. L'enfant existant est retrouvé ; son dossier antérieur est réutilisé avec l'historique et les permissions appropriées.
6. Pour un nouvel enfant, un dossier provisoire est créé.
7. Le parent renseigne l'identité, la date de naissance, la classe visée, la section, les tuteurs, les contacts, les personnes autorisées à le récupérer, les informations utiles et les pièces exigées.
8. Une photo d'identification est prise depuis l'application par un agent autorisé ou téléversée, avec information et accord requis. La vidéo d'identification de l'enfant n'est pas requise.
9. Le système vérifie les champs obligatoires, les doublons possibles, la cohérence des identifiants et les pièces manquantes.
10. L'école confirme l'admission et la classe visée, sous réserve des règles et places disponibles.
11. Le système génère un bordereau individualisé avec détail des frais, rubriques, montants, références et moyens de paiement validés pour cette école.
12. Le parent effectue le paiement auprès du canal autorisé.
13. Le parent charge la preuve de paiement dans CAMPUS237.
14. Le moteur d'audit extrait les données, les rapproche avec les transactions et les références disponibles, et classe le résultat.
15. En cas de rapprochement fiable, le paiement est confirmé. En cas d'incertitude, il est placé en file de vérification humaine.
16. Une fois toutes les conditions d'inscription remplies ou une exonération/prise en charge autorisée enregistrée, l'élève est déclaré inscrit.
17. La classe, l'année, les droits parentaux et les services sont activés.
18. Un reçu ou justificatif approprié est remis au parent ; les reçus officiels réglementaires proviennent du système officiel concerné.
19. La carte scolaire définitive est activée lorsque les identifiants et conditions officielles sont conformes.
20. Le parent reçoit le récapitulatif d'inscription et retrouve le dossier dans CAMPUS237 FAMILY.

Aucun dossier ne doit être déclaré définitivement inscrit uniquement parce qu'une image de reçu a été téléversée. La confirmation d'encaissement ou de paiement réglementaire doit provenir d'une source fiable ou d'une validation humaine documentée.

## 5.3 États du dossier

| Code | État |
|---|---|
| ENR-00 | Brouillon |
| ENR-01 | Préinscription ouverte |
| ENR-02 | Identité à compléter |
| ENR-03 | Recherche de doublon / identité à vérifier |
| ENR-04 | Matricule officiel en attente |
| ENR-05 | Admission à valider |
| ENR-06 | Bordereau émis / prêt à payer |
| ENR-07 | Paiement déclaré par le parent |
| ENR-08 | Audit de paiement en cours |
| ENR-09 | Paiement confirmé |
| ENR-10 | Inscription confirmée |
| ENR-11 | Carte définitive disponible |
| ENR-12 | Dossier incomplet |
| ENR-13 | Anomalie / contrôle humain |
| ENR-14 | Refus ou annulation motivée |
| ENR-15 | Transfert en cours |

Les états doivent être horodatés, attribués à un acteur et historisés.

## 5.4 Traitement des fratries

🔵 Le parent peut inscrire plusieurs enfants dans une même session. Chaque enfant conserve un dossier, un matricule, un bordereau et des paiements imputés séparément. Une présentation groupée dans l'application parent est possible. Un paiement groupé n'est admis que si le canal et les règles comptables le permettent et si le détail par enfant est parfaitement traçable.

## 5.5 Réinscription et transfert

La réinscription doit préremplir les informations existantes, demander seulement les mises à jour nécessaires et présenter les frais de la nouvelle année.

Le transfert exige :
- identification de l'élève ;
- établissement d'origine et d'accueil ;
- demande du tuteur ou procédure officielle applicable ;
- validation du dossier ;
- règles de transfert et de solde contrôlées juridiquement ;
- génération d'un dossier portable avec consentements et historique ;
- journal de toutes les transmissions.

---

# 6. IDENTIFIANTS, MATRICULES ET CARTE SCOLAIRE

## 6.1 Trois identifiants distincts

1. **Identifiant technique CAMPUS237 :** UUID interne, permanent, non porteur de données personnelles.
2. **Matricule national officiel :** enregistré lorsqu'il existe et s'applique, notamment pour les élèves du secondaire concernés par CarteScolaire.
3. **Référence locale de l'établissement :** référence scolaire interne si l'établissement l'utilise.

Aucun identifiant CAMPUS237 ne doit être présenté comme matricule national officiel.

## 6.2 CarteScolaire

🛡️ Pour les élèves du secondaire couverts par CarteScolaire, le matricule national est l'identifiant à rechercher et à conserver. CAMPUS237 doit utiliser l'identifiant existant et ne jamais créer un second matricule national.

Les opérations relevant des frais officiels de scolarité ou d'examen doivent respecter le circuit MINESEC / CarteScolaire et les opérateurs autorisés. Le reçu officiel reste celui émis par la plateforme officielle. CAMPUS237 peut enregistrer la référence, le statut, le justificatif et un récapitulatif interne ; il ne se substitue pas au reçu officiel.

Pour les autres cycles ou contextes où le matricule national n'est pas applicable, CAMPUS237 utilise son identifiant technique et la référence locale.

Les transferts doivent être régularisés dans le circuit officiel avant tout paiement auquel le matricule national est requis.

## 6.3 Carte physique et numérique

🔒 La carte comporte les éléments d'identification nécessaires : nom, photo, classe, année, référence scolaire et QR signé. Le QR ne contient aucune donnée personnelle directement lisible.

Le QR doit être opaque, signé, révocable et associé à une version de carte. Une copie d'un QR valide ne doit pas donner un accès au dossier en ligne. Au portail, le scan est accompagné d'un contrôle visuel de l'enfant et de la photo affichée à l'agent autorisé.

États : provisoire, active, suspendue, déclarée perdue, révoquée, expirée et remplacée.

Un duplicata peut être facturé si la politique de l'école le prévoit ; la rubrique et le reçu sont tracés.

NFC ou Bluetooth ne sont pas requis pour le socle initial ; ils restent optionnels après test de terrain et analyse de sécurité.

---

# 7. SMART PAYMENT — BORDEREAUX, PREUVES ET RAPPROCHEMENT

## 7.1 Rubriques de paiement

Rubriques paramétrables :
- inscription et réinscription ;
- frais réglementaires officiels, suivis sans substitution au circuit officiel ;
- scolarité privée et tranches ;
- contributions parentales autorisées ;
- cantine ;
- transport ;
- tenues, fournitures, manuels et boutique ;
- activités, sorties, examens internes et concours ;
- carte scolaire et duplicata ;
- dons, bourses et aides ;
- internat et services ;
- autres rubriques autorisées.

## 7.2 Moyens de paiement

L'école configure les canaux autorisés pour chaque rubrique : Mobile Money, banque, CAMPOST, Express Union, Afriland First Bank, paiement en espèces au guichet ou autre canal validé. Les paiements officiels doivent utiliser exclusivement le circuit et les partenaires autorisés par l'autorité compétente.

Le système affiche le bénéficiaire exact, le compte ou code marchand autorisé et les instructions à jour. Il ne doit pas afficher un compte personnel comme compte de collecte.

## 7.3 Paiement hybride

🔒 L'école peut définir, par cycle, niveau et rubrique :
- paiement en une fois ;
- paiement par tranches ;
- mensualités ;
- échéancier négocié ;
- combinaison de modalités ;
- remise, bourse ou exonération autorisée ;
- paiement partiel et avance ;
- trop-perçu à reporter ou rembourser ;
- ordre d'imputation réglable.

Aucun impayé ne doit suspendre automatiquement l'accès aux cours, examens ou évaluations. Une règle de service concernant cantine ou transport nécessite une décision de direction et une vérification juridique.

## 7.4 Dépôt de preuve et moteur d'audit

Le parent peut photographier ou importer un reçu, une capture ou un justificatif. Le moteur extrait : montant, date, référence, opérateur, bénéficiaire et identifiants présents.

Contrôles obligatoires :
- correspondance de l'enfant et de son matricule ;
- établissement et année scolaire ;
- rubrique et montant ;
- bénéficiaire autorisé ;
- référence de transaction ;
- date et statut de la transaction ;
- détection des doublons ;
- cohérence avec les relevés et le solde ;
- éventuelle annulation ou rétrofacturation.

La preuve téléversée n'est pas elle-même une confirmation d'encaissement.

Trois niveaux :
- confirmation automatique par source fiable et intégration autorisée ;
- rapprochement documentaire avec relevé ou portail officiel ;
- vérification humaine en cas de doute.

Une transaction ne peut être affectée qu'une seule fois. Toute correction, annulation ou réaffectation conserve l'ancienne valeur et un motif.

## 7.5 Lecture des SMS et compatibilité Android

La V2.0 prévoit la lecture des SMS financiers sans API, sur téléphone de l'économat, sans jamais lire PIN ni OTP. Cette orientation est conservée comme besoin de rapprochement automatisé, mais sa mise en œuvre est conditionnée par les permissions et politiques Android/Google Play applicables au moment de la publication.

Il est interdit de bâtir la continuité du produit sur une permission SMS dont l'application ne peut légalement ou contractuellement disposer. Solutions de repli :
- intégration officielle ou API autorisée ;
- relevé ou export bancaire ;
- portail marchand ;
- notification transactionnelle transférée volontairement ;
- preuve téléversée puis rapprochée ;
- contrôle manuel par l'économat.

CAMPUS237 ne doit ni contourner les permissions, ni accéder aux messages personnels hors du périmètre autorisé, ni stocker des historiques SMS inutiles.

## 7.6 Reçus, comptes et comptabilité

Chaque paiement interne confirmé génère un reçu numéroté CAMPUS237. Les reçus officiels sont téléchargés ou référencés depuis la plateforme officielle concernée.

Les reçus sont accessibles au parent, téléchargeables et partageables. Un reçu annulé reste consultable avec le statut annulé et le motif.

Les soldes des comptes marchands ou bancaires peuvent être rapprochés avec dernière heure de mise à jour ; les trous de solde et opérations manquantes sont signalés.

Le suivi financier comprend recouvrement par classe, rubrique, famille et période, restes à recouvrer, prévisions, écarts de caisse, rapprochement, remboursements et clôtures.

---

# 8. CAMPUS237 TEACHER SPACE — COMPTE ENSEIGNANT ET ACTIVITÉ QUOTIDIENNE

## 8.1 Compte individuel enseignant

🔒 Chaque professeur a son propre compte. Le compte est créé ou activé par l'administration autorisée. Le chef d'établissement lui affecte ses classes, matières et périodes.

Le professeur accède à :
- son tableau de bord ;
- ses établissements et affectations ;
- ses classes et listes d'élèves ;
- son emploi du temps ;
- les programmes et progressions applicables ;
- ses cours et préparations ;
- ses devoirs et évaluations ;
- ses scans et notes ;
- ses publications et bulletins selon droits ;
- les communications avec les parents dans le cadre autorisé.

Aucun professeur ne peut accéder à des classes ou matières non affectées.

## 8.2 Programme et progression pédagogique

Le programme de cours est chargé dans CAMPUS237 par l'administration habilitée. Le professeur prépare ses séances à partir du programme applicable et de sa progression.

Chaque séance comprend :
- date et horaire ;
- classe et matière ;
- thème, chapitre et objectif ;
- compétences visées ;
- notions prévues ;
- activités pédagogiques ;
- supports et ressources ;
- devoirs ou exercices ;
- progression par rapport au programme ;
- statut : préparée, confirmée, dispensée, partiellement dispensée, reportée ou non dispensée.

## 8.3 Préparation de cours filmée par l'enseignant

🔒 Le professeur doit pouvoir filmer sa préparation de cours via l'application. Il enregistre une capsule pédagogique de préparation ou de présentation de la séance, liée à la classe, la matière et la date.

Cette capsule permet au parent de comprendre ce que les élèves vont étudier pendant la journée.

Elle peut comporter :
- une présentation du thème du jour ;
- les objectifs de la séance ;
- les notions à retenir ;
- les activités ou exercices prévus ;
- les ressources et fournitures ;
- les prérequis ou rappels utiles ;
- les devoirs attendus.

Le parent reçoit le programme quotidien et, lorsque la capsule est publiée, la vidéo de préparation correspondante.

La capsule est produite par l'enseignant lui-même. Elle ne doit pas filmer les élèves, les copies nominatives, les dossiers sensibles ou des tiers sans base juridique et autorisation. La préparation filmée n'est pas une captation vidéo automatique du cours en classe.

Les vidéos ont une durée, un format, une taille et une durée de conservation définis ; elles sont accessibles uniquement aux parents des élèves concernés et aux acteurs pédagogiques habilités.

## 8.4 Absence et remplacement d'un enseignant

🔒 Si un enseignant ne peut pas assurer un cours, il le signale depuis son compte : cours concerné, date, classe, matière et statut d'absence. Il n'a pas à publier des informations médicales privées.

Le censeur ou le responsable désigné confirme l'absence et décide ou enregistre :
- remplacement par un autre enseignant ;
- réorganisation de l'emploi du temps ;
- étude surveillée ;
- travail autonome encadré ;
- report du cours ;
- annulation motivée lorsqu'elle est inévitable.

Le parent doit pouvoir connaître, pour son enfant et sa classe :
- le cours qui était prévu ;
- le cours réellement en cours ;
- le professeur initialement affecté ;
- le statut absent lorsque l'absence est confirmée ;
- le remplaçant, s'il existe ;
- l'activité réellement organisée à la place ;
- l'heure de la dernière mise à jour.

La plateforme ne doit pas afficher un état « cours en cours » sans confirmation suffisante. Le statut doit être horodaté et peut indiquer « planning prévu » si la réalité n'a pas encore été confirmée.

Le parent reçoit une notification lorsque le changement affecte le programme de son enfant. Le motif privé de l'absence n'est pas communiqué.

## 8.5 Suivi du déroulement réel

Le professeur ou le censeur peut confirmer le démarrage et la fin du cours. L'application maintient une frise quotidienne : prévu, confirmé, en cours, terminé, remplacé, reporté ou non dispensé.

Le parent consulte l'emploi du temps, le cours en cours, le cours précédent, les changements et le travail à faire.

La progression du programme est mise à jour par l'enseignant, puis suivie par la direction.

---

# 9. CAMPUS237 SMART GRADING — SCAN DES COPIES, NOTES ET DIFFUSION

## 9.1 Principe

🔒 Le professeur ne doit pas être obligé de ressaisir manuellement toutes les notes. Après correction pédagogique des copies, il utilise CAMPUS237 pour scanner les copies et laisser le système extraire automatiquement les notes.

Le système identifie la copie, lit la note inscrite ou la zone de notation structurée, propose la valeur et l'associe au bon élève, à la bonne matière, classe, évaluation et période.

🔒 Aucune note extraite ne devient officielle sans le OK explicite du professeur.

L'IA ou la vision ne doit pas corriger seule les réponses libres ni décider de la note de l'élève. Le professeur reste celui qui corrige et valide.

## 9.2 Préparation de l'évaluation

Le professeur sélectionne :
- établissement ;
- année ;
- classe ;
- matière ;
- type d'évaluation ;
- date ;
- barème ;
- coefficient ;
- durée éventuelle ;
- liste des élèves attendus ;
- modalités de traitement des absents et exemptions.

CAMPUS237 prépare un registre et, si nécessaire, un gabarit de copie ou une fiche de notation avec QR ou code unique.

## 9.3 Scan des copies

Le professeur peut :
- scanner une copie à la fois ;
- scanner plusieurs copies en lots ;
- scanner plusieurs pages par copie ;
- reprendre une image floue ;
- associer manuellement une copie non identifiée ;
- reprendre un lot après une coupure réseau.

Le moteur :
- détecte les bords et redresse l'image ;
- identifie le QR ou la référence de copie ;
- vérifie l'élève et l'évaluation ;
- détecte les pages manquantes ou doublons ;
- localise la zone de note ;
- extrait la note et le barème ;
- indique la confiance de lecture ;
- signale les valeurs ambiguës, illisibles ou hors barème.

## 9.4 Validation par le professeur

L'interface présente la copie et la note extraite côte à côte. Le professeur peut accepter, corriger ou rejeter l'extraction. Chaque validation est nominative, horodatée et historisée.

Une note illisible, une copie sans identité fiable, une note hors barème ou une incohérence doit rester en attente.

Le scan en lot ne signifie pas validation en lot aveugle. Le professeur peut valider plusieurs notes après examen, mais chaque résultat doit être identifiable et traçable.

## 9.5 Mise à jour automatique du bulletin

Dès que le professeur valide une note :
- elle est enregistrée dans le registre de notes ;
- la moyenne de la matière est recalculée selon les règles de l'établissement ;
- les moyennes et bulletins provisoires de l'élève sont actualisés ;
- les tableaux de bord autorisés sont mis à jour.

Les règles de moyenne, coefficients, arrondis, absences, exemptions, rattrapages et notes neutralisées sont paramétrées par section et période. Tous les calculs doivent être reproductibles et vérifiables.

## 9.6 Diffusion par le professeur

🔒 Lorsque toutes les notes attendues de l'évaluation sont traitées, le professeur peut cliquer sur DIFFUSER.

Avant l'activation du bouton, le système contrôle :
- copies attendues ;
- copies scannées ;
- notes extraites ;
- validations du professeur ;
- doublons ;
- notes hors barème ;
- absents, dispensés et exemptions ;
- notes manquantes et justifications ;
- affectation du professeur ;
- statut de l'évaluation.

Les exceptions autorisées doivent être explicitement qualifiées. Aucune note manquante ne peut être remplacée par zéro automatiquement sans règle validée et traçable.

Après diffusion :
- les notes de l'évaluation deviennent visibles aux parents autorisés ;
- les moyennes sont mises à jour ;
- les parents concernés reçoivent une notification ;
- la publication est enregistrée avec son auteur, date, heure et version ;
- les parents ne reçoivent jamais le tableau nominatif des autres élèves.

La diffusion d'une évaluation par un professeur n'est pas automatiquement la clôture officielle d'un bulletin trimestriel ou annuel. La direction conserve la clôture des périodes, conseils de classe et bulletins officiels selon les règles de l'école.

## 9.7 Corrections après publication

Une note publiée ne peut jamais être modifiée silencieusement. Le professeur demande une correction avec motif ; le système conserve l'ancienne valeur, la nouvelle valeur, l'auteur, les validations et la date. Les parents concernés sont notifiés de la modification.

## 9.8 Notification parentale

La notification indique qu'une nouvelle évaluation est disponible et donne accès au dossier de l'enfant. Par défaut, la note complète n'est pas affichée sur l'écran verrouillé du téléphone. Les parents peuvent consulter les résultats après authentification.

Les notifications sont regroupées lorsque plusieurs enfants ou matières sont concernés, sans exposer des données d'autres familles.

---

# 10. CAMPUS237 FAMILY — ESPACE PARENT ET SUIVI MULTI-ENFANTS

## 10.1 Compte familial

🔵 Le parent utilise un seul compte pour plusieurs enfants et plusieurs établissements partenaires. L'accueil regroupe les enfants mais chaque dossier reste cloisonné.

Chaque enfant présente :
- résumé de la journée ;
- programme prévu et cours réels ;
- professeur et changements d'enseignant ;
- présence, arrivée et sortie ;
- notes publiées et bulletins ;
- devoirs et cahier de textes ;
- solde, échéances et reçus ;
- cantine et transport ;
- circulaires, convocations et rendez-vous ;
- communauté de son établissement ;
- ressources Knowledge ;
- autorisations de retrait.

## 10.2 Accès à deux niveaux

Le matricule seul ne suffit jamais à ouvrir les données confidentielles.

Niveau restreint : opérations qui peuvent être réalisées sans accès aux données scolaires personnelles, selon le mécanisme autorisé.

Niveau complet : matricule ou identifiant associé à un code parent sécurisé, compte authentifié, lien tuteur vérifié et appareils/sessions contrôlés.

Protection : limitation des tentatives, alertes de nouvelle connexion, gestion des appareils, révocation et déconnexion à distance. Après cinq échecs, blocage temporaire et alerte au tuteur, selon les tests anti-abus.

## 10.3 Abonnement parent et gratuité de sécurité

🔒 CAMPUS237 ACCESS est gratuit pour tout parent/tuteur autorisé et inclus dans la licence établissement par élève. Il comprend les fonctions essentielles : compte familial multi-enfants/multi-écoles, sécurité et événements arrivée/sortie, informations de bus lorsqu'elles sont disponibles, absences et changements de cours, programme du jour, statut du professeur et remplaçant confirmé, capsules de préparation publiées, notes diffusées, rang provisoire de son enfant, bulletins, convocations, rendez-vous, reçus, communauté, livret scolaire et ressources KNOWLEDGE autorisées.

🔒 CAMPUS237 PREMIUM est facultatif et rattaché au compte familial. Il comprend assistant IA familial, résumés hebdomadaires écrits/audio, analyses avancées, parcours de révision recommandés, calendrier familial consolidé, détection de conflits d'agenda, recommandations de ressources, historique comparatif et préparation assistée des rendez-vous.

Le barème, les mensualités pendant neuf mois scolaires et les prix annuels égaux à sept mensualités sont définis au chapitre 23.3. Un enfant rattaché à deux écoles partenaires n'est compté qu'une fois. Le paiement ne modifie jamais les droits légaux des tuteurs.

---

# 11. BADGE QR, ARRIVÉES ET SORTIES — STUDENT GATE & FAMILY ALERTS

## 11.1 Principe

🔒 Le parent doit être informé lorsque son enfant arrive à l'école et lorsqu'il quitte l'école.

Le dispositif standard est le scan du QR code inscrit sur le badge scolaire, par un agent d'entrée autorisé ou un terminal de l'établissement. Le scan crée un événement horodaté d'entrée ou de sortie.

La notification est envoyée au parent lié à l'enfant :
- « Votre enfant est arrivé à l'école » ;
- « Votre enfant a quitté l'école ».

Le scan de badge constitue la preuve opérationnelle de l'événement de contrôle au portail ; il ne s'agit pas d'un suivi GPS continu de l'enfant.

## 11.2 Contrôles au portail

Au scan :
- vérification du QR signé et non révoqué ;
- affichage de la photo à l'agent ;
- contrôle visuel de l'enfant ;
- identification du portail et de l'appareil ;
- date, heure et sens entrée/sortie ;
- vérification des événements précédents pour éviter les doubles scans ;
- journal de l'agent.

Les scans incohérents ou répétés sont signalés. Un agent peut annuler une erreur de scan avec motif et historique.

## 11.3 Notifications et hors connexion

La notification push est envoyée dès que le réseau est disponible. Si l'école est hors connexion, l'événement reste stocké localement avec l'heure réelle de scan et l'identité de l'appareil ; il est synchronisé ensuite et la notification est marquée comme retardée. L'application ne doit jamais prétendre qu'une notification a été reçue en temps réel si le réseau était indisponible.

Les parents peuvent consulter l'historique arrivée/sortie et l'heure de l'événement.

Un SMS de secours peut être prévu sur la SIM de l'école ou par prestataire autorisé, sous réserve des permissions Android et de la réglementation télécom applicable. L'absence de smartphone ne doit pas faire perdre l'information au parent ; une procédure de contact alternative est définie par l'école.

## 11.4 Retrait sécurisé

Les personnes autorisées sont enregistrées par l'établissement, avec photo ou pièce requise selon la politique. Le parent peut autoriser un retrait ponctuel par un jeton à usage unique et durée limitée. Le vigile contrôle la personne, l'enfant et l'autorisation.

Les codes expirés, révoqués ou déjà utilisés sont refusés. En cas de réseau indisponible, une liste de secours chiffrée et limitée dans le temps peut être disponible sur terminal autorisé, avec journal de consultation.

---

# 12. NAXA SECURITY POUR CAMPUS237 — CAMÉRAS ET IA DE DÉTECTION D'ÉVÉNEMENTS DANGEREUX

## 12.1 Objectif

🔒 CAMPUS237 intègre les capacités logicielles pertinentes de NAXA SECURITY pour les établissements déjà équipés de caméras compatibles.

L'objectif est d'aider l'établissement à détecter plus rapidement des situations potentiellement dangereuses et à faire intervenir un responsable humain. Le système ne prétend pas garantir qu'aucun incident ne surviendra.

NAXA SECURITY reste une solution logicielle. Aucun matériel de caméra n'est fourni par défaut et aucun service de gardiennage ou de télésurveillance humaine 24/7 n'est inclus. L'établissement reste responsable de ses équipements, de leur installation, de leur alimentation, de leur réseau, de leur entretien et de la légalité du dispositif.

## 12.2 Compatibilité et raccordement

Le module doit pouvoir connecter les caméras et enregistreurs compatibles selon des protocoles et configurations validés : flux réseau, NVR/DVR ou connecteur local. La compatibilité exacte est testée caméra par caméra et modèle par modèle.

Chaque caméra dispose :
- d'un identifiant ;
- d'une école et d'un campus ;
- d'une zone ;
- d'une finalité ;
- d'un responsable autorisé ;
- d'une politique d'accès ;
- d'une durée de conservation ;
- d'un statut de connexion.

Les flux vidéo bruts ne sont pas diffusés dans l'application parent. L'accès direct au flux est réservé aux responsables de sécurité explicitement autorisés.

## 12.3 Zones vidéo autorisées et exclusions

🛡️ Avant activation, l'établissement doit réaliser une cartographie des caméras, informer les élèves, parents, personnels et visiteurs, préciser la finalité de chaque caméra et obtenir l'avis juridique nécessaire.

Zones susceptibles d'être examinées selon nécessité et base légale : portails, périmètre, accès aux bâtiments, zones de circulation autorisées et zones identifiées comme présentant un risque particulier.

Exclusions absolues du produit :
- toilettes et sanitaires ;
- vestiaires et espaces de déshabillage ;
- douches ;
- lieux de soin ou d'examen médical ;
- espaces de repos ou d'intimité ;
- toute zone où la captation serait disproportionnée ou interdite.

La captation en classe, dans les cours de récréation, cantines ou espaces de vie ne doit pas être activée par défaut. Elle nécessite une analyse de nécessité, de proportionnalité, de légalité et une validation écrite spécifique avant tout traitement.

Aucune écoute audio discrète n'est autorisée. La vidéo seule est le mode standard. Toute fonction audio est désactivée tant qu'une validation juridique distincte n'a pas été obtenue.

## 12.4 IA de détection d'événements dangereux

🔒 Le produit doit inclure une IA qui aide à détecter des cas dangereux dans les flux des caméras compatibles.

🔵 Familles d'événements candidates, sous réserve de validation, tests et analyse de faux positifs :
- altercation physique ou mouvement pouvant évoquer une bagarre ;
- personne au sol ou chute potentielle ;
- attroupement soudain ou mouvement de foule inhabituel ;
- intrusion ou présence dans une zone interdite ou en dehors des horaires ;
- franchissement du périmètre ou accès non autorisé ;
- fumée ou départ de feu lorsque la caméra et le modèle le permettent ;
- événement de sécurité au portail ou zone de circulation ;
- mouvement ou présence anormale signalés par des règles horaires et spatiales.

L'IA doit distinguer « événement possible détecté » de « incident confirmé ». Elle ne doit jamais affirmer seule qu'un élève a commis une faute ou qu'une personne est coupable.

## 12.5 Chaîne de traitement et intervention humaine

1. Le flux d'une caméra autorisée est analysé localement ou par un connecteur contrôlé.
2. L'IA détecte un événement potentiel et produit un signal avec date, zone, caméra, type, niveau de confiance et extrait strictement nécessaire.
3. L'alerte est envoyée au responsable de sécurité et aux personnes d'astreinte désignées.
4. Un humain vérifie l'événement, le qualifie comme confirmé, faux positif ou à surveiller.
5. Le responsable applique la procédure de sécurité de l'école.
6. Si l'incident concerne un enfant identifié de manière fiable par un processus non biométrique et une enquête humaine, le parent approprié peut être informé selon le protocole de l'établissement.
7. La décision, les actions et l'accès à l'extrait sont journalisés.

Les alertes critiques doivent être visibles immédiatement aux personnes responsables lorsque le réseau est disponible. Le système prévoit une procédure locale en cas de panne réseau.

## 12.6 Interdictions IA et exclusions NAXA SECURITY

🔒 Sont exclus :
- reconnaissance faciale ;
- identification biométrique d'un enfant à partir de son visage ;
- reconnaissance des émotions ;
- score de comportement ou profilage comportemental d'élève ;
- suivi individuel permanent d'un élève à travers toutes les caméras ;
- décisions automatiques de sanction, exclusion ou notation ;
- verrouillage automatique des portes ;
- appel automatique à la police ;
- IMSI ou surveillance de téléphones ;
- enregistrement vocal discret ;
- partage public d'images d'enfants.

L'IA sert à détecter un événement de sécurité, pas à surveiller la personnalité d'un enfant ni à remplacer les éducateurs.

## 12.7 Accès, preuves et conservation

Les accès sont déterminés par le rôle de sécurité et limités à l'établissement. Chaque lecture, extraction, partage ou suppression est journalisé.

Les images sont conservées pendant une durée définie par la finalité et validée juridiquement ; la conservation indéfinie est interdite. Un extrait lié à un incident peut être isolé et conservé selon une procédure documentée, une base légale et une échéance.

Les parents ne peuvent pas consulter librement les images en direct. Ils reçoivent les événements qui concernent leur enfant et qui ont été vérifiés par l'établissement. Toute demande d'accès à une image est traitée selon les droits des personnes, la protection des autres enfants et l'avis juridique.

## 12.8 Responsabilités

L'établissement est responsable de la finalité, de l'information, de l'emplacement et de l'usage de ses caméras. Le fournisseur logiciel agit selon le contrat, les instructions et obligations de sous-traitance applicables. Les procédures d'urgence, la présence de personnel et la réponse physique relèvent de l'établissement et des services compétents.

---

# 13. VIE SCOLAIRE, DISCIPLINE, SANTÉ ET SERVICES DE PROTECTION

## 13.1 Présence en classe

Appel par liste, badge ou QR selon matériel et choix de l'école. Les absences et retards sont enregistrés, justifiés et transmis au parent autorisé. La présence du portail et la présence en classe sont deux événements distincts.

## 13.2 Discipline et incidents

Le système enregistre incidents, témoins, mesures, responsables, pièces, convocations, sanctions et recours. Les sanctions sont motivées, validées par une personne habilitée et notifiées selon les règles de l'école.

L'IA peut repérer des tendances ou suggérer une alerte de répétition, mais ne décide jamais d'une sanction.

## 13.3 Infirmerie

Les données de santé sont minimales, séparées et strictement restreintes. Les enseignants ne voient pas les diagnostics et dossiers de santé, sauf consigne d'urgence strictement nécessaire. Les allergies ou consignes pratiques visibles à la cantine ou au transport sont limitées au minimum utile.

## 13.4 Convocations et mesures positives

Convocations de parents, élèves ou conseils : date, heure, lieu, motif, réception, rappel, rendez-vous et compte rendu.

Les mesures positives comprennent félicitations, encouragements et tableau d'honneur, avec règles de publication définies par l'école.

## 13.5 Urgences

L'établissement peut publier des alertes de fermeture, incident, météo, perturbation du transport ou urgence. Les messages sont validés par un responsable autorisé. Aucun appel automatique à la police ou service d'urgence n'est effectué par l'IA ; le personnel suit le protocole humain de l'établissement.

---

# 14. CAMPUS237 COMMUNITY — COMMUNAUTÉ PRIVÉE PAR ÉTABLISSEMENT

## 14.1 Principe

🔒 Chaque établissement dispose de son propre espace COMMUNITY privé afin de permettre aux parents de communiquer autour de la vie scolaire.

L'accès est réservé aux parents et tuteurs vérifiés de cet établissement, ainsi qu'aux représentants de l'école disposant d'un rôle autorisé.

Un parent ayant des enfants dans plusieurs établissements peut accéder à plusieurs communautés indépendantes. Aucun flux communautaire inter-écoles n'est ouvert par défaut.

## 14.2 Espaces

Espaces possibles :
- vie générale de l'établissement ;
- communauté des parents ;
- groupe par classe ;
- communauté APEE ;
- événements et activités ;
- entraide et solidarité ;
- questions à la direction ;
- espaces temporaires liés à une réunion ou un événement.

## 14.3 Fonctions

Publications, commentaires, réactions, sondages, annonces épinglées, recherche, pièces jointes limitées, abonnements à des discussions, notifications et signalements.

Les publications sont identifiées comme :
- communication officielle de l'école ;
- échange de parents ;
- communication APEE ;
- annonce sponsorisée/partenaire, si cette catégorie est activée.

La communauté n'est pas un espace de publicité déguisée. Les critiques légitimes de l'école ne sont pas supprimées au seul motif qu'elles sont négatives.

## 14.4 Modération et mineurs

Le système propose règles affichées, modérateurs identifiés, signalement, traitement, recours, journal et retrait rapide des contenus dangereux.

Il est interdit de publier dans les espaces communautaires des photos d'enfants, des informations médicales, des données de discipline, des coordonnées privées non consenties ou des détails permettant de localiser un mineur. Aucun contact privé non encadré entre un adulte et un élève mineur n'est autorisé.

L'IA peut prioriser les signalements, jamais imposer seule une sanction irréversible.

---

# 15. MESSAGERIE, APPELS ET COMMUNICATION

Messagerie entre parent et enseignant, professeur principal, direction ou secrétariat, liée à l'enfant et à l'établissement. Les pièces jointes sont limitées. Les accusés de lecture, horaires de disponibilité, modèles, traductions FR/EN et journaux sont prévus.

Aucun enseignant ne peut avoir de conversation privée non encadrée avec un élève mineur.

Les appels intégrés parent-école sont prévus avec appel Internet et repli éventuel vers appel classique. Les coûts de relais, de stockage et d'usage doivent être mesurés et paramétrés.

Les messages groupés par classe ou établissement sont possibles avec accusé de réception. Le parent n'a pas besoin de communiquer son numéro personnel à l'enseignant.

Les communications WhatsApp sont préparées en un clic lorsque le parent ou l'agent l'initie ; CAMPUS237 ne doit pas envoyer automatiquement des messages WhatsApp non autorisés.

Notifications applicatives gratuites selon le modèle retenu. SMS de secours depuis la SIM de l'école ou prestataire uniquement dans les conditions techniques, contractuelles et réglementaires autorisées.

---

# 16. SERVICES SCOLAIRES ET PATRIMOINE

## 16.1 Cantine

Menus, commandes, prépaiement, forfaits, scan des repas, comptage, stocks, achats, coûts, allergènes strictement nécessaires, prévisions, régimes déclarés, réductions de gaspillage et état de service.

## 16.2 Transport

Circuits, arrêts, véhicules, chauffeurs, accompagnateurs, assurances, maintenance, affectation des élèves, scan de montée et descente, notification au parent, incidents et alertes de retard. Pas de géolocalisation permanente de l'enfant par défaut.

## 16.3 Boutique et fournitures

Catalogue, fournisseurs, achats, bons de commande, réception, stocks, ventes, retours, inventaires, marges et imputations par élève.

## 16.4 Bibliothèque physique

Catalogue, exemplaires, prêts, retours, retards, réservations, historique et frais éventuels si autorisés.

## 16.5 Internat

Dortoirs, lits, affectations, présence de nuit, sorties, repas, frais et incidents. Réutilisation des fonctionnalités métier de NAXA HOTEL.

## 16.6 Patrimoine

Bâtiments, salles, mobilier, équipements, véhicules, contrats, assurances, entretien, inventaires, amortissements et maintenance.

---

# 17. CAMPUS237 KNOWLEDGE — BIBLIOTHÈQUE ET RESSOURCES ÉDUCATIVES

## 17.1 Principe de gratuité parentale

🔒 Le parent accède gratuitement aux ressources éducatives du catalogue dans les conditions de leur licence. Une ressource dont la licence n'autorise pas le téléchargement peut rester accessible sous forme de lien externe, sans copie ni téléchargement proposé.

Les contenus sont organisés par section, cycle, niveau, classe, matière, chapitre, langue, type et année.

## 17.2 Quatre espaces

1. **Bibliothèque numérique :** livres, manuels, PDF, cours, audio et documents.
2. **Encyclopédie pédagogique :** articles structurés à la manière d'une encyclopédie scolaire, par domaines et niveaux.
3. **Vidéothèque :** liens vers des leçons vidéo, organisés par classe, matière, chapitre et objectif.
4. **Annales et examens :** anciennes épreuves, sujets, corrigés, barèmes disponibles et exercices de préparation.

Examens à indexer notamment : CEP/FSLC, BEPC, Probatoire, Baccalauréat, GCE O-Level et A-Level, BTS et examens professionnels, sous réserve de vérification de nomenclature.

## 17.3 Fonctions

Recherche, filtres, lecture, favoris, historique, progression, recommandation par niveau, audio, contrôle parental, signalement et téléchargement hors connexion uniquement lorsque la licence le permet.

Les vidéos externes sont référencées par lien ; l'app ne télécharge pas ni ne republie de contenus sans droit.

## 17.4 Acquisition et droits

Sources autorisées :
- partenariats signés ;
- ressources libres et domaine public ;
- contenus créés par enseignants avec autorisation ;
- catalogues de liens externes sans copie ;
- ressources sous licence autorisant expressément les usages proposés.

Chaque ressource conserve source, adresse, auteur, licence, date de collecte, droit de lecture, téléchargement et redistribution. Le collecteur de métadonnées respecte liste blanche, robots.txt et conditions d'utilisation ; il ne contourne aucune protection ni paywall.

Le classement par IA suggère niveau, matière, difficulté et langue avec niveau de confiance. Un modérateur humain valide le contenu et les droits.

Le catalogue cible de plus de 100 000 ressources reste un objectif de croissance, pas une quantité garantie au lancement. L'acquisition, le stockage, les licences et les coûts doivent être budgétés.

---

# 18. CAMPUS237 OPPORTUNITIES — PLACE DE MARCHÉ ÉDUCATIVE

## 18.1 Principe

🔵 Place de marché d'annonces éducatives et professionnelles. Les parents consultent gratuitement. Les partenaires paient la publication selon une durée hebdomadaire. Aucun montant n'est inventé tant que le tarif n'est pas validé.

## 18.2 Catégories

Stages, formations, formations de vacances, cours de répétition, tutorat, préparation d'examens et concours, certifications, apprentissage de métiers, orientation, insertion professionnelle, événements et concours éducatifs.

## 18.3 Fiche d'annonce

Chaque annonce comprend partenaire, statut de vérification, catégorie, titre, description, objectifs, audience, âge/niveau ciblé, lieu, mode présentiel/distanciel, dates, durée, horaires, prix, places, prérequis, accréditation ou autorisation déclarée, contact, modalités de candidature et date d'expiration.

Le partenaire doit déclarer les conditions et justificatifs. Les annonces sont modérées avant publication.

## 18.4 Publication payante à la semaine

Processus :
1. ouverture du compte partenaire ;
2. vérification documentaire ;
3. dépôt de l'annonce ;
4. modération ;
5. choix de la durée ;
6. paiement ;
7. publication ;
8. expiration automatique ;
9. renouvellement ou archivage.

Formules possibles : Standard 7 jours, prolongation 7 jours, mise en avant 7 jours, campagne 30 jours. Les tarifs et niveaux de visibilité restent à arbitrer.

Les publications sponsorisées sont toujours identifiées. Aucun classement d'école dans l'annuaire ne peut être acheté.

## 18.5 Candidatures de mineurs

Le parent ou tuteur valide la candidature d'un mineur. Les partenaires ne peuvent pas contacter directement un mineur sans procédure encadrée. Les dossiers transmis sont minimisés et accessibles uniquement au partenaire sélectionné, avec traçabilité.

## 18.6 Programme de recommandation / affiliation

🔵 CAMPUS237 doit prévoir un programme de recommandation pour établissements, parents et partenaires. Le code, l'attribution, l'éligibilité, les annulations, la prévention de fraude et le calcul des commissions doivent être tracés.

⚠️ Les montants, taux, plafonds, périodes de validation et bénéficiaires des commissions ne sont pas arrêtés dans le présent cahier et doivent être arbitrés avant activation commerciale.

---

# 19. ANNUAIRE DES ÉTABLISSEMENTS ET TRANSFERTS

L'annuaire recense les établissements partenaires volontaires : localisation, sections, cycles, séries, frais, services, capacité et coordonnées autorisées.

Les critères de tri sont transparents. Pas de classement payant ni publicité déguisée dans l'annuaire scolaire.

Le parent peut rechercher, comparer, préinscrire, demander un rendez-vous, programmer un appel et demander une visite. Ses recherches restent privées ; son école actuelle n'en est pas informée automatiquement.

Le transfert du dossier est demandé par le parent, notifié à l'école d'origine, contrôlé, validé, signé ou authentifié selon procédure, importé par l'école d'accueil avec autorisation et journalisé.

Un identifiant CAMPUS237 stable peut relier les parcours entre établissements après arbitrage juridique et consentement lorsque requis. Il ne remplace pas les identifiants officiels.

---

# 20. ADMINISTRATION, RH, PAIE, COMPTABILITÉ, ACHATS ET GOUVERNANCE

## 20.1 Ressources humaines

Dossiers du personnel chiffrés et à accès restreint : identité, diplômes, pièces, affectations, types de contrat, historique, congés, absences, formation et évaluations.

Personnel permanent, contractuel, vacataire et intervenant externe.

Contrats CDI, CDD et vacation, modèles, avenants, période d'essai, échéances, attestations, départs et soldes. L'IA peut aider à rédiger ; humain et juriste valident les modèles et contrats.

## 20.2 Paie et obligations sociales

Bulletins, livre de paie, vacations horaires, avances, primes, retenues, congés payés et états de paie.

CNPS, impôts et cotisations gérés par tables paramétrables avec dates d'effet ; aucun taux légal figé dans le code. Les paramètres sont validés par un expert-comptable ou professionnel compétent avant mise en service.

Le dépôt officiel sur les portails concernés reste réalisé par l'établissement tant qu'une intégration habilitée n'est pas établie.

## 20.3 Comptabilité

Plan comptable SYSCOHADA, journaux, grand livre, balance, bilan, compte de résultat, TVA et taxes paramétrées, immobilisations, amortissements, budgets, centres de coûts, clôtures et rapprochements.

Les opérations doivent être traçables et respecter les règles d'écriture, de validation et de clôture. Une facture photographiée peut proposer une écriture, jamais la comptabiliser définitivement sans validation.

## 20.4 Achats, stocks et fournisseurs

Fournisseurs, demandes d'achat, appels de devis, bons de commande, réceptions, factures, paiements, dettes, stocks, inventaires et retours.

## 20.5 Gouvernance

Validation à plusieurs niveaux selon seuils, délégations, journal d'audit, rapports promoteur, consolidation multi-écoles, budgets par établissement et par service, documents partagés selon rôle.

Accès auditeur temporaire en lecture seule, limité à une école et aux informations autorisées.

---

# 21. INTELLIGENCE ARTIFICIELLE — ASSISTANTS ET LIMITES

## 21.1 Domaines

| Domaine | Fonctions assistées |
|---|---|
| Finance | prévision des retards, rapprochement suggéré, trésorerie, anomalies, prévisions de rentrée |
| Pédagogie | extraction de notes, création d'exercices, alignement au programme, propositions d'appréciation |
| Élève | aide à repérer risque de décrochage à finalité d'accompagnement, progression, recommandations |
| Vie scolaire | génération d'emploi du temps, remplacements, tri des événements et alertes vidéo |
| Parent | résumé hebdomadaire, assistant sur les échéances, emploi du temps et devoirs |
| Direction | copilote explicatif, comparatifs, alertes d'effectif, recouvrement et activité |
| RH | aide à la rédaction, classement documentaire et détection d'anomalies de paie |
| Sécurité | détection d'événements visuels dangereux dans zones autorisées et signalement à un humain |
| KNOWLEDGE | recherche sémantique dans les ressources approuvées avec citation de source |

## 21.2 Garde-fous

🔒 L'IA n'effectue aucune décision autonome de scolarité, notation, exclusion, sanction, paiement, transfert ou admission.

Les suggestions indiquent les éléments utilisés, le motif, la confiance et les limites. Les calculs déterministes restent locaux ou dans le backend contrôlé.

Aucune donnée personnelle d'enfant ne doit être envoyée à un prestataire IA externe sans base légale, minimisation/anonymisation adéquate, encadrement contractuel et autorisation requise.

Les réponses éducatives du tuteur IA doivent être adaptées à l'âge, limiter les contenus dangereux, citer les ressources de KNOWLEDGE et proposer une escalade adulte lorsque nécessaire.

## 21.3 Interdictions

Reconnaissance faciale, émotion, profilage de comportement, score de dangerosité individuel, décision autonome de sanction, correction automatique non validée par l'enseignant, décision financière, identification biométrique dans les caméras et transfert non autorisé de données de mineurs.

---

# 22. PILOTAGE, ACADEMIC RADAR, TABLEAUX DE BORD ET CLASSEMENTS

## 22.1 Pilotage global

Tableaux de bord par rôle : direction, censeur, économat, promoteur, RH, services, sécurité, professeur, parent, APE selon ses droits et administration plateforme.

Indicateurs : effectifs, inscriptions, paiements, recouvrement, trésorerie, présence, retards, progression des programmes, notes, publication des évaluations, bulletins, continuité des cours, heures non dispensées et rattrapées, incidents, repas, transports, communauté, Knowledge et Opportunities.

## 22.2 ACADEMIC RADAR — classement dynamique

🔒 Le système doit calculer et actualiser les classements à mesure que les enseignants valident et diffusent les notes, sans attendre la remise ou la clôture du bulletin trimestriel ou annuel.

Lorsqu'un professeur valide les notes puis clique sur DIFFUSER, les résultats de cette évaluation alimentent immédiatement le moteur de calcul des moyennes et classements provisoires. Les autres matières et évaluations alimentent ensuite le classement dès leur diffusion. Les mises à jour sont recalculées et propagées en temps réel lorsque la connexion le permet.

Le parent peut interroger le classement de son propre enfant avant la remise du bulletin et voir son rang évoluer au fur et à mesure des nouvelles notes diffusées. Le classement provisoire porte :
- la mention « provisoire / en cours de période » ;
- la période et le filtre sélectionnés ;
- le nombre d'évaluations et matières pris en compte ;
- le taux de couverture des notes disponibles ;
- la date et l'heure de dernière actualisation ;
- la règle de calcul et les limites de comparabilité.

Le parent ne voit que le rang, le percentile ou la tendance de son propre enfant et des informations agrégées sur le groupe de comparaison. Il ne voit ni les noms ni les notes individuelles des autres élèves. Aucun classement nominatif public d'enfants n'est publié dans COMMUNITY ou dans l'espace public.

## 22.3 Filtres ACADEMIC RADAR

Filtres combinables :
- organisation et groupe scolaire ;
- établissement et campus ;
- section et sous-système ;
- cycle ;
- niveau ;
- série et filière ;
- classe ;
- matière ;
- année scolaire ;
- trimestre, séquence, term ou semestre ;
- type d'évaluation ;
- compétence ou chapitre ;
- indicateur : meilleure moyenne, rang, percentile, progression, régularité, maîtrise ou évolution.

Le système distingue les classements bruts et les comparaisons normalisées. Il ne compare pas directement des classes, niveaux ou programmes non comparables. Un classement inter-niveaux ou inter-écoles n'est activé que si les barèmes, objectifs et évaluations sont comparables ou si un indicateur normalisé documenté est utilisé.

Les rangs ex æquo suivent une règle constante et documentée. Les notes manquantes, absences, dispenses, évaluations non diffusées et changements de barème sont gérés explicitement.

## 22.4 Deux palmarès complémentaires

- PALMARÈS PERFORMANCE : résultats, moyennes, maîtrise et réussite.
- PALMARÈS PROGRESSION : évolution, effort, régularité, compétences renforcées et rattrapage des lacunes.

La direction peut identifier le meilleur élève en mathématiques d'un niveau, d'une section ou d'un établissement sur des données comparables. Une requête « meilleur élève en mathématiques du collège » doit être précisée par niveau/période ou utiliser un indicateur normalisé ; les moyennes brutes de 6e et de 3e ne sont pas comparables par défaut.

## 22.5 SCHOOL INTELLIGENCE

Un assistant de pilotage permet aux directeurs et promoteurs de poser des questions en langage naturel : meilleurs résultats par matière, retards de programme, cours non rattrapés, notes non publiées, progression des classes, absentéisme, effectifs, recouvrement et incidents non clôturés.

Toute réponse affiche les filtres, la période, la source, l'heure de mise à jour, le périmètre et la définition de l'indicateur. L'assistant ne fabrique pas de chiffres et respecte les droits de l'utilisateur. Les réponses transversales du promoteur sont agrégées sauf permission individuelle expresse.

## 22.6 Exports et confidentialité

Exports PDF et Excel mis en forme et filtres favoris enregistrés. Les rapports nominatifs sont réservés aux personnels habilités. Le parent voit uniquement les informations de ses enfants. Aucun classement nominatif d'enfant n'est diffusé publiquement.

---

# 23. MODÈLE ÉCONOMIQUE ET TARIFICATION

## 23.1 Abonnement unique établissement — tarification dégressive par élève actif

🔒 Décision commerciale gelée V3.0.2 : un seul abonnement logiciel établissement, calculé par élève actif et par mois. L'école ne paie pas par professeur, compte, utilisateur ou module. Les comptes du personnel autorisés et tous les modules logiciels CAMPUS237 sont inclus.

| Tranche marginale d'élèves actifs | Tarif par élève dans la tranche |
|---|---:|
| Du 1er au 1 000e | 60 FCFA / élève / mois |
| Du 1 001e au 5 000e | 50 FCFA / élève / mois |
| À partir du 5 001e | 40 FCFA / élève / mois |

Les tranches sont marginales : chaque taux ne s'applique qu'aux élèves compris dans sa tranche, et non à la totalité de l'effectif. Minimum de facturation : 15 000 FCFA par mois pour une école indépendante. Pour un groupe sous contrat consolidé, le minimum s'applique une seule fois au groupe.

| Élèves actifs | Calcul | Mensuel |
|---:|---|---:|
| 200 | minimum contractuel | 15 000 FCFA |
| 500 | 500 × 60 | 30 000 FCFA |
| 800 | 800 × 60 | 48 000 FCFA |
| 1 000 | 1 000 × 60 | 60 000 FCFA |
| 2 500 | 1 000 × 60 + 1 500 × 50 | 135 000 FCFA |
| 5 000 | 1 000 × 60 + 4 000 × 50 | 260 000 FCFA |
| 10 000 | 1 000 × 60 + 4 000 × 50 + 5 000 × 40 | 460 000 FCFA |

La licence inclut l'ensemble des modules logiciels : administration, finance, RH, Teacher Space, SMART GRADING, bulletins, Academic Radar, Family ACCESS, Community, Knowledge, School Finder, Opportunities et logiciels NAXA SECURITY. Aucun supplément par enseignant, compte ou module n'est appliqué.

Matériel, caméras, GPS, installation, SIM/données, connectivité, intervention physique et capacité exceptionnelle de stockage/calcul vidéo peuvent faire l'objet d'un contrat tiers distinct, transparent et accepté. Cela ne crée pas de frais supplémentaires par utilisateur ou module logiciel.

La licence est facturée sur 12 mois pour couvrir hébergement, sauvegardes, maintenance, support et conservation. Le comptage des élèves actifs et les mouvements d'effectif sont audités et définis uniformément.

## 23.2 Groupes scolaires

🔒 Le prix multi-sites est déterminé selon le total d'élèves inscrits dans l'ensemble des établissements du promoteur, et non par application indépendante de la tranche à chaque école. L'architecture multi-sites est incluse dans le principe de l'offre.

Pour un groupe, les effectifs actifs de toutes les écoles rattachées sont additionnés, puis les tranches marginales 60/50/40 sont appliquées au total. Une facture consolidée est émise et ventilée analytiquement par école. Le minimum de 15 000 FCFA s'applique une seule fois au groupe. Le comptage, les mouvements en cours d'année, les transferts et les doubles inscriptions temporaires sont tracés ; un élève est compté une seule fois à l'instant de facturation dans une même organisation.

## 23.3 Parents

🔒 Décision V3.0.2 : compte familial unique. ACCESS est gratuit. PREMIUM est facultatif et dégressif selon le nombre d'enfants distincts rattachés, indépendamment du nombre d'écoles partenaires.

| Enfants distincts | Mensuel | Annuel |
|---:|---:|---:|
| 1 | 600 FCFA | 4 200 FCFA |
| 2 | 900 FCFA | 6 300 FCFA |
| 3 | 1 150 FCFA | 8 050 FCFA |
| 4 | 1 350 FCFA | 9 450 FCFA |
| 5 | 1 550 FCFA | 10 850 FCFA |
| 6 et plus | 1 550 FCFA + 200 FCFA par enfant au-delà du 5e | Mensuel × 7 |

La mensualité est facturée pendant les neuf mois scolaires ; l'abonnement annuel équivaut à sept mensualités. Exemple : deux enfants dans deux écoles partenaires représentent un seul Premium familial de 900 FCFA par mois ou 6 300 FCFA à l'année. Un enfant n'est jamais recompté parce qu'il fréquente plusieurs écoles ou change d'école.

ACCESS comprend la sécurité, les arrivées/sorties, le suivi des cours, les notes diffusées, le rang de son enfant, les bulletins, les convocations, les reçus, COMMUNITY et le livret scolaire. PREMIUM comprend assistant IA familial, résumés écrits/audio, analyses avancées, révisions recommandées, calendrier consolidé, détection de conflits et fonctions d'accompagnement avancées.

Les droits légaux des tuteurs restent indépendants du rôle de payeur. Les fonctions ACCESS essentielles ne sont jamais suspendues pour défaut de souscription Premium.

## 23.4 Partage 80/20

La V2.0 prévoit 80 % pour CAMPUS237 et 20 % pour le fonds de l'école géré avec l'APEE, calculés sur le montant net reçu après frais de l'opérateur.

Exemples arithmétiques avant frais :
- sur 4 200 FCFA annuels : 3 360 FCFA CAMPUS237 et 840 FCFA fonds école ;
- sur 5 400 FCFA perçus sur neuf mois : 4 320 FCFA CAMPUS237 et 1 080 FCFA fonds école.

Le partage est paramétrable par établissement à la création, consultable par les acteurs autorisés et reporté mensuellement. Le reversement est regroupé mensuellement ou trimestriellement selon convention et frais.

⚠️ L'arrivée d'un abonnement établissement payant crée un arbitrage : confirmer si la part de 20 % du Premium parent est maintenue en supplément de l'abonnement établissement, ou si la règle est remplacée/modifiée. La ventilation entre plusieurs écoles fréquentées par les enfants d'un même parent doit également être formalisée.

## 23.5 Opportunités et affiliation

Les partenaires paient la publication à la semaine. Les tarifs et options ne sont pas encore chiffrés.

Le programme d'affiliation est prévu, mais taux, commissions, conditions d'attribution, plafonds et calendrier de paiement restent à arbitrer.

## 23.6 Coûts à suivre

Hébergement, base de données, stockage des copies scannées et vidéos, sauvegardes, bande passante, notifications, appels, intégrations caméras, calcul IA, support, cartes imprimées, matériel compatible, SMS et conformité.

Les fonctions gratuites ou incluses ne doivent pas être considérées comme sans coût technique.

---

# 24. FRAIS OPÉRATEURS, TRÉSORERIE ET REVERSEMENTS

Les barèmes Mobile Money, banque, retrait, paiement marchand et transfert sont paramétrés par opérateur, canal, montant et date d'effet. Aucun tarif opérateur n'est supposé fixe.

Le parent voit, avant paiement, les frais qui lui sont imputés lorsqu'ils sont connus et autorisés. Le coût supporté par CAMPUS237 ou l'école est comptabilisé.

Les reversements au fonds APEE sont regroupés pour éviter de multiplier les frais. Chaque versement conserve une référence, un bénéficiaire, un montant brut, frais, net, école et période.

Les relevés doivent distinguer :
- paiement initial ;
- frais opérateur ;
- remboursement ;
- annulation ;
- reversement au fonds ;
- retrait ;
- écart ou transaction manquante.

---

# 25. CONFORMITÉ ET PROTECTION DES DONNÉES

## 25.1 Cadre de conformité

🛡️ Le produit doit être conçu au regard de la loi camerounaise n° 2024/017 du 23 décembre 2024 relative à la protection des données à caractère personnel, de la loi n° 2010/012 relative à la cybersécurité et à la cybercriminalité, des règles applicables à l'éducation et des textes sectoriels pertinents.

La loi 2024/017 prévoit un délai transitoire de 18 mois à compter de sa promulgation pour la mise en conformité ; ce délai arrive à échéance le 23 juin 2026. Au 22 novembre 2026, la conformité doit donc être traitée comme une condition actuelle du produit, et non comme un chantier futur facultatif.

Le statut et les modalités de fonctionnement de l'autorité compétente, les textes d'application et les formalités propres aux traitements sensibles doivent être vérifiés par un juriste camerounais avant mise en service.

## 25.2 Programme de conformité CAMPUS237

À mettre en place :
- registre des traitements ;
- identification du responsable et des sous-traitants ;
- finalités et bases juridiques documentées ;
- information compréhensible des parents, élèves et personnels ;
- consentement ou autre base juridique valide lorsque requis ;
- collecte minimale ;
- gestion des droits des personnes ;
- durées de conservation par catégorie ;
- contrôle des accès ;
- chiffrement des données sensibles ;
- journal des consultations ;
- procédures d'incident ;
- contrats avec hébergeurs, IA et partenaires ;
- analyse et encadrement des transferts internationaux ;
- procédure de retrait et de suppression ;
- encadrement des caméras et des contenus vidéo.

Les dossiers de santé, discipline, garde, finances, RH et vidéos sont séparés logiquement et accessibles uniquement aux rôles compétents.

## 25.3 Mineurs et consentement

L'école informe les familles et les élèves selon l'âge et le contexte. Les autorisations photo, vidéo pédagogique, publication communautaire, vidéosurveillance, transport, santé et transfert ne doivent pas être confondues dans un consentement global.

Une autorisation de photo d'identification pour la carte ne vaut pas autorisation de diffusion communautaire ou de vidéosurveillance.

## 25.4 Vidéosurveillance

Chaque établissement documente ses finalités, emplacements, destinataires, durées de conservation, mesures de sécurité et informations visibles. Une validation juridique préalable est exigée. Les recommandations de la CNIL française peuvent servir de référence comparative de privacy-by-design, mais ne constituent pas le droit camerounais.

---

# 26. SÉCURITÉ TECHNIQUE, CONFIDENTIALITÉ ET JOURNALISATION

Exigences :
- contrôle d'accès par rôle, établissement, groupe, classe, affectation et relation parent-enfant ;
- authentification robuste et renouvellement/révocation des sessions ;
- limitation des tentatives et anti-bruteforce ;
- chiffrement en transit et au repos selon capacités des services ;
- journal d'audit append-only pour les opérations sensibles ;
- séparation des secrets et clés ;
- aucune clé de service dans les applications clientes ;
- validation serveur des opérations financières et pédagogiques ;
- sauvegardes chiffrées et restauration testée ;
- stockage privé des documents et images ;
- URLs de téléchargement temporaires ;
- antivirus / contrôle des fichiers téléversés ;
- limitation des pièces jointes ;
- contrôle des appareils de scan et terminaux de portail ;
- révocation de carte et d'appareil ;
- gestion des incidents et notifications ;
- tests d'intrusion et tests d'accès croisés.

Si Supabase est retenu après validation de l'architecture, toute table exposée doit avoir RLS activée et des droits SQL cohérents. Les vues, fonctions et buckets de stockage sont également sécurisés. Les clés privilégiées restent côté serveur. Les politiques sont testées en autorisant et en refusant les scénarios pour les rôles réels. L'architecture Supabase ne doit pas être considérée comme verrouillée tant que le prompt 0.1 et l'étude d'architecture du dépôt ne sont pas confirmés.

---

# 27. ARCHITECTURE TECHNIQUE ET INTÉGRATIONS

## 27.1 Applications

🔒 Pour la famille NAXA, l'orientation Android est du natif Kotlin avec Jetpack Compose. Les applications Web/PWA sont construites séparément sur le même socle de backend, contrats API et règles métier. Le code Android n'est pas supposé être converti automatiquement en Web/PWA.

Applications :
- CAMPUS237 SCHOOL Android ;
- CAMPUS237 FAMILY Android ;
- CAMPUS237 DIRECTION Web ;
- CAMPUS237 PARTNERS Web ;
- CAMPUS237 PLATFORM ADMIN Web.

## 27.2 Backend

La V2.0 propose Supabase partagé avec la famille. Cette option demeure une proposition tant que la revue d'architecture du dépôt NAXA et le prompt 0.1 ne sont pas officiellement validés.

Les contrats métier doivent être indépendants des interfaces et inclure :
- API d'identité ;
- API organisation / écoles ;
- API élèves / inscriptions ;
- API paiements ;
- API pédagogique ;
- API notes / bulletins ;
- API présences / sécurité ;
- API communauté ;
- API Knowledge ;
- API partenaires / opportunités ;
- API notifications ;
- API BI et administration.

## 27.3 Hors connexion et synchronisation

Les opérations école suivantes doivent pouvoir être mises en file hors connexion selon les risques et conflits : inscription, consultation locale de listes autorisées, appel, scan de badge, scan de copies, préparation de cours, saisie de notes validées localement et événements de caisse sous contrôle.

Les opérations sensibles non confirmables hors connexion restent en état provisoire jusqu'au serveur : confirmation d'encaissement, clôture officielle de bulletin, révocation globale, validation finale de transfert et publication nécessitant contrôle central.

Chaque opération possède identifiant unique, clé d'idempotence, appareil, auteur, horodatage local et serveur, statut de synchronisation et résolution de conflit.

Aucune transaction financière, note ou alerte de sécurité ne doit être écrasée silencieusement.

## 27.4 Notifications

Canaux : push applicatif, WhatsApp préparé en un clic, SMS de secours lorsque permis, appels Internet ou classiques sous réserve de coûts et conformité.

La livraison est traçable : créée, envoyée, remise, lue lorsque le canal le permet, échec ou en attente réseau. Il ne faut pas confondre notification créée et notification effectivement reçue.

---

# 28. EXIGENCES NON FONCTIONNELLES

- Performance sur téléphones Android d'entrée de gamme.
- Interface simple en français et anglais.
- Contraste, tailles et navigation accessibles.
- Listes de milliers d'élèves fluides.
- Photos et vidéos compressées, tailles limitées et téléchargement différé.
- Haute disponibilité proportionnée au service.
- Sauvegardes régulières et tests de restauration.
- Plan de reprise après sinistre.
- Journalisation et surveillance technique.
- Séparation environnements développement, test et production.
- Gestion versionnée des programmes, barèmes, tarifs et politiques.
- Gestion des erreurs lisible.
- Tolérance réseau configurable.
- Synchronisation idempotente et anti-doublon.
- Tests de charge sur rentrée scolaire et publication massive des notes.
- Publication progressive des notifications pour éviter l'engorgement.
- Accessibilité aux parents disposant de téléphones modestes ou d'une connectivité faible.
- Stockage local limité, chiffré et révocable.
- Conservation et suppression conforme des médias et documents.

---

# 29. MODÈLE DE DONNÉES — ENTITÉS PRINCIPALES

Cette liste est un modèle conceptuel de référence, à détailler dans le dictionnaire de données et les migrations après revue d'architecture. Les noms ne constituent pas encore un schéma SQL exécuté.

## 29.1 Organisation

organizations, promoters, schools, campuses, school_years, school_settings, memberships, role_assignments, permissions, delegations, audit_log.

## 29.2 Structure pédagogique

sections, cycles, levels, series, tracks, classes, rooms, subjects, curricula, curriculum_versions, curriculum_units, calendars, terms, periods, timetable_slots, timetable_changes.

## 29.3 Élèves et familles

students, student_identifiers, national_matricules, local_student_references, guardians, family_accounts, student_guardians, guardian_permissions, custody_rules, authorized_pickups, student_photos, student_cards, card_versions, card_revocations, enrollments, admissions, transfers, student_documents.

## 29.4 Inscriptions et paiements

admission_cases, admission_steps, fee_items, fee_plans, installments, invoices, payment_orders, payment_proofs, payment_events, payment_matches, payment_allocations, receipts, reversals, refunds, scholarships, discounts, operator_fees, bank_accounts, balance_snapshots, cash_sessions, cash_movements, reconciliations, accounting_entries.

## 29.5 Personnel et enseignants

employees, teacher_profiles, teacher_assignments, teacher_substitutions, contracts, leaves, employee_attendance, payroll_runs, payslips, tax_tables, staff_documents.

## 29.6 Cours et pédagogie

lesson_plans, lesson_plan_versions, lesson_resources, teacher_preparation_videos, lesson_sessions, lesson_status_events, lesson_logs, homework, assignments, attendance, absences, justifications, assessment_types, assessments, assessment_rosters, assessment_rubrics, exam_copies, copy_pages, scan_batches, grade_extractions, grade_reviews, grade_entries, grade_approvals, grade_publications, grade_revisions, report_cards, report_card_versions, report_card_calculations, report_card_publications, live_report_snapshots, academic_rankings, ranking_snapshots, ranking_filters, ranking_publications, ranking_cohort_definitions, learning_competencies, student_competency_records, skill_evidence, learning_gap_indicators, remediation_recommendations, recovery_assignments, class_councils, exams, exam_registrations, exam_results.

## 29.7 Portail, sécurité et NAXA SECURITY

gate_devices, gate_events, student_arrival_events, student_departure_events, pickup_authorizations, pickup_events, visitor_logs, safeguarding_cases, incidents, incident_actions, camera_devices, camera_zones, camera_access_policies, camera_events, ai_event_detections, ai_detection_reviews, security_alerts, video_evidence, video_access_logs, retention_jobs.

## 29.8 Services

canteen_menus, canteen_orders, canteen_meals, canteen_checkins, allergies_minimal, bus_routes, bus_stops, bus_vehicles, bus_staff, bus_assignments, bus_events, vehicle_gps_devices, vehicle_gps_positions, bus_trip_sessions, bus_geofences, bus_eta_snapshots, student_boarding_events, student_alighting_events, safe_reunification_events, canteen_menu_versions, canteen_menu_publications, shop_items, inventory_movements, purchase_orders, library_catalog, library_loans, dormitories, beds, dormitory_assignments, assets, maintenance_tickets.

## 29.9 Communication et COMMUNITY

chat_threads, chat_messages, call_logs, notification_batches, notification_recipients, notification_deliveries, community_spaces, community_members, community_channels, community_posts, community_comments, community_reactions, community_reports, moderation_actions, school_transparency_projects, school_transparency_updates, school_transparency_documents, family_calendar_events, family_schedule_conflicts, parent_digest_snapshots, school_intelligence_queries, school_intelligence_results, moderation_appeals, community_blocks, community_events.

## 29.10 KNOWLEDGE et OPPORTUNITIES

knowledge_items, knowledge_articles, video_resources, exam_archives, content_sources, content_licenses, content_versions, content_downloads, reading_progress, link_checks, crawl_jobs, moderation_queue, partners, partner_verifications, opportunities, publication_periods, opportunity_payments, applications, application_consents, referral_codes, referral_attributions, referral_commissions.

## 29.11 Conformité et plateforme

processing_register, consent_records, privacy_requests, retention_policies, data_incidents, processor_contracts, data_transfer_records, devices, sessions, offline_operations, sync_conflicts, idempotency_keys, subscriptions, subscription_entitlements, revenue_shares, school_fund_ledger, payouts, support_tickets.

---

# 30. RÉUTILISATION DES APPLICATIONS DE LA FAMILLE NAXA

La réutilisation porte sur les modules métier, composants et contrats d'API pertinents ; elle ne signifie pas copier des applications entières ni fusionner leurs bases sans contrôle.

| Produit source | Composants réutilisables |
|---|---|
| NAXA | paiements, caisse, ventes, stocks, facturation, fournisseurs, indicateurs |
| NAXA HOTEL | chambres, dortoirs, occupation, hébergement, restauration et internat |
| COTIZ | APEE, adhésions, cotisations, réunions, votes, contributions et transparence |
| NAXA SERVICES | tickets, interventions, maintenance, prestataires et ordres de travail |
| JOBLY | orientation, compétences, stages, insertion, entreprises et carrière |
| LOYABLE | bâtiments, locaux, contrats, patrimoine immobilier et maintenance |
| GrillaD | menus, production et restauration collective |
| ZIPPLE | commandes, ventes, achats, approvisionnements et stocks de cantine/fournitures |
| NAXA SECURITY | caméras compatibles, contrôle d'accès logiciel, événements, détection IA et alertes |

Les données restent séparées par domaine, établissement et finalité. Les intégrations utilisent des API versionnées et des permissions minimales.

---

# 31. JALONS DE RÉALISATION

Le projet est construit par jalons testables, sans pilote public si la décision de lancement direct est maintenue. Aucun jalon ne signifie que le produit peut être mis en service sans recette complète.

| Jalon | Contenu |
|---|---|
| E0 | Architecture, comptes, multi-tenant, rôles, audit, sécurité, synchronisation et design system |
| E1 | Organisations, écoles, sections, cycles, élèves, familles, matricules, cartes et SMART ENROLL |
| E2 | Bordereaux, paiements, preuves, audit, rapprochement, reçus, caisse et comptabilité |
| E3 | CAMPUS237 FAMILY, compte familial, abonnements, alertes et notifications |
| E4 | Programmes, emplois du temps, comptes enseignants, affectations, cours et préparations filmées |
| E5 | SMART GRADING, scan, validation, diffusion, calculs et bulletins |
| E6 | Badge QR, arrivées/sorties, retrait sécurisé, présences et gestion des incidents |
| E7 | NAXA SECURITY, caméras compatibles, IA événementielle, revue humaine et journalisation |
| E8 | COMMUNITY, messagerie, appels et modération |
| E9 | Cantine, transport, boutique, bibliothèque physique, internat et patrimoine |
| E10 | RH, contrats, paie, comptabilité complète, achats et gouvernance |
| E11 | KNOWLEDGE : bibliothèque, encyclopédie, vidéos, annales et licences |
| E12 | OPPORTUNITIES, partenaires, annonces hebdomadaires et affiliation |
| E13 | Annuaire, transferts, passeport scolaire, BI, IA et recette complète |
| E14 | Préparation de mise en service, formation, support, surveillance et plan de reprise |

---

# 32. CRITÈRES DE RECETTE OBLIGATOIRES

## 32.1 Inscription et paiement

- Une inscription existante est retrouvée sans créer un doublon.
- Un matricule national existant est réutilisé.
- Un transfert est régularisé dans le circuit officiel avant paiement réglementaire concerné.
- Un bordereau contient les bonnes rubriques et montants.
- Le parent peut charger une preuve et suivre son statut.
- Une capture d'écran seule ne confirme pas automatiquement un encaissement.
- Un paiement confirmé est imputé une seule fois.
- Une transaction incertaine est mise en file humaine.
- Un reçu officiel n'est jamais remplacé par un reçu interne.
- L'inscription n'est confirmée qu'après satisfaction des conditions ou exonération autorisée.
- Un parent peut inscrire plusieurs enfants avec des paiements distincts.
- Les pièces et données sensibles ne sont visibles que par les rôles autorisés.

## 32.2 Professeurs et cours

- Chaque professeur dispose d'un compte personnel.
- Le chef d'établissement affecte les classes, matières et périodes.
- Le professeur ne voit que ses affectations.
- Le programme applicable est visible par niveau et matière.
- Le professeur prépare le cours dans l'application.
- Le professeur peut enregistrer une capsule de préparation sans filmer les élèves.
- Le parent voit le programme prévu du jour.
- L'enseignant peut déclarer une absence liée au cours concerné.
- Le censeur peut confirmer et affecter un remplaçant ou une activité de substitution.
- Le parent voit le cours réellement en cours, le statut de l'enseignant et l'heure de mise à jour.
- Une absence non confirmée n'est pas présentée comme un fait vérifié.

## 32.3 SMART GRADING

- Une copie scannée est associée au bon élève et à la bonne évaluation.
- Une page manquante ou un doublon est détecté.
- Une note illisible ou hors barème est bloquée pour vérification.
- Le professeur visualise la copie et la note extraite.
- Aucune note n'est officielle sans le OK du professeur.
- Le bulletin provisoire se met à jour après validation.
- Le bouton DIFFUSER est bloqué tant que les éléments requis ne sont pas traités.
- Les notes diffusées sont visibles uniquement aux tuteurs concernés.
- Les parents reçoivent une notification de publication.
- Une correction après diffusion conserve l'historique et notifie.
- Un bulletin officiel peut être clôturé par la direction selon le circuit défini.

## 32.4 Badge et sécurité

- Un badge valide produit un événement d'arrivée ou de sortie.
- Un badge révoqué est refusé.
- La photo est présentée à l'agent pour contrôle visuel.
- Le parent reçoit une alerte d'arrivée et de sortie lorsque le réseau permet la livraison.
- En mode hors connexion, l'événement est conservé et la notification est marquée retardée après synchronisation.
- Le QR n'expose pas de données personnelles lisibles.
- Le double scan ou l'ordre incohérent est signalé.
- Le retrait sécurisé refuse un code expiré, révoqué ou déjà utilisé.
- Le parent ne reçoit pas de flux vidéo des caméras.

## 32.5 NAXA SECURITY / IA vidéo

- Seules les caméras autorisées et référencées peuvent être connectées.
- Chaque caméra dispose d'une finalité et d'une zone documentées.
- Les zones interdites ne peuvent pas être activées.
- L'IA crée un événement potentiel et non une culpabilité.
- Un humain qualifie l'alerte.
- Aucun profil individuel ni score comportemental n'est produit.
- Aucune reconnaissance faciale n'existe.
- Aucune écoute audio discrète n'existe.
- Aucune sanction ni action de police n'est déclenchée automatiquement.
- L'accès aux images et extraits est journalisé.
- Les règles de conservation sont appliquées et testées.
- Le parent reçoit seulement une information pertinente autorisée concernant son enfant, jamais une image d'autres enfants.

## 32.6 COMMUNITY

- Un parent accède seulement à la communauté d'une école où son lien est vérifié.
- Les communautés d'établissements distincts sont cloisonnées.
- Les annonces officielles sont distinctes des publications parentales.
- Les signalements déclenchent un suivi traçable.
- Les parents peuvent contester une décision de modération.
- Les critiques légitimes ne sont pas supprimées uniquement pour protéger l'image de l'école.
- Les photos et identifiants sensibles d'enfants sont interdits dans les espaces communautaires.

## 32.7 KNOWLEDGE et OPPORTUNITIES

- Une ressource sans droit de téléchargement n'est pas téléchargée.
- Une ressource affiche source et licence.
- Les liens morts sont détectés.
- Une ressource proposée par IA passe en modération.
- Un partenaire non vérifié ne peut pas publier.
- Une publication payée expire selon la durée.
- Une annonce destinée à un mineur exige la validation du tuteur pour candidature.
- Le contenu sponsorisé est clairement identifié.

## 32.8 Sécurité des données et exploitation

- Un parent ne peut jamais accéder aux données d'un autre enfant.
- Un professeur ne peut pas consulter finance ou santé sans habilitation spécifique.
- Un directeur ne voit que son école.
- Un promoteur ne voit que ses établissements et droits autorisés.
- Les opérations hors connexion se synchronisent sans doublon.
- Les conflits sont visibles et résolus selon règles explicites.
- Les sauvegardes peuvent être restaurées.
- Les permissions sont testées positivement et négativement.
- Les journaux et les exports respectent les règles de conservation.
- Les coûts et limites d'hébergement sont mesurés avant montée en charge.

---

# 33. RISQUES MAJEURS ET MESURES DE MAÎTRISE

| Risque | Mesure |
|---|---|
| Périmètre très large | Jalons, contrats API, tests et dépendances |
| Confusion entre matricule officiel et identifiant interne | Trois identifiants distincts et intégration CarteScolaire |
| Paiement non confirmé | Rapprochement multi-source et file humaine |
| SMS non autorisés sur Android | Alternatives autorisées, aucune dépendance exclusive |
| Fausse note extraite | Validation explicite du professeur et historisation |
| Copie mal identifiée | QR, liste de session, vérification et file d'exception |
| Bulletin incohérent | Règles de calcul versionnées et recette indépendante |
| Cours annoncé mais non dispensé | Statut réel, confirmation d'absence et remplaçant |
| Notification retardée sans réseau | File locale et mention explicite du retard |
| Faux positif IA vidéo | Revue humaine, score de confiance et apprentissage contrôlé |
| Surveillance disproportionnée | Cartographie, zones restreintes, analyse de nécessité et avis juridique |
| Fuite de données de mineurs | RLS, chiffrement, journalisation, minimisation et tests d'intrusion |
| Contenu numérique sans licence | Registre de droits, liens seulement si besoin, retrait rapide |
| Partenaire frauduleux | Vérification et modération |
| Adoption faible | Simplicité, formation, mode assisté et supports |
| Coût des médias et de l'IA | Quotas, compression, stockage séparé et suivi de coût |
| Écarts tarifaires | Arbitrage obligatoire avant facturation automatique |

---

# 34. ARBITRAGES À NE PAS INVENTER

Les décisions suivantes restent ouvertes. Elles doivent être traitées dans un registre d'arbitrage séparé, sans bloquer les fonctions indépendantes.

| ID | Arbitrage | Donnée ou décision attendue |
|---|---|---|
| A-001 | Grille abonnement école | 🔒 RÉSOLU V3.0.2 : 60 FCFA sur les 1 000 premiers élèves, 50 FCFA du 1 001e au 5 000e, 40 FCFA dès le 5 001e ; progressif marginal, minimum 15 000 FCFA/mois |
| A-002 | Seuils d'effectifs | Date de comptage, élèves actifs, inscriptions tardives et changements de tranche |
| A-003 | Abonnement parent | 🔒 RÉSOLU V3.0.2 : ACCESS gratuit et PREMIUM familial progressif selon le nombre d'enfants, chapitre 23.3 |
| A-004 | Multi-écoles parent | 🔒 RÉSOLU V3.0.2 : un seul compte et abonnement familial ; un enfant compté une fois quel que soit le nombre d'écoles partenaires |
| A-005 | Partage 80/20 | Maintien ou adaptation après introduction du tarif établissement |
| A-006 | Ventilation inter-écoles | Répartition du fonds lorsque plusieurs enfants relèvent d'écoles différentes |
| A-007 | Essai parent | Confirmation de la période d'essai de deux semaines |
| A-008 | Affiliation | Taux, plafonds, éligibilité, attribution et calendrier |
| A-009 | Opportunités | Prix des annonces à la semaine et options mises en avant |
| A-010 | Public prioritaire | Ordre de couverture maternelle, primaire, secondaire et centres professionnels |
| A-011 | Sous-systèmes | Ordre de couverture et modèles officiels de bulletins |
| A-012 | CarteScolaire | Modalités techniques d'intégration autorisée, API ou partenariat |
| A-013 | Paiements internes | Corpus SMS, accès marchands, relevés et alternatives opérateurs |
| A-014 | Paie / CNPS | Paramètres datés validés par expert-comptable |
| A-015 | APEE | Convention écrite, statut et compte bénéficiaire du fonds |
| A-016 | Frais opérateurs | Barèmes réels, prise en charge et reversements |
| A-017 | Garde des enfants | Droits des tuteurs, séparation et décisions judiciaires |
| A-018 | QR / NFC / Bluetooth | Matériel à tester et sélection éventuelle |
| A-019 | Caméras | Zones autorisées, conformité, durée de conservation et finalités |
| A-020 | IA vidéo | Cas de détection, seuils, tests de faux positifs, traitement local/cloud et réponse humaine |
| A-021 | Appels | Coût du relais et prestataire |
| A-022 | Bibliothèque | Partenaires, licences, volume de 100 000 ressources et budget |
| A-023 | Arabe / chinois | Interface complète, calendrier et relecteurs natifs |
| A-024 | Transfert scolaire | Conditions, solde dû, consentements et règles de portabilité |
| A-025 | Identifiant global | Base juridique et consentement pour un identifiant scolaire transversal |
| A-026 | Écoles publiques | Frais, contributions, validations et rapports réglementaires |
| A-027 | Hébergement | Région, sauvegardes, sous-traitants et transferts |
| A-028 | SMS SIM école | Modalité conforme à Android/Google Play et réglementation télécom |
| A-029 | Stockage vidéo | Quotas, résolution, durée et coût |
| A-030 | Capsules enseignants | Durée, fréquence, publication et conservation des vidéos de préparation |

---

# 35. REGISTRE DES DÉCISIONS VERROUILLÉES

Cette section rassemble les décisions explicitement validées ou formulées directement par le porteur du projet. Elles ne doivent pas être ramenées au statut de simple suggestion lors de la réalisation.

1. Le produit s'appelle CAMPUS237 et appartient à la famille NAXA.
2. CAMPUS237 est un ERP scolaire à 360°.
3. Il couvre établissements uniques et groupes scolaires.
4. Il couvre public et privé, de la maternelle à la formation professionnelle.
5. Il existe une application établissement Android, une application parent, un espace web direction/promoteur et des espaces partenaires.
6. Les comptes du personnel sont créés/administrés par des acteurs autorisés ; les parents n'ont pas d'accès complet libre sans lien vérifié avec l'enfant.
7. L'école fonctionne hors connexion pour ses principales opérations, avec synchronisation sans doublon.
8. Le matricule national existant doit être réutilisé lorsqu'il s'applique ; aucun second matricule national ne doit être créé.
9. Le parent suit le parcours SMART ENROLL, charge la preuve de paiement et reçoit un justificatif après validation.
10. Les canaux de paiement sont ceux autorisés par l'établissement et, pour les frais réglementaires, par l'autorité compétente.
11. La preuve téléchargée ne vaut pas automatiquement confirmation d'encaissement.
12. Chaque professeur possède un compte personnel.
13. Le chef d'établissement affecte les professeurs aux classes et matières.
14. Le professeur scanne les copies ; le système extrait les notes.
15. Chaque note extraite reste soumise au OK du professeur.
16. Le bulletin se met à jour automatiquement après validation d'une note.
17. Lorsque les notes d'une évaluation sont traitées, le professeur peut cliquer sur DIFFUSER.
18. Les parents concernés reçoivent une notification de publication.
19. L'enseignant prépare ses cours dans l'application et filme une capsule de préparation destinée à informer les parents sur le programme de la journée.
20. Le parent peut consulter le programme quotidien et le cours réellement prévu/en cours.
21. L'enseignant peut signaler son absence dans l'application ; le parent est informé du cours réellement organisé et du statut de l'enseignant après confirmation par l'école.
22. Le parent reçoit une alerte à l'arrivée et au départ de son enfant à la suite du scan de son badge QR.
23. CAMPUS237 intègre les fonctions pertinentes de NAXA SECURITY pour les établissements disposant de caméras compatibles.
24. Une IA détecte des événements potentiellement dangereux et déclenche une alerte à vérifier par un humain.
25. Les exclusions NAXA SECURITY sont maintenues : reconnaissance faciale, IMSI, enregistrement vocal discret, verrouillage automatique des portes et appel automatique à la police.
26. L'IA ne décide jamais seule d'une note, sanction, exclusion, admission ou paiement.
27. Chaque établissement dispose d'un espace COMMUNITY pour les parents.
28. Les communautés des différents établissements restent séparées.
29. CAMPUS237 KNOWLEDGE inclut livres numériques, encyclopédie, vidéos référencées et annales ; l'accès aux ressources autorisées est gratuit pour les parents.
30. CAMPUS237 OPPORTUNITIES permet des annonces de stages, formations, répétitions, tutorat et opportunités éducatives payées à la semaine.
31. Les modules utiles de NAXA, NAXA HOTEL, COTIZ, NAXA SERVICES, JOBLY, LOYABLE, GrillaD, ZIPPLE et NAXA SECURITY sont réutilisés par composants et API.
32. Les notifications applicatives sont prévues comme canal gratuit du modèle produit ; coûts d'infrastructure suivis.
33. Le projet conserve l'orientation de lancement direct sans pilote public, avec recette interne complète avant mise en service.
34. Le tarif parent mensuel de référence de la V2.0 est 600 FCFA pendant neuf mois, avec prix annuel annoncé à 4 200 FCFA ; l'arithmétique et la nature familiale ou par enfant sont conservées explicitement.
35. La répartition historique 80 % CAMPUS237 / 20 % fonds scolaire sur le net reçu est maintenue comme règle V2.0 à arbitrer après introduction du tarif établissement.
36. Le tarif établissement selon effectif a été communiqué, avec chevauchement et plages manquantes à résoudre avant facturation.
37. Aucun PIN ni OTP n'est lu ou stocké.
38. La vie privée, la sécurité et les données des mineurs ont priorité sur la commodité.

---

# 36. SOURCES ET RÉFÉRENCES DE CADRAGE

## 36.1 Documents internes du dépôt

- V2.0 : [Cahier des charges CAMPUS237 du 5 novembre 2026](Cahier_des_charges_08_Campus237.pdf).
- Continuité famille NAXA / Campus237 / NAXA Security du 10 novembre 2026 : [fichier de continuité](../Continuite_projet_au_10_novembre_2026.md).
- Prompts CAMPUS237 : [Prompts série 12](../Prompt/Prompts_12_Campus237.pdf).
- Répertoire applicatif : [apps/campus237](../../apps/campus237/README.md).

## 36.2 Références externes à contrôler avant mise en service

- Présidence de la République du Cameroun — loi n° 2024/017 du 23 décembre 2024 relative à la protection des données personnelles : https://prc.cm/fr/actualites/actes/lois/7588-loi-n-2024-017-du-23-decembre-2024-autorisant-le-president-de-la-republique-a-ratifier-le-traite-de-beijing-sur-les-interpretations-et-executions-audiovisuelles-adopte-le-24-juin-2012-a-beijing-chine-9
- GICAM — pilier juridique, références de conformité données personnelles et cybersécurité : https://gcicameroon.cm/index.php/component/content/article/pilier-juridique?catid=2
- CarteScolaire / MINESEC — portail officiel : https://cartescolaire.cm/minesec
- CarteScolaire — FAQ, identifiant national et vérification des reçus : https://www.cartescolaire.cm/faq
- MINESEC — informations 2026/2027 relatives au matricule et aux paiements : https://ecolesaucameroun.com/en/article.php?id=231-minesec-press-release-related-to-the-payment-of-tuition-and-examination-fecs-for-the-2026-2027-school-year
- Google Play — politique sur les permissions SMS et Call Log : https://support.google.com/googleplay/android-developer/answer/10208820
- Google Play — permissions donnant accès à des informations sensibles : https://support.google.com/googleplay/android-developer/answer/16558241
- Supabase — Row Level Security, état de la documentation consultée le 22 novembre 2026 : https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase — Storage Access Control : https://supabase.com/docs/guides/storage/security/access-control
- CNIL — dispositifs vidéo dans les établissements scolaires, référence comparative de protection de la vie privée, non substitutive au droit camerounais : https://www.cnil.fr/fr/les-dispositifs-video-dans-les-etablissements-scolaires

## 36.3 Avertissement de conformité

Les références ci-dessus structurent le travail, mais ne remplacent pas un avis juridique camerounais. Avant activation des traitements de données d'enfants, caméras, IA vidéo, transferts internationaux, paiements réglementaires et contenus sous droits, une revue par un professionnel compétent doit confirmer les textes applicables, formalités, contrats, consentements et obligations de l'établissement comme de l'éditeur.

---

# 37. CONDITION FINALE DE VALIDATION V3.0

La V3.0 est la référence de spécification. Elle sera considérée prête pour le développement détaillé lorsque :
- les arbitrages bloquants du chapitre 34 auront reçu une réponse ;
- les règles d'identité et d'intégration CarteScolaire seront définies ;
- l'architecture aura été validée au regard du dépôt NAXA et du socle de la famille ;
- les traitements de données et de vidéosurveillance auront reçu leur revue de conformité ;
- la tarification ne contiendra plus de chevauchements ;
- chaque module aura une matrice de droits, des parcours, des règles et des critères de recette ;
- la recette complète aura été préparée et les responsabilités de mise en service attribuées.

**Fin du cahier des charges maître CAMPUS237 V3.0.1.**


---

# 38. ADDENDUM V3.0.1 — APE, RÉUNIONS, VISIOCONFÉRENCES ET CONVOCATIONS

Cet addendum complète les chapitres 2, 10, 14, 15, 19, 25, 27, 29, 31, 32, 34 et 35. En cas de contradiction, les exigences spécifiques du présent addendum prévalent pour les fonctionnalités qu'il introduit.

## 38.1 Compte institutionnel APE / APEE

🔒 Chaque établissement peut disposer d'un compte institutionnel propre à son association de parents d'élèves, désignée APE ou APEE selon le nom officiel retenu par l'établissement.

Ce compte n'est pas un compte parent ordinaire et n'est pas automatiquement attribué à tous les parents. Il est associé à une association identifiée, à un établissement, à un mandat et à des membres autorisés.

Le compte APE/APE doit permettre :
- de disposer d'une page institutionnelle propre à l'association dans l'application ;
- d'identifier les membres du bureau et leurs fonctions ;
- de gérer les mandats, dates de début et de fin, renouvellements et remplacements ;
- de publier les communications officielles de l'association ;
- de convoquer les parents à des réunions ;
- d'organiser des réunions physiques, des visioconférences et des réunions hybrides ;
- de partager les ordres du jour et documents préparatoires ;
- de gérer les confirmations de présence ;
- de faire l'appel et d'établir la liste des participants ;
- de rédiger et publier les procès-verbaux selon les droits ;
- d'enregistrer les résolutions et les actions à réaliser ;
- de suivre les échéances et responsables ;
- de consulter les rapports associatifs autorisés ;
- de gérer, si l'école l'autorise et si les règles applicables le permettent, les appels de cotisations, reçus et états du fonds APE.

## 38.2 Rôles APE

| Rôle | Permissions |
|---|---|
| Président(e) APE | Gestion du compte institutionnel, convocations, réunions et validations selon mandat |
| Secrétaire APE | Ordres du jour, invitations, présences, procès-verbaux et résolutions |
| Trésorier(ère) APE | États financiers associatifs, cotisations et reçus selon mandat |
| Membre du bureau | Accès limité aux fonctions explicitement déléguées |
| Parent membre | Consultation des informations diffusées à l'ensemble ou à son groupe |
| Direction de l'école | Coordination institutionnelle et consultation des éléments relevant de sa responsabilité, sans prise de contrôle arbitraire de l'association |
| Administration plateforme | Support technique et sécurité ; aucune gestion de fond ou décision associative à la place de l'APE |

Le chef d'établissement vérifie le rattachement de l'association et les personnes habilitées au moyen des pièces ou décisions appropriées. Le remplacement d'un membre du bureau entraîne la mise à jour des rôles et la révocation des accès qui ne sont plus justifiés.

Le compte APE ne donne pas automatiquement accès aux notes, à la santé, aux paiements individuels, aux dossiers disciplinaires ou aux messages privés d'un élève.

## 38.3 Gestion de bout en bout des réunions

CAMPUS237 doit permettre à l'APE comme à l'école d'organiser une réunion sans sortir du parcours de gestion.

Types de réunion :
- assemblée générale de l'APE ;
- réunion ordinaire ou extraordinaire de parents ;
- réunion de parents d'une classe ;
- réunion d'information de l'établissement ;
- réunion parents-professeurs ;
- réunion de conseil ou commission lorsque les personnes ont qualité pour y participer ;
- réunion d'organisation d'un événement scolaire ;
- réunion de suivi d'une situation individuelle, avec accès restreint.

Chaque réunion possède :
- un organisateur et un responsable ;
- un établissement et éventuellement une classe ;
- un type et un niveau de confidentialité ;
- un objet et un ordre du jour ;
- une date, une heure de début et de fin ;
- un mode : présentiel, visioconférence ou hybride ;
- une salle physique ou un lien sécurisé ;
- une liste de personnes invitées ou groupes ciblés ;
- des documents préparatoires ;
- un délai de réponse ;
- des rappels ;
- un statut : brouillon, programmée, invitations envoyées, confirmée, en cours, terminée, annulée ou reportée.

Le système envoie les notifications aux bons destinataires et suit les accusés de réception lorsque le canal le permet. L'organisateur peut relancer les personnes qui n'ont pas répondu.

## 38.4 Visioconférence intégrée

🔒 Les réunions et convocations peuvent se dérouler par visioconférence.

🔵 La visioconférence doit être accessible depuis CAMPUS237 FAMILY et les espaces autorisés de CAMPUS237 SCHOOL/DIRECTION, par un lien sécurisé ou une intégration de service compatible.

Fonctions attendues :
- création d'une salle pour une réunion donnée ;
- lien d'accès unique ou contrôlé ;
- salle d'attente ;
- authentification ou vérification des invités ;
- contrôle de l'organisateur ;
- admission et exclusion d'un participant par l'hôte ;
- désactivation du micro ou de la caméra par l'utilisateur ;
- partage d'écran et présentation des documents lorsque nécessaire ;
- modération et prise de parole ;
- indication de connexion faible ;
- reconnexion après coupure ;
- feuille de présence issue des connexions et validée par l'organisateur ;
- fermeture de la salle et archivage des éléments autorisés.

Aucun participant ne doit rejoindre une réunion confidentielle simplement parce qu'il a reçu un lien transféré. Les droits d'accès sont contrôlés côté serveur. Les liens expirent après la réunion ou selon la politique retenue.

L'enregistrement audio/vidéo est désactivé par défaut. Il ne peut être activé qu'après information préalable des participants, base juridique et autorisations requises, avec indication claire de l'enregistrement et des règles de conservation. Un procès-verbal écrit peut être produit sans enregistrer la réunion. Les transcriptions automatiques ou résumés IA ne sont pas activés par défaut ; ils nécessitent la même analyse de conformité et un contrôle humain.

Pour les réunions concernant un enfant ou une situation familiale, le système n'invite que les responsables concernés et les personnels habilités. Aucun contenu confidentiel n'est partagé dans la communauté générale.

## 38.5 Procès-verbaux, résolutions et suivi

À la fin de la réunion, le secrétaire ou l'organisateur peut :
- établir le procès-verbal ;
- joindre les documents approuvés ;
- enregistrer les décisions prises ;
- identifier les responsables ;
- attribuer des échéances ;
- demander validation ou signature selon les règles de l'association/école ;
- diffuser le compte rendu aux seuls participants ou groupes autorisés ;
- suivre l'état des actions jusqu'à clôture.

Les versions successives d'un procès-verbal sont conservées. Une modification après validation crée une nouvelle version avec motif et auteur ; elle ne remplace pas silencieusement la version déjà approuvée.

Pour l'APE, le système conserve les règles de quorum, de vote, de procuration et de majorité uniquement lorsqu'elles sont définies dans les statuts ou règlements applicables. CAMPUS237 ne doit pas inventer la validité juridique d'un vote électronique.

## 38.6 Cotisations et fonds associatif

L'APE peut publier un appel de cotisation ou de contribution, si ses statuts et l'accord de l'école l'autorisent. Les flux associatifs doivent être séparés des frais réglementaires de scolarité et de la comptabilité de l'établissement.

Chaque contribution possède un appel, un bénéficiaire associatif, un motif, un montant, un paiement, un justificatif et une trace de rapprochement. Le trésorier et les personnes autorisées consultent les états globaux. Les contributions individuelles ne sont pas exposées dans la communauté générale.

Les flux APE ne sont pas automatiquement fusionnés avec le partage 80/20 des abonnements parentaux : ils relèvent de conventions et de comptes distincts.

---

# 39. CONVOCATIONS SCOLAIRES ET RENDEZ-VOUS EN VISIOCONFÉRENCE

## 39.1 Convocation par l'établissement

🔒 L'école doit pouvoir convoquer un parent ou tuteur via CAMPUS237. Une convocation peut être organisée en présentiel, par visioconférence ou en format hybride.

La convocation peut concerner :
- entretien pédagogique ;
- suivi d'absences ou de retards ;
- rencontre avec le professeur principal ;
- échange avec un enseignant ;
- réunion avec la direction ;
- situation de discipline ou conseil, selon les droits et règles applicables ;
- accompagnement ou orientation ;
- demande de pièces ou régularisation administrative ;
- urgence ou situation de protection de l'élève.

## 39.2 Contenu de la convocation

Chaque convocation contient :
- référence unique ;
- établissement ;
- parent/tuteur destinataire ;
- enfant concerné lorsque nécessaire ;
- service ou personne convoquante ;
- objet et motif communiqué ;
- niveau de confidentialité ;
- date et plage horaire ;
- mode présentiel, visioconférence ou hybride ;
- adresse ou lien d'accès ;
- liste des participants habilités ;
- documents à apporter ou préparer ;
- délai de réponse ;
- possibilité de confirmer, demander un autre créneau ou signaler une impossibilité.

Le motif doit être rédigé avec mesure et ne doit pas exposer dans une notification verrouillée des détails sensibles de discipline, santé ou situation familiale.

## 39.3 Cycle de vie

1. L'acteur habilité crée et signe/valide la convocation selon la délégation.
2. Le parent reçoit la notification dans CAMPUS237 FAMILY.
3. Le parent accuse réception, confirme, demande un autre créneau ou sollicite un autre mode autorisé.
4. L'école confirme le rendez-vous et génère l'accès sécurisé s'il s'agit d'une visioconférence.
5. Les rappels sont envoyés selon une fréquence paramétrée.
6. À la réunion, la présence est enregistrée.
7. Le compte rendu, les décisions, engagements et dates de suivi sont rattachés à la convocation.
8. La convocation est clôturée ou maintenue ouverte avec action de suivi.

L'école voit les convocations en attente, confirmées, reportées, non honorées et clôturées. Le parent voit son propre historique et les actions qui le concernent.

## 39.4 Confidentialité et droits

Une convocation individuelle ne doit jamais être visible par les autres parents. Une convocation disciplinaire n'est accessible qu'aux personnes qui ont qualité pour la traiter. L'APE n'accède pas à une convocation individuelle sans mandat et base juridique spécifique.

Une convocation concernant un mineur est adressée au(x) tuteur(s) qui disposent des droits appropriés. Les différends de garde suivent les règles documentées par l'école et les décisions légales applicables.

---

# 40. LIVRET SCOLAIRE UNIQUE — PASSEPORT SCOLAIRE PERMANENT ET TRANSFÉRABLE

## 40.1 Principe obligatoire

🔒 CAMPUS237 doit gérer un livret scolaire unique qui accompagne l'élève tout au long de son cursus et qui peut être transféré d'une école partenaire à une autre via l'application.

Le livret est rattaché à un identifiant élève transversal CAMPUS237 distinct :
- du matricule national officiel ;
- du matricule local de chaque établissement ;
- du compte parent ;
- du compte de l'école.

Il accompagne l'élève de la maternelle, du primaire, du secondaire et, lorsque le cadre le permet, de la formation professionnelle.

Le livret conserve l'historique de chaque établissement et chaque année. Une école d'accueil ne peut pas réécrire les données émises par une école d'origine.

## 40.2 Sens de « non modifiable »

Le livret est **non modifiable en place** par un établissement, un parent ou un utilisateur. Les informations déjà émises sont conservées avec leur provenance, leur auteur institutionnel, leur date et leur preuve d'intégrité.

Une erreur ne peut pas être corrigée par écrasement silencieux. Elle fait l'objet d'une procédure de rectification :
- demande motivée ;
- vérification de l'émetteur ou de l'autorité compétente ;
- pièce justificative si nécessaire ;
- ajout d'un acte rectificatif signé ;
- lien entre la valeur initiale et la correction ;
- horodatage, auteur et motif ;
- journal d'audit.

Ce mécanisme d'historique append-only ne supprime pas les droits légaux de rectification, d'opposition, de limitation ou d'effacement applicables aux données personnelles. Lorsqu'une obligation légale impose la rectification, restriction ou suppression, la plateforme applique la mesure requise tout en préservant uniquement les traces dont la conservation est légalement justifiée.

Le terme « immuable » décrit l'intégrité de l'historique et l'impossibilité d'une réécriture unilatérale, pas une conservation illimitée contraire à la loi.

## 40.3 Contenu du livret

Contenu principal proposé :
- identifiant transversal CAMPUS237 ;
- identité et identifiants officiels applicables ;
- chronologie des inscriptions et établissements ;
- sections, cycles, classes et filières ;
- programmes/référentiels suivis ;
- résultats, notes, moyennes et bulletins officiels émis ;
- compétences et évaluations par compétences ;
- examens, attestations et certifications ;
- décisions de passage, redoublement ou orientation ;
- assiduité sous forme et niveau de détail autorisés ;
- activités scolaires ou réalisations validées lorsque pertinentes ;
- documents officiels numérisés et références de vérification ;
- provenance, émetteur, signatures, dates et versions.

Les données de santé ne font pas partie du livret portable standard. Les dossiers financiers des familles, coordonnées privées, messages, données de communauté et images de vidéosurveillance en sont exclus.

Les dossiers disciplinaires détaillés ne sont pas transférés par défaut. Toute information disciplinaire transmissible doit faire l'objet d'une règle distincte, nécessaire, proportionnée, légalement validée et explicitement portée à la connaissance du responsable concerné.

## 40.4 Émission et signature institutionnelle

Chaque établissement émet uniquement les événements et documents relevant de sa compétence. Le livret conserve :
- établissement émetteur ;
- responsable habilité ;
- date d'émission ;
- période scolaire ;
- référence de document ;
- version ;
- signature ou sceau électronique adapté ;
- empreinte d'intégrité ;
- statut de validité ;
- éventuel acte rectificatif.

Un QR ou code de vérification permet de contrôler l'authenticité et l'intégrité du document, sans exposer les notes ou les données personnelles à une personne non autorisée.

La signature électronique et la force probante des documents doivent être validées juridiquement ; une signature dessinée à l'écran n'est pas présentée automatiquement comme une signature électronique qualifiée ou un diplôme officiel.

## 40.5 Transfert d'école à école

Parcours :
1. Le parent ou représentant habilité demande le transfert depuis CAMPUS237 FAMILY.
2. Le système vérifie le lien avec l'élève et les droits du demandeur.
3. L'école d'accueil est sélectionnée.
4. L'établissement d'origine est notifié uniquement lorsque la demande de transfert est effectivement initiée, pas lors d'une simple recherche d'école.
5. Les conditions officielles de transfert et l'identifiant national applicable sont contrôlés.
6. L'établissement d'origine prépare le dossier portable.
7. Les pièces et événements transférables sont vérifiés, signés et scellés.
8. Le parent autorise le transfert selon la base légale applicable.
9. Le dossier est transmis par canal sécurisé à l'école d'accueil.
10. L'école d'accueil vérifie la provenance, l'intégrité, les signatures et le contenu.
11. L'école d'accueil accepte ou retourne le dossier avec motif.
12. Le transfert est confirmé ; la nouvelle inscription est créée sans effacer l'historique antérieur.
13. Un reçu de transfert et un journal des accès sont conservés.

Les dossiers d'origine restent attribués à leur émetteur. L'école d'accueil peut ajouter ses propres événements et documents, mais ne peut pas modifier les documents émis par l'école précédente.

## 40.6 Droits d'accès au livret

Le parent/tuteur habilité consulte le livret de l'enfant selon ses droits. L'élève peut disposer d'une vue adaptée à son âge. L'école d'origine voit ses propres données émises et les demandes de transfert la concernant. L'école d'accueil consulte les éléments transférés après autorisation et validation. Le promoteur ne reçoit que les droits explicitement définis. Les auditeurs ont un accès temporaire et limité.

Une école ne peut pas rechercher ou consulter librement les livrets d'élèves qui ne lui sont pas rattachés.

## 40.7 Distinction avec les identifiants officiels et dossiers officiels

Le livret unique CAMPUS237 est un dossier numérique de continuité scolaire. Il ne remplace pas les registres et documents officiels imposés par l'État, le matricule national CarteScolaire ni les procédures de transfert réglementaires. Les documents officiels restent émis ou reconnus par les autorités compétentes.

---

# 41. CAMPUS237 SCHOOL FINDER — OFFRES DE RENTRÉE, RECHERCHE ET VISITES

## 41.1 Objectif

🔒 Les écoles partenaires doivent pouvoir publier dans CAMPUS237 leurs offres et informations d'admission, particulièrement à l'approche de la rentrée scolaire.

Un parent qui recherche une nouvelle école pour son enfant peut interroger le volet SCHOOL FINDER, exprimer ses critères, comparer les établissements qui correspondent et prendre un rendez-vous en présentiel pour visiter l'école et obtenir des informations complémentaires.

Ce parcours de recherche reste privé. L'école actuellement fréquentée par l'enfant n'est pas avertie de la recherche ou de la comparaison.

## 41.2 Profil public d'un établissement partenaire

Chaque établissement partenaire dispose d'une fiche vérifiée comprenant, selon les données fournies :
- nom officiel et nom d'usage ;
- statut public/privé/confessionnel ;
- autorisations ou agréments, avec éléments de vérification lorsque requis ;
- adresse, quartier, ville et zone desservie ;
- sections et langues ;
- cycles, niveaux, séries et filières ;
- classes ouvertes pour la prochaine rentrée ;
- capacités et places déclarées ;
- frais détaillés et conditions d'admission ;
- dates de préinscription et d'inscription ;
- bourses, réductions ou conditions spécifiques, si elles existent ;
- cantine, transport, internat et autres services ;
- équipements et activités ;
- dispositifs d'accompagnement et accessibilité ;
- photos et médias autorisés ;
- journées portes ouvertes ;
- coordonnées institutionnelles ;
- date de dernière mise à jour et période de validité des informations.

Les caractéristiques et chiffres publiés doivent être déclarés par l'école, contrôlés selon leur importance et datés. Une information non vérifiée est identifiée comme déclarative et ne doit pas être présentée comme certifiée.

## 41.3 Campagnes et offres de rentrée

Chaque école peut créer une campagne liée à une année scolaire :
- rentrée et admissions ;
- préinscription ;
- nouvelles classes ou nouvelles filières ;
- places disponibles ;
- journées portes ouvertes ;
- bourses ou aides annoncées ;
- frais et échéanciers ;
- activités, services et options ;
- dates limites et conditions d'admission.

Chaque offre a une période de validité, un niveau concerné, des critères, un nombre de places déclaré le cas échéant, un contact responsable et un statut de modération.

Le système désactive ou archive automatiquement une offre expirée. L'établissement est responsable de l'exactitude et de la mise à jour de ses informations.

Les offres des établissements scolaires dans SCHOOL FINDER sont distinctes des annonces commerciales OPPORTUNITIES (stages, formations, tutorat, etc.). Aucun tarif de publication des offres scolaires n'est fixé dans cet addendum : la gratuité, l'inclusion ou une éventuelle facturation doit faire l'objet d'un arbitrage commercial séparé.

## 41.4 Recherche guidée et conversationnelle par critères

Le parent peut lancer une recherche classique par filtres ou interroger le volet comme un assistant conversationnel.

Exemples de critères :
- localisation, quartier, ville et temps de trajet souhaité ;
- cycle, niveau et classe recherchés ;
- section francophone, anglophone, bilingue ou autre ;
- établissement public ou privé ;
- budget et détail des frais ;
- langue d'enseignement ;
- disponibilité de places ;
- transport, cantine ou internat ;
- horaires ;
- activités ou options ;
- besoins d'accessibilité et d'accompagnement ;
- calendrier d'admission ;
- distance maximale ;
- visite possible à des dates précises.

L'assistant reformule les critères, demande une précision lorsque nécessaire et lance une recherche exclusivement à partir des fiches et offres publiées par les établissements. Il ne fabrique pas de caractéristiques, tarifs, places, résultats ou accréditations.

Chaque résultat explique les critères correspondants, les critères non renseignés et les éventuels écarts. Les filtres et raisons de classement sont visibles et modifiables par le parent.

## 41.5 Comparaison transparente

Le parent peut comparer plusieurs établissements sur des informations homogènes :
- frais connus ;
- niveau disponible ;
- section ;
- services ;
- distance ou zone ;
- conditions d'admission ;
- disponibilité déclarée ;
- dates de rentrée et de visite ;
- éléments vérifiés ou simplement déclarés.

Aucun établissement ne peut acheter un meilleur rang dans les résultats. Les annonces sponsorisées, si elles sont un jour autorisées, sont séparées et clairement étiquetées ; elles ne modifient pas le classement organique par critères.

L'absence d'une information est affichée « non renseignée », jamais remplacée par une estimation IA.

## 41.6 Rendez-vous en présentiel

🔒 Le parent peut réserver un rendez-vous physique avec un établissement de son choix pour découvrir l'école, rencontrer un responsable, visiter les locaux et obtenir des précisions.

L'école publie ses créneaux de visite :
- journées portes ouvertes ;
- créneaux individuels ;
- rendez-vous avec le responsable des admissions ;
- visite des infrastructures ;
- réunion d'information ;
- échange sur une classe, filière ou besoin précis.

Parcours :
1. le parent sélectionne l'école ;
2. consulte les créneaux disponibles ;
3. indique le cycle/niveau recherché et le motif ;
4. choisit un créneau ;
5. envoie la demande ;
6. l'école confirme, propose un autre créneau ou refuse avec motif approprié ;
7. parent et école reçoivent confirmation et rappel ;
8. le parent se présente, l'école enregistre la visite ;
9. le parent peut demander une préinscription ou un dossier d'admission après la visite.

Un rendez-vous de visite n'est pas une admission garantie. Il n'entraîne pas de transfert automatique du livret scolaire ni de communication à l'école actuelle.

## 41.7 Confidentialité des recherches

Les recherches et comparaisons du parent restent privées. Aucun établissement consulté n'est averti avant une demande de rendez-vous ou de candidature initiée par le parent. L'école actuelle n'est jamais informée automatiquement d'une recherche d'alternative.

Le parent choisit les informations qu'il transmet à l'école visitée. Les données du livret scolaire et les documents de l'enfant ne sont pas transmis pour une simple recherche. Leur transmission exige une démarche distincte avec contrôle des droits et autorisation applicable.

## 41.8 Modération et gouvernance de l'annuaire

L'administration CAMPUS237 vérifie l'identité de l'établissement et les éléments requis pour le profil. Les mises à jour sensibles (agrément, tarif, adresse, places) sont historisées. Les établissements peuvent demander correction de leur fiche.

Les comparaisons ne doivent pas devenir des notes ou classements payants. Les avis parentaux, s'ils sont activés, nécessitent règles, modération, droit de réponse et protection contre la divulgation d'informations sur les enfants.

---

# 42. MODÈLE DE DONNÉES — AJOUTS V3.0.1

Les entités suivantes complètent le chapitre 29. Elles sont conceptuelles et nécessitent dictionnaire, relations, index, politiques d'accès et migrations après validation technique.

## 42.1 APE et réunions

ape_associations, ape_accounts, ape_members, ape_mandates, ape_roles, ape_meetings, meeting_agendas, meeting_invites, meeting_attendance, meeting_rooms, meeting_video_sessions, meeting_documents, meeting_minutes, meeting_minute_versions, meeting_resolutions, meeting_action_items, meeting_votes, meeting_proxies, meeting_recording_consents, meeting_access_logs.

## 42.2 Convocations et rendez-vous

parent_convocations, convocation_recipients, convocation_acks, convocation_reschedules, convocation_attendance, convocation_minutes, convocation_followups, appointment_slots, appointment_bookings, appointment_participants, appointment_reminders, appointment_outcomes.

## 42.3 Livret unique et transfert

student_portfolios, portfolio_identifiers, portfolio_events, portfolio_documents, portfolio_issuers, portfolio_signatures, portfolio_integrity_hashes, portfolio_versions, portfolio_correction_requests, portfolio_correction_events, portfolio_access_grants, portfolio_transfer_requests, portfolio_transfer_packages, portfolio_transfer_items, portfolio_transfer_signatures, portfolio_transfer_receipts, portfolio_access_logs, portfolio_retention_actions.

## 42.4 SCHOOL FINDER

school_public_profiles, school_verifications, school_admission_campaigns, school_offers, school_offer_levels, school_capacity_snapshots, school_fee_schedules, school_services, school_open_days, school_visit_slots, school_visit_bookings, school_visit_attendees, school_visit_outcomes, parent_school_searches, school_search_criteria, school_comparison_sets, school_listing_moderation, school_listing_change_logs.

---

# 43. CRITÈRES DE RECETTE ADDITIONNELS V3.0.1

## 43.1 APE et réunions

1. Une association APE possède un compte institutionnel rattaché à une école.
2. Un parent ordinaire ne peut pas agir avec les permissions du bureau APE.
3. Un mandat expiré entraîne la révocation ou suspension des droits correspondants.
4. Le président ou membre autorisé crée une réunion physique, vidéo ou hybride.
5. Les invitations ne sont envoyées qu'aux groupes sélectionnés.
6. Un parent peut confirmer, décliner ou demander un autre créneau.
7. Une personne non invitée ne peut pas entrer dans une visioconférence confidentielle avec un lien transféré.
8. La salle d'attente et le contrôle d'accès sont opérationnels.
9. La feuille de présence conserve la distinction entre connexion technique et présence confirmée.
10. L'enregistrement est désactivé par défaut.
11. Un compte rendu validé ne peut pas être modifié silencieusement.
12. Une résolution peut générer des actions, responsables et échéances.
13. Un parent ne voit aucune convocation individuelle d'une autre famille.
14. L'APE ne consulte pas les dossiers individuels d'élèves par défaut.

## 43.2 Convocations scolaires

15. Une convocation est adressée uniquement au tuteur habilité.
16. Elle peut être présentielle, vidéo ou hybride.
17. Le parent reçoit les informations d'accès et peut confirmer ou demander un report.
18. Le lien vidéo expiré ou utilisé hors droits est refusé.
19. Les rappels et accusés sont historisés.
20. Le compte rendu reste visible seulement aux personnes autorisées.
21. L'école suit les convocations en attente, tenues, reportées et clôturées.

## 43.3 Livret scolaire unique

22. L'élève conserve le même identifiant transversal CAMPUS237 au fil de son cursus, si son attribution et son usage sont légalement validés.
23. Le matricule national et les références locales restent séparés.
24. Une école ne peut pas écraser ou supprimer l'événement scolaire émis par une autre école.
25. Toute rectification est un événement complémentaire traçable et lié à l'original.
26. L'intégrité du livret peut être vérifiée.
27. Un parent autorisé peut demander un transfert.
28. Une école d'accueil ne reçoit aucun document avant autorisation et déclenchement effectif du transfert.
29. L'école d'accueil vérifie la provenance et les signatures.
30. Le transfert conserve l'historique et n'efface pas les données de l'école d'origine.
31. Les informations médicales, vidéosurveillance et messages communautaires ne sont pas inclus dans le livret.
32. Une demande légale de rectification, limitation ou effacement est traitée malgré le principe d'historique non modifiable en place.
33. Un QR de vérification ne révèle pas les notes à un utilisateur non autorisé.

## 43.4 SCHOOL FINDER

34. Une école partenaire publie son profil et une campagne de rentrée.
35. Chaque offre possède une date de validité et un historique.
36. Une annonce expirée n'est plus présentée comme active.
37. Le parent recherche selon ses critères et peut poser une question conversationnelle.
38. L'IA ne crée aucun tarif, place, agrément ou service qui n'existe pas dans la fiche.
39. Les critères de comparaison sont visibles.
40. Un classement ne peut pas être acheté.
41. Le parent peut comparer plusieurs écoles.
42. Il peut réserver une visite présentielle.
43. L'école confirme, refuse ou propose un autre créneau.
44. La visite est enregistrée et peut être suivie d'une préinscription.
45. Une simple recherche ne notifie pas l'école actuelle.
46. Une simple recherche ne transmet pas le livret scolaire.
47. Une visite ne vaut pas admission.
48. Le transfert du livret exige une démarche distincte et autorisée.

---

# 44. REGISTRE DES DÉCISIONS AJOUTÉES — V3.0.1

Les exigences suivantes sont confirmées comme exigences produit par le porteur du projet :

39. L'APE/ APEE doit pouvoir disposer d'un compte institutionnel dans CAMPUS237.
40. L'APE doit pouvoir organiser des visioconférences et réunions de parents depuis l'application.
41. L'école doit pouvoir convoquer les parents et tenir les convocations en visioconférence.
42. CAMPUS237 doit gérer les invitations, confirmations, accès, présences et suites de réunion de bout en bout.
43. L'élève doit disposer d'un livret scolaire unique qui suit son cursus.
44. Le livret ne doit pas être modifiable en place par une école ou un utilisateur.
45. Le livret doit pouvoir être transféré d'une école partenaire à une autre via CAMPUS237, avec traçabilité.
46. Les écoles partenaires peuvent publier des offres et informations d'admission, notamment à l'approche de la rentrée.
47. Le parent doit pouvoir interroger le volet de recherche pour trouver une école selon ses critères.
48. Le parent doit pouvoir comparer les écoles et prendre un rendez-vous en présentiel pour mieux les connaître.
49. Le bulletin est un dossier pédagogique vivant, recalculé après chaque note validée ; le bulletin officiel reste soumis à la clôture de la direction.
50. Les évaluations diffusées alimentent ACADEMIC RADAR ; le parent peut consulter avant le bulletin le rang provisoire de son enfant et voir son évolution en temps réel.
51. Les classements sont filtrables par groupe, école, section, cycle, niveau, série, classe, matière, période, année, évaluation et compétence.
52. Le parent ne voit que le rang et les indicateurs de son enfant, jamais les noms ou notes nominatives des autres élèves.
53. Licence école : 60 FCFA/élève pour les 1 000 premiers, 50 FCFA du 1 001e au 5 000e, 40 FCFA dès le 5 001e ; progressif marginal, minimum 15 000 FCFA/mois.
54. Licence école facturée sur 12 mois et incluant tous les modules logiciels et les comptes du personnel autorisés sans supplément par utilisateur ou module.
55. Les groupes scolaires cumulent les effectifs pour les tranches marginales ; le minimum s'applique une seule fois au groupe.
56. ACCESS parent est gratuit, avec sécurité, suivi des cours, notes diffusées, rang personnel, bulletins, convocations, reçus, communauté et livret.
57. PREMIUM est familial : 600 F/mois pour 1 enfant, 900 F pour 2, 1 150 F pour 3, 1 350 F pour 4, 1 550 F pour 5, puis +200 F par enfant supplémentaire ; annuel égal à sept mensualités.
58. Un compte familial suit plusieurs enfants et plusieurs écoles sans double facturation d'un même enfant.
59. LEARNING CONTINUITY suit les cours prévus, réellement dispensés et les rattrapages.
60. SKILL PASSPORT accompagne les compétences et preuves vérifiées tout au long du cursus.
61. LEARNING RECOVERY propose des remédiations supervisées par les enseignants.
62. FAMILY COMMAND CENTER consolide calendriers et événements des enfants multi-écoles.
63. SAFE REUNIFICATION trace les étapes de prise en charge, montée, descente et remise.
64. SCHOOL TRANSPARENCY permet de suivre projets et réalisations avec données autorisées.
65. SCHOOL INTELLIGENCE permet des requêtes de pilotage sourcées, datées et filtrées.
66. Les bus équipés d'un GPS compatible peuvent être connectés à NAXA SECURITY afin que les parents autorisés suivent le véhicule sur un trajet actif où leur enfant est enregistré à bord.
67. Le GPS localise le véhicule, pas l'enfant ; suivi limité au trajet et aux droits autorisés.
68. Le menu de cantine du lendemain est publié la veille dans le fil officiel COMMUNITY ; les parents concernés reçoivent une notification.
69. Les coûts matériel GPS, SIM/données et équipements tiers sont distincts du logiciel et transparents.
70. Les fonctions de classement, géolocalisation, vidéos et données enfant restent soumises aux droits d'accès et aux gates de conformité.

Les règles de sécurité, de signature, de correction, de réunion, de visite et de transfert décrites dans cet addendum sont des spécifications de mise en œuvre proposées pour rendre ces décisions sûres et testables. Les montants, frais, modalités juridiques et formalités restent soumis aux arbitrages correspondants.

---

# 45. SOURCES ET RÉFÉRENCES COMPLÉMENTAIRES V3.0.1

- Loi camerounaise n° 2024/017 du 23 décembre 2024 relative à la protection des données personnelles — texte publié par la Présidence de la République : https://www.prc.cm/fr/actualites/actes/lois/7588
- Texte et articles de la loi 2024/017, notamment principes de consentement, exactitude et durée de conservation : https://www.soso.legal/soso/legal_text/735
- Loi camerounaise n° 2010/021 du 21 décembre 2010 régissant le commerce électronique — document de référence : https://art.cm/sites/default/files/documents/Loi-commerce-electronique-N-2010-021-du-21-12-2010.pdf
- MINESEC / CarteScolaire — portail officiel : https://cartescolaire.cm/minesec
- CarteScolaire — FAQ : https://www.cartescolaire.cm/faq

La conservation du livret, la valeur des signatures ou sceaux électroniques, le transfert trans-écoles, les convocations numériques, les assemblées et votes APE, les enregistrements de visioconférence et les traitements de données de mineurs doivent être validés par un juriste camerounais au regard des textes en vigueur et des statuts des associations concernées.

---

# 46. CONDITION DE VALIDATION DE L'ADDENDUM V3.0.1

L'addendum est considéré correctement spécifié lorsque :
- le compte APE et les mandats sont définis ;
- les rôles et droits des réunions sont testés ;
- les visioconférences peuvent être gérées sans exposition de réunions privées ;
- les convocations scolaires disposent d'un cycle de vie complet ;
- le principe d'un livret unique, non modifiable en place et rectifiable par acte contrôlé est validé juridiquement ;
- le format de transfert et la signature des documents sont définis ;
- le volet SCHOOL FINDER propose des profils vérifiés, offres de rentrée, recherche multicritère et conversationnelle, comparaison transparente et réservation de visites ;
- les recherches parentales restent confidentielles ;
- les conditions commerciales de publication des offres scolaires, si une facturation est envisagée, sont arbitrées séparément ;
- les critères de recette du chapitre 43 sont couverts.

**Fin de l'addendum CAMPUS237 V3.0.1.**



---

# 47. ADDENDUM V3.0.2 — BULLETIN VIVANT, ACADEMIC RADAR, ABONNEMENTS ET SERVICES INTELLIGENTS

Le présent addendum est approuvé par le porteur du projet le 22 novembre 2026. Il fige les ajouts pédagogiques, familiaux, économiques et opérationnels ci-dessous. Il complète les chapitres 9, 10, 11, 16, 21, 22, 23, 27, 29, 32, 33, 34 et 35. En cas de conflit, ses règles tarifaires et fonctionnelles prévalent sur les formulations antérieures non encore arbitrées.

## 47.1 Bulletin scolaire vivant — mise à jour au fil des soumissions

🔒 Le bulletin se met à jour progressivement au fur et à mesure que les enseignants valident et transmettent les notes.

Le fonctionnement distingue les états suivants :
1. **Scan / saisie en cours :** notes non validées ; elles ne sont pas prises en compte comme résultats pédagogiques officiels.
2. **Validée par le professeur :** la note a reçu le OK explicite de l'enseignant ; elle peut mettre à jour le bulletin de travail et les indicateurs internes.
3. **Diffusée :** le professeur clique sur DIFFUSER pour la session d'évaluation ; les notes deviennent visibles aux parents concernés et alimentent les rangs provisoires parentaux.
4. **Bulletin provisoire :** les moyennes, appréciations et indicateurs évoluent avec les évaluations diffusées.
5. **Conseil de classe / contrôle :** les résultats sont examinés selon le circuit pédagogique de l'établissement.
6. **Clôturé et publié :** la direction autorisée valide le bulletin officiel de la période.
7. **Rectifié :** toute correction postérieure est ajoutée sous forme d'événement rectificatif et n'efface pas l'historique.

Une note validée mais non diffusée peut alimenter les vues pédagogiques internes réservées aux personnels habilités, mais ne déclenche pas la publication parentale. Les notes non corrigées, non validées ou non diffusées ne sont pas considérées comme des résultats publiés.

Les bulletins provisoires portent clairement la mention « provisoire » et la date/heure de mise à jour. Les notes manquantes, absences, dispenses, évaluations neutralisées et rattrapages ne sont jamais assimilés automatiquement à un zéro.

Le calcul des moyennes utilise des règles versionnées : pondération, coefficients, arrondis, matières facultatives, absence, dispense, note neutralisée, rattrapage et changement de barème. Toute modification des règles recalcule les résultats avec trace et justification.

## 47.2 ACADEMIC RADAR — rang de l'enfant avant le bulletin

🔒 **Le parent peut interroger à tout moment le classement de son enfant avant la remise du bulletin.** Le rang affiché change au fur et à mesure que les enseignants diffusent de nouvelles évaluations.

À chaque diffusion d'une évaluation :
- le résultat validé rejoint le corpus de résultats publiés ;
- le moteur recalcule moyennes, indicateurs et cohortes pertinentes ;
- les rangs provisoires concernés sont actualisés ;
- l'application parent reçoit un événement de mise à jour ;
- le parent peut voir le nouveau rang sans attendre le bulletin de fin de période.

La fiche de rang parentale affiche :
- rang provisoire de l'enfant ;
- matière et classe/niveau ;
- taille de la cohorte de comparaison ;
- période sélectionnée ;
- nombre d'évaluations et matières prises en compte ;
- taux de couverture des données publiées ;
- percentile si pertinent ;
- évolution du rang depuis la précédente actualisation ;
- date et heure du calcul ;
- avertissement de caractère provisoire et de dépendance aux notes publiées.

Le système ne doit pas suggérer une précision supérieure à la couverture réelle. Si seulement une matière ou un petit nombre d'évaluations est disponible, le rang est marqué « partiel / précoce ». Il ne doit pas être présenté comme un verdict sur la valeur ou les capacités de l'enfant.

### 47.2.1 Règles de comparabilité

Le rang par matière est calculé dans une cohorte comparable : même établissement, même section, même niveau, même matière, même période et mêmes règles de notation, par défaut.

Le rang par classe est calculé uniquement sur les élèves de la classe et selon les règles communes à la classe.

Les comparaisons entre niveaux, séries, écoles ou groupes sont autorisées uniquement lorsque le programme, les barèmes et les évaluations sont comparables ou qu'une normalisation méthodologiquement documentée est disponible. Une moyenne brute de 6e et de 3e ne doit pas être utilisée comme si les deux niveaux étaient identiques.

Les filtres nominatifs de la direction sont limités au périmètre de l'utilisateur. Les parents ne voient jamais les noms, photos ou notes détaillées des camarades. Les classements nominatifs publics d'enfants sont interdits. Les égalités de rang suivent une règle constante et documentée.

### 47.2.2 Notifications

Les nouvelles notes sont notifiées après diffusion par le professeur. Les changements de rang peuvent être regroupés pour éviter une notification à chaque recalcul, mais le rang consultable est actualisé immédiatement après synchronisation. Une notification ne révèle pas de notes sur un écran verrouillé.

## 47.3 Licence unique établissement — modèle final

🔒 Le modèle établissement est une **licence unique par élève actif**, avec tarif progressif marginal :
- 60 FCFA par élève pour les 1 000 premiers ;
- 50 FCFA par élève du 1 001e au 5 000e ;
- 40 FCFA par élève à partir du 5 001e.

Minimum de facturation : 15 000 FCFA par mois pour un établissement indépendant. Le minimum ne s'applique qu'une fois à un groupe scolaire sous contrat consolidé.

La facturation court sur 12 mois. Tous les modules logiciels inclus dans le cahier sont compris, notamment administration, finance, RH, Teacher Space, SMART GRADING, bulletins, ACADEMIC RADAR, Family ACCESS, Community, Knowledge, School Finder, Opportunities et modules logiciels NAXA SECURITY.

Aucun supplément de licence n'est facturé par enseignant, par personnel, par compte ou par module. Les coûts tiers spécifiques — équipement, GPS, caméra, matériel, installation, SIM/données, connectivité, intervention et stockage/calcul vidéo exceptionnel — sont séparés, affichés et contractuellement approuvés avant consommation.

### 47.3.1 Calcul des tranches

Les tranches sont marginales et progressives. Exemple à 2 500 élèves :
- 1 000 × 60 = 60 000 FCFA ;
- 1 500 × 50 = 75 000 FCFA ;
- total mensuel = 135 000 FCFA.

Exemple à 10 000 élèves :
- 1 000 × 60 = 60 000 FCFA ;
- 4 000 × 50 = 200 000 FCFA ;
- 5 000 × 40 = 200 000 FCFA ;
- total mensuel = 460 000 FCFA.

Le minimum de 15 000 FCFA s'applique si le montant calculé est inférieur, à l'échelle de l'établissement indépendant ou du groupe consolidé.

### 47.3.2 Multi-écoles

Pour un groupe, le nombre d'élèves actifs des écoles de l'organisation est cumulé. Les tranches marginales s'appliquent à l'effectif cumulé. Une facture consolidée peut être produite avec ventilation analytique par école.

Un élève ne peut être compté qu'une seule fois au même instant de facturation dans une même organisation. Les règles de mouvements d'effectif, double inscription temporaire, changement d'école et transfert doivent être appliquées et auditées.

## 47.4 ACCESS gratuit et PREMIUM familial

🔒 Un parent possède un compte familial unique pour suivre plusieurs enfants dans plusieurs établissements partenaires. ACCESS est gratuit ; PREMIUM est facultatif, tarifé selon le nombre d'enfants distincts gérés.

### 47.4.1 ACCESS gratuit

ACCESS comprend sans paiement :
- sécurité, arrivée, sortie et retrait autorisé ;
- alertes de présence et de changement important ;
- suivi du bus lorsqu'il est disponible et que l'enfant est enregistré à bord ;
- absences et changements de cours ;
- programme du jour et statut du professeur/remplaçant confirmé ;
- capsules de préparation publiées ;
- notes diffusées, rang provisoire de l'enfant et bulletins ;
- convocations, rendez-vous et communications officielles ;
- consultation des frais et reçus ;
- COMMUNITY des établissements fréquentés ;
- livret scolaire unique et demande de transfert ;
- ressources KNOWLEDGE libres ou autorisées ;
- informations de cantine.

Aucune fonction essentielle de sécurité, aucune alerte arrivée/sortie, aucun accès aux notes diffusées, au rang de son enfant ou au bulletin ne peut être bloqué par défaut derrière Premium.

### 47.4.2 PREMIUM familial

| Enfants distincts dans le compte | Mensuel (9 mois scolaires) | Annuel (7 mensualités) |
|---:|---:|---:|
| 1 | 600 FCFA | 4 200 FCFA |
| 2 | 900 FCFA | 6 300 FCFA |
| 3 | 1 150 FCFA | 8 050 FCFA |
| 4 | 1 350 FCFA | 9 450 FCFA |
| 5 | 1 550 FCFA | 10 850 FCFA |
| 6 et plus | 1 550 + 200 FCFA par enfant au-delà du 5e | Mensuel × 7 |

L'abonnement est attaché au compte familial et à ses enfants vérifiés, et non à un établissement. Deux enfants dans deux écoles partenaires constituent un seul abonnement familial de deux enfants. Le même enfant n'est pas recompté lors d'un changement d'école.

Premium comprend assistant IA familial, résumés écrits et audio, analyses avancées, parcours de révision et exercices recommandés, calendrier familial consolidé, détection de conflits d'agenda, recommandations de ressources, historique comparatif avancé et préparation assistée de rendez-vous.

L'abonnement n'étend jamais les droits de garde ni les droits d'accès. Le payeur n'acquiert pas automatiquement un droit légal sur tous les enfants ; les responsables doivent être vérifiés selon les règles relatives à la famille.

## 47.5 LEARNING CONTINUITY — continuité pédagogique et rattrapage des cours

🔒 Le système compare le cours prévu au cours réellement dispensé et suit chaque cours manqué jusqu'à sa récupération ou une décision documentée.

Pour chaque séance, le registre conserve :
- cours prévu, matière, classe, date et heure ;
- enseignant initialement affecté ;
- statut de présence de l'enseignant ;
- remplacement éventuel ;
- cours réellement dispensé ;
- activité alternative encadrée ;
- heure réelle de début et fin si confirmée ;
- progression du programme ;
- devoir ou travail associé ;
- statut : dispensé, partiellement dispensé, remplacé, reporté, annulé ou à rattraper.

Toute séance non dispensée crée une action de rattrapage avec matière, durée, responsable, date proposée et statut. Le censeur suit les heures à récupérer. Les heures ne sont considérées comme rattrapées qu'après confirmation du cours réellement tenu.

Le parent voit le programme prévu, le professeur prévu, le statut d'absence confirmé, le remplaçant et l'activité réellement organisée. Le motif personnel d'une absence n'est pas communiqué.

## 47.6 SKILL PASSPORT — passeport de compétences

🔒 Le livret unique est complété par un passeport de compétences longitudinal. Il conserve :
- compétences par domaine ;
- niveau ou palier évalué ;
- date et contexte ;
- enseignant ou organisme validateur ;
- preuve ou réalisation ;
- établissement émetteur ;
- statut : déclaré, observé, évalué, attesté ou certifié.

Le système distingue les compétences évaluées dans un établissement, les réalisations déclarées par l'élève, les compétences attestées par un tiers et les certifications officielles. Le passeport ne remplace pas les diplômes, certificats ou titres réglementaires.

Il suit l'élève au transfert, dans la limite des règles de portabilité, de consentement et de conservation définies pour le livret scolaire.

## 47.7 LEARNING RECOVERY — remédiation pédagogique

🔒 Le système analyse les résultats et évaluations de compétences afin d'identifier les notions à renforcer, sans produire de profil psychologique ou de score de dangerosité de l'élève.

Il peut recommander :
- chapitres à reprendre ;
- exercices de remédiation ;
- ressources KNOWLEDGE adaptées ;
- séances de soutien ou tutorat ;
- nouvelle évaluation courte ;
- suivi de progression.

Les recommandations sont présentées à l'enseignant ou au responsable pédagogique pour validation. Le parent reçoit les objectifs et ressources autorisés. L'IA ne décide jamais qu'un élève est incapable, ne le stigmatise pas et ne déclenche pas automatiquement de sanction ou de changement de filière.

## 47.8 FAMILY COMMAND CENTER — tableau de bord familial multi-écoles

🔒 Un écran familial consolide les informations des enfants rattachés :
- emploi du temps et cours actuels ;
- arrivées, sorties et bus ;
- devoirs, évaluations et résultats ;
- changements de cours ;
- rendez-vous, réunions, convocations et visioconférences ;
- événements et visites ;
- cantine et menus ;
- paiements et échéances ;
- alertes et tâches familiales.

Le moteur repère les conflits (deux réunions simultanées, rendez-vous de deux écoles, chevauchement d'activités ou récupération impossible) et propose des rappels ou solutions. Il ne modifie jamais un rendez-vous sans accord du parent.

Chaque enfant conserve son contexte d'école et ses droits. Les agrégations ne fusionnent pas les données pédagogiques ou financières de différentes écoles dans une seule comptabilité.

## 47.9 SAFE REUNIFICATION — continuité de prise en charge

🔒 Le dispositif complète le scan du badge au portail :
1. élève enregistré à l'arrivée ;
2. élève affecté au trajet et au bus ;
3. montée dans le véhicule confirmée par scan ou agent autorisé ;
4. trajet suivi par GPS du véhicule si compatible ;
5. arrivée à l'arrêt ou à l'école confirmée ;
6. descente enregistrée ;
7. remise à un responsable autorisé si la procédure l'exige.

Le système détecte les ruptures ou incohérences d'événements et signale un état à vérifier. Le GPS localise le véhicule, pas le corps, le téléphone ou le badge de l'enfant. Les événements de prise en charge sont distincts de la géolocalisation.

En cas d'urgence, le personnel autorisé peut activer un mode de rassemblement et recenser les élèves avec statut confirmé, absent ou inconnu. L'outil assiste les équipes ; il ne garantit pas la sécurité physique.

## 47.10 GPS DES BUS SCOLAIRES — intégration NAXA SECURITY

🔒 Les bus équipés d'un dispositif GPS compatible peuvent être connectés à CAMPUS237 via NAXA SECURITY. Les parents autorisés peuvent suivre sur une carte la position du bus pendant le trajet actif où leur enfant est enregistré comme étant à bord.

Fonctions :
- connexion du GPS ou fournisseur télématique compatible ;
- association du véhicule, conducteur, accompagnateur, trajet et arrêts ;
- affichage de la position du bus et de l'heure de dernière mise à jour ;
- estimation d'arrivée au prochain arrêt et à l'école ou au point de retour ;
- zones géographiques virtuelles autour des arrêts, de l'école et des points autorisés ;
- notification de proximité ou d'arrivée selon le paramétrage ;
- événement de montée et de descente confirmé par scan de badge ou agent ;
- historique de trajet limité aux finalités définies ;
- alertes de sortie de parcours, arrêt prolongé ou anomalie GPS selon règles validées ;
- écran parent restreint au bus et trajet de son enfant.

La carte montre la position du véhicule, jamais une position GPS individuelle de l'enfant. Le parent ne suit le bus en temps réel que si son enfant est inscrit sur ce trajet et, pour le suivi pendant le trajet, enregistré comme monté. Les positions en dehors d'un trajet actif ne sont pas diffusées aux parents.

L'accès parent est fermé à la fin du trajet ou après le débarquement confirmé, sauf affichage d'information d'arrivée nécessaire. Les parents ne voient ni l'historique d'autres enfants ni les trajets privés du véhicule.

Si le réseau ou le GPS tombe, la carte indique clairement « dernière position connue », la date/heure et l'ancienneté. Le système ne prétend pas être en temps réel sur une position périmée.

La connexion nécessite compatibilité du GPS, autorisation de la flotte, information des familles et du personnel, base juridique, contrat du fournisseur, minimisation et durées de conservation. Les SIM, données et équipements tiers peuvent être facturés séparément s'ils ne sont pas fournis par l'établissement.

## 47.11 CANTINE — menu publié la veille dans COMMUNITY

🔒 Le menu de la cantine du lendemain doit être diffusé la veille dans le forum / fil officiel COMMUNITY de l'établissement afin que le parent sache ce que son enfant mangera le jour suivant.

Le responsable cantine prépare et valide le menu daté. Le système publie automatiquement ou programme la publication la veille, à l'heure configurée par l'établissement. Le post est identifié comme communication officielle et épinglé ou facilement accessible.

Le menu présente, selon les données disponibles :
- date du repas ;
- petit-déjeuner, déjeuner, goûter ou dîner selon service ;
- plats et accompagnements ;
- boissons et collations ;
- options ou substitutions ;
- allergènes connus ;
- éventuelles ruptures ou changements ;
- mention provisoire si le menu n'a pas été validé.

Les parents des élèves concernés reçoivent une notification dans CAMPUS237 FAMILY. Toute modification de dernière minute génère une nouvelle version et une notification de mise à jour.

Les informations individuelles sur allergies, diagnostics ou régimes médicaux ne sont jamais publiées dans le forum général. Les alertes individuelles liées aux ingrédients sont envoyées uniquement aux tuteurs autorisés et au personnel de cantine habilité, sur la base des informations nécessaires.

## 47.12 SCHOOL TRANSPARENCY — projets et reddition de comptes

🔒 L'établissement et l'APE peuvent publier un tableau de transparence sur les projets scolaires, travaux, activités, objectifs, contributions associatives, dépenses agrégées autorisées, réalisations et états d'avancement.

Chaque projet présente intitulé, objectif, responsable, calendrier, budget prévisionnel ou enveloppe autorisée, ressources ou contributions reçues, avancement, preuves de réalisation et compte rendu final.

Les informations publiées sont approuvées par les responsables habilités. Les salaires individuels, coordonnées bancaires, informations familiales et dépenses confidentielles ne sont pas exposés. Les contributions APE restent séparées des paiements de scolarité et des revenus de licence.

## 47.13 SCHOOL INTELLIGENCE — assistant de pilotage décisionnel

🔒 Le promoteur et les directions peuvent interroger le système en langage naturel. Exemples :
- « Quel établissement a la meilleure moyenne de mathématiques en 3e ce trimestre ? »
- « Quelles classes ont le plus de cours non rattrapés ? »
- « Quels enseignants n'ont pas encore diffusé les notes attendues ? »
- « Quelle matière progresse le plus ? »
- « Quel est le taux d'arrivée à l'heure par école ? »
- « Quels incidents restent sans responsable ou sans clôture ? »

Chaque réponse comprend la période, le périmètre, les filtres, les données sources, l'heure de calcul et la définition de l'indicateur. L'assistant respecte les permissions, n'invente pas de chiffres et peut répondre qu'il manque des données. Les données personnelles sont minimisées dans les réponses transversales.

## 47.14 Modèle de données complémentaire

Les entités conceptuelles à intégrer au dictionnaire de données :
- live_report_snapshots, report_card_states, published_assessment_coverage ;
- academic_rankings, ranking_snapshots, ranking_cohort_definitions, ranking_publications, ranking_change_events ;
- learning_competencies, skill_evidence, student_competency_records, competency_validations ;
- learning_gap_indicators, remediation_recommendations, remediation_assignments, remediation_assessments ;
- family_calendar_events, family_schedule_conflicts, family_digest_snapshots ;
- lesson_recovery_tasks, lesson_recovery_events, planned_vs_delivered_lessons ;
- vehicle_gps_devices, vehicle_gps_positions, bus_trip_sessions, bus_geofences, bus_eta_snapshots ;
- student_boarding_events, student_alighting_events, safe_reunification_events ;
- canteen_menu_versions, canteen_menu_publications, canteen_menu_changes ;
- school_transparency_projects, school_transparency_updates, school_transparency_documents ;
- school_intelligence_queries, school_intelligence_results, intelligence_data_sources ;
- school_subscription_snapshots, active_student_counts, family_premium_subscriptions, family_subscription_children, subscription_billing_events.

Les noms sont conceptuels, pas une migration SQL déjà appliquée.

## 47.15 Critères de recette V3.0.2

### Bulletin vivant et ACADEMIC RADAR
1. Après validation, les notes alimentent le calcul pédagogique selon leurs statuts.
2. Après DIFFUSER, le rang provisoire est recalculé sans attendre le bulletin officiel.
3. Le parent peut consulter le rang de son enfant avant la remise du bulletin.
4. L'arrivée d'une nouvelle note diffusée peut faire évoluer le rang et la tendance.
5. Le parent ne peut jamais afficher les notes ou noms de ses camarades.
6. Les rangs affichent période, périmètre, couverture, date de calcul et statut provisoire.
7. Une comparaison non comparable entre niveaux est bloquée ou clairement normalisée.
8. Les ex æquo suivent une règle documentée.
9. Un bulletin officiel demeure distinct du rang provisoire.

### Licence établissement et PREMIUM
10. La facture établissement applique les tranches marginales 60/50/40.
11. Le minimum de 15 000 FCFA est appliqué une seule fois à une école indépendante ou un groupe consolidé.
12. Les modules et comptes du personnel ne génèrent aucun supplément de licence par siège ou module.
13. Le calcul de groupe cumule les élèves actifs et ne compte pas deux fois le même élève dans l'organisation.
14. Deux enfants dans deux écoles produisent un seul Premium familial de deux enfants.
15. Les paliers 1 à 5 enfants et la formule 6+ donnent les montants exacts du chapitre 23.3.
16. Le prix annuel correspond exactement à sept mensualités.
17. ACCESS donne accès aux fonctions essentielles sans paiement Premium.
18. Le statut de payeur n'accorde pas de droits parentaux supplémentaires.

### Learning Continuity et Family Command Center
19. Toute séance non dispensée crée une tâche de rattrapage.
20. La tâche n'est clôturée qu'après cours réalisé ou décision documentée.
21. Le parent voit cours prévu, cours réel, remplacement confirmé et heure de mise à jour.
22. Le calendrier familial regroupe les enfants de plusieurs écoles.
23. Les conflits sont détectés sans déplacer automatiquement les rendez-vous.

### GPS bus et Safe Reunification
24. Un parent ne voit que le bus affecté à son enfant et les trajets autorisés.
25. Le suivi en cours de route s'active après l'enregistrement de la montée.
26. Le parent voit une position fraîche ou un horodatage de dernière position, jamais une fausse position temps réel.
27. Le GPS est celui du véhicule, pas celui de l'enfant.
28. La position parentale cesse d'être accessible à la fin du trajet selon la politique.
29. Les montées et descentes sont horodatées et rattachées au trajet.
30. Les alertes de zone et retards sont testées avec perte de réseau et GPS.
31. L'absence de réseau affiche clairement l'état dégradé.

### Menu de cantine
32. Le menu du lendemain est publié la veille sur le fil officiel COMMUNITY.
33. Les parents concernés reçoivent la notification.
34. Une modification du menu crée une nouvelle version et une alerte.
35. Les données médicales individuelles ne sont jamais publiées dans le forum.

### Intelligence et transparence
36. Learning Recovery propose une remédiation sans diagnostic ni décision automatique.
37. Skill Passport conserve la provenance et le statut de chaque compétence.
38. School Transparency n'expose que les indicateurs et pièces autorisés.
39. School Intelligence cite le périmètre, les filtres, les sources et l'heure de calcul.
40. Les réponses de l'assistant ne dépassent jamais les droits de l'utilisateur.

## 47.16 Arbitrages résiduels après gel

Les arbitrages A-001, A-003 et A-004 sont clôturés par les décisions V3.0.2.

Restent ouverts :
- A-002 : instantané des effectifs, mouvements, date et prorata ;
- A-005 : maintien ou adaptation du partage 80/20 du Premium vers le fonds de l'école après introduction de l'abonnement école ;
- A-006 : ventilation éventuelle d'un fonds entre plusieurs écoles ;
- A-007 : confirmation de la période d'essai Premium de deux semaines ;
- A-008 : taux/commissions d'affiliation ;
- A-009 : tarifs Opportunities ;
- A-012 à A-030 : intégrations, conformité, fournisseurs, coûts et paramètres listés au chapitre 34 ;
- A-031 : fournisseurs GPS compatibles, fréquence de position, précision, coûts SIM/data et durées de conservation ;
- A-032 : heure exacte de publication du menu la veille, définie par établissement ;
- A-033 : méthode et seuils de comparabilité des classements inter-établissements ;
- A-034 : règle de départage des ex æquo, seuils de couverture et fréquence de recalcul/actualisation des rangs ;
- A-035 : limites d'usage, quotas et coûts des services IA à forte consommation.

Ces arbitrages ne remettent pas en cause les décisions métier gelées ; ils précisent des paramètres d'exécution ou les gates de conformité.

**Fin de l'addendum CAMPUS237 V3.0.2.**
