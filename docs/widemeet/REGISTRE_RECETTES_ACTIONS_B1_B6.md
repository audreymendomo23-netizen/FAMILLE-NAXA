# WideMeet — Registre unique des actions et recettes B1–B6
27 novembre 2026 — référentiel de qualification, périmètre initial (B7–B12 différés). Version 1.0.

## Comptage et règles
46 blocs historiques, 46 actions de clôture et 269 recettes de niveau scénario = **315 entrées uniques**. Une action par bloc, une recette par résultat observable; une recette peut exiger plusieurs assertions/plateformes et n'est pas le nombre de tests unitaires ou de jobs CI. Les tests déjà verts restent dans le registre de non-régression; le registre n'est pas un décompte de reste-à-faire. Les contrôles génériques sont attribués à B1, les exigences métier à leur propriétaire; les mentions de dépendances ne créent pas de nouvelles lignes. Les propositions/arbitrages et validations physiques/commerciales sont explicitement conditionnels; aucune nouvelle autorisation de déploiement, paiement, migration, achat ou extension du périmètre. Les exigences historiques N0/N1 non couvertes par les 46 blocs sont rattachées à la qualification transversale B1 (identité, parcours, tarifs, fondation) sans créer de nouveau bloc. Les extensions N5 support/admin appartiennent à B5, sécurité/release à B6. Cette granularité est une décision de structuration du registre, pas un nombre contractuel antérieur.

| Bulk | Blocs | Actions | Recettes | Total entrées |
|---|---:|---:|---:|---:|
| B1 | 7 | 7 | 45 | 52 |
| B2 | 9 | 9 | 60 | 69 |
| B3 | 7 | 7 | 37 | 44 |
| B4 | 7 | 7 | 42 | 49 |
| B5 | 6 | 6 | 30 | 36 |
| B6 | 10 | 10 | 55 | 65 |
| GLOBAL | 46 | 46 | 269 | 315 |

## Sources auditées (snapshots immuables)
- [CDC v1 §1–19](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/8fec991a8d25071ed538d933000bf7f6ee5bfac7/7%20famille%20naxa/01-cahiers-des-charges/12-widemeet.md), blob b6f2b18580cc91c4b0652039b8257ab5be30aad1.
- [Continuité principale](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/8fec991a8d25071ed538d933000bf7f6ee5bfac7/docs/widemeet/CONTINUITE_WIDEMEET.md), [matrice N2–N4](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/8fec991a8d25071ed538d933000bf7f6ee5bfac7/docs/widemeet/MATRICE_RECETTES_N2_N4.md), [audit N1–N4](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/8fec991a8d25071ed538d933000bf7f6ee5bfac7/docs/widemeet/AUDIT_CONTRADICTOIRE_N1_N4.md).
- [B1 — continuité](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/d37314c1b2469693fe228d394ea26291dc632910/docs/widemeet/CONTINUITE_B1_INFRASTRUCTURE.md) : d37314c1b2469693fe228d394ea26291dc632910.
- [B2 — continuité](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/8fec991a8d25071ed538d933000bf7f6ee5bfac7/docs/widemeet/CONTINUITE_B2_COMMUNICATION.md) : 8fec991a8d25071ed538d933000bf7f6ee5bfac7.
- [B3 — continuité](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/bb6d27589d8116c8dc70d7163f5911068613d1df/docs/widemeet/CONTINUITE_B3_IA.md) : bb6d27589d8116c8dc70d7163f5911068613d1df.
- [B4 — continuité](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/4a52d5e79be246078e3258e8a997eadc70354c68/docs/widemeet/CONTINUITE_B4_PILOTAGE_REPORTING.md) : 4a52d5e79be246078e3258e8a997eadc70354c68.
- [B5 — continuité](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/c8deaf0c3fc1fd8c01c29e96673c6fcc0e492327/docs/widemeet/CONTINUITE_WIDEMEET_B5.md) : c8deaf0c3fc1fd8c01c29e96673c6fcc0e492327.
- [B6 — continuité](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/d0fb1c409670a54c9c211394d3a2157796b7a059/docs/widemeet/CONTINUITE_WIDEMEET_B6.md) : d0fb1c409670a54c9c211394d3a2157796b7a059.
- Code contrôlé sur 8fec991a8d25071ed538d933000bf7f6ee5bfac7 : workflows widemeet-gate.yml, widemeet-replay-isolated.yml, family-audio-replay.yml, widemeet-fcm-live.yml; scripts replay.mjs (blob 9826315), media-product-replay.mjs (38323e6), media-replay.mjs (aac64f7), et assertions SQL référencées par le gate. Lecture des marqueurs et des jobs; pas d'audit ligne par ligne de tous fichiers ou d'exécution de chaque recette dans cette passe.

## État de preuve au relevé
- B1 dédié e9d70dc : 13/13 jobs et 5/5 workflows SUCCESS. Branche commune 8fec991 : [Gate](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46030023434), [Replay](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46030023440), [SFU](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46030023429), [Audio](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46030023539) : 8/8 jobs PR SUCCESS. Push distinct non vérifié pour ce SHA.
- B2 document 72,2 % (6,5/9), Push foreground Web réel déjà prouvé (46022928052), background et Android live non prouvés sur les preuves lues; nouveau candidat 8fec991. Ne pas déduire le vert FCM du Gate général.
- B3 document 42,9 % (3/7), campagne 0c5cf2f : Gate 5/5, Replay et SFU SUCCESS, Audio live 46016817317 FAILURE (7/8 jobs), cause précise non auditée dans ce registre.
- B4 document 50 % (3,5/7), [campagne fcc84ab](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/46031615352) 5/5 SUCCESS; ne clôture pas les exigences restantes.
- B5 document 58,3 % (3,5/6), gate 45997016574 4/5, Recovery 45997016812 FAILURE (JSX connu), SFU B5 vert historique; correctif support commun 01773a6 qualifié par Replay 44 PASS.
- B6 document 65 % (6,5/10), [campagne 8190030](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45995623039) 7/7 SUCCESS; bail SQL et restauration historique prouvés sur ce candidat, limites physiques/opérationnelles/juridiques restent.
Ces scores sont ceux des documents, non un score recalculé de conformité. Pour chaque ID ci-dessous, inscrire à la qualification : statut NON ÉVALUÉ / PARTIEL / ÉCHEC / SUCCESS / CONDITIONNEL, SHA exact, run/job, artefact/log, environnement (local, CI, hébergé, physique), critères réellement prouvés, réserves. Le registre ne coche aucune ligne par extrapolation d'un workflow. Pour chaque scénario applicable, exécuter positif/négatif, droits, rejeu/concurrence, retour réseau, Android/Web/PWA et backend selon la surface; un skip obligatoire n'est pas vert. Une proposition [P] et un arbitrage [O] n'ont pas valeur d'exigence commerciale validée.

