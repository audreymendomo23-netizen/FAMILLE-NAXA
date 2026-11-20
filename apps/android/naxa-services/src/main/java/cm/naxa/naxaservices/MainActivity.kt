package cm.naxa.naxaservices

import android.os.Bundle

import androidx.room.Room
import androidx.compose.runtime.collectAsState
import cm.naxa.naxaservices.data.NsServicesDatabase
import cm.naxa.naxaservices.data.NaxaServicesLocalRepository
import cm.naxa.naxaservices.data.LocalPressingOrder
import cm.naxa.naxaservices.data.LocalAppointment
import cm.naxa.naxaservices.data.LocalCashSession
import cm.naxa.naxaservices.data.LocalSale
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
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
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.weight
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
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { NaxaServicesTheme { NaxaServicesRoot() } }
    }
}

internal enum class AppRoute {
    LOGIN, RECOVERY, CHANGE_PASSWORD, DASHBOARD, AGENDA, PRESSING, CASH,
    SERVICES, CUSTOMERS, TEAM, STOCK, REPORTS, ORGANIZATION, NETWORK,
    SITES, WORKSTATIONS, SECURITY, SETTINGS, HELP, MENU
}

@Composable
private fun NaxaServicesRoot() {
    val context = androidx.compose.ui.platform.LocalContext.current
    val api = remember { AuthApi(context) }
    val vault = remember { SessionVault(context) }
    val localDatabase = remember { Room.databaseBuilder(context, NsServicesDatabase::class.java, "naxa-services-local.db").build() }
    val localRepository = remember { NaxaServicesLocalRepository(localDatabase) }
    val scope = rememberCoroutineScope()

    var route by rememberSaveable { mutableStateOf(AppRoute.LOGIN.name) }
    var session by remember { mutableStateOf<AuthSession?>(null) }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var pendingRefresh by remember { mutableStateOf<String?>(null) }
    var rememberSession by rememberSaveable { mutableStateOf(false) }
    var lightTheme by rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        pendingRefresh = vault.loadRefreshToken()
        if (!pendingRefresh.isNullOrBlank()) {
            rememberSession = true
            busy = true
            runCatching { api.refresh(pendingRefresh!!, rememberDevice = true) }
                .onSuccess {
                    session = it
                    vault.save(it)
                    route = if (it.requirePasswordChange) AppRoute.CHANGE_PASSWORD.name else AppRoute.DASHBOARD.name
                }
                .onFailure {
                    vault.clear()
                    rememberSession = false
                    route = AppRoute.LOGIN.name
                }
            busy = false
        }
    }

    LaunchedEffect(session?.refreshToken) {
        var activeSession = session
        while (activeSession != null) {
            val waitSeconds = (activeSession.expiresIn - 60L).coerceAtLeast(30L)
            delay(waitSeconds * 1000L)
            var retry = 0
            var refreshed = false
            while (retry < 5 && !refreshed) {
                val token = activeSession?.refreshToken ?: break
                runCatching { api.refresh(token, rememberDevice = rememberSession) }
                    .onSuccess { next ->
                        session = next
                        if (vault.loadRefreshToken() != null) vault.save(next)
                        activeSession = next
                        refreshed = true
                    }
                    .onFailure { error ->
                        val authError = error as? AuthApiException
                        if (authError?.statusCode == 401 || authError?.statusCode == 403) {
                            vault.clear()
                            rememberSession = false
                            session = null
                            route = AppRoute.LOGIN.name
                            message = "Session expirée ou révoquée. Connecte-toi à nouveau."
                            activeSession = null
                        } else {
                            retry += 1
                            delay(30_000L)
                        }
                    }
            }
            if (!refreshed && activeSession != null) {
                message = "La session n'a pas pu être renouvelée. Vérifie le réseau avant de continuer."
                activeSession = null
            }
        }
    }

    val onLogin: (String, String, Boolean) -> Unit = { identifier, password, rememberMe ->
        scope.launch {
            busy = true
            message = null
            runCatching { api.login(identifier, password, rememberMe) }
                .onSuccess {
                    session = it
                    rememberSession = rememberMe
                    if (rememberMe) vault.save(it) else vault.clear()
                    route = if (it.requirePasswordChange) AppRoute.CHANGE_PASSWORD.name else AppRoute.DASHBOARD.name
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
                        route = AppRoute.DASHBOARD.name
                        message = "Mot de passe mis à jour."
                    }
                    .onFailure { message = it.message ?: "Modification impossible." }
                busy = false
            }
        }
    }

    NaxaServicesTheme(light = lightTheme) {
        Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
            when (AppRoute.valueOf(route)) {
                AppRoute.LOGIN -> LoginScreen(busy, message, onLogin, { route = AppRoute.RECOVERY.name })
                AppRoute.RECOVERY -> RecoveryScreen(busy, message, onRecovery, { route = AppRoute.LOGIN.name })
                AppRoute.CHANGE_PASSWORD -> ChangePasswordScreen(busy, message, onChangePassword)
                else -> {
                    val active = session
                    if (active == null) {
                        route = AppRoute.LOGIN.name
                    } else {
                        ErpScreen(
                            route = AppRoute.valueOf(route),
                            authApi = api,
                            activeSession = active,
                            localRepository = localRepository,
                            accountName = active.account.displayName,
                            roleCode = active.account.roleCode,
                            lightTheme = lightTheme,
                            onTheme = { lightTheme = !lightTheme },
                            onNavigate = { route = it.name },
                            onLogout = {
                                scope.launch {
                                    runCatching { api.logout(active.accessToken) }
                                    vault.clear()
                                    rememberSession = false
                                    session = null
                                    route = AppRoute.LOGIN.name
                                }
                            },
                            message = message,
                            onDismissMessage = { message = null }
                        )
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
    onLogin: (String, String, Boolean) -> Unit,
    onForgot: () -> Unit
) {
    var identifier by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var rememberMe by rememberSaveable { mutableStateOf(false) }
    var showPassword by rememberSaveable { mutableStateOf(false) }

    Column(
        Modifier.fillMaxSize().padding(horizontal = 26.dp, vertical = 30.dp),
        verticalArrangement = Arrangement.Center
    ) {
        NaxaServicesWordmark()
        Spacer(Modifier.height(36.dp))
        Text(stringResource(R.string.login_title), style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text(stringResource(R.string.login_subtitle), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(26.dp))
        OutlinedTextField(
            value = identifier, onValueChange = { identifier = it.uppercase() },
            modifier = Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.login_identifier)) },
            placeholder = { Text("NS-000000") }, singleLine = true
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = password, onValueChange = { password = it },
            modifier = Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.password)) },
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
            modifier = Modifier.fillMaxWidth().height(54.dp)
        ) {
            if (busy) CircularProgressIndicator(Modifier.size(20.dp), color = MaterialTheme.colorScheme.onPrimary, strokeWidth = 2.dp)
            else Text(stringResource(R.string.sign_in))
        }
        TextButton(onClick = onForgot, modifier = Modifier.align(Alignment.CenterHorizontally)) {
            Text(stringResource(R.string.forgot_password))
        }
        Text(stringResource(R.string.no_public_signup), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.labelSmall)
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
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center) {
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
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center) {
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
    ModuleSpec(AppRoute.CASH, R.string.module_cash, R.string.cash_desc, listOf(R.string.action_new_sale, R.string.action_open_cash, R.string.action_close_cash, R.string.action_expense)),
    ModuleSpec(AppRoute.SERVICES, R.string.module_services, R.string.services_desc, listOf(R.string.action_add_service, R.string.action_price_lists, R.string.action_packages)),
    ModuleSpec(AppRoute.CUSTOMERS, R.string.module_customers, R.string.customers_desc, listOf(R.string.action_new_customer, R.string.action_history, R.string.action_loyalty)),
    ModuleSpec(AppRoute.TEAM, R.string.module_team, R.string.team_desc, listOf(R.string.action_add_member, R.string.action_assign, R.string.action_commissions, R.string.action_attendance)),
    ModuleSpec(AppRoute.STOCK, R.string.module_stock, R.string.stock_desc, listOf(R.string.action_inventory, R.string.action_consumption, R.string.action_low_stock)),
    ModuleSpec(AppRoute.REPORTS, R.string.module_reports, R.string.reports_desc, listOf(R.string.action_daily_report, R.string.action_cash_report, R.string.action_export)),
    ModuleSpec(AppRoute.ORGANIZATION, R.string.module_organization, R.string.organization_desc, listOf(R.string.action_business_profile, R.string.action_subscription, R.string.action_permissions)),
    ModuleSpec(AppRoute.NETWORK, R.string.module_network, R.string.network_desc, listOf(R.string.action_site_overview, R.string.action_consolidation, R.string.action_transfer)),
    ModuleSpec(AppRoute.SITES, R.string.module_sites, R.string.sites_desc, listOf(R.string.action_add_site, R.string.action_site_settings, R.string.action_site_team)),
    ModuleSpec(AppRoute.WORKSTATIONS, R.string.module_workstations, R.string.workstations_desc, listOf(R.string.action_add_workstation, R.string.action_assign_staff, R.string.action_workstation_schedule)),
    ModuleSpec(AppRoute.SECURITY, R.string.module_security, R.string.security_desc, listOf(R.string.action_devices, R.string.action_recovery_queue, R.string.action_access_log)),
    ModuleSpec(AppRoute.SETTINGS, R.string.module_settings, R.string.settings_desc, listOf(R.string.action_language, R.string.action_theme, R.string.action_offline)),
    ModuleSpec(AppRoute.HELP, R.string.module_help, R.string.help_desc, listOf(R.string.action_faq, R.string.action_contact_support, R.string.action_briefings))
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ErpScreen(
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
    onDismissMessage: () -> Unit
) {
    val currentSpec = modules.firstOrNull { it.route == route }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Column { Text("NAXA SERVICES", fontWeight = FontWeight.Black); Text(accountName, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant) } },
                actions = { TextButton(onClick = onTheme) { Text(if (lightTheme) stringResource(R.string.dark_mode) else stringResource(R.string.light_mode)) } }
            )
        },
        bottomBar = {
            NavigationBar {
                NavigationBarItem(selected = route == AppRoute.DASHBOARD, onClick = { onNavigate(AppRoute.DASHBOARD) }, icon = { Text("⌂") }, label = { Text(stringResource(R.string.nav_home)) })
                NavigationBarItem(selected = route == AppRoute.AGENDA, onClick = { onNavigate(AppRoute.AGENDA) }, icon = { Text("◷") }, label = { Text(stringResource(R.string.nav_agenda)) })
                NavigationBarItem(selected = route == AppRoute.PRESSING, onClick = { onNavigate(AppRoute.PRESSING) }, icon = { Text("▤") }, label = { Text(stringResource(R.string.nav_pressing)) })
                NavigationBarItem(selected = route == AppRoute.CASH, onClick = { onNavigate(AppRoute.CASH) }, icon = { Text("₣") }, label = { Text(stringResource(R.string.nav_cash)) })
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
        if (route == AppRoute.DASHBOARD) {
            DashboardContent(Modifier.padding(padding), accountName, roleCode, onNavigate, onLogout)
        } else if (route == AppRoute.MENU) {
            ModuleMenu(Modifier.padding(padding), onNavigate, onLogout)
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
        } else if (route == AppRoute.STOCK) {
            StockContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.REPORTS) {
            ReportsContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.ORGANIZATION || route == AppRoute.NETWORK || route == AppRoute.SITES || route == AppRoute.WORKSTATIONS) {
            OrganizationWorkspaceContent(Modifier.padding(padding), route, localRepository, authApi, activeSession)
        } else if (route == AppRoute.HELP) {
            SupportContent(Modifier.padding(padding), localRepository, activeSession)
        } else if (route == AppRoute.SETTINGS) {
            SettingsContent(Modifier.padding(padding), localRepository, activeSession, lightTheme, onTheme)
        } else if (currentSpec != null) {
            ModuleContent(Modifier.padding(padding), currentSpec, onNavigate)
        } else {
            ModuleMenu(Modifier.padding(padding), onNavigate, onLogout)
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
    var siteId by rememberSaveable { mutableStateOf(session.account.activeSiteIds.firstOrNull().orEmpty()) }
    var customer by rememberSaveable { mutableStateOf("") }
    var phone by rememberSaveable { mutableStateOf("") }
    var garments by rememberSaveable { mutableStateOf("") }
    var total by rememberSaveable { mutableStateOf("") }
    var deposit by rememberSaveable { mutableStateOf("0") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val orders by remember(siteId) { repository.dao.observePressingOrders(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(stringResource(R.string.pressing_local_title), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.pressing_local_desc), color = MaterialTheme.colorScheme.onSurfaceVariant)
            AuthorizedSitePicker(
                session.account.activeSiteIds,
                siteId,
                session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }
            ) { siteId = it }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(siteId, { siteId = it.trim() }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.member_site_id)) }, singleLine = true)
                    OutlinedTextField(workstationId, { workstationId = it.trim() }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.member_workstation_id_optional)) }, singleLine = true)
                    OutlinedTextField(customer, { customer = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.customer_name)) }, singleLine = true)
                    OutlinedTextField(phone, { phone = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.customer_phone)) }, singleLine = true)
                    OutlinedTextField(garments, { garments = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.pressing_items_summary)) }, minLines = 2)
                    OutlinedTextField(total, { total = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.total_amount_xaf)) }, singleLine = true)
                    OutlinedTextField(deposit, { deposit = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.deposit_amount_xaf)) }, singleLine = true)
                    if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                    Button(
                        onClick = {
                            scope.launch {
                                busy = true
                                error = null
                                runCatching {
                                    repository.createPressingOrder(
                                        orgId = session.account.organizationId,
                                        siteId = siteId,
                                        workstationId = workstationId.ifBlank { null },
                                        customerName = customer,
                                        customerPhone = phone,
                                        itemsSummary = garments,
                                        totalXaf = total.toLong(),
                                        depositXaf = deposit.toLongOrNull() ?: 0L,
                                        promisedAtMillis = System.currentTimeMillis() + 24L * 60L * 60L * 1000L,
                                        actorMemberId = session.account.memberId
                                    )
                                }.onSuccess {
                                    customer = ""
                                    phone = ""
                                    garments = ""
                                    total = ""
                                    deposit = "0"
                                }.onFailure { error = it.message ?: "Création du ticket impossible." }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && customer.isNotBlank() && garments.isNotBlank() && (total.toLongOrNull() ?: 0L) > 0,
                        modifier = Modifier.fillMaxWidth()
                    ) { if (busy) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = MaterialTheme.colorScheme.onPrimary) else Text(stringResource(R.string.create_pressing_ticket)) }
                    Text(stringResource(R.string.local_outbox_notice), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
        item { Text(stringResource(R.string.local_pressing_tickets), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (orders.isEmpty()) {
            item { Text(stringResource(R.string.no_local_pressing_tickets), color = MaterialTheme.colorScheme.onSurfaceVariant) }
        } else {
            items(orders) { order ->
                PressingOrderCard(order = order, onAdvance = {
                    scope.launch {
                        runCatching { repository.advancePressingOrder(order, session.account.memberId) }
                            .onFailure { error = it.message }
                    }
                })
            }
        }
    }
}

@Composable
private fun PressingOrderCard(order: LocalPressingOrder, onAdvance: () -> Unit) {
    val status = when (order.status) {
        "received" -> stringResource(R.string.pressing_status_received)
        "in_progress" -> stringResource(R.string.pressing_status_in_progress)
        "ready" -> stringResource(R.string.pressing_status_ready)
        "picked_up" -> stringResource(R.string.pressing_status_picked_up)
        else -> order.status
    }
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                Text(order.ticketNumber, fontWeight = FontWeight.Bold)
                Text(status, color = MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.labelMedium)
            }
            Text(order.customerName, style = MaterialTheme.typography.titleMedium)
            Text(order.itemsSummary, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
            Text(stringResource(R.string.pressing_total_and_deposit, order.totalXaf, order.depositXaf), style = MaterialTheme.typography.bodySmall)
            if (order.status != "picked_up") {
                Button(onClick = onAdvance, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.advance_pressing_status)) }
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
    var siteId by rememberSaveable { mutableStateOf(session.account.activeSiteIds.firstOrNull().orEmpty()) }
    var workstationId by rememberSaveable { mutableStateOf("") }
    var customer by rememberSaveable { mutableStateOf("") }
    var service by rememberSaveable { mutableStateOf("") }
    var duration by rememberSaveable { mutableStateOf("30") }
    var start by rememberSaveable { mutableStateOf(SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date(System.currentTimeMillis() + 60L * 60L * 1000L))) }
    var deposit by rememberSaveable { mutableStateOf("0") }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    val appointments by remember(siteId) { repository.dao.observeAppointments(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(stringResource(R.string.agenda_local_title), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.agenda_local_desc), color = MaterialTheme.colorScheme.onSurfaceVariant)
            AuthorizedSitePicker(session.account.activeSiteIds, siteId, session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }) { siteId = it }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(siteId, { siteId = it.trim() }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.member_site_id)) }, singleLine = true)
                    OutlinedTextField(workstationId, { workstationId = it.trim() }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.member_workstation_id_optional)) }, singleLine = true)
                    OutlinedTextField(customer, { customer = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.customer_name)) }, singleLine = true)
                    OutlinedTextField(service, { service = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.service_name)) }, singleLine = true)
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
                                        ?: throw IllegalArgumentException("Date/heure invalide. Format attendu : AAAA-MM-JJ HH:MM.")
                                    val durationMinutes = duration.toLongOrNull() ?: throw IllegalArgumentException("Durée invalide.")
                                    require(durationMinutes in 5..600) { "La durée doit être comprise entre 5 et 600 minutes." }
                                    repository.createAppointment(
                                        orgId = session.account.organizationId,
                                        siteId = siteId,
                                        workstationId = workstationId.ifBlank { null },
                                        customerName = customer,
                                        serviceName = service,
                                        assignedMemberId = session.account.memberId,
                                        startsAtMillis = startAt,
                                        endsAtMillis = startAt + durationMinutes * 60_000L,
                                        depositXaf = deposit.toLongOrNull() ?: 0L,
                                        actorMemberId = session.account.memberId
                                    )
                                }.onSuccess { customer = ""; service = ""; deposit = "0" }
                                    .onFailure { error = it.message ?: "Rendez-vous impossible." }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && customer.isNotBlank() && service.isNotBlank(),
                        modifier = Modifier.fillMaxWidth()
                    ) { if (busy) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = MaterialTheme.colorScheme.onPrimary) else Text(stringResource(R.string.create_appointment)) }
                    Text(stringResource(R.string.appointment_conflict_local_only), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
        item { Text(stringResource(R.string.appointments_local_list), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (appointments.isEmpty()) item { Text(stringResource(R.string.no_local_appointments), color = MaterialTheme.colorScheme.onSurfaceVariant) }
        else items(appointments) { appointment ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text(appointment.customerName, fontWeight = FontWeight.Bold)
                    Text(appointment.serviceName)
                    Text(SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.getDefault()).format(Date(appointment.startsAtMillis)), color = MaterialTheme.colorScheme.secondary)
                    Text(stringResource(R.string.appointment_local_status, appointment.status), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
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
    val pendingOutbox by repository.dao.observePendingOutboxCount(session.account.organizationId).collectAsState(initial = 0)
    val openSession = sessions.firstOrNull { it.status == "open" }

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
                                    }.onSuccess { notice = "Caisse ouverte localement : " + it.id }
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
                        OutlinedTextField(saleDescription, { saleDescription = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.sale_description)) }, singleLine = true)
                        OutlinedTextField(saleTotal, { saleTotal = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.sale_total_xaf)) }, singleLine = true)
                        OutlinedTextField(paymentMethod, { paymentMethod = it.trim().lowercase() }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.payment_method_cash_or_momo)) }, singleLine = true)
                        Button(
                            onClick = {
                                scope.launch {
                                    busy = true
                                    error = null
                                    runCatching {
                                        repository.recordSale(session.account.organizationId, siteId, openSession.id, saleDescription, saleTotal.toLong(), paymentMethod, session.account.memberId)
                                    }.onSuccess { pair ->
                                        saleDescription = ""
                                        saleTotal = ""
                                        notice = if (pair.second.status == "pending") "Paiement Mobile Money en attente de confirmation serveur." else "Encaissement espèces enregistré localement."
                                    }.onFailure { error = it.message ?: "Vente impossible." }
                                    busy = false
                                }
                            },
                            enabled = !busy && saleDescription.isNotBlank() && (saleTotal.toLongOrNull() ?: 0L) > 0 && paymentMethod in setOf("cash", "mobile_money"),
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
                                    }.onSuccess { expenseCategory = ""; expenseDescription = ""; expenseAmount = ""; notice = "Dépense ajoutée à la file locale." }
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
                                    }.onSuccess { notice = "Clôture locale terminée. Écart : " + (it.varianceXaf ?: 0L) + " FCFA." }
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
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Row(Modifier.fillMaxWidth().padding(14.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(sale.description, fontWeight = FontWeight.Bold)
                        Text(sale.saleNumber + " · " + sale.status, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                    }
                    Text(sale.totalXaf.toString() + " F")
                }
            }
        }
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
    var workstationId by rememberSaveable { mutableStateOf("") }
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
                            Text("Rôle à attribuer : " + role.replace('_', ' '))
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
                        Text("Ton rôle ne permet pas de créer des comptes collaborateurs.", color = MaterialTheme.colorScheme.error)
                    }
                    Text("Affectation aux points de vente autorisés", fontWeight = FontWeight.SemiBold)
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
                    Text(
                        "Un collaborateur peut recevoir plusieurs points de vente. L’accès individuel à un poste précis sera activé après le filtrage dédié de ses données.",
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

private fun DashboardContent(
    modifier: Modifier,
    name: String,
    role: String,
    onNavigate: (AppRoute) -> Unit,
    onLogout: () -> Unit
) {
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(stringResource(R.string.dashboard_greeting, name), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(role.replace('_', ' ').uppercase(), color = MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.labelMedium)
            Spacer(Modifier.height(6.dp))
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(22.dp)) {
                Column(Modifier.padding(18.dp)) {
                    Text(stringResource(R.string.dashboard_today), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                    Text(stringResource(R.string.no_synced_data), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(stringResource(R.string.backend_pending), color = MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.labelSmall)
                }
            }
        }
        item {
            Text(stringResource(R.string.quick_actions), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        }
        items(listOf(AppRoute.CASH, AppRoute.PRESSING, AppRoute.AGENDA, AppRoute.SERVICES, AppRoute.CUSTOMERS, AppRoute.TEAM)) { target ->
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
            TextButton(onClick = { onNavigate(AppRoute.NETWORK) }) { Text(stringResource(R.string.network_overview)) }
            TextButton(onClick = { onNavigate(AppRoute.SECURITY) }) { Text(stringResource(R.string.security_devices)) }
            TextButton(onClick = onLogout) { Text(stringResource(R.string.sign_out)) }
            Spacer(Modifier.height(18.dp))
        }
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
private fun ModuleMenu(modifier: Modifier, onNavigate: (AppRoute) -> Unit, onLogout: () -> Unit) {
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(stringResource(R.string.all_modules), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        }
        items(modules) { spec ->
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
