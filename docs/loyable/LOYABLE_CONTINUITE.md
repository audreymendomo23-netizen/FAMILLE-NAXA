# LOYABLE — Document de continuité produit et technique

> Version : 1.1  
> Date de mise à jour : 21 novembre 2026 — addendum Centre de maintenance et interconnexion  
> Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA`  
> Branche documentaire : `main`  
> Statut : continuité produit consolidée — cahier détaillé du Centre de maintenance créé ; intégration non implémentée  
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

### 5.3 Catégories compatibles retenues pour LOYABLE [V]

La décision du 21 novembre 2026 limite les catégories du registre de prestataires LOYABLE aux deux activités suivantes du catalogue NAXA SERVICES :

- **Réparation** : la référence métier du catalogue couvre les téléphones, l'électronique et l'électroménager. Les sous-spécialités fines seront déclarées par chaque organisation et vérifiées séparément.
- **Menuiserie** : la référence métier couvre notamment les portes, fenêtres, meubles et installations. Les sous-spécialités fines seront déclarées et vérifiées séparément.

Le catalogue complet des 13 activités demeure inchangé dans NAXA SERVICES. Cette restriction concerne uniquement le filtre de compatibilité du Centre de maintenance LOYABLE. Elle ne supprime ni ne masque les autres activités dans NAXA SERVICES.

Ne sont donc pas des catégories de prestataires intégrées à LOYABLE V1 : Pressing, Coiffure, Couture, Beauté, Parfumerie, Garage, Nettoyage, Domicile, Imprimerie, Photographie et Autre. Les métiers plomberie, électricité, climatisation, serrurerie et maçonnerie ne sont pas ajoutés par déduction à la présente intégration ; ils demanderaient un arbitrage distinct.

Les sous-spécialités Réparation/Menuiserie, les pièces justificatives, l'état de vérification et les collaborateurs habilités restent à inventorier. L'activité principale sélectionnée par le Promoteur ne constitue pas à elle seule une preuve de compétence.

### 5.4 Profil professionnel enrichi dans NAXA SERVICES [P]

Pour exploiter le réseau sans construire un deuxième annuaire, chaque organisation NAXA SERVICES doit pouvoir renseigner un profil professionnel structuré comportant :

- activité principale choisie par le Promoteur ;
- catégorie LOYABLE compatible, limitée à Réparation ou Menuiserie ;
- sous-spécialités déclarées et spécialités vérifiées, distinguées ;
- prestations réellement proposées, prix indicatifs et durées éventuelles ;
- zones d'intervention ;
- horaires, disponibilités, périodes d'indisponibilité et capacité ;
- collaborateurs habilités à recevoir ou exécuter les missions ;
- moyens de contact professionnels ;
- justificatifs/qualifications lorsqu'ils existent ;
- statut actif, temporairement indisponible, suspendu ou à vérifier ;
- date et origine de la dernière mise à jour.

Le profil distingue obligatoirement activité déclarée, compétence déclarée, compétence vérifiée, collaborateur habilité et disponibilité confirmée. Un contrôle d'identité de l'organisation ne vaut pas validation technique d'une spécialité.

L'orientation fonctionnelle de ce profil est retenue pour la conception ; son ajout au modèle de données et aux écrans NAXA SERVICES demeure à spécifier et à développer. Aucun de ces champs ne doit être présenté comme déjà disponible en production.

### 5.5 Intégration du workflow entre applications [P]

- LOYABLE crée une demande et un ordre de travail référencés.
- Le bailleur choisit explicitement un concierge ou un prestataire compatible Réparation/Menuiserie.
- NAXA SERVICES reçoit un ordre externe distinct des rendez-vous clients et tickets pressing.
- Le Promoteur ou le collaborateur habilité accepte/refuse, propose un créneau, rédige le devis et met à jour les étapes dans NAXA SERVICES.
- Les décisions, devis, statuts, preuves et dépenses utiles reviennent à LOYABLE par API/événements versionnés.
- Le bailleur approuve le devis, les avenants et les dépenses selon ses droits ; il contrôle le résultat et clôture dans LOYABLE.
- Le locataire ne voit que les étapes et le compte rendu qui lui sont destinés.
- Les deux applications conservent leurs journaux d'audit et des identifiants corrélés.
- Les événements sont idempotents, signés côté serveur, rejouables et contrôlés par organisation/site/mission.
- Le partage des coordonnées du locataire et de l'adresse précise du logement est minimal, justifié et limité à la mission.
- Aucun SSO, aucune fusion de compte et aucun accès global du prestataire au portefeuille immobilier.

### 5.6 État réel des composants NAXA SERVICES et limites techniques [C]

Le rapport de construction consulté sur la branche de travail NAXA SERVICES confirme plusieurs fondations Android locales réutilisables :

- authentification interne, sessions et gestion des accès ;
- organisations avec modèles solo, multi-postes sur un site et réseau multi-sites ;
- séparation locale des données par organisation/site ;
- catalogue de prestations et prestataires ;
- agenda/rendez-vous avec contrôle local des conflits de site, poste et prestataire ;
- équipe, clients/CRM, stocks/consommables, caisse, dépenses et rapports locaux ;
- tickets pressing avec statuts et historique ;
- écrans d'organisation, accès, assistance et paramètres.

Le rapport précise aussi que l'outbox locale n'est pas à elle seule un moteur de synchronisation. Les addenda les plus récents documentent une synchronisation manuelle partielle pour certains flux fournisseur, un contrat commun plus large et des drafts de services serveur ; ils ne démontrent pas une réplication complète de tous les domaines, un workflow de maintenance LOYABLE ou une API inter-applications déjà en service.

Les workflows de devis, d'ordre de travail immobilier externe, d'approbation bailleur, de transmission de photos vers LOYABLE, d'accusés de réception inter-applications et de clôture coordonnée restent à concevoir, développer et tester. La simple présence d'un écran, d'une entité locale ou d'un contrat draft ne prouve pas que le flux est opérationnel.

Le rapport NAXA SERVICES consulté se trouve sur la branche de travail work/naxa-services-completion-20261120. Son contenu n'est pas une preuve que l'ensemble de ces évolutions a été fusionné dans main ni déployé en production.

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

- Quatre espaces LOYABLE : Gestion, Locataire, Immobilier et Publication NAXA.
- Centre de maintenance dans l'espace locataire, piloté depuis l'espace bailleur.
- États des lieux exclus du périmètre retenu.
- QR du site + identifiant locataire + lien personnel transmis par WhatsApp ; pas de vérification OTP supplémentaire dans le parcours locataire retenu.
- Paiements locatifs déclarés avec preuve, confirmation humaine du bailleur, reçu par règlement confirmé et quittance lorsque la période exigible est entièrement réglée.
- Publications partenaires gratuites ; publications externes assistées par NAXA selon les règles tarifaires décrites dans la continuité.
- NAXA SERVICES constitue le réseau métier à étudier pour les interventions.
- **Seules les catégories Réparation et Menuiserie du catalogue NAXA SERVICES sont retenues comme catégories compatibles du registre LOYABLE V1.**
- Les autres activités de NAXA SERVICES restent dans son propre catalogue et ne sont pas supprimées.

### Orientation produit retenue / conception à détailler [P]

- Profil professionnel NAXA SERVICES enrichi : spécialités, prestations, zones, disponibilité, capacité, collaborateurs habilités et statut.
- Recherche des prestataires selon catégorie, spécialité, zone, disponibilité, capacité et statut.
- Ordre de travail distinct des tickets et rendez-vous habituels NAXA SERVICES.
- Acceptation/refus, planification, diagnostic, devis versionné, approbation bailleur, exécution, justificatifs, reprise et clôture.
- API événementielle idempotente, journal de transitions, accusés serveur et transmission minimale des données.
- Historique privé de qualité des interventions, visible selon les droits du bailleur.
- Utilisation des patterns JOBLY de profil/KYC/QR/attribution uniquement après adaptation ; aucune réutilisation automatique du domaine commercial Partner.

### Points ouverts [O]

1. Quelles sous-spécialités Réparation et Menuiserie sont réellement proposées et vérifiables dans le réseau existant ?
2. Quels critères et justificatifs servent à distinguer spécialité déclarée et spécialité vérifiée ?
3. Quels seuils de dépense le concierge peut-il engager sans approbation préalable ?
4. Quel délai de réponse, délai d'intervention et traitement des urgences doivent être affichés ?
5. Comment partager les coordonnées du locataire et l'adresse précise du logement, et à quel moment ?
6. Quelle durée de conservation appliquer aux photos, vidéos et pièces justificatives ?
7. Le locataire peut-il évaluer l'intervention ; cette évaluation reste-t-elle privée ?
8. Quels faits composent l'historique de qualité du prestataire ?
9. Quelles règles juridiques/contractuelles régissent une éventuelle refacturation au locataire ?
10. Quels frais d'annulation ou de déplacement sont applicables en cas d'absence ou de refus tardif ?

## 10. Plan de réalisation proposé

1. Confirmer l'inventaire des organisations prestataires NAXA SERVICES et leur éligibilité Réparation/Menuiserie.
2. Cartographier les écrans LOYABLE du locataire, bailleur, gestionnaire et concierge.
3. Finaliser la matrice de droits, les règles de confidentialité et le modèle de données.
4. Spécifier les profils prestataires et l'ordre de travail externe dans NAXA SERVICES.
5. Écrire le contrat LOYABLE ↔ NAXA SERVICES : API, événements, identifiants, idempotence, accusés, erreurs et pièces.
6. Implémenter et tester chaque application séparément avant le parcours vertical inter-applications.
7. Réaliser une recette isolée sécurité/RLS, synchronisation, conflits, multi-appareils et droits.
8. Faire un pilote limité et documenter la recette avant toute activation de production.

Le cahier détaillé de référence est désormais : **docs/loyable/LOYABLE_CAHIER_DES_CHARGES_CENTRE_MAINTENANCE_INTERCONNEXION.md**.

## 11. Références et limites documentaires

- Cahier LOYABLE historique : 7 famille naxa/01-cahiers-des-charges/06-loyable.md.
- Prompts LOYABLE historiques : 7 famille naxa/02-prompts/06-loyable.md.
- Cahier NAXA SERVICES : 7 famille naxa/01-cahiers-des-charges/04-naxa-services.md.
- Prompts NAXA SERVICES : 7 famille naxa/02-prompts/04-naxa-services.md.
- Prompts du socle commun : 7 famille naxa/02-prompts/00-socle-commun.md.
- Rapport de construction NAXA SERVICES du 20 novembre 2026 : docs/naxa-services/NAXA_SERVICES_CONSTRUCTION_STATUS_2026-11-20.md, consulté sur la branche work/naxa-services-completion-20261120.
- Références JOBLY : Pack_Documentaire_JOBLY_2026.pdf et 00_ECOSYSTEME_JOBLY_DOCUMENT_MAITRE_V2.pdf.
- Cahier détaillé du Centre de maintenance : docs/loyable/LOYABLE_CAHIER_DES_CHARGES_CENTRE_MAINTENANCE_INTERCONNEXION.md.
- Continuité générale Famille NAXA : docs/CONTINUITE.md.

Le cahier historique LOYABLE contient des éléments désormais exclus (états des lieux) et ne couvre pas toutes les décisions ultérieures. Les décisions utilisateur du 21 novembre 2026 consignées dans cette continuité et dans le cahier détaillé prévalent pour la conception LOYABLE.

Le catalogue NAXA SERVICES de 13 activités reste propre à NAXA SERVICES. Le registre LOYABLE n'en expose que Réparation et Menuiserie. Le rapport de construction consulté indique que le parcours de sélection d'activité n'était pas retrouvé dans le code inspecté ; il doit être vérifié séparément avant d'être qualifié d'opérationnel.

Les composants NAXA et JOBLY ne sont pas présumés réutilisables techniquement : le cahier détaillé impose un audit de compatibilité, des dépendances, des permissions et des tests avant portage.

## 12. Règle de reprise

À la reprise, ne pas refaire les arbitrages déjà validés. Utiliser le cahier détaillé du Centre de maintenance comme base de conception. Commencer par l'inventaire des organisations Réparation/Menuiserie, puis le parcours vertical signalement → qualification → affectation → devis → exécution → contrôle → clôture. Garder les applications autonomes et ne modifier ni déployer les environnements Supabase ou les applications sans autorisation écrite applicable.

## 13. Addendum du 21 novembre 2026 — périmètre final de l'interconnexion

### Décision de catégorie
La restriction Réparation/Menuiserie est désormais intégrée à la continuité. Elle s'applique au registre et à la recherche des prestataires LOYABLE, pas au catalogue complet NAXA SERVICES.

### Réutilisation inter-applications
- NAXA : réutiliser uniquement les composants transverses compatibles après audit ; ne pas réutiliser les tables et données propres à la pharmacie.
- NAXA SERVICES : préserver le socle organisation/site, le catalogue, l'agenda, l'équipe et les composants locaux existants ; ajouter les ordres immobiliers comme un domaine distinct.
- JOBLY : adapter les modèles de profil, KYC, QR/code révocable, provenance, états et idempotence ; ne pas réutiliser les comptes, commissions, wallets ou règles de referral Partner.
- Aucun compte utilisateur, bail, transaction locative ou dossier professionnel n'est fusionné entre les applications.

### Statut d'intégration
Le profil prestataire enrichi, le registre filtré et le contrat API sont des orientations fonctionnelles et des exigences à construire. Le rapport NAXA SERVICES de la branche de travail ne démontre ni workflow complet d'ordre immobilier externe, ni synchronisation ERP globale, ni raccordement de production à LOYABLE.

### Livrables documentaires
- Cahier des charges détaillé : docs/loyable/LOYABLE_CAHIER_DES_CHARGES_CENTRE_MAINTENANCE_INTERCONNEXION.md.
- Présente continuité mise à jour : docs/loyable/LOYABLE_CONTINUITE.md.
- Continuité générale à référencer : docs/CONTINUITE.md.

**État de fin de cette mise à jour documentaire : les catégories Réparation et Menuiserie sont intégrées au référentiel ; le cahier de conception est créé ; aucune fonctionnalité LOYABLE/NAXA SERVICES n'est déclarée intégrée, déployée ou testée par ces documents.**
