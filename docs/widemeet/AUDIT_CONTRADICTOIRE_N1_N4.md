# WideMeet — Audit contradictoire N1 à N4
Date : 27 novembre 2026. Branche work/widemeet-n0-20261126, PR #1 brouillon. Révision de code 49f32852687af2602e209410afa30e5f0c90aa40.
 
## Base de preuve
07d9951 : Gate 45959015534 SUCCESS 5/5, 187/187 contrats 0 fail/skip ; Replay 45959015527 SUCCESS ; SFU 45959015561 SUCCESS ; audio 45959015548 SUCCESS. Le CDC demeure plus large que les scénarios.
 
## Contradictions et corrections enregistrées
| Module | Hypothèse réfutée | Correction | Qualification observée |
|---|---|---|---|
| N1-23 | Un pass payé et consommé suffit à rendre la réunion individuelle utilisable | Rejeu exact de création via digest privé + consommation atomique inchangée ; tentative identique Android/Web ; invitation externe nominative confinée à une salle | Rejeu pass PASS 45963997472 job 140388518925 ; externe candidat fc4197f / 252bf85 |
| N1-03/04 | Un collaborateur retiré ne peut pas bloquer la réunion | Normalisation des membres révoqués sous transaction, coupure de recording et projection de l'état réellement persisté | Gate 45963432060 5/5 et Replay 45963432033 SUCCESS ; nouvelle couverture ciblée à renforcer |
| N2-06/09 | L'expiration des grants ferme nécessairement la réunion | wm_close_due_rooms service-only, horloge serveur, SKIP LOCKED, état ended et raison deadline ; adaptateur tick | WIDEMEET_EXPIRY_SQL_PASS 45963432060, 45964420188 ; déploiement/scheduler régulier non réalisé |
| N2-07/08/11 | Une invitation externe peut être assimilée à une adhésion à l'entreprise | wm_external_guests RLS, destinataire enregistré, token 256 bits hashé, max 24h pour utilisation, lobby obligatoire, droits staff limités à salle, refus compte tiers et révocation ; interfaces Android code et Web lien fragment | Candidat fc4197f, Replay 45964420186 en cours ; SFU/audio réels externes 45964420200/45964420185 en cours |
| N3-12/13 | Vote ouvert implique que l'échéance est respectée | Durées 15–3600s bornées par fin de réunion, vérification serveur et projection résultats à échéance, champs Android/Web | 188/188 contrats 45964420188 ; E2E UI et horloge réelle résiduels |
| N3-14 | Arrêter la salle équivaut à arrêter normalement la capture | normal_stop reconnaît fin explicite hôte, vérifie consentement et comptes, toute exclusion nouvelle force discard ; annonce explicite et état de consentement personnel | Gate d0966c1 5/5 ; capture à fin hôte réelle candidate 252bf85 ; purge/annonce audible/traduction non qualifiées |
| N4-16/17/20 | Expiration du paiement à la clôture détruit les droits aux minutes | Droit de départ et échéance enregistrés côté serveur ; éligibilité Premium à l'échéance normale vérifiée ; exclusion des participants restés en attente pour les destinataires | WIDEMEET_EXPIRY_SQL_PASS, 45963432060 |
| N4-17/18 | Publication et tâches suffisent à informer les destinataires | wm_notices dérivé des droits : invitation/rappel 24h, minutes publiées, tâches/retards/validation, abonnement promoteur 72h ; lecture propre au compte, UI accueil | Replay 45963997472 PASS (avis publication et accusé de lecture, tiers refusé) ; push FCM et rappels planifiés réels non qualifiés |
| N4-21 | Un PDF suffit à couvrir tous les rapports | wm_report_export Premium hôte, journal de demande, synthèse + présences observées + tâches + votes agrégés ; véritable OOXML XLSX, chaînes non-formules ; Web/Android téléchargement | 49f3285 candidat, lecteur indépendant openpyxl et E2E ajoutés, non terminaux |
 
