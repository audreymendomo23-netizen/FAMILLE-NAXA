package cm.naxa.naxaservices

import android.os.Bundle
import android.content.res.Configuration
import org.json.JSONObject

import androidx.compose.runtime.collectAsState
import cm.naxa.naxaservices.data.NaxaServicesLocalRepository
import cm.naxa.naxaservices.data.LocalPressingOrder
import cm.naxa.naxaservices.data.LocalPressingStatusEvent
import cm.naxa.naxaservices.data.LocalAppointment
import cm.naxa.naxaservices.data.LocalCashSession
import cm.naxa.naxaservices.data.LocalSale
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.produceState
import cm.naxa.naxaservices.data.SecureLocalDatabase
import cm.naxa.naxaservices.data.NsServicesDatabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.changedToDown
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.Image
import cm.naxa.naxaservices.auth.AuthApi
import cm.naxa.naxaservices.auth.AuthApiException
import cm.naxa.naxaservices.auth.AuthSession
import cm.naxa.naxaservices.auth.ProvisionedAccess
import cm.naxa.naxaservices.auth.ProvisionScope
import cm.naxa.naxaservices.auth.RecoveryRequestItem
import cm.naxa.naxaservices.auth.RecoveryReset
import cm.naxa.naxaservices.auth.SessionVault
import cm.naxa.naxaservices.auth.RememberedSessionChanged
import cm.naxa.naxaservices.auth.discardRememberedSession
import cm.naxa.naxaservices.auth.isTemporarySessionFailure
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import androidx.compose.runtime.key
import java.util.Calendar
import cm.naxa.core.notifications.NotificationChannels
import cm.naxa.core.notifications.BriefingScheduler

class MainActivity : ComponentActivity() {
    private val lockGeneration = MutableStateFlow(0)
    private val notificationOpenSignal = MutableStateFlow(0)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { NaxaServicesTheme { NaxaServicesRoot(lockGeneration, notificationOpenSignal) } }
        consumeNotificationIntent(intent)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeNotificationIntent(intent)
    }

    private fun consumeNotificationIntent(source: android.content.Intent?) {
        val notificationId = source?.getStringExtra("naxa_notification_id")
        if (!notificationId.isNullOrBlank()) {
            notificationOpenSignal.value = notificationOpenSignal.value + 1
            source.removeExtra("naxa_notification_id")
            source.removeExtra("naxa_notification_route")
        }
    }

    override fun onStop() {
        super.onStop()
        lockGeneration.value = lockGeneration.value + 1
    }
}

internal enum class AppRoute {
    LOGIN, RECOVERY, CHANGE_PASSWORD, ACTIVITY_SETUP, LEGAL_ACCEPTANCE, DISCOVERY,
    DASHBOARD, AGENDA, PRESSING, WORK_ORDERS, CASH, SERVICES, CUSTOMERS, CUSTOMER_PROMOTIONS, NOTIFICATIONS, TEAM, STOCK, REPORTS,
    ORGANIZATION, NETWORK, SITES, WORKSTATIONS, SECURITY, SETTINGS, HELP, MENU,
    PROFILE, APPEARANCE, BILLING, SUBSCRIPTIONS, PURCHASES, TAXES, CHARGES, OBJECTIVES, TEAM_PERFORMANCE,
    AI_INSIGHTS, LIVECHAT
}

private val offlineLocalRoutes = setOf(AppRoute.DASHBOARD,AppRoute.MENU,AppRoute.AGENDA,AppRoute.PRESSING,AppRoute.WORK_ORDERS,AppRoute.CASH,AppRoute.SERVICES,AppRoute.CUSTOMERS,AppRoute.STOCK,AppRoute.REPORTS,AppRoute.PURCHASES,AppRoute.CHARGES,AppRoute.OBJECTIVES)

private const val TERMS_VERSION = "2026-11-v1"
private const val PRIVACY_VERSION = "2026-11-v1"

