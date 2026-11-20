package cm.naxa.naxaservices.data

import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Index
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.RoomDatabase
import androidx.room.Update
import androidx.room.withTransaction
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import kotlinx.coroutines.flow.Flow
import java.util.UUID

@Entity(tableName = "local_pressing_orders", indices = [Index(value = ["siteId"]), Index(value = ["ticketNumber"], unique = true)])
data class LocalPressingOrder(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val workstationId: String?,
    val ticketNumber: String,
    val customerName: String,
    val customerPhone: String,
    val itemsSummary: String,
    val totalXaf: Long,
    val depositXaf: Long,
    val promisedAtMillis: Long,
    val status: String = "received",
    val actorMemberId: String,
    val createdAtMillis: Long,
    val updatedAtMillis: Long
)

@Entity(tableName = "local_pressing_status_events", indices = [Index(value = ["orderId"]), Index(value = ["createdAtMillis"])])
data class LocalPressingStatusEvent(
    @PrimaryKey val id: String,
    val orderId: String,
    val orgId: String,
    val siteId: String,
    val fromStatus: String,
    val toStatus: String,
    val actorMemberId: String,
    val createdAtMillis: Long
)

@Entity(tableName = "local_appointments", indices = [Index(value = ["siteId"]), Index(value = ["startsAtMillis"])])
data class LocalAppointment(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val workstationId: String?,
    val customerName: String,
    val serviceName: String,
    val assignedMemberId: String,
    val startsAtMillis: Long,
    val endsAtMillis: Long,
    val depositXaf: Long,
    val status: String = "booked",
    val actorMemberId: String,
    val createdAtMillis: Long
)

@Entity(tableName = "local_cash_sessions", indices = [Index(value = ["siteId", "registerId", "status"])])
data class LocalCashSession(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val registerId: String,
    val registerName: String,
    val openingFloatXaf: Long,
    val openedByMemberId: String,
    val openedAtMillis: Long,
    val status: String = "open",
    val closedByMemberId: String? = null,
    val closedAtMillis: Long? = null,
    val countedCloseXaf: Long? = null,
    val varianceXaf: Long? = null,
    val varianceReason: String? = null
)

@Entity(tableName = "local_sales", indices = [Index(value = ["siteId"]), Index(value = ["cashSessionId"]), Index(value = ["createdAtMillis"])])
data class LocalSale(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val cashSessionId: String,
    val saleNumber: String,
    val description: String,
    val totalXaf: Long,
    val paymentMethod: String,
    val status: String,
    val actorMemberId: String,
    val createdAtMillis: Long
)

@Entity(tableName = "local_expenses", indices = [Index(value = ["siteId"]), Index(value = ["cashSessionId"]), Index(value = ["createdAtMillis"])])
data class LocalExpense(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val cashSessionId: String,
    val category: String,
    val description: String,
    val amountXaf: Long,
    val actorMemberId: String,
    val createdAtMillis: Long
)

@Entity(tableName = "local_outbox_events", indices = [Index(value = ["orgId", "state", "deviceSequence"])])
data class LocalOutboxEvent(
    @PrimaryKey val eventId: String,
    val appId: String = "naxa-services",
    val orgId: String,
    val aggregateType: String,
    val aggregateId: String,
    val actionCode: String,
    val payloadJson: String,
    val deviceSequence: Long,
    val createdAtEpochMs: Long,
    val state: String = "queued"
)

@Entity(tableName = "local_organization_profiles")
data class LocalOrganizationProfile(
    @PrimaryKey val orgId: String,
    val displayName: String,
    val businessMode: String,
    val defaultLocale: String,
    val updatedAtMillis: Long
)

@Entity(tableName = "local_sites", indices = [Index(value = ["orgId", "code"], unique = true)])
data class LocalSite(
    @PrimaryKey val id: String,
    val orgId: String,
    val code: String,
    val name: String,
    val addressLabel: String,
    val phoneContact: String,
    val status: String = "active",
    val syncStatus: String = "local_pending",
    val createdAtMillis: Long
)

@Entity(tableName = "local_workstations", indices = [Index(value = ["siteId", "code"], unique = true)])
data class LocalWorkstation(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val code: String,
    val name: String,
    val kind: String,
    val capacity: Int,
    val status: String = "active",
    val syncStatus: String = "local_pending",
    val createdAtMillis: Long
)

@Entity(tableName = "local_services", indices = [Index(value = ["siteId", "code"], unique = true)])
data class LocalService(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val code: String,
    val activity: String,
    val name: String,
    val durationMinutes: Int?,
    val priceXaf: Long,
    val active: Boolean = true,
    val createdAtMillis: Long
)

@Entity(tableName = "local_customers", indices = [Index(value = ["siteId"]), Index(value = ["phoneContact"])])
data class LocalCustomer(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val displayName: String,
    val phoneContact: String,
    val notesPrivate: String,
    val contactConsent: Boolean,
    val createdAtMillis: Long
)

@Entity(tableName = "local_inventory_items", indices = [Index(value = ["siteId"]), Index(value = ["name"])])
data class LocalInventoryItem(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val sku: String,
    val name: String,
    val unit: String,
    val quantity: Double,
    val reorderLevel: Double,
    val active: Boolean = true,
    val createdAtMillis: Long
)