## Inventaire numéroté intégral

### B1.1 — Build, contrats et fondation
- [ ] **B1.1-A01 — Action :** Stabiliser dépendances, caches CI et socle commun; consolider parcours N0/N1 non attribués ailleurs.
- [ ] **B1.1-R01 — Recette :** Contrats Node : exécuter tous les tests domaine, prix, sessions et scripts; zéro échec/skip obligatoire.
- [ ] **B1.1-R02 — Recette :** Compilation Kotlin/JUnit native : versions verrouillées, tâches réelles, aucune tâche de test NO-SOURCE.
- [ ] **B1.1-R03 — Recette :** Résolution Maven : cache froid/chaud, offline, 429/502/503 et miss connu; reprise bornée sur endpoints officiels et échec sur erreur de code.
- [ ] **B1.1-R04 — Recette :** Inscription individuelle réelle GoTrue : unicité, retry exact, mot de passe invalide, pas de droit automatique.
- [ ] **B1.1-R05 — Recette :** Création entreprise, invitation/adhésion multi-entreprises, changement espace; pas de mélange de données.
- [ ] **B1.1-R06 — Recette :** Profil, photo privée, contacts/favoris, groupes de contacts, onboarding 5 onglets, CGU versionnées, reprise et persistance.
- [ ] **B1.1-R07 — Recette :** Dashboard par rôle, affectation manager/staff, promoteur seul payeur, compteurs scope et révocation.
- [ ] **B1.1-R08 — Recette :** Prix Access/Premium mois/année et pass 20/50/100 : frontières, maximum, refus capacité non arbitrée, FCFA entier.
- [ ] **B1.1-R09 — Recette :** Paiement intention : montant/devise/plan, pending sans droit, rejeu, annulation, expiration et accès archives préservé.
- [ ] **B1.1-R10 — Recette :** Paiement réel OM/MoMo, remboursement et reçus [autorisation/qualification commerciale], aucun PIN/OTP ni débit de recette non autorisé.
- [ ] **B1.1-R11 — Recette :** Inventaire logo source exact, marque/nom/domaine, contrastes et charte; arbitrages capacité, quotas, SLA consignés sans promesses fictives.

### B1.2 — Android et artefacts
- [ ] **B1.2-A01 — Action :** Assurer build installable et matrice native reproductible.
- [ ] **B1.2-R01 — Recette :** Gradle SDK35/Java17/KVM : assembleDebug et assembleDebugAndroidTest produisent APK non vide.
- [ ] **B1.2-R02 — Recette :** Instrumentation Compose API35 : navigation, connexion, profil, accès par rôle, absence de crash.
- [ ] **B1.2-R03 — Recette :** Installation APK, lancement à froid, rotation, reprise arrière-plan et restauration sûre d'état.
- [ ] **B1.2-R04 — Recette :** Keystore/PIN quatre chiffres et biométrie : stockage chiffré, refus mauvais code, invalidation; physique pour biométrie.
- [ ] **B1.2-R05 — Recette :** Responsive natif sur tailles et versions supportées, clavier, lecteurs d'écran, zones tactiles et reduced motion.
- [ ] **B1.2-R06 — Recette :** APK archivé avec SHA/taille, installable et signé selon circuit autorisé; ne pas assimiler debug à release.

### B1.3 — Web/PWA
- [ ] **B1.3-A01 — Action :** Qualifier le socle Web responsive et PWA sans fuite de données.
- [ ] **B1.3-R01 — Recette :** Vite build, contrôle routes et navigation 5 onglets, hamburger et droits, textes sans détails techniques.
- [ ] **B1.3-R02 — Recette :** Chromium 320/1440, clavier, lecteurs d'écran, contraste AA, thème clair/nuit Horizon et reduced motion.
- [ ] **B1.3-R03 — Recette :** PWA installation, mise à jour/service worker, cache public uniquement; hors ligne aucun faux login ou mutation officielle.
- [ ] **B1.3-R04 — Recette :** Session Web persistée selon choix, cookie HttpOnly/Secure, reload et logout; aucun refresh secret exposé.
- [ ] **B1.3-R05 — Recette :** Export PDF/XLSX : fixture ouverte par lecteurs indépendants, caractères Unicode, aucune formule injectée; contenu métier B4.
- [ ] **B1.3-R06 — Recette :** Compatibilité navigateurs supportés, reload, onglets multiples, perte réseau et retour; mesurer anomalies.

### B1.4 — SQL
- [ ] **B1.4-A01 — Action :** Standardiser installation complète et non-régression PostgreSQL.
- [ ] **B1.4-R01 — Recette :** Installer tous drafts dans PostgreSQL17 vierge dans ordre exact, ON_ERROR_STOP; vérification intégrité et rollback.
- [ ] **B1.4-R02 — Recette :** Recette syntaxe des littéraux SQL/regex/délimiteurs; rejet des motifs hash malformés RPC/CHECK.
- [ ] **B1.4-R03 — Recette :** Assertions de schéma, contraintes, ACL/RLS, fonctions service-only; contrôle métier détaillé B6.
- [ ] **B1.4-R04 — Recette :** Transactions concurrentes, idempotence et erreurs rollback, aucune fixture persistante.
- [ ] **B1.4-R05 — Recette :** Migration répétable/ordre et compatibilité intégration : inventaire wm_ et préservation des objets sœurs; hébergé seulement autorisé.

### B1.5 — Edge
- [ ] **B1.5-A01 — Action :** Qualifier contrats réseau, environnement et flags.
- [ ] **B1.5-R01 — Recette :** Deno check auth/room/scheduler et nouveaux modules; validation types et entrées malformées.
- [ ] **B1.5-R02 — Recette :** GoTrue/PostgREST réels : HTTP succès/refus, erreurs neutres, CORS/origines, expiration, timeouts, flags fail-closed.
- [ ] **B1.5-R03 — Recette :** Secrets serveur uniquement, redaction journaux et isolation des environnements; aucune clé ou jeton dans APK/JS.
- [ ] **B1.5-R04 — Recette :** Scheduler/Edge : appel autorisé, cadence, reprise et idempotence; aucune exécution hors périmètre.
- [ ] **B1.5-R05 — Recette :** Régression intégrations sœurs et API, contrôle app_id/tenant, rollback sans toucher leurs ressources.

