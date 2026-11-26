# ZIPPLE — Cahier des charges fonctionnel 360° V2.0

**Date de référence :** 21 novembre 2026  
**Dernière révision intégrée :** 21 novembre 2026 — abonnement annuel et parrainage client  
**Statut :** périmètre fonctionnel consolidé et gelé par validation du promoteur  
**Produit :** ERP de gestion des restaurants, restaurants-bars et snack-bars  
**Dépôt de référence :** audreymendomo23-netizen/FAMILLE-NAXA  
**Fichier :** docs/cahiers-des-charges/ZIPPLE_V2_0.md

---

## 0. Objet, portée et règles de lecture

Ce document constitue la référence fonctionnelle ZIPPLE V2.0. Il conserve la vision métier initiale et les orientations QR, commande, disponibilité en temps réel, délai de service et feedback client validées, puis y ajoute les modules demandés : Bar, livraison Restaurant, multi-établissements, stocks et approvisionnements, dépenses, comptabilité, performances par poste, vidéosurveillance NAXA Security, IA, support et livechat.

Le périmètre fonctionnel est gelé à cette version. Les évolutions ultérieures devront faire l’objet d’une demande explicite et d’une nouvelle décision. Une précision technique nécessaire à l’implémentation ne doit pas être interprétée comme l’autorisation de supprimer ou de remplacer une fonctionnalité validée.

### 0.1. Statuts

- **[V] Validé :** exigence explicitement retenue par le promoteur.
- **[P] Proposition de spécification :** règle de détail nécessaire pour rendre un parcours testable ; elle ne remplace aucune décision commerciale ou juridique.
- **[O] Ouvert :** donnée ou arbitrage manquant à confirmer avant le sous-chantier concerné.
- **[C] Constat documentaire :** information tirée d’une source antérieure, sans présumer qu’elle est encore applicable.
- **[B] Bloquant :** dépendance qui empêche de certifier le sous-parcours tant qu’elle n’est pas vérifiée.

### 0.2. Principes non négociables

1. ZIPPLE est un ERP professionnel pour l’exploitation et le pilotage d’établissements de restauration. [V]
2. ZIPPLE comporte exactement deux espaces métier : **Restaurant** et **Snack-Bar**. [V]
3. Le mode **Restaurant-Bar** est une configuration de l’Espace Restaurant. Le Bar n’est pas une troisième application ni un troisième espace indépendant. [V]
4. La clientèle ne crée aucun compte ZIPPLE. Le client commande depuis une page publique mobile, sans compte, sans installation et sans application cliente. [V]
5. L’Espace Restaurant peut activer la livraison établissement par établissement. L’Espace Snack-Bar ne comporte pas de livraison. [V]
6. Les deux offres commerciales sont exclusivement **Accès** et **Premium**. Aucun troisième pack ne doit être réintroduit. [V]
7. Les opérations financières, stocks, paiements, annulations et écritures restent explicables, traçables et protégés par des validations humaines.
8. L’IA assiste et recommande ; elle ne valide jamais seule un paiement, un remboursement, une annulation sensible, un ajustement financier ou une écriture de stock.
9. La disponibilité publiée au client doit provenir de l’état opérationnel courant et être recontrôlée au moment de la soumission.
10. Ce cahier décrit le fonctionnement attendu. Il ne constitue pas une preuve que les fonctions sont déjà codées, testées, déployées ou opérationnelles.

### 0.3. Sources de référence

- Cahier ZIPPLE V1.0 du 31 octobre 2026 et dossier de prompts associé, conservés dans le dépôt historique NAXA :
  - https://github.com/audreymendomo23-netizen/NAXA/blob/main/7%20famille%20naxa/01-cahiers-des-charges/03-zipple.md
  - https://github.com/audreymendomo23-netizen/NAXA/blob/main/7%20famille%20naxa/02-prompts/03-zipple.md
- Cahier NAXA, notamment le mécanisme de livraison configurable F54 et les parcours de paiement décrits dans la documentation historique :
  - https://github.com/audreymendomo23-netizen/NAXA/blob/main/docs/CAHIER_DES_CHARGES.md
- Cahier NAXA Services V1.0, section V5 : fiche et historique client, points de fidélité, carte QR, offres et parrainage client (référence fonctionnelle du module de relation client) :
  - https://github.com/audreymendomo23-netizen/NAXA/blob/main/7%20famille%20naxa/01-cahiers-des-charges/04-naxa-services.md
- Architecture et règles de gouvernance du monorepo Famille NAXA :
  - https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/AGENTS.md
  - https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/docs/ARCHITECTURE_CIBLE.md
  - https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/docs/CONTINUITE.md

Les documents historiques constituent une base de comparaison. Toute règle explicitement remplacée par la présente V2.0 est supersédée pour ZIPPLE.

---

# 1. Vision produit et architecture générale

ZIPPLE doit permettre au propriétaire ou promoteur de connaître et de maîtriser toute l’activité de ses établissements : ventes, commandes, préparation, stocks, achats, dépenses, caisse, paiements, résultats, équipe, qualité du service et performance de chaque site.

ZIPPLE n’est pas une simple caisse. C’est un ERP de restauration qui relie les opérations physiques à la gestion financière et au pilotage.

## 1.1. Deux espaces métier

### Espace 1 — Restaurant

Couvre les restaurants traditionnels, modernes, familiaux, gastronomiques, maquis, grillades, braiseurs et établissements similaires.

Fonctionnement principal :
- zones, salles, tables et terrasses ;
- réservations, accueil et liste d’attente ;
- commandes à table et commandes à emporter ;
- page publique de commande liée au QR Code de chaque table ;
- carte, plats, boissons, variantes, suppléments et menus ;
- cuisine, postes de préparation, service et additions ;
- caisse, paiement, facturation et clôture ;
- stocks, recettes, production, achats et dépenses ;
- livraison activable pour l’établissement qui la propose ;
- analyse des délais, retours clients et performances.

### Module Bar — option de l’Espace Restaurant

Le mode Restaurant-Bar active une exploitation du bar rattachée au même établissement et au même moteur ZIPPLE.

Le module Bar comprend :
- comptoir et zones de service ;
- tables éventuellement servies par le bar ;
- catalogue de boissons alcoolisées et non alcoolisées ;
- bouteilles, canettes, verres, doses, cocktails et boissons composées ;
- recettes de cocktails et consommations associées ;
- stocks en unité, pack, carton, casier, fût, bouteille et portion ;
- consignes, bouteilles vides, casiers rendus, casse et pertes ;
- commandes transmises à un poste Bar distinct ;
- préparation, mise à disposition et remise au client ;
- caisse et chiffre d’affaires Bar distincts analytiquement ;
- compte de table et facture consolidés avec les plats du Restaurant ;
- délais de préparation et de service ;
- disponibilité en temps réel mise à jour par le responsable du Bar.

Le module Bar n’est pas une troisième application. Il utilise les mêmes comptes professionnels, permissions, stocks, caisses, achats, écritures et tableaux de bord que l’Espace Restaurant.

La livraison n’est pas un canal autonome du module Bar. La livraison éventuelle d’un établissement Restaurant-Bar reste gouvernée par l’Espace Restaurant et par les seuls articles déclarés livrables ; le bar ne crée pas un service de livraison indépendant. [P]

### Espace 2 — Snack-Bar

Couvre les snacks, fast-foods, comptoirs, sandwicheries, hamburgers, pizzerias, crêperies, points de restauration rapide et établissements similaires.

Fonctionnement principal :
- vente express au comptoir ;
- numéro de commande ;
- file d’attente ;
- menus combinés et formules ;
- tailles, options, sauces, accompagnements et suppléments ;
- commande sur place, à table si configurée, et à emporter ;
- QR de commande lié à une table ou à un point de retrait ;
- écran de préparation et délais ;
- stock, recettes, préparations intermédiaires, achats et dépenses ;
- caisse, paiements, facturation, comptabilité et pilotage ;
- retours clients et notation des postes ;
- assistance ZIPPLE et livechat.

**Aucune fonctionnalité de livraison ne doit être exposée ou activée dans l’Espace Snack-Bar.** [V]

## 1.2. Interfaces

ZIPPLE comporte trois interfaces complémentaires :

1. **Interface professionnelle Android :** exploitation quotidienne par le propriétaire, le gérant et les employés.
2. **Interface professionnelle Web responsive :** supervision, paramétrage, rapports, administration multi-sites et pilotage depuis ordinateur ou tablette.
3. **Pages publiques de commande :** pages web mobiles accessibles par QR Code ou lien. Elles ne sont pas une application cliente, n’exigent pas d’installation et ne créent aucun compte client.

Le promoteur et les employés disposent de comptes professionnels avec rôles et permissions. La règle « aucun compte client » concerne les consommateurs qui consultent le menu, commandent, paient ou déposent un avis.

---

# 2. Organisation multi-établissements et multi-sites

## 2.1. Architecture hiérarchique

ZIPPLE doit prendre en charge un propriétaire ou une organisation exploitant un ou plusieurs établissements.

Hiérarchie fonctionnelle :

**Organisation / Promoteur → Entité juridique éventuelle → Établissement → Espace métier → Zone → Poste → Table ou comptoir**

Exemples :
- Organisation : Groupe La Terrasse.
- Établissement : La Terrasse Bonamoussadi.
- Espace : Restaurant.
- Mode : Restaurant-Bar activé.
- Zones : salle intérieure, terrasse, VIP, comptoir.
- Postes : cuisine chaude, grill, boissons, bar et caisse.

Un autre établissement du même promoteur peut disposer d’un autre menu, d’autres horaires, d’autres prix, d’un autre stock et de son propre personnel.

## 2.2. Séparation obligatoire des opérations

Chaque établissement conserve :
- ses caisses et fonds de caisse ;
- ses moyens de paiement et rapprochements ;
- ses ventes, commandes et factures ;
- ses stocks et magasins ;
- ses lots, péremptions et inventaires ;
- ses achats, fournisseurs et dépenses ;
- ses employés, plannings et permissions ;
- ses réservations, tables et postes ;
- ses résultats et journaux comptables.

Aucune opération ne doit être automatiquement imputée à un autre établissement.

## 2.3. Compte mère et consolidation

Le propriétaire ou promoteur dispose d’une vue consolidée :
- chiffre d’affaires par établissement et total groupe ;
- marges, coûts et résultat par établissement ;
- trésorerie et écarts de caisse ;
- dettes fournisseurs et créances clients ;
- état des stocks, ruptures, pertes et transferts ;
- fréquentation, commandes et délais ;
- performance par espace, poste et période ;
- comparaison des établissements.

Il peut passer de la vue consolidée à la vue d’un établissement sans mélanger les données.

## 2.4. Transferts inter-établissements

Le moteur doit gérer les transferts autorisés de marchandises et de préparations :
1. demande de transfert ;
2. sélection du site source, du site destinataire et des articles ;
3. validation selon les permissions ;
4. sortie du stock source ;
5. état « en transit » ;
6. réception par le site destinataire ;
7. contrôle des quantités reçues et des écarts ;
8. clôture du transfert avec historique.