@Composable
private fun NaxaServicesRoot(
    lockGeneration: StateFlow<Int>,
    notificationOpenSignal: StateFlow<Int>
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val api = remember { AuthApi(context) }
    val vault = remember { SessionVault(context) }
    val preferences = remember { NaxaServicesPreferences(context) }
    val localPinManager = remember(context) { LocalAccessPinManager(context) }
    val lockGenerationValue by lockGeneration.collectAsState()
    var databaseRetry by remember { mutableIntStateOf(0) }
    val databaseResult by produceState<Result<NsServicesDatabase>?>(null, databaseRetry) {
        value = null
        value = withContext(Dispatchers.IO) {
            try { Result.success(SecureLocalDatabase.open(context)) }
            catch (c: CancellationException) { throw c }
            catch (failure: Exception) { Result.failure(failure) }
        }
    }
    val localDatabase = databaseResult?.getOrNull()
    if (localDatabase == null) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            if (databaseResult == null) CircularProgressIndicator()
            else Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(24.dp)) {
                Text(localizedLabel("Données locales indisponibles. Aucune donnée effacée automatiquement.", "Local data unavailable. No data automatically erased.", "Keɓe nokkuure heɓotaako. Keɓe momtaaka."))
                Button(onClick = { databaseRetry++ }) { Text(localizedLabel("Réessayer", "Retry", "Fuɗɗito")) }
            }
        }
        return
    }
    DisposableEffect(localDatabase) { onDispose { localDatabase.close() } }
    val localRepository = remember(localDatabase) { NaxaServicesLocalRepository(localDatabase) }
    val scope = rememberCoroutineScope()

    var route by rememberSaveable { mutableStateOf(AppRoute.LOGIN.name) }
    var session by remember { mutableStateOf<AuthSession?>(null) }
    var offlineRestored by remember { mutableStateOf(false) }
    val notificationOpenRequest by notificationOpenSignal.collectAsState()
    val pushRegistration by PushTokenRegistry.state.collectAsState()

    LaunchedEffect(notificationOpenRequest, session?.account?.memberId) {
        if (notificationOpenRequest > 0 && session != null) {
            route = AppRoute.NOTIFICATIONS.name
        }
    }

    LaunchedEffect(Unit) {
        PushTokenRegistry.initialize(context)
    }
    LaunchedEffect(
        lockGenerationValue,
        pushRegistration.enabled,
        pushRegistration.token,
        pushRegistration.retryNonce,
        session?.accessToken,
        session?.account?.memberId,
        offlineRestored
    ) {
        val activeSession = session
        if (!pushRegistration.enabled || activeSession == null || offlineRestored) return@LaunchedEffect
        if (
            android.os.Build.VERSION.SDK_INT >= 33 &&
            androidx.core.content.ContextCompat.checkSelfPermission(
                context, android.Manifest.permission.POST_NOTIFICATIONS
            ) != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            runCatching { api.revokeCurrentDevicePushTokens(activeSession.accessToken) }
            PushTokenRegistry.markFailed("POST_NOTIFICATIONS_PERMISSION_REQUIRED")
            return@LaunchedEffect
        }
        val token = pushRegistration.token
        if (token.isNullOrBlank()) {
            runCatching { FirebasePushClient.fetchToken(context) }
                .onSuccess { PushTokenRegistry.updateToken(context, it) }
                .onFailure { PushTokenRegistry.markFailed(it.message ?: "FCM_TOKEN_FETCH_FAILED") }
            return@LaunchedEffect
        }
        val registrationSessionKey = activeSession.account.memberId + ":" + activeSession.accessToken.hashCode()
        if (pushRegistration.registeredSessionKey == registrationSessionKey) return@LaunchedEffect
        runCatching { api.registerPushToken(activeSession.accessToken, token) }
            .onSuccess { PushTokenRegistry.markRegistered(activeSession.account.memberId, registrationSessionKey) }
            .onFailure { PushTokenRegistry.markFailed(it.message ?: "FCM_TOKEN_REGISTRATION_FAILED") }
    }
    var localPinUnlockedMemberId by remember { mutableStateOf<String?>(null) }
    var lastHandledLockGeneration by remember { mutableIntStateOf(lockGenerationValue) }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var pendingRefresh by remember { mutableStateOf<String?>(null) }
    var recoveryAttempt by remember { mutableIntStateOf(0) }
    var rememberSession by rememberSaveable { mutableStateOf(false) }
    var locale by rememberSaveable { mutableStateOf(preferences.locale()) }
    var lightTheme by rememberSaveable { mutableStateOf(preferences.isLightNow()) }
    var tourActive by rememberSaveable { mutableStateOf(false) }
    var tourStep by rememberSaveable { mutableIntStateOf(0) }
    var torchTarget by remember { mutableStateOf<Offset?>(null) }
    var nightActivation by remember { mutableStateOf(false) }
    var previousLightTheme by remember { mutableStateOf(lightTheme) }
    LaunchedEffect(lightTheme) {
        val changed = previousLightTheme != lightTheme
        previousLightTheme = lightTheme
        nightActivation = changed && !lightTheme && preferences.flashlightEnabled()
        if (nightActivation) { delay(1700L); nightActivation = false }
    }

    LaunchedEffect(lockGenerationValue) {
        if (lockGenerationValue != lastHandledLockGeneration) {
            lastHandledLockGeneration = lockGenerationValue
            localPinUnlockedMemberId = null
        }
    }

    fun routeAfterAuthentication(auth: AuthSession): String {
        locale = preferences.memberLocale(auth.account.memberId) ?: auth.account.defaultLocale
        preferences.saveLocale(locale)
        preferences.saveMemberLocale(auth.account.memberId, locale)
        val activity = auth.account.activityProfile
        if (activity.isNullOrBlank()) {
            tourActive = false
            return AppRoute.ACTIVITY_SETUP.name
        }
        preferences.saveActivity(auth.account.organizationId, activity)
        val acceptedTerms = "terms:$TERMS_VERSION" in auth.account.acceptedLegalDocs
        val acceptedPrivacy = "privacy:$PRIVACY_VERSION" in auth.account.acceptedLegalDocs
        if (!acceptedTerms || !acceptedPrivacy) {
            tourActive = false
            return AppRoute.LEGAL_ACCEPTANCE.name
        }
        if (!auth.account.discoveryCompleted) {
            tourActive = false
            return AppRoute.DISCOVERY.name
        }
        tourStep = 0
        tourActive = !auth.account.tourCompleted
        return AppRoute.DASHBOARD.name
    }

    LaunchedEffect(recoveryAttempt) {
        if(session!=null)return@LaunchedEffect
        pendingRefresh = vault.loadRefreshToken()
        val saved = pendingRefresh
        val binding=vault.binding()
        if (!saved.isNullOrBlank() && binding!=null) {
            rememberSession = true
            while (pendingRefresh == saved && session == null) {
                if (route != AppRoute.LOGIN.name || busy) { delay(15_000L); continue }
                busy = true
                try {
                    val restored = vault.refreshRemembered(binding){api.refresh(it, rememberDevice=true)}
                    if (pendingRefresh != saved || session != null || route != AppRoute.LOGIN.name) break
                    session = restored
                    pendingRefresh = null
                    message = null
                    route = if (restored.requirePasswordChange) AppRoute.CHANGE_PASSWORD.name else routeAfterAuthentication(restored)
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (failure: Exception) {
                    if (pendingRefresh != saved || session != null) break
                    if (failure is RememberedSessionChanged || discardRememberedSession((failure as? AuthApiException)?.statusCode)) {
                        pendingRefresh = null
                        rememberSession = false
                        message = "Session expirée ou révoquée. Connecte-toi à nouveau."
                    } else {
                        // A transport failure is not a revocation. Keep the encrypted token and retry.
                        message = "Connexion indisponible. Votre session mémorisée est conservée."
                        val cached=if(isTemporarySessionFailure(failure))vault.loadOfflineSnapshot() else null
                        if(cached!=null && localPinManager.isConfigured(cached.account.memberId)){
                            offlineRestored=true;session=cached;pendingRefresh=null;localPinUnlockedMemberId=null
                            route=AppRoute.DASHBOARD.name;tourActive=false
                            message="Mode hors connexion : accès local temporaire. Les opérations attendent le serveur."
                        }
                    }
                } finally { busy = false }
                if (pendingRefresh == saved) delay(15_000L)
            }
        }
    }

    LaunchedEffect(session?.deviceId, rememberSession,offlineRestored) {
        val activeSession = session
        if (
            rememberSession && !offlineRestored &&
            activeSession != null &&
            activeSession.deviceId.isNotBlank() &&
            SupplierSyncCoordinator.isConfigured()
        ) {
            NaxaServicesSyncScheduler.schedule(context)
            NaxaServicesSyncScheduler.enqueueNow(context)
        } else {
            NaxaServicesSyncScheduler.cancel(context)
        }
    }

    LaunchedEffect(Unit) {
        NotificationChannels.create(context)
        val notificationIcon = R.drawable.naxa_services_monogram
        BriefingScheduler.schedule(
            context, 7, 0,
            "NAXA SERVICES — Briefing du matin",
            "Ouvre ton tableau de bord pour consulter les opérations, rendez-vous, stocks et objectifs.",
            notificationIcon, NotificationChannels.OPERATIONS
        )
        BriefingScheduler.schedule(
            context, 19, 0,
            "NAXA SERVICES — Briefing du soir",
            "Vérifie les ventes, la caisse, les dossiers à livrer et les tâches du lendemain.",
            notificationIcon, NotificationChannels.OPERATIONS
        )
    }

    LaunchedEffect(Unit) {
        while (true) {
            lightTheme = preferences.isLightNow()
            delay(60_000L)
        }
    }

    LaunchedEffect(torchTarget) {
        if (torchTarget != null) {
            delay(1_400L)
            torchTarget = null
        }
    }

    LaunchedEffect(session?.accessToken,localPinUnlockedMemberId,rememberSession,offlineRestored) {
        val current=session?:return@LaunchedEffect
        if(offlineRestored||!rememberSession||localPinUnlockedMemberId!=current.account.memberId||!localPinManager.isConfigured(current.account.memberId))return@LaunchedEffect
        val expected=vault.binding()?:return@LaunchedEffect
        try{
            val access=api.subscriptionAccess(current.accessToken)
            if(session?.accessToken==current.accessToken&&!offlineRestored&&rememberSession)vault.saveOfflineSnapshot(current,access,expected)
        }catch(c:CancellationException){throw c}catch(_:Exception){}
    }
    LaunchedEffect(offlineRestored,session?.refreshToken) {
        while(offlineRestored&&session!=null){
            if(vault.loadOfflineSnapshot()==null){
                offlineRestored=false;session=null;localPinUnlockedMemberId=null;route=AppRoute.LOGIN.name
                message="Autorisation locale expirée. Reconnectez-vous pour reprendre."
                if(rememberSession)recoveryAttempt++
                break
            }
            delay(1000L)
        }
    }
    LaunchedEffect(session?.refreshToken,offlineRestored) {
        var activeSession = session
        val binding=if(rememberSession)vault.binding()else null
        while (activeSession != null) {
            val waitSeconds = if(offlineRestored) 15L else (activeSession.expiresIn - 60L).coerceAtLeast(30L)
            delay(waitSeconds * 1000L)
            var retry = 0
            var refreshed = false
            while (retry < 5 && !refreshed) {
                val token = activeSession?.refreshToken ?: break
                runCatching {
                    if(rememberSession){
                        val expected=binding?:throw RememberedSessionChanged()
                        if(expected.memberId!=activeSession?.account?.memberId||expected.deviceId!=activeSession?.deviceId)throw RememberedSessionChanged()
                        vault.refreshRemembered(expected){api.refresh(it,rememberDevice=true)}
                    }else api.refresh(token,rememberDevice=false)
                }
                    .onSuccess { next ->
                        if(offlineRestored){
                            localPinUnlockedMemberId=null
                            route=if(next.requirePasswordChange)AppRoute.CHANGE_PASSWORD.name else routeAfterAuthentication(next)
                            offlineRestored=false
                        }
                        session = next
                        activeSession = next
                        refreshed = true
                    }
                    .onFailure { error ->
                        val authError = error as? AuthApiException
                        if (error is CancellationException) throw error
                        if (error is RememberedSessionChanged || discardRememberedSession(authError?.statusCode)) {
                            runCatching { api.revokeCurrentDevicePushTokens(activeSession?.accessToken.orEmpty()) }
                            PushTokenRegistry.disable(context)
                            if(!rememberSession)vault.clear()
                            rememberSession = false
                            localPinUnlockedMemberId = null
                            session = null
                            offlineRestored=false
                            route = AppRoute.LOGIN.name
                            message = "Session expirée ou révoquée. Connecte-toi à nouveau."
                            activeSession = null
                        } else if(!offlineRestored) {
                            // Once renewal fails, no unbounded authenticated UI remains visible.
                            val cached=if(rememberSession && isTemporarySessionFailure(error))vault.loadOfflineSnapshot() else null
                            val previous=activeSession
                            if(cached!=null && previous!=null && cached.account.memberId==previous.account.memberId &&
                                cached.account.organizationId==previous.account.organizationId && cached.deviceId==previous.deviceId &&
                                localPinManager.isConfigured(cached.account.memberId)){
                                offlineRestored=true;session=cached;localPinUnlockedMemberId=null
                                route=AppRoute.DASHBOARD.name;tourActive=false
                                message=when(locale){"en"->"Temporary local access.";"ff-CM"->"Naatgol nokkuure sahaa seeɗa.";else->"Accès local temporaire."}
                            }else{
                                session=null;localPinUnlockedMemberId=null;route=AppRoute.LOGIN.name
                                message=when(locale){"en"->"Connection required to resume.";"ff-CM"->"Ceŋol soklaa ngam jokkude.";else->"Connexion requise pour reprendre."}
                                if(rememberSession)recoveryAttempt++
                            }
                            return@LaunchedEffect
                        }else{
                            retry += 1
                            delay(30_000L)
                        }
                    }
            }
            if (!refreshed && activeSession != null) {
                message = "La session n'a pas pu être renouvelée. Vérifie le réseau avant de continuer."
                // Stay on the original authenticated scope. Do not invent a longer session lifetime.
                delay(60_000L)
                if (session?.refreshToken != activeSession?.refreshToken) break
            }
        }
    }

    val onLogin: (String, String, Boolean) -> Unit = { identifier, password, rememberMe ->
        pendingRefresh = null
        offlineRestored=false
        // An explicit login starts a new generation, even for the same member/device.
        vault.clear()
        scope.launch {
            busy = true
            message = null
            runCatching { api.login(identifier, password, rememberMe) }
                .onSuccess { authenticated ->
                    val selectedLocale = preferences.memberLocale(authenticated.account.memberId) ?: locale
                    val withLocale = authenticated.copy(account = authenticated.account.copy(defaultLocale = selectedLocale))
                    if (preferences.memberLocale(authenticated.account.memberId) == null) {
                        runCatching { api.setMemberPreferredLocale(authenticated.accessToken, selectedLocale) }
                            .onSuccess { preferences.saveMemberLocale(authenticated.account.memberId, selectedLocale) }
                    }
                    localPinUnlockedMemberId = null
                    session = withLocale
                    rememberSession = rememberMe
                    if (rememberMe) vault.save(withLocale) else vault.clear()
                    route = if (withLocale.requirePasswordChange) AppRoute.CHANGE_PASSWORD.name else routeAfterAuthentication(withLocale)
                }
                .onFailure { message = it.message ?: "Connexion impossible." }
            busy = false
        }
    }

    val onRecovery: (String, String) -> Unit = { identifier, note ->
        scope.launch {
            busy = true
            message = null
            runCatching { api.requestRecovery(identifier, note) }
                .onSuccess { message = "Demande transmise si le compte peut être retrouvé. Le responsable effectuera le contrôle d'identité." }
                .onFailure { message = it.message ?: "Demande impossible pour le moment." }
            busy = false
        }
    }

    val onChangePassword: (String, String) -> Unit = { current, next ->
        val active = session
        if (active == null) {
            route = AppRoute.LOGIN.name
            message = "Session expirée. Connecte-toi à nouveau."
        } else {
            scope.launch {
                busy = true
                runCatching { api.changePassword(active, current, next) }
                    .onSuccess {
                        session = it
                        if (vault.loadRefreshToken() != null) vault.save(it)
                        route = routeAfterAuthentication(it)
                        message = "Mot de passe mis à jour."
                    }
                    .onFailure { message = it.message ?: "Modification impossible." }
                busy = false
            }
        }
    }

    val active = session
    val currentLocale = active?.account?.defaultLocale ?: locale
    val appConfiguration = remember(currentLocale) {
        Configuration(context.resources.configuration).apply {
            setLocale(Locale.forLanguageTag(currentLocale))
            setLayoutDirection(Locale.forLanguageTag(currentLocale))
        }
    }

    val localizedContext = remember(context, appConfiguration) { context.createConfigurationContext(appConfiguration) }
    NaxaServicesTheme(light = lightTheme) {
        CompositionLocalProvider(LocalConfiguration provides appConfiguration, androidx.compose.ui.platform.LocalContext provides localizedContext) {
            Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                Box(
                    Modifier.fillMaxSize().pointerInput(lightTheme, preferences.flashlightEnabled()) {
                        awaitPointerEventScope {
                            while (true) {
                                val event = awaitPointerEvent(PointerEventPass.Final)
                                val down = event.changes.firstOrNull { it.changedToDown() }
                                if (down != null) torchTarget = down.position
                            }
                        }
                    }
                ) {
                    when (AppRoute.valueOf(route)) {
                        AppRoute.LOGIN -> LoginScreen(
                            busy, message, locale,
                            onLogin,
                            { route = AppRoute.RECOVERY.name },
                            onLocale = { locale = it; preferences.saveLocale(it) },
                            lightTheme = lightTheme,
                            onToggleTheme = { val next = !lightTheme; preferences.saveTheme(if(next) "light" else "dark", preferences.nightStart(), preferences.nightEnd(), preferences.flashlightEnabled()); lightTheme = next }
                        )
                        AppRoute.RECOVERY -> RecoveryScreen(busy, message, onRecovery, { route = AppRoute.LOGIN.name })
                        AppRoute.CHANGE_PASSWORD -> ChangePasswordScreen(busy, message, onChangePassword)
                        AppRoute.ACTIVITY_SETUP -> {
                            val current = session
                            if (current == null) route = AppRoute.LOGIN.name
                            else ActivitySelectionScreen(
                                locale = current.account.defaultLocale,
                                initialSelection = preferences.cachedActivity(current.account.organizationId),
                                canChoose = current.account.roleCode == "promoter",
                                busy = busy,
                                error = message,
                                onLogout = {
                                    val logoutToken=vault.loadAccessToken()?:current.accessToken
                                    vault.clear()
                                    NaxaServicesSyncScheduler.cancel(context)
                                    PushTokenRegistry.disable(context)
                                    rememberSession=false;session=null;pendingRefresh=null;localPinUnlockedMemberId=null
                                    offlineRestored=false;tourActive=false;route=AppRoute.LOGIN.name
                                    scope.launch {
                                        runCatching { api.revokeCurrentDevicePushTokens(logoutToken) }
                                        runCatching { api.logout(logoutToken) }
                                    }
                                }
                            ) { selected ->
                                scope.launch {
                                    busy = true
                                    message = null
                                    runCatching { api.setOrganizationActivityProfile(current.accessToken, selected) }
                                        .onSuccess { saved ->
                                            preferences.saveActivity(current.account.organizationId, saved)
                                            val updated = current.copy(account = current.account.copy(activityProfile = saved))
                                            session = updated
                                            route = routeAfterAuthentication(updated)
                                        }
                                        .onFailure { message = it.message ?: "Le Promoteur doit enregistrer l’activité de l’organisation." }
                                    busy = false
                                }
                            }
                        }
                        AppRoute.LEGAL_ACCEPTANCE -> {
                            val current = session
                            if (current == null) route = AppRoute.LOGIN.name
                            else {
                                val hasTerms = "terms:$TERMS_VERSION" in current.account.acceptedLegalDocs
                                val hasPrivacy = "privacy:$PRIVACY_VERSION" in current.account.acceptedLegalDocs
                                LegalAcceptanceScreen(
                                    locale = current.account.defaultLocale,
                                    initialTermsAccepted = hasTerms,
                                    initialPrivacyAccepted = hasPrivacy,
                                    onAccept = { terms, privacy ->
                                        scope.launch {
                                            busy = true
                                            message = null
                                            runCatching {
                                                if (terms && !hasTerms) api.acceptLegalDocument(current.accessToken, "terms", TERMS_VERSION, if (current.account.defaultLocale == "en") "en" else "fr")
                                                if (privacy && !hasPrivacy) api.acceptLegalDocument(current.accessToken, "privacy", PRIVACY_VERSION, if (current.account.defaultLocale == "en") "en" else "fr")
                                            }.onSuccess {
                                                val accepted = current.account.acceptedLegalDocs +
                                                    (if (terms) setOf("terms:$TERMS_VERSION") else emptySet()) +
                                                    (if (privacy) setOf("privacy:$PRIVACY_VERSION") else emptySet())
                                                val updated = current.copy(account = current.account.copy(acceptedLegalDocs = accepted))
                                                session = updated
                                                route = AppRoute.DISCOVERY.name
                                            }.onFailure { message = it.message ?: "L’acceptation n’a pas pu être enregistrée." }
                                            busy = false
                                        }
                                    },
                                    busy = busy,
                                    error = message
                                )
                            }
                        }
                        AppRoute.DISCOVERY -> {
                            DiscoveryScreen(locale = session?.account?.defaultLocale ?: locale) {
                                val current = session
                                if (current == null) route = AppRoute.LOGIN.name
                                else scope.launch {
                                    busy = true
                                    runCatching { api.completeOnboardingStep(current.accessToken, "discovery") }
                                        .onSuccess {
                                            val updated = current.copy(account = current.account.copy(discoveryCompleted = true))
                                            session = updated
                                            tourActive = !updated.account.tourCompleted
                                            tourStep = 0
                                            route = AppRoute.DASHBOARD.name
                                        }
                                        .onFailure { message = it.message ?: "Impossible d’enregistrer la découverte." }
                                    busy = false
                                }
                            }
                        }
                        else -> {
                            val current = session
                            if (current == null) {
                                route = AppRoute.LOGIN.name
                            } else if(localPinUnlockedMemberId!=current.account.memberId){
                                Box(Modifier.fillMaxSize())
                            } else if(offlineRestored&&AppRoute.valueOf(route) !in offlineLocalRoutes){
                                AccessDeniedContent(Modifier.fillMaxSize()){route=AppRoute.DASHBOARD.name}
                            } else {
                                key(current.account.memberId,current.account.organizationId,current.account.roleCode,current.account.activeSiteIds,current.deviceId,offlineRestored){
                                ErpScreen(
                                    offlineLocal=offlineRestored,
                                    route = AppRoute.valueOf(route),
                                    authApi = api,
                                    activeSession = current,
                                    localRepository = localRepository,
                                    accountName = current.account.displayName,
                                    roleCode = current.account.roleCode,
                                    lightTheme = lightTheme,
                                    onTheme = {
                                        val nextMode = if (lightTheme) "dark" else "light"
                                        preferences.saveTheme(nextMode, preferences.nightStart(), preferences.nightEnd(), preferences.flashlightEnabled())
                                        lightTheme = !lightTheme
                                    },
                                    onNavigate = { route = it.name },
                                    onLogout = {
                                        val logoutToken=vault.loadAccessToken()?:current.accessToken
                                        vault.clear()
                                        NaxaServicesSyncScheduler.cancel(context)
                                        androidx.work.WorkManager.getInstance(context).cancelUniqueWork(
                                            "naxa-services-charge-reminders-" + current.account.organizationId
                                        )
                                        PushTokenRegistry.disable(context)
                                        rememberSession=false;localPinUnlockedMemberId=null;session=null;pendingRefresh=null
                                        offlineRestored=false;tourActive=false;route=AppRoute.LOGIN.name
                                        scope.launch {
                                            runCatching { api.revokeCurrentDevicePushTokens(logoutToken) }
                                            runCatching { api.logout(logoutToken) }
                                        }
                                    },
                                    message = message,
                                    onDismissMessage = { message = null },
                                    preferences = preferences,
                                    locale = locale,
                                    onAppearanceChanged = { selected -> lightTheme = selected },
                                    onLocale = { selectedLocale ->
                                        scope.launch {
                                            busy = true
                                            runCatching { api.setMemberPreferredLocale(current.accessToken, selectedLocale) }
                                                .onSuccess {
                                                    preferences.saveLocale(selectedLocale)
                                                    preferences.saveMemberLocale(current.account.memberId, selectedLocale)
                                                    locale = selectedLocale
                                                    session = current.copy(account = current.account.copy(defaultLocale = selectedLocale))
                                                }
                                                .onFailure {
                                                    preferences.saveLocale(selectedLocale)
                                                    preferences.saveMemberLocale(current.account.memberId, selectedLocale)
                                                    locale = selectedLocale
                                                    session = current.copy(account = current.account.copy(defaultLocale = selectedLocale))
                                                    message = "Langue enregistrée sur cet appareil. La synchronisation du profil sera réessayée à la prochaine connexion."
                                                }
                                            busy = false
                                        }
                                    },
                                    activityProfile = current.account.activityProfile,
                                    onSessionUpdated = { updated ->
                                        session = updated
                                        if (rememberSession) vault.save(updated)
                                    },
                                    tourActive = tourActive,
                                    tourStep = tourStep,
                                    onTourNext = {
                                        if (tourStep >= 4) {
                                            scope.launch {
                                                runCatching { api.completeOnboardingStep(current.accessToken, "tour") }
                                                    .onSuccess {
                                                        session = current.copy(account = current.account.copy(tourCompleted = true))
                                                        tourActive = false
                                                    }
                                                    .onFailure { message = it.message ?: "Le guide n’a pas pu être marqué comme terminé." }
                                            }
                                        } else tourStep += 1
                                    },
                                    onTourSkip = {
                                        scope.launch {
                                            runCatching { api.completeOnboardingStep(current.accessToken, "tour") }
                                                .onSuccess {
                                                    session = current.copy(account = current.account.copy(tourCompleted = true))
                                                    tourActive = false
                                                }
                                                .onFailure { message = it.message ?: "Le guide n’a pas pu être marqué comme terminé." }
                                        }
                                    }
                                )
                                }
                            }
                        }
                    }
                    MiniTorchOverlay(
                        target = torchTarget,
                        active = !lightTheme && preferences.flashlightEnabled(),
                        activation = nightActivation
                    )
                    val gatedSession = session
                    if (gatedSession != null && !gatedSession.requirePasswordChange &&
                        LocalAccessPinGatePolicy.requiresUnlock(
                            gatedSession.account.memberId,
                            localPinUnlockedMemberId
                        )
                    ) {
                        val pinIsConfigured = localPinManager.isConfigured(gatedSession.account.memberId)
                        key(gatedSession.account.memberId, pinIsConfigured, lockGenerationValue) {
                            LocalAccessPinGate(
                                memberId = gatedSession.account.memberId,
                                displayName = gatedSession.account.displayName,
                                isSetup = !pinIsConfigured,
                                authApi = api,
                                manager = localPinManager,
                                rememberSession = rememberSession,
                                onUnlocked = { localPinUnlockedMemberId = gatedSession.account.memberId },
                                onReauthenticated = { updated ->
                                    localPinUnlockedMemberId = null
                                    session = updated
                                    offlineRestored=false
                                    if (rememberSession) vault.save(updated) else vault.clear()
                                    if (updated.requirePasswordChange) route = AppRoute.CHANGE_PASSWORD.name
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NaxaServicesWordmark() {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Image(
            painter = painterResource(R.drawable.naxa_services_monogram),
            contentDescription = "NAXA Services",
            modifier = Modifier.size(48.dp)
        )
        Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
            Text("NAXA", color = MaterialTheme.colorScheme.onBackground, fontWeight = FontWeight.Black, style = MaterialTheme.typography.headlineMedium)
            Text("SERVICES", color = Color(0xFFDD3A33), fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelMedium, letterSpacing = 3.sp)
        }
    }
}

@Composable
private fun LoginScreen(
    busy: Boolean,
    message: String?,
    locale: String,
    onLogin: (String, String, Boolean) -> Unit,
    onForgot: () -> Unit,
    onLocale: (String) -> Unit,
    lightTheme: Boolean,
    onToggleTheme: () -> Unit
) {
    var identifier by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var rememberMe by rememberSaveable { mutableStateOf(false) }
    var showPassword by rememberSaveable { mutableStateOf(false) }

    Box(Modifier.fillMaxSize().imePadding(), contentAlignment = Alignment.Center) {
    Column(
        Modifier.widthIn(max = 560.dp).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 22.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.Center
    ) {
        NaxaServicesWordmark()
        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.End) {
            TextButton(onClick=onToggleTheme, modifier=Modifier.testTag("login-theme-toggle")){Text(if(lightTheme) "☾" else "☀")}
            TextButton(onClick={onLocale("fr")},enabled=locale!="fr",modifier=Modifier.testTag("locale-fr")){Text("FR")}
            TextButton(onClick={onLocale("en")},enabled=locale!="en",modifier=Modifier.testTag("locale-en")){Text("EN")}
            TextButton(onClick={onLocale("ff-CM")},enabled=locale!="ff-CM",modifier=Modifier.testTag("locale-ff")){Text("FF")}
        }
        Spacer(Modifier.height(12.dp))
        LoginBusinessBanner(locale)
        Spacer(Modifier.height(18.dp))
        Text(stringResource(R.string.login_title), style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text(stringResource(R.string.login_subtitle), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(26.dp))
        OutlinedTextField(
            value = identifier, onValueChange = { identifier = it.uppercase() },
            modifier = Modifier.fillMaxWidth().testTag("login-identifier"), label = { Text(stringResource(R.string.login_identifier)) },
            placeholder = { Text("NS-000000") }, singleLine = true
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = password, onValueChange = { password = it },
            modifier = Modifier.fillMaxWidth().testTag("login-password"), label = { Text(stringResource(R.string.password)) },
            visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
            trailingIcon = { TextButton(onClick = { showPassword = !showPassword }) { Text(if (showPassword) stringResource(R.string.hide) else stringResource(R.string.show)) } },
            singleLine = true
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Checkbox(checked = rememberMe, onCheckedChange = { rememberMe = it })
            Text(stringResource(R.string.remember_me), style = MaterialTheme.typography.bodyMedium)
        }
        if (!message.isNullOrBlank()) {
            Text(message, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(vertical = 8.dp))
        }
        Button(
            onClick = { onLogin(identifier, password, rememberMe) },
            enabled = !busy && identifier.isNotBlank() && password.isNotBlank(),
            modifier = Modifier.fillMaxWidth().height(54.dp).testTag("login-submit")
        ) {
            if (busy) CircularProgressIndicator(Modifier.size(20.dp), color = MaterialTheme.colorScheme.onPrimary, strokeWidth = 2.dp)
            else Text(stringResource(R.string.sign_in))
        }
        TextButton(onClick = onForgot, modifier = Modifier.align(Alignment.CenterHorizontally)) {
            Text(stringResource(R.string.forgot_password))
        }
    }
    }
}

@Composable
private fun RecoveryScreen(
    busy: Boolean,
    message: String?,
    onSubmit: (String, String) -> Unit,
    onBack: () -> Unit
) {
    var identifier by rememberSaveable { mutableStateOf("") }
    var note by rememberSaveable { mutableStateOf("") }
    Column(Modifier.fillMaxSize().imePadding().verticalScroll(rememberScrollState()).padding(24.dp), verticalArrangement = Arrangement.Center) {
        NaxaServicesWordmark()
        Spacer(Modifier.height(30.dp))
        Text(stringResource(R.string.recovery_title), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text(stringResource(R.string.recovery_explainer), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(22.dp))
        OutlinedTextField(identifier, { identifier = it.uppercase() }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.login_identifier)) }, singleLine = true)
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(note, { note = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.recovery_note)) }, minLines = 3)
        if (!message.isNullOrBlank()) Text(message, color = MaterialTheme.colorScheme.secondary, modifier = Modifier.padding(vertical = 10.dp))
        Spacer(Modifier.height(16.dp))
        Button(onClick = { onSubmit(identifier, note) }, enabled = !busy && identifier.isNotBlank(), modifier = Modifier.fillMaxWidth().height(52.dp)) {
            if (busy) CircularProgressIndicator(Modifier.size(18.dp), color = MaterialTheme.colorScheme.onPrimary, strokeWidth = 2.dp)
            else Text(stringResource(R.string.send_recovery))
        }
        TextButton(onClick = onBack, modifier = Modifier.align(Alignment.CenterHorizontally)) { Text(stringResource(R.string.back_to_login)) }
    }
}

@Composable
private fun ChangePasswordScreen(
    busy: Boolean,
    message: String?,
    onSubmit: (String, String) -> Unit
) {
    var current by rememberSaveable { mutableStateOf("") }
    var next by rememberSaveable { mutableStateOf("") }
    var confirm by rememberSaveable { mutableStateOf("") }
    Column(Modifier.fillMaxSize().imePadding().verticalScroll(rememberScrollState()).padding(24.dp), verticalArrangement = Arrangement.Center) {
        NaxaServicesWordmark()
        Spacer(Modifier.height(30.dp))
        Text(stringResource(R.string.change_password_title), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(stringResource(R.string.change_password_explainer), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(18.dp))
        OutlinedTextField(current, { current = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.current_password)) }, visualTransformation = PasswordVisualTransformation(), singleLine = true)
        Spacer(Modifier.height(10.dp))
        OutlinedTextField(next, { next = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.new_password)) }, visualTransformation = PasswordVisualTransformation(), singleLine = true)
        Spacer(Modifier.height(10.dp))
        OutlinedTextField(confirm, { confirm = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.confirm_password)) }, visualTransformation = PasswordVisualTransformation(), singleLine = true)
        if (!message.isNullOrBlank()) Text(message, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(vertical = 8.dp))
        Spacer(Modifier.height(14.dp))
        Button(
            onClick = { onSubmit(current, next) },
            enabled = !busy && current.isNotBlank() && next.length >= 10 && next == confirm,
            modifier = Modifier.fillMaxWidth().height(52.dp)
        ) {
            if (busy) CircularProgressIndicator(Modifier.size(18.dp), color = MaterialTheme.colorScheme.onPrimary, strokeWidth = 2.dp)
            else Text(stringResource(R.string.save_password))
        }
    }
}

