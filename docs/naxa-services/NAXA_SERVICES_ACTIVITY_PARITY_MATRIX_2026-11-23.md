# NAXA SERVICES — matrice de couverture des activités métiers

**Date initiale : 23 novembre 2026 — dernière preuve : 25 novembre 2026**  
**Branche :** `work/naxa-services-completion-20261120`  
**Statut :** VERT pour le cœur des 13 parcours de dossiers métiers et leurs contrôles CI Web / Android / PostgreSQL ; PARTIEL pour la couverture complète des modules ERP partagés et les intégrations hébergées.

## 1. Règle d'architecture

NAXA SERVICES est un ERP multisecteur, et non un logiciel Pressing étendu. Il repose sur :
- un socle partagé : organisation, sites, postes, clients, catalogue/prestations, agenda, caisse et paiements, équipe, stock, achats/fournisseurs, fidélité, rapports, notifications et assistance ;
- des parcours propres au métier : formulaires, champs obligatoires, objets métier, états, règles de passage, ressources et indicateurs ;
- un cloisonnement par organisation, site et poste selon le rôle et les permissions ; la réception d'un événement serveur ne doit jamais élargir ce périmètre.

Le registre Web de référence est `apps/web/naxa-services/src/erp/activity-workflows.ts`. Il décrit les 13 profils autorisés par `naxa-services-auth/scope_contract.ts`. Il ne remplace pas les invariants SQL, les règles Android ou les validations serveur : ces trois couches doivent rester alignées.

## 2. Matrice des profils

| Profil | Parcours principal | Données métier spécifiques | Objet de dossier | Cycle métier |
|---|---|---|---|---|
| Pressing / blanchisserie | Dépôt par ticket et pièces | Pièces/quantités, textile et entretien, taches/défauts, date promise, acompte demandé | `pressing_order` | Reçu → traitement → prêt → retiré |
| Coiffure | Rendez-vous puis prestation | Style/coupe, technique/longueur, coiffeur, fauteuil, produits/accessoires | `service_order` | Accueil → confirmé → en cours → contrôle → prêt → remis → clôturé |
| Couture / retouche | Commande et production | Vêtement/modèle, mensurations, tissu/fournitures, essayage, échéance | `work_order` | Reçu → mesures/étude → devis/accord → fournitures → confection → essayage/contrôle → prêt → livré |
| Beauté / esthétique | Rendez-vous et soin | Soin/formule, protocole commercial non médical, prestataire, cabine, produits | `service_order` | Accueil → confirmé → soin → contrôle → terminé → remis → clôturé |
| Parfumerie | Vente au comptoir ; réservation spéciale si nécessaire | Produit, référence, contenance/coffret, famille olfactive, lot/référence fournisseur | Vente via POS/stock ; réservation spéciale `work_order` | Réservation → disponibilité/devis → confirmation → réapprovisionnement → préparation → retrait |
| Réparation / dépannage | Prise en charge et ordre de réparation | Appareil/marque/modèle/série, panne, diagnostic, pièces, garantie et restitution | `repair_order` | Reçu → diagnostic → devis/accord → pièces → réparation → tests/contrôle → prêt → restitué |
| Menuiserie / fabrication | Ouvrage sur mesure | Ouvrage, dimensions/plan, bois/panneaux/quincaillerie, finition, pose | `work_order` | Demande → étude → devis/accord → matières → fabrication → finition → installation → réception |
| Garage / mécanique | Entrée véhicule et réparation | Véhicule/immatriculation, kilométrage, panne/travaux, diagnostic, pièces, essai/restitution | `repair_order` | Véhicule reçu → diagnostic → devis/accord → pièces → réparation → essai/contrôle → prêt → remis |
| Nettoyage / entretien | Contrat et interventions récurrentes | Site/adresse/zones, tâches/fréquence/niveau de service, équipe, matériel, checklist | `service_order` | Demande → devis/contrat → validation → planification → sur site → intervention → contrôle → réception |
| Services à domicile | Intervention à une adresse | Adresse/quartier/repère, prestation et accès, intervenant, matériel, créneau | `service_order` | Demande → devis/accord → planification → arrivée → intervention → validation → réception |
| Imprimerie / reprographie | Commande de production | Format/support/dimensions, quantité, couleurs, épreuve, finition/façonnage | `work_order` | Commande → devis/épreuve → validation → production → contrôle → prêt → remis |
| Photo / événementiel | Prestation planifiée et livrables | Événement/lieu/date, forfait et livrables, équipe, matériel/logistique | `work_order` | Demande → devis/confirmation → préparation → captation → post-production → contrôle → livraison |
| Autre activité | Parcours configurable par l'organisation | Prestation/commande, spécifications, ressources, consignes, échéance | `work_order` | Reçu → devis/validation → exécution → contrôle → prêt → livré |