Les mouvements doivent conserver l’établissement source, l’établissement destinataire, les opérateurs, les dates et les quantités. Un transfert ne doit jamais être comptabilisé comme une vente.

---

# 3. Expérience client sans compte — QR Code et commande à table

## 3.1. QR Code propre à chaque table

Chaque table possède :
- un QR Code imprimable ;
- un lien public dédié ;
- un identifiant opaque ou jeton non devinable ;
- un rattachement à l’établissement, à l’espace, à la zone et à la table.

Le QR Code n’expose pas les identifiants internes ni les informations de gestion.

Lorsqu’un client le scanne :
1. la page publique identifie l’établissement et la table ;
2. elle vérifie qu’une session de table est ouverte ;
3. elle affiche la carte disponible de cet établissement ;
4. elle permet au client de composer sa commande ;
5. elle rattache la commande à la session de table active.

Si aucune session n’est ouverte, la page affiche une instruction claire invitant le client à demander l’ouverture de la table à un employé. Elle ne crée pas de ticket professionnel non autorisé.

Le QR est réutilisable, mais les sessions de table sont distinctes. À la clôture ou à la libération d’une table, l’ancienne session publique doit être invalidée. Une ancienne page ne doit pas permettre de commander sur une nouvelle occupation de la table.

## 3.2. Aucun compte client

Le client :
- ne s’inscrit pas ;
- ne se connecte pas ;
- ne crée pas de profil ZIPPLE ;
- ne télécharge pas d’application ;
- n’a pas besoin de communiquer son numéro de téléphone pour une commande à table ;
- reçoit un accès temporaire à la commande et à son suivi.

Les informations nécessaires à une commande particulière restent rattachées à cette commande et ne constituent pas un compte client.

Les éventuelles fiches d’ardoise, coordonnées de livraison ou historiques commerciaux créés par l’établissement restent des données professionnelles gérées sous permissions. Elles ne créent pas un espace de connexion client.

## 3.3. Menu dynamique et disponibilité en temps réel

La page publique affiche :
- catégories et sous-catégories ;
- photos, noms, descriptions et prix ;
- portions, tailles et variantes ;
- suppléments, accompagnements et sauces ;
- formules et menus ;
- plats du jour et promotions ;
- temps indicatif de préparation ;
- disponibilité de chaque produit.

États de disponibilité :
- **Disponible :** commandable.
- **Disponibilité faible :** commandable, avec avertissement éventuel.
- **Indisponible / épuisé :** visible ou masqué selon la configuration, mais jamais commandable.

L’équipe de cuisine ou du Bar peut, selon ses permissions :
- suspendre un article ;
- réactiver un article ;
- déclarer une quantité limitée ;
- suspendre temporairement une catégorie ;
- signaler l’indisponibilité d’un ingrédient ou d’une préparation ;
- programmer une disponibilité à des horaires déterminés.

Toute modification doit se propager en temps réel vers les pages publiques ouvertes, les postes de commande et les interfaces professionnelles.

### Contrôle de concurrence

Au moment de l’envoi, ZIPPLE vérifie à nouveau :
- que le produit est actif ;
- que la variante est disponible ;
- que les composants nécessaires sont disponibles ;
- que les quantités ne dépassent pas le stock vendable ou les capacités configurées ;
- que la session de table est encore valide.

Si le dernier article vient d’être vendu ou si un autre client a réservé la dernière quantité, la seconde commande doit être bloquée ou corrigée avant confirmation. Une page affichée quelques secondes auparavant ne constitue jamais une garantie de disponibilité.

## 3.4. Panier, commande et facture

Le client peut :
- ajouter ou retirer des articles avant soumission ;
- changer les quantités ;
- choisir les variantes ;
- ajouter les suppléments ;
- indiquer une instruction de préparation ;
- consulter le récapitulatif et le montant total ;
- valider la commande.

Après acceptation, la page affiche :
- numéro de commande ;
- établissement et table ;
- date et heure ;
- articles, quantités et prix ;
- suppléments et éventuels frais ;
- montant total ;
- statut ;
- délai annoncé ;
- état du paiement, lorsque le paiement en ligne est utilisé.

La page distingue le récapitulatif de commande ou document provisoire de la facture définitive. La facture définitive est émise selon les règles de facturation de l’établissement, notamment après confirmation de la vente et des ajustements autorisés.

## 3.5. Plusieurs clients sur une table

Plusieurs personnes peuvent scanner le QR de la même table et soumettre des commandes distinctes.

ZIPPLE doit :
- rattacher ces commandes à la session de table ;
- conserver l’auteur technique de chaque soumission comme « invité anonyme » ;
- afficher les commandes au serveur ;
- permettre de regrouper les commandes sur une addition commune ;
- permettre de séparer l’addition par personne ou groupe au moment du règlement ;
- empêcher qu’un invité puisse modifier ou consulter les commandes privées d’un autre invité.

Le fractionnement et le transfert d’addition restent réservés aux employés autorisés.

---

## 3.6. Fichier client, fidélité et parrainage — modèle NAXA Services

Le module de relation client reprend le principe métier documenté dans NAXA Services : fiche client, historique, préférences, points de fidélité, carte QR, offres et parrainage client. [V]

Cette fonction complète les commandes publiques sans modifier la règle fondamentale : **aucun compte client ZIPPLE, aucun mot de passe et aucune installation d’application ne sont requis.** Le client peut toujours commander anonymement. L’identification dans une fiche professionnelle est facultative et sert uniquement aux services de fidélité, au parrainage et à l'historique autorisé.

### Fiche et identification client

- Le restaurant ou le Snack-Bar peut créer une fiche client à partir des informations strictement utiles, notamment un nom d’usage et un numéro de téléphone communiqué volontairement.
- Le client peut rattacher une commande à sa fiche en saisissant son numéro ou en présentant sa carte QR ; le personnel peut également faire ce rattachement avec les droits nécessaires.
- Une commande anonyme reste possible sans création de fiche.
- La fiche ne constitue pas un compte de connexion. Elle n'ouvre aucun accès aux commandes, aux données ou à l'espace professionnel.
- Les données client sont isolées par organisation et accessibles uniquement aux rôles habilités.

### Code et QR personnel de parrainage

- Chaque fiche client éligible peut disposer d'un code de parrainage unique et d'un QR personnel associé. [V]
- Le code est opaque, non séquentiel et révocable ; le QR ne contient ni nom, ni numéro de téléphone, ni donnée personnelle directement lisible.
- Le client parrain partage son code ou son QR à une personne qu'il invite.
- Le nouveau client peut saisir le code sur la page publique de commande ou présenter le QR au personnel avant la validation de sa première commande payante.
- Le personnel peut rattacher le code à la fiche du nouveau client avec une trace de l'opération.
- Un seul parrain est rattaché à un nouveau client pour une même organisation. Le rattachement ne peut plus être modifié après validation de la commande déclencheuse, sauf correction exceptionnelle par un rôle autorisé et journalisée.

### Validation et attribution de la récompense

- Un parrainage devient **qualifié** uniquement après une première commande éligible effectivement terminée et intégralement réglée.
- Une commande annulée, impayée, remboursée intégralement ou constituée uniquement d'un avantage gratuit ne déclenche aucune récompense.
- Un nouveau client ne peut produire qu'un seul parrainage qualifié au sein d'une même organisation, même s'il fréquente plusieurs établissements de cette organisation.
- Le moteur de fidélité enregistre le parrain, le filleul, le code utilisé, la commande déclencheuse, l'établissement, les dates, le statut et la récompense.
- La nature de l'avantage, sa valeur, son bénéficiaire (parrain et/ou filleul), ses conditions d'utilisation, sa durée de validité et son éventuel plafond sont configurables par le promoteur. [P]
- Les récompenses peuvent être gérées sous forme de points, de bon ou d'avantage de fidélité utilisable sur une commande ultérieure. Le barème chiffré n'est pas imposé par ce cahier : il doit être défini par le promoteur avant activation commerciale. [O]
- Par défaut, les récompenses ne sont pas convertibles en espèces ni retirables. Toute exception doit faire l'objet d'une règle explicite et d'un contrôle financier.
- En cas d'annulation ou de remboursement postérieur à l'attribution, ZIPPLE doit bloquer ou reprendre la récompense selon son état d'utilisation, avec une écriture inverse et un journal d'audit.

### Prévention de la fraude et suivi

- Interdire l'auto-parrainage et les rattachements circulaires.
- Détecter les doublons évidents de coordonnées et les répétitions anormales ; placer les cas douteux en revue plutôt que supprimer silencieusement les traces.
- Empêcher la réutilisation d'un code sur plusieurs fiches d'un même nouveau client.
- Conserver l'historique des codes, rattachements, validations, corrections, récompenses acquises et récompenses utilisées.
- Afficher au promoteur : invitations émises, parrainages saisis, parrainages qualifiés, taux de conversion, récompenses à attribuer, attribuées et utilisées, coûts des avantages et résultats par établissement.
- Le programme client de ZIPPLE est distinct d'un programme de partenaires commerciaux externes. Il ne rémunère pas automatiquement un intermédiaire externe.

Le parcours de parrainage et de fidélité est prévu pour les deux espaces Restaurant et Snack-Bar. Il ne crée jamais de canal de livraison dans le Snack-Bar et ne modifie pas l'absence de compte client.

---

# 4. Cycle de préparation, délai et compte à rebours

## 4.1. Routage automatique

Une commande peut contenir des éléments préparés à différents postes.

Exemple :
- poulet braisé → grill / cuisine chaude ;
- plantain → accompagnements ;
- jus naturel → boissons ;
- bière → Bar, si le mode Restaurant-Bar est activé.

ZIPPLE décompose les lignes et les envoie automatiquement aux postes compétents tout en conservant une commande consolidée pour le client et la caisse.

## 4.2. Statuts professionnels

Cycle recommandé :
1. reçue ;
2. acceptée ;
3. en préparation ;
4. prête ;
5. remise au service ou au comptoir ;
6. servie / remise au client ;
7. clôturée.

Les statuts d’annulation, de rejet, de rupture ou de remboursement sont distincts et nécessitent une raison selon les permissions.

## 4.3. Estimation du délai

Le délai annoncé est calculé à partir :
- des temps de préparation des articles ;
- des temps de cuisson ou de transformation ;
- des préparations simultanées possibles ;
- de la charge actuelle de chaque poste ;
- de la priorité des commandes ;
- des commandes en attente ;
- de la capacité de service configurée.

Le délai global d’une commande correspond à l’estimation de disponibilité complète de la commande, et non à la somme naïve de tous les temps unitaires.

L’estimation doit être horodatée et conservée. Toute prolongation doit conserver l’estimation initiale et la nouvelle estimation, avec le motif et l’heure du changement.

## 4.4. Compte à rebours synchronisé

