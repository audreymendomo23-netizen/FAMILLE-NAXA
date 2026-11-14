# PROMPT 0.4 — Comptes créés et administrés — Famille NAXA

> Version Famille NAXA adaptée du prompt historique 0.4 « Comptes créés par l'administration ».
> Source historique : [NAXA — 00-socle-commun.md](https://github.com/audreymendomo23-netizen/NAXA/blob/main/7%20famille%20naxa/02-prompts/00-socle-commun.md), version 1.0 du 31 octobre 2026.
> Statut : prompt adapté, prêt pour audit de conception ; aucune implémentation ni migration autorisée par ce document seul.

## 1. Rôle et objectif

Tu es architecte et ingénieur senior Android natif Kotlin/Compose, Web/PWA, Supabase Auth, PostgreSQL, sécurité applicative et gestion des appareils. Le porteur du projet n'est pas développeur : explique les décisions brièvement, donne les preuves et livre des fichiers complets avec chemins exacts.

Construire le parcours sécurisé de création, activation, connexion, récupération et administration des comptes de la Famille NAXA, sans inscription libre et sans créer un système d'identité parallèle au backend NAXA existant.

## 2. Périmètre des applications

Le périmètre Famille NAXA comprend dix applications autonomes :
1. Kiosko
2. Bootik
3. Zipple
4. NAXA Services
5. CotiZ
6. Loyable
7. NAXA Hotel
8. Campus237
9. NAXA Security
10. GrillaD

Chaque application possède son identité produit, ses parcours, ses permissions et son application Android native Kotlin/Compose. Une expérience Web responsive/PWA autonome est prévue selon le périmètre de l'application. Les APK sont distribuées depuis le site NAXA, sans Play Store. Un backend Supabase NAXA unique est partagé ; cela n'autorise aucun accès transversal implicite entre applications.

## 3. État de départ et ressources canoniques

Avant toute proposition technique, relire :
- `AGENTS.md`
- `docs/ARCHITECTURE_CIBLE.md`
- `docs/CONTINUITE_FAMILLE_NAXA.md`
- `docs/audits/AUDIT_COMPATIBILITE_BACKEND_COMMUN.md`
- le schéma et les migrations Famille existants, en distinguant drafts et migrations réellement appliquées.

Le projet Supabase NAXA existant est le backend commun. Les ressources historiques déjà identifiées comprennent notamment `auth.users`, `public.profiles`, `public.partners`, `public.partner_members`, `public.partner_universes`, `public.pharmacies`, `public.promoteur_pharmacies` et `public.naxa_professional_assignments`. Cette liste est un point de départ d'audit, pas une autorisation de les modifier.

Règles impératives :
- `auth.users` demeure la source canonique d'identité Auth ; ne pas créer une seconde table de comptes ou un second fournisseur d'identité.
- Réutiliser les profils, partenaires, organisations, pharmacies, lieux et affectations existants lorsqu'ils correspondent réellement au besoin.
- Avant de créer une table, démontrer par comparaison du schéma qu'aucune ressource existante ne couvre le besoin.
- Ne pas présumer qu'un téléphone est globalement unique entre tous les types d'acteurs ou toutes les applications. Auditer les contraintes existantes et définir une normalisation E.164 compatible avec le Cameroun et les autres pays concernés.
- Ne pas accorder automatiquement à un compte des droits sur les dix applications. Les autorisations applicatives et métiers sont explicites, séparées et contrôlées côté serveur.
- Ne jamais exposer une clé `service_role` ou clé secrète dans Android, Web, PWA ou code public.

## 4. Mission

Auditer, concevoir, implémenter et tester — dans les limites d'autorisation données par le porteur — le cycle de vie des comptes et appareils. Procéder dans l'ordre :
1. Audit des tables, contraintes, triggers, RPC, politiques RLS, Auth settings et flux déjà existants.
2. Matrice de correspondance entre les besoins ci-dessous et les ressources canoniques existantes.
3. Contradictions, causes racines, décisions à confirmer et modèle cible.
4. Implémentation additive minimale uniquement après validation du modèle et du diff.
5. Tests locaux PostgreSQL 17, tests serveur/Auth et tests Android/Web pertinents.
6. Documentation, preuves, statut et passation.

Ne pas déclarer le prompt VERT si une partie critique n'est pas implémentée et testée.

## 5. Création administrative des comptes clients et professionnels

### 5.1 Création par une autorité autorisée
- Aucun parcours d'inscription libre ou d'auto-attribution de rôle.
- L'administration NAXA crée ou autorise la création d'un dossier client/professionnel selon les règles métier.
- Le dossier précise les applications autorisées, l'organisation/structure concernée, le plan ou palier, la durée, la date d'effet, l'échéance, les éventuelles remises ou périodes d'essai et l'état du dossier.
- Les applications et droits accordés sont explicites ; aucune permission n'est héritée simplement parce que l'utilisateur existe dans Auth.
- L'identifiant de connexion peut être un numéro de téléphone vérifié et normalisé, sous réserve de compatibilité avec le modèle Auth existant. Ne jamais créer de doublon si le numéro appartient déjà à un compte.
- Générer un lien d'activation/téléchargement sûr, à durée limitée et à usage contrôlé. Le lien ne doit contenir ni mot de passe, ni PIN, ni OTP en clair.
- Les comptes professionnels, partenaires, employés et clients doivent conserver leurs catégories et relations métier existantes ; ne pas réduire tous les acteurs à un type générique « client ».

### 5.2 Invitations et employés
- Un propriétaire/promoteur ou responsable ne peut créer/inviter un employé que dans le périmètre de ses organisations, applications, lieux et délégations autorisés.
- Chaque employé possède son propre compte Auth et son propre profil/affectation ; aucun compte partagé d'équipe.
- Les rôles et fonctions sont attribués explicitement, datés, révocables et limités au périmètre autorisé.
- Un utilisateur peut recevoir plusieurs fonctions métier si le modèle de l'application le permet, mais les permissions effectives doivent être calculées côté serveur et auditées.
- Le mécanisme de création Auth privilégié doit être exécuté exclusivement côté serveur (Edge Function ou backend sécurisé approprié), avec validation de l'appelant, idempotence, contrôle anti-énumération et journalisation.
- La fonction serveur peut être développée et testée localement ; elle ne doit pas être déployée sans autorisation explicite.

## 6. Première connexion et verrouillage local

- À la première activation, l'utilisateur définit un mot de passe personnel selon la politique de sécurité NAXA validée et les exigences Supabase Auth en vigueur. Ne pas figer arbitrairement le minimum historique de six caractères si la politique actuelle exige davantage.
- Après authentification serveur, l'application peut proposer un verrouillage local par biométrie Android ou secret local.
- Si un code local à quatre chiffres est retenu, il est propre à l'appareil, stocké sous forme protégée via Android Keystore et mécanisme de dérivation adapté ; jamais en clair, jamais envoyé au serveur et jamais utilisé comme mot de passe Auth.
- Prévoir limitation progressive des essais, temporisation, effacement/réinitialisation contrôlée et repli sûr lorsque la biométrie n'est pas disponible.
- Le verrouillage local ne remplace jamais l'expiration, la révocation ou la validation du jeton serveur.
- Sur Web/PWA, ne pas prétendre disposer des garanties Android Keystore ; utiliser les mécanismes Web appropriés et ne pas synchroniser un PIN local entre appareils.

## 7. Récupération du compte

- Utiliser en priorité les mécanismes officiels Supabase Auth de récupération par e-mail lorsque l'adresse est vérifiée et disponible.
- Si aucun e-mail utilisable n'existe, proposer une demande d'assistance via le canal WhatsApp officiel NAXA, avec traitement humain après vérification d'identité selon une procédure documentée.
- Ne jamais demander à l'utilisateur d'envoyer son mot de passe, son code local, son PIN, un OTP ou le contenu sensible d'un SMS.
- Ne jamais envoyer de PIN/OTP dans WhatsApp ni utiliser un code secret transmis par l'utilisateur comme preuve suffisante d'identité.
- La procédure manuelle doit prévenir l'énumération de comptes, tracer l'agent, le motif, les preuves minimales et la décision, et informer le titulaire par un canal déjà vérifié lorsque possible.

## 8. Gestion et révocation des appareils

- Auditer d'abord les tables et fonctions d'appareils existantes. Ne pas créer une deuxième registry.
- Un appareil est enregistré avec un identifiant d'installation aléatoire, l'application, le compte, le contexte organisation/lieu pertinent, la date d'enregistrement, la dernière activité, l'état et les informations techniques minimales nécessaires.
- Définir le plafond d'appareils après analyse par application et par catégorie d'acteur. Le plafond historique de deux appareils actifs « par point » est une exigence à confronter aux règles réelles de chaque application ; ne pas l'appliquer aveuglément à tous les clients, employés, managers ou appareils.
- Si un plafond de deux appareils est confirmé pour un périmètre donné : la règle de sélection, l'ordre chronologique, la révocation atomique du plus ancien, les sessions existantes et les cas d'égalité doivent être explicitement spécifiés et testés.
- Notifier le propriétaire ou responsable autorisé lors d'un nouvel appareil, sans révéler de secret.
- Permettre la révocation distante et faire respecter cette révocation côté serveur sur les opérations sensibles ; ne pas se contenter de masquer l'appareil dans l'interface.
- Après cinq tentatives échouées, appliquer une limitation temporaire mesurée et résistante aux contournements. Distinguer échecs Auth, échecs du verrouillage local et échecs d'activation ; ne pas créer de mécanisme qui facilite le déni de service contre un compte.
- Ne pas utiliser de SMS payant comme mécanisme obligatoire.

## 9. Sécurité et conformité

- Autorisation serveur/RLS sur chaque lecture et écriture ; contrôle inter-applications, inter-organisations et inter-lieux.
- Aucune confiance dans les métadonnées modifiables par l'utilisateur pour décider des rôles ou permissions.
- Les fonctions privilégiées ont un `search_path` explicite, des vérifications d'identité et de périmètre, des droits EXECUTE en liste blanche et des tests négatifs.
- Les journaux enregistrent qui, quoi, quand, application, organisation/lieu, résultat et motif, sans secrets ni données excessives.
- Les opérations sensibles sont idempotentes et résistantes aux appels concurrents.
- Les messages d'erreur ne révèlent pas si un numéro ou un e-mail est enregistré.
- Respecter la minimisation des données, la durée de conservation et le consentement applicable.

## 10. Tests obligatoires

Créer des tests locaux reproductibles, sans toucher à Supabase Production :
1. Création administrative autorisée et refusée.
2. Refus d'inscription libre.
3. Création idempotente et prévention des doublons de téléphone/identité selon les règles validées.
4. Attribution d'une seule application, puis de plusieurs applications explicitement autorisées.
5. Première activation et changement obligatoire du mot de passe.
6. Verrouillage local, biométrie disponible/indisponible, limitation des essais et perte/réinitialisation de l'appareil.
7. Invitation employé autorisée et refusée hors périmètre.
8. Révocation d'un rôle et d'une affectation ; accès immédiatement refusé côté serveur selon le modèle de session.
9. Enregistrement d'appareil, plafond éventuel, deux enregistrements concurrents, révocation distante et notification.
10. Récupération par e-mail, assistance humaine et réponses anti-énumération.
11. Tests négatifs inter-applications, inter-organisations et inter-lieux.
12. Vérification qu'aucun secret privilégié n'est présent dans les bundles Android/Web/PWA.
13. Tests de régression sur les flux Auth et affectations NAXA existants.

Chaque test indique précondition, action, résultat attendu et preuve réelle. Un test non exécuté est marqué NON EXÉCUTÉ.

## 11. Livrables attendus

- Rapport d'audit du cycle de vie des comptes et appareils.
- Matrice « réutiliser / adapter / créer / écarter » des ressources existantes.
- Diagramme des parcours : création administrative, activation, connexion, récupération, invitation employé, gestion d'appareil et révocation.
- Modèle de données cible et dictionnaire, uniquement pour les éléments réellement manquants.
- Migrations additives ordonnées, non appliquées, si et seulement si elles sont justifiées.
- Fonction serveur de création/invitation, code source et tests, non déployée.
- Écrans et textes FR/EN Android natif et Web/PWA selon périmètre.
- Tests et preuves reproductibles.
- Rapport de passation et mise à jour de `docs/CONTINUITE_FAMILLE_NAXA.md`.

## 12. Gouvernance et interdictions

- Travailler sur `main` uniquement ; aucune branche ni PR.
- GitHub Actions sont autorisées lorsqu'elles sont utiles au contrôle qualité ; ne pas les désactiver au motif de la consigne historique.
- Aucun déploiement, migration Supabase Production, publication APK ou modification de configuration Production sans autorisation explicite distincte.
- Toute migration réelle doit être précédée du diff exact, du projet cible, de l'analyse de risque, du plan de rollback et d'une demande d'autorisation.
- Les tests de base de données doivent utiliser PostgreSQL 17 éphémère ou un environnement local isolé.
- Ne jamais exposer de secret, token, mot de passe, OTP, donnée personnelle réelle ou clé privilégiée.
- Ne pas modifier les applications existantes hors périmètre sans preuve de nécessité et analyse de non-régression.
- Préserver les données et ressources existantes ; préférer les changements additifs et réversibles.
- Ne jamais déclarer VERT sur la base d'un build seul.

## 13. Critères de clôture

Le Prompt 0.4 ne peut être déclaré VERT que lorsque :
- le mapping avec les identités, organisations, memberships, affectations et appareils NAXA est validé ;
- aucune identité ou relation canonique n'est dupliquée ;
- les parcours d'administration, d'activation, de récupération, d'invitation et de révocation sont implémentés ;
- les politiques serveur et tests négatifs prouvent l'isolation entre apps, organisations et lieux ;
- les tests Android/Web pertinents et PostgreSQL 17 sont exécutés et réussis ;
- les fonctions privilégiées ne sont pas déployées sans autorisation ;
- la continuité contient les preuves et les limites restantes.

**État initial de ce prompt adapté : PRÉPARATION DOCUMENTAIRE. Aucun code ni migration exécuté.**
