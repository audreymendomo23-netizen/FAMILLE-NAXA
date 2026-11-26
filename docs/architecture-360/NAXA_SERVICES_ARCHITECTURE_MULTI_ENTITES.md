# NAXA SERVICES — architecture fonctionnelle et hiérarchique 360°

Version de construction : 1.0 — 20 novembre 2026  
Statut : architecture construite, sous réserve des tests Auth/RLS et recettes métier.

## 1. Périmètre

NAXA Services est un ERP de prestations pour pressing et salon de coiffure. Les deux activités cohabitent dans une même organisation lorsque nécessaire, mais leurs workflows restent distincts.

- Pressing : dépôt, ticket, pièces, tarif par type de vêtement, acompte, date promise, étiquette, progression reçu → en cours → prêt → retiré, relances et conservation.
- Coiffure : catalogue, durée, coiffeur habilité, agenda par prestataire ou poste, réservation, acompte, annulation, absence, attente, fidélité et forfaits.
- Commerce : clients, ventes, caisse, paiements confirmés, reçus, dépenses, personnel, commissions, consommables, rapports, comptabilité et briefings.

Aucun matériel n'est livré par NAXA. L'impression Bluetooth et les notifications externes sont des intégrations facultatives. Un paiement Mobile Money n'est considéré comme payé qu'après preuve fiable de confirmation. L'IA ne confirme jamais un paiement et ne modifie jamais un solde.

## 2. Trois modes d'exploitation

### A — PME autonome
Une organisation → un point de vente → un ou plusieurs postes de travail. Le propriétaire/gérant administre son établissement. Caisse, stock, équipe, clients et rapports restent dans ce point. Aucun accès à un autre client NAXA Services.

### B — Responsable multi-emplacements dans un même lieu
Une organisation → un point de vente physique → plusieurs emplacements (fauteuils, postes coiffure, comptoirs, zones pressing, ateliers ou équipes).
- Le responsable dispose d'une vue consolidée du même établissement.
- Chaque emplacement possède son planning, ses ressources, ses employés et ses indicateurs.
- Les rendez-vous et travaux sont affectés à un emplacement et, si nécessaire, à un prestataire.
- La caisse et le stock sont partagés au niveau du point de vente par défaut ; une analytique par emplacement est possible, sans dupliquer la caisse.
- Les opérations gardent leur emplacement et leur point de vente d'origine.

### C — Promoteur multi-points de vente autonomes
Une organisation mère → plusieurs points de vente autonomes → plusieurs postes par point.
- Le Promoteur voit une consolidation du réseau et peut ouvrir les détails des sites relevant de son organisation.
- Chaque site garde sa caisse, ses sessions, ventes, dépenses, stocks, équipe, rendez-vous, tickets et paramètres.
- Aucun solde, encaissement, commission, remise ou stock n'est fusionné entre deux sites.
- Un transfert inter-sites est explicite, justifié, validé et audité.
- Le responsable d'un site ne voit que ses sites autorisés ; il ne devient pas responsable réseau par défaut.
- Le réseau peut distribuer un catalogue modèle ; chaque site conserve son catalogue effectif daté et son historique d'exceptions.
- Les rapports consolidés sont en lecture ; les écritures restent toujours rattachées au site.

## 3. Entités canoniques

| Entité | Responsabilité |
|---|---|
| Organisation | Tenant contractuel et propriétaire des données |
| Compte d'accès | Identité NAXA Services distincte des autres applications |
| Membre / scope | Utilisateur individuel et périmètre d'accès |
| Point de vente | Unité autonome caisse, stock, équipe, opérations et reporting |
| Emplacement | Poste, fauteuil, comptoir, atelier ou zone dans un site |
| Catalogue | Prestations, forfaits, consommables et produits comptoir |
| Client | Clientèle de l'organisation/site |
| Rendez-vous | Prestation réservée à un site, un poste et un prestataire |
| Ticket pressing | Dépôt, pièces et historique append-only |
| Vente / paiement | Encaissement et preuve au site/caisse d'origine |
| Session caisse | Ouverture, clôture, écarts et justification |
| Commission | Calcul daté et rattaché à une prestation exécutée |
| Audit | Historique des opérations sensibles, sans secret |