Dès l’acceptation de la commande dans le circuit opérationnel, ZIPPLE démarre le compte à rebours.

Le client et l’établissement voient le même état, calculé à partir des horodatages de référence du serveur. Le compteur ne doit pas dépendre de deux chronomètres indépendants.

Côté client :
- temps restant ;
- statut de préparation ;
- statut par poste si pertinent ;
- éventuelle mise à jour du délai ;
- bouton de confirmation de service.

Côté établissement :
- numéro de commande et table ;
- heure de réception ;
- délai annoncé ;
- temps restant ou retard ;
- postes concernés ;
- état détaillé de préparation ;
- éventuelle intervention requise.

À zéro, le système ne clôture pas automatiquement la commande. Il passe en état « délai dépassé » et mesure le retard tant que le service n’est pas déclaré effectué.

## 4.5. Service anticipé

Si le client reçoit sa commande avant la fin du compte à rebours, il peut cliquer sur :

**« J’ai été servi »**

ZIPPLE :
- arrête le compteur de service ;
- enregistre l’heure de confirmation ;
- calcule le délai réel ;
- calcule le gain ou l’écart par rapport au délai annoncé ;
- met à jour les indicateurs de service.

L’équipe peut également marquer le service comme effectué. Les deux événements restent distingués : confirmation employé et confirmation client.

## 4.6. Service après dépassement

Après dépassement, la page présente un message d’excuse et le temps de retard écoulé.

Quand le client confirme « J’ai été servi », la page lui propose un feedback facultatif :
- note globale ;
- note par poste concerné ;
- motif de l’insatisfaction ;
- commentaire ou suggestion.

Le client peut ignorer le formulaire. Le feedback ne conditionne ni la remise de la commande ni la clôture de l’addition.

## 4.7. Disponibilité réseau

La page publique de commande, la vérification en temps réel des produits, le paiement en ligne, la géolocalisation et le suivi synchronisé exigent une connexion Internet active.

Si la connexion est perdue :
- afficher clairement l’état hors connexion ;
- ne jamais présenter une commande comme confirmée sans accusé de réception serveur ;
- conserver le panier localement tant que la page reste disponible ;
- permettre une nouvelle tentative contrôlée ;
- éviter tout doublon par clé d’idempotence.

---

# 5. Module Bar — fonctionnement détaillé

Le Bar utilise le moteur de commande ZIPPLE mais dispose de ses propres catégories, stocks, recettes et postes de préparation.

## 5.1. Catalogue et tarification

- boissons alcoolisées et non alcoolisées ;
- bouteilles, demi-bouteilles, canettes, verres et doses ;
- boissons pression et fûts, lorsque l’établissement en exploite ;
- cocktails et boissons composées ;
- tailles, volumes et variantes ;
- suppléments, glaçons, fruits, sirops et accompagnements ;
- prix par format et unité de vente ;
- tarifs horaires ou promotions si configurés ;
- suspension immédiate d’un produit.

Toute tarification promotionnelle doit garder une trace de sa période, de son auteur et des autorisations nécessaires.

## 5.2. Stock et consignes

- stock par bouteille, canette, pack, carton, casier, fût et dose ;
- conversions d’unités ;
- suivi des bouteilles ouvertes et consommations par verre ;
- consignes par fournisseur et éventuellement par client ;
- suivi des casiers sortis, vides rendus et manquants ;
- retours fournisseur ;
- casse, offerts, dégustations et pertes justifiées ;
- inventaires physiques et écarts ;
- coût et marge par boisson.

Une vente au verre doit diminuer le stock selon la quantité réellement configurée dans la fiche article ou la recette.

## 5.3. Poste Bar et service

Le responsable du Bar reçoit les tickets dédiés, les priorise et met à jour les états :
- reçu ;
- préparation ;
- prêt ;
- remis au serveur ;
- servi.

Le serveur peut voir l’état de chaque boisson dans la commande globale de la table.

## 5.4. Indicateurs Bar

- boissons vendues par format ;
- chiffre d’affaires par catégorie ;
- coût matière et marge ;
- consommation théorique et stock réel ;
- rendement des bouteilles et fûts ;
- casse, offerts, dégustations et pertes ;
- temps de préparation ;
- commandes en retard ;
- retours clients ;
- performance par poste et par période.

Les règles légales de commercialisation des boissons alcoolisées, de contrôle d’âge et d’affichage doivent être vérifiées avant activation selon le pays et l’établissement. [O]

---

# 6. Espace Snack-Bar — parcours spécialisé

Le Snack-Bar doit reprendre les fonctions transversales du Restaurant tout en conservant un parcours express et sans livraison.

## 6.1. Vente rapide

- écran caisse comptoir ;
- catalogue avec photos et prix ;
- recherche immédiate ;
- catégories favorites ;
- ajout d’articles en quelques actions ;
- quantité et variantes ;
- menus combinés ;
- suppléments et options ;
- numéro de commande unique ;
- impression ou affichage du numéro ;
- paiement et reçu ;
- commandes sur place, à table si configurées, et à emporter.

## 6.2. Menus et formules

Un menu peut comprendre :
- produit principal ;
- accompagnement ;
- boisson ;
- dessert ou extra ;
- choix de taille ;
- choix de sauce ;
- suppléments payants.

Le moteur de formule doit vérifier les composants et leur disponibilité. Il doit permettre de remplacer un élément selon les règles de la formule et d’ajuster le prix si nécessaire.

Exemples de familles :
- sandwichs ;
- hamburgers ;
- hot-dogs ;
- pizzas ;
- frites ;
- poulet ;
- crêpes et gaufres ;
- jus et boissons ;
- desserts et menus combinés.

La liste n’est pas limitative.

## 6.3. Préparation et file d’attente

- envoi automatique aux postes de préparation ;
- affichage des commandes par priorité ;
- délai cible ;
- commandes en retard ;
- commande prête ;
- appel du numéro ;
- remise au client ;
- commandes non retirées ;
- annulation et perte selon les permissions.

## 6.4. Production et stock

- fiches recettes ;
- préparations intermédiaires ;
- sauces, pâtes, marinades, jus, produits précuits ;
- quantités produites ;
- rendement et portions disponibles ;
- consommation des ingrédients ;
- pertes et invendus ;
- stock d’emballages ;
- coût réel du menu.

## 6.5. QR et absence de livraison

Le Snack-Bar peut disposer :
- de QR Codes par table pour les clients qui consomment sur place ;
- d’un QR Code de commande au comptoir ou à une zone de retrait ;
- d’une page publique sans compte client ;
- d’un suivi de préparation par numéro.

**Le canal livraison est absent de l’Espace Snack-Bar.** Il ne doit pas apparaître dans les paramètres, les pages publiques, les tarifs de livraison ou les rapports de cet espace. [V]

---

# 7. Livraison de l’Espace Restaurant — réutilisation du mécanisme NAXA

## 7.1. Principe

La livraison est activable par le promoteur ou le responsable habilité pour chaque établissement Restaurant. Elle est désactivée tant que l’établissement n’a pas configuré son service, ses zones, ses tarifs et ses livreurs. [P]

ZIPPLE doit réutiliser le mécanisme de livraison déjà employé dans NAXA, en l’adaptant au secteur de la restauration. Il ne faut pas créer un système concurrent ni obliger le client à télécharger l’application.

La responsabilité opérationnelle de la livraison appartient à l’établissement et à son organisation de livreurs. ZIPPLE fournit les outils logiciels de gestion et de suivi.

## 7.2. QR Code de livraison en zone stratégique

En plus des QR Codes de table, l’établissement peut générer des QR Codes publics destinés à des emplacements stratégiques :
- affiches et panneaux ;
- comptoirs partenaires autorisés ;
- supports promotionnels ;
- lieux de passage ;
- campagnes et supports de communication.

Chaque QR Code ouvre une page de commande publique rattachée à l’établissement et, si configuré, à la zone ou à la campagne d’origine.

Cette page :
- présente le menu et les produits actuellement disponibles ;
- permet de composer un panier ;
- propose le mode livraison lorsque l’établissement l’a activé ;
- demande l’autorisation de géolocalisation du navigateur au moment utile ;
- permet de déplacer le point sur une carte ou de renseigner manuellement l’adresse si la géolocalisation est refusée ou indisponible ;
- calcule la zone et les frais applicables ;
- collecte uniquement les coordonnées minimales nécessaires à la remise de la commande ;
- propose le paiement selon les moyens activés.

Aucune application mobile cliente n’est exigée.

## 7.3. Géolocalisation et zones

La géolocalisation doit être demandée avec une explication claire et uniquement lorsque le client choisit la livraison.

ZIPPLE doit prévoir :
- coordonnées GPS lorsque le client l’autorise ;
- adresse et indications complémentaires ;
- point de livraison positionné sur carte ;
- zones de livraison configurées par établissement ;
- distances ou périmètres selon la méthode retenue ;
- frais par zone ou règle tarifaire configurée ;
- commande hors zone refusée ou soumise à validation manuelle ;
- possibilité de corriger la position ;
- solution manuelle si le navigateur ne fournit pas la position.

La position fournie par le navigateur doit être confirmée ou corrigée par le client. Elle ne doit pas être considérée comme une preuve suffisante de remise.

Les données de localisation ne doivent être conservées que selon la finalité et la durée nécessaires au traitement, à la preuve et aux obligations applicables. [P]

## 7.4. Données de contact sans compte

Pour une livraison, le client fournit les informations minimales de contact nécessaires :
- nom ou nom d’usage, selon le besoin de remise ;
- numéro de téléphone joignable ;
- localisation et adresse ;
- instructions d’accès utiles.

Ces données sont rattachées à la commande et ne créent aucun compte client. Aucun mot de passe, profil personnel ou historique de connexion client ne doit être créé.

## 7.5. Cycle de livraison

1. Commande créée par la page publique.
2. Vérification de disponibilité, zone, frais et moyen de paiement.
3. Confirmation de commande par ZIPPLE.
4. Préparation par la cuisine.
5. Commande prête.
6. Affectation à un livreur de l’établissement.
7. Remise au livreur enregistrée.
8. Départ en livraison et suivi du statut.
9. Livraison effectuée et confirmation de remise.
10. Clôture de la commande et rapprochement du paiement.

Statuts minimaux :
- à confirmer ;
- acceptée ;
- en préparation ;
- prête ;
- attribuée à un livreur ;
- remise au livreur ;
- en cours de livraison ;
- livrée ;
- échec / client injoignable ;
- annulée selon les règles.

Les événements de livraison doivent conserver les heures, les acteurs et les changements d’état.

## 7.6. Interface livreur

Le livreur utilise un accès professionnel ZIPPLE, avec des droits limités à ses missions :
- commandes qui lui sont attribuées ;
- coordonnées et consignes nécessaires ;
- itinéraire ou ouverture d’un service cartographique compatible ;
- changement de statut autorisé ;
- appel du client si nécessaire ;
- confirmation de remise ;
- motif d’échec ou d’impossibilité de remise.

