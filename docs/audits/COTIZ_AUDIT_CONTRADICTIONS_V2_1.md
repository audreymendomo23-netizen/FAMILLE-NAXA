# COTIZ 360° — Audit documentaire, analyse par contradiction et registre des corrections
## Version 2.1 — 22 novembre 2026

**Document de référence :** [Cahier des charges COTIZ 360° V2.1](../cahiers-des-charges/COTIZ_360_V2_1.md)  
**Dépôt :** `audreymendomo23-netizen/FAMILLE-NAXA`  
**Branche contrôlée :** `main`  
**Portée :** audit documentaire du cahier V1.0 et des décisions communiquées jusqu'au 22 novembre 2026, comparés au dépôt Famille NAXA.  
**Nature :** audit de cohérence fonctionnelle et documentaire ; ce document n'est pas un audit de code, de sécurité opérationnelle ou de conformité juridique.

---

# 1. Conclusion exécutive

L'audit confirme que le cahier initial CotiZ V1.0 du 31 octobre 2026 constituait une bonne base de gestion opérationnelle des tontines : membres, parts, cotisations, tours, pénalités, séances, Mobile Money documenté, épargne, prêts, garanties, solidarité, clôture, rappels, rapports et fonctionnement hors connexion.

Il ne décrivait toutefois pas encore le produit désormais approuvé. COTIZ V2.1 devient une plateforme à six univers : identité et confiance, réseau communautaire, TMS, social, réunions audio/vidéo, IA et voix multilingue. La transformation n'est pas un simple ajout d'écrans ; elle change les états d'accès, le cycle d'intégration des organisations, la gouvernance des contenus, le modèle de revenus, la protection des données et le périmètre réglementaire.

**Résultat de l'analyse :**
- les éléments métier fondamentaux de V1 sont conservés et enrichis ;
- les hypothèses d'inscription uniquement par administration sont remplacées ;
- les anciens prix par membre et les anciens plans sont retirés de la référence ;
- le principe de non-détention des fonds est conservé et renforcé ;
- la vérification des personnes, l'agrément de l'organisateur, le partenariat d'une organisation et l'approbation d'une tontine sont séparés ;
- le statut public est réservé aux organisations/tontines autorisées et expire après 24 heures ;
- la popularité Discover, COTIZ Boost et COTIZ Trust sont indépendants ;
- les opérations sensibles demeurent documentaires/conditionnelles tant qu'une validation juridique n'est pas obtenue.

La cible fonctionnelle est suffisamment structurée pour commencer la conception technique détaillée, après clôture des points ouverts prioritaires. **La fonctionalité n'est pas réalisée ni testée à ce stade :** l'audit du dépôt a montré que `apps/cotiz` ne contient qu'un README d'orientation. Aucune preuve d'implémentation, de test de sécurité, de test de charge ou de conformité n'est présentée.

# 2. Sources contrôlées et limites

## 2.1 Sources documentaires

1. Cahier des charges original **Cahier_des_charges_05_CotiZ.pdf**, extrait de l'archive `New.zip`, version 1.0, daté du 31 octobre 2026, neuf pages.
2. Proposition COTIZ 360° et arbitrages explicitement approuvés par le porteur dans la conversation du 22 novembre 2026.
3. Compléments explicitement fournis par le porteur sur :
   - compte libre et accès non vérifié limité ;
   - KYC NAXA et coche bleue ;
   - création de tontine sous approbation NAXA ;
   - intégration des associations, GIC, groupes d'initiatives et communautés par partenariat ;
   - messagerie sociale ;
   - statuts institutionnels visibles par tous pendant 24 heures ;
   - recherche par nom, ville et proximité ;
   - vues, cartes animées des tontines populaires ;
   - appels audio et visioconférences de groupe ;
   - abonnement par groupe/effectif et COTIZ Boost.
4. Dépôt GitHub `audreymendomo23-netizen/FAMILLE-NAXA`, notamment `AGENTS.md`, `README.md`, `docs/INDEX.md`, `docs/ARCHITECTURE_CIBLE.md`, `docs/DECISIONS.md`, `apps/cotiz/README.md`, l'arborescence `docs/cahiers-des-charges` et `docs/audits`.
5. Sources officielles de réglementation énumérées dans le cahier V2.1.

## 2.2 Limites

