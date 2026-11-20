# Audit global des sources NAXA / FAMILLE-NAXA et choix de la première application

**Date :** 20 novembre 2026  
**Dépôts examinés :**
- Cible : `audreymendomo23-netizen/FAMILLE-NAXA`, branche `main`.
- Patrimoine source : `audreymendomo23-netizen/NAXA`, branche `main`.
- Référence technique complémentaire : ZIP complet JOBLY déjà examiné. Les fonctions JOBLY Partner/parrainage/KYC/attribution/commissions/payout sont exclues de tout périmètre.

**Objet :** repérer ce qui est déjà réellement disponible, éviter les collisions, choisir l'application la plus rapide à construire à partir des actifs existants et préciser ses fonctionnalités.

## 1. Synthèse exécutive

1. Le dépôt FAMILLE-NAXA contient déjà les dix cibles Android et les dix cibles Web/PWA, des contrats, un design system, quelques fondations offline/notifications/sécurité locale, des scripts de génération et un socle SQL/RLS en préparation. **Les dix interfaces métier restent toutefois des coquilles :** NAXA Services Web affiche seulement son titre et la mention du socle PWA ; l'activité Android affiche le titre et une mention indiquant que les parcours métier restent à intégrer.
2. Le dépôt NAXA historique contient un patrimoine fonctionnel beaucoup plus riche : comptes et rôles, organisation hiérarchique, paiements/SMS, caisse/POS, stock, notifications Push, messagerie, comptabilité, rapports BI/IA, prestations à domicile et un chantier substantiel NAXA Security.
3. Le chantier NAXA Security est bien présent dans le dépôt NAXA `main`. Il comprend une passerelle locale, découverte et événements ONVIF, tickets de flux, MediaMTX/RTSPS/WHEP, enregistrement local, indexation, horodatage et politiques de haute surveillance. **Il n'est pas encore un produit terminé validé sur matériel réel** et n'est pas encore intégré dans l'application NAXA Security du monorepo FAMILLE-NAXA.
4. L'application recommandée pour commencer est **NAXA SERVICES**, en livrant d'abord son cœur opérationnel. Elle bénéficie de la meilleure combinaison entre périmètre maîtrisable et éléments réutilisables déjà présents (catalogue et demandes de prestations, rendez-vous, disponibilités, rappels, notifications, caisse, comptabilité et reporting). Les composants existants sont des références et des accélérateurs ; ils ne seront pas copiés tels quels si leur modèle de données appartient à la pharmacie ou aux partenaires Prestations à domicile.
5. **Aucun développement métier, aucune migration, aucune écriture Supabase et aucun déploiement n'ont été effectués pendant cet audit.**

## 2. Inventaire des dépôts

### 2.1 FAMILLE-NAXA — architecture cible

Le monorepo cible bien dix applications autonomes, chacune avec une cible Android Kotlin/Compose et une cible Web responsive/PWA. Les modules sont présents, mais les écrans métier ne sont pas réalisés.

Fondations actuellement identifiables :
- `packages/contracts` : identifiants des dix applications, types de domaines et enveloppe d'opération/synchronisation ;
- `packages/design-system` : tokens et contrôles de contraste ;
- `packages/core-android` : canaux de notifications, briefings et verrouillage biométrique/local ;
- `packages/core-kotlin` : petites fonctions d'analyse locale, contrats de notification et de synchronisation ;
- `packages/offline-web` : file IndexedDB, mise en file et changement d'état ;
- `packages/core-web` : vérification de manifeste de version et message WhatsApp sûr ;
- `packages/assistant` : explication simple de signaux et recommandations sous décision humaine ;
- `packages/billing-core` : fonctions élémentaires de tarification FCFA/prorata ;
- `supabase/drafts`, `supabase/migrations`, Edge Function de cycle de comptes : amorce du schéma Famille, RLS et administration.

