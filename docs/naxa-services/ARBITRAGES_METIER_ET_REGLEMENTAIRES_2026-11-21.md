# NAXA SERVICES — registre d'arbitrages métier et réglementaires

**Date de référence : 21 novembre 2026**  
**Portée :** NAXA SERVICES Android / Supabase et ses interfaces Web/PWA futures.  
**État :** décisions techniques recommandées et portes de validation ; ce document n'est ni une validation juridique, ni une autorisation de mise en production.

## 1. Décisions de sécurité non négociables

1. **Aucun paiement n'est confirmé par le téléphone.** Capture d'écran, SMS, déclaration opérateur ou simple retour UI ne valent pas preuve de paiement. Seule une confirmation vérifiée côté serveur par le fournisseur / compte marchand peut faire évoluer l'état financier.
2. **Aucun événement financier n'est écrasé.** Ventes, paiements, remboursements, récompenses et écritures sont append-only ou compensés par des événements liés ; conflit = rapprochement/arbitrage.
3. **Toute politique à impact financier est versionnée.** Chaque taux, barème, formule, plafond et date d'effet est stocké avec sa source et son statut d'approbation. Pas de taux magique dans le code Android.
4. **Aucune donnée sensible ni clé privilégiée dans les APK.** Les clés FCM serveur, secrets Mobile Money et clés Supabase de service restent dans un coffre serveur.
5. **Pas de roue active par défaut.** L'activation publique attend une qualification juridique écrite au Cameroun.
6. **Pas de migration ni de déploiement sur le projet Supabase historique.** La base de recette doit être isolée et identifiée avant toute exécution.

## 2. Parrainage client — proposition de politique produit

À distinguer absolument du parrainage PME déjà présent.

### Modèle recommandé

- Un code de parrainage appartient à un client et à une organisation ; son périmètre peut être limité à un site ou étendu à l'organisation selon la politique du Promoteur.
- Le nouveau client communique le code lors de sa création ou avant sa première vente. L'attribution devient immuable après la première vente éligible.
- Une recommandation est qualifiée uniquement après une première prestation/vente terminée et effectivement encaissée, après confirmation serveur ; une vente annulée, impayée ou intégralement remboursée ne qualifie pas.
- Un seul parrain par nouveau client ; auto-parrainage, doublons de téléphone normalisé, comptes fictifs et réutilisation abusive sont refusés ou mis en revue.
- Les récompenses sont des **avantages internes non convertibles en espèces** : points de fidélité, remise plafonnée, crédit commercial ou prestation offerte. Les valeurs et l'expiration sont configurées par campagne.
- Le Promoteur choisit explicitement le bénéficiaire : parrain seulement ou parrain et filleul. Pas de bénéficiaire implicite.
- Tableau de suivi : code, client parrain, filleuls, date d'inscription, date de première vente encaissée, état, récompense due/émise/utilisée/expirée et motif de rejet.
- Une récompense est créée une fois par événement de qualification, avec clé d'idempotence, puis appliquée une seule fois à une vente ultérieure.

### Paramètres qui restent à définir par politique de l'organisation

- bénéficiaire(s) : parrain seul ou les deux ;
- type et valeur de l'avantage, plafond, minimum d'achat, durée de validité ;
- périmètre du code : site ou organisation ;
- campagnes ouvertes/fermées, dates, segments de clients et plafond de filleuls.

**Recommandation d'implémentation :** moteur multi-campagnes configurable, en état `draft` tant que les paramètres ne sont pas publiés par un Promoteur autorisé. Aucun montant de récompense n'est prérempli arbitrairement.

## 3. Roue de la chance / roue promotionnelle — décision de conformité

Le Cameroun dispose de la loi n° 2015/012 du 16 juillet 2015 et du décret n° 2019/2300/PM du 18 juillet 2019 encadrant le régime des jeux de divertissement, d'argent et de hasard. Le décret officiel traite des conditions d'exploitation et de contrôle de ces jeux. Une roue qui attribue un avantage en fonction d'un tirage aléatoire **peut** entrer dans ce champ ; la qualification exacte d'une campagne commerciale donnée doit être faite par un conseil camerounais et, si nécessaire, l'autorité compétente.