- L'archive V1 a été examinée, mais n'est pas modifiée ni supprimée.
- Le dépôt a été contrôlé pour déterminer la présence de l'emplacement COTIZ ; il ne contient pas encore une implémentation métier auditable dans `apps/cotiz`.
- Les schémas et migrations Supabase n'ont pas été modifiés ni exécutés.
- Aucun test applicatif, test RLS, test de charge, test d'intrusion, test de paiement, test vidéo ou test linguistique n'a été exécuté dans le cadre de cet audit documentaire.
- La conformité réglementaire n'est pas certifiée. Les textes cités doivent être interprétés par un conseil spécialisé au regard du modèle final, des contrats, des flux réels et des marchés ciblés.

# 3. Matrice des contradictions et décisions de résolution

Les niveaux de gravité ci-dessous qualifient le risque si la contradiction restait non résolue :
- **Critique** : risque de fuite, de mauvaise autorisation, de flux financier illicite ou de dommage majeur.
- **Élevé** : risque de décision erronée, d'accès indu, de perte d'intégrité ou de modèle économique incohérent.
- **Moyen** : risque UX, de capacité ou de confusion commerciale.
- **Faible** : incohérence documentaire mineure.

| ID | Sujet contradictoire | Hypothèse ancienne / risque | Décision V2.1 et correction | Gravité |
|---|---|---|---|---|
| COT-A01 | Création de compte | V1 : comptes créés par l'administration seulement. Une inscription publique sans garde-fou donnerait immédiatement accès aux groupes. | Inscription individuelle libre, mais compte non vérifié limité aux statuts publics, à Discover et aux fiches publiques. Aucun accès communautaire privé. | Élevé |
| COT-A02 | Identité unique et frontières Famille | COTIZ veut un compte par personne dans plusieurs tontines, tandis que FAM-018 conserve les identités Auth distinctes par application. | Un COTIZ ID unique au sein de COTIZ, partagé entre toutes les tontines et communautés COTIZ ; pas de fusion automatique avec les comptes des autres apps NAXA Family. | Élevé |
| COT-A03 | Coche bleue vs accès public | Un compte peut être inscrit sans être vérifié ; l'accès complet est lié à la vérification. | Bleu = personne vérifiée par NAXA. Non vérifié = consultation publique uniquement ; vérifié = demande/acceptation d'adhésion selon décision du groupe. | Élevé |
| COT-A04 | KYC et données de domicile | CNI, portrait, plan et GPS peuvent aider l'identification, mais la collecte peut être excessive ou exposer un domicile. | Dossier privé, collecte finalisée, GPS ponctuel, alternative manuelle, contrôle d'accès besoin d'en connaître, rétention et proportionnalité à faire valider par juriste. | Critique |
| COT-A05 | Photo de profil vs photo KYC | Réutiliser la photo d'identité comme avatar exposerait un justificatif privé. | Photo de profil publique distincte des photos/documents de preuve KYC. | Critique |
| COT-A06 | Vérification personnelle vs agrément organisateur | Être bleu pourrait être interprété à tort comme autorisation de créer n'importe quel groupe. | Trois étapes : identité vérifiée, habilitation organisateur, approbation NAXA de chaque tontine. | Élevé |
| COT-A07 | Approbation d'une tontine vs garantie financière | Badge d'approbation pouvant être interprété comme caution NAXA. | Approbation = revue du dossier et autorisation d'usage COTIZ ; elle ne garantit ni solvabilité, ni fonds, ni comportement futur. | Critique |
| COT-A08 | Organisations auto-déclarées vs partenariat NAXA | Tout utilisateur pourrait créer une fausse association/GIC partenaire. | Les pages institutionnelles officielles sont intégrées par NAXA après vérification du représentant et convention/accord applicable. | Élevé |
| COT-A09 | Association mère vs autonomie de ses tontines | La fédération ou association pourrait voir toutes les cotisations de ses membres et sous-groupes. | Tontines autonomes ; accès parent limité aux agrégats et rapports explicitement délégués. | Critique |
| COT-A10 | Visibilité publique vs admission | Une tontine publique pourrait être interprétée comme ouverte à tous sans contrôle. | Visibilité publique = découverte uniquement ; admission et accès opérationnel restent vérifiés et soumis aux règles humaines du groupe. | Élevé |
| COT-A11 | Tontines privées vs recherche | Les filtres publics risquent de révéler un groupe privé. | Visibilités distinctes : privée/non indexée, sur invitation et publique. Seules les pages publiques sont indexées. | Élevé |
| COT-A12 | Invitation vs acceptation du rôle | Le créateur pourrait affecter un rôle sensible sans accord du membre. | Invitation, adhésion et rôle sont trois consentements/états séparés ; chaque rôle doit être accepté. | Élevé |
| COT-A13 | Rôle de trésorier vs séparation des tâches | Un responsable unique pourrait initier, valider et contrôler une opération. | Permissions fines, incompatibilités et double contrôle selon seuil/règlement ; historique des mandats. | Critique |
| COT-A14 | Parts multiples vs droits de vote | Plusieurs parts pourraient attribuer automatiquement plusieurs voix. | Parts, droits financiers et droits de vote sont des paramètres distincts ; le règlement définit le système de vote. | Élevé |
| COT-A15 | Messagerie sociale vs preuve comptable | Une phrase « j'ai payé » pourrait devenir une validation de paiement. | La conversation n'est pas le ledger. La cotisation, le vote, le tirage et la remise de fonds sont confirmés dans leurs modules métier. | Critique |
| COT-A16 | Statuts personnels vs statuts institutionnels | Une logique de stories personnelles contredirait la décision de limiter les statuts aux organisations. | Pas de statut personnel. Les tontines et organisations partenaires seules peuvent publier. | Moyen |
| COT-A17 | Audience des statuts vs compte non vérifié | L'accès limité du compte non vérifié pourrait exclure les statuts publics. | Statuts institutionnels visibles par tous les utilisateurs COTIZ, y compris les non vérifiés ; les actions privées restent verrouillées. | Moyen |
| COT-A18 | Expiration 24h vs conservation de preuve | Effacer toute donnée après 24h peut empêcher le traitement de signalements ; conserver le média public indéfiniment contredit l'éphémère. | Le contenu disparaît de l'accès public à 24h ; les traces minimales de modération peuvent être conservées avec accès et durée justifiés. | Élevé |
| COT-A19 | Vues répétées vs popularité réelle | Rafraîchissements, robots ou vues répétées gonfleraient le classement. | Vues qualifiées, visiteurs uniques, déduplication, périodes 24h/7j/30j et antifraude. | Moyen |
| COT-A20 | Popularité vs réputation | Les groupes les plus vus pourraient être présentés comme les plus fiables. | Popularité Discover, COTIZ Trust et vérification d'organisation sont trois indicateurs indépendants. | Élevé |
| COT-A21 | Boost payant vs classement organique | L'achat d'une promotion pourrait manipuler le classement ou le score de confiance. | Cartes sponsorisées étiquetées ; paiement n'altère ni le classement organique ni les scores Trust. | Élevé |
| COT-A22 | Recherche de proximité vs localisation domicile | Les coordonnées GPS KYC pourraient être utilisées pour localiser publiquement l'utilisateur. | Utiliser une position de recherche explicitement autorisée et une zone approximative ; jamais partager la géolocalisation exacte du domicile. | Critique |
| COT-A23 | Visioconférence vs faible débit | Une vidéo toujours activée exclurait les membres avec petits forfaits ou réseau instable. | Audio prioritaire, vidéo adaptative, limitation de consommation, fournisseur à choisir et tester. | Moyen |
| COT-A24 | Enregistrement de réunion vs vie privée | Enregistrement par défaut ou sans information porterait atteinte aux droits des participants. | Enregistrement désactivé par défaut ; information, consentement/autorisation requise, durée et accès documentés. | Critique |
| COT-A25 | IA autonome vs décision humaine | Une IA pourrait confirmer un paiement, sanctionner, admettre ou approuver un prêt. | IA assistive ; confirmation humaine obligatoire pour toute décision ou écriture sensible. | Critique |
| COT-A26 | Toutes les langues vs disponibilité réelle | Déclarer une IA vocale multilingue complète avant tests natifs créerait une promesse fausse. | Français/anglais interface d'abord, Fulfulde priorité vocale, autres langues progressives après jeux d'essais et validation native ; repli explicite. | Moyen |
| COT-A27 | COTIZ Trust personnel vs score interne | Un score universel écraserait les contextes et règles propres à chaque tontine. | Deux scores : personnel partageable avec consentement et score interne par groupe. | Élevé |
| COT-A28 | Exemple 920/1000 vs formule définitive | L'exemple chiffré de la maquette pourrait devenir un algorithme arbitraire. | Exemple non normatif ; dimensions, poids et vieillissement des événements doivent être versionnés, expliqués et testés avant production. | Élevé |
| COT-A29 | Litige déclaré vs sanction définitive | Une plainte pourrait automatiquement pénaliser le score ou mener à une exclusion. | Une accusation n'est pas un fait ; procédure contradictoire, preuve, médiation, appel ; aucune baisse automatique en litige pendant. | Critique |
| COT-A30 | Épargne/solidarité vs collecte de fonds | Un écran de suivi pourrait dériver vers collecte ou conservation d'épargne par NAXA. | Modules documentaires prévus, mais collecte, garde, mutualisation ou restitution bloquées jusqu'à avis juridique et modèle habilité. | Critique |
| COT-A31 | Prêt interne et intérêt vs activité de crédit | La tenue du calendrier pourrait être assimilée à l'octroi ou à l'intermédiation de crédit. | Enregistrement documentaire seulement avant avis écrit ; intérêts, prêts, cautions et garanties conditionnels. | Critique |
| COT-A32 | Mobile Money/SMS vs confirmation | V1 prévoyait une lecture SMS optionnelle ; un SMS ou une capture peut être faux, dupliqué ou non rapproché. | Lecture SMS désactivée par défaut ; pas d'OTP/PIN ; partenaire autorisé/API ou contrôle manuel documenté ; états de déclaration et de confirmation séparés. | Critique |
| COT-A33 | Trésorerie affichée vs fonds détenus | Un solde applicatif pourrait être présenté comme argent gardé par COTIZ. | Solde documentaire explicitement libellé ; fonds transférés directement aux acteurs ou via prestataire habilité. | Critique |
| COT-A34 | Ancien prix 500 FCFA/membre vs groupe/effectif | Le business case portefeuille et V1/V2 antérieurs avaient des modèles différents. | Modèle groupe/effectif de la section 25 remplace l'unité 500 FCFA par membre et le forfait 500/1 500/3 000. | Élevé |
| COT-A35 | V1 Essentiel/Pro/Réseau vs nouvelle grille | Les noms, quotas et tarifs V1 ne correspondent plus au produit social 360°. | Plans Découverte/Essentiel/Standard/Confort/Premium/Association/Fédération, selon effectif. Les anciennes formules sont historiques. | Élevé |
| COT-A36 | Annuel 15 % vs FAM-020 général | FAM-020 fixe 10 mensualités pour 12 mois ; COTIZ annonce 15 % de remise, soit 10,2 mois. | Exception COTIZ spécifique de 15 %, à enregistrer dans les décisions commerciales et dans la configuration tarifaire. | Élevé |
| COT-A37 | Compte gratuit vs offre Découverte gratuite | Un utilisateur individuel non vérifié pourrait être confondu avec un groupe gratuit de cinq membres. | Deux objets différents : compte individuel gratuit sans adhésion (public seulement) et abonnement Découverte d'une tontine approuvée jusqu'à cinq membres. | Moyen |
| COT-A38 | Expiration abonnement vs intégrité des historiques | Verrouiller tout accès détruirait la capacité d'export et les preuves. | Données conservées ; accès gestion restreint selon plan et politique, renouvellement accessible, consultation/export selon droits et obligations. | Élevé |
| COT-A39 | Offline vs confirmation | Une saisie locale pourrait être présentée comme confirmée avant synchronisation. | Les écritures offline sont en attente ; idempotence et confirmation serveur requises pour un statut confirmé. | Élevé |
| COT-A40 | Fédération vs confidentialité des groupes | La facturation centralisée pourrait ouvrir l'ensemble des données à la tête de réseau. | Contrat central et tableau agrégé autorisé, mais permissions distinctes par sous-groupe et aucun accès métier implicite. | Critique |
| COT-A41 | Réutilisation NAXA Family vs fuite inter-apps | Mutualiser les packages ou comptes pourrait créer des accès transversaux. | Réutilisation après audit uniquement ; COTIZ ID unique dans COTIZ mais identités de chaque app distinctes ; RLS serveur stricte. | Critique |
| COT-A42 | Fonctionnalité complète vs capacité/ coût | Messagerie, vidéo, statuts, IA et stockage sans limites peuvent rendre les plans non viables. | Quotas média, vidéo, stockage et IA par plan à établir par mesure ; sécurité et audit restent inclus à tous les niveaux. | Élevé |
| COT-A43 | Partenaire vérifié vs agrément légal | Badge partenaire pourrait être interprété comme validation de statut réglementaire. | Badge indique uniquement les contrôles de partenariat documentés ; il ne remplace ni agrément public ni autorisation réglementaire. | Élevé |
| COT-A44 | Publicité et adhésion vs manipulation de candidats | Les groupes pourraient payer pour contourner les critères ou imposer un score. | Boost visibilité seulement ; critères d'adhésion transparents ; décision humaine et partage du score avec consentement. | Élevé |
| COT-A45 | Appels de groupe vs preuve de présence | Être invité dans la salle ne signifie pas avoir effectivement participé. | Présence enregistrée à partir d'événements de session avec règles publiées ; invitation et participation sont distinctes. | Moyen |
| COT-A46 | Annonces dans le chat vs gouvernance officielle | Une annonce peut être confondue avec un règlement ou un procès-verbal adopté. | Publication informative dans Social ; les décisions officielles doivent être votées et archivées dans Governance. | Élevé |
| COT-A47 | Fonction de support/admin vs confidentialité privée | Un agent de support pourrait voir les messages privés et le détail financier par commodité. | Accès au support limité aux éléments fournis et autorisés ; accès privilégié temporaire et journalisé, aucune lecture globale par défaut. | Critique |
| COT-A48 | Migration documentaire vs réalisation technique | Le cahier complet pourrait être interprété comme preuve que l'application est opérationnelle. | État explicite : baseline documentaire seulement ; README seul dans apps/cotiz ; aucun code, migration, build, test ou déploiement livré. | Élevé |

