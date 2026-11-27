# WideMeet — Continuité du chantier B3 : intelligence artificielle

## 27 novembre 2026 — Audit de reprise contradictoire
Périmètre exclusif B3. Branche isolée `work/widemeet-b3-ia-20261127`, base immuable `4a44293ec3d5541cb0ce790485d4be5a292af154` (branche d'origine work/widemeet-n0-20261126). Pas de modification des chantiers B1/B2/B4/B5/B6, de main, de production, de migration persistante, de déploiement ou de dépense. Les dépendances avec les autres bulks sont des interfaces, pas une autorisation de les modifier.

Sources : [continuité générale](CONTINUITE_WIDEMEET.md), [CDC WideMeet](../../7%20famille%20naxa/01-cahiers-des-charges/12-widemeet.md) §§5, 7, 8, 9, 11, 14–16, code lu à la base ci-dessus et logs CI réels. Décisions utilisateur retrouvées : B3 = transcription automatique, identification des intervenants, synthèse sourcée, extraction des décisions, traduction simultanée et sous-titres multilingues ; six langues, bilan intelligent et questions vocales également demandés dans des échanges B3 antérieurs. Le CDC prévoit validation humaine et diffusion sélective, et distingue langue sélectionnable et capacité réellement qualifiée. Les identités des locuteurs ne doivent jamais être inventées. Les bilans IA/questions vocales sont à rattacher aux blocs IA ; le reporting non IA reste B4. Les six langues candidates FR/EN/Fulfulde/ES/IT/ZH proviennent du CDC et du précédent familial, non une certification de traduction. Les arbitrages fournisseur, coût, quotas, corpus et langues locales restent ouverts.

## Matrice fixe B3
Notation 1 = fonctionnalité qualifiée sur son périmètre, 0,5 = code ou sous-recette prouvés mais chaîne incomplète, 0 = réalisation non démontrée. Cette notation n'est pas le taux des workflows.
| Bloc | État | Score | Contradiction / recette de clôture |
|---|---|---:|---|
| B3.1 Préférences linguistiques | Qualifié pour la mémorisation | 1 | LanguageCenter.tsx/.kt, replay.mjs 189–198 et 565–578 : persistance, reset, isolation et parcours navigateur PASS. Ni traduction ni voix physique qualifiée. |
| B3.2 ASR et transcription | Partiel, sous-recette moteur verte | 0,5 | local-asr.py + widemeet-transcription.mjs + widemeet_transcription.sql + TranscriptionPanel.tsx/.kt. ASR offline réellement exécuté sur parole synthétique distincte du fichier Egress ; manque la chaîne parole en réunion -> capture -> ASR -> brouillon réel Android/Web/PWA, corpus multilingue, worker durable. |
| B3.3 Diarisation | Non démontré | 0 | Le résultat Python n'a aucun identifiant locuteur ; les deux UI indiquent explicitement locuteurs non identifiés. Tester deux voix, chevauchements, inconnus, incertitude et attribution autorisée. |
| B3.4 Synthèse sourcée | Non démontré | 0 | Insertion manuelle d'extraits horodatés != synthèse IA. Réutiliser minutes/versioning et modèle briefing familial ; produire brouillon cité et vérifiable, incertitude, bilans IA et questions vocales sur sources autorisées, tests anti-hallucination/injection. |
| B3.5 Décisions/actions | Non démontré | 0 | Workflow humain de minutes/tâches existant ne démontre pas extraction automatique. Distinguer proposition/refus/décision et responsable/échéance seulement attestés, citer segment et horodatage, validation humaine avant publication. |
| B3.6 Traduction vocale | Non démontré | 0 | LanguageCenter affiche indisponibilité traduction simultanée. ASR -> traduction -> TTS, écoute personnelle et piste originale, mutualisation, latence, repli et qualification par langue. |
| B3.7 Sous-titres multilingues | Non démontré | 0 | Préférence sous-titres != flux sous-titres. Tester synchronisation, affichage original/traduit, changement de langue et coupure à révocation. |

**Jauge fonctionnelle stricte : 1,5/7 = 21,4 % (21 %).** Inchangée par prudence par rapport au relevé 0963b91 : progrès réel sur B3.2, mais pas de fermeture de toute la chaîne. Sous-recette audio/ASR : passée de FAILURE à SUCCESS ; ne pas transformer cette preuve en vert complet B3.

## Preuves immuables
- [Audio 45989636203](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45989636203), job 140473896480 SUCCESS : préflight ASR local identique au worker, Egress audio-only réel et Storage privé avec SHA-256, ASR réel sur fixture de parole synthétique distincte, file hôte seulement, timestamps. Pas de preuve de transcription du flux de parole capturé en réunion ni de diarisation.
- [Replay 45989635931](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45989635931), job 140473895686 FAILURE global, mais PASS explicites préférences langue API et navigateur, minutes versionnées/validation/destinataires et PDF autorisé. Échec à replay.mjs:594 (support B5), hors périmètre B3.
- [Gate 45989636057](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45989636057) FAILURE Android Maven HTTP 429, SQL/contrats/Web/Edge SUCCESS. Ne pas prétendre Android qualifié à cette révision. B1 hors périmètre.
- Le sous-processus échouait sur 0963b91 (job 140457442981). 4a44293 verrouille les dépendances, valide le modèle et ajoute préflight/diagnostics sans audio privé. Succès observé ; cause interne historique précise non démontrée.

## Réutilisation effective / à faire
Code actuel lu : packages/media-core/widemeet-transcription.mjs ; scripts/widemeet/local-asr.py ; supabase/drafts/widemeet_transcription.sql ; apps/web/widemeet/src/{TranscriptionPanel,LanguageCenter}.tsx ; apps/android/widemeet/src/main/java/cm/naxa/widemeet/{TranscriptionPanel,LanguageCenter,MainActivity}.kt ; scripts/widemeet/replay.mjs. La file SQL vérifie session/espace, hôte, Premium acquis, clôture, conservation, SHA et bail ; résultat borné, trois tentatives. Le modèle local renvoie langue/segments/timestamps/incertitude, pas d'analyse sémantique. Les interfaces permettent demande, consultation, retry et insertion explicite dans brouillon. Les fonctions de lecture de résultats doivent être revalidées et l'état privé purgé après perte de droit ; aucun nouveau droit implicite.
NAXA SERVICES référence 13810a2 : lecture directe apps/android/naxa-services/src/main/java/cm/naxa/naxaservices/DailyBriefingCard.kt ; six langues de texte, données confirmées seulement, TTS Android local et indisponibilité explicite. Réutiliser ce patron pour bilan/lecture, pas ses données métier ni le considérer comme un moteur de traduction. Le socle SFU/Egress/Storage privé et minutes est déjà présent ; absence d'ASR sœur non prouvée exhaustivement par cet audit, ne pas inventer une brique commune. Avant nouvelle dépendance, inventorier les modules briefing, média, collaboration et tests de la famille.

## Plan d'exécution B3 uniquement
1. Compléter B3.2 : fixture de parole injectée dans vraie session Egress, intégrité et transcription attendue, corpus FR/EN puis langues qualifiées, silences, erreurs, reprise, refus et chaîne jusqu'au brouillon humain. Auditer worker permanent sans déployer.
2. B3.3–B3.5 en parallèle logique : attribution incertaine, contrats de citations, résumés et extraction de décisions/actions à partir de sources autorisées. Aucun contenu généré ne déclenche une tâche ou une publication sans validation humaine.
3. B3.6–B3.7 : capacité séparée ASR/traduction/TTS/sous-titres par langue ; flux authentifié, piste originale, repli, latence mesurée, tests Android/Web/PWA. Reprendre TTS familial après audit, aucune dépense.
4. Gate B3 ciblé : tests unitaires, SQL/RLS, intégration et E2E positifs/négatifs, concurrence, isolation inter-salle, révocation et vérification de sources ; consigner commit/run/job et résultats terminaux. Couverture physique et commerciale distinctes.

Cette passe est un audit et une création documentaire, pas une livraison de code supplémentaire. Mettre à jour ce document et la jauge à chaque réponse B3 ; aucun point vert sans preuve. Ne pas fusionner vers main ni déployer sans autorisation.


## 27/11/2026 — Campagne B3 groupée, preuve terminale et accélération
Base de qualification 008191863a43c08d811d7c2fa3075386b9ce7a10, PR #4 (brouillon, ne pas fusionner). Quatre workflows terminaux SUCCESS : [gate 45992186337](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45992186337) (5 jobs, dont Android et Web), [Replay 45992186365](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45992186365), [SFU 45992186396](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45992186396), [audio 45992186301](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45992186301). Job audio 140482520696 : PASS ASR préflight, PASS capture micro Chromium → SFU → Egress consenti → Storage privé → ASR offline avec ID source préservé, PASS brouillon privé non approuvé et invité refusé. La chaîne audio anglaise n'est plus une simple fixture injectée après réunion. Les corrections d'état des interfaces sont compilées mais aucune recette interactive native spécifique ASR n'est attestée sur cette base.

Nouvelle campagne limitée à B3, révision code 2c406170d4e141ad1ea344c1173747d337970551 :
- B3.2 : 52f2770 qualification FR/EN sur parole synthétique offline et silence sans texte ; 42cc7f5, dd396b1, 920b392 worker durable (entrée opt-in, arrêt drainant, boucle séquentielle, backoff plafonné, tests, réutilisation du bail SQL SKIP LOCKED et worker réel), 4b9df44 CI test boucle, 2c40617 raccordement de la boucle au vrai Replay. Pas de service déployé ; corpus réel, multi-instance/reprise de lease et parcours natif spécifique restent à prouver.
- B3.4 / B3.5 : 08fbe00 calcul SQL côté serveur des extraits et décisions/actions candidates, après contrôle existant du droit d'accès ASR. Références exactes recording_id/segment_index/horodatage/texte/incertitude, pas d'identité, responsable ou échéance inventés, aucun contenu généré ni validation automatique. Règles conservatrices FR/EN, exclusion de négation, question, incertitude, proposition ; ne garantit pas l'interprétation sémantique ni le contexte intersegments. 758c594 assertions de source exacte, refus anon et filtrage sur fixtures, abbac70 et 767c0f5 parité Web/Android et insertion explicite dans brouillon existant. Ce n'est pas une synthèse générative ni une extraction exhaustive validée ; questions vocales/bilans IA restent ouverts.
- Diff vérifié depuis 0081918 : 9 fichiers, tous B3 ; aucune modification des sœurs, autre chantier, main, production, migration persistante, coût ou déploiement. Syntaxe JS du Replay vérifiée par parsing du corps asynchrone sans imports dans le connecteur, pas une exécution de Node ni un E2E.
- Nouvelle CI : PR #4 mise à jour par commits ; au dernier relevé, recherche des runs sur 2c40617 vide. Ne pas déduire succès ou démarrage confirmé de la nouvelle CI du succès de 0081918.

### Jauge révisée (même méthode, 1 qualifié, 0,5 partiel code ou sous-recette, 0 non démontré)
| Bloc | Score | Etat |
|---|---:|---|
| B3.1 | 1 | Vert préférences |
| B3.2 | 0,5 | Orange avancé : chaîne anglaise prouvée, autres réserves en qualification |
| B3.3 | 0 | Rouge |
| B3.4 | 0,5 | Orange candidat extractif, non génératif |
| B3.5 | 0,5 | Orange candidat à vérifier, pas de décision approuvée |
| B3.6 | 0 | Rouge |
| B3.7 | 0 | Rouge |
Total 2,5/7 = 35,7 %, +14,3 points vs 21,4 %. Indicateur de progression mixte (code partiel + qualification), couverture entièrement verte = 1/7 = 14,3 %. Objectif 25 points non atteint : ne pas modifier la méthode pour masquer les réserves. Prochaine priorité : résultats CI, correction des échecs B3, preuve du worker durable, UI réelle et synthèse/décisions contextualisées ; puis diarisation, traduction et sous-titres.

Addendum de suivi : les quatre recettes de la révision technique 2c406170 sont maintenant visibles, toutes QUEUED au dernier contrôle : [gate 45994452464](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45994452464), [Replay 45994452353](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45994452353), [audio B3 45994452354](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45994452354), [SFU 45994452355](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45994452355). Aucun résultat terminal, jauge 35,7 % inchangée.