### B1.6 — Replay + SFU
- [ ] **B1.6-A01 — Action :** Piloter une qualification commune cohérente et éliminer les relances redondantes.
- [ ] **B1.6-R01 — Recette :** Gate PR et Push sur SHA identique, déclencheurs paths media-core/audio/scripts/SQL; les deux gates terminaux.
- [ ] **B1.6-R02 — Recette :** Replay GoTrue/Edge/Chromium réel complet avec comptes distincts et absence de mock métier.
- [ ] **B1.6-R03 — Recette :** Replay SFU réel : RTP, média bidirectionnel, screen-share, preuve paquet/décodage, éviction et non-régression.
- [ ] **B1.6-R04 — Recette :** Préparation CI isolée : ports mail TOML local_smtp/inbucket, boucle locale, cleanup même en échec.
- [ ] **B1.6-R05 — Recette :** Perte réponse, lecture agent et session fixture : exact message_id, HTTP 200, trois messages uniques, pas de nouveau login inutile.
- [ ] **B1.6-R06 — Recette :** Audit contradictoire des logs, premier point causal, preuve SHA/run/job/artifact, aucun skip ou vert historique transféré.
- [ ] **B1.6-R07 — Recette :** Intégration B1–B6 par hunks et comparaison des branches, vérifier tous workflows spécialisés avant clôture commune.

### B1.7 — Audio + ASR infrastructure
- [ ] **B1.7-A01 — Action :** Stabiliser chaîne audio et moteur offline sans changer métier B3/B6.
- [ ] **B1.7-R01 — Recette :** Redis/SFU/Egress isolés; capture audio non vide décodable sans piste vidéo, fichier privé.
- [ ] **B1.7-R02 — Recette :** Environnement ASR épinglé, pip check, révision modèle fixe, aucun téléchargement durant inférence.
- [ ] **B1.7-R03 — Recette :** Préflight réel parole synthétique et silence, même environnement worker, diagnostic étape/type non sensible.
- [ ] **B1.7-R04 — Recette :** Replay audio produit complet avec Storage réel, SHA/taille et vérification Whisper horodatée.
- [ ] **B1.7-R05 — Recette :** Résilience infrastructure : ports, démarrage/arrêt, timeout, erreur moteur, nettoyage des fichiers/containers; aucun faux PASS.

### B2.1 — Audio/vidéo, agenda et contrôle de salle
- [ ] **B2.1-A01 — Action :** Finaliser parcours communication et calendrier du CDC §4–5,18, parité native/Web/PWA.
- [ ] **B2.1-R01 — Recette :** Créer/programmer/dupliquer réunion, agenda sujets/temps/responsables, modèles, disponibilité et fuseaux.
- [ ] **B2.1-R02 — Recette :** Récurrence quotidienne/hebdo/mensuelle/personnalisée, édition occurrence/série, annulation et rollback/rejeu.
- [ ] **B2.1-R03 — Recette :** Invitations nominatives/urgence/en cours, lien/QR exact, expiry, RSVP, lobby, verrou et refus tiers.
- [ ] **B2.1-R04 — Recette :** Agenda équipe/entreprise, rappels, modification/annulation/version, ICS si retenu; vues uniques et totales.
- [ ] **B2.1-R05 — Recette :** Vrai A/V entre appareils, caméra/micro gestes explicites, grille/locuteur actif, périphériques et test matériel.
- [ ] **B2.1-R06 — Recette :** Partage écran autorisé, réactions/main levée, file parole, modérateur temporaire et refus d'escalade.
- [ ] **B2.1-R07 — Recette :** Pause/reprise/fin salle, restrictions entrants, chat politique, suspension des flux et reprise correcte.
- [ ] **B2.1-R08 — Recette :** Simultanéité par plan, superviseur bascule sans fuite, capacité atomique et refus supplémentaire (exclusivité B6).
- [ ] **B2.1-R09 — Recette :** Durée : 05:01/05:00, alerte organisateur, +15/30/60/personnalisé, répétition et pause.
- [ ] **B2.1-R10 — Recette :** Prolongation : rôle/tenant/pass/quota, double clic/perte réponse/révision concurrente, historique, reconnect, fermeture réelle à zéro.
- [ ] **B2.1-R11 — Recette :** Qualité présentation Low/Medium/High réellement mesurée, plafond, ratio, distinction caméra, repli et remontée.
- [ ] **B2.1-R12 — Recette :** Modes formation/quiz, entretien, webinaire, sous-groupes, tableau blanc et questions anonymes [proposés, arbitrer].

### B2.2 — Chat privé
- [ ] **B2.2-A01 — Action :** Terminer échange direct temps réel et historique parité.
- [ ] **B2.2-R01 — Recette :** Deux comptes autorisés : envoi, réception, lecture explicite, recherche et pagination.
- [ ] **B2.2-R02 — Recette :** Idempotence, réponse perdue, reconnexion, ordre stable, aucun doublon.
- [ ] **B2.2-R03 — Recette :** Réponses, mentions, signalement et résolution par rôle autorisé; refus de références hors scope.
- [ ] **B2.2-R04 — Recette :** Watch authentifié : changements reçus, arrêt sur révocation, isolement tenant, reprise sans ancienne fuite.
- [ ] **B2.2-R05 — Recette :** Web/Android/PWA E2E sur compte individuel/entreprise selon politique, latence mesurée et offline explicite.

### B2.3 — Chat réunion
- [ ] **B2.3-A01 — Action :** Qualifier collaboration en salle sans contourner modération.
- [ ] **B2.3-R01 — Recette :** Chat salle et privé entre admis, refus tiers même admis au privé; politique d'envoi et lecture.
- [ ] **B2.3-R02 — Recette :** Réactions et main levée via événements réels, ordre, latence et reconnexion.
- [ ] **B2.3-R03 — Recette :** Mentions/réponses/signalement, recherche/pagination, modération et rate limit.
- [ ] **B2.3-R04 — Recette :** Pause/reprise, exclusion, clôture : aucun envoi hors état, visibilité historique selon droit.
- [ ] **B2.3-R05 — Recette :** Parité native/Web/PWA, notifications liées sans fuite de contenu.

### B2.4 — Notifications internes
- [ ] **B2.4-A01 — Action :** Rendre inbox et navigation fiables, sans fausse preuve de réception.
- [ ] **B2.4-R01 — Recette :** Invitation, rappel, annulation/modification, échéance, publication, tâche et expiration au bon destinataire.
- [ ] **B2.4-R02 — Recette :** Lecture explicite et horodatage, refus tiers, navigation vers ressource autorisée et refus après révocation.
- [ ] **B2.4-R03 — Recette :** Rejeu du scheduler sans doublon, retard et rattrapage après interruption.
- [ ] **B2.4-R04 — Recette :** Inbox Android/Web/PWA, compteur et état lu/non lu synchronisés.
- [ ] **B2.4-R05 — Recette :** États envoyé, remis si preuve, ouvert, agenda ouvert, RSVP et lecture distincts; pas de déduction depuis Push.