@Entity(tableName = "local_inventory_movements", indices = [Index(value = ["siteId"]), Index(value = ["itemId"]), Index(value = ["createdAtMillis"])])
data class LocalInventoryMovement(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val itemId: String,
    val movementType: String,
    val quantityDelta: Double,
    val reason: String,
    val actorMemberId: String,
    val createdAtMillis: Long
)

@Entity(tableName = "local_support_requests", indices = [Index(value = ["orgId"]), Index(value = ["createdAtMillis"])])
data class LocalSupportRequest(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String?,
    val subject: String,
    val description: String,
    val priority: String,
    val state: String = "local_draft",
    val createdAtMillis: Long
)

@Entity(
    tableName = "local_management_records",
    indices = [Index(value = ["orgId", "siteId", "recordType", "createdAtMillis"]), Index(value = ["orgId", "siteId", "reference"])]
)
data class LocalManagementRecord(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val recordType: String,
    val reference: String,
    val title: String,
    val counterparty: String,
    val amountXaf: Long,
    val paidXaf: Long,
    val dueAtMillis: Long?,
    val status: String,
    val metadataJson: String,
    val actorMemberId: String,
    val createdAtMillis: Long
)

@Entity(
    tableName = "local_inventory_valuations",
    indices = [Index(value = ["orgId", "siteId", "inventoryItemId"], unique = true)]
)
data class LocalInventoryValuation(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val inventoryItemId: String,
    val unitCostXaf: Long,
    val sellingPriceXaf: Long,
    val updatedAtMillis: Long
)

@Dao
interface NaxaServicesDao {
    @Query("SELECT * FROM local_pressing_orders WHERE orgId = :orgId AND siteId = :siteId ORDER BY createdAtMillis DESC")
    fun observePressingOrders(orgId: String, siteId: String): Flow<List<LocalPressingOrder>>

    @Query("SELECT * FROM local_pressing_orders WHERE id = :id AND orgId = :orgId AND siteId = :siteId LIMIT 1")
    suspend fun findPressingOrder(id: String, orgId: String, siteId: String): LocalPressingOrder?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertPressingOrder(order: LocalPressingOrder)

    @Update
    suspend fun updatePressingOrder(order: LocalPressingOrder)

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertPressingStatusEvent(event: LocalPressingStatusEvent)

    @Query("SELECT * FROM local_appointments WHERE orgId = :orgId AND siteId = :siteId ORDER BY startsAtMillis ASC")
    fun observeAppointments(orgId: String, siteId: String): Flow<List<LocalAppointment>>

    @Query("""
        SELECT COUNT(*) FROM local_appointments
        WHERE orgId = :orgId AND siteId = :siteId
          AND status NOT IN ('cancelled', 'completed')
          AND startsAtMillis < :endsAtMillis
          AND endsAtMillis > :startsAtMillis
          AND ((:workstationId IS NOT NULL AND workstationId = :workstationId)
               OR assignedMemberId = :assignedMemberId)
    """)
    suspend fun countAppointmentConflicts(
        orgId: String,
        siteId: String,
        workstationId: String?,
        assignedMemberId: String,
        startsAtMillis: Long,
        endsAtMillis: Long
    ): Int

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertAppointment(appointment: LocalAppointment)

    @Query("SELECT * FROM local_cash_sessions WHERE orgId = :orgId AND siteId = :siteId ORDER BY openedAtMillis DESC")
    fun observeCashSessions(orgId: String, siteId: String): Flow<List<LocalCashSession>>

    @Query("SELECT * FROM local_cash_sessions WHERE orgId = :orgId AND siteId = :siteId AND registerId = :registerId AND status = 'open' LIMIT 1")
    suspend fun findOpenCashSession(orgId: String, siteId: String, registerId: String): LocalCashSession?

    @Query("SELECT * FROM local_cash_sessions WHERE id = :id AND orgId = :orgId AND siteId = :siteId LIMIT 1")
    suspend fun findCashSession(id: String, orgId: String, siteId: String): LocalCashSession?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertCashSession(session: LocalCashSession)

    @Update
    suspend fun updateCashSession(session: LocalCashSession)

    @Query("SELECT * FROM local_sales WHERE orgId = :orgId AND siteId = :siteId ORDER BY createdAtMillis DESC")
    fun observeSales(orgId: String, siteId: String): Flow<List<LocalSale>>

    @Query("SELECT COALESCE(SUM(totalXaf), 0) FROM local_sales WHERE orgId = :orgId AND siteId = :siteId AND cashSessionId = :sessionId AND paymentMethod = 'cash' AND status = 'confirmed'")
    suspend fun confirmedCashSalesTotal(orgId: String, siteId: String, sessionId: String): Long

    @Query("SELECT COALESCE(SUM(amountXaf), 0) FROM local_expenses WHERE orgId = :orgId AND siteId = :siteId AND cashSessionId = :sessionId")
    suspend fun sessionExpensesTotal(orgId: String, siteId: String, sessionId: String): Long

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertSale(sale: LocalSale)

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertExpense(expense: LocalExpense)

    @Query("SELECT COUNT(*) FROM local_outbox_events WHERE orgId = :orgId AND state <> 'synced'")
    fun observePendingOutboxCount(orgId: String): Flow<Int>

