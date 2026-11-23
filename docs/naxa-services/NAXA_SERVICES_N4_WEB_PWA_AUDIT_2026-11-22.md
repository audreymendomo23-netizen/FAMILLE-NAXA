# NAXA SERVICES — N4 Web/PWA : corrections du socle et points encore ouverts

**Date initiale :** 22 novembre 2026 — **Addendum :** 23 novembre 2026  
**Branche :** `work/naxa-services-completion-20261120`  
**Verdict consolidé : PARTIEL** — socle Web/PWA renforcé et scénarios navigateur ajoutés ; la parité métier complète, l'exécution réussie de la nouvelle recette Chromium et la validation sur environnement hébergé dédié restent à prouver.

## Corrections livrées
- Le `device_id` Auth est maintenant obligatoire dans la session Web.
- IndexedDB v3 conserve les métadonnées, une séquence monotone par application/appareil, les changements entrants et leur curseur.
- L'outbox attribue la séquence et insère l'événement dans une transaction atomique ; une réutilisation d'ID avec autre appareil ou payload est rejetée.
- Push Web utilise `apply_sync_event` et le reçu SQL `event_id` / statut `applied` est vérifié avant acquittement. Aucun reçu n'est fabriqué côté navigateur.
- Pull Web utilise `pull_sync_changes`; les pages et curseurs sont persistés ensemble, les curseurs ne peuvent pas reculer, les changements reçus sont visibles sans réémission dans l'outbox.
- Les formulaires génériques, transitions pressing simulées et réglages organisation non raccordés sont neutralisés en session authentifiée ; le mode aperçu reste local et identifié.

## Limites qui restent à fermer
Le code Web comporte déjà plusieurs parcours de mutation Authentifiés raccordés à l'outbox et au journal N3 : création d'article, fiche client, prestation, ticket pressing, rendez-vous, dépense, pointage du membre connecté et demande d'assistance. Les fonctions d'administration du profil organisation, des sites et des postes passent par Auth. Le rapport financier lit les vues serveur lorsqu'une session et les scopes l'autorisent. Le statut antérieur qui présentait l'article de stock comme unique parcours de création était incomplet et est remplacé par la matrice d'actions réelle.

La couverture de ces mutations ne vaut cependant pas parité ERP complète. Les vues de disponibilité et la gestion des cycles agenda, les transitions pressing, les sessions de caisse, ventes, paiements et reçus, les achats/fournisseurs/mouvements de stock, les vues CRM/fidélité complètes, la gestion d'équipe/commissions, les réglages sécurité, l'ensemble des projections réseau et des rapports détaillés restent à compléter ou à raccorder explicitement. Les actions non livrées restent en lecture seule ou en aperçu et ne doivent jamais être présentées comme validées.

La recette Chromium a été ajoutée au workflow : outbox hors ligne, fermeture/réouverture d'onglet, changement d'organisation sur un même appareil, reçu serveur, deux onglets concurrents, curseurs entrants isolés et navigation PWA hors ligne. Au moment de cet addendum, le dernier run GitHub Actions `45150669071` est encore en statut `pending` sans jobs remontés : aucun résultat E2E vert n'est donc revendiqué ici.

Le projet Supabase NAXA Services dédié n'est pas disponible pour tests hébergés. Les mocks E2E et CI PostgreSQL jetable vérifient des contrats et parcours contrôlés, pas l'intégration sur un environnement réel ni les secrets/protocoles marchands et Firebase. Aucun déploiement réel ni test FCM/Mobile Money ne peut être réputé achevé.

**Garde-fous :** aucun commit sur `main`, aucune fusion, aucun déploiement, aucune migration sur le Supabase historique NAXA/pharmacie. Les modules sans parcours serveur explicite restent désactivés hors aperçu.

---

## Addendum technique — fermeture des points N4 réalisables sans accès externe (23 novembre 2026)

**Branche :** `work/naxa-services-completion-20261120`
**Dernier commit de code audité :** `869a30a4ac469780db7981af68cd1b30279151bf`

### Corrections code et sécurité
- Le test IndexedDB importe effectivement `listQueued` et crée maintenant les fixtures de chaque appareil nécessaires au contrôle des leases concurrents.
- Les événements sortants sont filtrés par application, appareil et organisation. La métadonnée d'organisation doit correspondre au `org_id` contenu dans le payload ; un mismatch est rejeté.
- Les lots réservés (`acquireDueBatch`) appliquent le même filtre d'organisation.
- Le curseur entrant et les changements stockés sont partitionnés par application, appareil et organisation. Les tests couvrent deux organisations utilisant le même identifiant d'appareil.
- Après synchronisation, l'interface recharge les états locaux à partir de l'outbox afin d'afficher le reçu, le rejet ou le conflit réellement enregistré.
- Le parseur Auth conserve désormais le profil de l'organisation, la langue, les fiches des sites autorisés et rejette les fiches de site hors scope.
- Les libellés d'interface distinguent les créations réellement raccordées des cycles de vie et projections encore incomplets. Le formulaire de caisse indique une dépense, et non une vente.

### PWA et recette automatisée
- Manifeste d'installation complété avec identifiant, portée, couleur, description et icône carrée.
- Service Worker enregistré uniquement en production ; il met en cache le shell, le manifeste, l'icône et les ressources compilées, avec repli de navigation vers le shell hors ligne.
- Le nettoyage du cache ne supprime que les caches NAXA Services et l'ancien cache explicitement nommé ; les autres caches de même origine sont préservés.
- Playwright/Chromium est intégré au gate N4 avec tests du flux hors ligne, de la reprise et du cloisonnement multi-organisation, plus une recette PWA sur le build de production.
- **Preuve d'exécution : EN ATTENTE.** Le dernier run connu est `45150669071`, statut `pending` ; le gate n'est pas déclaré vert tant que les jobs et leur conclusion ne sont pas disponibles.

### Statut de clôture
| Point N4 | Statut au 23 novembre 2026 | Preuve / limite |
|---|---|---|
| Correction tests IndexedDB existants | Code corrigé | Import et fixtures corrigés ; nouveau gate à exécuter |
| Isolation outbox par organisation | Code + tests ajoutés | Filtre lecture, réservation et payload |
| Isolation pull/cursor par organisation | Code + tests ajoutés | Partition de curseur et projection |
| Parser Auth Web complet | Code + tests ajoutés | Fiche site, mode d'exploitation et locale |
| Exactitude des statuts UI | Code corrigé | Parcours livrés distingués des vues non livrées |
| Manifest/PWA offline shell | Code ajouté | Service Worker production et cache contrôlé |
| Recette Chromium réelle | En attente | Run `45150669071` pending, aucun résultat vert revendiqué |
| Parité métier ERP Web | Partiel | Cycles, vues, encaissements, achats et modules avancés à compléter |
| Auth/Accounting sur Supabase dédié | Bloqué externe | Environnement dédié absent ; aucun test hébergé réel |
| FCM/Mobile Money réels | Bloqué externe | Secrets, comptes marchands, webhooks et projet Firebase absents |

**Décision :** les corrections de code et scénarios reproductibles accessibles sans secrets sont engagés dans la branche de travail. N4 n'est pas globalement clôturé. Aucun commit sur `main`, aucune fusion, aucun déploiement et aucune migration sur le projet Supabase historique NAXA/pharmacie n'ont été réalisés.