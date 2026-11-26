package cm.naxa.bootik

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.room.Room
import androidx.room.withTransaction
import cm.naxa.bootik.data.BootikActivityDraftEntity
import cm.naxa.bootik.data.BootikLocalDatabase
import cm.naxa.bootik.data.BootikSiteActivityDraftEntity
import cm.naxa.bootik.data.BootikSiteDraftEntity
import cm.naxa.bootik.data.BootikWorkspaceDraftEntity
import cm.naxa.bootik.domain.RetailProfileCode
import java.util.UUID
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val database = Room.databaseBuilder(
            applicationContext,
            BootikLocalDatabase::class.java,
            "bootik-local.db"
        ).build()

        setContent {
            BootikTheme {
                BootikSetupScreen(database = database)
            }
        }
    }
}

private data class RetailProfileOption(
    val code: RetailProfileCode,
    val titleRes: Int,
    val descriptionRes: Int
)

private val retailProfileOptions = listOf(
    RetailProfileOption(RetailProfileCode.BOUTIQUE, R.string.profile_boutique, R.string.profile_boutique_desc),
    RetailProfileOption(RetailProfileCode.SUPERETTE, R.string.profile_superette, R.string.profile_superette_desc),
    RetailProfileOption(RetailProfileCode.POISSONNERIE, R.string.profile_poissonnerie, R.string.profile_poissonnerie_desc),
    RetailProfileOption(RetailProfileCode.BOULANGERIE, R.string.profile_boulangerie, R.string.profile_boulangerie_desc),
    RetailProfileOption(RetailProfileCode.SHOPPING, R.string.profile_shopping, R.string.profile_shopping_desc),
    RetailProfileOption(RetailProfileCode.ALIMENTATION, R.string.profile_alimentation, R.string.profile_alimentation_desc),
    RetailProfileOption(RetailProfileCode.CAVE, R.string.profile_cave, R.string.profile_cave_desc),
    RetailProfileOption(RetailProfileCode.QUINCAILLERIE, R.string.profile_quincaillerie, R.string.profile_quincaillerie_desc),
    RetailProfileOption(RetailProfileCode.PARFUMERIE, R.string.profile_parfumerie, R.string.profile_parfumerie_desc),
    RetailProfileOption(RetailProfileCode.BOUCHERIE, R.string.profile_boucherie, R.string.profile_boucherie_desc),
    RetailProfileOption(RetailProfileCode.FERME, R.string.profile_ferme, R.string.profile_ferme_desc),
    RetailProfileOption(RetailProfileCode.DEPOT_GAZ, R.string.profile_depot_gaz, R.string.profile_depot_gaz_desc),
    RetailProfileOption(RetailProfileCode.SUPERMARCHE, R.string.profile_supermarche, R.string.profile_supermarche_desc),
    RetailProfileOption(RetailProfileCode.BROCANTE, R.string.profile_brocante, R.string.profile_brocante_desc)
)