Limites à ne pas masquer :
- Les files offline Android/IndexedDB existent, mais le transport réseau, les accusés serveur, les retries/backoff, l'idempotence de bout en bout et la résolution des conflits ne sont pas démontrés comme un service complet.
- Les notifications Android ont des contrats et canaux ; FCM, enrôlement des appareils, livraison réelle, centre complet et reprise sur erreurs restent à finaliser.
- Les prompts 0.3/0.4/0.5/0.6 du socle sont partiellement testés ou encore ouverts ; les tests PostgreSQL éphémères ne prouvent pas la compatibilité complète avec le backend NAXA réel.
- Le package d'administration et les dix modules métier ne sont pas encore des produits complets.
- Le dépôt contient beaucoup d'artefacts de compilation sous les répertoires `build/`. À nettoyer dans un chantier séparé, sans confondre cette hygiène avec la construction fonctionnelle.

**Conséquence :** ne pas présenter les dix applications comme opérationnelles parce que les cibles compilent. Construire une première application métier complète, extraire ensuite uniquement les fondations prouvées et réutilisables.

### 2.2 Dépôt NAXA historique — actifs métier disponibles

Le dépôt NAXA `main` contient un monolithe Next.js/Supabase mature, avec notamment :
- authentification, profils, affectations, postes et contrôles de périmètre ;
- notifications, Push Web/FCM, boîte de notifications, messagerie et modèles de messages ;
- workflows Mobile Money/SMS de déclaration et de confirmation ;
- caisse/POS, clôture, dépenses, mouvements, justificatifs et reçus ;
- stock, lots, inventaires, commandes, import et journalisation ;
- composants comptables SYSCOHADA, plan comptable, mappings, journaux et worker de traitement ;
- rapports à la demande PDF/CSV, agrégats par rôle et assistance IA encadrée ;
- catalogue de prestations, demandes client, disponibilité, créneaux confirmés, rappels planifiés et géolocalisation ;
- nombreux schémas, fonctions SQL/RPC, triggers, politiques RLS et migrations.

**Limite structurante :** une grande partie de ces actifs est liée aux entités métier de la pharmacie (`pharmacies`, `profiles`, `partners`, `partner_members`, réservations pharmacie, caisse pharmacie, etc.). Leur présence dans le dépôt ne donne pas le droit de les réutiliser directement pour les dix applications. Il faut séparer les algorithmes, contrats et patterns des tables et autorisations propres à l'ancien produit.

### 2.3 JOBLY — source secondaire limitée

JOBLY n'est pas une source propriétaire des règles métier NAXA. Les seuls apports à examiner sont les patterns techniques génériques déjà décrits dans la section 6.12 du document de continuité : AI Gateway, contexte/mémoire cloisonnés, mesure d'usage/coût et certains patterns de sécurisation des liens.

**Exclusion absolue :** aucun module JOBLY Partner, parrainage, KYC partenaire, code de referral, attribution de parrainage, commissions de referral ou payout. Aucun code, table, API, écran, rôle ou workflow correspondant ne doit être repris.

## 3. Audit particulier — NAXA SECURITY

### 3.1 Patrimoine retrouvé dans NAXA `main`

Le dépôt source contient notamment :
- `services/security-gateway/` : agent passerelle, enrôlement, découverte ONVIF, inspection, Pull-Point events, publication RTSP, enregistrement local, indexeur, calendrier de surveillance et intégrité temporelle ;
- une série de routes `src/app/api/security/` pour enrôlement/provisionnement, heartbeat, révocation, découverte, événements, sessions live, publication, autorisation MediaMTX, segments et protection d'enregistrement, temps et haute surveillance ;
- composants Promoteur pour provisionnement de passerelle, inventaire caméra, lecteur WHEP, timeline d'enregistrement, horloge et calendrier ;
- configurations MediaMTX, migrations SQL de sécurité 301–314 et tests ciblés du gateway, ONVIF, vidéo, enregistrement, protection, calendrier et intégrité temporelle.

### 3.2 Architecture NAXA Security à préserver

