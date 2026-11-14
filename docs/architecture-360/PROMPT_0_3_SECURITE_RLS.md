# PROMPT 0.3 — Sécurité des données et règles RLS

Source : `Projet.zip` → `Nouveau projet/Prompt/Prompts_00_Socle_commun.pdf`, page 6. Le texte historique vise 7 apps Android ; le périmètre actuel prévaut : 10 applications, chacune Android native + Web responsive/PWA.

Mission : point de vente limité à ses lignes ; compte mère à tous ses points ; gérant à ses lieux assignés et jamais à un autre propriétaire ; admin voit abonnements/agrégats mais aucune transaction détaillée ; commercial/partenaire sans transaction ; blocage métier au-delà de la tolérance ; paiement et « J'ai payé » accessibles ; helpers `is_admin()`, `outlet_ids()` et tests SQL locaux.

Sémantique : `locations.id` est le point ; `owner` = portée organisation sans lieu ; `manager` = portée lieu ; `platform_admin` exclu des détails ; capacités inconnues refusées ; `grace_until` est fourni par le workflow de facturation, sans inventer une durée ; `submit_payment_intent()` passe à submitted, jamais confirmed ; `payment_matches` non lisible par les clients.

Livrables : migration candidate 0002, bootstrap/test PostgreSQL local, runner local, textes FR/EN et passation.

Limites : passation formelle 0.2 absente, reconstituée ; PostgreSQL/psql et Docker/Podman absents ici, tests écrits non exécutés ; tables métier et agrégats réels des dix apps à raccorder ; aucune CI, migration Supabase, exposition Data API ou déploiement. VERT technique non acquis.