### Précisions structurantes

- **Pressing** conserve son ticket de dépôt dédié. Il ne sert pas de modèle aux autres secteurs et les transitions d'aperçu Web ne sont pas des opérations réelles.
- **Parfumerie** est d'abord du commerce : catalogue, variantes/références, stock, fournisseurs/achats et vente/encaissement. Le dossier métier sert uniquement aux commandes spéciales et réservations. Aucun formulaire de réservation ne doit être assimilé à une vente ou à un paiement.
- **Coiffure et beauté** s'appuient sur agenda, prestataires et postes/cabines. Les horaires, capacités et collisions restent contrôlés par le moteur d'agenda ; un dossier de service ne les remplace pas.
- **Nettoyage et domicile** réutilisent le même type `service_order`, mais conservent leurs propres champs, fréquences, adresses et cycles.
- **Réparation et garage** réutilisent `repair_order`, avec des champs différents selon le bien pris en charge.
- **Photo/événementiel** est un cycle de production `work_order`, afin que captation et post-production soient autorisées par la matrice SQL.
- Pour la beauté, aucun antécédent, diagnostic ou donnée médicale ne doit être collecté dans ce dossier opérationnel. Les données de mensurations et d'identification d'équipement doivent être limitées au besoin et aux rôles autorisés.

## 3. Travaux de cette passe

### Registre métier Web
- Définition centralisée des 13 profils, libellés, champs, champs obligatoires, parcours, étapes, ressources partagées et notes de prudence.
- Fonctions de normalisation et validation des profils, résolution des étapes et contrôle des transitions.
- Tests Vitest sur l'exhaustivité des 13 profils, l'absence de repli silencieux vers Pressing, les champs obligatoires et des transitions propres à chaque famille.
- Session Web : lecture du profil transmis par Auth ; tout profil absent ou inconnu tombe sur `autre`, jamais sur Pressing.

### Web / PWA
- Nouveau module « Dossiers métier », généré depuis le profil de l'organisation.
- Formulaires Web spécialisés par profil ; données métier conservées dans `metadata_json` versionné.
- Création via la file IndexedDB et le contrat `apply_sync_event`, avec types `work_order`, `repair_order` et `service_order`.
- Transitions Web versionnées : contrôle du graphe côté client, motif obligatoire, `expected_version` et reçu serveur requis avant une transition ultérieure.
- Projection des dossiers provenant d'un autre appareil dans le même registre métier.
- Métadonnées de dossier limitées sous le plafond serveur de 4 Ko ; aucun acompte demandé n'est présenté comme encaissé.
- Pressing reste un module à part ; ventes et encaissements de parfumerie restent exclus de la fiche de réservation.

### Android
- Accès au module Ordres de travail désormais ouvert aussi pour coiffure, beauté et parfumerie ; le pressing conserve son écran dédié.
- Les profils de coiffure/beauté utilisent `service_order`, réparation/garage `repair_order`, domicile/nettoyage `service_order`, photo/événementiel, couture, menuiserie, imprimerie et autre `work_order`.
- Champs opérationnels requis avant création (au moins le sujet métier principal et les spécifications) ; le libellé du prestataire est explicitement indicatif et ne crée pas une affectation RH.
- L'acompte demandé est conservé comme information de demande ; `paid_xaf` reste à zéro tant qu'aucune vraie mutation de paiement ne l'a confirmé.

### Contrat serveur candidat
- La matrice de transitions de `supabase/drafts/naxa_services_v4_supplier_accounting_forecast.sql` a été alignée sur les étapes couture, menuiserie, impression, événementiel, réparation, coiffure/beauté, interventions nettoyage/domicile et activités configurables.
- Le contrat de synchronisation a reçu des tests create/status-change pour `work_order`, `repair_order` et `service_order`, ainsi que des cas de spoofing d'identifiant et d'écart de site.
- **Ce SQL est un brouillon non déployé.** Aucun environnement Supabase n'a été modifié.

## 4. Matrice de statut réelle — mise à jour du 25 novembre 2026

