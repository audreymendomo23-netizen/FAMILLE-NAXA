# WideMeet V2 — Audit des reprises familiales
28/11/2026. Audit en lecture seule des arbres Git et d'extraits de sources aux SHA exacts, non exécution des tests ni certification des modules. Priorité à WideMeet déjà intégré ; réutiliser comportements/contrats et non l'UI des sœurs. Master graphique intangible, pas de cartes décoratives. Les preuves anciennes B1–B6 ne valent pas qualification V2.
## Snapshots
| Dépôt / branche | SHA | Niveau |
|---|---|---|
| FAMILLE-NAXA / work/widemeet-integration-b1-b6-20261127 | 93f269e763dd8be53f7f85990371393dc93ea940 | arbre + sources ciblées |
| FAMILLE-NAXA / work/naxa-services-completion-20261120 | ca2847257675e1903a60ce37054a9e6d41f0132f | arbre + sources ciblées |
| FAMILLE-NAXA / work/zipple-completion-20261126 | f412b831a8635839cdc07784119f515107e2313c | arbre + sources ciblées |
| FAMILLE-NAXA / work/grillad-foundation-20261127 | 1e1dc7fa6b4ec1acf0a1510479985a4b373e6915 | arbre + sources ciblées |
| FAMILLE-NAXA / work/naxa-security-completion-20261128 | 0724f304e958e5a190bb051dac2fe01e43292477 | arbre + sources ciblées |
| FAMILLE-NAXA / work/bootik-n0-20261126 | 3313aa2d3844c7e7efe2cc9d9a7193c387063ac0 | arbre + sources ciblées |
| FAMILLE-NAXA / work/loyable-continuity-20261121 | 877c895cf61e62d90d91e52d5606a8f136682e9b | arbre + Web shell |
| FAMILLE-NAXA / main | 2fe794497cafee37133dcc28e3da7fa2f85f426f | arbre commun + Campus shell |
| NAXA / main | 4acbab129b403ef87e879c87e99793fb9d35e98f | arbre + sources ciblées |
Liste connectée : deux dépôts NAXA et FAMILLE-NAXA ; pas de dépôt JOBLY identifié. CAMPUS237, COTIZ, KIOSKO, NAXA HOTEL ont quatre fichiers app TS/KT/SQL/mjs chacun à main inspecté (MainActivity, OfflineQueue, main.tsx, vite config). Campus Web lu : shell PWA, Loyable Web lu : shell PWA. Aucun module de publication, courrier, annuaire prêt à reprendre démontré dans ces arbres ; cela ne prouve pas leur absence d'autres branches/dépôts. Aucune reprise métier supposée depuis cahier seul.
## Matrice 16 actions (R = reprendre WideMeet, A = adapter modèle sœur, N = nouveau métier)
| ID | Source principale / stratégie | Reste spécifique |
|---|---|---|
| V2-01.1 | R Visual.tsx / WideMeetPhoto.kt ; A GRILLAD AtelierAuthVisual | master/asset source, mesure, styles, marque/nav ; ne pas copier fumée |
| V2-01.2 | R SignIn, MainActivity, RoomPanel, MediaPanel, NativeMediaPanel, auth et agenda | reconstitution UI et accessibilité sans perdre droits |
| V2-01.3 | R IdentityPanel, wm_identity_action, ProfilePhoto ; A NAXA admin messagerie fonction_interne et NS roster/photos, BOOTIK rôles | N poste distinct du rôle et par membership, annuaire ACL, fiche, recherche, pas de données RH |
| V2-01.4 | R tests WideMeet existants, composants communs ; A GRILLAD reduced motion | nouvelles captures et comparaison master Android/Web/PWA |
| V2-02.1 | R GroupChat, ChatMedia et contrat chat-media ; A NAXA FilMessages, GRILLAD SupportThread | raccord UX texte/voice/fichiers, formats, reprises et parité |
| V2-02.2 | R MediaPanel + SupportMediaPanel, policy/admission ; A NAXA SupportAudioCall | N cycle appel direct, sonnerie, acceptation, refus, historique vidéo/audio, pas de droit support |
| V2-02.3 | R NoticeInbox, wm_notice_reads ; A NAXA lu_le, marquer_fil_lu ; SEC révocation | N reçus par message/destinataire, notification expéditeur, effacement privé/global ACL/propagation |
| V2-02.4 | A NAXA présence agent ; R identité et session WM | N présence opt-out avec TTL multi-appareil, projections sans fuite, filtre ; présence réunion != en ligne |
| V2-03.1 | R groupes, médias et identité ; A ZIPPLE référence source | N posts, audiences, feed, pagination, vidéo traitée |
| V2-03.2 | R room-policy votes/réactions et groupe ; A modèle ACL | N commentaires, réactions persistées, favoris post, modération et sondage hors salle |
| V2-03.3 | R notices et publication minutes/ACL ; A NS notification/ack roster, NAXA push | N annonce officielle versionnée et ciblée, confirmation explicite indépendante de remise |
| V2-03.4 | R identité, notices, tests ; A méthodes visuelles | N fil et liste sobres du master, recettes sociales |
| V2-04.1 | R chat/identité/stockage ; A NAXA FilMessages et admin inbox | N boîte interne, destinataires, objet, brouillons, envoyés, signatures, confirmations, transfert |
| V2-04.2 | R ChatMedia, ArchiveEvidence, recording storage ; A ZIPPLE docs et SECURITY support_attachment | N catalogue ACL source-aware, index sans copies, filtres récents/partagés/mes documents, aperçu/partage |
| V2-04.3 | R session workspace, central NAXA, notifications ; A BOOTIK outbox | intégration droits et routes, non-régression, aucune liaison comptes sœurs implicite |
| V2-04.4 | R workflows/Replay isolé existants ; A méthodes familles | nouveau registre V2 et preuves individuelles ; pas d'exécution ni de score ici |
## Sources lues (chemins relatifs au dépôt correspondant)
### WideMeet : prioritaire
- apps/web/widemeet/src/IdentityPanel.tsx blob 57302bad9704f91652f4c8340ba282fa22b2691d : charge profil/contacts/groupes/invitations/devices/billing par identityAction ; profil courant nom/langue, ne pas inférer poste professionnel du rôle d'autorisation.
- supabase/drafts/widemeet_n1_identity.sql blob cf8e66e13473c38824e7c2f1be2a422c9dffc54a : comptes, workspaces, memberships, sessions, favoris, invitations et groupe, switch workspace ; profile renvoie display_name, locale, workspace et role. Extension poste sur membership, projection minimale contrôlée.
- apps/web/widemeet/src/GroupChat.tsx blob 4e5952522f4e6017d1d12ec8a258d4307af6d0dc : list/thread/members, contacts, curseur 50, watch borné, epochs/reply/mentions. Préserver accès et retry ; compléter tests.
- apps/web/widemeet/src/ChatMedia.tsx blob dfd0373ea1b2477a53a912186224a85dd2202380 : scope peer/group/room, encode/decode/hash, capture/cleanup/revoke ObjectURL, refresh fail closed. Réutiliser API, pas de stockage parallèle. Native ChatMediaPanel.kt repéré seulement.
- apps/web/widemeet/src/SupportMediaPanel.tsx blob 7819ded1bdd7cd95e7c40df5fd20e5ca9340d2a4 : LiveKit, heartbeat, déconnexion, support uniquement (pas de caméra). Ne pas transformer un ticket en appel direct ; nouveau contrat distinct avec accès par participants.
- apps/web/widemeet/src/NoticeInbox.tsx blob a068bc53535173af2ed013fdfae1c36182fc8b89 et supabase/drafts/widemeet_n4_notifications.sql blob 16ba846c3b350b8979115ce8c628eea2134823fb : lecture explicite, relire read_at, wm_notice_reads et push claims/delivery ; notification lue ≠ message lu.
- apps/web/widemeet/src/Visual.tsx blob d63125f069de36a5060d1dcf1c78800e3b0f0d0b : image nommée, eager/lazy et fetchPriority ; adapter au master et conserver qualité. Autres fichiers repérés : RoomPanel, MediaPanel, NativeMediaPanel, ArchiveEvidence, GroupChat.kt, NoticeInbox.kt, ProfilePhoto.kt, media-core signaling/admission/lifecycle, chat-media-purge et recording-storage ; qualification à vérifier avant reprise.
### NAXA historique
- src/components/FilMessages.tsx blob 7d3276ab6968a86407b59f9a1099b272c48774d9 : conversation filtrée, realtime postgres_changes, champ lu_le et RPC marquer_fil_lu, notification après envoi. Limite : RPC appelée au montage ; ne pas copier comme preuve de lecture effective pour chaque nouveau message, ni anonymat/ACL pharmacie.
- src/app/admin/messagerie/page.tsx blob d1b7d80bf93a3a60bdfc75419d49ec7ffeac4526 : jointure auteur nom/role, fonction_interne prioritaire ; boîte tickets, pas courrier général. Reprendre projection sémantique, pas requête admin ni données de patients.
- src/components/support/SupportAudioCall.tsx blob 160fb9fef406c63c1bcf8da8f4a15b9d445b964e : queued/ringing/accepted/cancelled/declined/completed/failed/missed, WebRTC et canal realtime, écran/audio ; modèle d'état, pas transport parallèle à SFU WideMeet.
- src/app/api/support-agent/presence/route.ts blob 48944b2e2bdd376ab0447afd6c94a01f9d00723d : agent habilité met à jour available/unavailable, last_seen, journal ; présence manuelle agent, pas présence globale ni privacy opt-out ; TTL et masque nouveaux.
- src/app/api/messages/push/route.ts blob 13e03109f88329542303fa82ea3840209df2c064 : vérifier session, message et fil, destinataires calculés côté serveur ; ne pas réutiliser rôles, règles, secrets et contenu pharmacie.
- src/components/auth/AuthShell.tsx blob 3a1e4d640df4449d18aca7eae4b5e56d360f831d : safe area/scroll/état auth partagé, pas reprise esthétique.
### NAXA SERVICES
- apps/web/naxa-services/src/erp/staff-roster.tsx blob 34b80644443ba19b654d4ec308a6a3c8c5c2609e : target member/display_name/workstation_id/name, scopes site, acknowledgment shift revision. Ne pas exporter pointage/absence/RH ; adapter uniquement affiliation et confirmation.
- apps/android/naxa-services/src/main/java/cm/naxa/naxaservices/StaffRosterCard.kt blob 79104e7964d342016689d7d2186bc4df8bb8158c : lecture/upload authentifiés et scope chemin, taille bornée ; modèle de contrôle, pas photos de pointage.
- apps/web/naxa-services/src/auth/profile-photo.tsx blob 06574eae9ce78c1cb1994f695cb5f523af629d45 : bucket privé org/member, validation MIME/UUID/HTTPS, taille et dimensions ; WM a sa propre photo, pas de bucket NS ni compression des photos du master.
- supabase/functions/naxa-services-notifications/notification_contract.ts blob eaacb7800bfcaf1ad3347e38c87241f9c89e70eb : normalisation token/payload, limites, transition sent/read/actioned, retry/revoke. Réutiliser logique, pas credentials FCM.
- supabase/functions/naxa-services-meeting-media/media_contract.ts blob 5f177c1ea6f1db8ead826740442cbaeb40c6dc4b : grant signé 90 s et sources contrôlées, candidat, pas preuve service ; WM déjà transport, ne pas reprendre règle screen_share_audio sans consentement.
### ZIPPLE
- apps/web/zipple/src/business/FinanceDocuments.tsx blob 8aa775f20aaf5de500ce541a458184805a98666a : document lié source, request_id stable, digest comparé avant téléchargement, ObjectURL révoquée ; PDF/JPEG/PNG 2 Mo seulement. Étendre formats prouvés WM, pas copier binaire base64 illimité.
- docs/apps/zipple/n2-n5/bulk3-documents.sql blob 5a1a4e76fb0ee90dd4d8ac52e786148c95b3b2a5 : source_kind/id, SHA256, vérification signature fichier, idempotence, FK org/site, droits service-only ; modèle source-linked, pas reprendre tables finance ni stockage bytea pour vidéo. Native documents repérés.
### NAXA SECURITY
- docs/naxa-security/contracts/support-attachment-candidate.sql blob bf06444d95ea2e294ff603f47dcacb3bc47b6a1c : référence à evidence existante, org/site/case/owner, révocation et contrôle rôle/agent ; adapter lien sans copie et droits source, pas le métier support.
- apps/web/naxa-security/src/SupportAttachments.tsx blob ace40f4a2ccae4bd577b4c3eaa424f9370dc80ee : réinitialisation scope, génération anti-race, validation réponse actor/org/site, SHA256 avant download. Feature flag candidat, pas présumer vert.
### GRILLAD
- apps/web/grillad/src/AtelierAuthVisual.tsx blob 8be8e98afa6454238c9161fd42ede1b7c844dc01 : image fixe eager, visibilité page, reduced-motion et pause animation ; reprendre mécanisme pas photo/effet fumée, aucune nouvelle animation non approuvée.
- apps/web/grillad/src/SupportThread.tsx blob f6a435cd05c12a31f5c07ab3f5c6ae6f4cd66d15 : key par ticket, verrou, pending idempotent, refresh visible, envoi non confirmé. Adapter comportement par conversation, pas reprendre article/markup ou créer support parallèle.
### BOOTIK
- apps/android/bootik/src/main/java/cm/naxa/bootik/ScopedOffline.kt blob 62ae11676afbf6a0e6d4f2bdf044d69315b95546 : outbox et cache Room org/member/site, ack conditionnel et discard ; adapter scope workspace/account/device, jamais réunion hors ligne ni contenu privé non révoqué.
- apps/android/bootik/src/main/java/cm/naxa/bootik/BootikSecurityPanel.kt blob 790e6435197f87b9c031df0ae9ae88cc6c453214 : sessions/devices/membres, délégation et rôles ; modèle séparation des droits, ne pas réutiliser rôles retail.
### Socle commun et autres
Main arbre : core-android NotificationChannels, BiometricGate, LocalAppLock, core-kotlin NotificationContract/SyncContract, offline-web/src/index.ts, design-system. Audit d'arbre seulement, vérifier compatibilité et tests avant import. Loyable et Campus Web shells (blobs 8a986681f654831f640da1f14c4594838ccaf698, fc9e1ec8ccca00aa1763937992179c08fe479259) ne fournissent pas un module métier prêt. COTIZ/KIOSKO/NAXA HOTEL : inventaire uniquement ; JOBLY non localisé. Pas de déduction d'une fonctionnalité exploitable à partir du cahier.
## Contrats à figer avant parallélisation
V2-01 propriétaire identité pro et design : projection account/membership/workspace, poste distinct des rôles, scope actif et ACL de fiche. V2-02 propriétaire conversation/appel/présence : TTL et privacy, reçu de message idempotent, autorisations et suppression, notification typée. V2-03 propriétaire post/annonce : audience serveur, versions et accusés distincts. V2-04 propriétaire références fichier et intégration : référence source stable, contrôle accès au moment de list/read/search/download/share, pas de copie par défaut, purge coordonnée. Contrat notifications commun : événement stable, destinataire recalculé côté serveur, pas de contenu privé dans push, deep link revalidé. Pas d'accès implicite admin/support, pas de schéma/table/bucket/secret sœur, pas de copie de données ni de dépendance prod.
## Qualification et limites
Aucune recette nouvelle exécutée, aucune CI des sœurs relue, aucune estimation chiffrée de gain ou de progression métier. Réutilisabilité identifiée ≠ portage réalisé. Tester sur candidat V2 exact : tests contrat/SQL/Edge, Playwright, Compose et SFU isolés, négatifs inter-tenant/masquage/révocation/idempotence/lecture effective, comparaison visuelle master. Seuls six services ajoutés et Chat enrichi, Meet intact ; pas d'assistant IA entreprise, Drive ou ERP. Les nouveaux moteurs sociaux/courrier/annuaire métier et état de présence/effacement/appel direct nécessitent adaptation ou construction spécifique. 
