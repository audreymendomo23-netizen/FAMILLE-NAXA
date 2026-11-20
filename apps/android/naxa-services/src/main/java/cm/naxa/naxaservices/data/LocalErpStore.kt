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
import kotlinx.coroutines.flow.Flow
import java.util.UUID

@Entity(tableName = "local_pressing_orders", indices = [Index("siteId"), Index(value = ["ticketNumber"], unique = true)])
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

@Entity(tableName = "local_appointments", indices = [Index("siteId"), Index("startsAtMillis")])
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

@Entity(tableName = "local_sales", indices = [Index("siteId"), Index("cashSessionId"), Index("createdAtMillis")])
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

@Entity(tableName = "local_expenses", indices = [Index("siteId"), Index("cashSessionId"), Index("createdAtMillis")])
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

@Entity(tableName = "local_outbox_events", indices = [Index(value = ["state", "deviceSequence"])])
data class LocalOutboxEvent(
    @PrimaryKey val eventId: String,
    val appId: String = "naxa-services",
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

@Entity(tableName = "local_customers", indices = [Index("siteId"), Index("phoneContact")])
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

@Entity(tableName = "local_inventory_items", indices = [Index("siteId"), Index("name")])
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

@Entity(tableName = "local_inventory_movements", indices = [Index("siteId"), Index("itemId"), Index("createdAtMillis")])
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

@Entity(tableName = "local_support_requests", indices = [Index("orgId"), Index("createdAtMillis")])
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

@Dao
interface NaxaServicesDao {
    @Query("SELECT * FROM local_pressing_orders WHERE siteId = :siteId ORDER BY createdAtMillis DESC")
    fun observePressingOrders(siteId: String): Flow<List<LocalPressingOrder>>

    @Query("SELECT * FROM local_pressing_orders WHERE id = :id LIMIT 1")
    suspend fun findPressingOrder(id: String): LocalPressingOrder?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertPressingOrder(order: LocalPressingOrder)

    @Update
    suspend fun updatePressingOrder(order: LocalPressingOrder)

    @Query("SELECT * FROM local_appointments WHERE siteId = :siteId ORDER BY startsAtMillis ASC")
    fun observeAppointments(siteId: String): Flow<List<LocalAppointment>>

    @Query("""
        SELECT COUNT(*) FROM local_appointments
        WHERE siteId = :siteId
          AND status NOT IN ('cancelled', 'completed')
          AND startsAtMillis < :endsAtMillis
          AND endsAtMillis > :startsAtMillis
          AND ((:workstationId IS NOT NULL AND workstationId = :workstationId)
               OR assignedMemberId = :assignedMemberId)
    """)
    suspend fun countAppointmentConflicts(
        siteId: String,
        workstationId: String?,
        assignedMemberId: String,
        startsAtMillis: Long,
        endsAtMillis: Long
    ): Int

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertAppointment(appointment: LocalAppointment)

    @Query("SELECT * FROM local_cash_sessions WHERE siteId = :siteId ORDER BY openedAtMillis DESC")
    fun observeCashSessions(siteId: String): Flow<List<LocalCashSession>>

    @Query("SELECT * FROM local_cash_sessions WHERE siteId = :siteId AND registerId = :registerId AND status = 'open' LIMIT 1")
    suspend fun findOpenCashSession(siteId: String, registerId: String): LocalCashSession?

    @Query("SELECT * FROM local_cash_sessions WHERE id = :id LIMIT 1")
    suspend fun findCashSession(id: String): LocalCashSession?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertCashSession(session: LocalCashSession)

    @Update
    suspend fun updateCashSession(session: LocalCashSession)

    @Query("SELECT * FROM local_sales WHERE siteId = :siteId ORDER BY createdAtMillis DESC")
    fun observeSales(siteId: String): Flow<List<LocalSale>>

    @Query("SELECT COALESCE(SUM(totalXaf), 0) FROM local_sales WHERE cashSessionId = :sessionId AND paymentMethod = 'cash' AND status = 'confirmed'")
    suspend fun confirmedCashSalesTotal(sessionId: String): Long

    @Query("SELECT COALESCE(SUM(amountXaf), 0) FROM local_expenses WHERE cashSessionId = :sessionId")
    suspend fun sessionExpensesTotal(sessionId: String): Long

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertSale(sale: LocalSale)

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertExpense(expense: LocalExpense)

    @Query("SELECT COUNT(*) FROM local_outbox_events WHERE state <> 'synced'")
    fun observePendingOutboxCount(): Flow<Int>

    @Query("SELECT COALESCE(MAX(deviceSequence), 0) + 1 FROM local_outbox_events")
    suspend fun nextOutboxSequence(): Long

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

    @Query("SELECT * FROM local_workstations WHERE siteId = :siteId ORDER BY createdAtMillis ASC")
    fun observeWorkstations(siteId: String): Flow<List<LocalWorkstation>>

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertWorkstation(workstation: LocalWorkstation)

    @Query("SELECT * FROM local_services WHERE siteId = :siteId ORDER BY name COLLATE NOCASE ASC")
    fun observeServices(siteId: String): Flow<List<LocalService>>

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertService(service: LocalService)

    @Update
    suspend fun updateService(service: LocalService)

    @Query("SELECT * FROM local_customers WHERE siteId = :siteId ORDER BY displayName COLLATE NOCASE ASC")
    fun observeCustomers(siteId: String): Flow<List<LocalCustomer>>

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertCustomer(customer: LocalCustomer)

    @Query("SELECT * FROM local_inventory_items WHERE siteId = :siteId AND active = 1 ORDER BY name COLLATE NOCASE ASC")
    fun observeInventoryItems(siteId: String): Flow<List<LocalInventoryItem>>

    @Query("SELECT * FROM local_inventory_items WHERE id = :itemId AND siteId = :siteId LIMIT 1")
    suspend fun findInventoryItem(itemId: String, siteId: String): LocalInventoryItem?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertInventoryItem(item: LocalInventoryItem)

    @Update
    suspend fun updateInventoryItem(item: LocalInventoryItem)

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertInventoryMovement(movement: LocalInventoryMovement)

    @Query("SELECT * FROM local_inventory_movements WHERE siteId = :siteId ORDER BY createdAtMillis DESC LIMIT 100")
    fun observeInventoryMovements(siteId: String): Flow<List<LocalInventoryMovement>>

    @Query("SELECT COALESCE(SUM(totalXaf), 0) FROM local_sales WHERE siteId = :siteId AND status = 'confirmed' AND createdAtMillis BETWEEN :fromMillis AND :toMillis")
    fun observeSalesTotal(siteId: String, fromMillis: Long, toMillis: Long): Flow<Long>

    @Query("SELECT COALESCE(SUM(amountXaf), 0) FROM local_expenses WHERE siteId = :siteId AND createdAtMillis BETWEEN :fromMillis AND :toMillis")
    fun observeExpensesTotal(siteId: String, fromMillis: Long, toMillis: Long): Flow<Long>

    @Query("SELECT COUNT(*) FROM local_appointments WHERE siteId = :siteId AND startsAtMillis BETWEEN :fromMillis AND :toMillis AND status <> 'cancelled'")
    fun observeAppointmentCount(siteId: String, fromMillis: Long, toMillis: Long): Flow<Int>

    @Query("SELECT COUNT(*) FROM local_pressing_orders WHERE siteId = :siteId AND createdAtMillis BETWEEN :fromMillis AND :toMillis")
    fun observePressingCount(siteId: String, fromMillis: Long, toMillis: Long): Flow<Int>

    @Query("SELECT * FROM local_support_requests WHERE orgId = :orgId ORDER BY createdAtMillis DESC")
    fun observeSupportRequests(orgId: String): Flow<List<LocalSupportRequest>>

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertSupportRequest(request: LocalSupportRequest)
}

@Database(
    entities = [
        LocalPressingOrder::class,
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
        LocalSupportRequest::class
    ],
    version = 1,
    exportSchema = false
)
abstract class NsServicesDatabase : RoomDatabase() {
    abstract fun naxaServicesDao(): NaxaServicesDao
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
        val order = LocalPressingOrder(
            id = UUID.randomUUID().toString(),
            orgId = orgId,
            siteId = siteId,
            workstationId = workstationId?.takeIf(String::isNotBlank),
            ticketNumber = "PRS-" + now.toString(),
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
        enqueue("pressing_order", order.id, "pressing_order.created", siteId)
        order
    }

    suspend fun advancePressingOrder(order: LocalPressingOrder, actorMemberId: String) = database.withTransaction {
        val current = dao.findPressingOrder(order.id) ?: throw IllegalStateException("Ticket introuvable.")
        require(current.orgId == order.orgId && current.siteId == order.siteId && actorMemberId.isNotBlank()) { "Périmètre du ticket invalide." }
        val next = when (current.status) {
            "received" -> "in_progress"
            "in_progress" -> "ready"
            "ready" -> "picked_up"
            else -> throw IllegalStateException("Ce ticket ne peut plus avancer.")
        }
        dao.updatePressingOrder(current.copy(status = next, updatedAtMillis = System.currentTimeMillis()))
        enqueue("pressing_order", current.id, "pressing_order.status_changed:" + next, current.siteId)
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
        val conflicts = dao.countAppointmentConflicts(siteId, normalizedWorkstation, assignedMemberId, startsAtMillis, endsAtMillis)
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
        enqueue("appointment", appointment.id, "appointment.created", siteId)
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
        require(dao.findOpenCashSession(siteId, registerId.trim()) == null) { "Cette caisse possède déjà une session ouverte." }
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
        enqueue("cash_session", session.id, "cash_session.opened", siteId)
        session
    }

    suspend fun recordSale(
        siteId: String,
        cashSessionId: String,
        description: String,
        totalXaf: Long,
        paymentMethod: String,
        actorMemberId: String
    ): Pair<LocalSale, LocalOutboxEvent> = database.withTransaction {
        val cashSession = dao.findCashSession(cashSessionId) ?: throw IllegalStateException("Session de caisse introuvable.")
        require(cashSession.siteId == siteId && cashSession.status == "open") { "La caisse n'est pas ouverte sur ce point de vente." }
        require(description.isNotBlank() && totalXaf > 0 && actorMemberId.isNotBlank()) { "Description, montant et opérateur obligatoires." }
        require(paymentMethod in setOf("cash", "mobile_money")) { "Mode de paiement non pris en charge." }
        val now = System.currentTimeMillis()
        val sale = LocalSale(
            id = UUID.randomUUID().toString(),
            orgId = cashSession.orgId,
            siteId = siteId,
            cashSessionId = cashSessionId,
            saleNumber = "VTE-" + now.toString(),
            description = description.trim(),
            totalXaf = totalXaf,
            paymentMethod = paymentMethod,
            status = if (paymentMethod == "cash") "confirmed" else "pending",
            actorMemberId = actorMemberId,
            createdAtMillis = now
        )
        dao.insertSale(sale)
        val event = enqueue("sale", sale.id, "sale.created", siteId)
        sale to event
    }

    suspend fun addExpense(
        siteId: String,
        cashSessionId: String,
        category: String,
        description: String,
        amountXaf: Long,
        actorMemberId: String
    ): LocalExpense = database.withTransaction {
        val session = dao.findCashSession(cashSessionId) ?: throw IllegalStateException("Session de caisse introuvable.")
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
        enqueue("expense", expense.id, "expense.created", siteId)
        expense
    }

    suspend fun closeCashSession(
        sessionId: String,
        countedCloseXaf: Long,
        varianceReason: String,
        actorMemberId: String
    ): LocalCashSession = database.withTransaction {
        val current = dao.findCashSession(sessionId) ?: throw IllegalStateException("Session de caisse introuvable.")
        require(current.status == "open" && countedCloseXaf >= 0 && actorMemberId.isNotBlank()) { "Clôture de caisse invalide." }
        val expected = current.openingFloatXaf +
            dao.confirmedCashSalesTotal(sessionId) -
            dao.sessionExpensesTotal(sessionId)
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
        enqueue("cash_session", closed.id, "cash_session.closed", closed.siteId)
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
        enqueue("organization", orgId, "organization.profile_saved", null)
    }

    suspend fun createLocalSite(orgId: String, code: String, name: String, address: String, phone: String): LocalSite = database.withTransaction {
        require(orgId.isNotBlank() && code.isNotBlank() && name.isNotBlank()) { "Code et nom du point de vente obligatoires." }
        val site = LocalSite(UUID.randomUUID().toString(), orgId, code.trim().uppercase(), name.trim(), address.trim(), phone.trim(), createdAtMillis = System.currentTimeMillis())
        dao.insertSite(site)
        enqueue("site", site.id, "site.created", site.id)
        site
    }

    suspend fun createLocalWorkstation(orgId: String, siteId: String, code: String, name: String, kind: String, capacity: Int): LocalWorkstation = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && code.isNotBlank() && name.isNotBlank()) { "Point de vente, code et nom obligatoires." }
        require(kind in setOf("hair_chair", "pressing_counter", "pressing_workshop", "reception", "cashier", "other")) { "Type d'emplacement invalide." }
        require(capacity in 1..100) { "Capacité comprise entre 1 et 100." }
        require(dao.findSite(siteId, orgId) != null) { "Point de vente inconnu." }
        val workstation = LocalWorkstation(UUID.randomUUID().toString(), orgId, siteId, code.trim().uppercase(), name.trim(), kind, capacity, createdAtMillis = System.currentTimeMillis())
        dao.insertWorkstation(workstation)
        enqueue("workstation", workstation.id, "workstation.created", siteId)
        workstation
    }

    suspend fun createLocalService(orgId: String, siteId: String, activity: String, name: String, durationMinutes: Int?, priceXaf: Long): LocalService = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && name.isNotBlank()) { "Point de vente et prestation obligatoires." }
        require(activity in setOf("pressing", "hair", "retail")) { "Activité invalide." }
        require(durationMinutes == null || durationMinutes in 1..1440) { "Durée invalide." }
        require(priceXaf >= 0) { "Tarif invalide." }
        val now = System.currentTimeMillis()
        val service = LocalService(UUID.randomUUID().toString(), orgId, siteId, "SRV-" + now.toString(), activity, name.trim(), durationMinutes, priceXaf, createdAtMillis = now)
        dao.insertService(service)
        enqueue("service", service.id, "service.created", siteId)
        service
    }

    suspend fun createLocalCustomer(orgId: String, siteId: String, name: String, phone: String, privateNotes: String, contactConsent: Boolean): LocalCustomer = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && name.isNotBlank()) { "Nom du client et point de vente obligatoires." }
        require(phone.length <= 32 && privateNotes.length <= 1000) { "Coordonnées ou note trop longues." }
        val customer = LocalCustomer(UUID.randomUUID().toString(), orgId, siteId, name.trim(), phone.trim(), privateNotes.trim(), contactConsent, System.currentTimeMillis())
        dao.insertCustomer(customer)
        enqueue("customer", customer.id, "customer.created", siteId)
        customer
    }

    suspend fun createInventoryItem(orgId: String, siteId: String, sku: String, name: String, unit: String, reorderLevel: Double): LocalInventoryItem = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && name.isNotBlank() && unit.isNotBlank()) { "Article, unité et point de vente obligatoires." }
        require(reorderLevel >= 0.0) { "Seuil d'alerte invalide." }
        val item = LocalInventoryItem(UUID.randomUUID().toString(), orgId, siteId, sku.trim(), name.trim(), unit.trim(), 0.0, reorderLevel, createdAtMillis = System.currentTimeMillis())
        dao.insertInventoryItem(item)
        enqueue("inventory_item", item.id, "inventory_item.created", siteId)
        item
    }

    suspend fun recordInventoryMovement(orgId: String, siteId: String, itemId: String, movementType: String, quantity: Double, reason: String, actorMemberId: String): LocalInventoryItem = database.withTransaction {
        require(movementType in setOf("in", "consumption", "loss", "adjustment")) { "Type de mouvement invalide." }
        require(quantity > 0.0 && reason.trim().length >= 3 && actorMemberId.isNotBlank()) { "Quantité, motif et opérateur obligatoires." }
        val current = dao.findInventoryItem(itemId, siteId) ?: throw IllegalArgumentException("Article introuvable sur ce point de vente.")
        require(current.orgId == orgId) { "Organisation de l'article invalide." }
        val delta = if (movementType == "in" || movementType == "adjustment") quantity else -quantity
        val updatedQuantity = current.quantity + delta
        require(updatedQuantity >= 0.0) { "Stock insuffisant : le mouvement créerait un stock négatif." }
        dao.insertInventoryMovement(LocalInventoryMovement(UUID.randomUUID().toString(), orgId, siteId, itemId, movementType, delta, reason.trim(), actorMemberId, System.currentTimeMillis()))
        val updated = current.copy(quantity = updatedQuantity)
        dao.updateInventoryItem(updated)
        enqueue("inventory_movement", itemId, "inventory_movement.created", siteId)
        updated
    }

    suspend fun createSupportRequest(orgId: String, siteId: String?, subject: String, description: String, priority: String): LocalSupportRequest = database.withTransaction {
        require(orgId.isNotBlank() && subject.isNotBlank() && description.trim().length >= 10) { "Sujet et description détaillée obligatoires." }
        require(priority in setOf("low", "normal", "high")) { "Priorité invalide." }
        val item = LocalSupportRequest(UUID.randomUUID().toString(), orgId, siteId, subject.trim(), description.trim(), priority, createdAtMillis = System.currentTimeMillis())
        dao.insertSupportRequest(item)
        enqueue("support_request", item.id, "support_request.created", siteId)
        item
    }

    private suspend fun enqueue(type: String, aggregateId: String, action: String, siteId: String?): LocalOutboxEvent {
        val event = LocalOutboxEvent(
            eventId = UUID.randomUUID().toString(),
            aggregateType = type,
            aggregateId = aggregateId,
            actionCode = action,
            payloadJson = "{\"aggregate_id\":\"" + aggregateId + "\",\"site_id\":" + (siteId?.let { "\"" + it + "\"" } ?: "null") + "}",
            deviceSequence = dao.nextOutboxSequence(),
            createdAtEpochMs = System.currentTimeMillis()
        )
        dao.insertOutboxEvent(event)
        return event
    }
}
