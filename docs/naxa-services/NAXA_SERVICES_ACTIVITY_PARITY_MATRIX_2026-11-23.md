# NAXA SERVICES — matrice de couverture des activités métiers

**Date : 23 novembre 2026**  
**Branche :** `work/naxa-services-completion-20261120`  
**Statut :** socle multisecteur ajouté et raccordements verticaux engagés ; validation CI en cours, parité ERP totale non encore acquise.

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

## 4. Matrice de statut réelle

| Couche | État après cette passe | Ce que cela signifie |
|---|---|---|
| Inventaire des 13 profils | Code décrit | 13 profils couverts par le registre |
| Champs et cycles spécialisés Web | Implémentés dans le nouveau module | Contrat métier et interface, pas encore une recette E2E verte |
| Création/transition générique Web | Raccordement au journal N3 | Dépend de l'exécution CI et d'un test sur environnement serveur autorisé |
| Écrans métier Android | Champs et transitions existants/alignés | Données locales + outbox ; recette Android de cette passe encore requise |
| Matrice SQL candidate | Brouillon aligné | Pas appliqué, pas d'intégration hébergée |
| Agenda, caisse, ventes, paiement, stock, achats, CRM, RH, fidélité et rapports | Partiel selon module | Les dossiers métier ne livrent pas à eux seuls tous ces cycles partagés |
| Parité complète Web ↔ Android | Non démontrée | Les deux applications doivent réussir les mêmes scénarios sur deux installations |
| Déploiement NAXA Services dédié | Bloqué externe | Aucun projet Supabase dédié connecté n'est disponible dans la connexion actuelle |

## 5. Scénarios de recette à exécuter

Pour chacun des 13 profils :
1. créer une organisation de test avec ce profil, puis vérifier le profil retourné par Auth ;
2. créer un dossier avec les seuls champs obligatoires, rejeter le dossier si un champ requis manque ;
3. vérifier le type de registre, le site source, l'auteur, le montant et les métadonnées ;
4. franchir chaque transition permise et refuser chaque transition interdite ; vérifier motif, révision, idempotence et historique ;
5. synchroniser appareil A → serveur → appareil B puis B → A, sans doublon ni echo ;
6. tester isolation organisation/site, profil absent/inconnu, accès interdit et session/appareil révoqué ;
7. vérifier que les modules partagés (agenda, caisse/paiements, stock, achats, RH, fidélité, rapports) sont appelés via leurs propres transactions et non simulés par le dossier.

Scénarios supplémentaires :
- Pressing : dépôt multi-pièces, tache/défaut, ticket, date promise, retrait et vêtement non retiré.
- Parfumerie : SKU/variante, entrée fournisseur, vente POS, stock décrémenté et paiement confirmé ; réservation spéciale distincte de la vente.
- Coiffure/beauté : disponibilité du prestataire et du poste, rendez-vous, durée, annulation et commission uniquement sur vente réglée.
- Garage/réparation : état du bien au dépôt, devis accepté/refusé, pièce consommée, test, garantie configurée et restitution.
- Nettoyage/domicile : récurrence/contrat ou créneau, adresse, équipe, checklist et preuve de passage.
- Imprimerie/photo/production : preuve/épreuve, accord, ressources, production, contrôle, livrables et réception.

## 6. Points non résolus / décisions à ne pas inventer

Les valeurs suivantes restent configurables ou à arbitrer avant leur automatisation : prix et taxes ; acomptes obligatoires ou facultatifs ; annulation et remboursement ; délais de conservation ; durée de garantie ; fréquence contractuelle ; grille de commissions ; règles d'indemnisation ou de déplacement ; documents et consentements spécifiques. Les champs libres ajoutés dans les dossiers ne remplacent pas les référentiels normalisés (articles, temps, ressources, paiements, factures, stocks).

La présente matrice n'autorise aucune collecte de données disproportionnée. Le cloisonnement par rôle/site, la politique d'export et la conservation des dossiers, plans, mensurations et preuves doivent être testés avec les permissions du serveur.

## 7. Reprise N4

Reprendre au point N4-C puis N4-D sans recommencer le socle N3 :
- N4-C : compléter séparément les modules partagés Web manquants (disponibilité/transition d'agenda, caisse complète, ventes/paiements/reçus, fournisseurs-achats-réception, CRM/fidélité, équipe/commissions, stock et projections détaillées) ;
- N4-D : build Web et Android, tests Vitest/Deno/Kotlin, tests PostgreSQL 17 du SQL candidat, Playwright sur Chromium, puis tests multi-appareils et tests de chaque profil ;
- garder les mutations sans handler en fail-closed ;
- aucun run pending n'est PASS ; aucun environnement réel ne doit être supposé.

**Garde-fous inchangés :** travail sur `work/naxa-services-completion-20261120` uniquement ; aucun changement de `main`, aucune fusion, aucun déploiement, aucune migration hébergée et aucune modification du Supabase NAXA pharmacie historique.
