# COTIZ

Application autonome du monorepo Famille NAXA.

## Référence fonctionnelle
- Cahier des charges : [COTIZ 360° V2.1](../../docs/cahiers-des-charges/COTIZ_360_V2_1.md)
- Audit contradictoire : [COTIZ 360° V2.1](../../docs/audits/COTIZ_AUDIT_CONTRADICTIONS_V2_1.md)

## État
Cet emplacement ne contient pas encore l'implémentation métier COTIZ. Les documents ci-dessus constituent la baseline fonctionnelle de référence. Ne pas considérer les fonctions décrites comme développées, testées ou déployées.

## Contraintes de dépôt
- Android natif Kotlin / Jetpack Compose.
- Web/PWA séparée ; pas de WebView enveloppant le site.
- Réutilisation du socle Supabase NAXA uniquement après audit de compatibilité et d'isolation.
- Aucune donnée personnelle réelle, aucun secret ou jeton dans le dépôt.
- Aucune migration Production, aucun déploiement ni publication APK sans autorisation explicite distincte.