Architecture de référence issue des documents de faisabilité :
1. Caméras IP/NVR du client sur un réseau local isolé (VLAN/PoE quand nécessaire).
2. Passerelle/NVR sur site : découverte et diagnostic, lecture des flux, événements caméra, enregistrement local, tampon d'événement, horodatage, file locale et relais d'alarme si matériel compatible.
3. Connexion sortante chiffrée et authentifiée uniquement vers NAXA ; aucun port RTSP/ONVIF de caméra exposé sur Internet.
4. Services NAXA : identité et périmètre multi-site, autorisations serveur, audit, sessions live temporaires, événements, index temporel, clips sélectionnés et notifications.
5. Interfaces Promoteur multi-sites et Responsable mono-site ; futur compagnon Android pour alertes sonores renforcées.

Principes non négociables :
- l'enregistrement principal reste local ; Internet coupé ne doit pas arrêter l'enregistrement local ;
- le cloud ne doit pas recevoir en continu tous les flux HD ;
- secrets caméra conservés localement et chiffrés, jamais dans le navigateur ni dans les journaux ;
- accès live court, limité à la caméra/site/compte autorisé, révocable et journalisé ;
- IA descriptive uniquement, revue humaine obligatoire ; aucune reconnaissance faciale, biométrie, inférence d'intention ou accusation ;
- une sirène exige du matériel réel compatible, une confirmation humaine, une commande authentifiée anti-rejeu, un accusé matériel et un arrêt local ;
- audio désactivé par défaut et validation juridique/confidentialité avant pilote.

### 3.3 Niveau de maturité — ne pas confondre code et produit opérationnel

Le registre technique `docs/security/SUIVI_LOTS12_20_RESTANTS.md` (dernière qualification détaillée consultée : 9 novembre 2026) distingue :
- Lots 13, 14 et 16 : fondations logicielles rapportées vertes dans leurs tests, mais lots complets encore partiels ;
- Lot 12 live/MediaMTX : logiciel de contrôle et publication présent, mais aucun flux caméra physique validé ;
- Lot 17 IA avancée : événements ONVIF et revue humaine ; pas de runtime/modèle d'inférence validé ;
- Lot 15 sauvegarde Google Drive/téléphone : OAuth Drive et companion Android absents dans le registre ;
- Lot 18 companion Android : projet natif/FCM et recette téléphone absents ;
- Lot 19 sirène : schéma de commande, mais aucun relais/GPIO/contrôleur identifié et testé ;
- Lot 20 pilote E2E : aucun site/caméra/NVR/passerelle réel validé dans le relevé Replay.

Le relevé Replay inclus dans ce registre déclarait zéro installation, zéro passerelle, zéro caméra, zéro session live, zéro clip, zéro segment vidéo et zéro commande sirène ; les 15 adaptateurs caméra catalogués étaient `design_only`. Ces chiffres décrivent **Replay et le snapshot de ce rapport**, pas Production.

La branche `main` de NAXA contient des commits postérieurs à ce registre, dont des changements au 20 novembre 2026. Le résultat de CI cité dans le rapport (290/290 tests sur un SHA de novembre) ne doit donc pas être présenté comme un résultat fraîchement vérifié sur le HEAD actuel. Une revalidation ciblée de `main` et un pilote matériel sont requis.

**Décision d'architecture :** conserver NAXA Security comme application autonome dans FAMILLE-NAXA. Réutiliser le gateway, les API, les migrations et les contrats seulement après comparaison et adaptation au modèle d'identité, de tenant, de site et d'audit FAMILLE-NAXA. Ne pas importer toute l'application NAXA Pharmacy ni fusionner ses profils Promoteur/Pharmacie avec les identités autonomes de la famille.

À distinguer : le prompt commun `09-cameras.md` décrit aussi un module optionnel de consultation des caméras pour certains ERP. Ce module de consultation ERP n'est pas le produit autonome NAXA SECURITY ; ne pas les fusionner.

## 4. Comparatif global et ordre de construction recommandé

Classement indicatif selon le temps pour obtenir un premier produit métier utilisable, en tenant compte de la complexité intrinsèque et des éléments réellement réutilisables. Ce n'est pas une estimation contractuelle en jours.

