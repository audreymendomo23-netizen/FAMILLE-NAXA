# Exécution coordonnée des cinq chantiers — 14 novembre 2026

Branche : `main`  
Périmètre : prompts 0.3 à 0.13 ; 10 applications ; backend Supabase NAXA commun.

## Lot livré dans ce commit

| Chantier | Implémentation livrée | Preuve disponible | État |
|---|---|---|---|
| 1. Sécurité, identités, paiements, administration | Candidate SQL 0003 : scope app issu de `app_metadata.active_app_id`, helpers RLS app-contextualisés et EXECUTE en liste blanche | Assertions SQL de refus en absence/invalidité de claim | PARTIEL — tests inter-app réels et Auth hook manquants |
| 2. Offline, synchronisation, notifications, briefings | Contrats Kotlin : idempotence par operationId, politique de conflits par agrégat, horloge serveur, tolérance 7/14 jours, clés d'événements, garde WhatsApp | Code source ajouté ; tests Android non exécutés | PARTIEL |
| 3. Dix Android natifs et dix Web/PWA | Les dix identités produit restent inventoriées ; aucun des vingt manifests n'est encore livré par ce lot | Inventaire antérieur : 20 manifests absents | NON VERT |
| 4. Signature, exports, versions, distribution | Vérification SHA-256 d'artefact et contrôle de version minimale côté outillage Web | Tests Node ajoutés ; ce digest ne remplace pas la vérification du certificat Android | PARTIEL |
| 5. IA locale explicable | Fonctions déterministes de moyenne mobile, anomalie et estimation d'épuisement, sans données personnelles ni appel réseau | Code Kotlin ajouté ; tests Android non exécutés | PARTIEL |

## Sécurité — condition JWT

Le nouveau helper lit exclusivement le claim signé `app_metadata.active_app_id`. Il ne lit ni `user_metadata`, ni un GUC contrôlable par le client. Si le claim manque ou est invalide, la fonction retourne NULL et les helpers d'accès échouent fermés.

**Pré-requis non résolu :** il faut un mécanisme serveur/Auth fiable qui émette ce claim et le rafraîchit lors du changement d'application. Tant qu'il n'existe pas et n'est pas testé, la migration candidate ne doit pas être appliquée, même sur Replay.

## Règles de synchronisation

- L'identifiant d'opération est stable et unique ; le serveur doit imposer l'unicité.
- Le timestamp appareil est diagnostique, jamais autorité d'ordre.
- Les écritures comptables, paiements et événements SMS sont append-only ; les conflits passent en revue, jamais d'écrasement.
- Les agrégats versionnés peuvent utiliser une stratégie serveur dédiée ; « premier timestamp appareil gagne » n'est pas une règle universelle.
- L'expiration offline restreint l'accès mais ne supprime jamais la file locale.

## Limites et non-preuves

- Aucun projet Android complet ni PWA complète n'est construit par ce lot.
- Aucun test Kotlin/Android ni PostgreSQL 17 n'a été exécuté pendant ce lot.
- Aucun trigger/RPC Auth n'est déployé.
- Aucun DDL appliqué au Supabase réel ; aucun secret ni aucune configuration Production modifiés.
- Le hash SHA-256 est une vérification d'intégrité de fichier, pas une preuve de signature APK.
- La garde WhatsApp est conservatrice et peut bloquer des suites numériques légitimes ; elle nécessite validation métier et tests additionnels.

## État consolidé

Aucun des prompts 0.3 à 0.13 n'est déclaré VERT. Le lot apporte des fondations concrètes aux cinq chantiers, pas une clôture fonctionnelle. Continuer par tests PostgreSQL 17 avec fixtures multi-app, raccord Auth du claim signé, puis manifests Android/Web de chaque application et tests natifs.