### B2.5 — WideMeet Connect
- [ ] **B2.5-A01 — Action :** Terminer récepteur distinct source Android vers ordinateur/TV compatible.
- [ ] **B2.5-R01 — Recette :** Code/QR aléatoire à usage unique, expiré/réutilisé/mauvais appareil, confirmation source et politique hôte.
- [ ] **B2.5-R02 — Recette :** Appairage produit réel entre deux installations, autorisation salle/tenant/session, hash exact et refus malformés.
- [ ] **B2.5-R03 — Recette :** RTP décodé sur récepteur subscribe-only, aucune publication, data/chat/enregistrement ou commande.
- [ ] **B2.5-R04 — Recette :** Un récepteur actif, remplacement, renouvellement bail et refus de l'ancien jeton.
- [ ] **B2.5-R05 — Recette :** Filigrane nominatif, indicateur source, arrêt distant et historique.
- [ ] **B2.5-R06 — Recette :** Pas de double présence/vote, choix sortie audio sans écho, source conserve commandes.
- [ ] **B2.5-R07 — Recette :** Pause/reprise, fin, perte droits, sortie source, reconnexion, purge buffers; politique réactivée ne ressuscite rien.
- [ ] **B2.5-R08 — Recette :** Refus mode strict et confidentialité non qualifiée; Android→Web/PWA et TV physique, interop et charge.

### B2.6 — Pièces jointes
- [ ] **B2.6-A01 — Action :** Finaliser fichiers privés direct/groupe/agenda/salle et cycle complet.
- [ ] **B2.6-R01 — Recette :** Formats/taille/signature/nom sûrs, contrôle contenu, malware en quarantaine; refus fichier falsifié.
- [ ] **B2.6-R02 — Recette :** Réservation staging, upload sans écrasement, SHA et taille, publication atomique et retry.
- [ ] **B2.6-R03 — Recette :** Storage privé direct/groupe : ACL au téléchargement et après lecture, refus inter-tenant et non-membre.
- [ ] **B2.6-R04 — Recette :** Agenda/salle : upload hôte, RSVP et périmètre, pause/clôture, accès autorisé.
- [ ] **B2.6-R05 — Recette :** Web/Android/PWA : choisir, annuler, envoyer, télécharger et ouvrir, comparer octets et erreur/retry.
- [ ] **B2.6-R06 — Recette :** Révocation/expiration, nettoyage staging/orphelins, suppression vérifiée et restauration interdite (politique B6).

### B2.7 — Groupes de discussion
- [ ] **B2.7-A01 — Action :** Clore gestion collective, historique et accès membres.
- [ ] **B2.7-R01 — Recette :** Créer/renommer, ajouter/retirer/réadmettre; rôle, tenant et refus membre tiers.
- [ ] **B2.7-R02 — Recette :** Trois comptes réels : envoi, réception, accusés, retry et ordre stable.
- [ ] **B2.7-R03 — Recette :** Historique pré-admission interdit, curseur/pagination et reprise sans fuite.
- [ ] **B2.7-R04 — Recette :** Mentions/réponses/signalements autorisés et résolution, refus identifiant étranger.
- [ ] **B2.7-R05 — Recette :** Watch temps réel, révocation en vol, purge UI et accès réadmission.
- [ ] **B2.7-R06 — Recette :** Parcours natif complet Android/Web/PWA, gestion groupe et latence.

### B2.8 — Messages vocaux
- [ ] **B2.8-A01 — Action :** Qualifier capture volontaire et lecteur sans confusion avec enregistrement de réunion.
- [ ] **B2.8-R01 — Recette :** Permission microphone explicite, capture/arrêt/annulation, limite durée/taille et formats compatibles.
- [ ] **B2.8-R02 — Recette :** Préécoute et envoi volontaire avec UUID stable; aucun envoi automatique.
- [ ] **B2.8-R03 — Recette :** Transport privé, SHA, décodage réel voix, erreur codec et refus fichier falsifié.
- [ ] **B2.8-R04 — Recette :** Lecteur Web/Android/PWA, reprise, révocation purge lecture/cache, refus membre retiré.
- [ ] **B2.8-R05 — Recette :** Appareil physique micro/audio, interruption, perte réseau et interop codecs.

### B2.9 — Push FCM
- [ ] **B2.9-A01 — Action :** Prouver livraison réelle et cycle d'appareil, avec autorisation de test bornée.
- [ ] **B2.9-R01 — Recette :** Inscription token chiffré, opt-in/off, rotation et invalidation, refus autre appareil/tenant.
- [ ] **B2.9-R02 — Recette :** Ledger/scheduler : claim atomique, envoi idempotent, retry borné et invalid token, payload minimal.
- [ ] **B2.9-R03 — Recette :** FCM HTTP v1 réel autorisé, validate_only distinct d'envoi et réception.
- [ ] **B2.9-R04 — Recette :** Chromium foreground : token réel, message reçu exact, pas de lecture déduite.
- [ ] **B2.9-R05 — Recette :** Web/PWA background sans fenêtre : vrai service worker, tag exact, notification et clic autorisé.
- [ ] **B2.9-R06 — Recette :** Android émulateur Firebase : réception réelle au foreground et background, permission refusée, diagnostic sans secrets.
- [ ] **B2.9-R07 — Recette :** Appareil Android physique et navigateur cible : livraison, révocation et suppression token, aucun double envoi.
- [ ] **B2.9-R08 — Recette :** Relais CI OIDC temporaire limité SHA/plateforme/quota, refus non authentifié, expiration et nettoyage.

### B3.1 — Préférences linguistiques
- [ ] **B3.1-A01 — Action :** Finaliser préférences persistantes et capacités affichées.
- [ ] **B3.1-R01 — Recette :** FR/EN interface, langue parlée, écoute, PDF, sous-titres et vitesse mémorisées par compte.
- [ ] **B3.1-R02 — Recette :** Réinitialiser/restaurer sur changement appareil, isolation et validation codes langues.
- [ ] **B3.1-R03 — Recette :** Langue non qualifiée : repli explicite par capacité, aucune clé technique ou support fictif.
- [ ] **B3.1-R04 — Recette :** Préférence PDF et langue en appel appliquées, parité Android/Web/PWA, pas de profilage ethnique.

### B3.2 — ASR et transcription
- [ ] **B3.2-A01 — Action :** Qualifier pipeline durable de l'audio autorisé vers brouillon.
- [ ] **B3.2-R01 — Recette :** Micro réel synthétique Chromium→SFU→Egress→Storage→ASR, identité source et horodatage conservés.
- [ ] **B3.2-R02 — Recette :** FR/EN corpus représentatif, bruit/silence, accents, chevauchements et mesure erreur/latence; autres langues par corpus validé.
- [ ] **B3.2-R03 — Recette :** Job durable claim/lease, retry/crash/multi-instance, aucun doublon et diagnostic non sensible.
- [ ] **B3.2-R04 — Recette :** SHA/segment/durée/ordre/incertitude; fichier corrompu, vide, accès interdit et retrait consentement.
- [ ] **B3.2-R05 — Recette :** UI Android/Web/PWA : états en traitement, erreur/retry et texte horodaté, insertion brouillon non approuvé.
- [ ] **B3.2-R06 — Recette :** Coût, capacité multi-salles et rétention selon arbitrages, limites explicites.