| Rang | Application | Complexité initiale | Motif principal |
|---:|---|---|---|
| 1 | **NAXA SERVICES** | Faible à moyenne | Catalogue, demandes/rendez-vous, créneaux, notifications, caisse et reporting ont des correspondances dans NAXA ; aucun matériel spécialisé requis. Le pressing et la coiffure gardent toutefois leurs workflows propres. |
| 2 | **LOYABLE** | Moyenne | Parcours assez lisible, mais modèle locatif, échéanciers, impayés, caution, états des lieux et documents de bail sont à créer ; sensibilité juridique et financière élevée. |
| 3 | **GRILLAD** | Moyenne à élevée | POS/caisse/stock sont des références possibles ; rendement cuisson, pertes, sessions du soir, trois modes Manager et cloisonnement précis par lieu sont spécifiques. |
| 4 | **BOOTIK** | Élevée | Plusieurs profils de commerce, stock, crédit client, fournisseurs et parcours dépôt de gaz. |
| 5 | **ZIPPLE** | Élevée | Prise de commande/service, tickets, recettes, ingrédients, cuisson, pertes, consignes et marges. |
| 6 | **COTIZ** | Élevée | Contributions, tours, pénalités, épargne et prêts internes nécessitent des règles financières et des validations précises ; COTIZ ne détient jamais les fonds. |
| 7 | **CAMPUS237** | À qualifier / élevée | Cahier et prompts PDF présents dans le patrimoine NAXA, mais leur cartographie fonctionnelle doit être consolidée avant estimation. |
| 8 | **KIOSKO** | Très élevée | Lecture SMS Mobile Money en arrière-plan, formats opérateurs, anti-doublons, soldes de float, opérations et alertes sensibles. |
| 9 | **NAXA HOTEL** | Très élevée | PMS, chambres, réservations concurrentes/offline, folios, check-in/out, housekeeping et multi-hôtels. |
| 10 | **NAXA SECURITY** | Très élevée pour clôturer le produit | Un patrimoine logiciel existe déjà, mais la livraison dépend aussi des caméras/NVR, passerelle, réseau, médias, Android, sirène, conformité et pilote physique. Ce rang reflète le délai de clôture opérationnelle, pas l'absence de code. |

**Pourquoi NAXA SERVICES avant LOYABLE :** le dépôt NAXA offre déjà des modèles de catalogue, de demandes de prestations et de rendez-vous, un choix de créneau professionnel, des rappels planifiés, Push, messagerie, caisse, comptabilité et reporting. LOYABLE ne dispose pas d'un modèle locatif équivalent déjà identifié ; ses contrats, échéanciers, cautions et états des lieux sont à concevoir.

## 5. Première application — attentes fonctionnelles de NAXA SERVICES

**Référence fonctionnelle :** cahier NAXA Services v1.0 du 31 octobre 2026, complété par les prompts 4.1 à 4.7. L'application couvre deux activités : pressing et salon de coiffure. Les données, prestations et workflows doivent rester distinguables dans l'expérience métier.

### 5.1 Catalogue de prestations

- Prestations, catégories, prix, durées et prestataires habilités.
- Forfaits et formules.
- Prix par type de vêtement pour le pressing.
- Produits vendus au comptoir (shampoing, accessoires et autres produits autorisés).
- Historique des prix et règles de modification à préciser avant la comptabilisation.

### 5.2 Caisse et encaissements

- Paiement espèces, Mobile Money confirmé et paiement mixte.
- Reçu client, partage préparé par WhatsApp et impression Bluetooth si l'imprimante est prise en charge.
- Ouverture et clôture de caisse.
- Montant théorique contre montant réel et justification des écarts par utilisateur.
- Dépenses courantes (eau, électricité, produits, etc.) et journal des opérations.
- Les validations Mobile Money des ventes/acompte restent distinctes de la validation des abonnements Famille ; aucun SMS OTP/PIN ne doit être lu, conservé ou transféré.
- Les confirmations automatiques par SMS doivent utiliser des règles versionnées et une preuve fiable ; ne pas réutiliser le flux de paiement Promoteur/abonnement pour créditer la caisse du salon ou du pressing.

### 5.3 Agenda et rendez-vous coiffure

