# NAXA SERVICES — fermeture groupée des derniers points rouges

**Date : 21 novembre 2026**  
**Branche de travail :** `work/naxa-services-completion-20261120`  
**Règle :** un point est vert seulement après un test reproductible et une preuve d'exécution. Une configuration manquante, un accès marchand ou une validation réglementaire n'est jamais remplacé par un faux succès.

## 1. Ce qui est implémenté dans cette tranche

| Domaine | Implémentation livrée | Preuve attendue |
|---|---|---|
| Paiements Mobile Money | Noyau multi-opérateur MTN MoMo / Orange Money : intention XAF, idempotence, état pending après simple HTTP 2xx/202, confirmation séparée avec contrôle signature, référence, montant, devise et fournisseur. Registre d'adaptateurs fermé par défaut. | Tests unitaires. Les connexions marchands et webhooks réels ne sont pas déclarés actifs. |
| Commissions | Calcul uniquement sur prestation terminée et encaissement confirmé, net des remboursements, règle approuvée et datée, partage multi-exécutants totalisant exactement 10 000 points de base, écritures pending_approval, extourne append-only. | Tests unitaires. Les barèmes d'une PME sont à publier et approuver. |
| Fiscalité | Calcul XAF à partir d'une politique effective-datée approuvée, versionnée et sourcée. Aucun taux par défaut. Une politique absente, draft ou hors période renvoie un état bloqué. | Tests unitaires. La revue de l'expert-comptable/conseil fiscal reste requise par contribuable et opération. |
| Offline Web/PWA | IndexedDB v2, idempotence de l'event ID, détection de payload divergent, lease de batch multi-onglets, retry exponentiel borné, conflits/rejets conservés, acquittement uniquement sur receipt `applied`. | Tests de politique indépendants du navigateur. Le raccordement de chaque module métier Web au serveur reste un lot distinct. |
| Sauvegarde/restauration | Scripts PostgreSQL custom dump, chiffrement GPG AES-256, checksum, manifeste, contrôle de base cible et double confirmation destructive. Drill CI sur deux bases PostgreSQL isolées. | Workflow `NAXA SERVICES — encrypted backup and restore drill`. |
| Release Android | Configuration Gradle de signature et workflow tag/manuel : clés uniquement en secrets GitHub, APK signé, vérification apksigner et SHA-256. | Bloqué tant que les 4 secrets de signature ne sont pas fournis ; aucun certificat n'est inventé. |

## 2. Synchronisation : ce qui reste bloquant

Le socle commun d'enveloppe et la table serveur des reçus/conflits existent. Le coordinateur Android livré n'émet cependant que les quatre actions fournisseur/achats. L'outbox locale contient encore des événements dont certains payloads sont des références minimales et non des snapshots métier complets.

Aucun worker global ne doit envoyer un événement sans handler serveur typé. Aucun évènement ne passe à `synced` sur un simple HTTP 2xx. Les opérations finance, stock, caisse, ventes, rendez-vous, pressing, CRM, équipe et commissions doivent disposer chacune :
1. d'un snapshot complet et versionné côté outbox ;
2. d'un handler serveur dédié, vérifiant session, organisation, site, poste et rôle ;
3. d'un reçu idempotent écrit dans la même transaction que la mutation ;
4. de règles de conflit et de tests positifs/négatifs ;
5. d'un test de reprise sur deux appareils.

La file Web/PWA fournit maintenant le mécanisme de stockage/lease/retry, mais pas encore tous les connecteurs métier.

## 3. Notifications Firebase

Le code Edge FCM contient déjà le flux OAuth2 service-account, chiffrement AES-GCM des tokens, révocation des tokens invalides, claims avec lease, retries et mise à jour du centre de notifications. L'activation réelle exige `FCM_SERVICE_ACCOUNT_JSON`, `NS_PUSH_TOKEN_ENCRYPTION_KEY` (32 octets hexadécimaux), `NS_NOTIFICATION_WORKER_SECRET`, les variables Supabase et le projet Firebase/app Android correspondant. Ces secrets doivent être déposés dans le coffre Edge de l'environnement dédié, jamais dans Git, l'APK ou une conversation.

Le serveur marque l'envoi accepté par FCM comme `sent`, pas comme reçu/lu par une personne. Les états read/actioned viennent de l'application.

## 4. Supabase

L'unique projet actuellement visible via la connexion Supabase est le projet historique **NAXA**, déjà utilisé par la plateforme pharmacie. Les migrations NAXA Services v1-v6 sont des drafts et CI les exécute uniquement sur PostgreSQL jetable. Le projet historique n'est pas une base de recette NAXA Services et ne reçoit donc aucune migration.

