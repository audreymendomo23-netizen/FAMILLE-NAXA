# Continuité ZIPPLE — 26 novembre 2026
## Référence
Cahier gelé : ../../cahiers-des-charges/ZIPPLE_V2_0.md. Audit : AUDIT_N0_ZIPPLE.md. Matrice : MATRICE_N0_ZIPPLE.md. Contrat tarifaire : POLITIQUE_COMMERCIALE_ZIPPLE.json. Le promoteur a validé les modules réutilisables de NAXA, NS, JOBLY et Famille. Traitement en bulk, jamais une sous-tâche isolée comme résultat final.
## Architecture et méthode
Android Kotlin/Compose entièrement natif; Web/PWA responsive distincte; pages QR invité sans compte; cible Famille NAXA distincte à confirmer techniquement; aucun accès aux données d'autres applications. Audit → contradiction → cause → correction → preuves → doc → état. Ne pas modifier NAXA Services ni NAXA, aucun déploiement/APK/migration production sans autorisation. Reprendre le code existant après audit de compatibilité, pas de fusion aveugle.
## Plan d'exécution
| Niveau | Lot bulk | Gate minimal |
|---|---|---|
| N0 | inventaire sources, identité, cahier, contrats, matrice, backend | preuve de l'archive JOBLY ou décision explicite de ne réutiliser que sa documentation; arbitrages droits et fermeture contradictions de cadrage |
| N1 | socle Android/Web/PWA, auth, organisation, RLS, thème, locale, offline | builds réels, tests auth/session/PIN, routes et isolation, queue offline, design |
| N2 | billing, droits, administration et parrainage PME | 4 prix, refus 3/6, aucun prix obsolète, provider verified, 5 filleuls, reward idempotent, gates droits |
| N3 | Restaurant, Bar, Snack-Bar simultanément | commandes, menu, table/réservation, tickets, postes et absence livraison Snack |
| N4 | QR public, commandes sans compte, disponibilité, délai, feedback | tests anonymes et inter-session, dernier article concurrent, délai serveur, notation |
| N5 | ERP : caisse, stock, recettes, consignes, achats, dépenses, compta, équipe, CRM, fidélité | local+serveur, réconciliation, annulation, coûts, rapprochements, multisite |
| N6 | intégrations livraison, NAXA Security, notifications, support, partenaires | tests API, autorisations, pas de fuite, aucune activation GRILLAD sans accord/contrat |
| N7 | IA, projections, tableaux de bord et performance | données réelles, explications, no autonomous mutations, consolidations |
| N8 | recette complète Android/Web/PWA, test RLS, sécurité et préparation livraison | preuve par exigence, build/tests/recette, aucun déploiement sans accord |
## État au dernier contrôle
N0 PARTIEL : audit et docs réalisés en bulk. Contrat ZIPPLE vérifié en mémoire (16 checks), sans intégration production. Ouvert : lecture du ZIP JOBLY, droits détaillés, correction et tests runtime billing (N2), compatibilité effective backend et recettes (N1–N8), Connect conditionnel. Aucun N1 lancé. Aucune preuve inventée. Reprendre au dossier N0, traiter les réserves ensemble, ne pas redémarrer les audits déjà prouvés.

### Reprise bulk
Contrat exécutable ZIPPLE et tests ajoutés sous contracts/; 31 contrôles en mémoire réussis avant commit. Le workflow ciblé ne déploie rien et ne réécrit aucun autre socle. Matrice détaillée candidate ajoutée; validation commerciale des droits non arbitrés et audit sémantique JOBLY restent ouverts. Aucun appel backend d'écriture ni lancement N1. Ne pas déclarer N0 vert sans preuve.

### Preuve de reprise
Run GitHub Actions 45783733195 (job 139785200082) VERT : tests Node ZIPPLE et inventaire JOBLY. Archive intégrité vérifiée, 726 fichiers candidats, 12 modules ciblés pour inspection structurelle. Audit backend complémentaire lecture seule : 11 tables NS, RLS activée, aucun SELECT anon. Ne pas appeler les tables NS depuis ZIPPLE. La matrice de droits candidate reste à valider pour les options commerciales; la CI n'est pas une recette backend ZIPPLE.