- Agenda par prestataire ou poste.
- Création rapide d'un rendez-vous, durée par prestation et créneaux disponibles.
- Rappel WhatsApp préparé avant le rendez-vous.
- Acompte, annulation, absence non excusée et liste d'attente.
- Mobile Money confirmé pour acompte et règlement, avec rapprochement idempotent.
- Distinguer la préférence horaire demandée par le client du créneau effectivement confirmé par l'établissement.

### 5.4 Dépôts, suivi et retraits pressing

- Dépôt et ticket numéroté.
- Liste des vêtements/pièces, tarif, acompte et date promise de retrait.
- Étiquette imprimable ou écrite à la main.
- États et historique : reçu → en cours → prêt → retiré.
- Message préparé « votre linge est prêt » à partager en un clic.
- Alerte après un délai paramétrable pour les vêtements non retirés, relances et règles de conservation.
- Reçu transmis au client ; garder la preuve du dépôt, des pièces et des changements de statut.

### 5.5 Équipe, prestataires et commissions

- Fiche de chaque employé/prestataire et affectation à une prestation.
- Part/commission calculée par prestation et par personne.
- Synthèse des commissions par période.
- Avances, primes, pointage et présence.
- Classement et challenges si les règles sont définies.
- Les taux et montants de commission sont **ouverts** dans le cahier : ne pas inventer de barème.

### 5.6 Clients et fidélité

- Fiche client : historique, préférences et dernière visite.
- Points de fidélité, carte QR, anniversaires et offres.
- Relance de clients inactifs.
- Le cahier mentionne également parrainage client et roue de la chance. Ces fonctions ne sont pas dans le premier lot ; le parrainage/Partner JOBLY est exclu. Toute fonction de parrainage native NAXA Services doit faire l'objet d'un arbitrage écrit séparé avant construction.
- Aucune donnée client ou photo ne doit être partagée sans consentement approprié.

### 5.7 Consommables, comptabilité et multi-salons

- Stock léger de consommables (produits coiffure, lessive) avec alertes de rupture ; pas d'inventaire détaillé par code-barres dans le périmètre v1.
- Comptabilité SYSCOHADA et TVA datée, après validation des règles et comptes applicables.
- Tableau de bord : chiffre d'affaires, services rentables, heures de pointe, occupation de l'agenda, objectifs.
- Multi-salons via compte mère, avec visibilité et actions limitées aux établissements autorisés.

### 5.8 IA et briefings

- Prévision de fréquentation par jour/heure et périodes spéciales.
- Suggestion de créneaux.
- Détection de signaux : prestation non encaissée, remises répétées.
- Conseils tarifaires, relance de clients inactifs, score de santé de l'établissement.
- Assistant de questions/réponses sur les chiffres, à partir d'agrégats autorisés.
- Briefing matin : rendez-vous, dépôts à rendre, acomptes attendus, échéances.
- Briefing soir : recettes, commissions, caisse attendue/réelle, rendez-vous du lendemain.
- L'IA suggère et explique ; elle ne valide jamais un paiement, une commission, un solde ou une sanction.

### 5.9 Exigences transversales

- Android natif autonome + Web/PWA responsive.
- Hors connexion d'abord ; synchronisation sans doublon au retour du réseau. Le transport et la résolution de conflits doivent être construits/validés, pas supposés déjà présents.
- Français et anglais dès la V1.
- Comptes créés par l'administration ; pas d'inscription libre.
- Contrôle par application, établissement, rôle, appareil et droits ; RLS et contrôles serveur.
- Trois appareils maximum selon la règle du cahier ; le nouvel appareil ferme le plus ancien et notifie le propriétaire.
- Protection de l'APK signé, version minimale, exports datés, filigrane établissement/date.
- Textes/icônes pour chaque état et contraste de texte au moins 4,5:1.
- Données client, photos et documents limités au besoin, consentement et durée de conservation.
- Conditions d'utilisation et confidentialité FR/EN ; validation juridique locale avant premier client payant.

### 5.10 Points ouverts du cahier à ne pas transformer en décisions

