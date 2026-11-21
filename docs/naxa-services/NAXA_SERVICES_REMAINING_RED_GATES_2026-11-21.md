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