Le livreur ne voit ni la comptabilité complète, ni le stock complet, ni les ventes des autres établissements.

## 7.7. Paiement NAXA

Le paiement client doit réutiliser le mécanisme de paiement déjà disponible dans NAXA, sans créer un deuxième système de paiement ZIPPLE.

Exigences :
- réutiliser l’intégration et les contrats de paiement existants après vérification technique du code courant ;
- conserver l’abstraction de paiement et les moyens pris en charge par NAXA ;
- ne pas choisir un nouvel opérateur ou prestataire sans décision ;
- afficher le montant exact, le bénéficiaire et le statut ;
- confirmer une transaction côté serveur ;
- protéger contre les doubles soumissions et doubles paiements ;
- conserver la référence de transaction ;
- rapprocher paiement, commande et remboursement éventuel ;
- prévoir les états initié, en attente, confirmé, échoué, annulé et remboursé lorsque le mécanisme existant les prend en charge ;
- permettre un paiement en caisse ou à la remise uniquement si le promoteur l’active dans les moyens de paiement autorisés.

Une capture d’écran, une déclaration du client ou un simple montant identique ne constitue pas une confirmation de paiement. Le statut « payé » n’est attribué qu’après vérification par le mécanisme NAXA.

**Dépendance technique [B] :** le contrat exact de l’intégration de paiement active dans le code NAXA doit être relu au moment de l’implémentation. La documentation historique NAXA consultée contient des états de paiement différents selon les versions ; aucune route, aucun endpoint, aucune clé et aucun fournisseur ne doivent être inventés à partir d’un ancien texte.

## 7.8. Limite de livraison

- Espace Restaurant : livraison facultative par établissement.
- Module Bar : aucune livraison autonome.
- Espace Snack-Bar : aucune livraison.
- Les commandes à emporter et le retrait au comptoir ne sont pas des livraisons.

---

# 8. Catalogue, recettes, prix et disponibilité

## 8.1. Catalogue structuré

Chaque fiche article peut contenir :
- nom, code interne, catégorie ;
- photo, description ;
- unité de vente ;
- prix d’achat et prix de vente ;
- variantes et tailles ;
- suppléments ;
- recette ou composition ;
- postes de préparation ;
- temps cible ;
- état de disponibilité ;
- restrictions de canal ;
- dates et périodes de validité ;
- historique des modifications.

## 8.2. Formules et menus combinés

Le moteur doit prendre en charge :
- composants obligatoires et optionnels ;
- listes de choix ;
- suppléments ;
- remplacement d’un composant ;
- règles de prix ;
- disponibilité liée à chaque composant ;
- recette et consommation correspondantes ;
- historique des compositions.

Un menu ne doit pas rester commandable si un composant obligatoire est indisponible, sauf si une substitution autorisée est proposée au client.

## 8.3. Tarification

- prix par établissement ;
- prix par espace et par canal ;
- prix par format, portion ou variante ;
- prix promotionnels ;
- prix datés avec historique ;
- autorisation pour les changements de prix ;
- comparaison du prix courant au coût de revient ;
- historique de prix d’achat.

Une modification de recette ou de tarif ne modifie jamais rétroactivement le détail des ventes passées.

---

# 9. Stocks, approvisionnement et production

Ce module est commun aux deux espaces et doit être traité comme une composante du cœur opérationnel.

## 9.1. Familles de stocks

1. Ingrédients bruts : viandes, poissons, légumes, riz, farine, huile, épices, produits laitiers.
2. Boissons et marchandises : bouteilles, canettes, cartons, fûts, boissons préparées.
3. Préparations intermédiaires : sauces, marinades, pâtes, jus, fonds, garnitures.
4. Produits préparés ou portions prêtes à servir.
5. Emballages et consommables : barquettes, sachets, gobelets, serviettes, couverts, papier et produits de nettoyage.

## 9.2. Unités et conversions

Gérer les unités et conversions :
- kilogramme / gramme ;
- litre / millilitre ;
- pièce / portion ;
- carton / pack / bouteille ;
- casier / bouteille vide ;
- dose / verre / bouteille ;
- unité de conditionnement fournisseur.

Les conversions doivent être explicites et contrôlées. Une conversion ne peut pas être déduite automatiquement sans règle configurée.

## 9.3. Entrées et sorties

Chaque mouvement possède :
- établissement et magasin ;
- article ;
- quantité et unité ;
- coût unitaire et valeur ;
- lot et péremption si concernés ;
- origine ou destination ;
- motif ;
- auteur et date ;
- justificatif éventuel ;
- validation lorsque requise.

Les mouvements sont historisés. Une correction ne supprime pas l’historique : elle crée un mouvement correctif.

## 9.4. Lots, péremption et rotation

- lots fournisseurs ;
- date d’entrée ;
- date de péremption ;
- état du lot ;
- quantité restante ;
- alerte à l’approche de la péremption ;
- règle de sortie FEFO pour les denrées périssables, lorsque pertinente ;
- blocage des lots expirés ;
- retour fournisseur ;
- promotion autorisée ;
- perte ou destruction avec justificatif.

## 9.5. Recettes et consommation automatique

Une fiche recette détaille :
- ingrédients ;
- quantités ;
- unités ;
- pertes ou rendement attendu ;
- nombre de portions ;
- coût théorique ;
- version de recette.

À la vente confirmée, ZIPPLE consomme les composants correspondants. Les commandes qui ne sont pas encore acceptées ne doivent pas provoquer une sortie définitive. Les réservations temporaires de stock et leur libération doivent être gérées séparément des sorties effectives.

La consommation théorique doit pouvoir être comparée à l’inventaire physique et aux pertes enregistrées.

## 9.6. Préparations et production par lot

- ordre de production ;
- recette de préparation ;
- quantités planifiées ;
- matières consommées ;
- quantité obtenue ;
- rendement réel ;
- pertes ;
- date et opérateur ;
- lots des composants ;
- date limite d’utilisation ;
- stock de la préparation obtenue.

Exemple : une préparation de sauce, marinade, pâte ou jus peut être créée en lot puis consommée par plusieurs recettes.

## 9.7. Braisage et rendement

Conserver le module braiseur historique :
- achats à la pièce ou au poids ;
- poids entrant ;
- poids après cuisson ;
- quantité commercialisable ;
- rendement réel ;
- vente à la portion ou au poids ;
- prix du jour ;
- invendus ;
- report, promotion ou perte ;
- comparaison des quantités achetées, préparées, vendues et perdues.

Les pertes normales de transformation doivent être séparées des écarts inexpliqués.

## 9.8. Inventaires, pertes et écarts

- inventaire par comptage ou scan ;
- inventaire tournant ;
- stock théorique ;
- stock physique ;
- écart et motif ;
- casse, vol présumé, péremption, offert, dégustation, erreur de préparation ;
- validation selon seuil ;
- ajustement historisé ;
- rapports par site, magasin, catégorie et opérateur.

## 9.9. Fournisseurs et achats

Cycle d’approvisionnement :
1. fournisseur et catalogue ;
2. demande d’achat ;
3. devis ou prix de référence ;
4. commande ;
5. réception totale ou partielle ;
6. contrôle quantitatif et qualitatif ;
7. facture ;
8. dette fournisseur ;
9. règlement total ou partiel ;
10. évaluation du fournisseur.

Prévoir :
- prix historiques ;
- délais et fiabilité ;
- commande par WhatsApp préparée ;
- facture photo/PDF ;
- OCR pour préremplir les lignes ;
- rapprochement commande / réception / facture ;
- retour fournisseur ;
- échéancier fournisseur ;
- transfert entre sites.

L’OCR propose une lecture ; l’employé vérifie et valide les quantités et les montants.

---

# 10. Dépenses, charges et trésorerie

ZIPPLE doit enregistrer les dépenses d’approvisionnement et les dépenses d’exploitation.

## 10.1. Dépenses d’entrées et approvisionnements

- achats d’ingrédients ;
- achats de boissons ;
- achats d’emballages ;
- achats de consommables ;
- achats de produits d’entretien ;
- achats de marchandises et produits destinés à la revente ;
- frais associés à l’approvisionnement.

Les dépenses d’achat et les entrées en stock doivent être rapprochées pour éviter toute double comptabilisation.

## 10.2. Dépenses opérationnelles

Catégories configurables, notamment :
- eau, électricité et gaz ;
- transport et approvisionnement ;
- entretien et réparation ;
- loyers et charges locatives ;
- télécommunications ;
- commissions et frais de paiement ;
- nettoyage ;
- fournitures ;
- sécurité ;
- marketing et publicité ;
- frais administratifs ;
- autres charges autorisées.

Les salaires, primes, avances et commissions peuvent être suivis dans le module Équipe et alimenter les charges correspondantes selon la politique comptable.

## 10.3. Fiche de dépense

Chaque dépense conserve :
- date ;
- établissement ;
- catégorie ;
- bénéficiaire ou fournisseur ;
- description ;
- montant et devise ;
- moyen de paiement ;
- caisse ou compte utilisé ;
- justificatif photo/PDF ;
- auteur ;
- approbateur si requis ;
- état : brouillon, soumise, validée, payée, rejetée ou annulée.

## 10.4. Contrôles

- seuils d’autorisation ;
- approbation à distance ;
- séparation entre demandeur et valideur lorsque nécessaire ;
- pièce justificative ;
- journal des modifications ;
- prévention des doublons ;
- rapprochement dépense / décaissement / écriture.

---

# 11. Caisse, facturation et paiements

## 11.1. Multi-caisses

- plusieurs caisses par établissement ;
- caisse par poste ou terminal ;
- affectation à un caissier ;
- fonds initial ;
- ouverture ;
- encaissements ;
- décaissements ;
- retraits ;
- remboursements ;
- clôture ;
- comptage physique ;
- solde théorique ;
- écarts et motifs.

## 11.2. Moyens de paiement

- espèces ;
- Mobile Money ;
- autres moyens électroniques activés ;
- paiement à la remise si autorisé ;
- ardoise/crédit selon permissions ;
- paiement mixte.

Un montant peut être réparti entre plusieurs moyens de paiement. Chaque transaction conserve sa référence et son statut.

## 11.3. Annulations, avoirs et remboursements

- demande d’annulation ;
- motif obligatoire ;
- autorisation selon le montant et le rôle ;
- contrepassation ou écriture de correction ;
- restitution de stock si applicable ;
- remboursement selon le moyen d’origine ;
- preuve et référence ;
- journal complet.

Une annulation de commande ne doit pas être assimilée automatiquement à un remboursement financier. Les deux flux sont distincts.

## 11.4. Ardoise et créances

- client identifié par l’établissement lorsque nécessaire ;
- plafond ;
- échéance ;
- autorisation ;
- encaissements partiels ;
- solde ;
- relance ;
- journal des mouvements.

Une vente à crédit n’est pas considérée comme de la trésorerie encaissée.

## 11.5. Factures et reçus