La création d'un projet Famille/NAXA Services distinct reste nécessaire. Sa région, son coût et son rattachement organisation doivent être vérifiés avant création. Aucun secret privilégié n'est ajouté au dépôt.

## 5. Ce qui n'est pas déclaré vert

- synchronisation métier universelle Android + Web et réplication multi-appareils ;
- app Web/PWA complète : les vues actuelles restent en aperçu pour les opérations métier ;
- transactions MTN MoMo / Orange Money réellement exécutables : contrats, KYA, sandbox, comptes bénéficiaires, frais et webhooks marchands manquants ;
- activation Firebase réelle et test push sur appareils ;
- barèmes de commissions approuvés par chaque organisation ;
- validation comptable SYSCOHADA, régime fiscal, taux et paie/CNPS par professionnel ;
- roue promotionnelle : activation interdite tant que l'avis juridique/autorisation applicable manque ;
- Release signée : certificat privé et secrets de signature non disponibles ;
- restauration d'une sauvegarde réelle et test de reprise après sinistre de l'environnement hébergé ;
- validation physique Android, Web/PWA, impression, accessibilité et langue Fulfulde.

## 6. Variables et validations requises

### Edge Functions / environnement Supabase dédié
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
- `FCM_SERVICE_ACCOUNT_JSON`, `NS_PUSH_TOKEN_ENCRYPTION_KEY`, `NS_NOTIFICATION_WORKER_SECRET`
- `NS_ALLOWED_ORIGINS`

### Android / signature
- `NS_SUPABASE_PROJECT_REF`, `NS_FAMILY_SUPABASE_PROJECT_REF`, endpoint Auth/Accounting/Referral/Notifications
- `NS_SUPABASE_ANON_KEY` (clé publishable/anon uniquement)
- `NS_FIREBASE_API_KEY`, `NS_FIREBASE_APP_ID`, `NS_FIREBASE_PROJECT_ID`, `NS_FIREBASE_SENDER_ID`
- secrets GitHub `NAXA_SERVICES_RELEASE_KEYSTORE_BASE64`, `NAXA_SERVICES_RELEASE_STORE_PASSWORD`, `NAXA_SERVICES_RELEASE_KEY_ALIAS`, `NAXA_SERVICES_RELEASE_KEY_PASSWORD`

### Fournisseurs et expertise
- contrats marchands / accès sandbox MTN MoMo ou Orange Money, webhooks et bénéficiaires ;
- grille de commission approuvée par l'organisation ;
- expert-comptable/conseil fiscal et gestionnaire paie camerounais avec paramètres datés validés ;
- conseil juridique et autorisation applicable pour la roue promotionnelle.

**Conclusion :** cette tranche fait progresser simultanément les socles techniques qui peuvent être développés et testés sans secrets externes. Elle ne transforme pas artificiellement en VERT les points qui exigent de véritables comptes marchands, un Firebase dédié, un projet Supabase isolé, des décisions économiques ou un visa professionnel.


## 7. Addendum — politiques financières et événements prestataires (21 novembre 2026)