### B3.3 — Diarisation
- [ ] **B3.3-A01 — Action :** Implémenter attribution fiable ou inconnue, sans identité inventée.
- [ ] **B3.3-R01 — Recette :** Deux voix distinctes et alternées, chevauchement et silence; métrique diarisation et horodatages.
- [ ] **B3.3-R02 — Recette :** Association locuteur à identité seulement avec preuve autorisée, ambiguïté marquée.
- [ ] **B3.3-R03 — Recette :** Correction humaine des segments et révisions, journal et propagation au brouillon.
- [ ] **B3.3-R04 — Recette :** Refus accès tiers et anonymisation; corpus multilingue et limites de précision.

### B3.4 — Synthèse sourcée et IA de briefing
- [ ] **B3.4-A01 — Action :** Construire synthèse vérifiable, bilans et questions sur archives autorisées.
- [ ] **B3.4-R01 — Recette :** Résumé exécutif et thèmes, chaque affirmation reliée au segment/source horodatée.
- [ ] **B3.4-R02 — Recette :** Contradictions, incertitude, négations, contenu vide et refus de conclure sans preuve.
- [ ] **B3.4-R03 — Recette :** Briefing réunions précédentes, recherche sémantique et glossaire dans archives autorisées uniquement.
- [ ] **B3.4-R04 — Recette :** Synthèse personnalisée écrite/vocale, bilan périodique IA et questions vocales selon rôle.
- [ ] **B3.4-R05 — Recette :** Tests injection de consignes via transcript, fuite tenant, hallucination, contenu supprimé et citation invalide.
- [ ] **B3.4-R06 — Recette :** Brouillon modifiable par humain, aucun envoi/validation automatique; coût/latence et qualité FR/EN mesurés.

### B3.5 — Extraction décisions/actions
- [ ] **B3.5-A01 — Action :** Distinguer propositions, décisions et engagements attestés.
- [ ] **B3.5-R01 — Recette :** Corpus décisions positives, refus, condition, question, proposition et abstention; pas de faux engagement.
- [ ] **B3.5-R02 — Recette :** Responsable/échéance uniquement attestés, sinon inconnus, citation exacte.
- [ ] **B3.5-R03 — Recette :** Insérer dans brouillon explicite, modification humaine, validation version exacte B4.
- [ ] **B3.5-R04 — Recette :** Concurrence et retry extraction, pas de doublon tâche, accès source et refus tiers.
- [ ] **B3.5-R05 — Recette :** Évaluation précision/rappel et cas difficiles multilingues, audit correction humaine.

### B3.6 — Traduction vocale simultanée
- [ ] **B3.6-A01 — Action :** Raccorder ASR→traduction→TTS personnel sans couper piste originale.
- [ ] **B3.6-R01 — Recette :** Pipeline live réel avec audio traduit audible, qualité sémantique et latence mesurées FR/EN.
- [ ] **B3.6-R02 — Recette :** Sélecteur langue personnelle, vitesse, original disponible, changement pendant réunion.
- [ ] **B3.6-R03 — Recette :** Mutualisation par langue, concurrence plusieurs salles, plafond et coût.
- [ ] **B3.6-R04 — Recette :** Langues premium/locales par capacité qualifiée (Fulfulde, ES, IT, ZH et autres arbitrées), repli explicite.
- [ ] **B3.6-R05 — Recette :** Consentement, révocation et pause/fin : interruption TTS, aucun cache privé résiduel.
- [ ] **B3.6-R06 — Recette :** Parité Android/Web/PWA, appareils physiques et tests réseau dégradé avec B6.

### B3.7 — Sous-titres multilingues
- [ ] **B3.7-A01 — Action :** Finaliser fenêtre live sur capture active et synchronisation.
- [ ] **B3.7-R01 — Recette :** Audio Ogg accessible pendant Egress, traitement avant arrêt; pas de fixture après clôture.
- [ ] **B3.7-R02 — Recette :** Fenêtre original FR/EN et traduction texte effective, horodatage/latence/incertitude mesurés.
- [ ] **B3.7-R03 — Recette :** Changement langue, préférence restaurée, repli Fulfulde/non qualifié et piste originale.
- [ ] **B3.7-R04 — Recette :** Consentement avant/après inférence, autre salle/jeton invalide refusés.
- [ ] **B3.7-R05 — Recette :** TTL, purge fenêtre à retrait/pause/fin et worker crash; aucun résultat ancien ressuscité.
- [ ] **B3.7-R06 — Recette :** UI réelle Android/Web/PWA, débit, multi-salles, contrôle charge et capacités.

### B4.1 — KPI et rapports consolidés
- [ ] **B4.1-A01 — Action :** Compléter agrégations autorisées et visualisations.
- [ ] **B4.1-R01 — Recette :** Périodes calendrier Douala quotidien/hebdo/mois/trimestre/année, frontières et fuseaux.
- [ ] **B4.1-R02 — Recette :** KPI salles, invitations, RSVP, présence observée, votes clôturés, tâches validées et retards; exact dénominateur.
- [ ] **B4.1-R03 — Recette :** Dimensions employé/manager/équipe/service/site/entreprise, relations autorisées et absence de faux rattachement.
- [ ] **B4.1-R04 — Recette :** Promoteur/manager/staff : scope, refus tiers et revalidation droits; données nulles/inconnues explicites.
- [ ] **B4.1-R05 — Recette :** Graphiques, filtres, historique, recherche, consolidation/export et parité Web/Android/PWA.

### B4.2 — Vote simple Access
- [ ] **B4.2-A01 — Action :** Garantir vote simple serveur autoritaire.
- [ ] **B4.2-R01 — Recette :** Oui/non, pour/contre/abstention, éligibles, un vote par personne et rejeu exact.
- [ ] **B4.2-R02 — Recette :** Clôture manuelle/temporisée, refus après échéance, modification selon politique.
- [ ] **B4.2-R03 — Recette :** Anonymat et visibilité, compte agrégé exact et aucun nom exposé.
- [ ] **B4.2-R04 — Recette :** Organisateur/modérateur autorisé seulement, refus non admis/tiers et concurrence.
- [ ] **B4.2-R05 — Recette :** UI réelle Android/Web/PWA et résultat intégré au rapport sans altération.