| Couche | État | Preuve et portée exacte |
|---|---|---|
| Inventaire des activités | VERT | 13 profils présents dans le registre Web et le catalogue Android ; profils comparés : 13/13 identiques. |
| Formulaires et champs Web | VERT | Champs typés, obligatoires, listes contrôlées, nombres, dates et zones de texte. Les 12 profils génériques et le Pressing dédié sont exercés dans la recette Chromium. |
| Cycles Web des dossiers métier | VERT | E2E : les 12 parcours génériques sont créés puis suivis jusqu'à leur état terminal closed ; le Pressing est créé puis avancé jusqu'à picked_up. Chaque transition attend le reçu serveur simulé et vérifie l'état affiché. |
| Web / PWA | VERT | Build de production, tests Auth et 5/5 scénarios Chromium réussis : parcours métiers, reprise offline, isolation organisation, IndexedDB multi-onglets et shell PWA hors ligne. |
| Catalogue et validations Android | VERT | Catalogue Kotlin des 13 profils ; tests unitaires des champs, enums, bornes, dates, graphes de transitions, états terminaux et compatibilité des anciens dossiers. |
| Android Debug / émulateur | VERT | Tests unitaires, compilation APK Debug et 11 tests instrumentés sur émulateur API 35 (Keystore/PIN, login, Room/outbox et registre Push) réussis. APK téléversé comme artefact CI. |
| Contrat SQL candidat | VERT CI jetable | Drafts appliqués à PostgreSQL 17 jetable ; validations des champs et transitions, création Garage synchronisée, rejet d'un saut d'étape, acceptation de diagnostic et contrôle de la révision/état serveur. RLS/runtime réussi. |
| Contrats transversaux | VERT CI | Auth, synchronisation hors ligne, parrainage, tarifs, comptabilité/fournisseurs, sécurité statique, notifications, paiements, commissions, fiscalité et promotions réussis. |
| Modules ERP partagés | PARTIEL | Les cycles complets agenda/disponibilités, caisse/POS/paiements/reçus, achats/réception/fournisseurs, consommation de stock, CRM/fidélité, RH/commissions et rapports détaillés ne sont pas tous raccordés de bout en bout pour chaque secteur. |
| Parité ERP totale Web ↔ Android | PARTIEL | Les registres métier, champs et cycles d'étapes sont alignés ; la preuve ne couvre pas encore chaque transaction des modules partagés sur deux applications physiques et un backend hébergé commun. |
| Environnement Supabase NAXA Services dédié | BLOQUÉ EXTERNE | Aucun projet dédié n'est déployé par cette passe. Le SQL candidat a été exécuté uniquement sur PostgreSQL 17 jetable ; le Supabase historique NAXA/pharmacie n'a pas été modifié. |

## 5. Scénarios exécutés et scénarios encore ouverts

### Preuves exécutées

1. **13 profils** : les 12 profils génériques sont créés avec leurs champs obligatoires et conduits par le graphe Web jusqu'à closed ; le Pressing suit son parcours distinct jusqu'à picked_up.
2. **Validation des données** : tests unitaires Kotlin et validations PostgreSQL des champs requis, valeurs d'énumération, dates et bornes numériques ; cas invalides rejetés.
3. **Transitions et synchronisation serveur** : le runtime PostgreSQL teste la création d'un ordre Garage, refuse le saut received → approved, accepte received → diagnostic avec révision 2 et vérifie l'état stocké.
4. **Web / PWA** : 5/5 tests Playwright réussis, dont outbox après fermeture d'onglet, cloisonnement multi-organisation, deux onglets concurrents, curseurs entrants et navigation PWA hors ligne.
5. **Android** : tests unitaires, APK Debug et 11 tests instrumentés Keystore/PIN, login, migrations/outbox et Push réussis sur émulateur API 35.
6. **Sécurité serveur** : schémas, droits, isolation organisation/site et RLS runtime exécutés sur une base PostgreSQL 17 jetable.

### Limites non couvertes par ces preuves

- Le simulateur backend de l'E2E Chromium valide le contrat navigateur et les reçus attendus ; il ne remplace pas une recette hébergée contre le projet Supabase NAXA Services.
- Le scénario serveur métier positif de cette passe porte sur Garage ; les validateurs et transitions des 12 profils sont testés directement, mais toutes les combinaisons de transitions et tous les agrégats ne font pas encore l'objet d'une recette transactionnelle serveur exhaustive.
- La synchronisation fournisseur Android entre deux bases Room est couverte par un test instrumenté, mais la réplication croisée de chacun des 13 parcours métiers entre Android, Web et Supabase hébergé reste à réaliser.
- Les 13 parcours de dossiers ne remplacent pas les cycles de réservation/agenda, caisse, ventes, paiements, factures, approvisionnement, stock, fidélité, paie, commissions et reporting. Ces modules doivent rester pilotés par leurs objets et transactions dédiés.