Montants en entiers FCFA. Les corrections, annulations, mouvements de stock et transitions sensibles sont traçables ; pas de réécriture silencieuse du passé.

## 4. Rôles

| Rôle | Scope | Responsabilités |
|---|---|---|
| Promoteur | Organisation | Sites, consolidation, responsables, politiques globales |
| Responsable réseau | Sites délégués | Supervision consolidée et détails des sites autorisés |
| Responsable site | Un point | Equipe, agenda, catalogue effectif, caisse selon délégation |
| Responsable emplacements | Postes assignés dans un site | Planning, ressources, affectations et indicateurs |
| Caissier | Caisses assignées | Encaissement, reçu, ouverture/clôture autorisée |
| Réceptionniste | Accueil / dépôt / réservation | Clients, tickets, rendez-vous, retraits |
| Coiffeur | Prestations attribuées | Agenda personnel, prestations, commissions personnelles |
| Opérateur pressing | Atelier/tickets assignés | Progression, contrôle, prêt |
| Gestionnaire stock | Site autorisé | Consommables, entrées, sorties et inventaire |
| Comptable | Scope délégué, lecture | Rapports et exports ; aucun encaissement |

Les permissions sont des capacités explicites. Clôture, remise, annulation, remboursement, changement de prix, reset de compte et transfert inter-sites nécessitent droits distincts, motif et audit. L'administration centrale Famille NAXA ne peut consulter les clients, ventes, tickets, caisses ou données opérationnelles.

## 5. Authentification et appareils

- Identifiant d'accès généré propre à NAXA Services + mot de passe personnel.
- Aucun OTP, SMS de connexion, e-mail, boîte mail, magic link ni inscription publique.
- Création de compte par un administrateur/responsable habilité ; changement obligatoire du mot de passe initial.
- « Rester connecté sur cet appareil » : jeton de renouvellement conservé dans un coffre Android Keystore ; décoché, session mémoire seulement.
- Mot de passe oublié : demande interne sans code ni lien automatique ; contrôle d'identité hors bande par un agent habilité, reset serveur, révocation des sessions et changement obligatoire à la prochaine connexion.
- La biométrie ou le PIN local protège l'ouverture d'une session déjà enrôlée ; ce n'est pas une preuve d'identité distante.
- Limitation progressive, anti-énumération, suivi des appareils, révocation distante et audit.

Réserve active : l'identifiant doit être résolu côté serveur vers un alias Auth opaque. La compatibilité GoTrue et l'absence de tout e-mail sortant doivent être prouvées en local avant le statut opérationnel. Le client Android est conçu sur un contrat Edge Function dédié ; aucune configuration Supabase réelle n'est modifiée.

## 6. Pages ERP à construire

1. Accueil / tableau de bord et briefings.
2. Agenda jour/semaine, filtres site/poste/prestataire, disponibilités et liste d'attente.
3. Rendez-vous : création, acompte, confirmation, déplacement, annulation et historique.
4. Pressing : ticket, pièces, tarifs, acompte, date promise, étiquette, statuts et retrait.
5. Caisse/POS : ventes, espèces, Mobile Money confirmé, paiement mixte, reçus, ouverture/clôture, écarts et dépenses.
6. Prestations/catalogue : catégories, prix, durées, habilitations, forfaits et produits comptoir.
7. Clients : fiche, historique, préférences, fidélité, QR, anniversaires et inactivité.
8. Equipe : profils, habilitations, affectations, présence, avances, primes et commissions.
9. Consommables : stock léger, mouvements, consommation, seuils et inventaire.
10. Rapports : ventes, marges contributives, agenda, fréquentation, tickets, caisse, commissions et exports.
11. Organisation / PME : profil, activité, paramètres, abonnement/entitlements.
12. Réseau : points de vente, responsables, consolidation et comparaison.
13. Site : caisse, stock, équipe, catalogue effectif et paramètres.
14. Emplacements : postes, fauteuils, comptoirs, ateliers, horaires et ressources.
15. Sécurité & appareils : accès, sessions, récupération et journal.
16. Paramètres : langues, thèmes, imprimantes, notifications et hors connexion.
17. Assistance et briefings.

