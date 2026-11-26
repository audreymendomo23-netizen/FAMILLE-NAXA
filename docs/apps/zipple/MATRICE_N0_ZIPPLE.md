# ZIPPLE — Matrice de couverture et réutilisation N0
Statuts : R = réutilisation ciblée après compatibilité, A = adapter, S = spécifique ZIPPLE, D = inspiration documentaire seulement. Le choix de modules a été validé; il ne certifie pas leur fonctionnement.
| Domaine | Source et réutilisation | Android | Web/PWA | Backend / preuve attendue | Niveau |
|---|---|---|---|---|---|
| Identité, accessibilité, i18n | logo + design-system R/A | thème Compose, icônes, mode sombre | tokens, responsive, manifest | contraste et captures FR/EN | N1 |
| Auth, récupération, session, PIN, biométrie | NS AuthApi, SessionVault, LocalAccessPin R/A | écrans natifs | session Web et sécurité adaptée | contrôle app/org/site, révocation, RLS négative | N1 |
| Organisation, sites, postes, équipe | NS ErpModules / LocalErpStore A | promoteur et employés | gestion réseau | roles et scopes; isolation et tests | N1/N5 |
| Offline et sync | NS outbox, Room, WorkManager; offline-web et contracts R/A | stockage local, reprise | IndexedDB, SW | idempotence, ordre, conflits, reçus serveur | N1/N5 |
| Abonnements/entitlements | NAXA/NS + billing-core A; JOBLY D | choix plan, statut | idem | politique canonique, confirmation unique, expiration, RLS | N2 |
| Parrainage PME | NS ReferralScreen + Edge contract A | Profil > Parrainage | idem | vague de 5, aucun doublon, reward receipt | N2 |
| Admin, config, feature flags | Famille + JOBLY D/A | rôle autorisé | back-office | journal append-only, aucune transaction détaillée admin global | N2 |
| Restaurant/Bar/Snack | ZIPPLE S | espaces adaptés | responsive | séparation tables/postes, capacités, Snack sans livraison | N3 |
| Carte, tables, réservation, tickets cuisine | ZIPPLE S; NS agenda A | catalogue et écrans postes | salles/gestion | session, routage par ligne, statut et réservation concurrente | N3 |
| QR anonyme, commandes, disponibilité, délais | ZIPPLE S; JOBLY QR D | gestion QR, file postes | pages publiques mobiles | jetons opaques révocables, pas de lecture privée, concurrence dernier article, compteur serveur | N4 |
| Service, avis, notation | ZIPPLE S; NS performance A | équipe et feedback | avis invité et supervision | horodatage, notes par poste, anti-abus | N4/N7 |
| Caisse, facturation, ardoise | NS ManagementModules, cash operations, NAXA créances A | Room, reçus, impression | sessions, exports | ventes confirmées, facture, annulation, paiement séparé abonnement | N5 |
| Stock, inventaire, achats, fournisseurs, OCR | NS StockContent/shared operations, NAXA import A | stock et réception | inventaire et achats | lots, unités, coût pondéré, audit, imports | N5 |
| Recettes, production, bar, consignes | ZIPPLE S | production et pertes | recettes / rendement | version recette, consommation, consigne et retour | N5 |
| Dépenses, charges, comptabilité | NS finance/accounting A | opérations et rapports | journaux, exports | écriture équilibrée, CMV, rapprochement, transfert non vente | N5 |
| RH, pointage, objectifs, CRM | NS management/performance A | pointage autorisé, objectifs | dashboards et relances | droits et historique, localisation seulement sur action | N5/N7 |
| Fidélité et parrainage consommateur | NS customer promotions A | fiches facultatives | QR public facultatif | consentement, première vente réglée, aucun compte imposé, valeurs non validées | N5 |
| Livraison | NAXA routing, delivery UI A | missions livreur | QR livraison Restaurant | adresse manuelle ou consentement GPS, zone/frais, statut, aucun Snack | N6 |
| Paiements | NAXA merchant/payment proof; NS subscription credit A | paiement abonnement, enregistrement vente | parcours autorisés | confirmer côté serveur, distinguer abonnement/encaissement, pas PIN/OTP | N2/N6 |
| NAXA Security | NAXA live session API A | consultation autorisée | lecteur sécurisé | jetons courts, app/site, révoquer, pas accès public | N6 |
| Support, livechat, appel | NAXA native support + NS support A | Compose natif | chat et escalade | tickets, rôle, journal, consentement partage écran | N6 |
| Notifications | NS FCM/briefing/core R/A | push/inbox | inbox et préférences | dédoublonnage, messages préparés WhatsApp | N6 |
| GRILLAD Connect et HOTEL | intégration conditionnelle A | état des commandes autorisées | QR et portail de séjour | accords, droit, séparation commande/paiement/stock/folio; non activé sans contrat | N6 |
| IA et BI | NS PerformanceEngine, NAXA OCR, assistant core, JOBLY D/A | coach, projections | BI multi-sites | données sources, humains décident, sans coûts IA client inventés | N7 |
| Recette et sécurité | Famille, NS/NAXA scripts A | JUnit/Compose instrumentation | Playwright et PWA | build + tests SQL/RLS, isolation, non-régression, E2E, signatures | N8 |
## Matrice Accès/Premium
[V] Prix et cadence : contrat POLITIQUE_COMMERCIALE_ZIPPLE.json. [V portefeuille] Accès mono-compte; Premium inclut Accès et architecture multiniveau. [P] Transposition ZIPPLE : établissement autonome Accès, réseau multi-établissements avec promoteur/managers et consolidation Premium. Le cœur opérationnel (catalogue, commandes, caisse, stock, intégrité des données, sécurité, support et export) ne doit jamais être amputé de fonctions de cohérence. [O] Attribution commerciale précise des rôles employé, appareils, nombre de sites, vidéo, IA avancée, rapports, options, limites; aucun plafond chiffré ou droit additionnel inventé. Conserver un contrôle explicite par entitlement côté serveur, y compris cas négatifs. Ne pas activer la matrice proposée avant validation commerciale.