    @Query("SELECT COALESCE(MAX(deviceSequence), 0) + 1 FROM local_outbox_events WHERE orgId = :orgId")
    suspend fun nextOutboxSequence(orgId: String): Long

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertOutboxEvent(event: LocalOutboxEvent)

    @Query("SELECT * FROM local_organization_profiles WHERE orgId = :orgId LIMIT 1")
    fun observeOrganizationProfile(orgId: String): Flow<LocalOrganizationProfile?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertOrganizationProfile(profile: LocalOrganizationProfile)

    @Query("SELECT * FROM local_sites WHERE orgId = :orgId ORDER BY createdAtMillis ASC")
    fun observeSites(orgId: String): Flow<List<LocalSite>>

    @Query("SELECT * FROM local_sites WHERE id = :siteId AND orgId = :orgId LIMIT 1")
    suspend fun findSite(siteId: String, orgId: String): LocalSite?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertSite(site: LocalSite)

    @Query("SELECT * FROM local_workstations WHERE orgId = :orgId AND siteId = :siteId ORDER BY createdAtMillis ASC")
    fun observeWorkstations(orgId: String, siteId: String): Flow<List<LocalWorkstation>>

    @Query("SELECT * FROM local_workstations WHERE id = :workstationId AND orgId = :orgId AND siteId = :siteId AND status = 'active' LIMIT 1")
    suspend fun findWorkstation(workstationId: String, orgId: String, siteId: String): LocalWorkstation?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertWorkstation(workstation: LocalWorkstation)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertWorkstation(workstation: LocalWorkstation)

    @Query("SELECT * FROM local_services WHERE orgId = :orgId AND siteId = :siteId ORDER BY name COLLATE NOCASE ASC")
    fun observeServices(orgId: String, siteId: String): Flow<List<LocalService>>

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertService(service: LocalService)

    @Update
    suspend fun updateService(service: LocalService)

    @Query("SELECT * FROM local_customers WHERE orgId = :orgId AND siteId = :siteId ORDER BY displayName COLLATE NOCASE ASC")
    fun observeCustomers(orgId: String, siteId: String): Flow<List<LocalCustomer>>

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertCustomer(customer: LocalCustomer)

    @Query("SELECT * FROM local_inventory_items WHERE orgId = :orgId AND siteId = :siteId AND active = 1 ORDER BY name COLLATE NOCASE ASC")
    fun observeInventoryItems(orgId: String, siteId: String): Flow<List<LocalInventoryItem>>

    @Query("SELECT * FROM local_inventory_items WHERE id = :itemId AND orgId = :orgId AND siteId = :siteId LIMIT 1")
    suspend fun findInventoryItem(itemId: String, orgId: String, siteId: String): LocalInventoryItem?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertInventoryItem(item: LocalInventoryItem)

    @Update
    suspend fun updateInventoryItem(item: LocalInventoryItem)

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertInventoryMovement(movement: LocalInventoryMovement)

    @Query("SELECT * FROM local_inventory_movements WHERE orgId = :orgId AND siteId = :siteId ORDER BY createdAtMillis DESC LIMIT 100")
    fun observeInventoryMovements(orgId: String, siteId: String): Flow<List<LocalInventoryMovement>>

    @Query("SELECT COALESCE(SUM(totalXaf), 0) FROM local_sales WHERE orgId = :orgId AND siteId = :siteId AND status = 'confirmed' AND createdAtMillis BETWEEN :fromMillis AND :toMillis")
    fun observeSalesTotal(orgId: String, siteId: String, fromMillis: Long, toMillis: Long): Flow<Long>

    @Query("SELECT COALESCE(SUM(amountXaf), 0) FROM local_expenses WHERE orgId = :orgId AND siteId = :siteId AND createdAtMillis BETWEEN :fromMillis AND :toMillis")
    fun observeExpensesTotal(orgId: String, siteId: String, fromMillis: Long, toMillis: Long): Flow<Long>

    @Query("SELECT COUNT(*) FROM local_appointments WHERE orgId = :orgId AND siteId = :siteId AND startsAtMillis BETWEEN :fromMillis AND :toMillis AND status <> 'cancelled'")
    fun observeAppointmentCount(orgId: String, siteId: String, fromMillis: Long, toMillis: Long): Flow<Int>

    @Query("SELECT COUNT(*) FROM local_pressing_orders WHERE orgId = :orgId AND siteId = :siteId AND createdAtMillis BETWEEN :fromMillis AND :toMillis")
    fun observePressingCount(orgId: String, siteId: String, fromMillis: Long, toMillis: Long): Flow<Int>

    @Query("SELECT * FROM local_support_requests WHERE orgId = :orgId ORDER BY createdAtMillis DESC")
    fun observeSupportRequests(orgId: String): Flow<List<LocalSupportRequest>>

    @Query("SELECT * FROM local_support_requests WHERE orgId = :orgId AND siteId = :siteId ORDER BY createdAtMillis DESC")
    fun observeSupportRequestsForSite(orgId: String, siteId: String): Flow<List<LocalSupportRequest>>

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertSupportRequest(request: LocalSupportRequest)