private data class ModuleSpec(val route: AppRoute, val title: Int, val description: Int, val actions: List<Int>)

private val modules = listOf(
    ModuleSpec(AppRoute.AGENDA, R.string.module_agenda, R.string.agenda_desc, listOf(R.string.action_new_appointment, R.string.action_waitlist, R.string.action_absences)),
    ModuleSpec(AppRoute.PRESSING, R.string.module_pressing, R.string.pressing_desc, listOf(R.string.action_new_ticket, R.string.action_status, R.string.action_ready_pickup)),
    ModuleSpec(AppRoute.WORK_ORDERS, R.string.module_work_orders, R.string.work_orders_desc, listOf(R.string.action_create_work_order, R.string.action_quote, R.string.action_track_work)),
    ModuleSpec(AppRoute.CASH, R.string.module_cash, R.string.cash_desc, listOf(R.string.action_new_sale, R.string.action_open_cash, R.string.action_close_cash, R.string.action_expense)),
    ModuleSpec(AppRoute.SERVICES, R.string.module_services, R.string.services_desc, listOf(R.string.action_add_service, R.string.action_price_lists, R.string.action_packages)),
    ModuleSpec(AppRoute.CUSTOMERS, R.string.module_customers, R.string.customers_desc, listOf(R.string.action_new_customer, R.string.action_history, R.string.action_loyalty)),
    ModuleSpec(AppRoute.CUSTOMER_PROMOTIONS, R.string.module_customer_promotions, R.string.customer_promotions_desc, listOf(R.string.action_referral_campaign, R.string.action_share_customer_code, R.string.action_wheel_setup)),
    ModuleSpec(AppRoute.TEAM, R.string.module_team, R.string.team_desc, listOf(R.string.action_add_member, R.string.action_assign)),
    ModuleSpec(AppRoute.TEAM_PERFORMANCE, R.string.module_team_performance, R.string.team_performance_desc, listOf(R.string.action_clock_in, R.string.action_clock_out, R.string.action_commissions, R.string.action_advances)),
    ModuleSpec(AppRoute.STOCK, R.string.module_stock, R.string.stock_desc, listOf(R.string.action_inventory, R.string.action_consumption, R.string.action_low_stock)),
    ModuleSpec(AppRoute.PURCHASES, R.string.module_purchases, R.string.purchases_desc, listOf(R.string.action_add_supplier, R.string.action_purchase_order, R.string.action_receiving)),
    ModuleSpec(AppRoute.BILLING, R.string.module_billing, R.string.billing_desc, listOf(R.string.action_quote, R.string.action_invoice, R.string.action_credit_note, R.string.action_refund)),
    ModuleSpec(AppRoute.SUBSCRIPTIONS, R.string.module_subscriptions, R.string.subscriptions_desc, listOf(R.string.action_choose_plan, R.string.action_payment, R.string.action_entitlements)),
    ModuleSpec(AppRoute.OBJECTIVES, R.string.module_objectives, R.string.objectives_desc, listOf(R.string.action_daily_objective, R.string.action_team_target, R.string.action_compare)),
    ModuleSpec(AppRoute.TAXES, R.string.module_taxes, R.string.taxes_desc, listOf(R.string.action_tax_settings, R.string.action_tax_estimate, R.string.action_tax_deadlines)),
    ModuleSpec(AppRoute.AI_INSIGHTS, R.string.module_ai_insights, R.string.ai_insights_desc, listOf(R.string.action_sales_analysis, R.string.action_margin_analysis, R.string.action_forecast)),
    ModuleSpec(AppRoute.REPORTS, R.string.module_reports, R.string.reports_desc, listOf(R.string.action_daily_report, R.string.action_cash_report, R.string.action_export)),
    ModuleSpec(AppRoute.ORGANIZATION, R.string.module_organization, R.string.organization_desc, listOf(R.string.action_business_profile, R.string.action_subscription, R.string.action_permissions)),
    ModuleSpec(AppRoute.NETWORK, R.string.module_network, R.string.network_desc, listOf(R.string.action_site_overview, R.string.action_consolidation, R.string.action_transfer)),
    ModuleSpec(AppRoute.SITES, R.string.module_sites, R.string.sites_desc, listOf(R.string.action_add_site, R.string.action_site_settings, R.string.action_site_team)),
    ModuleSpec(AppRoute.WORKSTATIONS, R.string.module_workstations, R.string.workstations_desc, listOf(R.string.action_add_workstation, R.string.action_assign_staff, R.string.action_workstation_schedule)),
    ModuleSpec(AppRoute.SECURITY, R.string.module_security, R.string.security_desc, listOf(R.string.action_devices, R.string.action_recovery_queue, R.string.action_access_log)),
    ModuleSpec(AppRoute.LIVECHAT, R.string.module_livechat, R.string.livechat_desc, listOf(R.string.action_faq, R.string.action_contact_support, R.string.action_call_support)),
    ModuleSpec(AppRoute.APPEARANCE, R.string.module_appearance, R.string.appearance_desc, listOf(R.string.action_language, R.string.action_theme, R.string.action_night_schedule)),
    ModuleSpec(AppRoute.PROFILE, R.string.module_profile, R.string.profile_desc, listOf(R.string.action_personal_information, R.string.action_history, R.string.action_sign_out)),
    ModuleSpec(AppRoute.SETTINGS, R.string.module_settings, R.string.settings_desc, listOf(R.string.action_language, R.string.action_theme, R.string.action_offline)),
    ModuleSpec(AppRoute.HELP, R.string.module_help, R.string.help_desc, listOf(R.string.action_faq, R.string.action_contact_support, R.string.action_briefings))
)

private val commonRoutes = setOf(
    AppRoute.DASHBOARD, AppRoute.MENU, AppRoute.PROFILE, AppRoute.APPEARANCE,
    AppRoute.NOTIFICATIONS, AppRoute.LIVECHAT, AppRoute.HELP, AppRoute.SETTINGS
)

private fun activityVisibleRoutes(activity: String?): Set<AppRoute> {
    val shared = commonRoutes + setOf(
        AppRoute.SECURITY, AppRoute.CASH, AppRoute.CUSTOMERS, AppRoute.CUSTOMER_PROMOTIONS, AppRoute.STOCK, AppRoute.PURCHASES,
        AppRoute.BILLING, AppRoute.SUBSCRIPTIONS, AppRoute.OBJECTIVES,
        AppRoute.TAXES, AppRoute.AI_INSIGHTS, AppRoute.REPORTS, AppRoute.TEAM, AppRoute.TEAM_PERFORMANCE,
        AppRoute.ORGANIZATION, AppRoute.NETWORK, AppRoute.SITES, AppRoute.WORKSTATIONS
    )
    return when (activity) {
        // Pressing keeps its itemized deposit/ticket state machine.
        "pressing" -> shared + setOf(AppRoute.PRESSING, AppRoute.AGENDA, AppRoute.SERVICES)
        // Hair and beauty require both appointment booking and a service dossier lifecycle.
        "coiffure", "beaute" -> shared + setOf(AppRoute.WORK_ORDERS, AppRoute.AGENDA, AppRoute.SERVICES)
        // Perfume retail uses catalog, inventory, purchasing and cash; WORK_ORDERS is
        // reserved for customer reservations/special orders, never ordinary checkout.
        "parfumerie" -> shared + setOf(AppRoute.WORK_ORDERS, AppRoute.SERVICES)
        "couture", "reparation", "menuiserie", "garage", "nettoyage", "domicile", "impression", "photo_evenementiel" ->
            shared + setOf(AppRoute.WORK_ORDERS, AppRoute.AGENDA, AppRoute.SERVICES)
        else -> shared + setOf(AppRoute.PRESSING, AppRoute.AGENDA, AppRoute.SERVICES, AppRoute.WORK_ORDERS)
    }
}

private fun canAccessRoute(route: AppRoute, roleCode: String): Boolean {
    if (route in setOf(AppRoute.CUSTOMER_PROMOTIONS, AppRoute.SUBSCRIPTIONS) && roleCode != "promoter") return false
    val common = commonRoutes + setOf(AppRoute.DASHBOARD, AppRoute.MENU)
    val allowed = when (roleCode) {
        "promoter", "network_manager" -> AppRoute.values().toSet()
        "site_manager" -> common + setOf(
            AppRoute.SECURITY, AppRoute.AGENDA, AppRoute.PRESSING, AppRoute.WORK_ORDERS,
            AppRoute.CASH, AppRoute.SERVICES, AppRoute.CUSTOMERS, AppRoute.TEAM,
            AppRoute.TEAM_PERFORMANCE, AppRoute.STOCK, AppRoute.PURCHASES,
            AppRoute.BILLING, AppRoute.OBJECTIVES, AppRoute.TAXES, AppRoute.AI_INSIGHTS,
            AppRoute.REPORTS, AppRoute.WORKSTATIONS
        )
        "cashier" -> common + setOf(AppRoute.CASH, AppRoute.CUSTOMERS, AppRoute.BILLING, AppRoute.REPORTS)
        "receptionist" -> common + setOf(AppRoute.AGENDA, AppRoute.CUSTOMERS, AppRoute.PRESSING, AppRoute.WORK_ORDERS)
        "hair_stylist" -> common + setOf(AppRoute.AGENDA, AppRoute.SERVICES, AppRoute.CUSTOMERS)
        "pressing_operator" -> common + setOf(AppRoute.PRESSING, AppRoute.CUSTOMERS)
        "stock_manager" -> common + setOf(AppRoute.STOCK, AppRoute.PURCHASES)
        "accountant" -> common + setOf(AppRoute.REPORTS, AppRoute.BILLING, AppRoute.TAXES, AppRoute.OBJECTIVES, AppRoute.AI_INSIGHTS, AppRoute.TEAM_PERFORMANCE)
        "workstation_manager" -> common
        else -> common
    }
    return route in allowed
}

private fun canAccessConfiguredRoute(route: AppRoute, roleCode: String, activityProfile: String?): Boolean =
    route in activityVisibleRoutes(activityProfile) && canAccessRoute(route, roleCode)

private fun visibleModuleSpecs(roleCode: String, activityProfile: String?): List<ModuleSpec> =
    modules.filter { canAccessConfiguredRoute(it.route, roleCode, activityProfile) }

