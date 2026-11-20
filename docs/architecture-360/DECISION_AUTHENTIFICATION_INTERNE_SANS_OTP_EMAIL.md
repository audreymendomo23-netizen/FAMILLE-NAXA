# Décision d'architecture proposée — Authentification interne sans OTP ni boîte mail

**Date :** 20 novembre 2026  
**Périmètre immédiat :** NAXA SERVICES (J0), puis modèle réutilisable par les autres applications uniquement après validation.  
**Statut :** proposition technique documentée ; mécanisme d'alias et configuration Supabase à prouver en environnement local avant verrouillage.  
**Aucune configuration Supabase réelle ni aucun code applicatif n'a été modifié.**

## 1. Réponse

Oui. Il est possible de gérer en interne tout le parcours visible par l'utilisateur : création des comptes, identifiant de connexion, mot de passe, première activation, ouverture de session, appareils, révocation et récupération, **sans envoyer d'OTP SMS/WhatsApp et sans boîte mail**.

Il faut distinguer deux choses :
- **Pas de dépendance à l'e-mail ou au SMS :** réalisable avec Supabase Auth comme moteur de sessions et de jetons, à condition de choisir un identifiant de connexion adapté.
- **Aucune dépendance à un service d'authentification externe :** c'est un autre projet. Il faudrait héberger et exploiter un fournisseur d'identité OIDC ou un serveur Auth complet, avec ses propres exigences de disponibilité, sécurité, mises à jour, sauvegardes et rotation de clés. Ce n'est pas recommandé pour le premier lot NAXA Services.

L'objectif recommandé est donc : parcours interne côté Famille NAXA, sans SMTP, fournisseur SMS, OTP, magic link ni inscription libre, mais avec Supabase Auth pour vérifier les mots de passe et gérer les sessions/JWT.

## 2. Ce que Supabase permet réellement

