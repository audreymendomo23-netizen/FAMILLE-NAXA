# Cahier des charges — NAXA-Hotel

> Conversion fidèle du cahier des charges PDF source.
> Source : `Cahier_des_charges_07_NAXA_Hotel.pdf` · 12 pages.
> Le texte a été extrait du PDF et structuré en Markdown ; les formulations métier ne sont pas réécrites.

<!-- Page 1 -->

 Cahier des charges — NAXA Hotel
 Application n° 7 sur 7 de la famille d'applications · Version 1.0 · 31 octobre 2026 · Rang de
 construction : 7
 Issu du cahier des charges Kiosko v1.2 et de la version de référence « Gestion petit commerce »
 v2.1 ; inspiration complémentaire : NAXA.


## 0. Lecture du document
  - [V] validé par vos réponses · [P] proposé, à valider · [O] point ouvert.
  - Ce cahier des charges est autonome : il contient le socle commun de la famille (section 3) et ce qui
     est propre à l'application (sections 4 et suivantes). Les sept cahiers partagent la même architecture
     et les mêmes options (décision du 31 octobre 2026). [V]
  - Vocabulaire : « PIN » = code secret de l'opérateur, jamais demandé ni stocké ; « code d'accès » =
     code de l'application.


## 1. Présentation
 NAXA Hotel est l'outil de gestion à 360° des établissements d'hébergement : chambres et tarifs,
 réservations, accueil (arrivée et départ), compte du séjour, ménage, maintenance, restauration et bar,
 stock, équipe par poste, clients, comptabilité, pilotage et IA, du petit hôtel au groupe de plusieurs
 hôtels, y compris sans connexion. [V]

 1.1 Profils d'établissement
 Profil                              Spécificités

 Auberge, maison d'hôtes             Quelques chambres, un seul réceptionniste ou le propriétaire, tarifs simples,
                                     petit-déjeuner, saisie très rapide

 Hôtel                               Plusieurs types de chambres, réception jour et nuit, ménage organisé, restaurant et
                                     bar, maintenance, équipe par postes

 Résidence meublée, appart-hôtel     Séjours de plusieurs nuits ou semaines, tarifs dégressifs, cuisine et linge, facturation
                                     périodique

 Groupe hôtelier                     Plusieurs hôtels sous un compte mère : consolidation, comparaison, tarifs et règles
                                     communes, direction générale


 1.2 Objectifs
## 1. Savoir à tout instant quelles chambres sont libres, occupées, sales, à préparer ou hors service.
## 2. Ne jamais vendre deux fois la même chambre, même en cas de coupure de réseau.
## 3. Tenir un compte unique par séjour (chambre, restaurant, bar, extras) et un encaissement sans
     oubli.
## 4. Donner à chaque poste exactement les écrans et les droits de son travail.
## 5. Mesurer et améliorer le taux d'occupation et les revenus (prix moyen, revenu par chambre
     disponible).
## 6. Piloter plusieurs hôtels depuis un téléphone, avec le briefing du matin et du soir sur WhatsApp.

## 2. La famille d'applications : sept applications, une
 architecture



Cahier des charges — NAXA Hotel · v1.0 · 31 octobre 2026                                                               Page 1

---