- Barème des commissions par prestataire.
- Durée de conservation des vêtements non retirés et étapes de relance.
- Prix et paliers de l'offre marqués `[P]` dans le cahier.
- Règles TVA/SYSCOHADA à confirmer.
- Conditions exactes des acomptes, annulations et absences.
- Autorisation juridique éventuelle de la roue promotionnelle.
- Arbitrage sur parrainage client natif, hors tout module JOBLY Partner.

## 6. Réemploi NAXA proposé pour NAXA SERVICES — sans collision

| Besoin NAXA Services | Source existante | Réemploi autorisé | Ne pas copier |
|---|---|---|---|
| Catalogue et parcours de demande | `home_service_offers`, `home_service_requests`, catalogue et actions Prestations | Patterns de CRUD, validation, statuts, snapshots de prix, recherche et disponibilité | Tables `partners`, `partner_members`, `partner_type=professionnel_domicile`, marketplace publique et géolocalisation médicale |
| Rendez-vous et disponibilités | `scheduled_at`, confirmation par créneau, disponibilité hebdomadaire | Règles de créneau, fuseau `Africa/Douala`, transitions transactionnelles | Relations métier et autorisations du professionnel à domicile |
| Rappels et notifications | `home_service_reminder_preferences`, `home_service_reminder_dispatches`, outbox Push, cron | Scheduler, file, retries, déduplication, notifications in-app/Push et préférences à adapter | Destinataires partenaires et contenus propres à l'ancien catalogue |
| Caisse et paiements | POS/caisse, calculs, clôture, journaux, flux de preuve SMS | Patrons transactionnels, idempotence, reçu, audit, ouverture/clôture | Tables pharmacie, stock pharmaceutique, comptes et règles assureur ; paiement d'abonnement Promoteur |
| Comptabilité et exports | `src/lib/compta`, rapports comptables, PDF/CSV, mapping SYSCOHADA | Formules et pipeline d'export après mapping NAXA Services et tests | Compte comptable ou mapping Pharmacie supposé identique |
| BI / IA | `RapportsALaDemande`, RPC d'agrégats, architecture J'IA NAXA | Synthèse d'agrégats, limites, coûts et validation humaine | Données patients, pharmacie ou contexte métier de l'ancien produit |
| Notifications UI | `public.notifications`, `useNotifications`, Push FCM/WebPush | Contrats et service de distribution existants après audit | Dupliquer un deuxième centre de notifications |
| Fondation Famille | contrats, shells 10 apps, design system, core-android, RLS candidate, files offline | Étendre le générateur et les packages communs après preuve | Créer une deuxième identité, un deuxième système de rôles ou un backend parallèle |

### Règles de non-collision

- Le propriétaire des données NAXA Services doit être un espace opérationnel Famille propre à cette application (établissement, employés, clients, prestations, dépôts, rendez-vous, caisse), soumis au claim/app scope et aux droits Famille.
- Ne pas réutiliser les entités `partners`/prestataires à domicile pour représenter un salon, un pressing ou ses employés.
- Ne pas créer un second moteur de notifications, de paiements, d'audit, de comptabilité ou de reporting si l'actif canonique NAXA peut être étendu.
- Une API ou une fonction n'est réutilisée qu'après audit de son autorisation, de ses dépendances et de ses effets de bord ; jamais par simple copie de fichier.
- Un service technique partagé n'implique aucun partage des données, identités ou permissions entre applications.
- La gestion centrale se limite aux métadonnées et licences ; pas d'accès général aux dossiers clients ou aux opérations des établissements.

## 7. Découpage de livraison recommandé

### J0 — Socle à valider une seule fois
Identité de l'application, établissement et membres, RLS, audit, configuration FR/EN, design, appareils, contrats offline et notification. Le cahier dit que le socle vient de KIOSKO ; cela ne signifie pas qu'il faut attendre que toute l'application KIOSKO soit terminée : extraire et valider les fondations réellement communes.

