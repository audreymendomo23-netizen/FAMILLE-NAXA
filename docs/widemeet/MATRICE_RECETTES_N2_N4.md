# WideMeet — matrice de qualification N2–N4
Date : 27 novembre 2026. Révision de code contrôlée : 9314fa634cde7af4038ba6c574594daab4451c2b.
Référence : cahier des charges 12-widemeet.md. Branche work/widemeet-n0-20261126, PR #1 brouillon. Aucun N5, Cloudflare, main, fusion, migration persistante, dépense ou déploiement commercial.
 
## Règle de fermeture
Vert = scénario précisément décrit et résultat terminal SUCCESS avec preuve. Partiel = scénario vert mais exigences restantes. Candidat = code présent sans recette terminale sur sa révision. Non exécuté = aucune preuve ; ne jamais assimiler à un succès. Les anciennes preuves ne qualifient pas les nouveaux changements. Une recette à données synthétiques et services réels jetables ne constitue pas une recette commerciale ou sur appareil physique. Les flags nouveaux sont désactivés par défaut. 
 
## Matrice des 17 modules
| Bulk/module | Preuves exécutées | Écarts / recettes encore nécessaires | Statut |
|---|---|---|---|
| N2-06 agenda | création/agenda/reprogrammation et RSVP réel ; récurrence atomique/rollback/annulation 45957527361 | agenda structuré et duplication candidats 9314fa6 ; édition série complète, DST/fuseaux, modèles, disponibilité, rappel push et E2E UI | Partiel |
| N2-07 invitations | invitation tardive, verrou et refus tiers 45956684877 ; attente interne/refus/retry/admission 45957527361 | invités externes, lien/QR, expiration et révocation, appareil hors compte, anti-abus, E2E UI | Partiel |
| N2-08 média | SFU deux clients et flux réels, exclusion/revocation 45957795103 ; audio 45957920899 | TURN, réseau faible, reconnexion, qualité adaptative et limites débit, partage écran/audio natif sur matériel, sélection appareils | Partiel |
| N2-09 simultanéité | pass synthétique exactement une salle, refus élargissement, accès et agenda 45958371084 | exclusivité micro entre salles, Connect Android vers Web/TV en lecture seule avec bail court, révocation et isolement ; tests physiques et charge | Partiel |
| N2-10 messagerie | chat réel, message privé et refus troisième admis 45956684877 ; navigateur deux comptes 45958371084 | pièces jointes privées et contrôle fichier/taille, messages vocaux, historique/reconnexion/push et E2E natif | Partiel |
| N2-11 modération | rôle hôte, exclusion, contrôle admission et consentement 45956684877 / 45957795103 | délégation temporaire par permission candidate 7d1ab73 ; vérifier non-escalade, révocation et écrans ; journal complet | Partiel |
| N3-12 votes | vote Edge et isolement 45958371084 | vote temporisé, clôture, résultats/participation et cas limites, E2E UI natif | Partiel |
| N3-13 sondages | choix multiples anonymes différés, nominatif modifiable et secret avant clôture 45958371084 | texte/matrice/notation 1–10, échéances, exports, parcours complets Android/Web | Partiel |
| N3-14 audio | Egress réel, consentement/retrait, pause/RTP, reprise nouveau segment, arrêt, SHA-256, Storage privé, refus tiers et export hôte 45957920899 | téléchargement clients 94d4180 à qualifier ; annonce audible, durée et nom métier, purge effective/backup, crash multi-instance, accès après fin/expiration, charge et tests physiques | Partiel |
| N3-22 sécurité | SQL tenant/RLS 45957795136 ; SFU exclusion 45957795103 ; Storage privé 45957920899 ; refus non-destinataire/revocation 45958371084 | confidentialité standard/confidentiel candidate 9314fa6 ; strict non activé, FLAG_SECURE physique, journaux exhaustifs, rétention, protection écran Web non garantie ; aucun E2EE revendiqué | Partiel |
| N4-15 langues | FR/EN interfaces existantes et PDF français 45958370981 | couverture exhaustive FR/EN/Fulfulde et autres langues CDC, traduction réelle simultanée, précision/latence/terminologie et textes d'erreur | Partiel |
| N4-16 transcription/minutes | brouillon humain versionné et archive 45958371084 ; aucun ASR exécuté | transcription audio autorisé, diarisation, horodatage, génération IA sourcée, incertitude, correction humaine, confidentialité et coût | Partiel |
| N4-17 validation | approbation version exacte, publication sélective, lecture et révocation après expiration 45958371084 | notifications, parcours natif complet, concurrence/versions et cas clôture après expiration, audit long terme | Partiel |
| N4-18 tâches | affectation explicite, preuve texte, retour correction, validation, CAS et isolement destinataire 45956684877 / 45958371084 | preuve fichier sécurisée, échéances/rappels/escalade, continuité lors du remplacement de compte rendu, E2E UI | Partiel |
| N4-19 présences | observation serveur SFU réel, exclusion, rapport restreint 45957795103 / 45957920899 | scheduler robuste, interruption réseau et absence d'échantillons, exactitude du temps de connexion, seuils métier à valider, UI 94d4180 à qualifier ; aucun constat de présence humaine | Partiel |
| N4-20 archives | version publiée, lecture auditable et révocation, accès après expiration 45958371084 ; audio privé 45957920899 | recherche/filtres, rétention/purge/backup, audit de livraison, accès autorisés lors de clôture après expiration, téléchargement UI réel | Partiel |
| N4-21 rapports | PDF multipage FR réellement généré 45958370981 ; payload export version exacte, watermark et audit demande 45958371084 | PDF natif candidat, parcours téléchargement réel, Excel, rapport complet et consolidations/indicateurs, pagination Unicode/Fulfulde, charge et fidélité au CDC | Partiel |

