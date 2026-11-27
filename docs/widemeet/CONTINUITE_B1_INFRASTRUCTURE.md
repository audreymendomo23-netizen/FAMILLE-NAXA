# WideMeet — Continuité B1 : infrastructure et qualification
## 27 novembre 2026 — audit de reprise, B1 NON CLÔTURÉ
Périmètre exclusif B1, aucune intervention métier B2–B6. Branche dédiée `work/widemeet-b1-20261127`, issue de 9bf1e22efad1ccc7e0f7ffe06af527b3ac15cfba (branche source work/widemeet-n0-20261126, deux commits après 0963b9183fc13538ff5e3bfa6f37f422e9598e74). Pas de main, déploiement, migration persistante, dépense, ni modification des applications sœurs.

### Sources croisées et méthode
- [Cahier des charges v1](../../7%20famille%20naxa/01-cahiers-des-charges/12-widemeet.md) : architecture Android natif/Web/PWA, backend isolé, recettes positives/négatives et preuves SHA/run/job. N3 exige capture audio réelle et consentement; N4 exige audio→transcription réelle; B1 qualifie l'infrastructure de ces parcours, pas l'exhaustivité métier N0–N5.
- [Continuité générale](CONTINUITE_WIDEMEET.md) : matrice B1 et barème fixe. [Gate source](../../.github/workflows/widemeet-gate.yml), [audio](../../.github/workflows/family-audio-replay.yml), [worker](../../packages/media-core/widemeet-transcription.mjs), [script Python](../../scripts/widemeet/local-asr.py), [préflight](../../scripts/widemeet/asr-preflight.mjs), [dépendances](../../scripts/widemeet/asr-requirements.txt) lus à 9bf1e22 (gate inchangé depuis 0963b91).
- Réemploi vérifié : [gate NAXA SERVICES à 13810a2](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/13810a2/.github/workflows/naxa-services-technical-gate.yml) : Gradle setup v5/8.7, SDK35, assembleDebug et connectedDebugAndroidTest, KVM. WideMeet reprend cette stratégie et ajoute cache offline et retry Maven borné. Egress/SFU, Replay et stockage privé du socle famille déjà en place. Ne pas réinventer, ne pas copier secrets ou données métier.
- Les preuves historiques restent associées à leur SHA; une qualification en cours ne vaut pas succès. Barème de continuité 1/0,5/0; le dernier bloc reste à 0 tant que la qualification audio+ASR échoue ou n'est pas terminale.

### Matrice des sept blocs B1
| Bloc | Référence 0963b91 | Preuve |
|---|---|---|
| Build/test Android et contrats | Qualifié | [Gate PR](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45984772068), [Gate Push](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45984769041), contrats 192/192, 0 échec/skip, BUILD SUCCESSFUL |
| Émulateur Android 15 / APK | Qualifié | [Job Android](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45984772068/job/140457443687), job terminal success, build et instrumentation; artefact APK prévu avec if-no-files-found:error |
| Web/PWA | Qualifié | [Job Web](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45984772068/job/140457443828), Vite, Chromium 4/4, PDF et Excel indépendants, présence fichiers PWA |
| SQL isolé | Qualifié | [Job SQL](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45984772068/job/140457443748), PostgreSQL 17, 7 marqueurs SQL PASS, scripts draft exécutés |
| Edge | Qualifié (typecheck) | [Job Deno](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45984772068/job/140457443878), auth/room; intégration réelle distincte dans Replay |
| Replay + SFU | Qualifié | [Replay 40 PASS](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45984772124/job/140457443178), [SFU 9 PASS](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45984771966/job/140457442694) |
| Audio + ASR | Non qualifié | [Audio FAILURE](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45984772099/job/140457442981); 14 marqueurs PASS avant échec, dont Egress consentement/retrait/pause/arrêt, export privé et SHA-256; ASR claimed:true completed:false stage:inference reason:subprocess-exit |

**Jauge conservée : 6/7 = 85,7 % (86 %), delta 0.** Qualification isolée, pas une certification release/production ou appareil physique. Gate PR et Push 5/5 jobs chacun vérifiés sur 0963b91.

### Candidat correctif déjà présent (9bf1e22)
Diff 0963b91..9bf1e22 : épinglage des dépendances Python directes, pip check, fichiers modèle local vérifiés, fonction runLocalAsr commune worker/préflight, exécution offline avec HOME temporaire et environnement restreint, diagnostic stage/type en liste blanche, test synthétique en Ogg avec assertions langue, texte, segments et timestamps, conservation du Replay réel. Aucun fournisseur externe d'inférence. La cause interne exacte de l'échec initial demeure non prouvée : incompatibilité des dépendances hypothèse, non diagnostic confirmé.
Au relevé de la passe :
- [Gate PR 45990659102](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45990659102) : contrats, SQL, Edge et Web SUCCESS; Android en cours.
- [Replay 45990659163](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45990659163) : job SUCCESS.
- [SFU 45990659110](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45990659110) : job SUCCESS.
- [Audio 45990659135](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45990659135) : capture isolée SUCCESS, DB en cours au relevé; préparation du modèle, préflight et Replay ASR non terminés.
Le connecteur de recherche des runs par commit est limité aux PR; aucun statut Push nouveau affirmé sans preuve directe.

### Reprise obligatoire
1. Relever à nouveau le HEAD de la branche source et le statut terminal des runs ci-dessus, puis vérifier les journaux du préflight et du Replay ASR. Ne pas dupliquer le correctif existant.
2. Si échec, analyser le premier défaut causal, stage/type ou installation/CI; corriger uniquement infrastructure B1, garder les assertions métier et le stockage privé. Si préflight passe mais Replay échoue, comparer format, environnement, intégrité et RPC de fin. Si préflight échoue, vérifier dépendances, révision du modèle, décodage et exécution réelle, sans fallback simulé.
3. Requalifier Gate, Replay, SFU et audio sur une même révision candidate; documenter les résultats et les réserves avec SHA/run/job. B1 100 % exclusivement après succès terminal des sept blocs. Ne pas déclarer B3 vert ni développer ses fonctionnalités.
4. À chaque réponse B1 : jauge, variation, preuves, blocage exact, modifications, prochaine action; maintenir ce fichier de suivi. La continuité générale est source de référence partagée; ne pas écraser le travail des autres chantiers.

### Intervention de cette passe
Audit contradictoire du code de qualification, des décisions, du CDC, de la continuité et des logs. Création de la branche et de ce document uniquement; aucune nouvelle correction de code ni relance redondante pendant la qualification du candidat existant. Aucune réussite ASR prétendue.