- récapitulatif de commande ;
- facture provisoire ;
- facture définitive ;
- reçu de paiement ;
- avoir ou justificatif d’annulation ;
- impression ;
- envoi ou partage par lien/WhatsApp si l’établissement le choisit.

---

# 12. Comptabilité et pilotage financier

## 12.1. Base comptable

Prévoir une comptabilité de gestion structurée, avec :
- journal des ventes ;
- journal des achats ;
- journal des dépenses ;
- journal de caisse ;
- journal de banque ou portefeuille de paiement ;
- comptes clients ;
- comptes fournisseurs ;
- stock et consommation ;
- immobilisations ou équipements si le périmètre le prévoit ;
- TVA et taxes paramétrables ;
- plan de comptes SYSCOHADA configurable.

Les règles fiscales et comptables applicables doivent être validées avec le professionnel comptable de l’établissement. ZIPPLE ne doit pas présenter un paramétrage générique comme un conseil fiscal personnalisé.

## 12.2. Documents et états

- journal ;
- grand livre ;
- balance ;
- compte de résultat simplifié ;
- trésorerie ;
- état des créances ;
- état des dettes ;
- état des achats ;
- état des dépenses ;
- état des stocks et valorisation ;
- ventes par taux ou catégorie fiscale ;
- exports Excel et PDF.

## 12.3. Coût des ventes et résultat

La gestion doit distinguer :
- achats et entrées en stock ;
- valeur du stock ;
- consommation des ingrédients ;
- coût des produits vendus ;
- pertes et destructions ;
- charges d’exploitation ;
- chiffre d’affaires ;
- marge brute ;
- résultat selon les écritures paramétrées.

Un achat de matières premières immobilisé dans le stock ne doit pas être comptabilisé une seconde fois comme charge complète au moment de l’achat et au moment de la consommation. Les règles comptables doivent assurer la cohérence entre stock, coût des ventes et résultat.

## 12.4. Comptabilité multi-sites

- journaux distincts par établissement ;
- entité juridique de rattachement ;
- consolidation au niveau groupe ;
- élimination ou identification des transferts internes ;
- droits comptables en lecture ou export ;
- période clôturée non modifiable sans procédure de correction ;
- audit et historique des écritures.

---

# 13. Équipe, postes et performance terrain

## 13.1. Rôles métier

Rôles configurables :
- propriétaire / promoteur ;
- administrateur de l’organisation ;
- gérant ;
- responsable d’établissement ;
- responsable de salle ;
- serveur ;
- caissier ;
- chef de cuisine ;
- cuisinier ;
- responsable Bar ;
- barman ;
- magasinier ;
- acheteur ;
- comptable ;
- livreur pour le seul Espace Restaurant ;
- agent de nettoyage ;
- support ou contrôle interne, selon le besoin.

Un même employé peut occuper plusieurs fonctions selon les affectations autorisées. Les droits restent attribués explicitement.

## 13.2. Organisation RH

- dossiers professionnels ;
- affectation par établissement et par poste ;
- horaires et plannings ;
- pointage et présence ;
- pauses, absences et retards ;
- objectifs ;
- primes, commissions et avances ;
- formation ;
- compétences par poste ;
- intégration d’un nouvel employé ;
- évaluations périodiques ;
- historique des affectations.

## 13.3. Notation par poste sur feedback terrain

ZIPPLE doit produire un suivi de notation des postes à partir des retours terrain, en particulier des clients après une commande.

Postes évaluables selon la commande :
- cuisine / préparation ;
- grill / braisage ;
- Bar / boissons ;
- service en salle ;
- caisse / accueil ;
- livraison, uniquement dans l’Espace Restaurant ;
- comptoir / remise, dans l’Espace Snack-Bar.

Le feedback peut comprendre :
- note globale ;
- note par poste concerné ;
- temps d’attente ;
- exactitude de la commande ;
- qualité de préparation ;
- température ou présentation ;
- accueil et service ;
- commentaire ou suggestion ;
- motif prédéfini.

La page client n’affiche que les postes réellement impliqués dans sa commande. Elle ne doit pas imposer un questionnaire long.

## 13.4. Feedbacks internes

Le gérant peut enregistrer des retours terrain internes :
- observation ;
- poste ;
- période ou service ;
- point positif ;
- incident ou difficulté ;
- action corrective ;
- responsable ;
- échéance et état.

Ces observations sont distinguées des avis clients.

## 13.5. Calcul des performances

Indicateurs par poste :
- note moyenne ;
- nombre de retours ;
- taux de satisfaction ;
- motifs récurrents ;
- délai moyen ;
- taux de commandes correctes ;
- retards ;
- incidents ;
- progrès dans le temps.

Les performances peuvent être filtrées par jour, service, semaine, mois, établissement et période.

**Garde-fous :**
- une seule note ne doit pas produire un classement définitif ;
- le nombre de retours est affiché avec la note ;
- les échantillons insuffisants sont signalés ;
- les commentaires injurieux ou contenant des données personnelles peuvent être modérés ;
- les avis ne déclenchent jamais automatiquement une sanction, une retenue salariale ou une décision RH ;
- l’identité individuelle d’un employé n’est reliée à un avis que si le rattachement est fiable, autorisé et justifié.

## 13.6. Progression et formation

S’inspirer du suivi de progression professionnelle de JOBLY :
- compétences attendues par poste ;
- niveau actuel ;
- objectifs de progression ;
- formation suivie ;
- validation de compétence ;
- feedback du responsable ;
- recommandations de progression.

ZIPPLE ne devient pas une plateforme de recrutement. Il aide à intégrer, former et faire progresser les personnes déjà affectées à l’établissement.

---

# 14. Vidéosurveillance — intégration NAXA Security

## 14.1. Objectif

Le propriétaire/promoteur et les managers autorisés peuvent consulter en temps réel les caméras de leur établissement depuis l’interface ZIPPLE, via l’intégration du module NAXA Security.

L’objectif est de superviser l’activité et les espaces autorisés, pas de créer une prestation de gardiennage ou de surveillance humaine fournie par ZIPPLE.

## 14.2. Périmètre fonctionnel

- rattachement d’un établissement à une organisation NAXA Security autorisée ;
- liste des caméras accessibles ;
- organisation par zone : salle, caisse, cuisine, réserve, terrasse, entrée, Bar ;
- état de connexion ;
- ouverture d’un flux en direct ;
- sélection d’une caméra ;
- vues multiples si le niveau de droits et la capacité le permettent ;
- contrôle d’accès selon rôle et établissement ;
- journal des consultations et accès ;
- alertes techniques de caméra indisponible, si exposées par NAXA Security.

## 14.3. Réutilisation et limites

- Réutiliser le moteur NAXA Security et ses contrats d’accès.
- Ne pas créer un système vidéo parallèle dans ZIPPLE.
- Ne pas exposer les flux dans les pages publiques de commande ou les QR Codes clients.
- Ne pas stocker les flux vidéo dans les tables métier ZIPPLE.
- Les équipements de captation et enregistreurs restent ceux du client ou de son installateur ; ZIPPLE ne vend pas les caméras.
- ZIPPLE ne fournit pas de service de surveillance humaine.
- La conservation vidéo et les enregistrements restent gérés selon le dispositif NAXA Security et les équipements autorisés.
- Le périmètre demandé ici est la consultation vidéo. La captation audio et l’analyse biométrique ou la reconnaissance faciale ne sont pas ajoutées à cette spécification.

## 14.4. Sécurité

- authentification professionnelle requise ;
- rôle et établissement vérifiés côté serveur ;
- jeton de flux de courte durée ou mécanisme équivalent ;
- accès révocable ;
- journalisation des ouvertures de flux ;
- aucune URL permanente publique ;
- aucun accès croisé entre organisations ;
- contrôle des permissions lors de chaque ouverture.

La conformité de l’installation, l’information des personnes filmées et les durées de conservation doivent être vérifiées avant exploitation. [O]

---

# 15. ZIPPLE Intelligence — IA et automatisation

ZIPPLE doit réutiliser les moteurs IA et les modèles d’assistance éprouvés dans les autres solutions de la Famille NAXA, après audit de compatibilité. Il ne faut pas recopier aveuglément des modèles de données ou des permissions d’une autre application.

## 15.1. Moteurs spécialisés

### Demand Intelligence
- prévision des ventes par jour, période, événement et saison ;
- anticipation de l’affluence ;
- estimation des besoins par espace et établissement.

### Stock Intelligence
- prévision des ruptures ;
- suggestions de réapprovisionnement ;
- détection de stock dormant ;
- alertes sur péremption et rotation.

### Recipe Intelligence
- coût théorique et réel des recettes ;
- impact des variations de prix fournisseur ;
- analyse des rendements ;
- comparaison du coût par portion.

### Pricing Intelligence
- suggestions de prix basées sur le coût, les marges et les données de ventes ;
- simulations de prix ;
- alerte lorsqu’un prix devient inférieur au coût connu ;
- explication des hypothèses.

L’IA ne modifie pas automatiquement les prix.

### Waste Intelligence
- prévision des invendus ;
- détection des pertes récurrentes ;
- comparaison production / ventes ;
- recommandations de quantité à préparer.

### Fraud & Anomaly Detection
- annulations inhabituelles ;
- remboursements répétitifs ;
- offerts anormaux ;
- écarts de caisse ;
- consommation matière supérieure au théorique ;
- mouvements de stock atypiques ;
- doublons ou anomalies de paiement.

L’IA signale et explique ; un responsable examine.

### Workforce Intelligence
- prévision des besoins en personnel ;
- analyse des périodes de forte activité ;
- suggestions de planning ;
- analyse du temps de service ;
- comparaison de performance par poste.

### Feedback Intelligence
- regroupement des motifs de réclamation ;
- synthèse des suggestions ;
- tendances de satisfaction ;
- détection des causes récurrentes de retard ;
- recommandations d’amélioration.

### OCR & Document Intelligence
- lecture de factures fournisseurs ;
- lecture de bons de commande et de livraison ;
- préremplissage des entrées de stock et dépenses ;
- comparaison commande / facture / réception ;
- contrôle humain avant validation.

### Business Companion
Assistant conversationnel écrit et vocal, en français et en anglais, permettant de questionner les données :
- « Quel établissement a été le plus rentable cette semaine ? »
- « Quels produits risquent la rupture demain ? »
- « Quelles dépenses ont augmenté ce mois-ci ? »
- « Quel poste accumule le plus de retards ? »
- « Quels plats ont une marge devenue faible ? »

Les réponses doivent citer la période et les données utilisées, distinguer données exactes et estimations et signaler les données manquantes.

## 15.2. Briefings

Briefing du matin :
- résultats de la veille ;
- meilleures ventes ;
- commandes et retards ;
- stocks critiques ;
- achats à prévoir ;
- réservations ;
- dépenses et échéances ;
- feedbacks terrain à traiter.

Briefing du soir :
- chiffre d’affaires ;
- paiements et trésorerie ;
- caisse théorique et réelle ;
- coût et marge ;
- pertes et invendus ;
- incidents de service ;
- retours clients ;
- points à corriger le lendemain.