### Dernière preuve
Run 45783895660, job 139785736136 : SUCCESS, 31/31 tests Node, 12 modules JOBLY inspectés statiquement. L'inventaire JOBLY est désormais acquis; la réutilisation de code reste conditionnée à une revue ciblée lors des intégrations. Les droits optionnels et quotas ne sont pas approuvés; compatibilité backend et raccordement facturation non prouvés. N0 PARTIEL selon ses critères initiaux. Ne pas relancer les audits archive et contrat déjà verts.

### Troisième passe bulk : recette technique verte
Run 45792810950, commit 32d0cd2ef13cf570548b48d299fdc29f25ef0202, jobs 139815827440 et 139815827943 : SUCCESS. 31/31 tests JS; JOBLY inventaire et 12 modules prioritaires; PostgreSQL 17 réel éphémère : quatre prix, refus 3/6, isolation app/org/site, rôle, compte révoqué, inactivité, anon, options avec/sans grant et absence d'écriture client. N0 technique VERT dans son périmètre de cadrage et faisabilité. N0 global PARTIEL : restent les décisions commerciales détaillées exigées par le cahier §21.1; droits non définis refusés par défaut. Aucun droit fictif considéré validé. Raccordement réel du backend/clients et paiement à N1/N2/N6; aucune mise en production. Reprendre sans rejouer les contrôles déjà validés, sauf modification des contrats.

## N1 — lancement en bulk
Voir n1/ETAT_N1.md. Socle ZIPPLE Android/Web/PWA modifié sur commit 1952cf7946ccef49292ca9e55fba77dde2d39ea6; recettes ciblées lancées séparément. N1 PARTIEL avant preuves, pas d'API ZIPPLE réelle ni de migration hébergée.

## Reprise — commit 4616b08128fadb0a65dcf4dda652366d6fb4f2b3
Gestionnaire de PIN par membre repris de NAXA Services (Keystore HMAC et backoff), biométrie du socle commun, expiration de session et Room avec scopes app/org/member/site et déduplication. Tests unitaires PIN ajoutés. Le changement de schéma Room v1→v2 n'a pas encore de migration testée; aucun effacement automatique autorisé. WorkManager et reçus serveur restent à raccorder. Premier run 45794002307 : Web SUCCESS (13/13, build et assets); Android encore à constater. Nouveau contrôle navigateur desktop/mobile et nouveau build Android lancés pour le dernier code. Pas d'intégration de production.

### N1 — dernières preuves et couverture offline
Run 45794318728 : Android et Web SUCCESS, y compris APK debug, 13 tests web et recette navigateur FR/EN mobile/desktop, thème, formulaire, SW. Run 45794464457 : web SUCCESS, 26 tests Node (session + frontière serveur à fournisseur simulé) et navigateur. Commit 325ef34ba283a05780a36137474956812f0f7ff5 : migration Room 1→2 conservant les anciens événements non scoped en quarantaine, WorkManager et reçu scope. Commit 75d934ab65dc6af43624ad3be527885601cff400 : raccordement Web IndexedDB, récupération et révocation distante, indication réseau et attente, synchronisation avec reçu. Tests offline et build du dernier lot lancés. Il ne s'agit pas de la preuve d'une API ZIPPLE hébergée. Aucun provider Supabase ZIPPLE n'est configuré; le gate auth réel, RLS ZIPPLE réel, UI Android instrumentée, migration Room sur émulateur, installation PWA et parité offline réelle restent à démontrer. N1 PARTIEL. Aucun déploiement ni N2 lancé.

### Dernier point de contrôle N1
Run 45794464457 SUCCESS (Android job 139821452179, Web job 139821452490), 26 tests Node, build APK debug, navigateur responsive. Dernier lot offline : run 45794746665, commit e9ffe74893cf55a2c56bfb14184c20085452c8ce, état observé in_progress, conclusion non disponible, jobs android=in_progress, web=in_progress. 
N1 reste PARTIEL tant que l'API réelle ZIPPLE, la recette Supabase/RLS propre à ZIPPLE, le test UI/Keystore/biométrie/Room sur appareil et la synchronisation réelle ne sont pas prouvés. Ne pas confondre les builds/tests avec un raccordement production. Le risque du générateur global qui régénère les socles reste identifié. Aucune autre application, migration hébergée ou publication APK modifiée.
