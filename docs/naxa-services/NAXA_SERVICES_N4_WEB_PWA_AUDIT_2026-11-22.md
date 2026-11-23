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

---

## Addendum — N4-C : parcours métier multisecteur — 23 novembre 2026

La reprise N4 a été effectuée sans recommencer le socle N3. Le traitement du Pressing comme parcours prioritaire unique a été corrigé : les 13 profils Auth de NAXA Services ont maintenant un registre métier dédié dans `apps/web/naxa-services/src/erp/activity-workflows.ts`, avec ses champs, validations, objets de dossier, étapes et transitions. La matrice détaillée est publiée dans `NAXA_SERVICES_ACTIVITY_PARITY_MATRIX_2026-11-23.md`.

### Changements réalisés sur la branche de travail
- Auth Web conserve le profil métier de l'organisation ; les valeurs absentes/inconnues sont traitées comme `autre`.
- Nouveau module « Dossiers métier » Web, piloté par le profil, avec création outbox/serveur des dossiers `work_order`, `repair_order` et `service_order`, transition versionnée et projection des changements entrants.
- Android expose les dossiers métier pour coiffure, beauté et parfumerie ; les familles de types sont alignées. Photo/événementiel est bien une production `work_order`, et non un `service_order`, afin d'autoriser les étapes shooting/post-production.
- Les créations Android contrôlent les principaux champs métier. L'acompte demandé est enregistré dans les métadonnées et ne gonfle plus le montant `paid_xaf`.
- SQL v4 candidat : matrice transactionnelle des transitions génériques élargie pour supporter les cycles couture, menuiserie, impression, événementiel, réparation, coiffure/beauté et interventions.
- Tests de contrat Deno ajoutés pour les créations/transitions des trois objets génériques et leurs cas négatifs de spoofing/scope ; tests Vitest ajoutés pour les profils, leurs champs et cycles.

### État de preuve
Les changements ont été poussés uniquement sur `work/naxa-services-completion-20261120`. Les runs observés pendant cette passe :
- Run #511 — [45154162146](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45154162146), SHA `74bcd433ad41f2cb4682b109b503398b3130ee0d`, statut `pending` au dernier contrôle.
- Run #510 — [45154138961](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45154138961), SHA `fef997446eab99db0303d4561bd53a7741b1c95c`, statut `in_progress` au dernier contrôle.
- Dernier SHA de code après les corrections Android : `fcf8d9d6099be65e5680942a5853a2c87d0ea5ce`.

**Aucun de ces statuts pending/in_progress ne constitue un PASS.** La compilation, les tests automatisés, la recette Playwright et la recette Android de cette nouvelle passe restent à confirmer. Les formulaires métier ne démontrent pas la parité complète des modules partagés : agenda et disponibilités, caisse/ventes/paiements/reçus, stock/achats/fournisseurs, CRM/fidélité, RH/commissions, rapports et réseau conservent leurs propres points de fermeture.

La parfumerie est un commerce de détail : ses ventes doivent transiter par le POS/stock/paiements. Le nouveau parcours de dossier ne couvre que les réservations et commandes spéciales, jamais une vente encaissée. Le pressing garde son flux de tickets dédié. Les montants demandés ne sont pas assimilés à des paiements confirmés.

**Verdict N4 maintenu : PARTIEL — non clôturé.** N4-C est engagé pour les profils multisecteurs ; N4-D doit démontrer les builds, tests, projections et échanges réels A↔B. Le SQL v4 reste un brouillon ; aucun environnement hébergé n'a été modifié.

**Garde-fous :** aucune fusion, aucun commit sur `main`, aucun déploiement et aucune migration sur le Supabase historique NAXA/pharmacie.


### Addendum — corrections après exécution des premiers jobs — 23 novembre 2026

Le run #511 `45154162146` (SHA `74bcd43`) a fourni les premières erreurs reproductibles :
- Vitest : la couture ne contenait pas l'étape `measurement` attendue par le test de parité ; étape ajoutée dans le registre Web.
- Deno : les deux nouvelles fixtures create/status-change avaient des UUID invalides ; leurs derniers groupes ont été corrigés.
- vérification N1 : `OBX-050` était décalé de 34 lignes dans le manifeste ; la référence est actualisée à la ligne source 4053.
- Android : le contrôle d'entrée impose maintenant les données principales du métier et n'écrit plus l'acompte demandé comme somme payée.

Commits correctifs : `91065774967701da2c58f01e0c67dc34dbb5f7e3`, `a609a62059a9cce034abcf871721bb8c19135cec`, `aba1fc497976ef9b7eafb975be66e65e26003316`.

Le run #511 a donc **échoué** sur les trois jobs ci-dessus avant les corrections ; ses autres jobs ont été annulés par les pushes successifs. Le run #512 `45154704480` (SHA `a609a62`) était encore `in_progress` mais n'exposait pas de journaux complets au dernier contrôle. Le run #513 `45154731735` (SHA `aba1fc4`) était `pending` sans jobs visibles. Il n'existe donc pas encore de preuve CI complète et verte pour ces corrections.

**Verdict N4 inchangé : PARTIEL — non clôturé.** La matrice multisecteur et les corrections de sources sont enregistrées ; la compilation, les tests, la recette Playwright, l'APK Android et les tests PostgreSQL doivent encore sortir avec une conclusion explicite sur un SHA unique. Aucun déploiement, aucune migration hébergée, aucune fusion et aucun changement de `main`.