# 4. Analyse par contradiction — causes racines

## 4.1 La V1 décrivait un produit fermé, V2.1 un réseau à plusieurs niveaux d'accès

La V1 était centrée sur un groupe créé et administré par des responsables. Le modèle V2.1 ouvre l'inscription, la consultation publique et la découverte, tout en maintenant une barrière d'identité vérifiée pour l'adhésion, les conversations et les engagements.

**Cause racine :** l'identité était modélisée comme un simple login, pas comme un cycle de confiance.

**Correction :** séparer visiteur inscrit, compte vérifié, organisateur agréé, responsable de groupe et organisation partenaire.

## 4.2 La V1 mélangeait plusieurs types de validation

La vérification du membre, l'approbation d'un organisateur, la reconnaissance d'une association et l'approbation de chaque tontine ne sont pas le même acte.

**Cause racine :** les statuts institutionnels n'étaient pas définis.

**Correction :** identifiants et états séparés, badges distincts, agents habilités, motifs et preuves séparés.

## 4.3 La V1 traitait la tontine comme unité unique ; V2.1 introduit une hiérarchie

Une association peut contenir plusieurs communautés et plusieurs tontines. La centralisation des rapports et abonnements ne doit pas donner un accès implicite aux finances de chaque sous-groupe.

**Cause racine :** la hiérarchie organisationnelle et les périmètres de données étaient insuffisamment spécifiés.

