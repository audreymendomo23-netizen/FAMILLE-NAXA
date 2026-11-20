# naxa-services-auth — source non déployée

Cette fonction est préparatoire et ne doit pas être déployée avant :
1. la preuve locale de l'alias technique dans la version GoTrue ciblée ;
2. la révision de supabase/drafts/naxa_services_v1.sql ;
3. les tests RLS/rate limit/session et l'approbation d'un déploiement distincte.

Secrets requis côté Edge Function uniquement : SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY. Aucune clé service_role dans Android/Web.

Actions codées : login, refresh, request_recovery, change_password, logout.
La création initiale des comptes, l'approbation de récupération, le reset Admin et la révocation par appareil perdu nécessitent encore un workflow support/Admin dédié et audité. Les alias Auth existants doivent être fournis par provisioning serveur ; leur génération n'est pas verrouillée dans ce code.