Briefings par établissement et synthèse consolidée au niveau du promoteur.

## 15.3. Règles de confiance IA

- l’IA propose, l’humain décide ;
- aucun chiffre financier n’est inventé ;
- chaque calcul est traçable ;
- les recommandations expliquent leur fondement ;
- aucune décision sensible ne se valide uniquement par l’IA ;
- les données personnelles et de paiement ne sont pas envoyées à un service externe sans nécessité, base légitime et contrôle ;
- le fonctionnement métier de base doit rester disponible sans IA en ligne.

---

# 16. Support client et livechat

ZIPPLE reprend le centre de support et le livechat utilisés dans les autres solutions, en distinguant clairement le support logiciel et l’assistance liée à une commande.

## 16.1. Support professionnel ZIPPLE

Accessible aux promoteurs, managers et employés autorisés :
- centre d’aide ;
- FAQ ;
- guides d’utilisation ;
- création de ticket ;
- choix de catégorie ;
- priorité et niveau d’urgence ;
- pièces jointes ;
- historique des échanges ;
- statut de traitement ;
- escalade vers agent humain ;
- suivi de résolution ;
- satisfaction après résolution.

## 16.2. Livechat

Parcours :
1. utilisateur ouvre le chat ;
2. classification de la demande ;
3. réponse documentaire ou automatisée si possible ;
4. transmission à un conseiller si nécessaire ;
5. reprise humaine avec contexte ;
6. historique et clôture.

Le livechat peut proposer un relais vers WhatsApp Business officiel lorsque le canal est activé et que les conditions de messagerie sont respectées.

## 16.3. Assistance client final

Depuis une page publique de commande, le client peut accéder à une aide liée à sa commande :
- problème de commande ;
- article indisponible ;
- délai ou retard ;
- question de paiement ;
- difficulté de livraison, seulement pour le Restaurant ;
- réclamation.

Le client n’a pas besoin de créer un compte. L’accès à la commande est limité par un jeton temporaire et les informations nécessaires.

Le support client final ne doit jamais donner accès au support professionnel, aux ventes globales, aux données d’autres clients ou aux fonctions de gestion.

---

# 17. Modules transversaux de la Famille NAXA

Les mécanismes transversaux doivent être réutilisés lorsqu’ils sont compatibles, avec adaptation des droits et modèles de ZIPPLE.

## 17.1. Comptes et authentification professionnelle

- accès du promoteur et des employés ;
- création ou activation par les canaux d’administration prévus ;
- authentification sécurisée ;
- changement d’utilisateur ;
- verrouillage après tentatives anormales ;
- récupération de compte encadrée ;
- session et appareil ;
- révocation à distance ;
- aucune inscription ou connexion client final.

## 17.2. Rôles, permissions et validations

Permissions granulaires par organisation, établissement, espace et poste :
- consulter ;
- créer ;
- modifier ;
- valider ;
- annuler ;
- rembourser ;
- exporter ;
- clôturer ;
- administrer.

Les opérations sensibles nécessitent une validation par le rôle autorisé. Chaque approbation conserve l’auteur, le valideur, la date, la valeur précédente, la nouvelle valeur et le motif.

## 17.3. Fonctionnement hors connexion

Les opérations professionnelles courantes doivent être conçues offline-first :
- ventes ;
- commandes internes ;
- mouvements de stock ;
- dépenses ;
- pointages ;
- opérations de caisse selon les règles autorisées.

La synchronisation :
- reprend automatiquement ;
- utilise des identifiants uniques ;
- évite les doublons ;
- gère les conflits ;
- conserve l’heure locale et l’heure serveur ;
- journalise les erreurs et reprises.

Les pages QR publiques, la disponibilité en temps réel, la géolocalisation, la vidéo et la confirmation de paiement nécessitent une connexion active.

## 17.4. Notifications et WhatsApp

- notifications locales ;
- push ;
- centre de notifications ;
- messages WhatsApp préparés ;
- notifications de commande ;
- commande prête ;
- retard ;
- rupture ;
- alerte stock ;
- dépense à approuver ;
- clôture à effectuer ;
- incident ;
- ticket support.

Les messages automatiques WhatsApp ne sont permis que via une intégration officielle et selon les consentements et modèles requis. Les messages préparés par lien restent disponibles lorsque l’automatisation n’est pas activée.

## 17.5. Documents et pièces jointes

- factures fournisseurs ;
- bons de commande ;
- bons de livraison ;
- justificatifs de dépenses ;
- photos de pertes ou incidents ;
- documents comptables ;
- rapports ;
- pièces liées au support.

Les fichiers sont privés, soumis aux permissions, journalisés et rattachés à un établissement. Les liens temporaires doivent expirer.

## 17.6. Abonnements et droits d’accès

- deux offres uniquement : Accès et Premium ;
- état de l’abonnement ;
- date de début et d’échéance ;
- période d’essai éventuelle si elle est autorisée ;
- paiement et rapprochement ;
- activation des droits par entitlements ;
- gestion des limites d’utilisateurs, appareils, sites et options ;
- historique des changements ;
- données métier conservées selon les règles de résiliation et d’export ;
- périodicités vendues : mensuelle ou annuelle uniquement ;
- formule annuelle : accès pendant 12 mois consécutifs pour le prix de 10 mensualités, soit 2 mois offerts ;
- aucune formule commerciale de 3 mois ou de 6 mois, ni promotion accordant 3 ou 6 mois d'accès ;
- aucune campagne ou remise ne peut cumuler des avantages pour transformer l'offre annuelle en 3 ou 6 mois offerts.

Aucune troisième formule ne doit être créée sous un autre nom. La règle de durée annuelle est transversale à toutes les solutions du portefeuille, conformément à la décision FAM-020 du registre central.

## 17.7. Sécurité, audit et observabilité

- cloisonnement strict entre organisations ;
- séparation des établissements ;
- contrôles serveur et RLS ;
- stockage sécurisé ;
- aucun secret dans l’application cliente ;
- journal d’audit ;
- sauvegardes et tests de restauration ;
- surveillance des erreurs et synchronisations ;
- suivi des paiements et des webhooks ;
- gestion de versions ;
- export et traçabilité.

---

## 17.8. Parrainage des abonnés professionnels — modèle NAXA Services [V]
Ce module est distinct du parrainage consommateur de la section 3.6. Le promoteur professionnel accède à Profil → Parrainage et suivi de mes gains, génère un code unique et le partage. Un filleul organisation ne peut rattacher qu'un seul code, une fois; auto-parrainage interdit. Seul le premier abonnement réellement payé et confirmé par le serveur qualifie le filleul; ni essai, ni inscription, ni renouvellement, ni pending. Chaque vague de cinq filleuls distincts qualifiés donne un cycle mensuel gratuit au parrain mensuel ou un mois d'accès supplémentaire à l'échéance au parrain annuel. Le registre est idempotent par événement et abonnement, la cadence réelle est lue côté serveur; la récompense reste en attente tant que l'entitlement n'est pas appliqué et confirmé. Aucun paiement fictif, aucun code secret opérateur ni accès client aux événements serveur. Les récompenses sont distinctes des forfaits commerciaux interdits 3/6 mois. Ne pas inventer plafond, commission monétaire ni valeur de récompense consommateur. Source : https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/work/naxa-services-completion-20261120/supabase/functions/naxa-services-referrals/README.md

# 18. Tableau de bord et performances 360°

## 18.1. Vue promoteur

- chiffre d’affaires du jour, semaine, mois et année ;
- marge brute et résultat selon les données disponibles ;
- ventes par établissement ;
- ventes par espace ;
- ventes par canal ;
- panier moyen ;
- commandes en cours ;
- délais estimés et réels ;
- retards ;
- occupation des tables ;
- consommation et état des stocks ;
- ruptures et péremptions ;
- achats et dettes fournisseurs ;
- dépenses ;
- trésorerie ;
- écarts de caisse ;
- retours clients ;
- notation par poste ;
- incidents ;
- performances du personnel ;
- parrainages saisis et qualifiés ;
- conversion des filleuls en clients payants ;
- récompenses de fidélité/parrainage à attribuer, attribuées et utilisées ;
- coût des avantages et comparaison par établissement.

## 18.2. Vue gérant

- commandes du service ;
- postes de préparation ;
- état de la salle ;
- réservations ;
- retards ;
- disponibilité ;
- stocks critiques ;
- dépenses en attente ;
- caisse ;
- feedbacks récents ;
- tâches et validations.

## 18.3. Vue cuisine et Bar

- file de préparation ;
- priorités ;
- temps restant ;
- commandes en retard ;
- disponibilité des articles ;
- stock des matières et préparations ;
- pertes ;
- rendement ;
- feedbacks du poste.

## 18.4. Vue caisse

- ventes ;
- paiements ;
- factures ;
- tickets ;
- remboursements autorisés ;
- fonds ;
- mouvements ;
- clôture ;
- écarts.

## 18.5. Vue multi-sites

Comparaisons :
- établissement contre établissement ;
- Restaurant contre Snack-Bar ;
- cuisine contre Bar ;
- produits et catégories ;
- chiffre d’affaires ;
- marge ;
- délai ;
- satisfaction ;
- coût matière ;
- pertes ;
- performance par poste.

Les indicateurs doivent toujours afficher leur période, leur périmètre et leur source. Un indicateur non disponible ne doit pas être remplacé par une estimation présentée comme un chiffre réel.

---

# 19. Données, sécurité et règles de gestion

## 19.1. Entités fonctionnelles principales

Le modèle doit notamment couvrir :
- organisations ;
- entités juridiques ;
- établissements ;
- espaces ;
- zones ;
- tables ;
- sessions de table ;
- QR Codes et jetons publics ;
- utilisateurs professionnels ;
- rôles et permissions ;
- affectations et postes ;
- produits et catégories ;
- variantes et suppléments ;
- menus et formules ;
- recettes et versions ;
- ingrédients et unités ;
- stocks, lots et magasins ;
- préparations et productions ;
- fournisseurs ;
- commandes d’achat et réceptions ;
- fiches clients et préférences facultatives ;
- commandes clients invité ;
- codes et QR de parrainage ;
- rattachements parrain/filleul ;
- comptes, mouvements et récompenses de fidélité ;
- lignes de commande ;
- routage et tickets de préparation ;
- événements de service ;
- livraisons et livreurs ;
- paiements et remboursements ;
- caisses et clôtures ;
- dépenses ;
- écritures et journaux ;
- feedbacks et notes par poste ;
- sessions vidéos autorisées ;
- tickets support et conversations ;
- abonnements et droits ;
- notifications ;
- journal d’audit.

Cette liste est un inventaire fonctionnel, pas un schéma SQL définitif. Les tables existantes du backend partagé doivent être auditées avant toute migration.

## 19.2. Isolation

Les données doivent être isolées par organisation puis par établissement. Un employé d’un site ne peut pas lire les données d’un autre site sans délégation explicite.