**Correction :** autorisations parent/enfant, agrégats délégués et données financières isolées par tontine.

## 4.4 L'expérience sociale et le TMS n'ont pas la même valeur probante

Un message vocal, une réaction ou un statut sont des moyens de communication, pas des écritures financières ou des décisions officielles.

**Cause racine :** confusion possible entre interaction sociale et opérations métier.

**Correction :** chaque objet officiel possède son module, son état, son auteur, son approbateur et son audit. Le chat peut pointer vers l'objet, mais ne le remplace pas.

## 4.5 La popularité n'est pas la confiance

Les vues sont un signal d'intérêt. Elles ne prouvent ni la fiabilité de l'organisation, ni la discipline des membres. Un Boost est une transaction publicitaire, pas un achat de réputation.

**Cause racine :** l'annuaire, la publicité et le score de discipline pourraient être présentés sur une même surface sans distinction.

**Correction :** trois surfaces distinctes : popularité organique, sponsorisé et Trust.

## 4.6 La technologie sociale accroît les coûts et les risques

La vidéo, les médias, les notifications, les messages et l'IA ont un coût variable significatif et des enjeux de sécurité/consentement.

**Cause racine :** V1 ne prévoyait qu'une messagerie/rappels légers.

**Correction :** quotas par plan, mesure des coûts, audio-first, fournisseur à sélectionner, modération et rétention maîtrisée.

