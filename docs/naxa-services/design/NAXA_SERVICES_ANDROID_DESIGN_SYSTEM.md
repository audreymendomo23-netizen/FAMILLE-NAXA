# NAXA SERVICES — Android design system and experience specification
**Implementation target: Android native Kotlin / Jetpack Compose**

## Brand and visual direction
- Brand: NAXA SERVICES.
- Direction: B — premium dark by default.
- Brand red: #DD3A33; background #111111; dark surface #1E1E1E; white #FFFFFF; light background #FDECEA.
- Semantic colors: success #197A33, alert #C62828, warning #8F5400; always pair icon + label.
- Cards 18–26 dp radius; fields 16 dp; primary actions 48–54 dp high; spacing scale 4/8/12/16/24/32 dp.
- Typography scale 11/13/15/17/22/32 sp; text contrast at least 4.5:1; support 130% font scaling; no text baked into images.
- Animations: touch response 160 ms, state 250 ms, sheets/cards 300 ms; respect system reduce-motion and use low-cost opacity/translation on entry-level Android devices.
- Night is the default. Light theme is optional. Programmed night start/end belongs to user preferences and is recalculated on app resume.
- Mini-torch is an original UI illustration; it must never activate camera flash or request camera permissions. Red NAXA handle; soft radial light follows user interaction, fades when idle, pauses in background, and can be disabled independently.
- Image library: assets/naxa-services/activities/<activity>/; 6–10 user-provided approved photos per activity; readable dark overlay; fallback gradient/icon if photos are not yet supplied.

## First-use journey
1. FR/EN choice on the login start page.
2. Authentication and mandatory temporary password change if applicable.
3. Terms and Privacy accepted separately, each with versioned server audit.
4. Organization promoter chooses one primary activity. The activity profile drives business modules; the organization mode is selected separately.
5. Four discovery cards, five-second autoplay, manual navigation and skip.
6. First session tour (max 5 steps), role-aware and skippable; marked completed server-side; can be replayed from Help later.

## Activity profiles
Supported IDs: pressing, coiffure, couture, beaute, parfumerie, reparation, menuiserie, garage, nettoyage, domicile, impression, photo_evenementiel, autre. See NaxaServicesPreferences.kt.

## Organisation hierarchy
- Solo: one site and its workstations, local books and cash stay at that site.
- Multi-workstation single site: one shared site ledger by default; workstations have schedules/resources/analytics, no duplicate cashbook.
- Multi-site network: site books remain autonomous; promoter sees permitted consolidated read-only summaries and allowed site details. Transfers are explicit, justified and audited.
- Workstation-only permissions must not be widened to site permissions. Do not expose that role for transaction screens until every read and mutation enforces workstation scope.

## Dashboard
- Time-based Bonjour/Bonsoir + authenticated display name and locale.
- Horizontal hero carousel advances every 5 seconds, pauses on interaction and shows key KPI cards. Image backgrounds come from the selected activity folder; text overlay remains contrast-safe.
- Every KPI has source, period and freshness (local/synced) indicator; never call local unsynced data a live consolidated result.

## Operational truth labels
Local-only drafts must be labelled local / waiting to sync. Server-confirmed records must show server confirmation. Payment declared is not payment confirmed. Tax estimate is not a filing or tax advice. AI suggestion is not an approved accounting entry.