@Composable
private fun AccessDeniedContent(modifier: Modifier, onBack: () -> Unit) {
    Column(
        modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(localizedLabel("Accès non autorisé","Access denied","Naatugol salaama"), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text(localizedLabel("Ce module n’est pas disponible pour le rôle associé à ce compte.","This module is not available for your account role.","Golle ɗee heɓotaake e yamiroore konte maa."), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(16.dp))
        Button(onClick = onBack) { Text(localizedLabel("Retour à l’accueil","Back to home","Rutto to jaɓɓorgo")) }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ErpScreen(
    offlineLocal: Boolean,
    route: AppRoute,
    authApi: AuthApi,
    activeSession: AuthSession,
    localRepository: NaxaServicesLocalRepository,
    accountName: String,
    roleCode: String,
    lightTheme: Boolean,
    onTheme: () -> Unit,
    onNavigate: (AppRoute) -> Unit,
    onLogout: () -> Unit,
    message: String?,
    onDismissMessage: () -> Unit,
    preferences: NaxaServicesPreferences,
    locale: String,
    onAppearanceChanged: (Boolean) -> Unit,
    onLocale: (String) -> Unit,
    activityProfile: String?,
    onSessionUpdated: (AuthSession) -> Unit,
    tourActive: Boolean,
    tourStep: Int,
    onTourNext: () -> Unit,
    onTourSkip: () -> Unit
) {
    val reminderContext = androidx.compose.ui.platform.LocalContext.current
    LaunchedEffect(activeSession.account.organizationId,offlineLocal) {
        if(offlineLocal)return@LaunchedEffect
        val request = androidx.work.PeriodicWorkRequestBuilder<RecurringChargeReminderWorker>(
            24, java.util.concurrent.TimeUnit.HOURS
        ).setInputData(
            androidx.work.workDataOf(
                RecurringChargeReminderWorker.KEY_ORGANIZATION_ID to activeSession.account.organizationId
            )
        ).build()
        androidx.work.WorkManager.getInstance(reminderContext).enqueueUniquePeriodicWork(
            "naxa-services-charge-reminders-" + activeSession.account.organizationId,
            androidx.work.ExistingPeriodicWorkPolicy.UPDATE,
            request
        )
    }
    val currentSpec = modules.firstOrNull { it.route == route }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Column { Text("NAXA SERVICES", fontWeight = FontWeight.Black); Text(accountName, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant) } },
                actions = {
                    TextButton(onClick = { onNavigate(AppRoute.NOTIFICATIONS) }) { Text(localizedLabel("Alertes","Alerts","Tintine")) }
                    TextButton(onClick = { onNavigate(AppRoute.PROFILE) }) { Text(localizedLabel("Profil","Profile","Humpito am")) }
                    TextButton(onClick = onTheme) { Text(if (lightTheme) stringResource(R.string.dark_mode) else stringResource(R.string.light_mode)) }
                }
            )
        },
        bottomBar = {
            NavigationBar {
                NavigationBarItem(selected = route == AppRoute.DASHBOARD, onClick = { onNavigate(AppRoute.DASHBOARD) }, icon = { Text("⌂") }, label = { Text(stringResource(R.string.nav_home)) })
                if (canAccessConfiguredRoute(AppRoute.AGENDA, roleCode, activityProfile)) {
                    NavigationBarItem(selected = route == AppRoute.AGENDA, onClick = { onNavigate(AppRoute.AGENDA) }, icon = { Text("◷") }, label = { Text(stringResource(R.string.nav_agenda)) })
                }
                if (canAccessConfiguredRoute(AppRoute.PRESSING, roleCode, activityProfile)) {
                    NavigationBarItem(selected = route == AppRoute.PRESSING, onClick = { onNavigate(AppRoute.PRESSING) }, icon = { Text("▤") }, label = { Text(stringResource(R.string.nav_pressing)) })
                }
                if (canAccessRoute(AppRoute.CASH, roleCode)) {
                    NavigationBarItem(selected = route == AppRoute.CASH, onClick = { onNavigate(AppRoute.CASH) }, icon = { Text("₣") }, label = { Text(stringResource(R.string.nav_cash)) })
                }
                NavigationBarItem(selected = route == AppRoute.MENU, onClick = { onNavigate(AppRoute.MENU) }, icon = { Text("•••") }, label = { Text(stringResource(R.string.nav_more)) })
            }
        },
        snackbarHost = {
            if (!message.isNullOrBlank()) {
                TextButton(onClick = onDismissMessage, modifier = Modifier.fillMaxWidth()) { Text(message, color = MaterialTheme.colorScheme.secondary) }
            }
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { padding ->
        if (!canAccessConfiguredRoute(route, roleCode, activityProfile) || (offlineLocal && route !in offlineLocalRoutes)) {
            AccessDeniedContent(Modifier.padding(padding)) { onNavigate(AppRoute.DASHBOARD) }
        } else if (route == AppRoute.DASHBOARD) {
            DashboardContent(Modifier.padding(padding), accountName, roleCode, locale, activityProfile, localRepository, activeSession, onNavigate, onLogout, tourActive, tourStep, onTourNext, onTourSkip,offlineLocal)
        } else if (route == AppRoute.MENU) {
            ModuleMenu(Modifier.padding(padding), roleCode, activityProfile, onNavigate, onLogout,offlineLocal)
        } else if (route == AppRoute.PRESSING) {
            PressingLocalContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.AGENDA) {
            AgendaLocalContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.CASH) {
            CashLocalContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.TEAM) {
            TeamManagementContent(Modifier.padding(padding), authApi, activeSession)
        } else if (route == AppRoute.SECURITY) {
            AccessManagementContent(Modifier.padding(padding), authApi, activeSession)
        } else if (route == AppRoute.SERVICES) {
            ServicesCatalogContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.CUSTOMERS) {
            CustomersContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.CUSTOMER_PROMOTIONS) {
            CustomerPromotionsContent(Modifier.padding(padding), localRepository, activeSession, authApi) { onNavigate(AppRoute.PROFILE) }
        } else if (route == AppRoute.NOTIFICATIONS) {
            NotificationInboxContent(Modifier.padding(padding), activeSession, authApi) { onNavigate(AppRoute.PROFILE) }
        } else if (route == AppRoute.STOCK) {
            StockContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.REPORTS) {
            ReportsContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.ORGANIZATION || route == AppRoute.NETWORK || route == AppRoute.SITES || route == AppRoute.WORKSTATIONS) {
            OrganizationWorkspaceContent(Modifier.padding(padding), route, localRepository, authApi, activeSession, onSessionUpdated)
        } else if (route == AppRoute.HELP) {
            SupportContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.LIVECHAT) {
            LivechatContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.PROFILE) {
            ProfileContent(Modifier.padding(padding), activeSession, authApi, activityProfile, localRepository, preferences, onNavigate, onLogout)
        } else if (route == AppRoute.APPEARANCE) {
            AppearanceSettingsContent(locale, preferences, onChanged = onAppearanceChanged, onLocale = onLocale)
        } else if (route == AppRoute.BILLING) {
            BillingContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.SUBSCRIPTIONS) {
            SubscriptionsContent(Modifier.padding(padding), authApi, activeSession)
        } else if (route == AppRoute.PURCHASES) {
            PurchasesContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.TAXES) {
            TaxesContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.CHARGES) {
            RecurringChargesContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.OBJECTIVES) {
            ObjectivesContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.TEAM_PERFORMANCE) {
            TeamPerformanceContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.AI_INSIGHTS) {
            AiInsightsContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.WORK_ORDERS && activityProfile == "pressing") {
            PressingLocalContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.WORK_ORDERS) {
            WorkOrdersContent(Modifier.padding(padding), localRepository, activeSession, activityProfile)
        } else if (route == AppRoute.SETTINGS) {
            SettingsContent(Modifier.padding(padding), localRepository, activeSession, authApi, lightTheme, onTheme)
        } else if (currentSpec != null) {
            ModuleContent(Modifier.padding(padding), currentSpec, onNavigate)
        } else {
            ModuleMenu(Modifier.padding(padding), roleCode, activityProfile, onNavigate, onLogout,offlineLocal)
        }
    }
}



@Composable
private fun PressingLocalContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession
) {
    val scope = rememberCoroutineScope()
    val fr = session.account.defaultLocale != "en"
    var siteId by rememberSaveable { mutableStateOf(session.account.activeSiteIds.firstOrNull().orEmpty()) }
    var workstationId by rememberSaveable { mutableStateOf("") }
    var customer by rememberSaveable { mutableStateOf("") }
    var phone by rememberSaveable { mutableStateOf("") }
    var garments by rememberSaveable { mutableStateOf("") }
    var total by rememberSaveable { mutableStateOf("") }
    var deposit by rememberSaveable { mutableStateOf("0") }
    var depositPaymentMethod by rememberSaveable { mutableStateOf("") }
    var depositCashSessionId by rememberSaveable { mutableStateOf("") }
    var promisedPickup by rememberSaveable {
        mutableStateOf(SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date(System.currentTimeMillis() + 24L * 60L * 60L * 1000L)))
    }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }
    var advanceReasons by remember { mutableStateOf<Map<String, String>>(emptyMap()) }
    val orders by remember(siteId) {
        repository.dao.observePressingOrders(session.account.organizationId, siteId)
    }.collectAsState(initial = emptyList())
    val workstations by remember(siteId) {
        repository.dao.observeWorkstations(session.account.organizationId, siteId)
    }.collectAsState(initial = emptyList())
    val cashSessions by remember(siteId) {
        repository.dao.observeCashSessions(session.account.organizationId, siteId)
    }.collectAsState(initial = emptyList())
    val openCashSessions = cashSessions.filter { it.status == "open" }
    val depositXafValue = deposit.toLongOrNull() ?: 0L
    val depositPaymentReady = depositXafValue == 0L ||
        (depositPaymentMethod in setOf("cash", "mobile_money", "other") &&
            (depositPaymentMethod != "cash" ||
                openCashSessions.any { it.id == depositCashSessionId }))

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle(
                when (session.account.defaultLocale) { "en" -> "Laundry — tickets and pickup"; "ff-CM" -> "Lootugol — kayite e heɓtugol"; else -> "Pressing — tickets et retrait" },
                when (session.account.defaultLocale) { "en" -> "Follow every ticket from drop-off to pickup."; "ff-CM" -> "Kayit kala e innol mum, nokkuure mum, ñalnde fodoonde e jaŋtol feere mum."; else -> "Chaque ticket possède une référence unique, un emplacement d'origine, une date promise et un historique des étapes." }
            )
            AuthorizedSitePicker(
                session.account.activeSiteIds,
                siteId,
                session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }
            ) { siteId = it; workstationId = ""; depositCashSessionId = "" }
            LocalOnlyNotice(when (session.account.defaultLocale) { "en" -> "Track tickets until pickup. Automatic pickup alerts are unavailable."; "ff-CM" -> "Rewindo kayite maa haa heɓtugol. Tintine heɓtugol neldeteeɗe e hoore mum alaa jooni."; else -> "Suivez vos tickets jusqu’au retrait. L'envoi automatique des alertes de retrait est indisponible." })
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "New laundry ticket"; "ff-CM" -> "Kayit lootugol kesol"; else -> "Nouveau ticket pressing" }, fontWeight = FontWeight.Bold)
                    Text(when (session.account.defaultLocale) { "en" -> "Counter / workshop"; "ff-CM" -> "Jaɓɓorgo / nokkuure golle"; else -> "Comptoir / atelier" }, fontWeight = FontWeight.SemiBold)
                    OutlinedButton(onClick = { workstationId = "" }, modifier = Modifier.fillMaxWidth()) {
                        Text(if (workstationId.isBlank()) (when (session.account.defaultLocale) { "en" -> "✓ Site-wide (no dedicated workstation)"; "ff-CM" -> "✓ Nokkuure jaaygol (alaa nokkuure golle keeriiɗe)"; else -> "✓ Point de vente (sans poste dédié)" }) else when (session.account.defaultLocale) { "en" -> "No dedicated workstation"; "ff-CM" -> "Alaa nokkuure golle keeriiɗe"; else -> "Aucun poste dédié" })
                    }
                    workstations.filter { it.status == "active" }.forEach { workstation ->
                        OutlinedButton(onClick = { workstationId = workstation.id }, modifier = Modifier.fillMaxWidth()) {
                            Text((if (workstationId == workstation.id) "✓ " else "") + workstation.name + " · " + workstation.kind)
                        }
                    }
                    OutlinedTextField(customer, { customer = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.customer_name)) }, singleLine = true)
                    OutlinedTextField(phone, { phone = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.customer_phone)) }, singleLine = true)
                    OutlinedTextField(garments, { garments = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Garments (type, color, brand, condition/stains and requested treatment)"; "ff-CM" -> "Comci (fannu, noone, marque, ngonka/tache e lootugol ɗaɓɓitaangol)"; else -> "Pièces (type, couleur, marque, état/taches et traitement demandé)" }) }, minLines = 3)
                    OutlinedTextField(total, { total = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.total_amount_xaf)) }, singleLine = true)
                    OutlinedTextField(deposit, { deposit = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.deposit_amount_xaf)) }, singleLine = true)
                    if (depositXafValue > 0) {
                        Text(when (session.account.defaultLocale) { "en" -> "Deposit collection method"; "ff-CM" -> "Heɓugol ceede adiiɗe"; else -> "Encaissement de l'acompte" }, fontWeight = FontWeight.SemiBold)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(
                                onClick = { depositPaymentMethod = "cash"; depositCashSessionId = "" },
                                modifier = Modifier.weight(1f)
                            ) { Text((if (depositPaymentMethod == "cash") "✓ " else "") + when (session.account.defaultLocale) { "en" -> "Cash"; "ff-CM" -> "Ceede e juuɗe"; else -> "Espèces" }) }
                            OutlinedButton(
                                onClick = { depositPaymentMethod = "mobile_money"; depositCashSessionId = "" },
                                modifier = Modifier.weight(1f)
                            ) { Text((if (depositPaymentMethod == "mobile_money") "✓ " else "") + "Mobile Money") }
                        }
                        OutlinedButton(
                            onClick = { depositPaymentMethod = "other"; depositCashSessionId = "" },
                            modifier = Modifier.fillMaxWidth()
                        ) { Text((if (depositPaymentMethod == "other") "✓ " else "") + when (session.account.defaultLocale) { "en" -> "Bank transfer / other — pending confirmation"; "ff-CM" -> "Virement / goɗɗum — tabbitin"; else -> "Virement / autre — à confirmer" }) }
                        if (depositPaymentMethod == "cash") {
                            Text(
                                when (session.account.defaultLocale) { "en" -> "Select the cash session that actually receives the cash."; "ff-CM" -> "Suɓo keesu ngu heɓi ceede e juuɗe."; else -> "Choisis la session de caisse qui reçoit réellement les espèces." },
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                style = MaterialTheme.typography.bodySmall
                            )
                            if (openCashSessions.isEmpty()) {
                                Text(
                                    when (session.account.defaultLocale) { "en" -> "No open cash session at this site. Open a register before recording this cash deposit."; "ff-CM" -> "Alaa keesu udditaangu e nokkuure ndee. Uddit keesu hade danndude ceede adiiɗe."; else -> "Aucune session ouverte sur ce point de vente. Ouvre une caisse avant d'enregistrer cet acompte en espèces." },
                                    color = MaterialTheme.colorScheme.error,
                                    style = MaterialTheme.typography.bodySmall
                                )
                            }
                            openCashSessions.forEach { cashSession ->
                                OutlinedButton(
                                    onClick = { depositCashSessionId = cashSession.id },
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Text(
                                        (if (depositCashSessionId == cashSession.id) "✓ " else "") +
                                            cashSession.registerName + " · " +
                                            SimpleDateFormat("dd/MM HH:mm", Locale.getDefault()).format(Date(cashSession.openedAtMillis))
                                    )
                                }
                            }
                        } else if (depositPaymentMethod in setOf("mobile_money", "other")) {
                            Text(
                                when (session.account.defaultLocale) { "en" -> "Record only a deposit already received outside the app; it is excluded from physical cash."; "ff-CM" -> "Winndu tan ceede adiiɗe keɓaaɗe tawa aplikasiyoŋ alaa; ɗe naatataa e keesu."; else -> "Saisis uniquement l'acompte déjà reçu hors application ; il n'entre pas dans le solde des espèces." },
                                color = MaterialTheme.colorScheme.secondary,
                                style = MaterialTheme.typography.bodySmall
                            )
                        } else {
                            Text(
                                when (session.account.defaultLocale) { "en" -> "Select how the deposit is collected; no payment method is assumed."; "ff-CM" -> "Suɓo laawol heɓugol ceede. Njoɓdi limtaaka so tabbitinaaka."; else -> "Sélectionne le mode d'encaissement ; aucun paiement ne sera supposé." },
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                    } else {
                        Text(
                            when (session.account.defaultLocale) { "en" -> "No deposit collected when this ticket is created."; "ff-CM" -> "Alaa ceede adiiɗe e sosde kayit."; else -> "Aucun acompte à encaisser à la création du ticket." },
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                    OutlinedTextField(
                        promisedPickup,
                        { promisedPickup = it },
                        Modifier.fillMaxWidth(),
                        label = { Text(when (session.account.defaultLocale) { "en" -> "Promised pickup (YYYY-MM-DD HH:MM)"; "ff-CM" -> "Heɓtugol fodoonde (AAAA-MM-JJ HH:MM)"; else -> "Retrait promis (AAAA-MM-JJ HH:MM)" }) },
                        singleLine = true
                    )
                    if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                    Button(
                        onClick = {
                            scope.launch {
                                busy = true
                                error = null
                                runCatching {
                                    val promisedAt = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault())
                                        .apply { isLenient = false }
                                        .parse(promisedPickup)?.time
                                        ?: throw IllegalArgumentException(when (session.account.defaultLocale) { "en" -> "Invalid promised pickup date."; "ff-CM" -> "Ñalnde heɓtugol feewaani."; else -> "Date de retrait invalide." })
                                    require(promisedAt > System.currentTimeMillis()) {
                                        when (session.account.defaultLocale) { "en" -> "Promised pickup must be in the future."; "ff-CM" -> "Ñalnde heɓtugol foti arde caggal hannde."; else -> "Le retrait promis doit être dans le futur." }
                                    }
                                    repository.createPressingOrder(
                                        orgId = session.account.organizationId,
                                        siteId = siteId,
                                        workstationId = workstationId.takeIf { it.isNotBlank() },
                                        customerName = customer,
                                        customerPhone = phone,
                                        itemsSummary = garments,
                                        totalXaf = total.toLong(),
                                        depositXaf = deposit.toLongOrNull() ?: 0L,
                                        promisedAtMillis = promisedAt,
                                        actorMemberId = session.account.memberId,
                                        depositPaymentMethod = depositPaymentMethod.takeIf { depositXafValue > 0 },
                                        depositCashSessionId = depositCashSessionId.takeIf { depositPaymentMethod == "cash" && depositXafValue > 0 }
                                    )
                                }.onSuccess { newOrder ->
                                    customer = ""; phone = ""; garments = ""; total = ""; deposit = "0"
                                    depositPaymentMethod = ""; depositCashSessionId = ""
                                    notice = if (fr) {
                                        "Ticket créé : " + newOrder.ticketNumber + " · acompte " +
                                            (if (newOrder.depositPaymentStatus == "confirmed") "encaissé en espèces" else if (newOrder.depositPaymentStatus == "pending") "en attente de confirmation" else "non encaissé")
                                    } else {
                                        "Ticket created: " + newOrder.ticketNumber + " · deposit " +
                                            (if (newOrder.depositPaymentStatus == "confirmed") "received in cash" else if (newOrder.depositPaymentStatus == "pending") "awaiting confirmation" else "not collected")
                                    }
                                    error = null
                                }.onFailure { error = it.message ?: when (session.account.defaultLocale) { "en" -> "Unable to create ticket."; "ff-CM" -> "Sosugol kayit waawataa."; else -> "Création du ticket impossible." } }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && customer.isNotBlank() && garments.isNotBlank() &&
                            (total.toLongOrNull() ?: 0L) > 0 && depositPaymentReady,
                        modifier = Modifier.fillMaxWidth()
                    ) { if (busy) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = MaterialTheme.colorScheme.onPrimary) else Text(stringResource(R.string.create_pressing_ticket)) }
                    if (!notice.isNullOrBlank()) Text(notice!!, color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        item { Text(when (session.account.defaultLocale) { "en" -> "Tickets and pickups"; "ff-CM" -> "Kayite e heɓtugol"; else -> "Tickets et retraits" }, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (orders.isEmpty()) {
            item { Text(stringResource(R.string.no_local_pressing_tickets), color = MaterialTheme.colorScheme.onSurfaceVariant) }
        } else {
            items(orders) { order ->
                val events by remember(order.id, siteId) {
                    repository.dao.observePressingStatusEvents(order.id, session.account.organizationId, siteId)
                }.collectAsState(initial = emptyList())
                PressingOrderCard(
                    order = order,
                    events = events,
                    locale = session.account.defaultLocale,
                    reason = advanceReasons[order.id].orEmpty(),
                    onReasonChange = { value -> advanceReasons = advanceReasons + (order.id to value) },
                    onAdvance = {
                        scope.launch {
                            runCatching {
                                repository.advancePressingOrder(order, session.account.memberId, advanceReasons[order.id].orEmpty())
                            }.onSuccess {
                                advanceReasons = advanceReasons + (order.id to "")
                                notice = when (session.account.defaultLocale) { "en" -> "Laundry stage updated and recorded."; "ff-CM" -> "Feere lootugol hesɗitinaama e danndaama."; else -> "Étape pressing mise à jour et historisée." }
                                error = null
                            }.onFailure { error = it.message ?: "Status update failed." }
                        }
                    }
                )
            }
        }
        if (!error.isNullOrBlank()) item { Text(error!!, color = MaterialTheme.colorScheme.error) }
    }
}


@Composable
private fun PressingOrderCard(
    order: LocalPressingOrder,
    events: List<LocalPressingStatusEvent>,
    locale: String,
    reason: String,
    onReasonChange: (String) -> Unit,
    onAdvance: () -> Unit
) {
    val status = when (order.status) {
        "received" -> stringResource(R.string.pressing_status_received)
        "in_progress" -> stringResource(R.string.pressing_status_in_progress)
        "ready" -> stringResource(R.string.pressing_status_ready)
        "picked_up" -> stringResource(R.string.pressing_status_picked_up)
        else -> order.status
    }
    val promised = SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.getDefault()).format(Date(order.promisedAtMillis))
    val nextLabel = when (order.status) {
        "received" -> when (locale) { "en" -> "Start processing"; "ff-CM" -> "Fuɗɗo golle"; else -> "Lancer le traitement" }
        "in_progress" -> when (locale) { "en" -> "Mark laundry ready"; "ff-CM" -> "Maanto comci ko hebii"; else -> "Marquer le linge prêt" }
        "ready" -> when (locale) { "en" -> "Confirm pickup"; "ff-CM" -> "Tabbitin heɓtugol"; else -> "Confirmer le retrait" }
        else -> ""
    }
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                Text(order.ticketNumber, fontWeight = FontWeight.Bold)
                Text(status, color = MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.labelMedium)
            }
            Text(order.customerName, style = MaterialTheme.typography.titleMedium)
            if (order.customerPhone.isNotBlank()) Text(order.customerPhone, style = MaterialTheme.typography.bodySmall)
            Text(order.itemsSummary, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
            Text((when (locale) { "en" -> "Promised pickup: "; "ff-CM" -> "Heɓtugol fodoonde : "; else -> "Retrait promis : " }) + promised, style = MaterialTheme.typography.bodySmall)
            order.workstationId?.let { Text((when (locale) { "en" -> "Workstation: "; "ff-CM" -> "Nokkuure golle : "; else -> "Poste : " }) + it, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall) }
            Text(stringResource(R.string.pressing_total_and_deposit, order.totalXaf, order.depositXaf), style = MaterialTheme.typography.bodySmall)
            if (order.depositXaf > 0) {
                val methodLabel = when (order.depositPaymentMethod) {
                    "cash" -> when (locale) { "en" -> "cash"; "ff-CM" -> "ceede e juuɗe"; else -> "espèces" }
                    "mobile_money" -> "Mobile Money"
                    "other" -> when (locale) { "en" -> "bank transfer / other"; "ff-CM" -> "virement / goɗɗum"; else -> "virement / autre" }
                    else -> when (locale) { "en" -> "method not recorded"; "ff-CM" -> "laawol winndaaka"; else -> "mode non renseigné" }
                }
                val paymentState = when (order.depositPaymentStatus) {
                    "confirmed" -> when (locale) { "en" -> "received · session linked"; "ff-CM" -> "heɓaama · keesu jokkondiraama"; else -> "encaissé · session liée" }
                    "pending" -> when (locale) { "en" -> "awaiting confirmation"; "ff-CM" -> "nana fadi tabbitinol"; else -> "en attente de confirmation" }
                    else -> when (locale) { "en" -> "not reconciled"; "ff-CM" -> "tabbitinaaka"; else -> "non rapproché" }
                }
                Text(
                    (when (locale) { "en" -> "Deposit: "; "ff-CM" -> "Ceede adiiɗe : "; else -> "Acompte : " }) + methodLabel + " · " + paymentState,
                    color = if (order.depositPaymentStatus == "confirmed") MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary,
                    style = MaterialTheme.typography.bodySmall
                )
            }
            if (order.status != "picked_up") {
                OutlinedTextField(
                    reason,
                    onReasonChange,
                    Modifier.fillMaxWidth(),
                    label = { Text(when (locale) { "en" -> "Reason required for next stage"; "ff-CM" -> "Daliilu waajib ngam feere aroore"; else -> "Motif obligatoire pour l'étape suivante" }) },
                    minLines = 1
                )
                Button(onClick = onAdvance, enabled = reason.trim().length >= 3, modifier = Modifier.fillMaxWidth()) {
                    Text(nextLabel)
                }
            }
            if (events.isNotEmpty()) {
                Text(when (locale) { "en" -> "Ticket history"; "ff-CM" -> "Jaŋtol kayit"; else -> "Historique du ticket" }, fontWeight = FontWeight.SemiBold)
                events.take(6).forEach { event ->
                    Text(
                        event.fromStatus + " → " + event.toStatus + " · " + event.reason.ifBlank { when (locale) { "en" -> "Initial stage"; "ff-CM" -> "Feere arande"; else -> "Étape initiale" } },
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }
    }
}


@Composable
private fun AgendaLocalContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession
) {
    val scope = rememberCoroutineScope()
    val fr = session.account.defaultLocale != "en"
    var siteId by rememberSaveable { mutableStateOf(session.account.activeSiteIds.firstOrNull().orEmpty()) }
    var workstationId by rememberSaveable { mutableStateOf("") }
    var customer by rememberSaveable { mutableStateOf("") }
    var service by rememberSaveable { mutableStateOf("") }
    var duration by rememberSaveable { mutableStateOf("30") }
    var start by rememberSaveable { mutableStateOf(SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date(System.currentTimeMillis() + 60L * 60L * 1000L))) }
    var deposit by rememberSaveable { mutableStateOf("0") }
    var waitlistCustomer by rememberSaveable { mutableStateOf("") }
    var waitlistService by rememberSaveable { mutableStateOf("") }
    var waitlistPreference by rememberSaveable { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var message by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    val appointments by remember(siteId) { repository.dao.observeAppointments(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    val workstations by remember(siteId) { repository.dao.observeWorkstations(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    val services by remember(siteId) { repository.dao.observeServices(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    val waitlist by remember(siteId) { repository.dao.observeManagementRecordsByType(session.account.organizationId, siteId, "appointment_waitlist") }.collectAsState(initial = emptyList())

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle(
                when (session.account.defaultLocale) { "en" -> "Calendar and appointments"; "ff-CM" -> "Doggol sahaaaji"; else -> "Agenda et rendez-vous" },
                when (session.account.defaultLocale) { "en" -> "Slots by site, workstation and provider; appointments, deposits, cancellations and waitlist."; "ff-CM" -> "Sahaaaji nokkuure jaaygol, nokkuure golle e gollotooɗo; ceede adiiɗe, haaytugol e doggol fadotooɓe."; else -> "Créneaux par point de vente, emplacement et prestataire ; rendez-vous, acomptes, annulations et liste d'attente." }
            )
            AuthorizedSitePicker(session.account.activeSiteIds, siteId, session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }) {
                siteId = it
                workstationId = ""
            }
            LocalOnlyNotice(when (session.account.defaultLocale) { "en" -> "Check availability at your location. External reminders are unavailable."; "ff-CM" -> "Ƴeewto sahaaaji golle maa. Tintine goɗɗe alaa jooni."; else -> "Vérifiez les disponibilités de votre établissement. Les rappels externes sont indisponibles." })
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "New booking"; "ff-CM" -> "Sahaa keso"; else -> "Nouvelle réservation" }, fontWeight = FontWeight.Bold)
                    Text(when (session.account.defaultLocale) { "en" -> "Workstation / service location"; "ff-CM" -> "Nokkuure golle"; else -> "Emplacement / poste de travail" }, fontWeight = FontWeight.SemiBold)
                    OutlinedButton(onClick = { workstationId = "" }, modifier = Modifier.fillMaxWidth()) {
                        Text(if (workstationId.isBlank()) (when (session.account.defaultLocale) { "en" -> "✓ No workstation required"; "ff-CM" -> "✓ Nokkuure suɓaaka"; else -> "✓ Aucun emplacement imposé" }) else when (session.account.defaultLocale) { "en" -> "No workstation required"; "ff-CM" -> "Nokkuure suɓaaka"; else -> "Aucun emplacement imposé" })
                    }
                    workstations.filter { it.status == "active" }.forEach { workstation ->
                        OutlinedButton(onClick = { workstationId = workstation.id }, modifier = Modifier.fillMaxWidth()) {
                            Text((if (workstationId == workstation.id) "✓ " else "") + workstation.name + " · " + workstation.kind)
                        }
                    }
                    OutlinedTextField(customer, { customer = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.customer_name)) }, singleLine = true)
                    OutlinedTextField(service, { service = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.service_name)) }, singleLine = true)
                    services.filter { it.active }.take(20).forEach { item ->
                        OutlinedButton(
                            onClick = { service = item.name; duration = (item.durationMinutes ?: 30).toString() },
                            modifier = Modifier.fillMaxWidth()
                        ) { Text((if (service == item.name) "✓ " else "") + item.name + " · " + item.durationMinutes + " min · " + item.priceXaf + " F") }
                    }
                    OutlinedTextField(start, { start = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.appointment_start_local)) }, singleLine = true)
                    OutlinedTextField(duration, { duration = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.appointment_duration_minutes)) }, singleLine = true)
                    OutlinedTextField(deposit, { deposit = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.deposit_amount_xaf)) }, singleLine = true)
                    if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                    Button(
                        onClick = {
                            scope.launch {
                                busy = true
                                error = null
                                runCatching {
                                    val dateParser = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).apply { isLenient = false }
                                    val startAt = dateParser.parse(start)?.time
                                        ?: throw IllegalArgumentException(when (session.account.defaultLocale) { "en" -> "Invalid date/time. Expected YYYY-MM-DD HH:MM."; "ff-CM" -> "Ñalnde/sahaa feewaani. Huutoro AAAA-MM-JJ HH:MM."; else -> "Date/heure invalide. Format attendu : AAAA-MM-JJ HH:MM." })
                                    val durationMinutes = duration.toLongOrNull() ?: throw IllegalArgumentException(when (session.account.defaultLocale) { "en" -> "Invalid duration."; "ff-CM" -> "Sahaa feewaani."; else -> "Durée invalide." })
                                    require(durationMinutes in 5..600) { when (session.account.defaultLocale) { "en" -> "Duration must be between 5 and 600 minutes."; "ff-CM" -> "Sahaa foti wonde minit 5 haa 600."; else -> "La durée doit être comprise entre 5 et 600 minutes." } }
                                    repository.createAppointment(
                                        orgId = session.account.organizationId,
                                        siteId = siteId,
                                        workstationId = workstationId.takeIf { it.isNotBlank() },
                                        customerName = customer,
                                        serviceName = service,
                                        assignedMemberId = session.account.memberId,
                                        startsAtMillis = startAt,
                                        endsAtMillis = startAt + durationMinutes * 60_000L,
                                        depositXaf = deposit.toLongOrNull() ?: 0L,
                                        actorMemberId = session.account.memberId
                                    )
                                }.onSuccess {
                                    customer = ""; service = ""; deposit = "0"
                                    message = when (session.account.defaultLocale) { "en" -> "Appointment saved — awaiting synchronization."; "ff-CM" -> "Sahaa danndaama — nana fadi hesɗitingol."; else -> "Rendez-vous enregistré — en attente de synchronisation." }
                                }.onFailure { error = it.message ?: when (session.account.defaultLocale) { "en" -> "Booking failed."; "ff-CM" -> "Sahaa waawaa danndeede."; else -> "Rendez-vous impossible." } }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && customer.isNotBlank() && service.isNotBlank(),
                        modifier = Modifier.fillMaxWidth()
                    ) { if (busy) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = MaterialTheme.colorScheme.onPrimary) else Text(stringResource(R.string.create_appointment)) }
                    if (!message.isNullOrBlank()) Text(message!!, color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "Waitlist"; "ff-CM" -> "Doggol fadotooɓe"; else -> "Liste d'attente" }, fontWeight = FontWeight.Bold)
                    OutlinedTextField(waitlistCustomer, { waitlistCustomer = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Customer name"; "ff-CM" -> "Innde soottotooɗo"; else -> "Nom du client" }) }, singleLine = true)
                    OutlinedTextField(waitlistService, { waitlistService = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Requested service"; "ff-CM" -> "Golle ɗaɓɓitaande"; else -> "Prestation souhaitée" }) }, singleLine = true)
                    OutlinedTextField(waitlistPreference, { waitlistPreference = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Preferred date / time"; "ff-CM" -> "Ñalnde / sahaa cuɓaaɗo"; else -> "Préférence de date / heure" }) }, singleLine = true)
                    Button(
                        onClick = {
                            scope.launch {
                                runCatching {
                                    repository.createManagementRecord(
                                        session.account.organizationId, siteId, "appointment_waitlist",
                                        "ATT-" + System.currentTimeMillis(), waitlistService, waitlistCustomer,
                                        0, 0, null, "open",
                                        JSONObject().put("preferredTime", waitlistPreference.trim()).toString(),
                                        session.account.memberId
                                    )
                                }.onSuccess {
                                    waitlistCustomer = ""; waitlistService = ""; waitlistPreference = ""
                                    message = when (session.account.defaultLocale) { "en" -> "Customer added to waitlist."; "ff-CM" -> "Soottotooɗo ɓeydaama e doggol fadotooɓe."; else -> "Client ajouté à la liste d'attente." }
                                }.onFailure { error = it.message ?: "Waitlist update failed." }
                            }
                        },
                        enabled = siteId.isNotBlank() && waitlistCustomer.isNotBlank() && waitlistService.isNotBlank(),
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(when (session.account.defaultLocale) { "en" -> "Add to waitlist"; "ff-CM" -> "Ɓeydu e doggol fadotooɓe"; else -> "Ajouter à la liste d'attente" }) }
                }
            }
        }
        item { Text(stringResource(R.string.appointments_local_list), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (appointments.isEmpty()) item { Text(stringResource(R.string.no_local_appointments), color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(appointments) { appointment ->
            val events by remember(appointment.id, siteId) {
                repository.dao.observeWorkflowEvents(session.account.organizationId, siteId, "appointment", appointment.id)
            }.collectAsState(initial = emptyList())
            var reason by rememberSaveable(appointment.id) { mutableStateOf("") }
            var proposedStart by rememberSaveable(appointment.id) {
                mutableStateOf(SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date(appointment.startsAtMillis)))
            }
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(appointment.customerName, fontWeight = FontWeight.Bold)
                    Text(appointment.serviceName)
                    Text(SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.getDefault()).format(Date(appointment.startsAtMillis)), color = MaterialTheme.colorScheme.secondary)
                    Text(stringResource(R.string.appointment_local_status, appointment.status), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (appointment.status in setOf("booked", "confirmed")) {
                        OutlinedTextField(reason, { reason = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Reason for change is required"; "ff-CM" -> "Daliilu waylugol ko waajib"; else -> "Motif de modification obligatoire" }) })
                        val statuses = if (appointment.status == "booked") listOf("confirmed" to (when (session.account.defaultLocale) { "en" -> "Confirm"; "ff-CM" -> "Tabbitin"; else -> "Confirmer" }), "cancelled" to (when (session.account.defaultLocale) { "en" -> "Cancel"; "ff-CM" -> "Haaytu"; else -> "Annuler" }), "no_show" to (when (session.account.defaultLocale) { "en" -> "No-show"; "ff-CM" -> "Alaa ɗoo"; else -> "Absent" })) else listOf("completed" to (when (session.account.defaultLocale) { "en" -> "Complete"; "ff-CM" -> "Timmin"; else -> "Terminer" }), "cancelled" to (when (session.account.defaultLocale) { "en" -> "Cancel"; "ff-CM" -> "Haaytu"; else -> "Annuler" }), "no_show" to (when (session.account.defaultLocale) { "en" -> "No-show"; "ff-CM" -> "Alaa ɗoo"; else -> "Absent" }))
                        statuses.forEach { (nextStatus, label) ->
                            OutlinedButton(
                                onClick = {
                                    scope.launch {
                                        runCatching {
                                            repository.transitionAppointmentStatus(session.account.organizationId, siteId, appointment.id, nextStatus, reason, session.account.memberId)
                                        }.onSuccess { reason = ""; message = when (session.account.defaultLocale) { "en" -> "Appointment updated and audited."; "ff-CM" -> "Sahaa hesɗitinaama e danndaama."; else -> "Rendez-vous mis à jour et historisé." } }
                                            .onFailure { error = it.message ?: "Appointment update failed." }
                                    }
                                },
                                enabled = reason.trim().length >= 3,
                                modifier = Modifier.fillMaxWidth()
                            ) { Text(label) }
                        }
                        OutlinedTextField(proposedStart, { proposedStart = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "New date/time (YYYY-MM-DD HH:MM)"; "ff-CM" -> "Ñalnde/sahaa keso (AAAA-MM-JJ HH:MM)"; else -> "Nouvelle date/heure (AAAA-MM-JJ HH:MM)" }) }, singleLine = true)
                        OutlinedButton(
                            onClick = {
                                scope.launch {
                                    runCatching {
                                        val parsed = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).apply { isLenient = false }.parse(proposedStart)?.time
                                            ?: throw IllegalArgumentException("Invalid date/time")
                                        repository.rescheduleAppointment(
                                            session.account.organizationId, siteId, appointment.id,
                                            parsed, parsed + (appointment.endsAtMillis - appointment.startsAtMillis),
                                            reason, session.account.memberId
                                        )
                                    }.onSuccess { reason = ""; message = when (session.account.defaultLocale) { "en" -> "Appointment rescheduled after conflict check."; "ff-CM" -> "Sahaa waylaama, ƴeewtaama."; else -> "Créneau déplacé ; contrôle de conflit effectué." } }
                                        .onFailure { error = it.message ?: "Reschedule failed." }
                                }
                            },
                            enabled = reason.trim().length >= 3 && proposedStart.isNotBlank(),
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(when (session.account.defaultLocale) { "en" -> "Reschedule"; "ff-CM" -> "Waylu sahaa"; else -> "Reprogrammer" }) }
                    }
                    events.take(5).forEach { event ->
                        Text(event.fromStatus + " → " + event.toStatus + " · " + event.reason, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
        item { Text(when (session.account.defaultLocale) { "en" -> "Waiting customers"; "ff-CM" -> "Soottotooɓe fadotooɓe"; else -> "Clients en attente" }, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(waitlist) { row ->
            var waitReason by rememberSaveable(row.id) { mutableStateOf("") }
            var waitStart by rememberSaveable(row.id) {
                mutableStateOf(SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date(System.currentTimeMillis() + 60L * 60L * 1000L)))
            }
            var waitDuration by rememberSaveable(row.id) { mutableStateOf("30") }
            var waitDeposit by rememberSaveable(row.id) { mutableStateOf("0") }
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(14.dp)) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text(row.counterparty, fontWeight = FontWeight.Bold)
                    Text(row.title + " · " + row.status)
                    OutlinedTextField(waitReason, { waitReason = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Reason for update / conversion"; "ff-CM" -> "Daliilu waylugol"; else -> "Motif de mise à jour / conversion" }) })
                    if (row.status in setOf("open", "contacted")) {
                        OutlinedTextField(waitStart, { waitStart = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Booked slot (YYYY-MM-DD HH:MM)"; "ff-CM" -> "Sahaa cuɓaaɗo (AAAA-MM-JJ HH:MM)"; else -> "Créneau retenu (AAAA-MM-JJ HH:MM)" }) }, singleLine = true)
                        OutlinedTextField(waitDuration, { waitDuration = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Duration (minutes)"; "ff-CM" -> "Sahaa (minit)"; else -> "Durée (minutes)" }) }, singleLine = true)
                        OutlinedTextField(waitDeposit, { waitDeposit = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Deposit (XAF)"; "ff-CM" -> "Ceede adiiɗe (FCFA)"; else -> "Acompte (FCFA)" }) }, singleLine = true)
                        OutlinedButton(
                            onClick = {
                                scope.launch {
                                    runCatching {
                                        val parsed = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).apply { isLenient = false }.parse(waitStart)?.time
                                            ?: throw IllegalArgumentException(when (session.account.defaultLocale) { "en" -> "Invalid date."; "ff-CM" -> "Ñalnde feewaani."; else -> "Date invalide." })
                                        repository.convertWaitlistToAppointment(
                                            session.account.organizationId, siteId, row.id,
                                            workstationId.takeIf { it.isNotBlank() },
                                            parsed, waitDuration.toIntOrNull() ?: 0,
                                            waitDeposit.toLongOrNull() ?: 0L,
                                            waitReason, session.account.memberId
                                        )
                                    }.onSuccess {
                                        waitReason = ""
                                        message = when (session.account.defaultLocale) { "en" -> "Waitlist entry converted into a real appointment."; "ff-CM" -> "Sahaa goonga sosaama e doggol fadotooɓe."; else -> "La liste d'attente a été convertie en rendez-vous réel." }
                                    }.onFailure { error = it.message ?: "Waitlist conversion failed." }
                                }
                            },
                            enabled = waitReason.trim().length >= 3 && (waitDuration.toIntOrNull()?.let { it in 5..600 } == true),
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(when (session.account.defaultLocale) { "en" -> "Create appointment and convert"; "ff-CM" -> "Sos sahaa e waylu"; else -> "Créer le rendez-vous et convertir" }) }
                    }
                    if (row.status == "open") {
                        OutlinedButton(
                            onClick = {
                                scope.launch {
                                    runCatching {
                                        repository.transitionManagementRecord(session.account.organizationId, siteId, row.id, "contacted", waitReason, session.account.memberId)
                                    }.onSuccess { waitReason = ""; message = when (session.account.defaultLocale) { "en" -> "Customer marked as contacted."; "ff-CM" -> "Maantaama ko jokkondiraama e soottotooɗo."; else -> "Client marqué comme contacté." } }
                                        .onFailure { error = it.message ?: "Waitlist transition failed." }
                                }
                            },
                            enabled = waitReason.trim().length >= 3,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(when (session.account.defaultLocale) { "en" -> "Mark customer as contacted"; "ff-CM" -> "Maanto ko jokkondiraama e soottotooɗo"; else -> "Marquer le client comme contacté" }) }
                    }
                    if (row.status in setOf("open", "contacted")) {
                        OutlinedButton(
                            onClick = {
                                scope.launch {
                                    runCatching {
                                        repository.transitionManagementRecord(session.account.organizationId, siteId, row.id, "cancelled", waitReason, session.account.memberId)
                                    }.onSuccess { waitReason = ""; message = when (session.account.defaultLocale) { "en" -> "Entry removed from waitlist."; "ff-CM" -> "Ittaama e doggol."; else -> "Entrée retirée de la liste." } }
                                        .onFailure { error = it.message ?: "Waitlist transition failed." }
                                }
                            },
                            enabled = waitReason.trim().length >= 3,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(when (session.account.defaultLocale) { "en" -> "Remove from waitlist"; "ff-CM" -> "Ittu e doggol"; else -> "Retirer de la liste" }) }
                    }
                }
            }
        }
        if (!error.isNullOrBlank()) item { Text(error!!, color = MaterialTheme.colorScheme.error) }
        if (!message.isNullOrBlank()) item { Text(message!!, color = MaterialTheme.colorScheme.primary) }
    }
}

@Composable
private fun CashLocalContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession
) {
    val scope = rememberCoroutineScope()
    var siteId by rememberSaveable { mutableStateOf(session.account.activeSiteIds.firstOrNull().orEmpty()) }
    val sessions by remember(siteId) { repository.dao.observeCashSessions(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    val sales by remember(siteId) { repository.dao.observeSales(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    val pressingOrders by remember(siteId) { repository.dao.observePressingOrders(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    val stockItems by remember(siteId) { repository.dao.observeInventoryItems(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    val stockValuations by remember(siteId) { repository.dao.observeInventoryValuations(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    val pendingOutbox by repository.dao.observePendingOutboxCount(session.account.organizationId).collectAsState(initial = 0)
    val openSession = sessions.firstOrNull { it.status == "open" }
    val pressingCashDepositsForOpenSession = openSession?.let { active ->
        pressingOrders.filter {
            it.depositCashSessionId == active.id &&
                it.depositPaymentMethod == "cash" &&
                it.depositPaymentStatus == "confirmed"
        }.sumOf { it.depositXaf }
    } ?: 0L

    var selectedStockItemId by rememberSaveable { mutableStateOf("") }
    var saleStockQuantity by rememberSaveable { mutableStateOf("1") }
    val selectedStockItem = stockItems.firstOrNull { it.id == selectedStockItemId }
    val selectedStockValuation = selectedStockItem?.let { item -> stockValuations.firstOrNull { it.inventoryItemId == item.id } }
    val parsedStockSaleQuantity: Double = saleStockQuantity.replace(",", ".").toDoubleOrNull() ?: 0.0
    val linkedStockPrice = selectedStockValuation?.sellingPriceXaf ?: 0L
    val linkedStockTotal = (parsedStockSaleQuantity * linkedStockPrice.toDouble()).takeIf { it.isFinite() && it <= Long.MAX_VALUE.toDouble() }?.toLong() ?: 0L

    var registerId by rememberSaveable { mutableStateOf("") }
    var registerName by rememberSaveable { mutableStateOf("Caisse principale") }
    var openingFloat by rememberSaveable { mutableStateOf("0") }
    var saleDescription by rememberSaveable { mutableStateOf("") }
    var saleTotal by rememberSaveable { mutableStateOf("") }
    var paymentMethod by rememberSaveable { mutableStateOf("cash") }
    var expenseCategory by rememberSaveable { mutableStateOf("") }
    var expenseDescription by rememberSaveable { mutableStateOf("") }
    var expenseAmount by rememberSaveable { mutableStateOf("") }
    var countedClose by rememberSaveable { mutableStateOf("") }
    var varianceReason by rememberSaveable { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }
    var receiptSale by remember { mutableStateOf<LocalSale?>(null) }
    var busy by remember { mutableStateOf(false) }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(stringResource(R.string.cash_local_title), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.cash_local_desc), color = MaterialTheme.colorScheme.onSurfaceVariant)
            AuthorizedSitePicker(session.account.activeSiteIds, siteId, session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }) { siteId = it }
            Text(stringResource(R.string.outbox_pending_count, pendingOutbox), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.secondary)
        }
        if (openSession == null) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                    Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(stringResource(R.string.cash_open_session_title), fontWeight = FontWeight.Bold)
                        OutlinedTextField(registerId, { registerId = it.trim() }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.cash_register_id)) }, singleLine = true)
                        OutlinedTextField(registerName, { registerName = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.cash_register_name)) }, singleLine = true)
                        OutlinedTextField(openingFloat, { openingFloat = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.cash_opening_float)) }, singleLine = true)
                        Button(
                            onClick = {
                                scope.launch {
                                    busy = true
                                    error = null
                                    runCatching {
                                        repository.openCashSession(session.account.organizationId, siteId, registerId, registerName, openingFloat.toLongOrNull() ?: 0L, session.account.memberId)
                                    }.onSuccess { notice = "Caisse ouverte." }
                                        .onFailure { error = it.message ?: "Ouverture de caisse impossible." }
                                    busy = false
                                }
                            },
                            enabled = !busy && siteId.isNotBlank() && registerId.isNotBlank(),
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(stringResource(R.string.open_cash_session)) }
                    }
                }
            }
        } else {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                    Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(stringResource(R.string.cash_session_open, openSession.registerName), fontWeight = FontWeight.Bold)
                        Text(stringResource(R.string.cash_opening_amount_xaf, openSession.openingFloatXaf))
                        Text(
                            (if (session.account.defaultLocale == "en") "Confirmed pressing cash deposits in this session: " else "Acomptes pressing espèces confirmés sur cette session : ") +
                                pressingCashDepositsForOpenSession.toString() + " F",
                            color = MaterialTheme.colorScheme.secondary,
                            style = MaterialTheme.typography.bodySmall
                        )
                        Text(localizedLabel("Vente libre ou article lié au stock","Direct sale or stock item","Jaaygol walla jawdi e stock"), fontWeight = FontWeight.SemiBold)
                        OutlinedButton(
                            onClick = {
                                selectedStockItemId = ""
                                saleStockQuantity = "1"
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(if (selectedStockItemId.isBlank()) "✓ Vente libre / prestation" else "Passer en vente libre / prestation") }
                        stockItems.forEach { item ->
                            OutlinedButton(
                                onClick = {
                                    selectedStockItemId = item.id
                                    saleDescription = item.name
                                    val valuation = stockValuations.firstOrNull { it.inventoryItemId == item.id }
                                    saleTotal = ((saleStockQuantity.replace(",", ".").toDoubleOrNull() ?: 1.0) * (valuation?.sellingPriceXaf ?: 0L)).toLong().takeIf { it > 0 }?.toString() ?: ""
                                },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text((if (selectedStockItemId == item.id) "✓ " else "") + item.name + " · " + item.quantity + " " + item.unit)
                            }
                        }
                        if (selectedStockItem != null) {
                            OutlinedTextField(
                                saleStockQuantity,
                                {
                                    saleStockQuantity = it
                                    val q = it.replace(",", ".").toDoubleOrNull() ?: 0.0
                                    val amount = (q * linkedStockPrice.toDouble()).toLong()
                                    saleTotal = if (amount > 0L) amount.toString() else ""
                                },
                                Modifier.fillMaxWidth(),
                                label = { Text(localizedLabel("Quantité vendue (","Quantity sold (","Keewal jaayngal (") + selectedStockItem.unit + ")") },
                                singleLine = true
                            )
                            Text(localizedLabel("Prix unitaire : ","Unit price: ","Njoɓdi gootal : ") + linkedStockPrice + " F · Total calculé : " + linkedStockTotal + " F · Stock disponible : " + selectedStockItem.quantity,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                style = MaterialTheme.typography.bodySmall
                            )
                            if (selectedStockValuation == null || linkedStockPrice <= 0L) {
                                Text(localizedLabel("Aucun prix de vente configuré pour cet article. Enregistre sa valorisation dans le module Stock.","No sale price set for this item. Set its valuation in Inventory.","Alaa njoɓdi jaaygol jawdi ndii. Danndu njoɓdi e nokkuure jawdi."), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                            }
                            Text(localizedLabel("Saisis uniquement les paiements déjà reçus hors application. La vente et la sortie de stock sont enregistrées ensemble.","Enter only payments already received outside the app. The sale and stock issue are recorded together.","Winndu tan ceede keɓaaɗe tawa aplikasiyoŋ alaa. Jaaygol e yaltugol jawdi ndanndetee gootum."), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        OutlinedTextField(saleDescription, { saleDescription = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.sale_description)) }, singleLine = true)
                        OutlinedTextField(
                            saleTotal,
                            { saleTotal = it.filter(Char::isDigit) },
                            Modifier.fillMaxWidth(),
                            label = { Text(stringResource(R.string.sale_total_xaf)) },
                            singleLine = true,
                            enabled = selectedStockItem == null
                        )
                        OutlinedTextField(paymentMethod, { paymentMethod = it.trim().lowercase() }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.payment_method_cash_or_momo)) }, singleLine = true)
                        Button(
                            onClick = {
                                scope.launch {
                                    busy = true
                                    error = null
                                    runCatching {
                                        repository.recordSale(
                                            session.account.organizationId,
                                            siteId,
                                            openSession.id,
                                            saleDescription,
                                            saleTotal.toLong(),
                                            paymentMethod,
                                            session.account.memberId,
                                            inventoryItemId = selectedStockItem?.id,
                                            stockQuantity = selectedStockItem?.let { saleStockQuantity.replace(",", ".").toDoubleOrNull() }
                                        )
                                    }.onSuccess { pair ->
                                        saleDescription = ""
                                        saleTotal = ""
                                        selectedStockItemId = ""
                                        saleStockQuantity = "1"
                                        receiptSale = pair.first
                                        notice = if (pair.first.status == "pending") {
                                            "Paiement Mobile Money en attente de confirmation. Les articles sont réservés."
                                        } else {
                                            if (pair.first.inventoryItemId != null) {
                                                "Encaissement enregistré ; sortie de stock et mouvement d'inventaire créés dans la même transaction."
                                            } else {
                                                "Encaissement externe enregistré. Votre reçu est prêt."
                                            }
                                        }
                                    }.onFailure { error = it.message ?: "Vente impossible." }
                                    busy = false
                                }
                            },
                            enabled = !busy &&
                                saleDescription.isNotBlank() &&
                                (saleTotal.toLongOrNull() ?: 0L) > 0 &&
                                paymentMethod in setOf("cash", "mobile_money") &&
                                (selectedStockItem == null || (
                                    linkedStockPrice > 0L &&
                                    saleStockQuantity.isNotBlank() &&
                                    parsedStockSaleQuantity > 0.0 &&
                                    parsedStockSaleQuantity <= selectedStockItem.quantity
                                )),
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(stringResource(R.string.record_sale_local)) }
                        Divider()
                        Text(stringResource(R.string.cash_expense_title), fontWeight = FontWeight.Bold)
                        OutlinedTextField(expenseCategory, { expenseCategory = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.expense_category)) }, singleLine = true)
                        OutlinedTextField(expenseDescription, { expenseDescription = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.expense_description)) }, singleLine = true)
                        OutlinedTextField(expenseAmount, { expenseAmount = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.expense_amount_xaf)) }, singleLine = true)
                        Button(
                            onClick = {
                                scope.launch {
                                    busy = true
                                    error = null
                                    runCatching {
                                        repository.addExpense(session.account.organizationId, siteId, openSession.id, expenseCategory, expenseDescription, expenseAmount.toLong(), session.account.memberId)
                                    }.onSuccess { expenseCategory = ""; expenseDescription = ""; expenseAmount = ""; notice = "Dépense enregistrée, en attente de confirmation." }
                                        .onFailure { error = it.message ?: "Dépense impossible." }
                                    busy = false
                                }
                            },
                            enabled = !busy && expenseCategory.isNotBlank() && expenseDescription.isNotBlank() && (expenseAmount.toLongOrNull() ?: 0L) > 0,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(stringResource(R.string.record_expense_local)) }
                        Divider()
                        Text(stringResource(R.string.cash_close_title), fontWeight = FontWeight.Bold)
                        OutlinedTextField(countedClose, { countedClose = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.cash_counted_amount)) }, singleLine = true)
                        OutlinedTextField(varianceReason, { varianceReason = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.cash_variance_reason)) }, minLines = 2)
                        Button(
                            onClick = {
                                scope.launch {
                                    busy = true
                                    error = null
                                    runCatching {
                                        repository.closeCashSession(session.account.organizationId, siteId, openSession.id, countedClose.toLong(), varianceReason, session.account.memberId)
                                    }.onSuccess { notice = "Clôture enregistrée, en attente de confirmation. Écart : " + (it.varianceXaf ?: 0L) + " FCFA." }
                                        .onFailure { error = it.message ?: "Clôture impossible." }
                                    busy = false
                                }
                            },
                            enabled = !busy && (countedClose.toLongOrNull() ?: -1L) >= 0,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(stringResource(R.string.close_cash_session)) }
                    }
                }
            }
        }
        if (!error.isNullOrBlank()) item { Text(error!!, color = MaterialTheme.colorScheme.error) }
        if (!notice.isNullOrBlank()) item { Text(notice!!, color = MaterialTheme.colorScheme.secondary) }
        item { Text(stringResource(R.string.local_sales), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (sales.isEmpty()) item { Text(stringResource(R.string.no_local_sales), color = MaterialTheme.colorScheme.onSurfaceVariant) }
        else items(sales) { sale ->
            var cancellationReason by rememberSaveable(sale.id) { mutableStateOf("") }
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(sale.description, fontWeight = FontWeight.Bold)
                            Text(sale.saleNumber + " · " + sale.status, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                            if (sale.inventoryItemId != null && sale.stockQuantity != null) {
                                Text(localizedLabel("Stock lié : ","Linked stock: ","Jawdi jokkondiraandi : ") + sale.stockQuantity + " unité(s)", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            TextButton(onClick = { receiptSale = sale }) { Text(localizedLabel("Reçu","Received","Heɓaama")) }
                        }
                        Text(sale.totalXaf.toString() + " F")
                    }
                    if (sale.paymentMethod == "mobile_money" && sale.status == "pending") {
                        Text(localizedLabel("Réservation en attente de confirmation. Les articles sont réservés.","Awaiting confirmation. The items are reserved.","Nana fadi tabbitinol. Jawdi ndii suuɗaama."), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
                        OutlinedTextField(
                            cancellationReason,
                            { cancellationReason = it },
                            Modifier.fillMaxWidth(),
                            label = { Text(localizedLabel("Motif obligatoire pour annuler la vente en attente","Reason required to cancel pending sale","Daliilu waajib ngam haaytude jaaygol fadotoongol")) },
                            minLines = 1
                        )
                        OutlinedButton(
                            onClick = {
                                scope.launch {
                                    runCatching {
                                        repository.cancelPendingMobileMoneySale(
                                            session.account.organizationId,
                                            siteId,
                                            sale.id,
                                            cancellationReason,
                                            session.account.memberId
                                        )
                                    }.onSuccess {
                                        cancellationReason = ""
                                        notice = "Vente annulée ; les articles réservés sont de nouveau disponibles."
                                        error = null
                                    }.onFailure { error = it.message ?: "Annulation impossible." }
                                }
                            },
                            enabled = cancellationReason.trim().length >= 3,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(localizedLabel("Annuler la vente Mobile Money en attente","Cancel pending Mobile Money sale","Haaytu jaaygol Mobile Money fadotoongol")) }
                    }
                }
            }
        }
    }
    receiptSale?.let { sale ->
        CashReceiptActions(sale, session) { receiptSale = null }
    }
}