Les pages publiques ne disposent que d’un accès limité :
- catalogue public ;
- disponibilité ;
- données de l’établissement destinées à l’affichage ;
- session de table ou commande détenue par le jeton ;
- statut de la commande concernée.

Elles ne peuvent lire aucune donnée interne, aucun autre panier, aucune caisse, aucun stock détaillé, aucun personnel ou aucune vidéo.

## 19.3. Journal d’audit

Les opérations importantes conservent :
- qui ;
- quand ;
- sur quel établissement ;
- action ;
- état avant ;
- état après ;
- justification ;
- validateur ;
- référence de l’objet.

Les journaux ne doivent pas être supprimés par les utilisateurs métier.

## 19.4. Confidentialité

- minimisation des données client ;
- aucune identité client obligatoire à table ;
- géolocalisation uniquement à la demande pour la livraison ;
- conservation limitée des informations de livraison ;
- accès restreint aux feedbacks ;
- vidéos accessibles uniquement aux rôles autorisés ;
- politique de confidentialité et information des personnes ;
- durée de conservation paramétrée selon les obligations applicables.

---

# 20. Charte graphique et ergonomie

La charte graphique du cahier ZIPPLE initial est conservée. [V]

**Couleurs de référence :**
- bleu nuit : **#0E224D** ;
- orange : **#F56202**.

Ces couleurs sont la base de l’identité ZIPPLE. Elles ne doivent pas être remplacées par la charte d’une autre solution de la Famille NAXA.

Principes d’interface :
- cohérence avec le logo ZIPPLE du premier cahier ;
- français et anglais ;
- mobile-first ;
- écrans lisibles sur téléphones d’entrée de gamme ;
- gros boutons ;
- navigation courte ;
- états associés à une icône et un libellé ;
- contraste du texte d’au moins 4,5:1 ;
- thème clair et mode sombre selon les réglages ;
- interfaces adaptées au plein soleil dans les espaces de travail ;
- pages QR simples, rapides et à faible consommation de données ;
- tableaux de bord denses mais lisibles sur Web.

Les composants partagés peuvent être réutilisés après vérification qu’ils ne changent pas l’identité visuelle de ZIPPLE.

---

# 21. Offres commerciales et audit des prix

## 21.1. Architecture tarifaire actuelle

Seules deux offres sont retenues :
1. **Accès**
2. **Premium**

Aucun pack Basic, Essentiel, Pro, Réseau ou troisième niveau ne doit être présenté comme une offre ZIPPLE actuelle. [V]

Les seules périodicités de souscription sont **mensuelle** et **annuelle**. Cette règle applique la décision transversale FAM-020 : aucune formule de 3 mois ou de 6 mois, aucun forfait prépayé de ces durées et aucune promotion ne doit accorder 3 ou 6 mois d'accès. [V]

Les fonctionnalités et limites précises de chaque offre doivent être pilotées par des droits configurables. La matrice Accès/Premium ne doit pas être inventée par l’équipe technique. Elle doit être fondée sur une décision commerciale explicite, notamment pour :
- nombre d’établissements ;
- utilisateurs et appareils simultanés ;
- accès multi-sites ;
- IA avancée ;
- vidéosurveillance ;
- rapports avancés ;
- options et volumes.

Les fonctions nécessaires à l’intégrité des ventes, des stocks, des paiements et de la comptabilité ne doivent pas être désactivées au point de rendre l’offre Accès dangereuse ou incohérente.

## 21.2. Audit des montants historiques et arbitrage tarifaire final