@Composable
private fun BootikSetupScreen(database: BootikLocalDatabase) {
    val context = LocalContext.current
    val dao = remember(database) { database.drafts() }
    val workspaceDrafts by dao.observeWorkspaceDrafts().collectAsState(initial = emptyList())
    val scope = rememberCoroutineScope()

    var businessName by rememberSaveable { mutableStateOf("") }
    var siteName by rememberSaveable { mutableStateOf("") }
    var selectedProfileCode by rememberSaveable { mutableStateOf(RetailProfileCode.BOUTIQUE.code) }
    var statusMessage by rememberSaveable { mutableStateOf<String?>(null) }
    var saving by rememberSaveable { mutableStateOf(false) }

    val canSave = businessName.isNotBlank() &&
        siteName.isNotBlank() &&
        RetailProfileCode.fromCode(selectedProfileCode) != null &&
        !saving

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize().testTag("bootik-setup-list"),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(18.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Card(
                    shape = RoundedCornerShape(24.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primary)
                ) {
                    Column(Modifier.fillMaxWidth().padding(22.dp)) {
                        Text(
                            text = stringResource(R.string.app_name),
                            color = MaterialTheme.colorScheme.onPrimary,
                            style = MaterialTheme.typography.headlineMedium,
                            fontWeight = FontWeight.Black
                        )
                        Spacer(Modifier.height(6.dp))
                        Text(
                            text = stringResource(R.string.setup_subtitle),
                            color = MaterialTheme.colorScheme.onPrimary
                        )
                    }
                }
            }

            item {
                Card(
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                ) {
                    Column(Modifier.fillMaxWidth().padding(16.dp)) {
                        Text(
                            stringResource(R.string.universe_retailer),
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            stringResource(R.string.universe_retailer_desc),
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(Modifier.height(14.dp))
                        Text(
                            stringResource(R.string.universe_distributor),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            stringResource(R.string.universe_distributor_next),
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        stringResource(R.string.setup_workspace_title),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold
                    )
                    OutlinedTextField(
                        value = businessName,
                        onValueChange = { businessName = it; statusMessage = null },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.business_name)) },
                        singleLine = true
                    )
                    OutlinedTextField(
                        value = siteName,
                        onValueChange = { siteName = it; statusMessage = null },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.site_name)) },
                        singleLine = true
                    )
                    Text(
                        stringResource(R.string.profile_selection_title),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            items(retailProfileOptions, key = { it.code.code }) { option ->
                val isSelected = selectedProfileCode == option.code.code
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            selectedProfileCode = option.code.code
                            statusMessage = null
                        },
                    shape = RoundedCornerShape(16.dp),
                    border = if (isSelected) BorderStroke(2.dp, MaterialTheme.colorScheme.secondary) else null,
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = isSelected,
                            onClick = {
                                selectedProfileCode = option.code.code
                                statusMessage = null
                            }
                        )
                        Column(Modifier.weight(1f)) {
                            Text(stringResource(option.titleRes), fontWeight = FontWeight.SemiBold)
                            Text(
                                stringResource(option.descriptionRes),
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                    }
                }
            }

            item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = {
                            val profile = RetailProfileCode.fromCode(selectedProfileCode) ?: return@Button
                            val now = System.currentTimeMillis()
                            val workspaceId = UUID.randomUUID().toString()
                            val activityId = UUID.randomUUID().toString()
                            val siteId = UUID.randomUUID().toString()
                            val workspace = BootikWorkspaceDraftEntity(
                                id = workspaceId,
                                displayName = businessName.trim(),
                                createdAtEpochMs = now,
                                updatedAtEpochMs = now
                            )
                            val activity = BootikActivityDraftEntity(
                                id = activityId,
                                workspaceId = workspaceId,
                                profileCode = profile.code,
                                displayName = businessName.trim(),
                                createdAtEpochMs = now
                            )
                            val site = BootikSiteDraftEntity(
                                id = siteId,
                                workspaceId = workspaceId,
                                code = "LOCAL-001",
                                displayName = siteName.trim(),
                                createdAtEpochMs = now
                            )

                            scope.launch {
                                saving = true
                                statusMessage = null
                                runCatching {
                                    database.withTransaction {
                                        dao.insertWorkspace(workspace)
                                        dao.insertActivity(activity)
                                        dao.insertSite(site)
                                        dao.linkSiteToActivity(
                                            BootikSiteActivityDraftEntity(
                                                siteId = siteId,
                                                activityId = activityId
                                            )
                                        )
                                    }
                                }.onSuccess {
                                    statusMessage = context.getString(R.string.local_draft_saved)
                                    businessName = ""
                                    siteName = ""
                                }.onFailure {
                                    statusMessage = context.getString(R.string.local_draft_error)
                                }
                                saving = false
                            }
                        },
                        enabled = canSave,
                        modifier = Modifier.fillMaxWidth().height(52.dp),
                        shape = RoundedCornerShape(14.dp)
                    ) {
                        Text(stringResource(R.string.save_local_draft))
                    }
                    if (!statusMessage.isNullOrBlank()) {
                        Text(
                            statusMessage.orEmpty(),
                            color = MaterialTheme.colorScheme.primary,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                    Text(
                        stringResource(R.string.local_only_warning),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }

            item {
                Text(
                    stringResource(R.string.local_drafts_title),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
            }

            if (workspaceDrafts.isEmpty()) {
                item {
                    Text(
                        stringResource(R.string.no_local_drafts),
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                items(workspaceDrafts, key = { it.id }) { draft ->
                    Card(
                        shape = RoundedCornerShape(14.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                    ) {
                        Column(Modifier.fillMaxWidth().padding(14.dp)) {
                            Text(draft.displayName, fontWeight = FontWeight.SemiBold)
                            Text(
                                stringResource(R.string.local_draft_state),
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                    }
                }
            }
        }
    }
}