### B4.3 — Enquêtes avancées et quorum
- [ ] **B4.3-A01 — Action :** Terminer tous formats et règles CDC §6.
- [ ] **B4.3-R01 — Recette :** Choix unique/multiple, notes 1–5/1–10, questions multiples, texte libre.
- [ ] **B4.3-R02 — Recette :** Classement, matrices, modèles et question conditionnelle si retenue.
- [ ] **B4.3-R03 — Recette :** Électorat ciblé figé, refus identifiants invalides/doublons et non-réponse distincte.
- [ ] **B4.3-R04 — Recette :** Quorum, majorité simple/absolue/seuil, abstention, égalité et zéro exprimé; calculs exacts.
- [ ] **B4.3-R05 — Recette :** Anonymat/nominatif, affichage immédiat/différé, modification avant clôture, secret avant clôture.
- [ ] **B4.3-R06 — Recette :** Graphiques, parts/nombres/taux, dénominateurs, export sans identité anonyme.
- [ ] **B4.3-R07 — Recette :** Parité UI et E2E réel, concurrence de clôture/vote et validation version.

### B4.4 — Décisions, tâches et suivi
- [ ] **B4.4-A01 — Action :** Compléter suivi, preuve et continuité interversions.
- [ ] **B4.4-R01 — Recette :** Tâche issue version approuvée, responsable/échéance explicites, refus autres rôles.
- [ ] **B4.4-R02 — Recette :** Preuve texte/fichier privé si exigence, correction, approbation, retour et états.
- [ ] **B4.4-R03 — Recette :** Rappel/retard/escalade, timezone, création nouvelle passée refusée, retry historique exact autorisé.
- [ ] **B4.4-R04 — Recette :** Historique append-only, concurrence/CAS et tableaux par responsable.
- [ ] **B4.4-R05 — Recette :** Remplacement/révocation version : historique et reprise explicite sans ancien droit.
- [ ] **B4.4-R06 — Recette :** Web/Android/PWA E2E, export et notifications B2; IA B3 ne crée pas de tâche approuvée.

### B4.5 — Minutes, PDF, Excel et archives
- [ ] **B4.5-A01 — Action :** Compléter rapport structuré et cycle de validation.
- [ ] **B4.5-R01 — Recette :** Rapport identité/date/durée/agenda, participants, discussions, décisions/votes/quorum, enquêtes, actions, pièces, points ouverts.
- [ ] **B4.5-R02 — Recette :** Brouillon manuel/IA sourcé, correction humaine, approbation exacte et auteur/heure/version.
- [ ] **B4.5-R03 — Recette :** Sélection destinataires, publication idempotente, notification individuelle, refus autres comptes.
- [ ] **B4.5-R04 — Recette :** Versions immuables, remplacée/révoquée, concurrence et historique, accès après pass selon droits.
- [ ] **B4.5-R05 — Recette :** PDF multipage Unicode, filigrane nominatif/identifiant vérification, langue, contrôle pagination et contenu.
- [ ] **B4.5-R06 — Recette :** XLSX indépendant openpyxl, données typées, chaînes non-formules, anonymat, agrégats/extractions consolidées.
- [ ] **B4.5-R07 — Recette :** Archives recherche/filtres, consultation/téléchargement réellement audités, accès révoqué et export non rappelable.
- [ ] **B4.5-R08 — Recette :** Parité native/Web/PWA : génération/téléchargement, erreur/retry, fichier exact et droits au moment de lecture.

### B4.6 — Présences et participation
- [ ] **B4.6-A01 — Action :** Construire registre de transport honnête et complet.
- [ ] **B4.6-R01 — Recette :** Invités/confirmés/excusés/absents/retards selon seuils arbitrés, RSVP et non-réponse.
- [ ] **B4.6-R02 — Recette :** Arrivées/départs observés, durée nette sans doublon, reconnexions et lacunes inconnues.
- [ ] **B4.6-R03 — Recette :** Échantillons SFU réels, écart réseau vérifiable vs inconnu, jamais présence humaine supposée.
- [ ] **B4.6-R04 — Recette :** Observateur durable/scheduler, concurrence, interruption, rattrapage et rapport fermé.
- [ ] **B4.6-R05 — Recette :** Scope Access/Premium et agrégats par période/rôle, export cohérent, refus tiers.
- [ ] **B4.6-R06 — Recette :** Parcours UI natif/Web, contrôle fixture et métriques réelles, aucune sanction automatique.

### B4.7 — Bilans périodiques automatiques
- [ ] **B4.7-A01 — Action :** Implémenter planificateur de rapports non IA et diffusion autorisée.
- [ ] **B4.7-R01 — Recette :** Génération quotidien/hebdo/mensuel/trimestriel/annuel aux frontières calendaires.
- [ ] **B4.7-R02 — Recette :** Idempotence et concurrence worker, rattrapage après panne, absence de doublon.
- [ ] **B4.7-R03 — Recette :** Consolidation période et dimensions, historique et version, exactitude contre requêtes source.
- [ ] **B4.7-R04 — Recette :** Distribution aux rôles autorisés, revalidation à livraison et refus après révocation.
- [ ] **B4.7-R05 — Recette :** UI planification/préférences, export et observabilité sans données privées; mesurer charge.

### B5.1 — FAQ
- [ ] **B5.1-A01 — Action :** Finaliser aide cohérente et accessible.
- [ ] **B5.1-R01 — Recette :** FAQ publique et authentifiée, recherche/thèmes/liens, retour navigation.
- [ ] **B5.1-R02 — Recette :** FR/EN sans promesses fictives, langues supplémentaires uniquement qualifiées.
- [ ] **B5.1-R03 — Recette :** Android/Web/PWA, accessibilité et aide contextuelle selon état/role.

### B5.2 — Tickets et Livechat texte
- [ ] **B5.2-A01 — Action :** Stabiliser cycle support et habilitations.
- [ ] **B5.2-R01 — Recette :** Demande privée, catégories, file masquée, claim atomique et affectation/réaffectation.
- [ ] **B5.2-R02 — Recette :** Deux acteurs : réponse réelle, HTTP 200 sent:true, même message_id, trois messages exactement et auteur; lecture agent.
- [ ] **B5.2-R03 — Recette :** Retry après réponse perdue, polling/reconnexion, aucun doublon et contrôle latence.
- [ ] **B5.2-R04 — Recette :** Refus tiers, agent non affecté, révocation, clôture et état inaccessible si droits perdus.
- [ ] **B5.2-R05 — Recette :** Feedback, suivi, provisionnement/révocation agents, audit et quotas.
- [ ] **B5.2-R06 — Recette :** Android/Web/PWA E2E, accessibilité et aucune donnée réunion/secret visible.