@Composable
private fun OrganizationModeContent(
    modifier: Modifier,
    route: AppRoute,
    session: AuthSession
) {
    var mode by rememberSaveable { mutableStateOf("solo") }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(
                when (route) {
                    AppRoute.ORGANIZATION -> stringResource(R.string.organization_modes_title)
                    AppRoute.NETWORK -> stringResource(R.string.network_scope_title)
                    AppRoute.SITES -> stringResource(R.string.site_autonomy_title)
                    else -> stringResource(R.string.workstation_scope_title)
                },
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold
            )
            Text(stringResource(R.string.organization_modes_desc), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if (route == AppRoute.ORGANIZATION) {
            item {
                ArchitectureModeCard(
                    stringResource(R.string.mode_pme_title),
                    stringResource(R.string.mode_pme_desc),
                    selected = mode == "solo",
                    onClick = { mode = "solo" }
                )
            }
            item {
                ArchitectureModeCard(
                    stringResource(R.string.mode_manager_title),
                    stringResource(R.string.mode_manager_desc),
                    selected = mode == "single_site_multi_workstation",
                    onClick = { mode = "single_site_multi_workstation" }
                )
            }
            item {
                ArchitectureModeCard(
                    stringResource(R.string.mode_promoter_title),
                    stringResource(R.string.mode_promoter_desc),
                    selected = mode == "multi_site_network",
                    onClick = { mode = "multi_site_network" }
                )
            }
            item {
                Text(stringResource(R.string.structure_selection_preview), color = MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.bodySmall)
            }
        }
        if (route == AppRoute.NETWORK || route == AppRoute.SITES) {
            item {
                Text(stringResource(R.string.authorized_site_scope), fontWeight = FontWeight.Bold)
                if (session.account.activeSiteIds.isEmpty()) {
                    Text(stringResource(R.string.no_active_sites), color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    session.account.activeSiteIds.forEachIndexed { index, siteId ->
                        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                            Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                                Text((index + 1).toString().padStart(2, '0'), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                                Spacer(Modifier.width(14.dp))
                                Column(Modifier.weight(1f)) {
                                    Text(stringResource(R.string.site_reference, index + 1), fontWeight = FontWeight.SemiBold)
                                    Text(siteId, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Text(stringResource(R.string.scope_authorized), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)
                            }
                        }
                    }
                }
            }
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                    Column(Modifier.padding(18.dp)) {
                        Text(stringResource(R.string.network_non_mixing_title), fontWeight = FontWeight.Bold)
                        Text(stringResource(R.string.network_non_mixing_desc), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }
        if (route == AppRoute.WORKSTATIONS) {
            item {
                Text(stringResource(R.string.workstation_types_title), fontWeight = FontWeight.Bold)
                listOf(
                    R.string.workstation_hair,
                    R.string.workstation_pressing,
                    R.string.workstation_reception,
                    R.string.workstation_cash
                ).forEachIndexed { index, label ->
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                        Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(stringResource(label), fontWeight = FontWeight.SemiBold)
                                Text(stringResource(R.string.workstation_not_created), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                            }
                            Text((index + 1).toString().padStart(2, '0'), color = MaterialTheme.colorScheme.primary)
                        }
                    }
                }
            }
        }
        item {
            Text(stringResource(R.string.organization_scope_safety), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
            Spacer(Modifier.height(18.dp))
        }
    }
}

@Composable
private fun ArchitectureModeCard(
    title: String,
    description: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    Card(
        onClick = onClick,
        colors = CardDefaults.cardColors(
            containerColor = if (selected) MaterialTheme.colorScheme.surfaceVariant else MaterialTheme.colorScheme.surface
        ),
        shape = RoundedCornerShape(18.dp)
    ) {
        Row(Modifier.fillMaxWidth().padding(18.dp), verticalAlignment = Alignment.Top) {
            Text(if (selected) "●" else "○", color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(end = 13.dp))
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(title, fontWeight = FontWeight.Bold)
                Text(description, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun TeamManagementContent(
    modifier: Modifier,
    api: AuthApi,
    session: AuthSession
) {
    val scope = rememberCoroutineScope()
    var name by rememberSaveable { mutableStateOf("") }
    var phone by rememberSaveable { mutableStateOf("") }
    val assignableRoles = when (session.account.roleCode) {
        "promoter" -> listOf("network_manager", "site_manager", "cashier", "receptionist", "hair_stylist", "pressing_operator", "stock_manager", "accountant")
        "network_manager" -> listOf("site_manager", "cashier", "receptionist", "hair_stylist", "pressing_operator", "stock_manager", "accountant")
        "site_manager" -> listOf("cashier", "receptionist", "hair_stylist", "pressing_operator", "stock_manager", "accountant")
        else -> emptyList()
    }
    var role by rememberSaveable { mutableStateOf(assignableRoles.firstOrNull() ?: "cashier") }
    var roleMenuExpanded by remember { mutableStateOf(false) }
    var selectedSiteIds by rememberSaveable { mutableStateOf(session.account.activeSiteIds.take(1)) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var provisioned by remember { mutableStateOf<ProvisionedAccess?>(null) }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(stringResource(R.string.team_access_admin_title), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.team_access_admin_desc), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.member_display_name)) }, singleLine = true)
                    OutlinedTextField(phone, { phone = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.member_phone_optional)) }, singleLine = true)
                    Box(Modifier.fillMaxWidth()) {
                        OutlinedButton(
                            onClick = { roleMenuExpanded = true },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = assignableRoles.isNotEmpty()
                        ) {
                            Text(localizedLabel("Rôle à attribuer : ","Role to assign: ","Golle suɓeteeɗe : ") + role.replace('_', ' '))
                        }
                        DropdownMenu(
                            expanded = roleMenuExpanded,
                            onDismissRequest = { roleMenuExpanded = false }
                        ) {
                            assignableRoles.forEach { value ->
                                DropdownMenuItem(
                                    text = { Text(value.replace('_', ' ')) },
                                    onClick = { role = value; roleMenuExpanded = false }
                                )
                            }
                        }
                    }
                    if (assignableRoles.isEmpty()) {
                        Text(localizedLabel("Ton rôle ne permet pas de créer des comptes collaborateurs.","You are not authorized to create staff accounts.","A yamiraaka sosde konte golluɓe."), color = MaterialTheme.colorScheme.error)
                    }
                    Text(localizedLabel("Affectation aux points de vente autorisés","Assign authorized locations","Suɓo nokkuuji jaaygol yamiraaɗi"), fontWeight = FontWeight.SemiBold)
                    if (session.account.activeSiteIds.isEmpty()) {
                        Text(stringResource(R.string.no_active_sites), color = MaterialTheme.colorScheme.error)
                    } else {
                        session.account.activeSites.forEachIndexed { index, site ->
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Checkbox(
                                    checked = site.id in selectedSiteIds,
                                    onCheckedChange = { checked ->
                                        val updated = if (checked) (selectedSiteIds + site.id).distinct() else selectedSiteIds - site.id
                                        selectedSiteIds = updated
                                    }
                                )
                                Column {
                                    Text(site.name.ifBlank { stringResource(R.string.site_reference, index + 1) })
                                    Text(listOf(site.code, site.addressLabel).filter { it.isNotBlank() }.joinToString(" · "), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }
                    }
                    Text(localizedLabel("Un collaborateur peut recevoir plusieurs points de vente. L’accès individuel à un poste précis sera activé après le filtrage dédié de ses données.","Staff can be assigned to multiple locations. Workstation-only access is not available yet.","Gollotooɗo waawi heɓde nokkuuji keewɗi. Naatugol e nokkuure golle wootere alaa tawo."),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                    Button(
                        onClick = {
                            scope.launch {
                                busy = true
                                error = null
                                provisioned = null
                                runCatching {
                                    api.provisionMember(
                                        accessToken = session.accessToken,
                                        displayName = name,
                                        roleCode = role,
                                        scopes = selectedSiteIds.map { ProvisionScope(it) },
                                        contactPhone = phone
                                    )
                                }.onSuccess {
                                    provisioned = it
                                    name = ""
                                    phone = ""
                                }.onFailure {
                                    error = it.message ?: "Création du compte impossible."
                                }
                                busy = false
                            }
                        },
                        enabled = !busy && assignableRoles.isNotEmpty() && name.isNotBlank() && selectedSiteIds.isNotEmpty() && role in assignableRoles,
                        modifier = Modifier.fillMaxWidth().height(52.dp)
                    ) {
                        if (busy) CircularProgressIndicator(Modifier.size(18.dp), color = MaterialTheme.colorScheme.onPrimary, strokeWidth = 2.dp)
                        else Text(stringResource(R.string.provision_member))
                    }
                }
            }
        }
        if (provisioned != null) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                    Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(stringResource(R.string.provisioned_credentials_title), fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.secondary)
                        Text(stringResource(R.string.provisioned_login_id) + ": " + provisioned!!.loginId)
                        Text(stringResource(R.string.provisioned_temporary_password) + ": " + provisioned!!.temporaryPassword, fontWeight = FontWeight.Bold)
                        Text(stringResource(R.string.provisioned_one_time_warning), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        TextButton(onClick = { provisioned = null }) { Text(stringResource(R.string.hide_credentials)) }
                    }
                }
            }
        }
    }
}

