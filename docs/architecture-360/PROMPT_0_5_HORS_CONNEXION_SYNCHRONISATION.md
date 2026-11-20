# PROMPT 0.5 — Hors connexion et synchronisation — Famille NAXA

> Adaptation du Prompt 0.5 historique « Hors connexion et synchronisation ».
> Source : [NAXA — 00-socle-commun.md](https://github.com/audreymendomo23-netizen/NAXA/blob/main/7%20famille%20naxa/02-prompts/00-socle-commun.md), version 1.0 du 31 octobre 2026.
> Statut : cadrage adapté et audit initial réalisés ; implémentation complète non commencée. Ce document n'autorise aucune migration Production ni aucun déploiement.

## 1. Rôle et objectif

Concevoir, implémenter et tester un moteur de persistance locale et de synchronisation fiable, commun aux dix applications Famille NAXA, pour Android natif Kotlin/Compose et Web responsive/PWA.

Le moteur doit préserver les données lors des coupures réseau, reprendre les envois sans doublon, conserver les preuves métier et traiter les conflits selon le domaine. Il doit rester utilisable sur des téléphones Android d'entrée de gamme.

## 2. Périmètre canonique

Dix applications : Kiosko, Bootik, Zipple, NAXA Services, CotiZ, Loyable, NAXA Hotel, Campus237, NAXA Security et GrillaD.

- Android : Room/SQLite, WorkManager et moteur Kotlin partagé dans `packages/core-android`.
- Web/PWA : IndexedDB et service worker ; moteur TypeScript partagé dans `packages/offline-web`.
- Contrats partagés dans `packages/contracts`.
- Un seul backend Supabase NAXA existant. Ne pas créer un backend, un registre d'identité ou une file serveur parallèle sans preuve d'absence d'équivalent.
- L'isolation est obligatoire par application, acteur, organisation et lieu ; les permissions sont revalidées côté serveur à chaque lot.
- Les clients n'embarquent jamais de `service_role`.

## 3. Ressources NAXA déjà existantes à préserver

L'audit en lecture seule de Production a identifié notamment :
- `public.appareils` : registre professionnel pharmacie, déjà consommé par les opérations hors ligne NAXA ; ne pas le généraliser aux dix applications sans modèle compatible.
- `public.offline_operations` : opérations de correction de quantité de stock, idempotence par `operation_id`, séquence appareil, horodatage de modification et statut.
- `public.naxa_offline_sales` : ventes différées de caisse, identifiant d'opération, appareil, utilisateur, pharmacie, session caisse, séquence et résultat.
- `private.naxa_offline_lww_config` : date d'activation de la chronologie LWW.
- `public.stock_manager_movement_journal` : journal des mouvements utilisé par les corrections de stock.
- Les fonctions `naxa_apply_offline_operation_v1`, `naxa_apply_offline_sale_v1` et `offline_stock_set_quantity` portent déjà des règles métier spécifiques.

Ces ressources sont pharmacie-spécifiques. Les réutiliser pour leurs cas métier actuels ; ne pas les détourner pour les dix applications.

## 4. File locale et enveloppe d'événement

Chaque application garde ses données métier dans ses propres agrégats locaux, mais utilise un contrat d'événement commun versionné.

Enveloppe minimale à valider et compléter :
- `event_id` UUID aléatoire stable, généré une seule fois et conservé à chaque tentative ;
- `app_id`, `organization_id`, `location_id`, `actor_id`, `device_id` ;
- `aggregate_type`, `aggregate_id`, `aggregate_version` ;
- `device_sequence` monotone et unique pour une installation ;
- `occurred_at` informatif (horloge locale non fiable), `schema_version` ;
- payload métier typé, taille limitée et sans secret inutile ;
- état local, nombre d'essais, prochaine tentative, dernière erreur non sensible et accusé serveur.

États minimaux : `queued`, `sending`, `retry_wait`, `acknowledged`, `conflict`, `rejected`. Un événement n'est jamais supprimé avant accusé serveur durable et politique de rétention documentée. Un même `event_id` avec un contenu différent doit être rejeté.

L'identifiant d'événement sert à l'idempotence ; la séquence appareil sert à détecter les trous, doublons et réordonnancements. Les deux ne sont pas interchangeables.

## 5. Synchronisation

- Envoi par lots bornés, ordonnés par séquence, avec taille et durée de requête adaptées aux réseaux mobiles.
- Réponse individuelle par événement : accepté, déjà appliqué (même résultat), conflit, rejet définitif ou erreur temporaire.
- Transaction serveur atomique par événement métier ; une erreur dans un événement ne doit pas effacer les accusés des autres événements du lot.
- Idempotence serveur par clé unique stable et comparaison du hash/contenu canonique.
- Reprise automatique au retour réseau via WorkManager côté Android et mécanismes PWA adaptés côté Web ; pas de boucle agressive.
- Backoff exponentiel plafonné avec jitter, reprise sur réseau disponible, et bouton de reprise manuel si utile.
- L'accusé serveur et le résultat métier sont persistés localement avant de passer à l'événement suivant.
- Aucun événement financier ne doit être rejoué comme une nouvelle vente ou un nouveau paiement après un timeout : la même clé d'idempotence doit retourner le résultat initial.
- Aucun traitement de synchronisation ne contourne RLS, l'Auth ou les contrôles serveur.

## 6. Immutabilité des preuves SMS et corrections

- Une preuve issue d'un SMS est une source factuelle append-only : conserver son identifiant, hash, origine autorisée, horodatages disponibles, champs extraits et provenance de chaque champ.
- Ne jamais envoyer le SMS brut ou un numéro complet à un service IA externe.
- Une correction ne modifie pas la preuve source : elle crée une écriture corrective liée à l'original, avec motif obligatoire, auteur, horodatage serveur, valeurs avant/après et identifiant de corrélation.
- Les corrections et décisions de validation doivent être auditées et idempotentes.
- Ne jamais confondre SMS déclaré, SMS capturé, rapprochement automatique et paiement réellement vérifié.
- Les preuves capturées sur appareil doivent rester locales en attente de synchronisation ; la file ne doit pas les supprimer en cas d'échec.
- Les tables NAXA de preuves SMS existantes doivent être auditées pour leurs chemins d'écriture et de correction avant tout ajout de modèle générique.

## 7. Tolérance hors connexion et ancrage temporel

Règle historique à adapter et vérifier avec les plans réellement applicables :
- Essentiel et Pro : 7 jours ;
- Réseau : 14 jours.
- Jours 1 à 3 : fonctionnement normal avec indicateur discret de synchronisation/échéance.
- Avant la limite : message localisé « Connectez-vous avant le [date] ».
- Après la limite : accès métier restreint selon la matrice des capacités, mais les données locales restent conservées et exportables lorsque cela est sûr.

À chaque synchronisation réussie, mémoriser l'heure UTC du serveur, l'heure murale locale, l'horloge monotone et, sur Android, l'identifiant de démarrage disponible. Le moteur détecte un recul de l'horloge, un ancrage incohérent ou une durée dépassée et passe en état temporel suspect. Il ne doit jamais effacer la file locale.

Limites à respecter :
- l'horloge murale du client n'est pas une preuve de temps ;
- Android peut fournir un temps monotone dans un même démarrage, mais pas une durée fiable traversant un redémarrage sans source de confiance supplémentaire ;
- Web/PWA ne dispose pas d'un stockage matériel inviolable ;
- le serveur reste l'autorité pour l'heure, les abonnements, les droits et l'acceptation finale des opérations.
Ne pas prétendre qu'une détection locale empêche un appareil rooté ou un navigateur compromis de falsifier le temps.

Le plan d'abonnement et le palier doivent provenir d'une autorité serveur ; ne pas les laisser modifiables dans le payload local.

## 8. Conflits — règle métier prioritaire

Le texte historique dit « l'enregistrement le plus ancien côté serveur gagne ». Cette règle ne peut pas être appliquée uniformément au backend NAXA existant.

Le contrat actuel `packages/contracts/src/index.ts` prévoit déjà :
- égalité de version : acceptation ;
- vente, paiement, abonnement : revue manuelle ;
- stock : compensation ;
- autres domaines : revue manuelle.

Cette politique métier prime sur une règle générique LWW. Pour deux envois du même événement, le premier commit serveur est idempotent et toute répétition retourne le même résultat. Pour deux événements distincts sur le même agrégat, appliquer la règle de son domaine, avec verrouillage transactionnel et versions ; ne pas écraser silencieusement une vente, un paiement, un abonnement ou une écriture de sécurité.

Le stock pharmacie existant conserve son algorithme LWW spécifique basé sur `modified_at`, les séquences et le journal des mouvements, tant qu'un audit métier distinct n'a pas autorisé son remplacement.

Toute opération perdante est conservée et présentée à l'utilisateur avec le motif et l'action de résolution. Le libellé historique « à replacer » doit être localisé et son sens métier précisé par type d'opération.

## 9. Tests obligatoires

Tests unitaires et d'intégration reproductibles, Android, Web et PostgreSQL 17 éphémère :
1. coupure réseau puis reprise, sans perte et sans doublon ;
2. même lot envoyé plusieurs fois, même résultat serveur ;
3. même `event_id` avec payload différent : rejet ;
4. ordre de séquence, trou, répétition, séquences concurrentes ;
5. batch partiellement accepté et reprise des seuls événements non acquittés ;
6. timeout après commit serveur : reprise sans double écriture ;
7. conflits concurrents sur même agrégat, avec politique par domaine ;
8. ventes, paiements et abonnements jamais écrasés automatiquement ;
9. correction append-only d'une preuve SMS avec motif, auteur et valeurs avant/après ;
10. absence de suppression locale avant accusé durable ;
11. jours 1, 3, 7 et 14 selon palier ; accès restreint après échéance sans perte de données ;
12. recul de l'horloge, changement de fuseau, redémarrage et horloge incohérente ;
13. appareils désactivés, profil suspendu, abonnement expiré et permissions révoquées ;
14. isolation inter-app, inter-organisation et inter-lieu ;
15. Web PWA : cache hors connexion des ressources et persistance IndexedDB des données ;
16. vérification qu'aucune clé privilégiée ni donnée sensible brute n'est incluse dans les bundles.

Chaque test précise préconditions, scénario, résultat attendu et preuve. Tout test non exécuté reste NON EXÉCUTÉ.

## 10. Gouvernance et livrables

Méthode : audit → contradiction → cause racine → correction → test/preuve → documentation → état.

Livrables :
- audit de compatibilité avec les opérations hors ligne NAXA ;
- matrice des domaines et règles de conflit des dix applications ;
- moteur Android partagé Room/WorkManager ;
- moteur Web partagé IndexedDB/PWA ;
- contrats d'événements versionnés ;
- service serveur idempotent et règles de conflit, avec migrations additives seulement si justifiées ;
- textes FR/EN, tests et documentation de reprise.

Travailler sur `main` uniquement, sans branche ni PR. GitHub Actions sont autorisées pour les contrôles qualité. Les tests DB utilisent PostgreSQL 17 éphémère. Aucun changement Production, migration appliquée, Edge Function déployée, APK publiée ou site mis en ligne sans autorisation explicite distincte.

## 11. Critères de clôture

Prompt 0.5 VERT uniquement lorsque :
- les dix apps utilisent un moteur partagé ou des adaptateurs prouvés compatibles ;
- les files locales survivent aux arrêts et redémarrages ;
- les lots et opérations sont idempotents côté serveur ;
- les preuves SMS sont append-only et les corrections traçables ;
- les durées hors connexion sont appliquées par plan validé et le recul d'horloge est détecté sans perte de données ;
- les conflits sont résolus par domaine, avec tests concurrents ;
- les tests Android, Web et PostgreSQL 17 sont exécutés et réussis ;
- aucune régression des flux NAXA existants n'est constatée ;
- la continuité contient les preuves et les limites restantes.

**État initial : AUDIT DE DÉPART PARTIEL. Aucune implémentation Prompt 0.5 ni migration Production n'a été réalisée par ce document.**