    @Query("SELECT * FROM local_management_records WHERE orgId = :orgId AND siteId = :siteId ORDER BY createdAtMillis DESC")
    fun observeManagementRecords(orgId: String, siteId: String): Flow<List<LocalManagementRecord>>

    @Query("SELECT * FROM local_management_records WHERE orgId = :orgId AND siteId = :siteId AND recordType = :recordType ORDER BY createdAtMillis DESC")
    fun observeManagementRecordsByType(orgId: String, siteId: String, recordType: String): Flow<List<LocalManagementRecord>>

    @Query("SELECT * FROM local_management_records WHERE orgId = :orgId AND recordType = :recordType ORDER BY createdAtMillis DESC")
    fun observeOrganizationManagementRecordsByType(orgId: String, recordType: String): Flow<List<LocalManagementRecord>>

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertManagementRecord(record: LocalManagementRecord)

    @Query("SELECT * FROM local_inventory_valuations WHERE orgId = :orgId AND siteId = :siteId ORDER BY updatedAtMillis DESC")
    fun observeInventoryValuations(orgId: String, siteId: String): Flow<List<LocalInventoryValuation>>

    @Query("SELECT * FROM local_inventory_valuations WHERE orgId = :orgId AND siteId = :siteId AND inventoryItemId = :itemId LIMIT 1")
    suspend fun findInventoryValuation(orgId: String, siteId: String, itemId: String): LocalInventoryValuation?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertInventoryValuation(valuation: LocalInventoryValuation)
}

@Database(
    entities = [
        LocalPressingOrder::class,
        LocalPressingStatusEvent::class,
        LocalAppointment::class,
        LocalCashSession::class,
        LocalSale::class,
        LocalExpense::class,
        LocalOutboxEvent::class,
        LocalOrganizationProfile::class,
        LocalSite::class,
        LocalWorkstation::class,
        LocalService::class,
        LocalCustomer::class,
        LocalInventoryItem::class,
        LocalInventoryMovement::class,
        LocalSupportRequest::class,
        LocalManagementRecord::class,
        LocalInventoryValuation::class
    ],
    version = 2,
    exportSchema = false
)
abstract class NsServicesDatabase : RoomDatabase() {
    abstract fun naxaServicesDao(): NaxaServicesDao
}

val NS_SERVICES_MIGRATION_1_2: Migration = object : Migration(1, 2) {
    override fun migrate(database: SupportSQLiteDatabase) {
        database.execSQL(
            "CREATE TABLE IF NOT EXISTS local_management_records (" +
                "id TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, siteId TEXT NOT NULL, " +
                "recordType TEXT NOT NULL, reference TEXT NOT NULL, title TEXT NOT NULL, counterparty TEXT NOT NULL, " +
                "amountXaf INTEGER NOT NULL, paidXaf INTEGER NOT NULL, dueAtMillis INTEGER, status TEXT NOT NULL, " +
                "metadataJson TEXT NOT NULL, actorMemberId TEXT NOT NULL, createdAtMillis INTEGER NOT NULL)"
        )
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_management_records_orgId_siteId_recordType_createdAtMillis ON local_management_records(orgId, siteId, recordType, createdAtMillis)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_management_records_orgId_siteId_reference ON local_management_records(orgId, siteId, reference)")
        database.execSQL(
            "CREATE TABLE IF NOT EXISTS local_inventory_valuations (" +
                "id TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, siteId TEXT NOT NULL, inventoryItemId TEXT NOT NULL, " +
                "unitCostXaf INTEGER NOT NULL, sellingPriceXaf INTEGER NOT NULL, updatedAtMillis INTEGER NOT NULL)"
        )
        database.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_local_inventory_valuations_orgId_siteId_inventoryItemId ON local_inventory_valuations(orgId, siteId, inventoryItemId)")
    }
}

class NaxaServicesLocalRepository(private val database: NsServicesDatabase) {
    val dao: NaxaServicesDao = database.naxaServicesDao()

    suspend fun createPressingOrder(
        orgId: String,
        siteId: String,
        workstationId: String?,
        customerName: String,
        customerPhone: String,
        itemsSummary: String,
        totalXaf: Long,
        depositXaf: Long,
        promisedAtMillis: Long,
        actorMemberId: String
    ): LocalPressingOrder = database.withTransaction {
        val now = System.currentTimeMillis()
        require(orgId.isNotBlank() && siteId.isNotBlank() && actorMemberId.isNotBlank()) { "Organisation, point de vente ou opérateur manquant." }
        require(customerName.isNotBlank() && itemsSummary.isNotBlank()) { "Client et articles obligatoires." }
        require(totalXaf > 0 && depositXaf >= 0 && depositXaf <= totalXaf) { "Le total et l'acompte sont incohérents." }
        val normalizedWorkstationId = workstationId?.takeIf(String::isNotBlank)
        if (normalizedWorkstationId != null) {
            require(dao.findWorkstation(normalizedWorkstationId, orgId, siteId) != null) {
                "L'emplacement sélectionné n'existe pas dans ce point de vente."
            }
        }
        val order = LocalPressingOrder(
            id = UUID.randomUUID().toString(),
            orgId = orgId,
            siteId = siteId,
            workstationId = normalizedWorkstationId,
            ticketNumber = "PRS-" + now.toString() + "-" + UUID.randomUUID().toString().take(6).uppercase(),
            customerName = customerName.trim(),
            customerPhone = customerPhone.trim(),
            itemsSummary = itemsSummary.trim(),
            totalXaf = totalXaf,
            depositXaf = depositXaf,
            promisedAtMillis = promisedAtMillis,
            actorMemberId = actorMemberId,
            createdAtMillis = now,
            updatedAtMillis = now
        )
        dao.insertPressingOrder(order)
        enqueue(orgId, "pressing_order", order.id, "pressing_order.created", siteId)
        order
    }