## 7. Règles métiers

- Pressing : reçu → en cours → prêt → retiré. Transition inverse ou retrait anticipé soumis à autorisation et motif.
- Agenda : vérifier chevauchements prestataire/poste, horaires, durée, absence et acompte avant confirmation.
- Caisse : session ouverte par caisse selon politique ; mouvements idempotents ; clôture avec attendu/réel/écart/motif ; session fermée non réécrivable.
- Mobile Money : preuve de confirmation ou rapprochement autorisé ; ni IA ni saisie non vérifiée ne peuvent confirmer.
- Commission : règle datée appliquée à une prestation exécutée et éligible ; base et calcul visibles.
- Stock : unités adaptées, sorties justifiées, seuils et alertes ; pas d'inventaire code-barres lourd en V1.
- Offline : UUID + clé d'idempotence, file append-only, conflits explicites et délai d'autorisation borné.
- Réseau : consolidation en lecture seule par défaut ; chaque écriture sur son site ; transferts inter-sites explicites.

## 8. Abonnements et entitlements

Les tarifs du cahier du 31 octobre sont [P] à tester, pas des prix approuvés. Capacités candidates à lier au moteur Famille Billing/Entitlements après audit (sans doublon) : limite de sites, membres/site, emplacements, agenda, commissions, fidélité, exports comptables, consolidation réseau, IA et jours offline. L'entitlement ne remplace jamais RBAC/RLS.

## 9. Architecture technique

- Android Kotlin/Jetpack Compose, base locale et synchronisation après contrat offline validé.
- Web responsive/PWA dans apps/web/naxa-services.
- Backend Supabase Famille partagé après inventaire, avec tables métier dédiées NAXA Services et RLS stricte.
- UI → use cases → repository → Edge Function/RPC → tables RLS.
- Fonction d'auth proposée : naxa-services-auth ; secrets Admin/service_role uniquement côté serveur.
- Ne pas copier pharmacies, partners, partner_members, prescriptions ni rôles pharmaceutiques du NAXA historique.
- JOBLY est une référence technique secondaire ; aucun domaine Talent/Recruiter/Partner/referral n'est repris.

## 10. Jalons

| Jalon | Contenu | Critère de sortie |
|---|---|---|
| J0 | Identifiants, sessions, appareils, récupération, membres/scopes | Tests alias, remember-me, reset, révocation et isolation |
| J1 | Catalogue, clients, caisse, tickets pressing, membres | Dépôt → retrait, vente → encaissement → clôture, audit |
| J2 | Agenda, rendez-vous, équipe, commissions, consommables | Chevauchements, affectations, commissions, offline |
| J3 | PME, emplacements, multi-sites, rapports, exports, IA | Tests négatifs entre sites et consolidation |
| J4 | Observabilité, sauvegarde, sécurité, performance, accessibilité | Tests sur appareils réels et pilotes |

## 11. Réserves empêchant le vert complet