La documentation officielle confirme :
- `signInWithPassword` accepte un mot de passe associé à une adresse e-mail **ou à un numéro de téléphone** ([référence](https://supabase.com/docs/reference/javascript/auth-signinwithpassword)).
- L'API Admin `createUser` permet de créer un utilisateur côté serveur et de marquer son e-mail comme confirmé via `email_confirm: true` ([référence](https://supabase.com/docs/reference/javascript/auth-admin-createuser)). L'API de création directe n'est pas le flux d'invitation et ne nécessite pas l'envoi d'un message.
- Le login téléphone + mot de passe est possible sans appeler le flux OTP ; cependant Supabase avertit que les numéros de téléphone peuvent être recyclés et recommande de ne pas les traiter comme une preuve d'identité durable ([guide mots de passe](https://supabase.com/docs/guides/auth/passwords)).
- Supabase accepte aussi des jetons d'un fournisseur OIDC tiers, à condition que celui-ci expose une découverte OIDC et signe les JWT par clé asymétrique ([guide Third-party Auth](https://supabase.com/docs/guides/auth/third-party/overview)).

**Conséquence :** Supabase ne propose pas directement `username + password` comme identifiant natif ; il attend une identité e-mail ou téléphone pour le flux mot de passe. Il faut donc prévoir soit le téléphone comme identifiant natif, soit un identifiant Famille résolu vers un identifiant Auth interne, soit un fournisseur OIDC propre.

## 3. Architecture recommandée pour respecter l'identité séparée par application

Le document de cadrage retient des identités séparées et pas de SSO transversal par défaut. Un numéro de téléphone utilisé directement comme identité Auth peut créer une collision si la même personne doit disposer de comptes distincts sur plusieurs applications dans le même projet Supabase.

### Option A — Identifiant NAXA par application + alias Auth interne (recommandée, sous réserve de preuve)

Chaque compte reçoit un identifiant d'accès propre à son application, par exemple un identifiant généré « NS-… » pour NAXA Services. Le numéro de téléphone reste une coordonnée de contact et n'est pas la clé Auth primaire.

1. L'administration crée le dossier NAXA Services et associe l'utilisateur à un établissement, un rôle et des droits précis.
2. Le backend génère un identifiant de connexion aléatoire et un alias Auth technique, opaque et non destiné à recevoir du courrier. L'alias est propre à l'application et au compte.
3. Un backend/Edge Function sécurisé crée l'utilisateur Supabase Auth avec cet alias et confirme l'identité technique par l'API Admin. Aucun mail d'activation n'est envoyé ; le secret Admin ne quitte jamais le serveur.
4. L'utilisateur reçoit son identifiant et un mot de passe initial temporaire par un parcours interne maîtrisé (remise en main propre ou fiche d'activation remise par le responsable). Il définit son mot de passe personnel à la première connexion.
5. Sur l'écran NAXA Services, il saisit son identifiant d'accès et son mot de passe. Le service interne résout l'alias technique et utilise le flux mot de passe de Supabase Auth.
6. Supabase Auth délivre la session et les JWT. Les contrôles serveur/RLS vérifient ensuite le compte, l'application active, l'organisation, l'établissement, le rôle, le plan et l'appareil.
7. L'alias e-mail reste invisible dans l'interface, ne sert jamais de boîte de réception, ne reçoit aucune communication et ne peut pas être modifié par l'utilisateur.

**Point à prouver avant adoption :** un test local doit confirmer que la version GoTrue/Supabase utilisée accepte l'alias interne retenu (syntaxe et domaine réservés), que l'API Admin peut créer et confirmer le compte sans message, et que `signInWithPassword` fonctionne avec cet alias. Ne pas choisir un domaine appartenant à un tiers et ne pas inventer une adresse réelle. Le format final d'alias reste ouvert jusqu'à ce test.

Avantages : identifiant distinct par application, même numéro de téléphone possible comme coordonnée de contact dans plusieurs applications, pas de SMS/OTP/e-mail, et conservation de Supabase Auth pour les mots de passe, sessions et JWT.

Limites : le mécanisme de résolution identifiant → alias est un composant interne supplémentaire, à protéger contre l'énumération et les attaques par force brute. Les changements Auth et la récupération doivent rester exclusivement serveur.

### Option B — Téléphone + mot de passe natif Supabase (simple, mais moins adaptée à l'identité séparée)

Supabase permet officiellement la connexion avec téléphone + mot de passe. On peut créer un compte côté serveur et marquer le téléphone comme confirmé sans envoyer d'OTP, mais cela revient à déclarer que l'administration a contrôlé la coordonnée.

Cette option n'est acceptable que si l'on accepte :
- un téléphone unique dans le périmètre Auth du projet ;
- l'absence de preuve automatique que le titulaire contrôle encore ce numéro ;
- une procédure manuelle pour changement de numéro et récupération ;
- la gestion du risque de recyclage du numéro.

Elle n'est pas le choix préféré si une même personne doit conserver des comptes Auth réellement séparés dans plusieurs applications.

### Option C — Fournisseur OIDC interne/autohébergé (non retenue pour J0)

Un fournisseur OIDC contrôlé par NAXA pourrait gérer directement des identifiants et mots de passe internes puis émettre des JWT asymétriques acceptés par Supabase. C'est une architecture prise en charge par Supabase, mais elle ajoute un service critique à héberger, superviser, sauvegarder, mettre à jour et sécuriser. Elle ne supprime pas la dépendance à une infrastructure ; elle la déplace vers notre propre fournisseur d'identité.

À évaluer uniquement si l'option A échoue aux tests ou si une exigence contractuelle impose que l'authentification ne passe pas par Supabase Auth.

## 4. Parcours cible proposé pour NAXA SERVICES

### 4.1 Création du compte
- Pas de bouton « créer un compte » public.
- L'administrateur central ou un responsable autorisé crée l'utilisateur dans son périmètre.
- Un dossier d'accès comporte : identifiant NAXA Services, compte Auth interne, organisation/établissement, type d'utilisateur, rôles, droits, état, durée/abonnement, appareils et historique.
- Le rôle n'est jamais déduit du seul fait que le compte Auth existe.
- Aucun compte employé partagé : chaque personne possède son compte individuel.

### 4.2 Première connexion
- Identifiant d'accès + mot de passe temporaire remis par le canal interne convenu.
- Changement obligatoire du mot de passe à la première connexion.
- Écran de consentement/conditions d'utilisation selon le parcours.
- Enrôlement de l'appareil et établissement des droits autorisés.
- Pas d'OTP, pas de lien magique, pas de confirmation par e-mail et pas de SMS.

### 4.3 Connexions suivantes
- Identifiant d'accès + mot de passe.
- Session Supabase Auth/JWT ; vérification de l'utilisateur côté serveur.
- Limitation progressive des tentatives et anti-automatisation.
- Sessions et appareils suivis ; révocation serveur des sessions/appareils.
- Verrouillage local facultatif : biométrie Android ou code local propre à l'appareil. Ce code local n'est jamais le mot de passe Auth et n'est jamais envoyé au serveur.
- Aucun SSO ou accès implicite aux autres applications.

### 4.4 Mot de passe oublié / compte bloqué
Sans canal e-mail/SMS et sans OTP, **la récupération autonome à distance n'est pas possible par défaut**. C'est un arbitrage sécurité/support, pas une difficulté de programmation.

Parcours recommandé :
1. L'utilisateur ouvre une demande de récupération via le responsable de son établissement ou le support officiel.
2. L'agent autorisé vérifie l'identité au moyen d'une procédure hors bande définie par NAXA (présence physique, responsable déjà identifié, éléments opérationnels non secrets).
3. Une action serveur réinitialise le mot de passe, révoque les sessions à risque et force le changement au prochain accès.
4. L'action conserve un audit : demandeur, agent, date, périmètre, motif, vérification effectuée et résultat.
5. Les comptes d'administration centrale exigent une procédure d'urgence distincte, avec une clé de récupération conservée hors ligne dans un lieu sûr. La perte du téléphone ou du navigateur ne doit pas suffire à prendre le contrôle d'un compte.

Ne jamais demander ou enregistrer l'ancien mot de passe, le code local ou le PIN. Aucun mot de passe temporaire ne doit être envoyé dans un canal non contrôlé.

## 5. Contrôles de sécurité obligatoires

- Désactiver l'inscription publique et toute auto-attribution de rôle ; création par backend Admin uniquement.
- Ne jamais exposer `service_role`/clé secrète Supabase dans Android, Web, navigateur ou variables `NEXT_PUBLIC_*`.
- Le mot de passe est vérifié par Supabase Auth ; ne jamais créer de table de mots de passe ni écrire son propre hachage de mot de passe pour cette option.
- Mot de passe robuste (phrase de passe) et politique alignée sur les réglages Auth vérifiés ; ne pas conserver l'ancien seuil de six caractères comme décision suffisante.
- Ne pas révéler si un identifiant existe ; réponse générique en cas d'échec.
- Limitation par IP, identifiant, appareil et fenêtre temporelle ; journalisation des échecs sans secret ; éviter les blocages définitifs exploitables pour déni de service.
- Sessions : durée, refresh, révocation, déconnexion distante et contrôle des appareils, testés réellement. L'audit Famille 0.4 a identifié des stubs dans le mécanisme historique de limitation de sessions : ne pas prétendre que la limite de deux appareils est déjà opérationnelle.
- RLS et fonctions vérifient identité, app scope, organisation, établissement et rôle. Les claims d'autorisation sont établis côté serveur et signés ; ne jamais utiliser des métadonnées modifiables par l'utilisateur pour autoriser une action.
- Journal append-only des créations, activations, changements de mot de passe, resets, changements de rôle, enrôlements et révocations.
- Hors connexion : l'accès aux seules données locales est borné par une durée de tolérance définie ; la révocation serveur s'applique dès reconnexion. L'accès offline ne doit jamais étendre silencieusement l'autorisation serveur.

## 6. Protection forte sans OTP

Une biométrie ou un PIN local protège l'ouverture de l'application sur un appareil déjà enrôlé ; ce n'est pas une preuve d'identité distante et cela ne remplace pas le mot de passe Auth.

Les passkeys/WebAuthn peuvent être étudiées comme deuxième étape sans SMS ni e-mail : le système utilise une clé cryptographique et le déverrouillage biométrique/PIN du dispositif. Toutefois, la documentation Supabase consultée classe actuellement cette API comme expérimentale ; elle exige une identité confirmée et une configuration WebAuthn des domaines/origines. **Ne pas en faire une dépendance du MVP** avant tests Android et Web réels ([documentation officielle](https://supabase.com/docs/guides/auth/passkeys)).

Pour le compte Admin central, privilégier une phrase de passe unique et envisager une clé de sécurité/passkey après validation, avec procédure d'urgence hors ligne.

## 7. Contradictions à résoudre dans les documents existants

Le cahier NAXA Services mentionne actuellement :
- connexion par numéro de téléphone + mot de passe ;
- code local à quatre chiffres ou empreinte ;
- récupération par e-mail, sinon procédure WhatsApp manuelle ;
- limite d'appareils et blocage après tentatives échouées.

Le Prompt Famille 0.4 propose également le téléphone vérifié, la récupération e-mail puis WhatsApp, et un modèle générique d'appareils.

Ces éléments doivent être harmonisés après le test technique :
- identifiant d'application généré plutôt que téléphone comme clé Auth si l'identité doit être séparée par application ;
- téléphone conservé comme coordonnée de contact ;
- suppression de la dépendance à l'e-mail/OTP pour activation et récupération ;
- récupération par administration contrôlée ;
- politique d'appareils et sessions définie pour NAXA Services, sans supposer que les anciens stubs l'appliquent déjà.

## 8. Tests requis avant verrouillage de J0

1. Créer deux identités de test distinctes pour NAXA Services et une autre application, avec une même coordonnée téléphonique de contact.
2. Créer les comptes via l'API Admin en utilisant des alias internes confirmés ; vérifier qu'aucun e-mail ou SMS n'est envoyé.
3. Tester l'acceptation de l'alias par Auth local et le login identifiant + mot de passe.
4. Vérifier qu'un identifiant d'une autre application ne donne aucune session/permission NAXA Services.
5. Tester mot de passe erroné, tentative répétée, réponses anti-énumération, compte suspendu, mot de passe initial expiré et changement obligatoire.
6. Tester révocation session/appareil, perte d'appareil, reset manuel, audit complet et déconnexion à distance.
7. Tester accès offline autorisé puis expiration de la tolérance ; rétablir le réseau et vérifier la révocation.
8. Vérifier que ni alias, mot de passe, jeton, PIN ni secret ne figurent dans les logs ou le dépôt.

Les tests sont locaux/éphémères. Aucune modification de configuration Auth d'un projet Supabase réel, aucune migration Replay/Production et aucun déploiement ne sont inclus sans autorisation.

## 9. Décision recommandée

**Recommandation : Option A — identifiant interne propre à chaque application + mot de passe personnel, résolu vers un alias Auth technique, avec création et récupération exclusivement administratives.**

Cette option répond à l'objectif sans OTP, sans boîte mail, sans SMS et sans SSO transversal, tout en conservant Supabase Auth pour la sécurité des mots de passe et des sessions. Elle reste conditionnée par les tests locaux de compatibilité de l'alias et par une validation du modèle exact d'identité séparée.

Le choix entre identifiant NAXA généré et numéro de téléphone comme identifiant visible doit être validé avant de modifier le cahier NAXA Services ou le Prompt 0.4.