## Matrice détaillée candidate (26/11, non approuvée pour commercialisation)
| Capacité | Accès | Premium | Contrôle |
|---|---|---|---|
| Catalogue, commandes, tables, Bar et Snack-Bar selon activité | cœur métier | hérité | rôle et établissement |
| Caisse, stocks, achats, dépenses, comptabilité intègre | cœur métier | hérité | permissions et validation serveur |
| Support, export des données, sécurité de base | cœur métier | hérité | accès autorisé |
| Parrainage PME | cœur métier | hérité | promoteur et premier paiement confirmé |
| Architecture mono-compte | oui | héritée | compte actif |
| Gestion multiniveau | non | éligible | organisation et affectations serveur |
| Quotas utilisateurs/appareils/sites; vidéosurveillance, IA avancée, rapports avancés, options | à arbitrer | à arbitrer | refus par défaut sans droit explicite |

Cette répartition est une proposition technique de sûreté, non une nouvelle décision commerciale. L'éligibilité ne confère jamais une permission métier. La tarification et le modèle de parrainage sont testés par le contrat isolé; l'idempotence de la base et l'application des récompenses restent des tests N2.

### JOBLY — preuves de sources et choix d'adaptation
Inventaire et audit structurel 12 modules vérifiés par CI 45783895660. Reprendre concepts et fonctions ciblées : getPlan/getPrice/getEntitlements (sans catalogue recrutement), resolveActiveEntitlements (sans quotas candidature ni mode test illimité), PaymentProvider/ProviderVerification (pas de fournisseur mock en prod), session manager et offline-store (priorité NS et socle commun), adminWorkspaceCatalog et buildAnalytics360 (adapter métriques/permissions), enforceApiRateLimit, routes support/notifications; AI core et SMS Android sous revue spécifique. QR autonome non retrouvé par nom, à développer. Aucun module n'est déclaré directement compatible par la seule inspection statique.

### Preuve de faisabilité des droits et facturation
CI 45792810950 / PostgreSQL 17, job 139815827943 SUCCESS : quote_for_org recalcule les prix du catalogue et refuse un acteur sans droit promoteur; feature_allowed teste le droit de plan, l'app/org et l'abonnement actif. RLS teste les lignes des sites affectés; aucune écriture des tables d'abonnement depuis le client. Les options avancées ne sont ouvertes que par un grant explicite, sans prix ni quota présumé. Les utilisateurs et octrois de la recette sont fictifs, aucun droit commercial supplémentaire n'est approuvé. Candidat serveur testé, pas déployé. Les critères de recette N1/N2 restent inchangés.