## 4.7 Les services financiers ont une frontière réglementaire

Le logiciel de registre n'est pas la même activité que recevoir, conserver ou transférer des fonds, collecter de l'épargne ou accorder des crédits.

**Cause racine :** la V1 contenait des fonctions de prêt/épargne tout en indiquant qu'elles devaient être juridiquement examinées.

**Correction :** maintenir les parcours documentaires, mais verrouiller les activités financières réglementées jusqu'à un avis écrit et à l'autorisation éventuelle.

# 5. Audit de couverture de la V1 historique

| Contenu V1 | Couverture V2.1 | Décision |
|---|---|---|
| Gestion des groupes | Sections 4–5 | Conservé et élargi |
| Membres, rôles, parts | Sections 3–4 | Conservé, rôles acceptés explicitement |
| Cotisations fixes/variables/partielles/anticipées | Section 6 | Conservé, états plus précis |
| Ordre fixe et tirage | Section 7 | Étendu à cinq modes et preuve |
| Pénalités | Sections 4, 8, 13, 14 | Conservé avec recours |
| Réunions et présence | Sections 13 et 20 | Étendu aux votes, audio et vidéo |
| Mobile Money | Sections 6 et 29 | Registre/documentation ; partenaire habilité conditionnel |
| SMS/lecture de preuve | Sections 6 et 37 | Lecture automatique écartée par défaut |
| Épargne par objectifs | Section 10 | Suivi documentaire, activation conditionnelle |
| Prêts internes/intérêts | Section 11 | Documentaire, verrou juridique |
| Cautions/garanties | Section 11 | Documentaire, verrou juridique et consentement |
| Caisse de solidarité | Section 12 | Conservée, accès sensible |
| Clôture de cycles | Sections 4 et 9 | Étendue aux écarts, litiges et preuves |
| Rappels WhatsApp | Section 21 | Liens préparés ; API officielle seulement après validation |
| IA/rapports | Section 22 | Assistant métier gouverné |
| Offline/synchronisation | Section 30.4 | Conservé avec statuts explicites |
| Exports | Section 24 | Conservé, accès contrôlé |
| Administration | Section 28 | Étendue à KYC, partenaires, statuts et modération |
| Français/anglais | Section 23 | Conservé et étendu à la voix locale |
| Abonnements V1 | Section 25 | Ancienne grille retirée |
| Cycles historiques et archives | Sections 4, 9, 24 | Conservés sans effacement à expiration |