1. Alias GoTrue non encore prouvé localement.
2. Edge Function source inclut login, refresh, demande de recovery, provisioning membre, reset Admin et révocation appareil ; elle n'est pas déployée et reste à tester.
3. SQL ci-joint = draft non appliqué ; fonctions d'identité, liaison session/appareil et policies RLS sont écrites dans le draft, mais doivent être relues et testées en PostgreSQL isolé avec rôles/sites de test.
4. Builds Android/Web, tests unitaires, scénarios négatifs et sync à exécuter localement.
5. Commissions, conservation des vêtements, fidélité, durée des sessions, offline, nombre d'appareils et tarifs [P]/[O] restent à arbitrer.
6. Logo binaire spécifique non récupéré de façon fiable par le connecteur pendant cette passe. Le SVG livré est reconstruit depuis la spécification écrite (N rouge, NAXA blanc, SERVICES sur noir) ; remplacer par l'original exact s'il se trouve dans l'archive graphique non lisible.
7. Impression Bluetooth, WhatsApp, Mobile Money, Push et IA restent derrière adaptateurs non déclarés connectés à un fournisseur réel.

État : architecture documentée ; UI/contrats en construction ; technique sous réserve ; recette non exécutée ; Production inchangée.


## Planning hiérarchique et service-écart — arbitrage du 26 novembre 2026

**Champ d'application.** Les 13 activités utilisent un socle commun. Mode A `solo` : aucun menu, écran ou accès API de planning hiérarchique, pointage probant employeur ou service-écart. L'agenda commercial reste distinct. Modes B `single_site_multi_workstation` et C `multi_site_network` : planning personnel pour tout compte actif et planning d'équipe pour les supérieurs habilités. Le promoteur pilote le réseau, le responsable réseau les sites délégués, le responsable site son établissement et le responsable emplacement ses postes uniquement. Un supérieur ne confirme pas la réception à la place d'un subordonné. Les droits d'abonnement et de session restent distincts des scopes.

**Fonctions.** Créer, publier, modifier et annuler des services; affecter un salarié à un site/poste autorisé; heures de début et fin, pause prévue, tolérance paramétrable, motif et versions immuables. Services de nuit possibles; chevauchements d'un même salarié interdits entre sites. Envoi ciblé à chaque nouvelle version: notification dans la boîte interne durable et push FCM en file via le moteur existant; distinguer disponibilité dans la boîte, envoi push, lecture et accusé explicite de la version courante. L'accusé est idempotent et ne vaut pas accord contractuel. Les changements de dernière minute doivent être visibles dès synchronisation; pas de notification générale des données RH.

**Service-écart.** Relier chaque pointage à une version du service, utiliser les preuves GPS et selfie configurables déjà spécifiées en v9, préserver les événements réels et la version du planning à l'arrivée. Calculer retard, départ anticipé, temps supplémentaire, pause réelle et écarts; signaler les pointages manquants ou ambigus à examiner, jamais conclure automatiquement à une absence ni sanctionner. Le manager peut traiter une justification sans effacer le pointage d'origine. Le promoteur peut modifier le planning même après publication; toute correction est versionnée, motivée et notifiée. Prévoir rotations et modèles hebdomadaires, publication groupée, congés/indisponibilités, remplacement, alertes de conflit avec rendez-vous, rappel avant début, alerte de non-accusé, demande de justification et décision motivée, rapports par site et employé. Pas de modification de salaire automatique; validation RH et juridique requise. Extensions non encore réalisées.

**Implémentation candidate.** Drafts v10 roster, service comparison et directory; composant React dans Équipe et composant Compose sur le dashboard pour tous les rôles actifs B/C, activations de recette explicites `VITE_NAXA_SERVICES_ROSTER_ENABLED=true` et `NS_ENABLE_ROSTER=true`, désactivées par défaut. Ne pas les activer commercialement avant application contrôlée du schéma et recette complète. Tolérance initiale proposée 10 min (0–120), pause paramétrable, durée maximale 24 h, heure Africa/Douala, fenêtre de rapprochement anticipée provisoire de 2 h, aucun appariement ambigu. FR/EN/Fulfulde proposés, relecture linguistique nécessaire. Sécurité RLS, version optimiste, notifications via outbox, vue security_invoker, aucun secret ajouté. Hors connexion, cache sécurisé et signalement d'une version périmée restent à intégrer; aucun envoi de notification physique démontré.