### Scénarios métier complémentaires à fermer

- Pressing : dépôt multi-pièces avec défauts/taches, retrait, conservation et relance des pièces non retirées.
- Parfumerie : SKU/variantes, réception fournisseur, vente POS, décrément de stock et paiement confirmé ; réservation distincte de la vente.
- Coiffure/beauté : disponibilité du prestataire et du poste, rendez-vous, durée, collision, annulation et commission sur vente réglée.
- Garage/réparation : état et accessoires au dépôt, devis accepté/refusé, sortie de pièces, test, garantie paramétrée et restitution.
- Nettoyage/domicile : contrat ou récurrence, créneau, adresse, équipe affectée, checklist et preuve de passage.
- Imprimerie/photo/production : épreuve ou preuve, accord, ressources, consommation, production, contrôle, livrables et réception.

## 6. Points non résolus / décisions à ne pas inventer

Les valeurs suivantes restent configurables ou à arbitrer avant leur automatisation : prix et taxes ; acomptes obligatoires ou facultatifs ; annulation et remboursement ; délais de conservation ; durée de garantie ; fréquence contractuelle ; grille de commissions ; règles d'indemnisation ou de déplacement ; documents et consentements spécifiques. Les champs libres ajoutés dans les dossiers ne remplacent pas les référentiels normalisés (articles, temps, ressources, paiements, factures, stocks).

La présente matrice n'autorise aucune collecte de données disproportionnée. Le cloisonnement par rôle/site, la politique d'export et la conservation des dossiers, plans, mensurations et preuves doivent être testés avec les permissions du serveur.

## 7. Reprise N4 — ordre des travaux restant

- **N4-C — modules partagés** : poursuivre séparément les disponibilités/transitions d'agenda, la caisse complète, les ventes/paiements/reçus, les fournisseurs/achats/réceptions, le CRM/fidélité, l'équipe/commissions, les mouvements de stock et les projections détaillées.
- **N4-D — activité métier** : les gates CI Web/Chromium, Android Debug/API 35 et PostgreSQL 17 du cœur des dossiers métiers sont VERTS sur le SHA indiqué ci-dessous. Ne pas rouvrir ces points sans changement de code ; toute modification ultérieure doit relancer le gate complet.
- Garder les mutations sans handler serveur fail-closed.
- Aucun run pending ou in_progress ne vaut PASS ; aucun environnement réel, secret marchand ou compte Firebase ne doit être supposé.

**Garde-fous inchangés :** travail sur work/naxa-services-completion-20261120 uniquement ; aucun changement de main, aucune fusion, aucun déploiement, aucune migration hébergée et aucune modification du Supabase NAXA pharmacie historique.

## 8. Addendum de preuve — 25 novembre 2026

**Exécution GitHub Actions :** [run #567 — succès complet](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45530039938)  
**SHA validé :** cd0a4eaae76d5da44aabd88c363d9ab2fd1541ff  
**Résultat :** 12/12 jobs terminés avec success.

- **Web/PWA** : tests Auth 24/24 ; build Vite réussi ; Playwright/Chromium 5/5 ; scénario métier couvrant les 12 profils génériques et le Pressing dédié ; offline/IndexedDB multi-onglets et shell PWA hors ligne réussis.
- **Android** : tests unitaires réussis ; APK Debug construit ; 11/11 tests instrumentés sur émulateur API 35 réussis ; artefact [naxa-services-debug-apk](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45530039938/artifacts/14985375669) téléversé (13 718 905 octets).
- **PostgreSQL** : drafts candidats appliqués à une base de test PostgreSQL 17 jetable ; tests runtime/RLS, validations des profils et synchronisation Garage réussis.
- **Contrats complémentaires** : Auth, sync inter-applications, parrainage, tarifs, comptabilité/fournisseurs, sécurité SQL statique, notifications, paiements/commissions/fiscalité et promotions réussis.

**Périmètre du vert :** le cœur des dossiers métiers est vert en CI. Cela ne transforme pas en vert les modules ERP partagés non encore livrés intégralement, l'intégration sur un projet Supabase hébergé, les webhooks Mobile Money réels, le push FCM réel, une Release Android signée ni les validations comptables, fiscales, juridiques et physiques qui requièrent des paramètres ou accès externes. Aucun déploiement et aucune migration sur le Supabase NAXA pharmacie n'ont été effectués.
