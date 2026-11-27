# BOOTIK — Audit des fonctions transversales Détaillants / Distributeurs
Référence : V1.1 et audit des 6 BULK, HEAD 32cad945, run 45891154929 5/5. Statuts : construit = code, candidat = nouvelle construction à qualifier, partiel = périmètre incomplet, non attesté = absence de preuve suffisante. Aucun vert global déclaré.
| Famille | Détaillants | Distributeurs | Reste |
|---|---|---|---|
| Identité et droits | construit | construit | central hébergé, preuve opérateur, droits terrain |
| Catalogue, unités, lots | partiel | partiel | XLSX, variantes, sérialisation, verticales |
| Stocks, inventaires, transferts | partiel | partiel | WMS, réservations, quarantaine, scan caméra, litiges |
| Achats, réception, dette | partiel | partiel | multi-lignes, avances, avoirs, cotation et échéances |
| Ventes et caisse | partiel | non attesté pour vente B2B | crédit, mixte, retours, unification offline, factures |
| CRM et tiers | candidat agenda | candidat agenda | consentement, segmentation, opportunités, fidélité, relances externes |
| Réapprovisionnement | candidat indicatif | candidat indicatif | délais, transit, saison, seuils automatiques, validation bilatérale |
| Finance et pilotage | candidat indicateurs | candidat indicateurs | journal, CA/encaissé, charges, recouvrement, rapprochement, fiscalité |
| RH et objectifs | partiel droits | partiel droits | pointage, commissions, salaires, objectifs |
| Livraison et réseau B2B | non attesté | non attesté | flotte, WMS, livraison, portail, devis B2B, contrats |
| IA et intégrations | partiel | partiel | IA, FCM, sécurité, support RTC, exports, restauration |
Les nouveaux parcours sont communs mais cloisonnés par activité, site, organisation et formule. Agenda interne, aucune transmission automatique. Pas de comptabilité certifiée. Aucun changement des autres solutions, main ou hébergement. Le statut final dépend des recettes et du HEAD exact.
## Extension achats commune
Candidat multi-articles : création atomique 2–20 lignes, en-tête immuable et montants agrégés, réutilisation de la réception et du règlement par ligne. Les tests API et navigateur sont inscrits dans la recette. Ce lot n'est pas une preuve de réception groupée, cotation, avoir, avance, ni WMS complet.