**Résultat :** aucun module métier initial majeur n'est supprimé. Les mécanismes V1 sont soit conservés, renforcés, soit placés sous condition réglementaire.

# 6. Audit des 18 domaines V2 et des nouveaux univers

| Domaine | Couverture documentaire | Contrôle de contradiction principal |
|---|---|---|
| 1. Identité et membres | Sections 3 et 29 | KYC privé, état non vérifié |
| 2. Groupes et adhésions | Sections 4 et 5 | Approbation et accès multi-groupes |
| 3. Cotisations | Section 6 | Déclaré ≠ confirmé |
| 4. Tours et tirages | Section 7 | Reproductibilité et pas de relance silencieuse |
| 5. Discipline et réputation | Section 8 | Personnel ≠ score du groupe |
| 6. Trésorerie et rapprochement | Section 9 | Solde documentaire ≠ fonds détenus |
| 7. Épargne et objectifs | Section 10 | Aucun fonds collecté par défaut |
| 8. Prêts et garanties | Section 11 | Verrou réglementaire |
| 9. Solidarité | Section 12 | Données sensibles restreintes |
| 10. Réunions et gouvernance | Section 13 | Vote officiel distinct du chat |
| 11. Communication et rappels | Sections 19 et 21 | Confidentialité, consentement |
| 12. Litiges et médiation | Section 14 | Plainte ≠ fait établi |
| 13. Annuaire | Section 15 | Public/privé/sur invitation |
| 14. Fédération | Section 5 | Autonomie financière des sous-groupes |
| 15. Abonnements et parrainage | Sections 25–26 | Groupe payeur, anti-fraude |
| 16. Rapports et comptabilité | Section 24 | Registre de gestion ≠ comptes certifiés |
| 17. IA et prévention des risques | Section 22 | IA sans pouvoir de décision autonome |
| 18. Administration et sécurité | Sections 28–29 | Need-to-know, MFA, RLS, journaux |
| Identité bleue et partenaires | Sections 3 et 5 | Trois niveaux de validation |
| Statuts 24 h | Section 16 | Émetteurs institutionnels seulement |
| Vues et cartes animées | Section 17 | Popularité séparée de Trust |
| Boost | Section 18 | Sponsorisé sans manipulation organique |
| Messagerie sociale | Section 19 | Conversation distincte du ledger |
| Audio/vidéo | Section 20 | Consentement, quota et faible débit |
| COTIZ Voix | Section 23 | Langues testées, repli explicite |

