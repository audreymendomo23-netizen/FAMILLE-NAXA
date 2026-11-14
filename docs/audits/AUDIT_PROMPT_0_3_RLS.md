# AUDIT — PROMPT 0.3 — RLS

Date : 14 novembre 2026. Dépôt FAMILLE-NAXA, main.

Livré : migration candidate 0002, helpers, policies du socle, GRANT minimaux, action paiement idempotente, tests locaux, FR/EN et passation reconstituée.

Tests écrits : compte mère voit deux lieux ; gérant voit son lieu et pas un autre propriétaire ; autre propriétaire isolé ; admin zéro détail mais agrégat/abonnements ; commercial/partenaire zéro transaction ; abonnement au-delà de grace_until bloque lecture/écriture ; paiement reste accessible ; payment_matches non lisible.

Limites : psql/createdb/dropdb, Docker/Podman absents ; tests non exécutés ; fixture de test et non vraies tables métier ; tables transactionnelles et vues agrégées réelles des dix apps à raccorder ; durée de grâce fournie par facturation ; aucune CI lancée, aucun SQL appliqué à Replay/Production.

Décision : Prompt 0.3 préparé, VERT technique non acquis.