Sources officielles :
- [Décret n° 2019/2300/PM — Services du Premier Ministre](https://www.spm.gov.cm/site/?q=fr%2Fcontent%2Fd%C3%A9cret-n%C2%B020192300pm-du-18-juillet-2019-pr%C3%A9cisant-les-modalit%C3%A9s-dapplication-de-la-loi-n)
- [Copie officielle du décret en PDF](https://www.spm.gov.cm/site/sites/default/files/decret_jeux_hasard.pdf)

### Décision d'exploitation

- Fonction désactivée par défaut, y compris en production.
- Aucune mise en jeu d'argent, mise payante ou achat obligatoire ne doit être codée comme hypothèse.
- Aucun tirage public réel, remise de lot ou publicité avant avis écrit sur la qualification et les éventuelles autorisations.
- Le dossier juridique doit couvrir : nature des lots, valeur, probabilités, mode d'accès, lien éventuel avec achat, public/âge, territoire, dates, nombre de tentatives, stock de lots, règles de remise, fiscalité, réclamations et conditions publiques.

### Architecture à appliquer après autorisation

- campagnes versionnées avec statut `draft` / `legal_review` / `approved` / `active` / `suspended` / `expired` ;
- preuve d'autorisation ou avis juridique référencé et daté obligatoire pour passer à `active` ;
- tirage exclusivement côté serveur avec générateur cryptographiquement sûr ;
- probabilités publiées et totalisées, quotas/stock de lots vérifiés transactionnellement ;
- une clé d'idempotence par tentative, journal d'audit append-only, anti-doublon et règles de réclamation ;
- résultat serveur signé/stocké ; le client ne choisit jamais le lot ni le résultat ;
- désactivation automatique à la fin, épuisement des lots ou retrait de l'autorisation.

## 4. Notifications distantes — choix cible

### Décision technique recommandée

- **FCM** pour les push Android ; message de données minimal, puis chargement du détail après authentification.
- **Centre de notifications intégré** persisté côté serveur : états distincts créé, envoyé au fournisseur, reçu si confirmé par le fournisseur, lu dans l'application, actionné et échec.
- Canaux Android déjà présents : Critique, Opérations, Abonnement, Information, Coaching IA.
- Notifications locales via le socle Android existant ; préférences, heures calmes, anti-doublon et gestion explicite de la permission Android 13+.
- WhatsApp : lien `wa.me` préparé que l'utilisateur déclenche lui-même. Aucun envoi automatique ; aucun SMS sortant payant inclus dans le périmètre approuvé.

### Conditions d'activation manquantes

- projet Firebase Famille NAXA/NAXA Services avec applications Android correctement enregistrées ;
- configuration publique Firebase non secrète intégrée au build ; clé/service account d'envoi uniquement côté serveur ;
- secrets Edge, table des installations/tokens, rotation/révocation, RLS et tests de livraison/lecture ;
- consentement et préférences par application, organisation, lieu et utilisateur.

Une acceptation FCM n'est jamais affichée comme une lecture humaine. La spécification commune 0.6 s'applique aux dix applications ; NAXA SERVICES seul ne peut être déclaré conforme à ce socle partagé.

## 5. Synchronisation globale — ordre de réalisation

### Constat vérifié

Le contrat `SyncEnvelope` existe dans `packages/contracts` et une outbox Room existe. Le coordinateur actuellement raccordé dans NAXA SERVICES est `SupplierSyncCoordinator`, manuel et limité aux quatre actions fournisseur/achats suivantes : `supplier.saved`, `purchase.ordered`, `purchase.receipt.confirmed`, `supplier.payment.recorded`. Les dépendances non résolues (article stock distant, session de caisse serveur) sont bloquées, ce qui est préférable à une fausse confirmation.

### Décision cible

- une enveloppe commune versionnée : app, organisation, lieu, poste, membre, appareil, événement stable, agrégat/version, séquence appareil, heure d'origine et payload métier complet ;
- API serveur batch, réception atomique par événement, reçu persistant et idempotence sur `(org_id, device_id, event_id)` et séquence ;
- même clé + même hash : retourner le résultat précédent ; même clé + hash différent : rejet + conflit audité ;
- retry borné avec backoff/jitter pour erreurs transitoires ; rejet définitif pour validation/permissions ;
- références croisées avec UUID stables ou table de mapping explicite ;
- conflit selon domaine : ventes/paiements/abonnements = rapprochement humain ; stock = mouvement compensatoire ; profil/catalogue = fusion/version contrôlée ; jamais de LWW universel pour la finance ;
- aucune opération marquée `synced` avant reçu serveur `applied` confirmé ;
- moteur Android WorkManager et moteur Web/PWA IndexedDB distincts, fondés sur les mêmes contrats ;
- RLS réellement exécutée et testée pour organisation, lieu, poste, membre, appareil et application.

### Domaines à couvrir pour NAXA SERVICES

Profil/organisation, sites/postes, équipe/présences, clients/CRM, catalogue, rendez-vous, tickets et statuts pressing, ordres de travail, caisse/sessions, ventes/lignes, paiements/remboursements, dépenses, stocks/mouvements/transferts, achats/réceptions/règlements, fidélité, parrainage, commissions, comptabilité, charges récurrentes, notifications et journaux d'audit.

## 6. Mobile Money — arbitrage d'intégration

### Décision technique recommandée

Ne pas choisir un prestataire exclusif dans le code. Prévoir un adaptateur multi-opérateur et commencer les intégrations par les deux voies documentées pour le Cameroun :

- **MTN MoMo Collections** : la documentation développeur du produit Collections inclut le Cameroun pour la collecte à distance ; l'ouverture du compte marchand, l'onboarding et les frais sont contractuels. [Détails Collections Cameroun](https://momodeveloper.mtn.com/Cameroon_Collection_productDetails).
- **Orange Money Web Payment / M Payment** : le service liste le Cameroun et est réservé aux marchands inscrits, soumis au KYA et aux conditions locales. [Présentation officielle Orange Developer](https://developer.orange.com/apis/om-webpay/) ; [FAQ / conditions d'accès](https://developer.orange.com/apis/om-webpay/faq).

### Contrat technique commun

- création serveur d'une intention de paiement avec référence marchande unique ;
- états `initiated`, `pending`, `succeeded`, `failed`, `expired`, `cancelled`, `refunded` ;
- confirmation par webhook authentifié, vérification API serveur ou mécanisme de rapprochement fournisseur documenté ;
- idempotence fournisseur et marchande ; montant, devise XAF, bénéficiaire et transaction comparés avant validation ;
- retour tardif, doublon, montant partiel, annulation et remboursement journalisés ;
- frais fournisseur séparés des ventes et des charges métier ;
- aucun secret/provider key dans l'application.

### Blocage commercial

Il manque les contrats marchand/identifiants de production, les accès sandbox, les barèmes et règles de règlement, ainsi que la désignation des bénéficiaires des paiements (chaque PME ou un collecteur NAXA). Aucune transaction réelle ne peut être activée sans ces éléments.

## 7. Commissions des collaborateurs — règle métier proposée

### Règle de calcul recommandée

- définir un barème daté par prestation, éventuellement modulé par collaborateur ou rôle ;
- rattacher chaque ligne de prestation à son ou ses exécutants ; prévoir le partage explicite lorsque plusieurs collaborateurs ont contribué ;
- calculer la commission sur le montant réellement encaissé de la ligne, net des remises et remboursements, sans inclure les taxes collectées pour le compte de l'État lorsque celles-ci s'appliquent ;
- ne reconnaître la commission qu'après achèvement de la prestation et encaissement confirmé ;
- en cas de remboursement/annulation postérieure, passer une écriture inverse liée à la commission d'origine ; ne jamais modifier l'historique ;
- distinguer commission calculée, à valider, approuvée, payée et reprise ;
- la validation reste soumise à un responsable autorisé ; la commission ne lance pas automatiquement un décaissement.

### Paramètres à publier par le Promoteur

Taux ou montant fixe, base taxable/HT/TTC selon le régime de la PME, règle de partage, exclusions, période, arrondis, plafonds et traitement des remises/retours. Aucune valeur numérique par défaut n'est approuvée dans ce registre.

## 8. Fiscalité Cameroun — moteur versionné, non un taux unique

La DGI publie le Code général des impôts 2026 mis à jour au 1er janvier 2026. Le logiciel doit donc stocker le régime fiscal et l'identification du contribuable, le type d'opération, les exonérations, les taux et seuils datés, les retenues applicables et la version de la source. Les cas de TVA et de retenues à la source doivent être paramétrés selon le statut de la PME et la nature de la prestation, puis validés par son conseil fiscal.

Source officielle : [DGI — Code général des impôts, édition 2026](https://www.impots.cm/index.php/fr/publication/code-general-des-impots-mis-jour-au-1er-janvier-2026).

**Décision :** créer un moteur de règles fiscales effectives-datées et traçables ; ne pas appliquer un taux universel à toutes les PME, activités ou factures. Aucun calcul n'est présenté comme certifié sans validation du régime et des paramètres par un professionnel.

## 9. Comptabilité SYSCOHADA — modèle cible

L'AUDCIF et le SYSCOHADA révisé sont le référentiel OHADA applicable ; l'OHADA précise son entrée en vigueur pour les comptes personnels à compter du 1er janvier 2018 et pour les comptes consolidés/combinés/IFRS à compter du 1er janvier 2019.

Source officielle : [OHADA — AUDCIF et SYSCOHADA révisé](https://www.ohada.org/acte-uniforme-relatif-au-droit-comptable-et-a-linformation-financiere-audcif/).

### Décision technique

- comptabilité en partie double, journaux, grand livre, balance, auxiliaires clients/fournisseurs, immobilisations/amortissements et états financiers ;
- plan de comptes SYSCOHADA révisé versionné ; correspondance compte ↔ événement métier par organisation et régime ;
- écritures équilibrées débitées/créditées et générées côté serveur à partir d'événements confirmés ;
- journal validé non modifiable ; correction par extourne et nouvelle écriture, avec motif/auteur ;
- clôture de période, verrouillage et piste d'audit ;
- exports et états de travail ; aucun libellé « certifié » sans revue/validation de l'expert-comptable.

Les comptes symboliques et le journal de gestion local actuellement présents ne sont pas encore une comptabilité SYSCOHADA complète.

## 10. Paie et retenues sociales

### Architecture cible

- dossier salarié : contrat, catégorie professionnelle, date d'entrée/sortie, établissement, assiette, statut CNPS, classification du risque de l'employeur ;
- éléments : salaire de base, primes, avantages en nature, commissions approuvées, avances, retenues, absences et congés ;
- moteurs distincts : brut/net, IRPP et autres retenues DGI, cotisations CNPS part patronale/salariale, taxe de développement local et autres obligations applicables ;
- barèmes versionnés avec dates d'effet et source officielle ; bulletin détaillé, livre de paie, journal comptable et échéancier de déclaration/paiement ;
- séparation claire entre coût employeur et retenue salarié ;
- correction par bulletin rectificatif et journal d'audit ; droits d'accès RH/comptabilité.

La DGI publie un CGI 2026 et un barème indicatif de liquidation de l'IRPP/retenues salariales ; la CNPS expose les branches de cotisations et indique que les taux varient selon les branches et sont fixés par décret. Les documents CNPS disponibles incluent des textes antérieurs : une confirmation des paramètres applicables au moment de la paie reste indispensable avant mise en calcul.

Sources :
- [DGI — Code général des impôts 2026](https://www.impots.cm/index.php/fr/publication/code-general-des-impots-mis-jour-au-1er-janvier-2026)
- [DGI — barème indicatif IRPP et retenues salariales](https://www.impots.cm/fr/document/bareme-indicatif-de-liquidation-de-lirpp-et-autres-retenues-salariales-hors-taxe-de)
- [CNPS — obligations de l'employeur](https://www.cnps.cm/fr/?Itemid=134&showall=1)
- [CNPS — textes et barèmes de cotisations](https://www.cnps.cm/images/recueiltextesbasecnps2021.pdf)

**Décision :** ne pas utiliser un barème 2021/2024 comme vérité juridique 2026 sans confirmation CNPS/DGI et validation expert-comptable/paie. Les simulations non validées doivent être étiquetées « estimatives ».

## 11. Autres écarts à conserver dans le périmètre de clôture

- API métier serveur pour toutes les familles ERP, RLS d'exécution et isolation organisation/site/poste/appareil ;
- synchronisation hors connexion complète et résolveur de conflits ;
- intégration des abonnements, webhooks et entitlements ;
- automatisation fidélité et CRM (anniversaires, inactivité, pressing prêt/non retiré et relances) ;
- sauvegarde chiffrée, restauration testée et politique de rétention ;
- application Web/PWA au niveau de parité fonctionnelle et de sécurité attendu ;
- tests multi-appareils/physiques, réseau instable, restauration, performance et upgrade Room ;
- build Release signé, gestion du certificat et chaîne de distribution ;
- complétude Fulfulde, tests de langue et accessibilité ;
- centre de notifications multi-applications, console centrale, mutualisation CSO et intégrations Famille NAXA/NAXA SECURITY ;
- assistant IA distant et livechat réellement raccordés, avec limites et consentements définis.

## 12. Ordre d'exécution recommandé

| Ordre | Lot | Critère de sortie |
|---:|---|---|
| 0 | Environnement isolé NAXA SERVICES | Projet de recette identifié, accès et coût approuvés, aucune connexion au projet NAXA historique |
| 1 | Schéma, RLS et APIs serveur ERP | Migrations v1-v4 validées en local/isolation, tests négatifs multi-tenant/site/device/membre réussis |
| 2 | Synchronisation globale | Tous les agrégats NAXA SERVICES couverts, IDs stables, receipts idempotents, retries, conflits et tests multi-appareils |
| 3 | Commissions et comptabilité SYSCOHADA | Barèmes métier publiés, comptes validés par expert-comptable, journaux équilibrés et corrections auditées |
| 4 | Mobile Money et abonnements | Prestataire(s) sous contrat, sandbox réussi, webhooks authentifiés, rapprochement et entitlements idempotents |
| 5 | Paie et fiscalité | Barèmes DGI/CNPS datés validés par expert-comptable/paie, bulletins et déclarations de contrôle |
| 6 | Notifications et automatisations CRM | Firebase configuré, tokens révoqués/rotés, centre et actions idempotentes, tests multi-appareils |
| 7 | Parrainage client | Campagnes configurables, première vente encaissée confirmée serveur, anti-fraude et récompenses prouvées |
| 8 | Roue promotionnelle | Avis juridique/autorisation documentée, règles publiques, probabilités/quotas serveur, tests et activation explicitement approuvée |
| 9 | Qualification finale | Android + Web, test physique, sauvegarde/restauration, performance, audit sécurité et Release signée |

## 13. Ressources et autorisations externes à obtenir avant activation

- base Supabase NAXA SERVICES de recette séparée (ou référence d'une base de recette déjà existante) ; le projet historique NAXA n'est pas un substitut ;
- projet Firebase NAXA SERVICES et secrets FCM serveur, gérés dans le coffre de l'environnement ;
- contrats et accès sandbox/production MTN MoMo Collections et/ou Orange Money Web Payment, KYC marchand et barèmes ;
- décision écrite du Promoteur sur les avantages du parrainage client et les barèmes de commission ;
- expert-comptable camerounais pour les comptes SYSCOHADA, régime fiscal, TVA/retenues, règles de paie et paramètres CNPS à jour ;
- conseil juridique camerounais et, le cas échéant, autorité compétente pour la qualification/autorisations de la roue promotionnelle.

**Conclusion :** les décisions de sécurité et l'architecture cible sont définies ici. Les valeurs économiques, contrats, validations professionnelles et secrets d'environnement ne sont pas remplacés par des hypothèses de développement. Aucun élément de ce registre n'autorise à lui seul une migration, un déploiement ou une activation en production.