| Source / décision | Grille ou tarif | Statut |
|---|---|---|
| Cahier ZIPPLE V1.0, 31 octobre 2026 | Essentiel 1 000 F/mois ; Pro 3 000 F/mois ; Réseau 6 000 F/mois | Ancienne proposition [P], retirée |
| Document maître portefeuille V1.4, 8 novembre 2026 | Basic 5 000 F/mois et 50 000 F/an ; Premium 15 000 F/mois et 150 000 F/an ; Pro 18 000 F/mois et 180 000 F/an | Ancienne grille à trois offres, supersédée |
| Business Model 11 Solutions, 10 novembre 2026 | Modèle Excel ZIPPLE : 5 000 / 15 000 / 18 000 F par mois | Ancienne grille de travail à harmoniser, supersédée |
| Ancien arbitrage documenté | Pro : 18 000 F/mois × 10 = 180 000 F/an | Arbitrage historique concernant l'ancien pack Pro ; ne constitue pas la règle annuelle du Premium actuel |
| **Décision explicite du promoteur, 21 novembre 2026 — tarifs mensuels** | **Accès : 5 000 FCFA/mois ; Premium : 18 000 FCFA/mois** | **[V] VALIDÉ — tarifs mensuels actuels ZIPPLE** |
| **Décision explicite du promoteur, 21 novembre 2026 — annuel** | **Accès : 50 000 FCFA/an ; Premium : 180 000 FCFA/an** (10 mensualités payées pour 12 mois d'accès) | **[V] VALIDÉ — 2 mois offerts sur l'annuel** |
| **Décision transversale FAM-020, 21 novembre 2026** | **Souscription mensuelle ou annuelle uniquement ; aucune formule de 3 ou 6 mois** | **[V] VALIDÉ — portefeuille de solutions** |

## 21.3. Tarifs et périodicités applicables

Les montants et périodes suivants sont validés :

| Offre | Paiement mensuel | Paiement annuel | Durée de service annuelle |
|---|---:|---:|---:|
| **Accès** | **5 000 FCFA** | **50 000 FCFA** | **12 mois** |
| **Premium** | **18 000 FCFA** | **180 000 FCFA** | **12 mois** |

Le tarif annuel correspond exactement à **10 mensualités payées pour 12 mois de service**. Les deux mensualités restantes sont offertes et intégrées au prix annuel : il ne s'agit pas d'un crédit de deux mois à cumuler avec d'autres promotions.

Règles obligatoires :
- Les seuls choix commerciaux de paiement sont **mensuel** et **annuel**.
- Aucun abonnement, forfait ou offre de 3 mois ou de 6 mois ne peut être proposé par ZIPPLE.
- Aucune campagne promotionnelle ne peut offrir une durée d'accès de 3 ou 6 mois, ni cumuler les avantages pour atteindre ces durées.
- Le renouvellement annuel donne droit à 12 mois de service à compter de la date de prise d'effet du renouvellement, contre le paiement de 10 mensualités.
- Aucun troisième pack ne doit être créé sous un autre nom.
- Les anciennes formules Essentiel, Basic, Pro et Réseau sont retirées des offres actuelles.
- La matrice détaillée des droits et limites Accès/Premium reste pilotée par les entitlements validés et ne doit pas être inventée par le code.
- Les valeurs des récompenses du parrainage client sont distinctes de l'abonnement ZIPPLE ; elles ne peuvent pas prolonger automatiquement la durée de l'abonnement logiciel.

**Calculs annuels validés :**
- Accès : 5 000 × 10 = **50 000 FCFA/an**, soit 10 000 FCFA d'économie par rapport à 12 mensualités.
- Premium : 18 000 × 10 = **180 000 FCFA/an**, soit 36 000 FCFA d'économie par rapport à 12 mensualités.

Cette règle applique à ZIPPLE la décision commerciale transversale FAM-020 du 21 novembre 2026, applicable à l'ensemble du portefeuille de solutions.

---

# 22. Priorités de construction

Le périmètre est gelé. Les priorités ci-dessous organisent la construction et les tests ; elles ne reportent pas la définition des fonctions essentielles.

## J0 — Fondations et organisation

- organisations, établissements et séparation des données ;
- comptes professionnels et permissions ;
- journal d’audit ;
- synchronisation et mode hors connexion ;
- abonnements Accès/Premium avec prix non présumés ;
- notifications et documents.

## J1 — Cœur opérationnel des deux espaces

- Restaurant ;
- module Bar activable ;
- Snack-Bar ;
- catalogue et disponibilité temps réel ;
- QR de table ;
- commandes invité ;
- tickets cuisine/Bar ;
- compte à rebours ;
- caisse et paiements ;
- factures ;
- service et feedback.

## J2 — Stocks, recettes et finances

- stocks et lots ;
- recettes et production ;
- achats et fournisseurs ;
- dépenses ;
- multi-caisses ;
- comptabilité ;
- marge et rentabilité.

## J3 — Multi-sites, livraison et expérience client

- compte mère ;
- transferts ;
- QR de livraison Restaurant ;
- géolocalisation ;
- zones et frais ;
- livreurs ;
- paiement via NAXA ;
- suivi de livraison ;
- support client final.

Le canal livraison reste exclu du Snack-Bar.

## J4 — Performance, vidéosurveillance et support avancé

- équipe et compétences ;
- notation par poste ;
- indicateurs multi-sites ;
- intégration NAXA Security ;
- support professionnel ;
- livechat et escalade humaine.

## J5 — ZIPPLE Intelligence

- prévisions ;
- OCR ;
- analyses de coût et de rendement ;
- anomalies ;
- feedback intelligence ;
- Business Companion ;
- briefings.

Aucun jalon ne peut être déclaré terminé sur la seule base d’un écran, d’un build ou de la présence d’un fichier. Chaque fonction doit disposer de critères de recette et de preuves d’exécution.

---

# 23. Critères de recette fonctionnelle

Recette additionnelle obligatoire du parrainage PME (17.8) : premier paiement confirmé, 4 filleuls sans récompense, 5 avec une récompense, 10 avec deux vagues, rejouer le même événement sans double crédit, rejet auto-parrainage/essai/pending/renouvellement, mois gratuit ou extension selon cadence, récompense pending avant reçu entitlement; isolation app/organisation et permissions. Recette facturation ZIPPLE : 5000/50000 et 18000/180000 FCFA, rejet de 3/6 mois côté serveur, 12 mois d'accès annuel, non-repricing des périodes payées.

La recette doit être faite sur des données de test et par établissement isolé.

## 23.1. Espaces et multi-sites

1. Créer une organisation avec plusieurs établissements.
2. Vérifier que chaque établissement possède ses stocks, caisses, achats, employés et ventes séparés.
3. Vérifier que le compte mère consolide les résultats sans modifier les opérations source.
4. Vérifier qu’un utilisateur d’un site ne consulte pas un autre site sans permission.
5. Vérifier qu’un transfert de stock produit une sortie et une entrée cohérentes, sans être compté comme une vente.

## 23.2. QR et commandes

1. Scanner le QR d’une table ouverte.
2. Consulter le menu sans compte client.
3. Commander plusieurs articles.
4. Vérifier les variantes, suppléments et formules.
5. Vérifier que la commande est rattachée à la bonne session de table.
6. Scanner le même QR après clôture et vérifier que l’ancienne session ne permet plus de commander.
7. Faire commander deux clients sur une même table et vérifier le regroupement et le cloisonnement des commandes.
8. Vérifier qu’une page publique ne peut accéder à aucune donnée interne.

## 23.3. Disponibilité et concurrence

1. Ouvrir une page client avec un produit disponible.
2. Désactiver le produit depuis la cuisine.
3. Vérifier la mise à jour de la page ouverte.
4. Tenter de commander le produit après sa désactivation.
5. Simuler deux commandes concurrentes pour la dernière portion.
6. Vérifier qu’une seule commande peut obtenir la quantité disponible.
7. Vérifier la libération des réservations après expiration ou annulation.

## 23.4. Préparation et délai

1. Envoyer une commande avec plusieurs postes.
2. Vérifier le routage des lignes.
3. Vérifier la cohérence du délai global.
4. Vérifier le même compteur côté client et établissement.
5. Marquer le service avant la fin et vérifier l’arrêt du compteur.
6. Dépasser le délai et vérifier le compteur de retard.
7. Confirmer le service et enregistrer le feedback.
8. Vérifier que l’estimation initiale, les changements et le délai réel restent historisés.

## 23.5. Bar et Snack-Bar

1. Activer le mode Restaurant-Bar.
2. Commander un plat et une boisson sur la même table.
3. Vérifier l’envoi de la boisson au poste Bar et du plat à la cuisine.
4. Vérifier les stocks par verre, bouteille, pack ou casier.
5. Vérifier le cycle des consignes et des bouteilles vides.
6. Exécuter une commande Snack-Bar au comptoir avec numéro.
7. Vérifier les formules et suppléments.
8. Vérifier qu’aucune option de livraison n’apparaît dans le Snack-Bar.

## 23.6. Livraison Restaurant

1. Vérifier que la livraison est désactivée avant configuration.
2. L’activer pour un établissement Restaurant.
3. Générer un QR de livraison.
4. Commander depuis un navigateur sans installer d’application.
5. Autoriser la géolocalisation et vérifier le point.
6. Refuser la géolocalisation et vérifier la saisie manuelle.
7. Vérifier la zone, les frais et le refus hors zone.
8. Payer via le mécanisme NAXA et vérifier la confirmation serveur.
9. Vérifier l’absence de double paiement et de double commande.
10. Attribuer un livreur, remettre la commande et clôturer la livraison.
11. Vérifier que le livreur ne voit que les missions autorisées.
12. Vérifier que le Snack-Bar ne présente aucune livraison.

## 23.7. Stocks, dépenses et comptabilité

1. Réceptionner une commande fournisseur.
2. Vérifier l’entrée en stock et le justificatif.
3. Créer une préparation par lot et contrôler son rendement.
4. Vendre une recette et contrôler la consommation exacte.
5. Enregistrer une perte et son motif.
6. Réaliser un inventaire et vérifier les écarts.
7. Enregistrer une dépense avec justificatif et validation.
8. Vérifier le rapprochement caisse, paiement, vente et écriture.
9. Vérifier la distinction achat de stock / coût des ventes.
10. Vérifier les journaux par établissement et la consolidation.

## 23.8. Performance et feedback

1. Enregistrer un avis après service.
2. Noter les postes réellement concernés.
3. Vérifier les notes et les volumes de retours par poste.
4. Vérifier qu’un avis isolé ne produit pas de classement définitif.
5. Enregistrer un feedback interne et le distinguer d’un avis client.
6. Vérifier les synthèses et filtres multi-sites.

## 23.9. Vidéosurveillance

1. Associer un établissement à une intégration NAXA Security autorisée.
2. Ouvrir un flux avec un rôle autorisé.
3. Tenter l’accès avec un rôle non autorisé.
4. Tenter l’accès depuis une autre organisation.
5. Vérifier l’expiration et la révocation du jeton ou de la session.
6. Vérifier que les pages publiques et QR clients n’exposent aucun flux.
7. Vérifier la journalisation des consultations.

## 23.10. IA et support

1. Vérifier que chaque recommandation IA expose ses données et hypothèses.
2. Vérifier qu’une suggestion de prix n’est jamais appliquée automatiquement.
3. Vérifier l’OCR avec correction humaine.
4. Vérifier que les indicateurs sans données restent non disponibles et ne sont pas inventés.
5. Ouvrir un ticket support professionnel et suivre son cycle.
6. Tester le livechat automatisé puis le transfert humain.
7. Ouvrir une assistance publique liée à une commande sans compte client.
8. Vérifier la séparation stricte des conversations professionnelles et clientes.

---

## 23.11. Fidélité et parrainage client

1. Créer une fiche client sans créer de compte de connexion.
2. Générer un code et un QR de parrainage uniques sans exposer de donnée personnelle dans le QR.
3. Passer une commande anonyme et vérifier qu'elle reste possible sans fiche client.
4. Saisir un code de parrainage sur la page publique ou le rattacher par un employé avant validation de la première commande.
5. Vérifier qu'un seul parrain peut être associé à un nouveau client dans une même organisation.
6. Vérifier qu'une commande annulée, impayée ou remboursée intégralement ne qualifie pas le parrainage.
7. Régler et terminer la première commande, puis vérifier l'unique qualification du parrainage et l'inscription de la récompense dans le registre.
8. Tenter l'auto-parrainage et un doublon de filleul ; vérifier le blocage ou la revue anti-fraude.
9. Vérifier l'historique du code, du rattachement, de la commande déclencheuse, de la récompense et de son utilisation.
10. Vérifier les indicateurs parrainage dans le tableau de bord promoteur et par établissement.
11. Vérifier que la politique de récompense n'ouvre aucun compte client et n'accorde pas de mois supplémentaires d'abonnement logiciel.

---

# 24. Décisions consolidées et sujets non bloquants

## 24.1. Décisions validées [V]

- Un ERP ZIPPLE pour les restaurants et bars.
- Deux espaces seulement : Restaurant et Snack-Bar.
- Restaurant-Bar comme option du Restaurant.
- Snack-Bar spécialisé comptoir, menus rapides et retrait, sans livraison.
- Aucun compte client ZIPPLE.
- QR Code unique par table et page publique de commande.
- Menu dynamique et disponibilité mise à jour en temps réel par l’équipe.
- Vérification de disponibilité à la soumission.
- Facture/récapitulatif visible après commande.
- Compte à rebours synchronisé client/restaurant.
- Confirmation du service anticipé par le client.
- En cas de retard, mesure du dépassement et proposition de feedback.
- Livraison Restaurant sans application cliente, via QR de zone, géolocalisation et paiement NAXA.
- Vidéosurveillance en direct via NAXA Security.
- Architecture multi-établissements avec séparation et consolidation.
- Stocks, achats, dépenses, comptabilité et performances.
- Notation par poste à partir du feedback terrain.
- Réutilisation des modules IA et transversaux de la Famille NAXA après contrôle de compatibilité.
- Support et livechat.
- Charte bleue nuit #0E224D et orange #F56202.
- Deux offres : Accès et Premium.
- Abonnements mensuels ou annuels uniquement ; annuel = 10 mensualités payées pour 12 mois de service ; aucune formule de 3 ou 6 mois, conformément à FAM-020.
- Fidélité et parrainage client inspirés du modèle NAXA Services, sans compte client ZIPPLE.

## 24.2. Points techniques à vérifier sans rouvrir la vision

Réutilisation des modules NAXA, NAXA Services, JOBLY et Famille NAXA validée par le promoteur le 26/11/2026, conditionnée aux preuves techniques; références et matrice dans `docs/apps/zipple/AUDIT_N0_ZIPPLE.md` et `MATRICE_N0_ZIPPLE.md`. Accès mono-compte, Premium inclut Accès et architecture multiniveau selon règle portefeuille; répartition détaillée et quotas restent à arbitrer, sans invention. Intégration GRILLAD Connect conditionnée aux droits et accords réciproques, commandes/paiements séparés et résolution du blocage GRILLAD V1.3. Interaction NAXA HOTEL conformément à FAM-023, folio sur validation seulement.

- contrat courant du paiement NAXA et opérations supportées ;
- contrat courant de livraison NAXA et possibilité de réutilisation ;
- interface sécurisée entre ZIPPLE et NAXA Security ;
- compatibilité des équipements vidéo du client ;
- droits de consultation vidéo et conservation ;
- limites de capacité et droits des offres Accès/Premium ;
- règles fiscales et comptables locales ;
- politique de conservation des données de livraison et de feedback.

Ces contrôles ne constituent pas des alternatives au périmètre retenu. Ils sont des conditions de réalisation sûre et de recette.

## 24.3. Prix

[26/11/2026] La politique ZIPPLE canonique est décrite dans `docs/apps/zipple/POLITIQUE_COMMERCIALE_ZIPPLE.json`. Les anciens tarifs de lancement/maturité présents dans le code partagé ne doivent pas être appliqués à ZIPPLE en contradiction avec ce cahier. Aucun changement automatique des montants ZIPPLE sans décision explicite. Les règles des autres produits restent hors de cette modification.


Les tarifs mensuels et annuels sont validés : Accès à 5 000 FCFA/mois ou 50 000 FCFA/an ; Premium à 18 000 FCFA/mois ou 180 000 FCFA/an. Le paiement annuel correspond à 10 mensualités pour 12 mois de service, donc 2 mois offerts. Les seules périodicités sont mensuelle et annuelle ; aucune formule de 3 ou 6 mois n'est autorisée. La matrice précise des droits reste pilotée par les entitlements validés.

---

# 25. Règle de gel et gouvernance du document

Cette V2.0, révisée le 21 novembre 2026 pour intégrer la politique annuelle transversale et le parrainage client, constitue la référence fonctionnelle ZIPPLE gelée. Toute évolution ultérieure doit faire l'objet d'une nouvelle décision tracée et d'une nouvelle révision documentaire.

- Les décisions [V] ne doivent pas être remplacées par une ancienne proposition.
- Les anciennes grilles tarifaires à trois niveaux ne sont plus les offres actuelles.
- Les règles [P] ne deviennent pas des arbitrages commerciaux.
- Les points [O] doivent rester visibles jusqu’à validation ou preuve. Les tarifs mensuels et annuels sont arbitrés ; le barème chiffré et la nature définitive des récompenses de parrainage client restent à paramétrer avant activation commerciale.
- Toute modification de périmètre doit être enregistrée avec date, auteur, valeur précédente, valeur nouvelle, motif et validation du promoteur.
- Les changements techniques doivent respecter les règles du monorepo Famille NAXA : audit, contradiction, cause racine, correction, tests/preuves, documentation et état.
- Aucun déploiement, aucune migration Production et aucune publication APK ne sont autorisés par le seul fait de ce cahier des charges.

**Conclusion : ZIPPLE = un ERP, deux espaces métier, un module Bar activable dans Restaurant, une page publique de commande sans compte client, une chaîne opérationnelle reliée aux stocks et aux finances, une livraison limitée au Restaurant, une intégration NAXA Security, un pilotage multi-sites, une fidélité avec parrainage client sans compte applicatif et deux offres uniquement : Accès et Premium, payables au mois ou à l'année (10 mois payés pour 12 mois de service).**