    suspend fun advancePressingOrder(order: LocalPressingOrder, actorMemberId: String) = database.withTransaction {
        val current = dao.findPressingOrder(order.id, order.orgId, order.siteId) ?: throw IllegalStateException("Ticket introuvable.")
        require(current.orgId == order.orgId && current.siteId == order.siteId && actorMemberId.isNotBlank()) { "Périmètre du ticket invalide." }
        val next = when (current.status) {
            "received" -> "in_progress"
            "in_progress" -> "ready"
            "ready" -> "picked_up"
            else -> throw IllegalStateException("Ce ticket ne peut plus avancer.")
        }
        val changedAt = System.currentTimeMillis()
        dao.updatePressingOrder(current.copy(status = next, updatedAtMillis = changedAt))
        dao.insertPressingStatusEvent(
            LocalPressingStatusEvent(
                id = UUID.randomUUID().toString(),
                orderId = current.id,
                orgId = current.orgId,
                siteId = current.siteId,
                fromStatus = current.status,
                toStatus = next,
                actorMemberId = actorMemberId,
                createdAtMillis = changedAt
            )
        )
        enqueue(current.orgId, "pressing_order", current.id, "pressing_order.status_changed:" + next, current.siteId)
    }

    suspend fun createAppointment(
        orgId: String,
        siteId: String,
        workstationId: String?,
        customerName: String,
        serviceName: String,
        assignedMemberId: String,
        startsAtMillis: Long,
        endsAtMillis: Long,
        depositXaf: Long,
        actorMemberId: String
    ): LocalAppointment = database.withTransaction {
        val now = System.currentTimeMillis()
        require(orgId.isNotBlank() && siteId.isNotBlank() && actorMemberId.isNotBlank()) { "Organisation, point de vente ou opérateur manquant." }
        require(customerName.isNotBlank() && serviceName.isNotBlank()) { "Client et prestation obligatoires." }
        require(startsAtMillis > 0 && endsAtMillis > startsAtMillis) { "Créneau invalide." }
        require(depositXaf >= 0) { "Acompte invalide." }
        val normalizedWorkstation = workstationId?.takeIf(String::isNotBlank)
        if (normalizedWorkstation != null) {
            require(dao.findWorkstation(normalizedWorkstation, orgId, siteId) != null) {
                "L'emplacement sélectionné n'existe pas dans ce point de vente."
            }
        }
        val conflicts = dao.countAppointmentConflicts(orgId, siteId, normalizedWorkstation, assignedMemberId, startsAtMillis, endsAtMillis)
        require(conflicts == 0) { "Conflit de planning : ce poste ou ce prestataire est déjà réservé sur ce créneau." }
        val appointment = LocalAppointment(
            id = UUID.randomUUID().toString(),
            orgId = orgId,
            siteId = siteId,
            workstationId = normalizedWorkstation,
            customerName = customerName.trim(),
            serviceName = serviceName.trim(),
            assignedMemberId = assignedMemberId,
            startsAtMillis = startsAtMillis,
            endsAtMillis = endsAtMillis,
            depositXaf = depositXaf,
            actorMemberId = actorMemberId,
            createdAtMillis = now
        )
        dao.insertAppointment(appointment)
        enqueue(orgId, "appointment", appointment.id, "appointment.created", siteId)
        appointment
    }