## Erreur traitée
Gate 45963767069 SQL et Replay 45963767132 échouaient avant les tests sur le prédicat digest de wm_room_creation_replay (substitution de chaîne ayant retiré la fin de regex). Correction 5b7f187 : prédicat ancré SHA-256 préservé. Replay 45963997472 SUCCESS avec PASS exact paid room creation replay et PASS recipient-scoped notice. Audio 45963997519 SUCCESS.
 
## Limites et décisions conservatrices
- Rejeu de création : digest canonique de requête ; pas d'identifiants de paiement inventés ; passerelle réelle OM/MoMo non qualifiée. Les tarifs WideMeet restent distincts du catalogue de maturité des sœurs ; aucune maturité ajoutée. N1 CGU approuvées, biométrie physique, remboursement et capacité négociée restent ouverts.
- Invités externes : compte WideMeet enregistré et authentifié, invitation nominative, pas d'anonymat, pas d'adhésion entreprise, lobby nécessaire, réservation conservatrice 24 h, aucun QR natif, accès aux archives externes non activé ; liste contact/administration demeure propre au tenant. L'E2E média doit prouver vraie connexion et révocation. Aucune invitation publique libre.
- Expiration : procédure et adaptateur testés séparément, pas de service planifié ou production. Ne pas assimiler fermeture SQL à disponibilité 24/7 d'un worker. Les segments audio à échéance automatique restent conservateurs ; fin hôte explicite seulement en qualification nouvelle.
- Notifications : in-app dérivées, pas FCM, SMS, email ni WhatsApp. Délais 24h/72h proposés pour recette, à valider.
- Rapport Excel : aucune identité de vote anonyme exposée, données d'observation SFU non assimilables à une présence humaine ; pas de preuve de livraison après téléchargement, pas d'export global entreprise qualifié.
- Reste à faire : N2 QR, TURN/weak network/Connect, pièces jointes, vocal, simultanéité micro, récurrence série édition/fuseaux, tests physiques ; N3 mode strict, annonce audio, purge/backup, concurrence worker, votes avancés ; N4 ASR/transcription et traduction simultanée réelle, Fulfulde exhaustif, génération IA sourcée et validation, notifications push, pièces justificatives et rapports consolidés. Aucun fournisseur réel de paiement/ASR qualifié dans les preuves actuelles.
 
## Matrice terminale du dernier code
Révision 49f32852687af2602e209410afa30e5f0c90aa40 : Gate 45964621884 pending, Replay 45964621929 pending, audio 45964621877 en cours, SFU 45964621875 queued au dernier relevé. Révision 252bf85 Gate 45964420188 4/5 (188/188 contrats, SQL/Web/Edge success, Android en cours) ; autres recettes non terminales. Tous les nouveaux candidats restent non verts jusqu'à résultats terminaux et conformité fonctionnelle exhaustive.
Aucun N5, main, fusion, hébergement Cloudflare, migration persistante, paiement réel ni dépense.


## Reprise 09:53 — base 25e580b puis 35b3108
25e580b : les quatre workflows sont terminaux SUCCESS (45967726452, 45967726280, 45967726329, 45967726386). Gate 5/5, contrats 188/188, aucun fail ou skip ; navigateur, Android émulateur/Keystore, PostgreSQL, Edge et média jetable sont qualifiés dans le périmètre exécuté.
35b3108 : code de déverrouillage biométrique lié à une opération Keystore sur une enveloppe du refresh token, identité et espace dans les clés des composants, filtrage caractères XML interdits et test Android après purge. Nouveau candidat non qualifié au dernier relevé (45969439007, 45969439067, 45969439051, 45969439145).
Correctif complémentaire : Android et Web affichent un avertissement si l'annonce TTS échoue, sans certifier qu'une annonce a été entendue. Fixture XLSX injectant U+FFFE/U+FFFF dans le titre, le lecteur openpyxl existant doit retrouver le titre nettoyé sans formules. Recettes du nouveau candidat à relever. Les dépendances externes et scénarios physiques, pipeline IA/transcription/traduction, récupération supervisée, push et purge réelle restent non qualifiés. Aucun main, production, Cloudflare, N5 ni dépense.