# 7. Cohérence économique vérifiée

## 7.1 Anciennes hypothèses retirées

Le business case portefeuille mentionnait 500 FCFA par membre et par mois. La V1.0 proposait également des forfaits ESSENTIEL/PRO/RÉSEAU de 500/1 500/3 000 FCFA. Ces deux logiques contredisent le modèle groupe/effectif retenu ici.

**La grille groupe/effectif prévaut** dans le cahier V2.1.

## 7.2 Tarifs contrôlés arithmétiquement

| Plan | Mensuel × 12 | Annuel annoncé | Réduction |
|---|---:|---:|---:|
| Essentiel | 12 000 | 10 200 | 15 % |
| Standard | 24 000 | 20 400 | 15 % |
| Confort | 42 000 | 35 700 | 15 % |
| Premium | 72 000 | 61 200 | 15 % |
| Association | 120 000 | 102 000 | 15 % |

Les montants annuels sont cohérents avec une remise de 15 %.

## 7.3 Contradiction avec la politique annuelle transversale

La règle famille FAM-020 prévoit 10 mensualités payées pour 12 mois de service, soit 16,67 % de remise. COTIZ prévoit 15 %.

**Résolution :** exception de produit COTIZ, à enregistrer explicitement au registre décisionnel général avant publication de la grille. Ne pas normaliser silencieusement les prix COTIZ sur 10 mensualités.

## 7.4 Distinction compte gratuit / offre gratuite

- compte individuel gratuit non vérifié : consultation publique uniquement ;
- compte individuel vérifié : adhésion et participation autorisées gratuitement au niveau du compte ;
- offre Découverte : abonnement logiciel gratuit pour une tontine approuvée de cinq membres maximum.

Ces trois états ne doivent pas être confondus dans le code, les factures ou les tableaux de bord.

# 8. Analyse de conformité à traiter avant lancement

| Sujet | Risque | Travail exigé |
|---|---|---|
| CNI, portrait et GPS domicile | Collecte excessive, fuite d'identité/localisation | Avis juridique, finalités, alternative, sécurité, conservation, procédure de droits |
| Messages, médias et appels | Atteinte à la vie privée | Politique, modération, enregistrement désactivé par défaut, rétention |
| Score de discipline | Profilage injuste, décisions opaques | Analyse d'impact, explication, correction, recours, seuils proportionnés |
| Services de paiement | Activité potentiellement réglementée | Qualification juridique du rôle COTIZ et du partenaire |
| Épargne et prêts | Activité potentiellement réglementée | Avis écrit avant activation |
| Cautions/garanties | Engagement contractuel et risque financier | Validation du rôle, consentement, validité des contrats |
| Associations/GIC | Statut des partenaires | Contrôle documentaire adapté à leur statut et conventions |
| Transfert international des données | Risque de transfert non conforme | Cartographie des fournisseurs et destinations |
| IA vocale | Voix et corpus personnels | Consentement, licences, sécurité et gestion des données vocales |

**Aucune certification légale n'est attribuée par cet audit.** Le juriste doit confirmer les textes applicables, leur version en vigueur, les éventuelles mesures d'application et la qualification exacte de chaque flux.

# 9. Priorité des points ouverts