    suspend fun openCashSession(
        orgId: String,
        siteId: String,
        registerId: String,
        registerName: String,
        openingFloatXaf: Long,
        actorMemberId: String
    ): LocalCashSession = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && registerId.isNotBlank() && registerName.isNotBlank()) { "Organisation, caisse et point de vente obligatoires." }
        require(openingFloatXaf >= 0 && actorMemberId.isNotBlank()) { "Fond de caisse invalide." }
        require(dao.findOpenCashSession(orgId, siteId, registerId.trim()) == null) { "Cette caisse possède déjà une session ouverte." }
        val session = LocalCashSession(
            id = UUID.randomUUID().toString(),
            orgId = orgId,
            siteId = siteId,
            registerId = registerId.trim(),
            registerName = registerName.trim(),
            openingFloatXaf = openingFloatXaf,
            openedByMemberId = actorMemberId,
            openedAtMillis = System.currentTimeMillis()
        )
        dao.insertCashSession(session)
        enqueue(orgId, "cash_session", session.id, "cash_session.opened", siteId)
        session
    }

    suspend fun recordSale(
        orgId: String,
        siteId: String,
        cashSessionId: String,
        description: String,
        totalXaf: Long,
        paymentMethod: String,
        actorMemberId: String
    ): Pair<LocalSale, LocalOutboxEvent> = database.withTransaction {
        val cashSession = dao.findCashSession(cashSessionId, orgId, siteId) ?: throw IllegalStateException("Session de caisse introuvable.")
        require(cashSession.siteId == siteId && cashSession.status == "open") { "La caisse n'est pas ouverte sur ce point de vente." }
        require(description.isNotBlank() && totalXaf > 0 && actorMemberId.isNotBlank()) { "Description, montant et opérateur obligatoires." }
        require(paymentMethod in setOf("cash", "mobile_money")) { "Mode de paiement non pris en charge." }
        val now = System.currentTimeMillis()
        val sale = LocalSale(
            id = UUID.randomUUID().toString(),
            orgId = cashSession.orgId,
            siteId = siteId,
            cashSessionId = cashSessionId,
            saleNumber = "VTE-" + now.toString() + "-" + UUID.randomUUID().toString().take(6).uppercase(),
            description = description.trim(),
            totalXaf = totalXaf,
            paymentMethod = paymentMethod,
            status = if (paymentMethod == "cash") "confirmed" else "pending",
            actorMemberId = actorMemberId,
            createdAtMillis = now
        )
        dao.insertSale(sale)
        val event = enqueue(cashSession.orgId, "sale", sale.id, "sale.created", siteId)
        sale to event
    }

    suspend fun addExpense(
        orgId: String,
        siteId: String,
        cashSessionId: String,
        category: String,
        description: String,
        amountXaf: Long,
        actorMemberId: String
    ): LocalExpense = database.withTransaction {
        val session = dao.findCashSession(cashSessionId, orgId, siteId) ?: throw IllegalStateException("Session de caisse introuvable.")
        require(session.siteId == siteId && session.status == "open") { "La caisse n'est pas ouverte sur ce point de vente." }
        require(category.isNotBlank() && description.isNotBlank() && amountXaf > 0 && actorMemberId.isNotBlank()) { "Catégorie, motif, montant et opérateur obligatoires." }
        val expense = LocalExpense(
            id = UUID.randomUUID().toString(),
            orgId = session.orgId,
            siteId = siteId,
            cashSessionId = cashSessionId,
            category = category.trim(),
            description = description.trim(),
            amountXaf = amountXaf,
            actorMemberId = actorMemberId,
            createdAtMillis = System.currentTimeMillis()
        )
        dao.insertExpense(expense)
        enqueue(session.orgId, "expense", expense.id, "expense.created", siteId)
        expense
    }

    suspend fun closeCashSession(
        orgId: String,
        siteId: String,
        sessionId: String,
        countedCloseXaf: Long,
        varianceReason: String,
        actorMemberId: String
    ): LocalCashSession = database.withTransaction {
        val current = dao.findCashSession(sessionId, orgId, siteId) ?: throw IllegalStateException("Session de caisse introuvable.")
        require(current.status == "open" && countedCloseXaf >= 0 && actorMemberId.isNotBlank()) { "Clôture de caisse invalide." }
        val expected = current.openingFloatXaf +
            dao.confirmedCashSalesTotal(orgId, siteId, sessionId) -
            dao.sessionExpensesTotal(orgId, siteId, sessionId)
        val variance = countedCloseXaf - expected
        require(variance == 0L || varianceReason.trim().length >= 8) { "Justifie tout écart de caisse avec au moins 8 caractères." }
        val closed = current.copy(
            status = "closed",
            closedByMemberId = actorMemberId,
            closedAtMillis = System.currentTimeMillis(),
            countedCloseXaf = countedCloseXaf,
            varianceXaf = variance,
            varianceReason = varianceReason.trim().takeIf(String::isNotBlank)
        )
        dao.updateCashSession(closed)
        enqueue(current.orgId, "cash_session", closed.id, "cash_session.closed", closed.siteId)
        closed
    }

    suspend fun saveOrganizationProfile(
        orgId: String,
        displayName: String,
        businessMode: String,
        defaultLocale: String = "fr"
    ) = database.withTransaction {
        require(orgId.isNotBlank() && displayName.isNotBlank()) { "Le nom de l'organisation est obligatoire." }
        require(businessMode in setOf("solo", "single_site_multi_workstation", "multi_site_network")) { "Modèle d'exploitation invalide." }
        require(defaultLocale in setOf("fr", "en")) { "Langue non prise en charge." }
        dao.upsertOrganizationProfile(LocalOrganizationProfile(orgId, displayName.trim(), businessMode, defaultLocale, System.currentTimeMillis()))
        enqueue(orgId, "organization", orgId, "organization.profile_saved", null)
    }

    suspend fun createLocalSite(orgId: String, code: String, name: String, address: String, phone: String): LocalSite = database.withTransaction {
        require(orgId.isNotBlank() && code.isNotBlank() && name.isNotBlank()) { "Code et nom du point de vente obligatoires." }
        val site = LocalSite(UUID.randomUUID().toString(), orgId, code.trim().uppercase(), name.trim(), address.trim(), phone.trim(), createdAtMillis = System.currentTimeMillis())
        dao.insertSite(site)
        enqueue(orgId, "site", site.id, "site.created", site.id)
        site
    }

    suspend fun cacheServerWorkstation(
        workstationId: String,
        orgId: String,
        siteId: String,
        code: String,
        name: String,
        kind: String,
        capacity: Int,
        status: String
    ): LocalWorkstation = database.withTransaction {
        require(workstationId.isNotBlank() && orgId.isNotBlank() && siteId.isNotBlank()) {
            "Identifiants serveur, organisation et site obligatoires."
        }
        require(kind in setOf("hair_chair", "pressing_counter", "pressing_workshop", "reception", "cashier", "other")) {
            "Type d’emplacement non autorisé."
        }
        require(capacity in 1..100 && status == "active") { "Emplacement serveur inactif ou capacité invalide." }
        val workstation = LocalWorkstation(
            id = workstationId,
            orgId = orgId,
            siteId = siteId,
            code = code.trim().uppercase(),
            name = name.trim(),
            kind = kind,
            capacity = capacity,
            status = "active",
            syncStatus = "server_confirmed",
            createdAtMillis = System.currentTimeMillis()
        )
        dao.upsertWorkstation(workstation)
        workstation
    }

    suspend fun createLocalWorkstation(
        orgId: String,
        siteId: String,
        code: String,
        name: String,
        kind: String,
        capacity: Int,
        isServerAuthorizedSite: Boolean
    ): LocalWorkstation = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && code.isNotBlank() && name.isNotBlank()) { "Point de vente, code et nom obligatoires." }
        require(kind in setOf("hair_chair", "pressing_counter", "pressing_workshop", "reception", "cashier", "other")) { "Type d'emplacement invalide." }
        require(capacity in 1..100) { "Capacité comprise entre 1 et 100." }
        require(isServerAuthorizedSite || dao.findSite(siteId, orgId) != null) {
            "Le point de vente n’est ni affecté par le serveur ni présent comme brouillon local."
        }
        val workstation = LocalWorkstation(UUID.randomUUID().toString(), orgId, siteId, code.trim().uppercase(), name.trim(), kind, capacity, createdAtMillis = System.currentTimeMillis())
        dao.insertWorkstation(workstation)
        enqueue(orgId, "workstation", workstation.id, "workstation.created", siteId)
        workstation
    }

    suspend fun createLocalService(orgId: String, siteId: String, activity: String, name: String, durationMinutes: Int?, priceXaf: Long): LocalService = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && name.isNotBlank()) { "Point de vente et prestation obligatoires." }
        require(activity in setOf("pressing", "hair", "retail")) { "Activité invalide." }
        require(durationMinutes == null || durationMinutes in 1..1440) { "Durée invalide." }
        require(priceXaf >= 0) { "Tarif invalide." }
        val now = System.currentTimeMillis()
        val service = LocalService(UUID.randomUUID().toString(), orgId, siteId, "SRV-" + now.toString() + "-" + UUID.randomUUID().toString().take(6).uppercase(), activity, name.trim(), durationMinutes, priceXaf, createdAtMillis = now)
        dao.insertService(service)
        enqueue(orgId, "service", service.id, "service.created", siteId)
        service
    }

    suspend fun createLocalCustomer(orgId: String, siteId: String, name: String, phone: String, privateNotes: String, contactConsent: Boolean): LocalCustomer = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && name.isNotBlank()) { "Nom du client et point de vente obligatoires." }
        require(phone.length <= 32 && privateNotes.length <= 1000) { "Coordonnées ou note trop longues." }
        val customer = LocalCustomer(UUID.randomUUID().toString(), orgId, siteId, name.trim(), phone.trim(), privateNotes.trim(), contactConsent, System.currentTimeMillis())
        dao.insertCustomer(customer)
        enqueue(orgId, "customer", customer.id, "customer.created", siteId)
        customer
    }

    suspend fun createInventoryItem(orgId: String, siteId: String, sku: String, name: String, unit: String, reorderLevel: Double): LocalInventoryItem = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && name.isNotBlank() && unit.isNotBlank()) { "Article, unité et point de vente obligatoires." }
        require(reorderLevel >= 0.0) { "Seuil d'alerte invalide." }
        val item = LocalInventoryItem(UUID.randomUUID().toString(), orgId, siteId, sku.trim(), name.trim(), unit.trim(), 0.0, reorderLevel, createdAtMillis = System.currentTimeMillis())
        dao.insertInventoryItem(item)
        enqueue(orgId, "inventory_item", item.id, "inventory_item.created", siteId)
        item
    }

    suspend fun recordInventoryMovement(orgId: String, siteId: String, itemId: String, movementType: String, quantity: Double, reason: String, actorMemberId: String): LocalInventoryItem = database.withTransaction {
        require(movementType in setOf("in", "consumption", "loss", "adjustment")) { "Type de mouvement invalide." }
        require(quantity != 0.0 && reason.trim().length >= 3 && actorMemberId.isNotBlank()) { "Quantité non nulle, motif et opérateur obligatoires." }
        require(movementType == "adjustment" || quantity > 0.0) { "Les entrées, consommations et pertes utilisent une quantité positive." }
        val current = dao.findInventoryItem(itemId, orgId, siteId) ?: throw IllegalArgumentException("Article introuvable sur ce point de vente.")
        require(current.orgId == orgId) { "Organisation de l'article invalide." }
        val delta = if (movementType == "in" || movementType == "adjustment") quantity else -quantity
        val updatedQuantity = current.quantity + delta
        require(updatedQuantity >= 0.0) { "Stock insuffisant : le mouvement créerait un stock négatif." }
        val movement = LocalInventoryMovement(
            id = UUID.randomUUID().toString(),
            orgId = orgId,
            siteId = siteId,
            itemId = itemId,
            movementType = movementType,
            quantityDelta = delta,
            reason = reason.trim(),
            actorMemberId = actorMemberId,
            createdAtMillis = System.currentTimeMillis()
        )
        dao.insertInventoryMovement(movement)
        val updated = current.copy(quantity = updatedQuantity)
        dao.updateInventoryItem(updated)
        enqueue(orgId, "inventory_movement", movement.id, "inventory_movement.created", siteId)
        updated
    }

    suspend fun createSupportRequest(orgId: String, siteId: String?, subject: String, description: String, priority: String): LocalSupportRequest = database.withTransaction {
        require(orgId.isNotBlank() && subject.isNotBlank() && description.trim().length >= 10) { "Sujet et description détaillée obligatoires." }
        require(priority in setOf("low", "normal", "high")) { "Priorité invalide." }
        val item = LocalSupportRequest(UUID.randomUUID().toString(), orgId, siteId, subject.trim(), description.trim(), priority, createdAtMillis = System.currentTimeMillis())
        dao.insertSupportRequest(item)
        enqueue(orgId, "support_request", item.id, "support_request.created", siteId)
        item
    }

    suspend fun createManagementRecord(
        orgId: String,
        siteId: String,
        recordType: String,
        reference: String,
        title: String,
        counterparty: String,
        amountXaf: Long,
        paidXaf: Long,
        dueAtMillis: Long?,
        status: String,
        metadataJson: String,
        actorMemberId: String
    ): LocalManagementRecord = database.withTransaction {
        val allowedTypes = setOf("quote", "invoice", "credit_note", "refund_due", "customer_receivable", "purchase", "tax_estimate", "business_goal", "subscription_request", "support_chat", "work_order", "repair_order", "service_order", "staff_clock_in", "staff_clock_out", "staff_break_start", "staff_break_end", "staff_commission", "staff_advance", "staff_bonus")
        require(orgId.isNotBlank() && siteId.isNotBlank() && actorMemberId.isNotBlank()) { "Organisation, site et opérateur obligatoires." }
        require(recordType in allowedTypes) { "Type de registre non autorisé." }
        require(title.isNotBlank() && amountXaf >= 0L && paidXaf >= 0L && paidXaf <= amountXaf) { "Montants ou libellé incohérents." }
        require(status in setOf("draft", "open", "partial", "paid", "cancelled", "pending_review")) { "Statut non autorisé." }
        val now = System.currentTimeMillis()
        val item = LocalManagementRecord(
            id = UUID.randomUUID().toString(), orgId = orgId, siteId = siteId,
            recordType = recordType, reference = reference.trim(), title = title.trim(),
            counterparty = counterparty.trim(), amountXaf = amountXaf, paidXaf = paidXaf,
            dueAtMillis = dueAtMillis, status = status, metadataJson = metadataJson.take(4000),
            actorMemberId = actorMemberId, createdAtMillis = now
        )
        dao.insertManagementRecord(item)
        enqueue(orgId, recordType, item.id, recordType + ".created", siteId)
        item
    }

    suspend fun saveInventoryValuation(
        orgId: String,
        siteId: String,
        itemId: String,
        unitCostXaf: Long,
        sellingPriceXaf: Long
    ): LocalInventoryValuation = database.withTransaction {
        require(unitCostXaf >= 0L && sellingPriceXaf >= 0L) { "Le coût et le prix doivent être positifs ou nuls." }
        require(dao.findInventoryItem(itemId, orgId, siteId) != null) { "Article absent de ce site." }
        val current = dao.findInventoryValuation(orgId, siteId, itemId)
        val valuation = LocalInventoryValuation(
            id = current?.id ?: UUID.randomUUID().toString(),
            orgId = orgId, siteId = siteId, inventoryItemId = itemId,
            unitCostXaf = unitCostXaf, sellingPriceXaf = sellingPriceXaf,
            updatedAtMillis = System.currentTimeMillis()
        )
        dao.upsertInventoryValuation(valuation)
        enqueue(orgId, "inventory_valuation", itemId, "inventory_valuation.updated", siteId)
        valuation
    }

    private suspend fun enqueue(orgId: String, type: String, aggregateId: String, action: String, siteId: String?): LocalOutboxEvent {
        val event = LocalOutboxEvent(
            eventId = UUID.randomUUID().toString(),
            orgId = orgId,
            aggregateType = type,
            aggregateId = aggregateId,
            actionCode = action,
            payloadJson = "{\"aggregate_id\":\"" + aggregateId + "\",\"site_id\":" + (siteId?.let { "\"" + it + "\"" } ?: "null") + "}",
            deviceSequence = dao.nextOutboxSequence(orgId),
            createdAtEpochMs = System.currentTimeMillis()
        )
        dao.insertOutboxEvent(event)
        return event
    }
}