### J1 — Noyau exploitable NAXA SERVICES
Catalogue distinct pressing/coiffure ; fiche client minimale ; caisse avec paiement, reçu, ouverture/clôture ; ticket de dépôt pressing et transitions ; affectation d'un service à un employé ; journal opérationnel ; écran de synthèse quotidien.

### J2 — Agenda et exploitation quotidienne
Agenda, disponibilités, créneaux confirmés, acompte, rappels, annulation/absence/liste d'attente ; commissions ; dépenses ; consommables légers ; vêtements non retirés.

### J3 — Gestion avancée
Fidélité hors parrainage, QR selon arbitrage, comptabilité/exports, multi-salons, briefings détaillés, IA, challenges et roue promotionnelle sous réserve juridique et décision écrite.

**Critère de sortie J1 :** un salon/pressing pilote peut créer une prestation, enregistrer une opération ou un dépôt, suivre un ticket jusqu'au retrait, affecter la prestation à un employé, encaisser et clôturer la caisse, avec audit et fonctionnement local contrôlé. Le pilote doit prouver les workflows réels, pas seulement afficher les écrans.

## 8. Ordre de travail et contrôles avant intégration

1. Geler l'inventaire des actifs NAXA et vérifier leurs contrats/dépendances sur le HEAD courant de `NAXA/main`.
2. Définir le modèle de données NAXA Services dans le contexte Famille sans reprendre les tables partenaires/pharmacie.
3. Écrire les migrations additives et tests RLS sur environnement éphémère/Replay autorisé uniquement.
4. Construire d'abord J1 ; tests unitaires, SQL/RLS, multi-établissements, offline, reçus et caisse.
5. Raccorder les notifications, exports et rapports canoniques.
6. Faire une recette avec un pressing et un salon réels avant J2/J3.
7. Réintégrer les leçons validées au générateur `scripts/bootstrap-foundations.mjs` et aux packages communs, pour les autres applications.

## 9. Sources vérifiées

### FAMILLE-NAXA
- `docs/ARCHITECTURE_CIBLE.md` — dix apps, cibles, Supabase et garde-fous.
- `docs/CONTINUITE_FAMILLE_NAXA.md` — état des fondations et éléments incomplets.
- `7 famille naxa/01-cahiers-des-charges/04-naxa-services.md` — cahier NAXA Services v1.0.
- `7 famille naxa/02-prompts/04-naxa-services.md` — prompts 4.1 à 4.7.
- `packages/contracts`, `packages/design-system`, `packages/offline-web`, `packages/core-kotlin`, `packages/core-android`, `packages/billing-core`.

### NAXA historique
- `docs/security/AUDIT_FAISABILITE_360_NAXA_SECURITE_INTELLIGENTE_2026-11-07.md`.
- `docs/security/SUIVI_LOTS12_20_RESTANTS.md`.
- `docs/security/PHASE2_...` à `PHASE16_...` selon les lots.
- `services/security-gateway/`, `src/app/api/security/`, `src/components/pharmacie/Security*.tsx`, `supabase/migrations/20261108*security*` à `20261109*security*`.
- `docs/audits/AUDIT_360_PRESTATIONS_DOMICILE_2026-11-11.md` et migration `20261111160000_home_services_appointments_reminders.sql`.
- `docs/architecture/RAPPORTS_BI_IA_NAXA.md`, composants caisse/compta et `src/app/api/rapports/route.ts`.

### Limites de cet audit
- Le document de suivi NAXA Security lu est daté du 9 novembre ; le dépôt NAXA `main` contient des commits ultérieurs jusqu'au 20 novembre. Le statut exact du HEAD actuel et la recette sur matériel réel restent à revalider.
- Les PDF autonomes Cahier des charges NAXA Security et Prompts Security sont présents dans le dépôt source ; leur lecture détaillée page par page est à compléter avant le chantier de développement Security. Les conclusions de maturité ci-dessus s'appuient sur les rapports techniques Markdown et les fichiers de code recensés.
- Cet audit ne constitue pas un audit juridique, un test de production, ni une recette sur équipements physiques.
- Aucun code applicatif, schéma de données réel, migration Supabase, configuration externe, déploiement ou APK n'a été modifié.