Le cahier V2.1 identifie 24 points ouverts (O-01 à O-24). Les plus critiques à fermer avant toute mise en production sont :

1. O-01 — nécessité/proportionnalité du GPS et des documents KYC ;
2. O-02/O-03/O-04 — procédures de vérification, d'agrément et d'approbation ;
3. O-06/O-07 — formule Trust, partage et recours ;
4. O-08/O-09 — modèle de vote, règlements et droits par parts ;
5. O-10/O-11/O-12 — quotas, expiration et paiement d'abonnement ;
6. O-13/O-14/O-15 — fournisseurs média, rétention et chiffrement ;
7. O-17 — qualité par langue et consentement corpus vocal ;
8. O-18/O-19/O-20 — Boost, parrainage et quotas de contenu ;
9. avis juridique écrit sur épargne, prêts, intérêts, garanties et paiements ;
10. O-23 — objectifs de sécurité, restauration et continuité.

# 10. Audit du dépôt Famille NAXA et statut de livraison

## 10.1 Constat du dépôt

- Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA`.
- Branche de travail autorisée : `main`.
- Le chemin `apps/cotiz/README.md` existe et décrit COTIZ comme une application autonome de gestion des tontines.
- Le chemin documentaire `docs/cahiers-des-charges/` existe.
- Le chemin `docs/audits/` existe.
- Aucun cahier COTIZ V2 n'existait dans la liste consultée avant cette création.
- L'emplacement `apps/cotiz` n'a pas d'implémentation métier démontrée par le README consulté.

## 10.2 Règles du dépôt respectées dans la portée de cette livraison

- travail documentaire uniquement sur `main` ;
- aucun branchement ou PR créé ;
- aucun code applicatif modifié ;
- aucune migration SQL/Supabase créée ou exécutée ;
- aucune migration Production ;
- aucun déploiement ;
- aucune APK construite ou publiée ;
- aucun secret ou donnée personnelle réelle ajouté.

## 10.3 État de livraison

| Élément | État |
|---|---|
| Audit de la V1 documentaire | EFFECTUÉ |
| Analyse des contradictions fonctionnelles | EFFECTUÉE — 48 sujets enregistrés |
| Baseline fonctionnelle V2.1 | DOCUMENTÉE |
| Couverture des 18 domaines | VÉRIFIÉE DOCUMENTAIREMENT |
| Audit du code COTIZ | NON RÉALISABLE : implémentation absente du dossier consulté |
| Audit SQL/RLS COTIZ | NON EFFECTUÉ |
| Test Android/Web | NON EFFECTUÉ |
| Test hors connexion | NON EFFECTUÉ |
| Test sécurité/charge | NON EFFECTUÉ |
| Avis juridique formel | NON EFFECTUÉ |
| Conformité de production | NON DÉMONTRÉE |

**Statut global : DOCUMENTATION DE RÉFÉRENCE CRÉÉE ; PRÉPARATION TECHNIQUE POSSIBLE APRÈS FERMETURE DES PORTES PRIORITAIRES ; APPLICATION NON DÉCLARÉE OPÉRATIONNELLE.**

# 11. Conclusion de l'audit

Le cahier COTIZ 360° V2.1 intègre l'ensemble des familles fonctionnelles de la V1.0, les 18 domaines du cadrage 360° et les extensions approuvées par le porteur : compte libre à accès limité, KYC gratuit avec coche bleue, agrément de l'organisateur, approbation de chaque tontine, associations/GIC/communautés partenaires, postes acceptés, messagerie, statuts institutionnels de 24 heures, recherche géographique, cartes populaires animées, statistiques de vues, Boost, audio/vidéo, langues camerounaises, voix IA et monétisation par groupe/effectif.

L'analyse par contradiction a identifié et résolu les ambiguïtés qui auraient pu conduire à un produit incohérent ou risqué. Les points non résolus sont clairement étiquetés comme ouverts ou conditionnels plutôt que masqués par une décision inventée.

La prochaine étape correcte n'est pas de déclarer COTIZ terminé techniquement : c'est de fermer O-01 à O-24 par décisions, avis juridiques, mesures de coûts et audits techniques, puis de lancer J0 (audit du socle NAXA Family) et J1 (fondations identité/KYC/permissions).

---

**Fin de l'audit documentaire et contradictoire COTIZ 360° V2.1.**