### B5.3 — Récupération supervisée
- [ ] **B5.3-A01 — Action :** Terminer perte de clé avec validation de politique, sans reset abusif.
- [ ] **B5.3-R01 — Recette :** Clé individuelle valide/incorrecte/consommée, changement GoTrue et révocation tous appareils.
- [ ] **B5.3-R02 — Recette :** Code secours préenregistré et preuve de possession, référence opaque; secret jamais à agent.
- [ ] **B5.3-R03 — Recette :** Deux examinateurs habilités distincts, pas d'auto-examen, cas expiré/refus et usage unique.
- [ ] **B5.3-R04 — Recette :** Concurrence et retry exact, clôture du dossier et journal, aucun reset avant preuve.
- [ ] **B5.3-R05 — Recette :** Perte de toutes preuves : procédure indépendante à arbitrer, refus fermé jusqu'à validation.
- [ ] **B5.3-R06 — Recette :** Corriger JSX RecoveryKey et qualifier parcours Web/Android/PWA réel, flags désactivés par défaut.

### B5.4 — Assistance audio
- [ ] **B5.4-A01 — Action :** Finaliser appel support consenti et transport réel.
- [ ] **B5.4-R01 — Recette :** Demande/acceptation/refus, un appel par ticket, droit agent assigné, bail et état.
- [ ] **B5.4-R02 — Recette :** RTP audio bidirectionnel réel deux clients, micro volontaire, aucune réunion jointe.
- [ ] **B5.4-R03 — Recette :** Refus tiers, fin/retrait/révocation agent/session/ticket, ancien grant refusé.
- [ ] **B5.4-R04 — Recette :** Parcours UI Android/Web/PWA, permission micro physique, perte réseau, audit et feedback.

### B5.5 — Partage écran support
- [ ] **B5.5-A01 — Action :** Qualifier capture explicitement consentie, jamais invisible.
- [ ] **B5.5-R01 — Recette :** Demande/acceptation/refus et sélection écran par utilisateur, aucun audio système.
- [ ] **B5.5-R02 — Recette :** Flux réel reçu, refus publication par agent, aucune lecture réunion.
- [ ] **B5.5-R03 — Recette :** Arrêt/retrait, nouvelle autorisation sans résurrection ancien grant, clôture et révocation.
- [ ] **B5.5-R04 — Recette :** Web getDisplayMedia et Android MediaProjection sur appareil physique, course callback/polling et nettoyage.
- [ ] **B5.5-R05 — Recette :** Audit et limites Web/capture externe, compatibilité sécurité B6.

### B5.6 — Administration centrale et interconnexion
- [ ] **B5.6-A01 — Action :** Construire console à moindre privilège selon CDC §12, sans extension B7–B12.
- [ ] **B5.6-R01 — Recette :** Rôles admin/support dédiés, authentification renforcée/MFA si arbitrée, refus élévation.
- [ ] **B5.6-R02 — Recette :** Comptes/organisations/membres/droits : consultation, suspension/réactivation et journal.
- [ ] **B5.6-R03 — Recette :** Offres/paiements/quotas : lecture et mutation explicitement autorisée, aucune opération financière implicite.
- [ ] **B5.6-R04 — Recette :** Incidents, support, langues qualifiées et métriques infrastructure sans contenu réunion.
- [ ] **B5.6-R05 — Recette :** Interconnexion autorisée des solutions sœurs via contrat explicite, pas de doublon facturation ni fuite.
- [ ] **B5.6-R06 — Recette :** Console responsive et audit de toutes mutations, tests négatifs et récupération; aucun déploiement sans accord.

### B6.01 — Sessions, appareils et révocation
- [ ] **B6.01-A01 — Action :** Assurer cycle de session et preuves d'accès.
- [ ] **B6.01-R01 — Recette :** Jeton opaque haché, login/refresh/rotation/logout, expiration et ancien secret refusé.
- [ ] **B6.01-R02 — Recette :** Mauvaise installation, autre produit, compte désactivé et espace retiré : refus.
- [ ] **B6.01-R03 — Recette :** Révocation appareil, password change, changement workspace et sessions concurrentes.
- [ ] **B6.01-R04 — Recette :** Anti-brute force, récupération neutre et rate limit, aucun contournement par fixtures.
- [ ] **B6.01-R05 — Recette :** Client purge données/session sur refus et offline borné; Android Keystore et Web cookie.

### B6.02 — Isolation tenant/salle/produit
- [ ] **B6.02-A01 — Action :** Garantir moindre privilège sur toutes interfaces.
- [ ] **B6.02-R01 — Recette :** RLS et grants table/RPC/storage : anon/authenticated refusés hors contrat, service role serveur seul.
- [ ] **B6.02-R02 — Recette :** Promoteur/manager/staff/invité/modérateur/agent : accès positif et refus scope/tenant/salle.
- [ ] **B6.02-R03 — Recette :** Accès direct API, UUID deviné, token d'un autre produit, données à cache périmé.
- [ ] **B6.02-R04 — Recette :** Révalidation après lecture octets/mutation sous verrou, révocation concurrente et fail-closed.
- [ ] **B6.02-R05 — Recette :** Audit et journaux minimisés; aucun secret ou données métier sœurs, contrôle compatibilité.

### B6.03 — Consentement audio et retrait
- [ ] **B6.03-A01 — Action :** Qualifier état enregistrement et protection participant.
- [ ] **B6.03-R01 — Recette :** Premium/pass et responsable habilité, information visible et audible avant capture, consentements explicites.
- [ ] **B6.03-R02 — Recette :** Refus/absence/nouvel entrant non consentant : aucune capture active ou suspension sûre.
- [ ] **B6.03-R03 — Recette :** Retrait pendant capture : arrêt Egress, discard segment et refus accès; pas de vidéo.
- [ ] **B6.03-R04 — Recette :** Pause enregistrement indépendante de salle, reprise segment nouveau et arrêt normal/hôte/échéance.
- [ ] **B6.03-R05 — Recette :** Consentement pour transcription/sous-titres/traduction et droit de retrait, audit sans secret.
- [ ] **B6.03-R06 — Recette :** Annonce audible réellement entendue sur appareils physiques, erreur TTS visible, aucune garantie inventée.

### B6.04 — Révocation média effective
- [ ] **B6.04-A01 — Action :** Fermer droits réellement dans SFU et stockage associé.
- [ ] **B6.04-R01 — Recette :** Exclusion participant, révocation délégation/session, fin salle : éviction effective.
- [ ] **B6.04-R02 — Recette :** Ancien jeton non expiré refusé, renouvellement et reconnexion interdits.
- [ ] **B6.04-R03 — Recette :** Retrait politique/consentement et pause : fence capture/grant, reprise autorisée distincte.
- [ ] **B6.04-R04 — Recette :** Tests proxy/SFU sous concurrence et crash, pas de fenêtre de réadmission silencieuse.
- [ ] **B6.04-R05 — Recette :** Historique autorisé indépendant de flux, purge client et droits export contrôlés.