<!-- Page 2 -->

 Sept applications distinctes, sept projets de développement, une seule architecture et un seul compte
 client. [V]

 N°     Application          Public                              Modules propres                             Lecture des
                                                                                                             SMS

 1      Kiosko               Agents Orange Money, MTN            M1 : floats, commissions, natures           Obligatoire
                             MoMo, Wave                          d'opérations, abonnements de toute la
                                                                 famille

 2      Bootik               Boutique, supérette,                Ventes, stock, ardoise, fournisseurs,       Facultative
                             quincaillerie, articles et          fidélité, compta, multi-boutiques,
                             vêtements, parfumerie,              catalogue
                             poissonnerie, dépôt de gaz,
                             pharmacie informelle restreinte

 3      Zipple               Bar, buvette, restaurant,           Tables et tickets, carte et recettes,       Facultative
                             maquis, braiseur de porc et de      consignes, portions et rendement
                             poulet

 4      NAXA Services        Pressing, salon de coiffure         Prestations, rendez-vous, dépôts et         Facultative
                                                                 statuts, commissions par prestataire

 5      CotiZ                Groupes de tontine, trésorières,    Cotisations, tours, pénalités, présences,   Facultative,
                             membres                             épargne, prêts, garanties                   désactivée par
                                                                                                             défaut

 6      Loyable              Propriétaires et gestionnaires de   Biens, locataires, loyers, quittances,      Facultative,
                             biens locatifs                      relances, charges, états des lieux          désactivée par
                                                                                                             défaut

 7      NAXA Hotel           Hôtels, auberges, résidences        Chambres, réservations, accueil, folio      Facultative
                             meublées, maisons d'hôtes,          du séjour, ménage, maintenance,
                             groupes hôteliers                   postes, multi-hôtels

     - Un code partagé, sept APK : un noyau commun (comptes, synchronisation, notifications,
       WhatsApp, IA locale, abonnement, sécurité) et, par application, uniquement ses modules. Chaque
       APK reste légère sur les téléphones d'entrée de gamme. [P]
     - Sept projets : sept dépôts GitHub (un par application) plus un dépôt du noyau commun, ou un seul
       dépôt à sept dossiers. Chaque projet a son propre cahier des charges, ses jalons et sa recette. [P]
     - Un seul backend Supabase partagé pour les sept (plus un projet de test) : l'offre gratuite
       n'autorise que deux projets actifs par organisation, donc sept backends séparés ne sont pas
       possibles gratuitement. Cela permet aussi un compte unique et un compte mère qui consolide
       plusieurs applications. [P]
     - Un compte pour toutes les applications : le client garde les mêmes identifiants ; l'administration
       choisit à la création de l'accès quelles applications il peut utiliser. [V]
     - Marques : NAXA est une marque distincte (système de pharmacie, NAXA Services, NAXA Hotel) ;
       Kiosko, Bootik, Zipple, CotiZ et Loyable portent leurs noms propres. Toutes les applications
       partagent la même architecture et le même compte client, quelle que soit leur marque. [V]
     - Rang de construction proposé : 1 Mobile Money (il porte le téléphone admin qui détecte les
       paiements d'abonnement de toute la famille), 2 Boutique, 3 Resto-Bar, 4 Services, 5 Bailleur, 6
       Tontine, 7 Hôtel. Cette application porte le rang n° 7. [P]


## 3. Socle commun à toutes les applications [V]
 S1. Comptes et accès
 - Accès créés uniquement par l'administration : fiche client, applications autorisées, palier,
       durée, remise ou essai éventuel ; identifiants et lien de téléchargement remis au client, mot de
       passe changé à la première connexion. Pas d'inscription libre. [V]
     - Connexion par numéro de téléphone et mot de passe (6 caractères minimum) ; à chaque ouverture,
       code d'accès à 4 chiffres ou empreinte, sur le téléphone seulement. Mot de passe oublié : par e-mail
       s'il existe, sinon demande par WhatsApp traitée par l'administration après contrôle d'identité.
     - Employés créés par le gérant ou le propriétaire, avec leur propre code d'accès ; changement
       d'utilisateur sans déconnexion ; jusqu'à 2 appareils actifs par point, notification au propriétaire pour
       tout nouvel appareil, déconnexion à distance. Blocage temporaire après 5 tentatives. Aucun code



Cahier des charges — NAXA Hotel · v1.0 · 31 octobre 2026                                                                   Page 2

---

<!-- Page 3 -->

     envoyé par SMS payant.

 S2. Hors connexion et synchronisation
 - Tout fonctionne d'abord sur la base locale du téléphone ; synchronisation par lots au retour du
     réseau, reprise automatique, identifiant unique par opération contre les doublons. Une opération
     issue d'un SMS est immuable ; les corrections s'ajoutent comme écritures nouvelles.
  - Tolérance hors connexion : 7 jours (Essentiel et Pro), 14 jours (Réseau) ; l'heure du serveur est
     mémorisée et un recul d'horloge est détecté. [P]
  - Chaque APK ne crée que les tables locales dont elle a besoin et ne synchronise que celles-ci. [P]

 S3. Lecture des SMS et solutions de secours
 - Chaîne de traitement de la v1.2 (6.4) : filtre sur l'expéditeur officiel, SMS contenant un OTP ou un
     PIN ignorés (jamais lus, stockés, transmis ni affichés), analyse par règles versionnées (table
     parser_rules mise à jour sans nouvelle APK), contrôle de cohérence des soldes, dédoublonnage, file «
     À classer ».
  - Permission SMS : obligatoire dans Kiosko, facultative dans les autres applications (confirmation
     automatique des paiements reçus) ; désactivée par défaut dans Tontine et Bailleur. [P]
  - Solutions de secours dans toutes les applications : partage d'un SMS vers l'application (sans
     permission SMS), saisie manuelle guidée, rapprochement avec le SMS réel arrivé ensuite, alerte de
     trou dans la chaîne des soldes (Mobile Money). Un SMS partagé n'active jamais un abonnement.

 S4. Notifications
 - Quatre canaux gratuits : notifications locales, push FCM, messages WhatsApp préparés, centre de
     notifications dans l'application. Aucun SMS sortant payant.
  - Canaux Android distincts (Critique, Opérations, Abonnement, Information, Coaching IA), anti-doublon
     par événement, heures calmes, textes courts dans la langue choisie, montants formatés (45 000 F).
  - Santé de l'appli : permission, paramètres restreints, batterie, dernière synchronisation ; assistant de
     configuration au premier lancement, selon la marque du téléphone.

 S5. WhatsApp et briefings
 - Messages préparés (lien wa.me) en un clic, modèles modifiables en français et en English ; aucun
     message ne contient jamais de PIN ou d'OTP. L'envoi automatique gratuit est impossible.
  - Briefing du matin (7 h) et du soir, adaptés à l'application : chiffres clés, alertes, tâches,
     échéances.

 S6. Équipe, droits et audit
 - Droits par rôle fixés par le propriétaire ; validation du patron à distance pour les actions sensibles ;
     journal d'audit (qui, quand, avant, après) ; correction ou annulation avec raison obligatoire.

 S7. Comptabilité de base et exports
 - Export des données (listing, historique en PDF simple et Excel) pour tous les paliers ; rapports PDF et
     Excel mis en forme à partir du palier Pro ; nom du point de vente et date d'export en pied de page.
  - Pour les applications de gestion : journal, compte de résultat simple, trésorerie, plan SYSCOHADA,
     TVA paramétrable, datée et par catégorie, accès comptable par lien temporaire en lecture seule
     limité à un point (inspiré de NAXA). [P]

 S8. Intelligence artificielle locale
 - L'IA propose, l'humain décide ; calculs d'abord sur le téléphone ; aucun numéro ni SMS brut envoyé
     à un service externe ; chaque suggestion explique pourquoi ; mode dégradé sans IA en ligne.
  - Fonctions communes : prévision (rupture, épuisement, échéance selon l'application), détection
     d'anomalies, coach du jour, score de santé de l'activité, relances personnalisées. Assistant « posez
     une question » écrit et vocal (français et anglais) au palier Réseau, en ligne.

 S9. Abonnement et paiements
 - Un abonnement par application (section 7). Paiement par OM ou MoMo sur le code marchand de
     l'administration ; le client saisit l'identifiant de transaction (« J'ai payé ») ; le téléphone admin, qui


Cahier des charges — NAXA Hotel · v1.0 · 31 octobre 2026                                                   Page 3

---

<!-- Page 4 -->

     exécute Kiosko en mode admin, lit le SMS et vérifie expéditeur officiel, montant exact et identifiant
     jamais utilisé ; sinon file de validation manuelle. Le téléphone admin détecte les paiements de
     toutes les applications de la famille.
  - Rapprochement sur identifiant unique, montant exact, numéro du payeur et horaire ; deuxième
     téléphone admin de secours ; accès provisoire de 24 h une seule fois par période ; journal complet.
  - Blocage après échéance : données jamais supprimées, export possible, synchronisation serveur
     refusée sauf écran de paiement ; mêmes règles de prorata, d'offres, de parrainage, de partenaires
     et de roue promotionnelle que la v1.2. [P]

 S10. Sécurité des APK et distribution
 - Signature de l'APK (keystore sauvegardé en plusieurs lieux sûrs, jamais dans un dépôt public),
     obfuscation R8, empreinte de signature vérifiée par le serveur, version minimale exigée (table
     app_versions), abonnement décidé par le serveur (RLS), identifiant de transaction unique, filigrane
     des exports (protections 14.5 de la v1.2).
  - APK direct, sans Play Store ; une page de téléchargement officielle listant les sept applications,
     avec l'empreinte de chaque APK et un guide illustré d'installation (sources inconnues, paramètres
     restreints). [P]
  - Un keystore par application ou un keystore commun : à décider avant la première publication, car sa
     perte empêche toute mise à jour. [O]

 S11. Langues et ergonomie
 - Français et English dès la première version, choix sur la première page ; mobile d'abord, gros
     boutons, écrans clés en 3 touches au plus, lisible en plein soleil, mode sombre en option, léger et
     faible consommation de données.


## 4. Modules propres à l'application
 H1. Chambres, types et tarifs [V]
 - Fiche chambre : numéro, étage, type, capacité, lits, équipements, état ; types de chambre (simple,
     double, suite, familiale…) avec photos.
  - Tarifs par type, par saison, par jour de la semaine, par durée de séjour (nuit, semaine, mois), tarif
     entreprise ou agence, tarif à l'heure ou de passage si le profil l'autorise. [P]
  - Taxes et frais paramétrables et datés : TVA, taxe de séjour, service ; petit-déjeuner inclus ou en
     option ; suppléments (lit d'appoint, climatisation, parking).

 H2. Réservations et plan d'occupation [V]
 - Calendrier d'occupation en grille chambres × jours, avec couleurs par statut ; réservation en
     quelques touches, par téléphone, WhatsApp, agence ou sur place (client sans réservation).
  - Acompte et garantie, avec paiement par mobile money confirmé automatiquement ; politique
     d'annulation réglable ; liste d'attente ; suivi des absences non annoncées (no-show).
  - Blocs de chambres pour groupes (séminaires, mariages, délégations) avec liste des participants
     ; réservation de plusieurs chambres pour un même client ; prolongation et changement de chambre.
  - Confirmation de réservation par message WhatsApp préparé (dates, tarif, acompte, conditions) en
     un clic.
  - Hors connexion : deux réceptionnistes peuvent réserver la même chambre sans réseau ; à la
     synchronisation, la première réservation enregistrée gagne, l'autre devient « à replacer » avec
     alerte au manager. Pour limiter ce risque, une réservation hors connexion est marquée « provisoire
     » jusqu'à synchronisation. [P]

 H3. Accueil : arrivée et départ [V]
 - Arrivée (check-in) : fiche d'arrivée du client, attribution de la chambre, tarif confirmé, caution ou
     avance, remise de la clé ou du badge (suivi des clés), numéro de séjour ; arrivées sans réservation
     prises en charge.
  - Pièce d'identité et registre des voyageurs : saisie des informations exigées pour la fiche ou le
     registre ; la photo de la pièce est facultative, chiffrée, à durée de conservation limitée et soumise au



Cahier des charges — NAXA Hotel · v1.0 · 31 octobre 2026                                                 Page 4

---

<!-- Page 5 -->

     consentement (section 9). [P]
  - Départ (check-out) : solde du compte en quelques touches, restitution de la clé et de la caution,
     facture finale ou reçu PDF envoyé par WhatsApp, départ tardif facturable, chambre aussitôt
     marquée « à nettoyer ».
  - Changement de chambre, prolongation, départ anticipé, client qui part sans payer (dossier d'impayé
     avec relance).

 H4. Compte du séjour (folio) et facturation [V]
 - Un compte par séjour regroupe : nuitées, petit-déjeuner, restaurant, bar, minibar, blanchisserie,
     transport, Wi‑Fi, téléphone, extras ; chaque ligne porte son poste et son auteur.
  - Imputation sur la chambre : un ticket de Zipple peut être mis sur le compte de la chambre («
     mettre sur la chambre 12 »), grâce au compte unique de la famille. [P]
  - Paiements partiels, mixtes (espèces, mobile money confirmé par SMS), avances et acomptes ;
     partage de la note entre plusieurs payeurs ; remises validées par le manager.
  - Comptes entreprise : facturation différée à une société ou une agence, relevé mensuel, relances ;
     devis, proforma et facture avec numérotation continue ; avoirs.

 H5. Ménage et gouvernante [V]
 - Statuts de chambre : libre propre, libre sale, occupée, départ prévu, hors service, contrôlée ; mise à
     jour en une touche par la femme de chambre.
  - Répartition des chambres par femme de chambre ; liste des chambres à préparer en priorité (arrivée
     proche) ; contrôle par la gouvernante ; temps de nettoyage et productivité.
  - Minibar et consommables à réapprovisionner ; objets trouvés et rendus (journal) ; suivi du linge :
     propre, sale, en blanchisserie, perdu, usé.

 H6. Maintenance [V]
 - Signalement d'une panne par chambre ou par zone (plomberie, climatisation, électricité, serrure,
     télévision, Wi‑Fi) avec photo ; priorité ; affectation à un technicien ; suivi jusqu'à la clôture.
  - Chambre mise hors service avec dates, qui la retire automatiquement de la vente ; coût des
     réparations par chambre ; maintenance préventive (groupe électrogène, citerne, climatiseurs) avec
     rappels.

 H7. Restauration et bar de l'hôtel [V]
 - Module léger intégré : petit-déjeuner, room service, minibar, boissons ; pour une carte complète, des
     recettes et des tables, l'hôtel utilise Zipple avec les mêmes identifiants, et les tickets s'imputent
     aux chambres.
  - Petit-déjeuner inclus : liste du jour des convives par chambre ; room service avec statut de
     commande.

 H8. Stock, économat et achats [V]
 - Consommables (savon, draps, serviettes, eau, boissons du minibar), lots et péremption, inventaire,
     pertes et casse, transferts entre hôtels, fournisseurs et dettes, commande par WhatsApp sous le
     seuil, facture lue par photo, valeur du stock, responsable des achats.

 H9. Postes, équipes et droits [V]
 Le propriétaire ou la direction fixe, pour chaque poste, les écrans et les actions autorisés. Postes
 prédéfinis, modifiables :

 Poste                               Écrans et droits principaux

 Propriétaire, directeur général     Tout voir, tous les hôtels, finances, objectifs, droits des postes, rapports du groupe

 Manager d'hôtel (directeur ou       Tout son hôtel : tarifs, remises, annulations, validation à distance, rapports,
 gérant)                             planning, clôture, incidents

 Chef de réception                   Réservations, arrivées et départs, planning de la réception, remises limitées, litiges,
                                     remise de poste

 Réceptionniste de jour              Réserver, enregistrer l'arrivée et le départ, encaisser, imprimer ou envoyer la
                                     facture ; pas de modification des tarifs



Cahier des charges — NAXA Hotel · v1.0 · 31 octobre 2026                                                               Page 5

---

<!-- Page 6 -->

 Poste                               Écrans et droits principaux

 Réceptionniste de nuit (audit de    Même droits que le jour, plus la clôture de nuit : contrôle des soldes et de la
 nuit)                               caisse, report du jour, rapport du matin

 Caissier, comptable                 Encaissements, comptes entreprise, dépenses, journal, TVA et taxe de séjour,
                                     exports, accès comptable ; pas de réservation

 Gouvernante générale                Statuts et contrôle des chambres, répartition du ménage, linge, minibar, objets
                                     trouvés

 Femme de chambre, valet             Ses chambres du jour, statut en une touche, signalement de panne, consommables
                                     utilisés

 Responsable maintenance,            Tickets de panne, chambres hors service, maintenance préventive, coûts
 technicien

 Responsable restauration,           Commandes, imputation sur chambre, stock de la cuisine et du bar (via module
 serveur, barman, cuisinier          léger ou Resto-Bar)

 Économe, responsable des achats     Stock, fournisseurs, commandes, réceptions, inventaire, dettes fournisseurs

 Agent de sécurité, portier,         Liste des arrivées et départs, registre des visiteurs, incidents, clés ; pas d'accès aux
 bagagiste                           finances

 Commercial, réservations de         Devis, blocs de chambres, comptes entreprise, suivi des prospects ; pas
 groupes                             d'encaissement

  - Planning et équipes : équipes de jour, de nuit et de week-end ; planning des postes ; pointage et
     présences ; remplacements.
  - Passation de poste : à chaque changement d'équipe, remise de caisse, de clés et de consignes
     avec écart signalé ; journal par réceptionniste ; écarts de caisse par employé.
  - Primes, commissions et avances ; alertes de fraude ; journal d'audit de toute remise, annulation,
     changement de tarif ou de chambre.

 H10. Clients et fidélité [V]
 - Fiche client : historique des séjours, préférences, dépenses, entreprise ; clients fidèles et VIP ; points
     de fidélité, parrainage, anniversaires et offres, roue de la chance clients (tirage réel, lots plafonnés).
  - Demande d'avis après le séjour par message WhatsApp préparé ; suivi des plaintes et des
     incidents par client.
  - Liste de clients à surveiller (impayés, dégradations), limitée au personnel habilité, motif factuel et
     durée de conservation limitée. [P]

 H11. Canaux et distribution [V]
 - Page de réservation en ligne gratuite (page statique) qui envoie une demande de réservation à
     l'hôtel ; disponibilités et tarifs partageables par WhatsApp et réseaux sociaux ; catalogue de
     chambres avec photos.
  - Synchronisation de calendriers par lien iCal avec les plateformes de réservation qui l'acceptent
     : importer leurs réservations et exporter celles de l'hôtel pour éviter les doubles ventes. Les mises à
     jour se font à intervalles réguliers, pas en temps réel ; un véritable gestionnaire de canaux temps
     réel est payant et hors périmètre gratuit. [P]
  - Origine de chaque réservation (direct, agence, plateforme, entreprise) pour mesurer la rentabilité de
     chaque canal.

 H12. Comptabilité et indicateurs hôteliers [V]
 - Journal, compte de résultat par département (hébergement, restauration, bar, services),
     trésorerie, plan SYSCOHADA, TVA et taxe de séjour datées et paramétrables, accès comptable par
     lien temporaire en lecture seule, exports mis en forme.
  - Indicateurs : taux d'occupation, prix moyen de la chambre vendue, revenu par chambre disponible,
     durée moyenne de séjour, taux d'annulation et de no-show, marge d'exploitation simple, coût par
     chambre occupée.

 H13. Multi-hôtels et groupe [V]
 - Compte mère de la direction générale : tableau de bord consolidé (occupation, revenus, caisse,
     incidents) de tous les hôtels ; comparatif entre hôtels et classement ; objectifs par hôtel.


Cahier des charges — NAXA Hotel · v1.0 · 31 octobre 2026                                                                Page 6

---

<!-- Page 7 -->

  - Tarifs, politiques et catalogues communs ou propres à chaque hôtel ; clients et fidélité partagés
     entre les hôtels du groupe ; transferts de stock et de linge entre hôtels, confirmés par le receveur ;
     personnel affectable à plusieurs hôtels.
  - Droits par hôtel : un manager ne voit que son hôtel ; la direction voit le groupe ; rapport mensuel du
     groupe prêt à envoyer.

 H14. Pilotage [V]
 - Tableau de bord du jour : arrivées, départs, chambres à préparer, occupation, encaissements,
     impayés, incidents ; prévision d'occupation à 30 jours ; revenus par canal et par département ; jours
     et saisons les plus rentables ; objectifs mensuels ; comparatif mois contre mois et année contre
     année ; hors connexion avec indicateur de fraîcheur.

 H15. Sécurité de l'établissement [V]
 - Registre des incidents, objets de valeur déposés (coffre), clés et badges, accès restreints par poste,
     journal d'audit, déconnexion à distance d'un téléphone perdu.


## 5. Intelligence artificielle
 Fonction                               Rôle

 Prévision d'occupation et de           Saisons, fêtes, événements, jours de la semaine, historique des réservations
 demande

 Suggestion de prix dynamique           Propose un tarif par chambre et par date selon l'occupation prévue ; le manager
                                        valide

 Prévision de no-show et d'annulation   Repère les réservations à risque et suggère un acompte ou un rappel

 Détection de fraude                    Remises anormales, notes annulées, chambres occupées sans encaissement,
                                        ménage fictif, écarts répétés par employé

 Vente additionnelle                    Suggère surclassement, petit-déjeuner, transfert ou services au bon moment

 Pilotage du stock et du linge          Minibar, consommables, linge usé ou manquant, réassort

 Maintenance prédictive                 Pannes qui se répètent par chambre ou équipement, appareils à remplacer

 Analyse des avis et des plaintes       Regroupe les retours par thème (propreté, bruit, accueil) et suggère des actions

 Score de santé de l'hôtel              Note sur 100 : occupation, marge, propreté, impayés, avis, maintenance

 Assistant « posez une question »       Écrit et vocal, français et English : « combien de chambres libres vendredi ? », «
                                        quel hôtel du groupe rapporte le moins ? »

 Résumé de la nuit et du jour           Texte court prêt à lire par le manager et à envoyer au propriétaire

 L'IA propose, l'humain décide : aucune chambre vendue, aucun tarif changé, aucune note modifiée par
 l'IA seule. Calculs d'abord sur le téléphone ; mode dégradé sans IA en ligne. [V]


## 6. Briefings
  - Matin (7 h) : « Aujourd'hui : 9 arrivées, 7 départs, 22 chambres occupées sur 30, 3 chambres à
     préparer en priorité, 2 pannes ouvertes, impayés 85 000 F ». Soir : recette par département,
     occupation du jour, écarts de caisse, incidents, arrivées de demain. Clôture de nuit : rapport
     envoyé au manager et au propriétaire. Pour un groupe : briefing consolidé de tous les hôtels. [V]


## 7. Paliers et prix
 Prix mensuels en francs CFA par hôtel, selon le nombre de chambres, plus élevés que pour un
 commerce car le revenu d'un hôtel est plus élevé. Forfaits de 3, 6 et 12 mois comme pour les autres
 applications. [P] Prix à tester auprès de 5 ou 6 hôteliers avant de les figer.

                                               Essentiel               Pro                        Réseau

 Prix par mois (proposition)                   3 000                   8 000                      20 000

 Chambres par hôtel                            jusqu'à 10              jusqu'à 40                 illimité

 Hôtels                                        1                       1 + 2 000 F par hôtel      Multi-hôtels, compte
                                                                       supplémentaire             mère



Cahier des charges — NAXA Hotel · v1.0 · 31 octobre 2026                                                             Page 7

---

<!-- Page 8 -->

                                                  Essentiel             Pro                         Réseau

 Utilisateurs                                     3                     15                          illimité

 Chambres, réservations, arrivée et départ,       oui                   oui                         oui
 compte du séjour, caisse, mobile money
 confirmé

 Ménage, maintenance, postes et droits,           non                   oui                         oui
 passation de poste, audit de nuit

 Stock et économat, restauration légère,          non                   oui                         oui
 comptes entreprise, compta SYSCOHADA

 Fidélité, avis, page de réservation,             non                   oui                         oui
 calendriers iCal, groupes et blocs

 IA avancée (prix dynamique, fraude,              non                   partielle                   complète
 maintenance, assistant vocal)

 Multi-hôtels, consolidation, transferts, accès   non                   non                         oui
 comptable, Drive

 Tolérance hors connexion                         7 jours               7 jours                     14 jours

  - Prix des hôtels supplémentaires, remise de lot avec les autres applications (par exemple un hôtel et
     son restaurant avec Resto-Bar) : à décider. [O]
  - Forfaits : Essentiel 8 100 / 15 000 / 30 000 F ; Pro 21 600 / 40 000 / 80 000 F ; Réseau 54 000 / 100
     000 / 200 000 F (3, 6, 12 mois). [P]


## 8. Solutions gratuites et limites [P]
 Besoin                         Solution gratuite                             Limite à surveiller

 Base, authentification,        Un Supabase partagé par les sept              Deux projets actifs par organisation ; 500 Mo
 temps réel                     applications                                  de base partagés ; pause d'un projet gratuit
                                                                              après une semaine d'inactivité

 Notifications push             Firebase Cloud Messaging                      Aucune notable

 Code-barres, texte sur         Bibliothèques du téléphone (ML Kit ou         Qualité sur téléphones d'entrée de gamme
 photo                          équivalent)

 Voix                           Service vocal d'Android                       Hors connexion variable

 Impression                     Bluetooth, imprimante thermique du client     Matériel du client

 Catalogue partageable          Page web statique (GitHub Pages)              Pas de paiement en ligne

 Sauvegarde                     Google Drive API                              Compte Google du client

 Code et APK                    GitHub, Actions, Releases                     Quotas de construction multipliés par sept

 IA en ligne                    API gratuite d'un fournisseur                 Quotas à vérifier

 Sept applications sur un seul backend gratuit multiplient les données : l'offre gratuite de Supabase (500
 Mo de base) peut devenir insuffisante avant d'avoir beaucoup de clients, et un projet gratuit sans trafic
 pendant une semaine est mis en pause. Prévoir une alerte de capacité, l'archivage des anciennes
 données, un plan de migration payant financé par les abonnements et une activité de maintien en
 ligne. [O]
  - Les photos de chambres et de pièces d'identité pèsent lourd : compression avant envoi, stockage
     séparé de la base, durée de conservation limitée.
  - Un calendrier de réservations plus lourd et partagé entre plusieurs téléphones augmente le trafic de
     synchronisation : surveiller le quota de bande passante gratuit.


## 9. Conformité et vigilance [P]
  - Relecture juridique unique avant le premier client payant : conditions d'utilisation et confidentialité
     en français et en anglais, consentement à la lecture des SMS conservé comme preuve, conformité à
     la réglementation camerounaise sur les données personnelles, mention que l'IA est une aide et non
     un conseil financier, comptable ou fiscal.




Cahier des charges — NAXA Hotel · v1.0 · 31 octobre 2026                                                             Page 8

---

<!-- Page 9 -->

  - Registre des voyageurs et fiche de police : les hébergeurs sont généralement tenus
     d'enregistrer leurs clients ; les informations exigées, la durée de conservation et la transmission aux
     autorités sont à faire confirmer par un juriste avant la mise en service. [O]
  - Pièces d'identité : stockage chiffré, accès limité aux postes habilités, consentement, suppression
     après la durée légale ; aucune photo de pièce n'est partagée par WhatsApp.
  - Taxe de séjour, TVA et facturation : taux et mentions obligatoires à vérifier à la construction ;
     numérotation continue des factures.
  - Classement et normes hôtelières : l'application aide, sans valoir attestation de conformité.
     Alcool : règles de licence du bar à vérifier. Objets de valeur : responsabilité de l'hôtel à afficher
     dans ses conditions.
  - Données des clients : consentement, visibilité limitée par poste, aucune revente, durée de
     conservation limitée de la liste de clients à surveiller.


## 10. Plan de réalisation
 Un prompt autonome à la fois. Le socle commun (jalon 0) est construit une seule fois pour la première
 application, puis réutilisé. Pilote avec quelques commerçants réels avant de généraliser. [P]

 Jalon                   Contenu

 J0. Socle commun        Réutilisé depuis Kiosko

 J1. Cœur hôtel          Chambres et tarifs, calendrier d'occupation, réservations, arrivée et départ, compte du séjour,
                         caisse, mobile money confirmé, briefing du soir

 J2. Opérations et       Ménage et statuts, maintenance, postes et droits, planning, passation de poste, clôture de nuit,
 postes                  stock et économat

 J3. Clients et          Fiche client et fidélité, avis, comptes entreprise, blocs de groupes, page de réservation,
 distribution            calendriers iCal, compta SYSCOHADA et indicateurs hôteliers

 J4. Réseau et IA        Multi-hôtels, consolidation, transferts, prix dynamique, fraude, maintenance prédictive,
                         assistant vocal, accès comptable, Drive, recette, tests terrain et distribution



## 11. Risques
  - Limites des offres gratuites avec un backend partagé par sept applications.
  - Installation hors Play Store : méfiance des utilisateurs, avertissements Android, paramètres
     restreints.
  - Charge de travail : sept projets en parallèle ; le rang de construction et les jalons servent à la
     maîtriser.
  - Charge de l'administration : tous les accès sont créés à la main ; prévoir des outils de création
     rapide.
  - Faux SMS et fraude ; copie de l'APK (protection dissuasive, non absolue).
  - Conflits de réservation hors connexion : deux réceptionnistes peuvent vendre la même
     chambre ; règle « première enregistrée gagne », réservations provisoires et alerte au manager.
  - Un calendrier iCal n'est pas un gestionnaire de canaux temps réel : risque résiduel de double vente
     avec les plateformes.
  - Sensibilité des données (pièces d'identité) : risque juridique et de sécurité plus élevé que dans les
     autres applications.
  - Périmètre très large : un hôtel utilise presque tous les modules ; recette à faire avec un hôtel pilote
     réel.


## 12. Points ouverts
## 1. Obligations légales exactes du registre des voyageurs au Cameroun.
## 2. Tarifs d'abonnement par nombre de chambres, à tester.
## 3. Fonctionnement de l'hôtel pilote : taille, postes réels, canaux de réservation utilisés.
## 4. Imprimante de reçus et de factures (Bluetooth, A4) à prévoir.
## 5. Lien précis entre NAXA Hotel et Zipple pour l'imputation sur chambre.


Cahier des charges — NAXA Hotel · v1.0 · 31 octobre 2026                                                              Page 9

---

<!-- Page 10 -->

## 6. Noms retenus le 31 octobre 2026 : Kiosko, Bootik, Zipple, NAXA Services, CotiZ, Loyable, NAXA
      Hotel. À vérifier pour chacun : nom de domaine, WhatsApp Business, réseaux sociaux, antériorité
      auprès de l'OAPI ; [O]
## 7. Un abonnement par application : remise de lot pour un client qui en prend plusieurs (proposition :
      −20 % sur la deuxième application et les suivantes) [O].
## 8. Un keystore par application ou commun (section 3, S10).
## 9. Plan de migration quand l'offre gratuite de Supabase devient insuffisante.

## 13. Modèle de données propre à l'application
  - rooms, room_types, room_photos, rate_plans, seasons, taxes_dated, reservations,
      reservation_rooms, group_blocks, stays, folios, folio_items, payments, guests, guest_documents
      (chiffrés), guest_flags, companies (comptes entreprise), keys_log, housekeeping_tasks,
      room_status_log, linen_stock, lost_found, maintenance_tickets, maintenance_plans, shifts,
      handovers, night_audits, staff_planning, ical_links, booking_requests, reviews, hotel_groups,
      hotel_group_members, plus les tables communes de caisse, stock, fournisseurs, équipe, compta et
      notifications.


## 14. Critères de recette (extraits)
  - Une chambre ne peut pas être vendue deux fois pour les mêmes dates ; une réservation hors
      connexion en conflit devient « à replacer » avec alerte au manager.
  - Un check-out solde le compte du séjour, restitue la caution et passe la chambre à « libre sale ».
  - Un ticket de Zipple mis sur la chambre apparaît dans son compte de séjour.
  - Une femme de chambre ne voit que ses chambres ; un réceptionniste de jour ne peut pas modifier
      un tarif ; un agent de sécurité n'accède à aucune donnée financière.
  - La clôture de nuit signale tout écart de caisse et produit le rapport du matin.
  - Une chambre « hors service » disparaît des disponibilités à la vente aux dates indiquées.
  - Un manager ne voit que son hôtel ; la direction voit tous les hôtels du groupe ; le client fidèle d'un
      hôtel est reconnu dans un autre hôtel du groupe.
  - Un calendrier iCal importé crée des blocs d'indisponibilité ; l'export reflète les réservations de l'hôtel.
  - La photo d'une pièce d'identité est chiffrée, n'est visible que des postes habilités et est supprimée
      après la durée réglée.
  - L'IA propose un prix pour une date mais ne le change jamais sans validation du manager.
  - Un accès créé par l'administration n'ouvre que les applications et les modules du palier choisi ;
      aucune inscription n'est possible depuis l'application.
  - Un même SMS reçu deux fois ne crée qu'une opération ; un SMS contenant un OTP ou un PIN n'est ni
      stocké ni synchronisé ; un SMS partagé n'active jamais un abonnement.
  - Hors connexion : toutes les fonctions locales marchent ; au retour du réseau, synchronisation sans
      doublon ; au-delà de la tolérance, accès restreint.
  - Un point dont l'abonnement est échu ne peut ni lire ni écrire sur le serveur hors écran de paiement ;
      ses données et son export restent disponibles.
  - Un APK modifié et signé avec une autre clé ne peut pas se synchroniser et l'administration est
      alertée ; une version inférieure à la version minimale est bloquée.
  - Un troisième appareil ferme le plus ancien et notifie le propriétaire.
  - Chaque export PDF et Excel porte le nom du point et la date.
  - Le briefing du matin et celui du soir contiennent les chiffres clés de l'application.
  - Les couleurs, le logo et la police de l'application correspondent à la charte de la section 15 ; chaque
      état de couleur (succès, alerte, avertissement) a une icône et un libellé ; le texte courant atteint un
      contraste de 4,5 : 1.


## 15. Identité visuelle et charte graphique [V]
 Chaque application suit la charte graphique de son logo : mêmes couleurs, même style. Le logo et
 le nom ont été fournis le 31 octobre 2026. [V]


Cahier des charges — NAXA Hotel · v1.0 · 31 octobre 2026                                                 Page 10

---

<!-- Page 11 -->

 15.1 Logo
 - Logo : monogramme N jaune-orangé, mot « NAXA » en bleu vif, mention « HOTEL » en lettres
     espacées. Style lumineux.
  - Le logo en tête de ce cahier est le fichier fourni. Usage : sur fond clair (ou sur le fond d'origine pour
     NAXA Services), sans le déformer ni le recolorer ; zone de protection égale à la hauteur d'une lettre ;
     taille minimale à l'écran de 24 pixels de haut. [P]
  - À prévoir à partir du fichier fourni : icône d'application adaptative, écran de démarrage, logo
     monochrome pour l'icône des notifications, logo pour les reçus et documents. Fournir idéalement les
     logos au format vectoriel (SVG) ou en grande taille avec fond transparent. [P]

 15.2 Palette
                                                                                                        Contraste sur
        Couleur                      Code          Usage
                                                                                                        blanc

                                                   Barre supérieure, boutons principaux, titres,
        Bleu vif — principale        #2058F4                                                            5.6 : 1
                                                   logotype ; texte blanc dessus

        Jaune-orangé — accent                      Monogramme, indicateurs, états actifs ; en fond
                                     #FDA601                                                            2.0 : 1
        de marque                                  seulement, texte noir dessus

        Ambre foncé — accent
                                     #B36F00       Liens et petits textes sur fond clair                4.0 : 1
        texte

        Bleu profond                 #153AA8       Titres et textes importants sur fond clair           9.5 : 1

        Fond clair                   #FFF4DC       Cartes, lignes alternées                             1.1 : 1

        Texte                        #111111       Texte courant                                        18.9 : 1

        Mode sombre — fond           #0B1B4D       Fond du mode sombre ; surfaces #15296E               16.4 : 1

                                                   Opération réussie, paiement confirmé (toujours
        Succès                       #197A33                                                            5.4 : 1
                                                   avec l'icône ✓ et le mot « payé »)

                                                   Erreur, écart, impayé, rupture (toujours avec
        Alerte                       #C62828                                                            5.6 : 1
                                                   l'icône ! et un libellé)

                                                   À vérifier, échéance proche (toujours avec l'icône
        Avertissement                #8F5400                                                            6.1 : 1
                                                   et un libellé)

 Les codes de marque sont mesurés sur le fichier du logo ; les couleurs « texte », « foncé » et de fond
 sont des dérivées proposées pour la lisibilité. [P] Règle de lisibilité : texte courant à 4,5 : 1 de contraste
 au minimum, gros texte et icônes à 3 : 1 ; une couleur de marque plus claire que cela n'est utilisée
 qu'en fond, avec un texte foncé dessus.

 15.3 Règles d'application
 - Un seul code, un thème par application : l'interface, les écrans et le comportement sont
     identiques d'une application à l'autre ; seuls les couleurs, le logo, la police et le vocabulaire
     changent. La couleur principale sert à la barre supérieure, aux boutons principaux et aux titres ;
     l'accent aux actions secondaires, aux badges et aux graphiques. [P]
  - Police : Montserrat (gras pour les titres, normal pour le texte), police libre à embarquer dans
     l'application pour fonctionner hors connexion. [P]
  - États : succès, alerte et avertissement gardent leurs couleurs de sens, toujours doublées d'une
     icône et d'un libellé, quelle que soit la couleur de marque.
  - Mode clair par défaut, mode sombre en option (sauf NAXA Services) ; contrastes forts pour la
     lecture en plein soleil sur téléphone d'entrée de gamme.
  - Documents émis (reçus, factures, quittances, briefings WhatsApp) : en-tête avec le nom du
     commerce du client et la mention discrète « établi avec NAXA Hotel », aux couleurs de l'application.
     Le client peut ajouter son propre logo à partir du palier Pro. [P]
  - Cohérence de la famille : la page de téléchargement officielle présente les sept applications avec
     leur logo et leur couleur ; un client qui en utilise plusieurs retrouve les mêmes repères.
 Point d'attention. Le planning des chambres utilise des couleurs de statut (libre, occupée, à nettoyer,
 hors service) distinctes des couleurs de marque, chacune avec une icône et une lettre pour rester lisible


Cahier des charges — NAXA Hotel · v1.0 · 31 octobre 2026                                                           Page 11

---

<!-- Page 12 -->

 sans couleur.


## 16. Glossaire
  - APK : fichier d'installation d'une application Android. FCM : notifications push gratuites de Google.
     RLS : règles de sécurité par ligne dans la base.
  - Famille d'applications : l'ensemble des sept applications partageant la même architecture. Socle
     commun : la partie partagée (section 3). Jalon : étape de construction testable.
  - Compte mère : compte du propriétaire qui regroupe plusieurs points. Parseur : programme qui
     extrait montant, nature et solde d'un SMS. PIN : code secret de l'opérateur. Code d'accès : code
     qui déverrouille l'application.




Cahier des charges — NAXA Hotel · v1.0 · 31 octobre 2026                                             Page 12


---

# Addendum fonctionnel NAXA HOTEL — Version 2.0 proposée
**Date : 22 novembre 2026**  
**Portée :** complément au cahier v1.0 du 31 octobre 2026. Cet addendum conserve intégralement les exigences et modules antérieurs. En cas de contradiction, les décisions plus récentes explicitement approuvées dans cet addendum prévalent sur les anciennes propositions [P] du cahier v1.0. Les éléments tarifaires de la section 20 sont une proposition commerciale et ne deviennent pas des prix validés avant arbitrage.

## 17. Référentiel fonctionnel hôtelier conservé et complété

Les 18 domaines fonctionnels issus de la proposition d'évolution 360° sont maintenus sans suppression :

1. Administration et organisation de l'établissement.
2. PMS hébergement, chambres, réservations et réception.
3. Commercial, groupes, séminaires et événements.
4. Distribution, canaux et gestion des revenus.
5. CRM et expérience client.
6. Housekeeping, entretien et linge.
7. Restauration, bar et room service, avec moteur métier ZIPPLE.
8. Services et prestations, avec interconnexion NAXA SERVICES.
9. Économat, achats et stocks.
10. Maintenance et gestion du patrimoine.
11. RH, personnels, équipes et plannings.
12. Finance, comptabilité et contrôle de gestion.
13. Caisse, paiements, facturation et rapprochements.
14. Contrôle interne, conformité et audit.
15. Sécurité intégrée à NAXA SECURITY.
16. Portail de séjour à accès limité par QR code.
17. Énergie, eau et environnement.
18. Direction, BI, indicateurs et IA sous contrôle humain.

Deux modules transversaux complètent ce périmètre, sans remplacer les domaines précédents :

19. **Livechat et communication professionnelle** : échanges du promoteur et des employés avec les équipes de support, assistance produit et échanges internes selon permissions. Les canaux, l'historique, les statuts, les pièces autorisées, l'escalade et la traçabilité sont conservés. Le SLA, les horaires et les délais de réponse restent à contractualiser. Ce module ne crée pas une cinquième entrée dans le portail QR client.
20. **Support client NAXA HOTEL** : helpdesk destiné au promoteur et aux utilisateurs professionnels de l'hôtel, avec tickets catégorisés (compte, abonnement, paiement, PMS, caisse, finance, synchronisation, intégration, sécurité, formation), priorité, affectation, réponse, escalade et historique. Mutualiser les services de support autorisés de FAMILLE-NAXA et NAXA SECURITY LIVECARE ; ne pas créer un helpdesk concurrent. Tout accès exceptionnel aux données d'un client doit être temporaire, limité, autorisé et journalisé.

## 18. Portail de séjour client — QR code en chambre

### 18.1 Principe impératif

Le client hébergé **n'a pas à installer d'application NAXA HOTEL, ZIPPLE, NAXA SERVICES ou LOYABLE**. Il ne doit pas créer de compte applicatif, de mot de passe ou d'identité utilisateur FAMILLE-NAXA.

Un QR code apposé dans chaque chambre ouvre une page Web responsive du portail de séjour. L'accès fonctionne avec le navigateur du téléphone du client. Le portail est un point d'accès public et limité ; il ne constitue pas un espace de gestion, une application mobile client, ni un compte client.

Le portail expose exactement quatre entrées, et aucune autre navigation fonctionnelle :

1. **Services de l'hôtel** : catalogue des services réellement proposés par l'établissement, leurs descriptions, conditions, horaires, prix et modalités de demande lorsqu'ils sont configurés dans NAXA HOTEL.
2. **Autres services disponibles** : consultation des catalogues publics des utilisateurs professionnels ZIPPLE et NAXA SERVICES, uniquement pour les catégories de services que l'hôtel ne propose pas lui-même. Le portail doit éviter les doublons et afficher clairement que le prestataire est externe à l'hôtel. Une disponibilité ou un prix non confirmé doit être présenté comme tel.
3. **Marketplace LOYABLE** : lien direct vers la page publique de la marketplace LOYABLE pour rechercher un hébergement et effectuer une demande de réservation.
4. **Pharmacie NAXA** : lien direct vers la page publique NAXA (pharmacie) permettant uniquement de rechercher un médicament et de consulter sa disponibilité publiée.

Aucune cinquième entrée n'est prévue. Ne pas ajouter au portail QR : chat, messagerie, fidélité, avis, promotions, vidéosurveillance, tableau de bord, compte client, paiement de séjour, contenu publicitaire, réseaux sociaux ou autres liens. Les modules Livechat et Support Client restent des fonctions professionnelles distinctes.

### 18.2 QR de chambre, sécurité et données minimales

- Générer un QR par chambre et par établissement, avec identifiant public opaque ou jeton non prédictible ; ne jamais encoder le nom du client, son téléphone, son numéro de réservation, son numéro de pièce, son folio, ses dates de séjour ou un identifiant interne directement exploitable.
- Associer côté serveur le QR à l'organisation, au site hôtelier et à la chambre correspondante.
- Permettre à l'établissement de désactiver, révoquer et régénérer un QR perdu, copié ou remplacé.
- Appliquer des limites de débit, des protections anti-automatisation et une journalisation technique minimale, proportionnée.
- Le portail ne révèle pas l'identité de l'occupant, les réservations, le solde du séjour, les coordonnées des autres clients ni les données internes de l'hôtel.
- Toute demande adressée à un prestataire externe transmet seulement les informations nécessaires à cette demande, après action explicite du client. Le numéro de chambre et l'identité du client ne sont pas communiqués par défaut.
- Un QR photographié ou partagé ne doit jamais suffire à autoriser une opération financière, un crédit au folio ou une action sensible.
- Le portail affiche le statut et l'horodatage des informations de disponibilité lorsque celles-ci ne sont pas synchronisées en temps réel. Il ne promet pas une disponibilité garantie si la source ne l'a pas confirmée.

### 18.3 Règle de sélection des services externes

NAXA HOTEL maintient, par établissement, une matrice des catégories de services proposées en interne. Pour une catégorie absente, le portail peut interroger les catalogues autorisés de ZIPPLE et NAXA SERVICES.

Le moteur doit :
- vérifier que le prestataire a une organisation active, un catalogue publié et une catégorie compatible ;
- respecter les zones, horaires, disponibilités et conditions réellement renseignés par le prestataire ;
- distinguer clairement un service de l'hôtel d'une offre d'un prestataire externe ;
- ne pas transformer une simple consultation de catalogue en commande acceptée ;
- transmettre une demande au système propriétaire du catalogue, qui reste responsable de la confirmation, du prix définitif, de l'exécution et de l'encaissement ;
- ne pas partager les dossiers de séjour, le folio ou les données de sécurité de l'hôtel avec ZIPPLE ou NAXA SERVICES.

Les catalogues ZIPPLE et NAXA SERVICES restent la source de vérité de leurs prestataires et offres. NAXA HOTEL orchestre l'accès et le contexte hôtelier par contrat API ; aucune écriture directe dans les tables d'une autre application n'est autorisée.

## 19. Commandes de restaurant et de bar par QR code — intégration ZIPPLE

### 19.1 Principe

Lorsqu'un hôtel exploite un restaurant, un bar, ou les deux, il doit pouvoir proposer la consultation des menus et la commande client par QR code, sans application client à installer.

Le QR peut être affiché :
- dans les chambres, depuis le portail de séjour, pour commander au room service lorsque cette prestation est activée ;
- sur les tables du restaurant ;
- dans les espaces ou tables du bar.

Si l'hôtel possède à la fois un restaurant et un bar, les deux activités sont configurées distinctement, avec leurs menus, points de service, circuits de préparation et responsables. Aucun paiement, ticket, stock ou chiffre d'affaires du restaurant ne doit être mélangé avec celui du bar sans écriture et ventilation explicites.

### 19.2 Parcours client

1. Le client scanne le QR avec l'appareil photo de son téléphone.
2. Une page Web légère présente le menu du point de service concerné (restaurant, bar ou room service).
3. Il consulte les articles, descriptions, prix, variantes, suppléments, disponibilités et conditions.
4. Il compose sa commande, vérifie le récapitulatif et soumet la demande.
5. ZIPPLE crée une commande identifiée, rattachée au bon établissement et au bon point de service.
6. Le personnel habilité accepte ou refuse la commande ; la cuisine ou le bar reçoit le ticket selon le routage configuré.
7. Le client voit les seuls statuts utiles de sa commande : reçue, acceptée, en préparation, prête, servie/livrée, refusée ou annulée.
8. La clôture et le paiement suivent les règles de caisse ZIPPLE et les règles d'imputation NAXA HOTEL lorsqu'une consommation doit être portée au folio.

Le parcours est utilisable sans compte ni installation. Une référence temporaire de commande permet de retrouver le suivi sans exposer les commandes d'un autre client.

### 19.3 Propriété des données et intégration

- **ZIPPLE reste propriétaire** du catalogue de restauration, des prix, recettes, ingrédients, disponibilités, tickets, préparation, postes cuisine/bar, stock, caisse, paiements et rapports du point de vente.
- **NAXA HOTEL reste propriétaire** des chambres, séjours, clients, folios, règles d'imputation sur chambre et opérations PMS.
- L'intégration se fait par contrats API et événements idempotents. Aucun accès direct ou écriture croisée dans les tables des deux applications.
- Chaque commande possède une référence unique, un établissement, un point de service, un canal source (hotel_room_qr, hotel_table_qr ou hotel_bar_qr), un instantané des lignes/prix et des états horodatés.
- Les commandes restaurant et bar restent analytiquement séparées par point de service, même si elles peuvent être présentées sur un folio de séjour unique.
- Le client ne peut pas modifier directement le stock, le prix, le ticket, la remise ou le statut financier.

### 19.4 Imputation au folio hôtelier

La commande peut être réglée par les moyens activés dans ZIPPLE ou, lorsque l'établissement l'autorise, être proposée à l'imputation au folio du séjour.

L'imputation au folio exige :
- un séjour ouvert et une chambre valide ;
- une correspondance de QR et de point de service vérifiée côté serveur ;
- une règle d'autorisation explicite de l'hôtel ;
- une validation du personnel habilité ou un mécanisme de confirmation renforcé défini par l'hôtel ;
- une référence de commande unique, un montant figé et une protection contre le double débit ;
- un événement d'imputation accepté par NAXA HOTEL avant que ZIPPLE ne considère l'imputation comme réalisée.

Un QR partagé ne permet pas de créditer automatiquement une chambre. Une commande refusée, annulée ou non confirmée ne génère aucune ligne payée dans le folio. Les paiements directs suivent les statuts de confirmation serveur de ZIPPLE ; une capture d'écran ou déclaration du client ne vaut pas preuve de paiement.

### 19.5 Restaurant/bar absent

Si l'hôtel ne possède ni restaurant ni bar, les fonctions POS/commande QR de ses propres points de vente sont désactivées. Le portail QR conserve uniquement les quatre entrées de la section 18. Les offres externes disponibles via les catalogues ZIPPLE et NAXA SERVICES restent consultables dans l'entrée « Autres services disponibles » lorsqu'une catégorie correspondante manque dans l'hôtel.

## 20. Abonnements NAXA HOTEL — proposition tarifaire à arbitrer [P]

### 20.1 Modèle de facturation inspiré de LOYABLE

Recommander une souscription par organisation/promoteur hôtelier, calculée sur le nombre de chambres actives/en gestion dans le portefeuille couvert. Le calcul suit le principe LOYABLE : montant unitaire par chambre, quantité facturable affichée et historisée, sans créer une souscription indépendante pour chaque chambre.

**Formule Essentiel proposée [P] :**
- 800 FCFA par chambre active et par mois ;
- minimum de facturation : 10 000 FCFA par organisation et par mois.

**Formule Premium proposée [P] :**
- 1 000 FCFA par chambre active et par mois ;
- minimum de facturation : 18 000 FCFA par organisation et par mois.

Formules :
- Essentiel mensuel = max(10 000 FCFA, 800 FCFA × nombre de chambres actives facturables).
- Premium mensuel = max(18 000 FCFA, 1 000 FCFA × nombre de chambres actives facturables).

Le nombre de chambres facturables doit être un instantané daté de la quantité de chambres actives/en gestion rattachées à l'organisation. Les chambres archivées ou définitivement retirées de la gestion sont exclues. La règle exacte de traitement d'une chambre temporairement hors service (travaux, sinistre, rénovation) doit être affichée et arbitrée avant facturation automatisée.

### 20.2 Périodicité annuelle proposée

Conformément à FAM-020, les abonnements proposés sont mensuels ou annuels uniquement. Pour les deux formules NAXA HOTEL, recommander 12 mois de service pour 10 mensualités payées :

- Annuel Essentiel = montant mensuel calculé × 10.
- Annuel Premium = montant mensuel calculé × 10.
- Aucun abonnement de 3 ou 6 mois.
- Aucun cumul de promotions ne doit recréer 3 ou 6 mois gratuits.
- Aucun tarif payé ne peut être révisé rétroactivement pendant la période couverte.

### 20.3 Exemples de simulation (FCFA)

| Chambres actives | Essentiel / mois | Essentiel / an (10 mois payés) | Premium / mois | Premium / an (10 mois payés) |
|---:|---:|---:|---:|---:|
| 10 | 10 000 | 100 000 | 18 000 | 180 000 |
| 20 | 16 000 | 160 000 | 20 000 | 200 000 |
| 30 | 24 000 | 240 000 | 30 000 | 300 000 |
| 50 | 40 000 | 400 000 | 50 000 | 500 000 |
| 80 | 64 000 | 640 000 | 80 000 | 800 000 |

Ces montants sont des simulations commerciales, non des prix homologués. Le catalogue doit afficher le nombre de chambres, le prix unitaire, le minimum éventuel, la période, le tarif mensuel équivalent, le total annuel et les deux mensualités offertes.

### 20.4 Comparaison publique indicative

La grille a été construite après consultation, le 22 novembre 2026, de prix publics affichés par des solutions ciblant les marchés africains :
- Hotelia affiche un plan Hébergement à partir de 16 200 FCFA/mois et une formule Tout-en-un hébergement + POS + cuisine à partir de 27 000 FCFA/mois : https://www.hotelia.cloud/
- The African Hotelier affiche 25 000 FCFA/mois pour 1 à 20 chambres et 50 000 FCFA/mois pour 21 à 50 chambres : https://theafricanhotelier.com/pms-hotelier/
- 1412 PMS affiche 29 000 FCFA/mois (Starter), 39 000 FCFA/mois (Business) et 69 000 FCFA/mois (Premium) : https://1412pms.com/
- StayFlow affiche un cloud optionnel à 30 000 FCFA/mois pour Essentiel et 72 000 FCFA/mois pour Business, en plus d'une licence initiale : https://stayflow.pro/

Ces pages sont des références de positionnement, pas une comparaison technique certifiée : les quotas, modules, frais de mise en service, matériels, support, fiscalité et conditions commerciales ne sont pas identiques. La proposition NAXA HOTEL vise un prix d'entrée accessible pour les petits établissements et un prix par chambre qui évolue avec la taille.

### 20.5 Différenciation fonctionnelle proposée

Les deux formules doivent préserver les fonctions nécessaires à l'exploitation quotidienne et à la sécurité ; ne pas désactiver une fonction métier essentielle afin de pousser artificiellement vers Premium.

**Essentiel — un établissement hôtelier :**
- PMS de base complet : chambres, tarifs, réservations, arrivées/départs, folio, caisse, facturation et paiements avec statuts confirmés ;
- tâches de ménage, maintenance courante, équipe, rôles, passations et audit des opérations essentielles ;
- catalogue hôtel, économat/achats/stocks de base, services et prestations ;
- restaurant et bar lorsqu'ils existent, avec QR de menu et de commande client via ZIPPLE, room service par QR si activé, tickets séparés cuisine/bar et consultation du statut ;
- NAXA SECURITY intégré : socle de sécurité du site, appareils compatibles, événements, alertes, incidents, droits et historique ; intégrations compatibles fumée/incendie dans les limites des dispositifs tiers ;
- portail QR client limité aux quatre entrées de la section 18 ;
- accès marketplace hôtel LOYABLE gratuit tant que l'abonnement NAXA HOTEL est actif et que l'hôtel respecte les règles de publication ;
- support professionnel standard selon les canaux et horaires qui seront publiés.

**Premium — établissement renforcé et groupes hôteliers :**
- toutes les fonctions Essentiel ;
- périmètre multi-hôtels/multi-sites au niveau de l'organisation, consolidation et délégation avancée ;
- rapports avancés, contrôle de gestion, gestion commerciale approfondie, groupes et événements, revenue management et outils IA avancés soumis à validation humaine ;
- fonctions avancées ZIPPLE pour les points de service, le routage cuisine/bar, le pilotage, les analyses et la consolidation selon entitlements ;
- capacité étendue NAXA SECURITY : multi-zones/multi-sites, capacités et quotas supérieurs, analyses et corrélations avancées, rapports et options de supervision autorisées ;
- support prioritaire selon engagement de service publié.

Les quotas précis (utilisateurs, sites, chambres, appareils, caméras, capteurs, stockage, rétention, flux simultanés, QR/points de service et volumes) doivent être chiffrés selon les coûts et capacités réels avant publication. Aucun plafond numérique n'est inventé dans ce cahier.

**Sécurité NAXA SECURITY dans les deux formules :** le socle de protection est inclus dans Essentiel comme dans Premium ; Premium augmente la portée et les capacités, mais ne supprime pas la protection de base d'Essentiel. NAXA fournit les logiciels, les intégrations, la configuration, la formation et le support prévus. NAXA ne fournit pas les caméras, centrales incendie, capteurs, câblages, serveurs, sirènes ni installation matérielle, et ne fournit pas de service humain de télésurveillance. Les systèmes locaux certifiés d'alarme et de protection incendie doivent rester autonomes et opérationnels sans dépendance au cloud NAXA.

### 20.6 Règles de quantité et changements en cours de période [O]

Reprendre le modèle LOYABLE :
- une souscription par organisation/promoteur ;
- affichage du nombre de chambres retenues et de son détail ;
- journal de l'ancienne quantité, nouvelle quantité, auteur, date de constat, date d'effet et tarif appliqué ;
- conservation d'un instantané de la quantité facturée pour chaque période ;
- aucune hausse rétroactive et aucune mutation concurrente incohérente.

**Point à arbitrer avant automatisation [O] :** ajout/retrait de chambres pendant une période payée : effet immédiat avec prorata ou effet au prochain renouvellement. Aucune proratisation automatique ne doit être codée avant décision.

Les frais uniques d'installation logicielle, configuration, formation, migration ou déplacement, s'ils sont retenus, sont affichés séparément et ne constituent pas un abonnement trimestriel ou semestriel. Le matériel reste à la charge de l'hôtel ou de son installateur/intégrateur.

### 20.7 Règles LOYABLE de publication hôtelière

La marketplace publique LOYABLE doit disposer d'une catégorie spécifique **Hébergements et établissements hôteliers**, distincte des annonces de location résidentielle.

Deux parcours sont retenus :

**Hôtel utilisateur de NAXA HOTEL :**
- publication et présence sur la marketplace LOYABLE gratuites ;
- accès réservé à une organisation ayant un abonnement NAXA HOTEL actif ;
- création/mise à jour de l'annonce à partir des données autorisées du PMS ;
- sélection des types de chambres, photos, tarifs et conditions visibles ;
- LOYABLE reste responsable de la publication publique et de l'affichage ;
- NAXA HOTEL reste l'autorité pour les tarifs, stocks de chambres, disponibilités et confirmations de réservation ;
- aucune demande issue de LOYABLE n'est présentée comme une réservation confirmée avant acceptation par NAXA HOTEL.

**Hôtel n'utilisant pas NAXA HOTEL :**
- abonnement de référencement/réservation LOYABLE proposé à **10 000 FCFA par mois** ;
- intégration, vérification de l'établissement, création et administration de l'annonce par l'administration centrale de l'entreprise ;
- aucune inscription autonome ni auto-publication par un hôtel externe dans ce circuit ;
- les demandes de réservation sont transmises à l'établissement par le circuit administratif défini ; confirmation uniquement après réponse et vérification de disponibilité ;
- en l'absence de PMS connecté, la disponibilité est déclarative ou administrée manuellement, horodatée et revalidée par l'établissement avant toute confirmation ;
- le forfait est mensuel ; un tarif annuel et les SLA d'administration ne sont pas définis à ce stade.

Ce service hôtelier est distinct de la tarification LOYABLE des bailleurs (1 000 FCFA × chambres actives/en gestion). Aucun double abonnement LOYABLE ne doit être appliqué à un hôtel utilisateur de NAXA HOTEL pour sa seule publication hôtelière.

### 20.8 Contrats inter-applications et événements

Prévoir des contrats versionnés, authentifiés, idempotents et audités. Les événements proposés comprennent :
- hotel_listing.created, hotel_listing.updated, hotel_listing.withdrawn ;
- naxa_hotel.tariff.updated, naxa_hotel.availability.updated ;
- loyable.hotel_booking_request.created ;
- naxa_hotel.booking_request.accepted, naxa_hotel.booking_request.rejected, naxa_hotel.reservation.confirmed, naxa_hotel.reservation.cancelled ;
- zipple.order.created, zipple.order.accepted, zipple.order.preparing, zipple.order.ready, zipple.order.served, zipple.order.cancelled ;
- naxa_hotel.folio_charge.requested, naxa_hotel.folio_charge.accepted, naxa_hotel.folio_charge.rejected.

Chaque événement conserve au minimum event_id, idempotency_key, version de contrat, application source/destination, organisation, site, acteur/service, horodatage, référence métier, statut et motif d'échec. Pas de partage global de profils ou d'écritures directes dans les tables d'une autre application.

## 21. Exigences supplémentaires de recette

### Portail QR
- Scanner le QR de deux chambres différentes affiche le bon établissement et le bon catalogue, sans révéler le séjour ou l'identité des occupants.
- Un QR révoqué/refait ne permet plus l'accès avec l'ancien jeton.
- Le portail présente exactement les quatre entrées prévues et aucune cinquième fonctionnalité.
- Les offres internes de l'hôtel ne sont pas dupliquées dans la liste des services externes.
- Un service absent de l'hôtel peut être recherché dans les catalogues ZIPPLE/NAXA SERVICES ; un catalogue indisponible ou non synchronisé est présenté comme tel.
- Les liens LOYABLE et pharmacie NAXA ouvrent leurs pages publiques ; aucun espace professionnel n'est accessible.

### Restaurant et bar QR / ZIPPLE
- Les QR restaurant, bar et chambre ouvrent le bon point de service et le bon menu.
- Un hôtel possédant restaurant et bar peut recevoir deux commandes indépendantes et les router vers les bonnes équipes.
- Une commande ne crée qu'un seul ticket ; les retries et scans répétés ne produisent pas de doublons.
- Une commande refusée ou annulée ne crée aucun paiement ni débit de folio.
- L'imputation sur chambre exige séjour ouvert, référence unique, autorisation et confirmation NAXA HOTEL ; le débit n'est jamais exécuté deux fois.
- Stock, recettes, prix, paiements et chiffre d'affaires restent dans le domaine ZIPPLE ; le PMS ne reçoit que les références et éléments autorisés nécessaires au folio.

### Marketplace hôtel LOYABLE
- Un hôtel NAXA HOTEL actif peut publier gratuitement ; abonnement échu, hôtel suspendu ou annonce rejetée masque les annonces selon les règles LOYABLE.
- Un hôtel externe ne peut être créé/publié qu'après procédure administrative et paiement mensuel confirmé.
- Une demande externe n'est jamais annoncée comme réservation confirmée avant vérification de la disponibilité.
- Une panne d'intégration ne doit pas afficher une disponibilité temps réel fictive.

### Abonnements et sécurité
- Tester les calculs de quantité, minimum de facturation, annuel à dix mensualités, changement de chambres et absence de rétroactivité.
- Tester que NAXA SECURITY est inclus dans les deux formules ; les entitlements Premium étendent les capacités sans retirer le socle Essentiel.
- Tester les événements fumée/incendie compatibles, l'autonomie locale du système certifié tiers et les alertes NAXA, sans prétendre remplacer le contrôleur matériel ou les secours humains.

## 22. Arbitrages restant nécessaires avant gel commercial

1. Valider ou modifier les tarifs proposés : 800 FCFA/chambre/mois Essentiel (minimum 10 000 F) et 1 000 FCFA/chambre/mois Premium (minimum 18 000 F).
2. Confirmer Premium multi-hôtels et le mode de calcul de la quantité à l'échelle du groupe.
3. Arbitrer l'effet des variations de chambres en cours de période (prorata immédiat ou renouvellement suivant).
4. Définir les quotas publiés : utilisateurs, appareils, sites, chambres, sécurité, stockage, rétention, QR/points de service et flux.
5. Définir les SLA, horaires et délais du support standard et prioritaire.
6. Définir les frais uniques de configuration/formation/déplacement, distincts de l'abonnement.
7. Confirmer les SLA d'administration du référencement des hôtels externes LOYABLE et l'éventuel tarif annuel du forfait mensuel de 10 000 F.

## 23. Statut et gouvernance de cette version

- Les sections 17 à 19 reprennent les évolutions fonctionnelles demandées ; le périmètre client QR est strictement limité et les commandes QR restaurant/bar sont intégrées à ZIPPLE.
- Les règles de publication hôtelière LOYABLE et d'intégration NAXA SECURITY reflètent les arbitrages communiqués.
- Les montants proposés dans la section 20 sont **[P] — non validés comme prix définitifs**.
- Les points de la section 22 restent **[O] — arbitrage nécessaire**.
- Cet addendum ne certifie aucune implémentation, migration, connexion inter-app, disponibilité réelle, paiement opérationnel ou recette réussie. Les documents décrivent la cible à construire et à tester.


---

## 24. Addendum commercial v2.1 — abonnement unique et tarification dynamique NAXA HOTEL

**Date de décision : 22 novembre 2026**  
**Statut : [V] proposition tarifaire acceptée par l'utilisateur ; cible commerciale à mettre en œuvre.**  
**Portée :** remplace les propositions de prix Essentiel/Premium de la section 20 et les arbitrages tarifaires correspondants des sections 22 et 23. Les autres dispositions fonctionnelles des sections précédentes restent applicables.

### 24.1. Décision commerciale

NAXA HOTEL commercialise **un seul abonnement par établissement ou organisation contractante**, facturé **mensuellement uniquement**.

- Aucun plan commercial Essentiel/Premium distinct.
- Aucun paiement annuel, trimestriel ou semestriel.
- Aucun abonnement additionnel pour le portail QR de séjour, les commandes QR restaurant/bar, les fonctions de base NAXA SECURITY ou l'intégration LOYABLE prévue pour les clients NAXA HOTEL.
- Le prix mensuel est déterminé par le nombre de chambres actives/gérées et par l'exploitation effective d'un service de restauration.
- À partir de 50 chambres, l'établissement relève d'une offre négociée sur devis. Aucun montant fixe ou calcul automatique n'est affiché pour cette tranche.
- Un groupe multi-hôtels relève également d'un devis négocié, même si chaque établissement pris isolément compte moins de 50 chambres. Le devis reste un abonnement mensuel consolidé, et non une addition d'abonnements par module.

Cette décision constitue une exception spécifique à la règle générale FAM-020 : **NAXA HOTEL n'offre pas de paiement annuel**.

### 24.2. Définition des chambres et du service de restauration

**Chambres facturables :** nombre de chambres actives et gérées dans le PMS au début de chaque cycle mensuel, hors chambres définitivement retirées de l'inventaire ou archivées. Une chambre temporairement hors service pour maintenance reste comptée lorsqu'elle demeure gérée dans NAXA HOTEL.

**Établissement avec restauration :** établissement exploitant au moins un point de restauration actif géré dans ZIPPLE : restaurant, espace de restauration, snack ou bar avec carte/menu, prise de commandes et caisse. Un minibar simple ou un petit-déjeuner inclus sans prise de commande ni exploitation de point de vente ne déclenche pas à lui seul le tarif restauration.

Le statut « avec restauration » sélectionne le barème correspondant ; il ne crée pas un deuxième abonnement ni une ligne d'abonnement ZIPPLE distincte.

### 24.3. Barème public — hôtel sans restaurant

Soit **N** le nombre de chambres facturables.

| Nombre de chambres | Calcul du prix mensuel |
|---|---:|
| 1 à 10 | 1 500 FCFA × N |
| 11 à 20 | max(15 000 FCFA ; 1 000 FCFA × N) |
| 21 à 30 | max(20 000 FCFA ; 800 FCFA × N) |
| 31 à 49 | max(24 000 FCFA ; 500 FCFA × N) |
| 50 et plus | Devis mensuel négocié |

### 24.4. Barème public — hôtel avec service de restauration

Soit **N** le nombre de chambres facturables.

| Nombre de chambres | Calcul du prix mensuel |
|---|---:|
| 1 à 10 | 2 000 FCFA × N |
| 11 à 20 | min(24 000 FCFA ; max(20 000 FCFA ; 1 500 FCFA × N)) |
| 21 à 30 | min(25 000 FCFA ; max(24 000 FCFA ; 1 000 FCFA × N)) |
| 31 à 49 | Forfait fixe de 26 000 FCFA |
| 50 et plus | Devis mensuel négocié |

Les planchers et plafonds sont intentionnels : ils empêchent une baisse de facture lorsqu'un établissement change de tranche et maintiennent le prix de la formule restauration sous le repère public de 27 000 FCFA/mois relevé pour une offre hôtelière tout-en-un concurrente. Ils priment sur la multiplication brute du tarif unitaire lorsqu'un plancher ou un plafond est atteint.

### 24.5. Exemples de facturation mensuelle

| Chambres | Sans restaurant | Avec restauration |
|---:|---:|---:|
| 5 | 7 500 FCFA | 10 000 FCFA |
| 10 | 15 000 FCFA | 20 000 FCFA |
| 11 | 15 000 FCFA | 20 000 FCFA |
| 14 | 15 000 FCFA | 21 000 FCFA |
| 16 | 16 000 FCFA | 24 000 FCFA |
| 20 | 20 000 FCFA | 24 000 FCFA |
| 21 | 20 000 FCFA | 24 000 FCFA |
| 25 | 20 000 FCFA | 25 000 FCFA |
| 26 | 20 800 FCFA | 25 000 FCFA |
| 30 | 24 000 FCFA | 25 000 FCFA |
| 31 | 24 000 FCFA | 26 000 FCFA |
| 40 | 24 000 FCFA | 26 000 FCFA |
| 49 | 24 500 FCFA | 26 000 FCFA |
| 50 et plus | Devis | Devis |

### 24.6. Règles de facturation et évolutions de capacité

1. La quantité facturable est photographiée au début de chaque période mensuelle payée.
2. Les ajouts, retraits ou changements durables de chambres sont pris en compte au renouvellement mensuel suivant ; aucune régularisation rétroactive n'est appliquée.
3. La facture précise le nombre de chambres retenu, le statut restauration et le barème appliqué.
4. La date d'effet, la quantité de référence et le montant facturé sont conservés dans l'historique d'abonnement.
5. À partir de 50 chambres, le montant résulte d'un devis accepté par le client et enregistré dans le système ; aucun algorithme ne doit inventer un forfait de 30 000 ou 40 000 FCFA.
6. Toute réduction commerciale exceptionnelle est autorisée par l'administration habilitée, datée, motivée et journalisée. Aucune modification rétroactive d'une facture payée.

### 24.7. Périmètre inclus dans l'abonnement unique

Le prix couvre le socle fonctionnel NAXA HOTEL décrit dans le présent cahier, selon les capacités contractuelles convenues : PMS, réception, séjour/folio, housekeeping, maintenance, gestion d'équipe, stocks/économat, finance et pilotage, portail Web QR à quatre entrées, commandes QR restaurant/bar via ZIPPLE lorsque les points de vente existent, intégration LOYABLE prévue pour les clients NAXA HOTEL et fonctions de base NAXA SECURITY.

Les capacités additionnelles ou besoins hors périmètre peuvent faire l'objet d'un devis spécifique, notamment pour les grands établissements, groupes multi-hôtels ou extensions de capacité. Ce devis ne doit pas réintroduire une tarification par module pour les fonctions standard. Les équipements physiques, câblages, travaux d'installation, prestations sur site, migration exceptionnelle ou formation supplémentaire peuvent être chiffrés séparément une seule fois ; ils ne sont pas compris implicitement dans l'abonnement mensuel.

### 24.8. Positionnement concurrentiel — vérification publique du 22 novembre 2026

Repères tarifaires publiés consultés :

| Offre publique observée | Prix affiché |
|---|---:|
| Hotelia — hébergement seul | À partir de 16 200 FCFA/mois |
| Hotelia — hôtel tout-en-un avec restaurant/bar | À partir de 27 000 FCFA/mois |
| The African Hotelier — 1 à 20 chambres | 25 000 FCFA/mois |
| The African Hotelier — 21 à 50 chambres | 50 000 FCFA/mois |
| 1412 PMS — Starter / Business / Premium | 29 000 / 39 000 / 69 000 FCFA/mois |

Sources consultées : https://www.hotelia.cloud/ ; https://theafricanhotelier.com/pms-hotelier/ ; https://1412pms.com/.

**Lecture commerciale :** le barème NAXA HOTEL avec restauration plafonne à 26 000 FCFA jusqu'à 49 chambres, sous le prix d'entrée tout-en-un Hotelia affiché à 27 000 FCFA et sous les offres 1412 PMS et The African Hotelier dans les tranches comparables citées. Le barème sans restaurant reste à 24 500 FCFA au maximum avant devis. Hotelia affiche aussi un prix d'entrée inférieur pour son offre hébergement seul (16 200 FCFA) : NAXA HOTEL ne prétend donc pas être systématiquement le tarif le plus bas de chaque catégorie. Les périmètres, quotas, frais d'installation, services, limites d'utilisateurs et niveaux de support ne sont pas identiques ; ces prix sont des repères publics, pas une preuve d'équivalence fonctionnelle.

### 24.9. Gouvernance, contrôles et statut de réalisation

- Les anciens prix Essentiel 800 FCFA/chambre (minimum 10 000 FCFA) et Premium 1 000 FCFA/chambre (minimum 18 000 FCFA), ainsi que leur paiement annuel proposé, sont **retirés et supersédés** pour NAXA HOTEL.
- Le socle NAXA SECURITY demeure inclus dans l'abonnement unique ; il ne dépend plus d'une formule Essentiel/Premium. Les capacités au-delà du socle contractuel sont chiffrées au besoin.
- Le portail QR de séjour, limité aux quatre entrées déjà définies, et les commandes QR restaurant/bar via ZIPPLE restent inclus sans supplément QR.
- La publication hôtelière LOYABLE reste gratuite pour un client NAXA HOTEL dont l'abonnement mensuel est actif, conformément à FAM-022.
- Les quotas précis de comptes, appareils, sites, chambres, caméras, capteurs, stockage, rétention et volumes d'événements doivent être fixés à partir des coûts et capacités techniques réels ; aucun quota fictif n'est autorisé.
- Un contrôle de marge/coût de service doit être conduit avant la mise en vente générale, à partir des coûts réels d'hébergement cloud, support, stockage, sécurité et intégrations.
- Cette mise à jour est documentaire. Elle ne prouve pas que la facturation dynamique, les entitlements, le calcul automatique, les paiements, les contrats inter-applications, le portail QR ou les modules NAXA HOTEL soient implémentés, testés ou déployés.