Le draft v7 complète les tests PostgreSQL jetables :
- versions de politique de commission (taux en points de base ou montant fixe, dates d'effet, approbation explicite, version approuvée immuable) ;
- écritures d'ajustement de commission signées et append-only, liées à un événement source idempotent ;
- politiques fiscales par type d'impôt, version, taux en points de base, mode TTC/HT, dates et références de source ; le statut `approved` exige une approbation et la référence documentaire ;
- comptes Mobile Money dont la configuration ne contient qu'un pointeur vers le coffre, jamais de secret ;
- événements de callback Mobile Money limités à des empreintes et métadonnées non sensibles, tables interdites aux rôles clients ; un événement `verified` ou `applied` exige une preuve de vérification serveur.

Les API Edge qui administrent ces nouvelles tables, l'intégration marchande et le rapprochement restent des gates séparées. Le draft v7 est exécuté seulement sur la base PostgreSQL jetable du CI ; il n'est pas appliqué au projet Supabase NAXA historique.


### Alignement des statuts Mobile Money

Le moteur financier, les contrats transversaux et le schéma v7 utilisent désormais les mêmes statuts métier : `initiated`, `pending`, `confirmed`, `failed`, `expired`, `cancelled`, `refunded`, `reversed`. Un simple HTTP 2xx/202 demeure `pending`. Les statuts `refunded` et `reversed` sont terminaux ; la transition vers un remboursement ou une extourne n'est autorisée qu'à partir d'un paiement `confirmed`.


## 8. Web authentification et alignement des paiements (21 novembre 2026)

Le portail Web NAXA Services reçoit maintenant une session d'authentification complète du backend, vérifie la présence des jetons et du périmètre membre/organisation/sites, enregistre uniquement un identifiant d'installation non secret dans le stockage local, et garde les jetons d'accès/renouvellement en mémoire de l'onglet. Le renouvellement avant expiration, la révocation à la déconnexion et le remplacement obligatoire d'un mot de passe initial sont raccordés à l'Edge Auth. Les tests unitaires couvrent la validation du périmètre et la borne de durée de session.

**Limite maintenue :** cette authentification ne transforme pas les écrans CRM, agenda, pressing, caisse, stock, RH et rapports en modules Web connectés. Leurs opérations restent des brouillons locaux ; aucun montant ni reçu commercial n'est présenté comme enregistré en backend. Le gate ajoute un build Web et les tests du parseur de session.

Les statuts paiements sont désormais alignés entre le moteur financier, les contrats et le draft PostgreSQL v7 : `initiated`, `pending`, `confirmed`, `failed`, `expired`, `cancelled`, `refunded`, `reversed`. Un code HTTP `202` reste une demande en attente ; une confirmation exige la vérification serveur du prestataire et la comparaison du montant, de la devise et de la référence.


## 9. État consolidé de livraison et preuves (21 novembre 2026, 20:xx UTC)

### Dernier commit audité
- Branche : `work/naxa-services-completion-20261120`
- Commit : `b0023e351743f716b4a532172d800a049fd4eddb`
- La branche `main` reste indépendante ; aucune fusion ni écriture n'a été faite sur celle-ci.

### Gate courant
- Workflow : [NAXA SERVICES — Android + Auth contract gate](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44944459740)
- Résultats vérifiés : 11 jobs sur 12 terminés en succès, dont le nouveau build Web/test de session et les tests SQL/RLS v7 sur PostgreSQL 17.
- Le seul job encore en cours dans ce relevé est le job Android (tests instrumentés Keystore/PIN, puis assemblage et upload). Le build et les tests Android complets ont réussi sur le commit précédent `0e0e5d9ebd94ab2f539c1ce8a8b89c0f2ed1083a`. La comparaison GitHub montre qu'aucun fichier `apps/android/**` n'a changé entre ce commit et `b0023e3`; l'APK ci-dessous correspond donc au code Android identique et déjà vérifié, mais le nouveau passage Android reste ouvert jusqu'à fermeture du workflow courant.

### APK Android Debug disponible
- Artifact GitHub : `14721924884`, workflow précédent terminé vert.
- SHA-256 APK : `fec5a4c2427222e422b06053d0346f203801ebd2f9d9ccab28adbf707c25e1fc`.
- SHA-256 archive : `aad4903c6d393bbb0370b256defecb7b8a5b1af20957da518f83f08e1f92c975`.
- Ce livrable est un APK Debug non signé pour distribution de production.

### Sauvegarde/restauration
- [Drill PostgreSQL 17 chiffré réussi](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44942987790) sur bases source et destination jetables.
- Aucun backup/restauration n'a été exécuté contre le projet Supabase NAXA existant.

### Blocages de lancement encore actifs
1. Le projet Supabase dédié NAXA Services n'est pas créé ; le seul projet visible reste le projet historique NAXA partagé avec la pharmacie. Le devis de création retourné pour l'organisation visible était de 0 USD/mois, mais le projet isolé n'est pas créé sans confirmation de l'organisation et de la région.
2. Firebase/FCM n'est pas activé dans un projet réel ; comptes, secrets de coffre, déploiement et tests de livraison sur appareil restent requis.
3. MTN MoMo/Orange Money n'ont ni compte marchand/sandbox réel ni secrets/webhooks configurés ; l'engine et la persistance serveur restent en mode fail-closed.
4. La synchronisation métier universelle Android/Web n'est pas implémentée : l'Android serveur ne traite que les quatre actions fournisseur/achats ; les autres domaines restent en file locale. Le Web possède authentification et file générique, mais ses écrans métier demeurent des brouillons locaux.
5. Les barèmes de commission et paramètres fiscaux doivent être approuvés par l'organisation et le professionnel compétent ; paie/CNPS et comptabilité SYSCOHADA complète restent à faire valider.
6. La Release signée exige la clé privée et les secrets GitHub nommés dans la section précédente ; le certificat n'est pas créé ni inventé.
7. La roue promotionnelle reste désactivée jusqu'à avis juridique écrit et autorisation applicable.

**Décision de statut :** VERT pour les contrats/CI, schéma/RLS jetable, build Web, sauvegarde-restauration de test et APK Android Debug déjà vérifié. Pas encore VERT pour la mise en production ou la fermeture de tous les lots métier. Les éléments manquants ci-dessus ne sont pas des échecs de tests ; ce sont des gates d'environnement, d'intégration, d'autorisation ou de livraison.