### B6.05 — Confidentialité avancée et capture
- [ ] **B6.05-A01 — Action :** Qualifier modes et limites réelles de protection.
- [ ] **B6.05-R01 — Recette :** Standard/confidentiel/strict : politique serveur, refus mode non qualifié et restrictions partage.
- [ ] **B6.05-R02 — Recette :** FLAG_SECURE Android écran complet, rotation/recreation, screenshot/record/casting physiques.
- [ ] **B6.05-R03 — Recette :** Web/PWA filigrane dynamique nominatif et avertissement; aucune promesse blocage OS.
- [ ] **B6.05-R04 — Recette :** Connect refus strict, politique renforcée et appareil qualifié en confidentiel.
- [ ] **B6.05-R05 — Recette :** Détection et réaction aux pertes de capacité, droits restreints, annonce et audit; caméra externe non bloquable.

### B6.06 — Exclusivité média par appareil
- [ ] **B6.06-A01 — Action :** Relier bail SQL durable à publication SFU et Connect.
- [ ] **B6.06-R01 — Recette :** Bail account/installation unique, verrou, renew/release, expiration et révocation SQL.
- [ ] **B6.06-R02 — Recette :** Deux salles concurrentes même installation : une publication autorisée, autre refusée; installations distinctes autorisées.
- [ ] **B6.06-R03 — Recette :** Fencing multi-instance et crash : ancien lease/grant ne republie pas.
- [ ] **B6.06-R04 — Recette :** Connect subscribe-only et pas de double identité; contrôle source/récepteur et sortie audio B2.
- [ ] **B6.06-R05 — Recette :** Tests simultanés SFU réels et bascule Android/Web/PWA sans fuite de flux.

### B6.07 — Réseau faible et résilience
- [ ] **B6.07-A01 — Action :** Qualifier TURN, faible débit et reprise sans fuite.
- [ ] **B6.07-R01 — Recette :** TURN réel, NAT/relais et refus credentials expirés, réseau faible représentatif.
- [ ] **B6.07-R02 — Recette :** Perte paquets/latence/jitter/débit, dégradation adaptative et mode audio économique.
- [ ] **B6.07-R03 — Recette :** Reconnexion, interruption, bascule réseau et recovery sans double présence ni renouvellement interdit.
- [ ] **B6.07-R04 — Recette :** Crash SFU/proxy/worker et failover, éviction/reprise sûre, mesures de transport inconnues.
- [ ] **B6.07-R05 — Recette :** Charge par plan et multi-salles, coût média/IA et seuils SLA arbitrés; appareil physique.

### B6.08 — Rétention, purge et droits
- [ ] **B6.08-A01 — Action :** Terminer effacement vérifié et cycle de vie de données.
- [ ] **B6.08-R01 — Recette :** Politique rétention audio/PDF/chat/transcription/dérivés et droit après pass approuvés.
- [ ] **B6.08-R02 — Recette :** Expiration bloque lecture avant suppression; purge Storage réelle et copie locale vérifiée.
- [ ] **B6.08-R03 — Recette :** Nettoyage staging/orphelins, retry après crash, idempotence, contenu frais préservé.
- [ ] **B6.08-R04 — Recette :** Course purge/export/ASR/revocation, worker multi-instance et registre durable.
- [ ] **B6.08-R05 — Recette :** Suppression des minutes, fichiers, transcriptions, chat et dérivés; journal minimisé.
- [ ] **B6.08-R06 — Recette :** Demandes accès/rectification/effacement, preuve de traitement, limites copies exportées et backups.

### B6.09 — Sauvegarde et sécurité opérationnelle
- [ ] **B6.09-A01 — Action :** Qualifier restauration, durcissement et exploitation.
- [ ] **B6.09-R01 — Recette :** Archive chiffrée, manifeste SHA/taille, chemins sûrs et refus clé erronée/altération.
- [ ] **B6.09-R02 — Recette :** pg_dump/pg_restore réels, ACL/RLS et Storage privé restaurés dans environnement jetable.
- [ ] **B6.09-R03 — Recette :** Ancienne archive contenant objet expiré : registre courant avant/après, refus indisponible, suppression compensatoire.
- [ ] **B6.09-R04 — Recette :** Reprise crash et historique complet SQL : aucune résurrection d'accès/purge, stratégie WAL/backups tiers.
- [ ] **B6.09-R05 — Recette :** XSS/CSRF/injection, limites payload, analyse dépendances/secrets, antivirus/validation contenu.
- [ ] **B6.09-R06 — Recette :** Chiffrement transport/stockage, clés, MFA sensible si validée, audit, supervision, incident et récupération.
- [ ] **B6.09-R07 — Recette :** Plan backup/restore autorisé, RPO/RTO et tests charge; aucune restauration production non autorisée.

### B6.10 — Langues, transparence et conformité
- [ ] **B6.10-A01 — Action :** Clore informations, droits et validation juridique sans promesse non qualifiée.
- [ ] **B6.10-R01 — Recette :** FR/EN exhaustif : interface, erreurs, notifications, CGU, FAQ, PDF, consentement et sécurité.
- [ ] **B6.10-R02 — Recette :** Langues premium/locales par capacité (UI/ASR/traduction/TTS/PDF) et validation locuteurs natifs.
- [ ] **B6.10-R03 — Recette :** Registre finalités/sous-traitants/transferts, consentement, durée et droit de retrait; validation juridique avant release.
- [ ] **B6.10-R04 — Recette :** Demandes confidentialité via support et rôle habilité, pas de transmission de secrets.
- [ ] **B6.10-R05 — Recette :** Information honnête sur capture, E2EE non revendiqué, copies exportées non rappelables.
- [ ] **B6.10-R06 — Recette :** Gate release : revue loi applicable/CGU/PC, accessibilité, appareils physiques, coûts et autorisation propriétaire; B7–B12 exclus.

## Fermeture et exploitation du registre
À chaque passe : sélectionner les IDs, grouper les modifications, diagnostiquer les échecs par contradiction, ne pas relancer un SHA déterministiquement rouge, exécuter les recettes applicables sur le même candidat, compléter les preuves, mettre à jour continuité autonome/principale. Les cinq workflows globaux (Gate PR/Push, Replay, SFU, Audio) plus les spécialisées concernées doivent être SUCCESS sur une révision cohérente avant vert intégré. Ne pas écraser un fichier partagé ni affaiblir un contrôle pour obtenir SUCCESS. Aucun main, déploiement, migration persistante ni dépense initiés par ce registre.
