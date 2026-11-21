# Verrouillage local NAXA SERVICES — code personnel v1

**Périmètre :** Android natif Kotlin / Jetpack Compose. **Statut :** implémentation candidate soumise aux contrôles CI du commit associé ; aucune qualification sur appareil physique n'est implicite.

## Comportement
- Le premier accès authentifié sur un appareil impose la création d'un code personnel de quatre chiffres avant l'affichage des écrans ERP.
- Le code est demandé après chaque arrêt de l'activité Android et au retour dans l'application.
- Le code est propre au membre authentifié ; un code ne déverrouille pas un autre compte.
- Le Profil permet de modifier le code après vérification du code actuel.
- « Code oublié » exige une nouvelle authentification Auth avec les identifiants du même membre. La réinitialisation est refusée si l'identifiant correspond à un autre membre.
- Cinq erreurs déclenchent un blocage de 30 secondes ; les blocages suivants s'allongent progressivement jusqu'à une heure. Le compteur est local et persistant.

## Stockage et sécurité
- Aucun code PIN en clair ni chiffrement réversible du PIN n'est stocké.
- Le vérificateur est un HMAC-SHA256 avec une clé non exportable Android Keystore et un sel aléatoire par membre.
- La comparaison du vérificateur utilise MessageDigest.isEqual.
- Une clé Keystore absente alors qu'un vérificateur existe produit une erreur de coffre : aucun contournement vers l'écran ouvert.
- La réinitialisation exige une nouvelle authentification réussie et une correspondance stricte du member_id.
- Le verrouillage local ne remplace ni l'authentification serveur, ni les contrôles RLS, ni la révocation distante de session.

## Contrôles
- Tests unitaires : format à quatre chiffres, seuils et délais de blocage.
- Tests Android instrumentés : persistance Keystore, vérification, changement, verrouillage après cinq échecs et réinitialisation après authentification.
- CI : exécution instrumentée sur émulateur API 35, en plus des tests unitaires et de la compilation debug.

## Limites
La recette sur appareils physiques et différents constructeurs Android reste nécessaire. En cas de perte des données Keystore, l'utilisateur doit se réauthentifier ; aucun contournement local n'est prévu. La variante livrée utilise l'alternative PIN prévue au cahier des charges, pas la biométrie.