## Exécution transversale
| Couche | Dernier résultat confirmé | Complément |
|---|---|---|
| Gate 315a278 | 45956684805 SUCCESS 5/5 ; 182/182 contrats ; 6/6 SQL | nouveaux changements postérieurs |
| Gate 68b35e5 | 45957795136 SUCCESS 5/5 ; 185/185 contrats ; Web/SQL/Edge/Android | ne qualifie pas export/modération/agenda postérieurs |
| Gate 16df30f | 45958370981 Web, SQL, Edge, contrats SUCCESS ; Android en cours au relevé | PDF Web multipage PASS job 140370117965 |
| Replay produit | 45958371084 SUCCESS, 26 PASS, job 140370162931 | autorisation PDF et parcours existants |
| SFU | 45957795103 SUCCESS, présence et exclusion réelles | TURN, Connect, débit et physique non exécutés |
| Egress + Storage | 45957920899 SUCCESS, 13 PASS, job 140368615308 | stockage jetable, pas de production |
| Dernière révision 9314fa6 | Gate 45958746382, Replay 45958746331, audio 45958746399, SFU 45958746369 lancés ; non terminaux au relevé | contrôler résultats, corriger échec éventuel sans ignorer de test |
| Android physique / Web-PWA multi-appareils / charge | non exécutés exhaustivement | environnement et appareils nécessaires ; ne pas déclarer vert |
| Préproduction/production | non autorisées | Cloudflare différé ; aucun appel paiement réel |

## Hypothèses et dépendances
- Séries : UTC, 2–12 occurrences, intervalle 1–12, entreprise uniquement ; hypothèses de recette, limites définitives à arbitrer.
- Mode confidentiel candidat : partage écran interdit ; mode strict indisponible tant que FLAG_SECURE physique non qualifié. Aucune protection absolue de capture OS sur Web.
- Présences : observations de connexion SFU, durée estimée uniquement entre observations successives (écart <=10 s), état inconnu sans preuve. Aucun seuil de présence commerciale validé.
- Audio : segments distincts après reprise, plafond de recette 128 MiB, bucket privé jetable, rétention visibilité 90 jours hypothétique sans purge effective ; audit demande de téléchargement et non preuve de livraison.
- N1 dépendance : paiement réel opérateur, CGU et biométrie physique restent à qualifier ; les fixtures ne débitent rien.
- Gate de sortie : tous les scénarios obligatoires CDC positifs, négatifs, concurrence, idempotence, isolation, régression et terminaux Android/Web/PWA/SQL/Edge/SFU/Egress doivent être verts sur une révision cohérente ; ne pas engager N5 avant autorisation.

 
## Addendum audit N1–N4 (27/11/2026)
La base 07d9951 est terminale verte sur les 4 workflows, 187/187 contrats. Les nouvelles preuves 45963432060 (Gate 5/5 et clôture/archives SQL) et 45963997472 (rejeu pass + notifications) complètent les lignes N2-06/09, N3-14, N4-17/20 et la dépendance N1-23. 45964420188 : 188/188 contrats, SQL/Web/Edge SUCCESS, Android non terminal au relevé. Les invitations externes nominatives, votes temporisés (contrats verts), conservation lors de fin hôte et rapport XLSX sont candidats en nouvelle qualification 49f3285. Les limites CDC et les conditions de fermeture restent applicables. Voir [audit N1–N4](AUDIT_CONTRADICTOIRE_N1_N4.md).