@Composable
private fun AccessManagementContent(
    modifier: Modifier,
    api: AuthApi,
    session: AuthSession
) {
    val scope = rememberCoroutineScope()
    var requests by remember { mutableStateOf<List<RecoveryRequestItem>>(emptyList()) }
    var selected by remember { mutableStateOf<RecoveryRequestItem?>(null) }
    var verificationMethod by rememberSaveable { mutableStateOf("Présence physique") }
    var verificationNote by rememberSaveable { mutableStateOf("") }
    var installationId by rememberSaveable { mutableStateOf("") }
    var accountId by rememberSaveable { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var reset by remember { mutableStateOf<RecoveryReset?>(null) }

    fun reload() {
        scope.launch {
            busy = true
            error = null
            runCatching { api.listRecoveryRequests(session.accessToken) }
                .onSuccess { requests = it }
                .onFailure { error = it.message ?: "Impossible de charger la file." }
            busy = false
        }
    }
    LaunchedEffect(session.account.memberId) { reload() }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(stringResource(R.string.recovery_queue_title), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.recovery_queue_desc), color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = { reload() }) { Text(stringResource(R.string.refresh_queue)) }
                if (busy) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
            }
            if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error)
        }
        if (requests.isEmpty()) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                    Text(stringResource(R.string.no_recovery_requests), Modifier.padding(18.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        } else {
            items(requests) { item ->
                Card(
                    onClick = { selected = item; reset = null },
                    colors = CardDefaults.cardColors(containerColor = if (selected?.id == item.id) MaterialTheme.colorScheme.surfaceVariant else MaterialTheme.colorScheme.surface),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Text(item.displayName, fontWeight = FontWeight.Bold)
                        Text(item.loginId + " · " + item.roleCode, color = MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.bodySmall)
                        Text(item.note.ifBlank { stringResource(R.string.no_recovery_note) }, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                        Text(item.requestedAt, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.labelSmall)
                    }
                }
            }
        }
        if (selected != null) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                    Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(stringResource(R.string.verify_identity_title), fontWeight = FontWeight.Bold)
                        Text(selected!!.displayName + " · " + selected!!.loginId)
                        OutlinedTextField(verificationMethod, { verificationMethod = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.identity_check_method)) }, singleLine = true)
                        OutlinedTextField(verificationNote, { verificationNote = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.identity_check_note)) }, minLines = 3)
                        Button(
                            onClick = {
                                scope.launch {
                                    busy = true
                                    error = null
                                    runCatching {
                                        api.completeRecovery(session.accessToken, selected!!.id, verificationMethod, verificationNote)
                                    }.onSuccess {
                                        reset = it
                                        selected = null
                                        verificationNote = ""
                                        reload()
                                    }.onFailure { error = it.message ?: "Réinitialisation impossible." }
                                    busy = false
                                }
                            },
                            enabled = !busy && verificationMethod.isNotBlank() && verificationNote.length >= 12,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(stringResource(R.string.complete_recovery)) }
                    }
                }
            }
        }
        if (reset != null) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                    Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(stringResource(R.string.reset_credentials_title), fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.secondary)
                        Text(stringResource(R.string.provisioned_login_id) + ": " + reset!!.loginId)
                        Text(stringResource(R.string.provisioned_temporary_password) + ": " + reset!!.temporaryPassword, fontWeight = FontWeight.Bold)
                        Text(stringResource(R.string.provisioned_one_time_warning), style = MaterialTheme.typography.bodySmall)
                        TextButton(onClick = { reset = null }) { Text(stringResource(R.string.hide_credentials)) }
                    }
                }
            }
        }
        item {
            Divider()
            Text(stringResource(R.string.revoke_device_title), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            OutlinedTextField(accountId, { accountId = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.device_account_id_optional)) }, singleLine = true)
            OutlinedTextField(installationId, { installationId = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.device_installation_id)) }, singleLine = true)
            Button(
                onClick = {
                    scope.launch {
                        busy = true
                        runCatching { api.revokeDevice(session.accessToken, installationId, accountId.ifBlank { null }) }
                            .onSuccess { error = null; installationId = ""; accountId = "" }
                            .onFailure { error = it.message ?: "Révocation impossible." }
                        busy = false
                    }
                },
                enabled = !busy && installationId.isNotBlank(),
                modifier = Modifier.fillMaxWidth()
            ) { Text(stringResource(R.string.revoke_device)) }
        }
    }
}

