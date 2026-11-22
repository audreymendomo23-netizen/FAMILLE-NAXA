# BOOTIK — état d'implantation, tranche 1

> Date : 22 novembre 2026  
> Branche : `feat/bootik-retail-foundation-2026-11-22`  
> Base documentaire : BOOTIK V1.1  
> Statut : **premier socle local préparé ; tests et backend non qualifiés**.

## 1. Livré dans cette tranche

- Shell Android BOOTIK autonome dans `apps/android/bootik`, package `cm.naxa.bootik`.
- Identifiants stables pour les 14 profils Détaillants et les 8 profils Distributeurs réservés à la phase suivante.
- Premier écran Détaillants : nom d'organisation, premier site et sélection du profil métier.
- Persistance locale Room dans `bootik-local.db`, avec tables `bk_workspace_drafts`, `bk_activity_drafts`, `bk_site_drafts`, `bk_site_activity_drafts`.
- Outbox locale BOOTIK distincte `bk_offline_events`.
- Charte BOOTIK bleu nuit `#052163` et orange `#FC7820`.
- Ressources FR/EN et tests de catalogue/contrat d'approbation humaine.
- Draft serveur `supabase/drafts/bootik_v1.sql` avec schéma `bootik`, objets `bk_*`, modèle catalogue/stock/emplacements, compatibilité de profils, liens B2B et commandes avec validations humaines.
- Contrat de recette RLS anti-collision et audit des frontières NAXA SERVICES / NAXA Pharmacie.

## 2. Séparation confirmée

- Aucun fichier `apps/android/naxa-services/**` n'est modifié.
- Aucun draft, Edge Function ou table `ns_*` NAXA SERVICES n'est modifié.
- Aucun fichier du projet NAXA indépendant/pharmacie, aucune table pharmacie ou rôle pharmacie n'est importé.
- BOOTIK utilise son namespace, sa base locale et son schéma propres.
- Aucun package partagé métier nouveau n'est ajouté.
- Le registre commun Famille Core n'est qu'une dépendance de conception côté serveur ; son état candidat/non déployé est respecté.

## 3. Limites de cette tranche

Les brouillons enregistrés dans l'application restent locaux et non synchronisés. Ils ne créent pas de compte serveur, abonnement, client, organisation ou site en production. Le backend n'a pas été raccordé. Le draft SQL n'a été appliqué nulle part et ne contient volontairement aucune policy/grant client.

La caisse, les ventes, les achats, l'import Excel, le CRM détaillant, les commandes fournisseur WhatsApp, les paiements, les rapports et les modules verticaux ne sont pas déclarés livrés. Ils restent dans le périmètre V1.1 et seront implémentés par lots, sans réduction.

## 4. Preuves et état des tests

Les fichiers de tests JUnit et Compose sont présents dans la branche, mais **aucune exécution Gradle/Kotlin, instrumentation Android ou PostgreSQL 17 n'est revendiquée ici**. L'environnement disponible dans cette passe ne disposait pas de `psql`, Docker ou Gradle local pour les exécuter directement.

Le draft SQL et les contrats RLS doivent être relus puis exécutés sur PostgreSQL isolé, jamais sur Replay ou Production à ce stade. Aucune CI n'a été déclenchée ; la branche de travail n'est pas `main`.

## 5. Prochaine tranche recommandée

1. Obtenir une compilation locale démontrée de `:bootik:assembleDebug` et exécuter les tests JUnit/Compose.
2. Corriger toute erreur de compilation/test sans toucher aux autres applications.
3. Valider le schéma draft et les tests RLS sur une base PostgreSQL éphémère ; aucun grant utilisateur tant que la matrice n'est pas verte.
4. Construire le catalogue Détaillant, ses fiches Excel contrôlées, unités/conversions, lots et emplacements.
5. Ajouter ensuite les mouvements d'inventaire, puis la caisse/ventes, CRM, fournisseurs et dépenses.

**Règle de reprise :** poursuivre sur cette branche ; comparer avant toute modification ; limiter les changements à `apps/android/bootik/**`, `supabase/drafts/bootik_*`, `supabase/tests/drafts/bootik_*` et aux documents BOOTIK. Toute opération sur NAXA SERVICES ou NAXA indépendant est hors périmètre.
