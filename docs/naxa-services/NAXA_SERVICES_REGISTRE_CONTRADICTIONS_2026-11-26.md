# NAXA SERVICES — Registre contradictoire consolidé (26 novembre 2026)

Référence audit : 7c64a882207f6b703d0db03d7a2e3f2e961e960b, cahier des charges 04-naxa-services.md, architecture multi-entités, continuité §22.46–22.77, code et journaux Actions. Statut par preuve, non par promesse. Cet inventaire couvre les écarts recensés dans ces sources et les fichiers ciblés ; il ne prouve pas l'absence de toute anomalie inconnue.

| ID | Exigence / contradiction | État et preuve | Suite |
|---|---|---|---|
| C01 | Auth CORS bloquait le navigateur ; accounting wildcard et promotions 204 avec corps | Correctifs §22.24–22.37 ; Replay #44 vrai Auth local et parcours métier ; pas de preuve de tous les comptes hébergés | Qualification hébergée autorisée |
| C02 | Isolation tenant, site et rôle, jetons révoqués | Gate #787 RLS et Replay #44 ; scénarios négatifs réels isolés | Étendre postes et appareils réels |
| C03 | Restaurer sans ACL modifiait les droits | Corrigé §22.33, drill #7 vert | Sauvegarde hébergée et Storage à qualifier |
| C04 | FR/EN/FF annoncé mais CGU/PC seulement FR/EN ; accept_legal_document refuse FF | Ouvert, actifs FR/EN et Auth vérifiés | Traductions intégrales relues juridiquement, version et consentement FF cohérents ; aucune preuve FF fictive |
| C05 | 43 divergences de validation des dossiers, puis navigation pictogramme et titre/revision instables | v20 365/365, Replay #44 et gate #787 ; base permanente non activée | Activation contrôlée puis recette cible |
| C06 | Transition non acquittée affichée confirmée | Corrigé 22.67, régression navigateur et gate #787 | Ne pas rouvrir sans échec |
| C07 | GPS désactivable, absence de règle et chemin ancien sans preuve B/C | v21, test rollback et Replay #40/#44, UI fail-closed | Qualification physique + activation cible |
| C08 | Poste sélectionné absent de l'enveloppe sync, preuve réutilisable après changement | Corrigé, Replay #44 réel Storage/DB avec capteurs simulés | Capteurs physiques, droits poste et reprise |
| C09 | Pointage/roster uniquement site alors que cahier prévoit héritage site/poste/rôle, congés/rotations/remplacements | Partiel ; planning et écart de service éprouvés, fonctions supplémentaires ouvertes | B1, pas de sanction automatique |
| C10 | Réunion créée deux fois après perte de réponse | Retry Web et récurrence qualifiés Replay #44 | Persistance Android et transport réel |
| C11 | Réunion type Meet et enregistrement promis, contrôle plane seulement | Invites, chat, réactions, consentement éprouvés ; média/recording et traduction streaming non réalisés | B2/B3 appels réels, contrôle effectif et consentement |
| C12 | Bilan toutes périodes/rôles vs daily briefing partiel | Code SQL v11 et clients ne couvrent que données confirmées partielles d'une journée ; rapport explicite | B3 périodes, indicateurs, consolidations, archives, audio/Q&A |
| C13 | Bilan Web arrêté en arrière-plan, Android pas de contrôle explicite avant verrouillage onStop | Correctif Android lifecycle + annulation requête et effacement dans cette passe | CI et recette appareil |
| C14 | Rapport Web acceptait des nombres absents/malformés malgré règle de données confirmées | Validateur runtime strict et tests cette passe | Gate et Replay ; parité native à poursuivre |
| C15 | Écritures futures faussaient le résultat Android | Correctif §22.71, gate #784–787 | Parité tous rapports serveur |
| C16 | Push route // et redirections fournisseur | Correctif #787, 5/5 tests | Activer uniquement après qualification |
| C17 | HTTP 200 FCM sans référence enregistré comme accepté | Correctif SHA 7c64a882 ; gate #788/Replay #45 en cours au relevé | Ne pas confondre accepté fournisseur/reçu physique |
| C18 | Code fournisseur UNAVAILABLE/QUOTA_EXCEEDED/INTERNAL lu comme erreur définitive | Correctif de normalisation et tests dans cette passe | Qualification CI et FCM réel |
| C19 | Android acceptait JWT anon expiré alors que Web preflight le refuse | Correctif exp et tests dans cette passe | Gate ; clé publishable opaque requiert validation réelle de l'environnement |
| C20 | Contrôle signature calculait attendu depuis même keystore | Corrigé #787 ; readiness #4 refuse empreinte absente | Certificat approuvé indépendant en attente du propriétaire, aucune signature publique |
| C21 | Flags preuves/roster/réunions/bilan désactivés par défaut en release bien que requis | Candidats SQL non activés en cible, blocage volontaire ; ne pas activer uniquement le client | Qualifier et activer ensemble backend/clients dans environnement autorisé |
| C22 | Encaissement métier déclaré hors API vs abonnement réellement payé | Intention et annulation testées ; aucun argent déplacé | Paiement d'abonnement/rapprochement réels autorisés ; aucun PIN/OTP |
| C23 | Push, matériel NAXA SECURITY, support/partage d'écran, Bluetooth et restauration cible | Contrats et simulations ne prouvent pas matériel/exploitation ; pas d'intégration physique attestée | B5, environnement et appareils autorisés |
| C24 | FR/EN/FF navigation != traduction de chaque texte, PDF et documents légaux | Parité ressources et navigation éprouvées ; couverture complète et relecture FF ouvertes | B6, inventaire des chaînes et tests de contenu |

## Règle de fermeture
Gate #787 13/13 et Replay #44 verts ; #788 11/13 et #45 en cours au relevé. Les quatre corrections de cette passe sont candidates jusqu'aux résultats du SHA. Une fonctionnalité non livrée n'est pas une régression ni une simple recette jaune. Signature mise à part sur demande du propriétaire. Aucun main, activation SQL durable, paiement ni déploiement manuel. Réserves §22.68 maintenues.