@Composable
private fun DashboardContent(
    modifier: Modifier,
    name: String,
    role: String,
    locale: String,
    activityProfile: String?,
    localRepository: NaxaServicesLocalRepository,
    session: AuthSession,
    onNavigate: (AppRoute) -> Unit,
    onLogout: () -> Unit,
    tourActive: Boolean,
    tourStep: Int,
    onTourNext: () -> Unit,
    onTourSkip: () -> Unit,
    offlineLocal:Boolean
) {
    val dashboardContext = androidx.compose.ui.platform.LocalContext.current
    val syncApi = remember(dashboardContext) { AuthApi(dashboardContext) }
    val syncScope = rememberCoroutineScope()
    var syncBusy by remember { mutableStateOf(false) }
    var syncMessage by remember { mutableStateOf<String?>(null) }
    val syncEnabled = !offlineLocal && SupplierSyncCoordinator.isConfigured() && session.deviceId.isNotBlank()
    var hour by remember { mutableIntStateOf(Calendar.getInstance(java.util.TimeZone.getTimeZone("Africa/Douala")).get(Calendar.HOUR_OF_DAY)) }
    var nowMillis by remember { mutableStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            val clock = Calendar.getInstance(java.util.TimeZone.getTimeZone("Africa/Douala"))
            hour = clock.get(Calendar.HOUR_OF_DAY)
            nowMillis = System.currentTimeMillis()
            delay(60_000L)
        }
    }
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable(session.account.organizationId) {
        mutableStateOf(siteIds.firstOrNull().orEmpty())
    }
    val dayStartMillis = remember(nowMillis) {
        Calendar.getInstance(java.util.TimeZone.getTimeZone("Africa/Douala")).apply {
            timeInMillis = nowMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }
    val salesToday by remember(siteId, dayStartMillis, nowMillis) {
        localRepository.dao.observeSalesTotal(session.account.organizationId, siteId, dayStartMillis, nowMillis)
    }.collectAsState(initial = 0L)
    val expensesToday by remember(siteId, dayStartMillis, nowMillis) {
        localRepository.dao.observeExpensesTotal(session.account.organizationId, siteId, dayStartMillis, nowMillis)
    }.collectAsState(initial = 0L)
    val appointmentsToday by remember(siteId, dayStartMillis, nowMillis) {
        localRepository.dao.observeAppointmentCount(session.account.organizationId, siteId, dayStartMillis, nowMillis)
    }.collectAsState(initial = 0)
    val pressingTicketsToday by remember(siteId, dayStartMillis, nowMillis) {
        localRepository.dao.observePressingCount(session.account.organizationId, siteId, dayStartMillis, nowMillis)
    }.collectAsState(initial = 0)
    val inventoryItems by remember(siteId) {
        localRepository.dao.observeInventoryItems(session.account.organizationId, siteId)
    }.collectAsState(initial = emptyList())
    val pendingOperations by localRepository.dao.observePendingOutboxCount(session.account.organizationId)
        .collectAsState(initial = 0)
    val remoteReviewCount by localRepository.dao.observeRemoteReviewCount(session.account.organizationId)
        .collectAsState(initial = 0)
    val remoteChangesNeedingReview by localRepository.dao.observeRemoteChangesNeedingReview(session.account.organizationId)
        .collectAsState(initial = emptyList())
    val lowStockCount = inventoryItems.count { it.quantity <= it.reorderLevel }
    val siteLabels = session.account.activeSites.associate {
        it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel)
    }
    val greeting = if (locale == "ff-CM") {
        if (hour >= 18 || hour < 6) "Jam waali, $name" else "Jam weeti, $name"
    } else if (locale == "en") {
        if (hour >= 18 || hour < 6) "Good evening, $name" else "Good morning, $name"
    } else {
        if (hour >= 18 || hour < 6) "Bonsoir, $name" else "Bonjour, $name"
    }
    Box(modifier.fillMaxSize()) {
    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(greeting, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(role.replace('_', ' ').uppercase(), color = MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.labelMedium)
            Spacer(Modifier.height(6.dp))
        }
        item {
            DashboardHeroCarousel(locale, activityProfile) {
                onNavigate(if (activityProfile in setOf("couture","reparation","menuiserie","garage","nettoyage","domicile","impression","photo_evenementiel")) AppRoute.WORK_ORDERS else AppRoute.REPORTS)
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(22.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (locale == "en") "Today's activity" else "Activité du jour", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    AuthorizedSitePicker(siteIds, siteId, siteLabels) { siteId = it }
                    DashboardMetricRow(if (locale == "en") "Confirmed turnover" else "Chiffre d'affaires confirmé", dashboardXaf(salesToday))
                    DashboardMetricRow(if (locale == "en") "Journalized operating expenses" else "Charges d'exploitation journalisées", dashboardXaf(expensesToday))
                    DashboardMetricRow(if (locale == "en") "Indicative balance before stock costs and supplier settlements" else "Solde indicatif avant coût des ventes et règlements fournisseurs", dashboardXaf(salesToday - expensesToday))
                    if (activityProfile in setOf("coiffure", "beaute")) {
                        DashboardMetricRow(if (locale == "en") "Appointments today" else "Rendez-vous du jour", appointmentsToday.toString())
                    }
                    if (activityProfile == "pressing") {
                        DashboardMetricRow(if (locale == "en") "Laundry tickets today" else "Tickets pressing du jour", pressingTicketsToday.toString())
                    }
                    DashboardMetricRow(if (locale == "en") "Low-stock items" else "Articles sous seuil", lowStockCount.toString() + " / " + inventoryItems.size.toString())
                    DashboardMetricRow(if (locale == "en") "Pending local operations" else "Opérations locales en attente", pendingOperations.toString())
                    DashboardMetricRow(if (locale == "en") "Peer changes to review" else "Changements reçus à examiner", remoteReviewCount.toString())
                    if (remoteChangesNeedingReview.isNotEmpty()) {
                        Card(
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                            shape = RoundedCornerShape(16.dp)
                        ) {
                            Column(
                                Modifier.fillMaxWidth().padding(14.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text(
                                    if (locale == "en") "Synchronization review queue" else "File de revue de synchronisation",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold
                                )
                                remoteChangesNeedingReview.forEach { change ->
                                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                        Text(
                                            change.actionCode + " · " + change.aggregateType + " / " + change.aggregateId.take(12),
                                            style = MaterialTheme.typography.bodyMedium,
                                            fontWeight = FontWeight.SemiBold
                                        )
                                        Text(
                                            change.lastErrorCode ?: if (locale == "en") "Manual review required" else "Revue manuelle requise",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                                Text(
                                    if (locale == "en") "These changes are retained locally and not silently discarded. Resolve the business conflict before relying on this device's view." else "Ces changements sont conservés localement et ne sont pas supprimés. Résous le conflit métier avant de te fier à la vue de cet appareil.",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                    Button(
                        onClick = {
                            syncScope.launch {
                                syncBusy = true
                                syncMessage = null
                                try {
                                    val summary = runNaxaServicesSyncCycle(localRepository, syncApi, session)
                                    syncMessage = if (locale == "en") {
                                        "Sent: ${summary.outgoing.applied} · Received from peers: ${summary.incomingApplied} · Blocked: ${summary.outgoing.blocked} · Rejected: ${summary.outgoing.rejected} · Remaining: ${summary.outgoing.remaining}"
                                    } else {
                                        "Envoyées : ${summary.outgoing.applied} · Reçues des autres appareils : ${summary.incomingApplied} · Bloquées : ${summary.outgoing.blocked} · Rejetées : ${summary.outgoing.rejected} · Restantes : ${summary.outgoing.remaining}"
                                    }
                                } catch (cancelled: CancellationException) {
                                    throw cancelled
                                } catch (failure: Exception) {
                                    syncMessage = failure.message ?: if (locale == "en") "Synchronization failed." else "Échec de la synchronisation."
                                } finally {
                                    syncBusy = false
                                }
                            }
                        },
                        enabled = syncEnabled && !syncBusy,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(if (syncBusy) (if (locale == "en") "Synchronizing…" else "Synchronisation…") else (if (locale == "en") "Synchronize now" else "Synchroniser maintenant"))
                    }
                    if (syncMessage != null) {
                        Text(syncMessage!!, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                    }
                    if (!syncEnabled) {
                        Text(
                            if (locale == "en") "ERP sync remains disabled until the dedicated Famille NAXA endpoint and registered device are configured." else "L’actualisation est momentanément indisponible.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                    Text(
                        if (locale == "en")
                            "Available figures for this location, including operations pending confirmation."
                        else
                            "Chiffres disponibles pour ce point de vente, y compris les opérations en attente de confirmation.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }
        if (!offlineLocal && BuildConfig.BRIEFING_ENABLED) { item { DailyBriefingCard(session, siteId) } }
        if (!offlineLocal && BuildConfig.MEETINGS_ENABLED && rosterAvailable(session.account.businessMode)) { item { InternalMeetingsCard(session, siteId) } }
        if (!offlineLocal && BuildConfig.ROSTER_ENABLED && rosterAvailable(session.account.businessMode)) {
            item { StaffRosterCard(session, siteId) }
        }
        item {
            Text(stringResource(R.string.quick_actions), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        }
        items(visibleModuleSpecs(role, activityProfile).map { it.route }.filter { !offlineLocal || it in offlineLocalRoutes }
            .filter { it !in setOf(AppRoute.NETWORK, AppRoute.SITES, AppRoute.WORKSTATIONS, AppRoute.ORGANIZATION, AppRoute.SECURITY, AppRoute.SETTINGS, AppRoute.HELP, AppRoute.PROFILE, AppRoute.APPEARANCE, AppRoute.LIVECHAT, AppRoute.SUBSCRIPTIONS, AppRoute.TAXES, AppRoute.AI_INSIGHTS) }
            .distinct().take(8)) { target ->
            val spec = modules.firstOrNull { it.route == target }
            if (spec != null) {
                Card(onClick = { onNavigate(target) }, colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                    Row(Modifier.fillMaxWidth().padding(18.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(stringResource(spec.title), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                            Text(stringResource(spec.description), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                        }
                        Text("›", color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.headlineMedium)
                    }
                }
            }
        }
        item {
            TextButton(onClick = { onNavigate(AppRoute.MENU) }) { Text(stringResource(R.string.nav_more)) }
            TextButton(onClick = { onNavigate(AppRoute.PROFILE) }) { Text(localizedLabel("Mon profil","My profile","Humpito am")) }
            if (canAccessRoute(AppRoute.NETWORK, role)) {
                TextButton(onClick = { onNavigate(AppRoute.NETWORK) }) { Text(stringResource(R.string.network_overview)) }
            }
            if (canAccessRoute(AppRoute.SECURITY, role)) {
                TextButton(onClick = { onNavigate(AppRoute.SECURITY) }) { Text(stringResource(R.string.security_devices)) }
            }
            TextButton(onClick = onLogout) { Text(stringResource(R.string.sign_out)) }
            Spacer(Modifier.height(18.dp))
        }
    }
    if (tourActive) {
        FirstUseTourContent(locale, tourStep, onTourNext, onTourSkip)
    }
    }
}

private fun dashboardXaf(amount: Long): String =
    "%,d FCFA".format(amount).replace(',', ' ')

@Composable
private fun DashboardMetricRow(label: String, value: String) {
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, modifier = Modifier.weight(1f), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
    }
}

@Composable
private fun ModuleContent(modifier: Modifier, spec: ModuleSpec, onNavigate: (AppRoute) -> Unit) {
    var formOpen by remember(spec.route) { mutableStateOf(false) }
    var entry by remember(spec.route) { mutableStateOf("") }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(stringResource(spec.title), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(stringResource(spec.description), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.padding(18.dp)) {
                    Text(stringResource(R.string.module_status_title), fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(6.dp))
                    Text(stringResource(R.string.module_status_pending), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(stringResource(R.string.no_synced_data), color = MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.labelSmall)
                }
            }
        }
        item { Text(stringResource(R.string.available_workflows), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) }
        items(spec.actions) { action ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(stringResource(action), modifier = Modifier.weight(1f))
                    Text("›", color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.headlineSmall)
                }
            }
        }
        item {
            Button(onClick = { formOpen = true }, modifier = Modifier.fillMaxWidth().height(52.dp)) {
                Text(stringResource(spec.actions.firstOrNull() ?: R.string.action_create))
            }
            TextButton(onClick = { onNavigate(AppRoute.DASHBOARD) }) { Text(stringResource(R.string.back_dashboard)) }
            Spacer(Modifier.height(16.dp))
        }
    }
    if (formOpen) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { formOpen = false },
            title = { Text(stringResource(R.string.form_prepare_title)) },
            text = {
                Column {
                    Text(stringResource(R.string.form_prepare_explainer), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(10.dp))
                    OutlinedTextField(entry, { entry = it }, label = { Text(stringResource(R.string.form_reference)) }, singleLine = true)
                }
            },
            confirmButton = {
                TextButton(onClick = { formOpen = false; entry = "" }) { Text(stringResource(R.string.close)) }
            },
            dismissButton = {
                TextButton(onClick = { formOpen = false }) { Text(stringResource(R.string.cancel)) }
            }
        )
    }
}

@Composable
private fun ModuleMenu(modifier: Modifier, roleCode: String, activityProfile: String?, onNavigate: (AppRoute) -> Unit, onLogout: () -> Unit,offlineLocal:Boolean) {
    val visibleModules = visibleModuleSpecs(roleCode, activityProfile).filter { !offlineLocal || it.route in offlineLocalRoutes }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(stringResource(R.string.all_modules), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        }
        items(visibleModules) { spec ->
            Card(onClick = { onNavigate(spec.route) }, colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp)) {
                    Text(stringResource(spec.title), fontWeight = FontWeight.Bold)
                    Text(stringResource(spec.description), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
        item {
            TextButton(onClick = onLogout) { Text(stringResource(R.string.sign_out)) }
            Spacer(Modifier.height(16.dp))
        }
    }
}
