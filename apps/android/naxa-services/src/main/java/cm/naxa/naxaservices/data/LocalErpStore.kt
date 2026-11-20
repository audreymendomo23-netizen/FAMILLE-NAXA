package cm.naxa.naxaservices.data

import androidx.room.Dao
import androidx.room.Database
import androidx.room.ColumnInfo
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
import java.util.Calendar
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
    val createdAtMillis: Long,
    val reason: String = ""
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

@Entity(
    tableName = "local_sales",
    indices = [
        Index(value = ["siteId"]),
        Index(value = ["cashSessionId"]),
        Index(value = ["createdAtMillis"]),
        Index(value = ["orgId", "siteId", "inventoryItemId", "status"])
    ]
)
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
    val createdAtMillis: Long,
    val inventoryItemId: String? = null,
    val stockQuantity: Double? = null,
    @ColumnInfo(defaultValue = "0") val unitCostAtSaleXaf: Long = 0L,
    @ColumnInfo(defaultValue = "0") val costOfGoodsXaf: Long = 0L,
    @ColumnInfo(defaultValue = "0") val costSnapshotComplete: Boolean = false
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
    val createdAtMillis: Long,
    val category: String = "general",
    val description: String = "",
    val providerMemberIdsJson: String = "[]",
    val requiredWorkstationKindsJson: String = "[]",
    val packageSessions: Int? = null
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
    val createdAtMillis: Long,
    val addressLine: String = "",
    val neighborhood: String = "",
    val landmark: String = "",
    val latitude: Double? = null,
    val longitude: Double? = null,
    val locationAccuracyMeters: Float? = null,
    val locationCapturedAtMillis: Long? = null,
    val locationConsentAtMillis: Long? = null
)

@Entity(
    tableName = "local_customer_followups",
    indices = [
        Index(value = ["orgId", "siteId", "nextDueAtMillis"]),
        Index(value = ["customerId"]),
        Index(value = ["orgId", "siteId", "status"])
    ]
)
data class LocalCustomerFollowUp(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val customerId: String,
    val title: String,
    val frequency: String,
    val channel: String,
    val notes: String,
    val nextDueAtMillis: Long,
    val status: String = "active",
    val createdByMemberId: String,
    val createdAtMillis: Long,
    val updatedAtMillis: Long,
    val lastCompletedAtMillis: Long? = null
)

@Entity(
    tableName = "local_customer_contact_events",
    indices = [
        Index(value = ["orgId", "siteId", "happenedAtMillis"]),
        Index(value = ["customerId", "happenedAtMillis"]),
        Index(value = ["followUpId"])
    ]
)
data class LocalCustomerContactEvent(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val customerId: String,
    val followUpId: String,
    val eventType: String,
    val outcome: String,
    val notes: String,
    val actorMemberId: String,
    val happenedAtMillis: Long
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
    val createdAtMillis: Long,
    @ColumnInfo(defaultValue = "''") val supplierWhatsApp: String = ""
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
    indices = [
        Index(value = ["orgId", "siteId", "recordType", "createdAtMillis"]),
        Index(value = ["orgId", "siteId", "reference"]),
        Index(value = ["orgId", "siteId", "workstationId", "createdAtMillis"])
    ]
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
    val createdAtMillis: Long,
    val workstationId: String? = null
)

@Entity(
    tableName = "local_workflow_events",
    indices = [
        Index(value = ["orgId", "siteId", "aggregateType", "aggregateId", "createdAtMillis"]),
        Index(value = ["actorMemberId", "createdAtMillis"])
    ]
)
data class LocalWorkflowEvent(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val aggregateType: String,
    val aggregateId: String,
    val fromStatus: String,
    val toStatus: String,
    val reason: String,
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

data class LocalInventoryImportRow(
    val sku: String,
    val name: String,
    val unit: String,
    val quantity: Double,
    val reorderLevel: Double,
    val unitCostXaf: Long?,
    val sellingPriceXaf: Long?,
    val supplierWhatsApp: String = ""
)

@Entity(tableName = "local_recurring_charges", indices = [
    Index(value = ["orgId", "siteId", "nextDueAtMillis"]),
    Index(value = ["orgId", "siteId", "active"])
])
data class LocalRecurringCharge(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val name: String,
    val category: String,
    val amountXaf: Long,
    val recurrence: String,
    val nextDueAtMillis: Long,
    val reminderDays: Int,
    val active: Boolean,
    val createdByMemberId: String,
    val createdAtMillis: Long,
    val updatedAtMillis: Long,
    val lastReminderAtMillis: Long? = null
)

@Entity(tableName = "local_charge_payments", indices = [
    Index(value = ["orgId", "siteId", "paidAtMillis"]),
    Index(value = ["chargeId", "referenceDueAtMillis"])
])
data class LocalChargePayment(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val chargeId: String,
    val referenceDueAtMillis: Long,
    val paidAtMillis: Long,
    val amountXaf: Long,
    val actorMemberId: String
)

@Entity(tableName = "local_loyalty_programs", indices = [
    Index(value = ["orgId", "activityProfile", "programCode"], unique = true)
])
data class LocalLoyaltyProgram(
    @PrimaryKey val id: String,
    val orgId: String,
    val activityProfile: String,
    val programCode: String,
    val name: String,
    val description: String,
    val metricCode: String,
    val unitAmountXaf: Long,
    val targetValue: Long,
    val rewardDescription: String,
    val windowDays: Int,
    val active: Boolean,
    val createdAtMillis: Long,
    val updatedAtMillis: Long
)

@Entity(tableName = "local_loyalty_events", indices = [
    Index(value = ["orgId", "siteId", "programId", "customerId", "createdAtMillis"]),
    Index(value = ["relatedEventId"])
])
data class LocalLoyaltyEvent(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val programId: String,
    val customerId: String,
    val eventType: String,
    val amountXaf: Long,
    val metricDelta: Long,
    val waveNumber: Int?,
    val relatedEventId: String?,
    val rewardStatus: String?,
    val description: String,
    val actorMemberId: String,
    val createdAtMillis: Long
)


@Entity(
    tableName = "local_suppliers",
    indices = [Index(value = ["orgId", "siteId", "normalizedName"], unique = true), Index(value = ["orgId", "siteId", "active"])]
)
data class LocalSupplier(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val name: String,
    val normalizedName: String,
    val phone: String,
    val whatsapp: String,
    val email: String,
    val address: String,
    val paymentTermsDays: Int,
    val notes: String,
    val active: Boolean,
    val createdByMemberId: String,
    val createdAtMillis: Long,
    val updatedAtMillis: Long
)

@Entity(
    tableName = "local_purchase_documents",
    indices = [
        Index(value = ["orgId", "siteId", "status", "createdAtMillis"]),
        Index(value = ["supplierId", "createdAtMillis"]),
        Index(value = ["siteId", "reference"], unique = true)
    ]
)
data class LocalPurchaseDocument(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val supplierId: String,
    val supplierNameSnapshot: String,
    val reference: String,
    val supplierInvoiceNumber: String,
    val status: String,
    val subtotalXaf: Long,
    val recoverableTaxXaf: Long,
    val nonRecoverableTaxXaf: Long,
    val shippingXaf: Long,
    val otherFeesXaf: Long,
    val receivedBaseXaf: Long,
    val recognizedNonRecoverableXaf: Long,
    val recognizedRecoverableTaxXaf: Long,
    val receivedTotalXaf: Long,
    val paidTotalXaf: Long,
    val dueAtMillis: Long?,
    val notes: String,
    val actorMemberId: String,
    val createdAtMillis: Long,
    val updatedAtMillis: Long
)

@Entity(
    tableName = "local_purchase_lines",
    indices = [Index(value = ["purchaseId"]), Index(value = ["orgId", "siteId", "inventoryItemId"])]
)
data class LocalPurchaseLine(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val purchaseId: String,
    val inventoryItemId: String?,
    val description: String,
    val itemType: String,
    val unit: String,
    val quantityOrdered: Double,
    val quantityReceived: Double,
    val unitCostXaf: Long,
    val createdAtMillis: Long
)

@Entity(
    tableName = "local_purchase_receipts",
    indices = [
        Index(value = ["purchaseId", "receivedAtMillis"]),
        Index(value = ["orgId", "siteId", "receivedAtMillis"]),
        Index(value = ["orgId", "idempotencyKey"], unique = true)
    ]
)
data class LocalPurchaseReceipt(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val purchaseId: String,
    val purchaseLineId: String,
    val quantityReceived: Double,
    val baseCostXaf: Long,
    val nonRecoverableCostXaf: Long,
    val recoverableTaxXaf: Long,
    val actorMemberId: String,
    val receivedAtMillis: Long,
    @ColumnInfo(defaultValue = "''") val idempotencyKey: String = ""
)

@Entity(
    tableName = "local_supplier_payments",
    indices = [
        Index(value = ["orgId", "siteId", "paidAtMillis"]),
        Index(value = ["purchaseId", "paidAtMillis"]),
        Index(value = ["orgId", "idempotencyKey"], unique = true)
    ]
)
data class LocalSupplierPayment(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val purchaseId: String,
    val supplierId: String,
    val cashSessionId: String?,
    val amountXaf: Long,
    val paymentMethod: String,
    val paymentReference: String,
    val idempotencyKey: String,
    val actorMemberId: String,
    val paidAtMillis: Long
)

@Entity(
    tableName = "local_accounting_entries",
    indices = [
        Index(value = ["orgId", "sourceType", "sourceId", "eventCode"], unique = true),
        Index(value = ["orgId", "siteId", "occurredAtMillis"]),
        Index(value = ["orgId", "siteId", "debitAccount", "occurredAtMillis"]),
        Index(value = ["orgId", "siteId", "creditAccount", "occurredAtMillis"])
    ]
)
data class LocalAccountingEntry(
    @PrimaryKey val id: String,
    val orgId: String,
    val siteId: String,
    val journalBatchId: String,
    val sourceType: String,
    val sourceId: String,
    val eventCode: String,
    val debitAccount: String,
    val creditAccount: String,
    val amountXaf: Long,
    val description: String,
    val actorMemberId: String,
    val occurredAtMillis: Long
)

data class SupplierPurchaseLineDraft(
    val inventoryItemId: String?,
    val description: String,
    val itemType: String,
    val unit: String,
    val quantity: Double,
    val unitCostXaf: Long
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

    @Query("SELECT * FROM local_pressing_status_events WHERE orderId = :orderId AND orgId = :orgId AND siteId = :siteId ORDER BY createdAtMillis DESC")
    fun observePressingStatusEvents(orderId: String, orgId: String, siteId: String): Flow<List<LocalPressingStatusEvent>>

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

    @Query("SELECT * FROM local_appointments WHERE id = :appointmentId AND orgId = :orgId AND siteId = :siteId LIMIT 1")
    suspend fun findAppointment(orgId: String, siteId: String, appointmentId: String): LocalAppointment?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertAppointment(appointment: LocalAppointment)

    @Update
    suspend fun updateAppointment(appointment: LocalAppointment)

    @Query("SELECT COUNT(*) FROM local_appointments WHERE orgId = :orgId AND siteId = :siteId AND id <> :excludedAppointmentId AND status NOT IN ('cancelled','completed') AND startsAtMillis < :endsAtMillis AND endsAtMillis > :startsAtMillis AND ((:workstationId IS NOT NULL AND workstationId = :workstationId) OR assignedMemberId = :assignedMemberId)")
    suspend fun countAppointmentConflictsExcludingId(orgId: String, siteId: String, excludedAppointmentId: String, workstationId: String?, assignedMemberId: String, startsAtMillis: Long, endsAtMillis: Long): Int

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

    @Query("SELECT COALESCE(SUM(stockQuantity), 0) FROM local_sales WHERE orgId = :orgId AND siteId = :siteId AND inventoryItemId = :itemId AND status = 'pending'")
    suspend fun pendingInventoryReservations(orgId: String, siteId: String, itemId: String): Double

    @Query("SELECT * FROM local_sales WHERE id = :saleId AND orgId = :orgId AND siteId = :siteId LIMIT 1")
    suspend fun findSale(orgId: String, siteId: String, saleId: String): LocalSale?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertSale(sale: LocalSale)

    @Update
    suspend fun updateSale(sale: LocalSale)

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

    @Query("SELECT * FROM local_services WHERE id = :serviceId AND orgId = :orgId AND siteId = :siteId LIMIT 1")
    suspend fun findService(orgId: String, siteId: String, serviceId: String): LocalService?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertService(service: LocalService)

    @Update
    suspend fun updateService(service: LocalService)

    @Query("SELECT * FROM local_customers WHERE orgId = :orgId AND siteId = :siteId ORDER BY displayName COLLATE NOCASE ASC")
    fun observeCustomers(orgId: String, siteId: String): Flow<List<LocalCustomer>>

    @Query("SELECT * FROM local_customers WHERE id = :customerId AND orgId = :orgId AND siteId = :siteId LIMIT 1")
    suspend fun findCustomer(customerId: String, orgId: String, siteId: String): LocalCustomer?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertCustomer(customer: LocalCustomer)

    @Update
    suspend fun updateCustomer(customer: LocalCustomer)

    @Query("SELECT * FROM local_customer_followups WHERE orgId = :orgId AND siteId = :siteId AND status = 'active' ORDER BY nextDueAtMillis ASC")
    fun observeCustomerFollowUps(orgId: String, siteId: String): Flow<List<LocalCustomerFollowUp>>

    @Query("SELECT * FROM local_customer_followups WHERE id = :followUpId AND orgId = :orgId AND siteId = :siteId LIMIT 1")
    suspend fun findCustomerFollowUp(followUpId: String, orgId: String, siteId: String): LocalCustomerFollowUp?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertCustomerFollowUp(followUp: LocalCustomerFollowUp)

    @Update
    suspend fun updateCustomerFollowUp(followUp: LocalCustomerFollowUp)

    @Query("SELECT * FROM local_customer_contact_events WHERE orgId = :orgId AND siteId = :siteId ORDER BY happenedAtMillis DESC LIMIT 100")
    fun observeCustomerContactEvents(orgId: String, siteId: String): Flow<List<LocalCustomerContactEvent>>

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertCustomerContactEvent(event: LocalCustomerContactEvent)

    @Query("SELECT * FROM local_inventory_items WHERE orgId = :orgId AND siteId = :siteId AND active = 1 ORDER BY name COLLATE NOCASE ASC")
    fun observeInventoryItems(orgId: String, siteId: String): Flow<List<LocalInventoryItem>>

    @Query("SELECT * FROM local_inventory_items WHERE id = :itemId AND orgId = :orgId AND siteId = :siteId LIMIT 1")
    suspend fun findInventoryItem(itemId: String, orgId: String, siteId: String): LocalInventoryItem?

    @Query("SELECT * FROM local_inventory_items WHERE orgId = :orgId AND siteId = :siteId AND sku = :sku")
    suspend fun findInventoryItemsBySku(orgId: String, siteId: String, sku: String): List<LocalInventoryItem>

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

    // Read operating expenses from the journal, not the cash-outflow table.
    // Supplier settlements affect treasury and payable balances, never a second time the P&L.
    @Query("SELECT COALESCE(SUM(amountXaf), 0) FROM local_accounting_entries WHERE orgId = :orgId AND siteId = :siteId AND debitAccount LIKE 'OPERATING_EXPENSE%' AND occurredAtMillis BETWEEN :fromMillis AND :toMillis")
    fun observeOperatingExpensesTotal(orgId: String, siteId: String, fromMillis: Long, toMillis: Long): Flow<Long>

    @Query("SELECT COALESCE(SUM(amountXaf), 0) FROM local_supplier_payments WHERE orgId = :orgId AND siteId = :siteId AND paidAtMillis BETWEEN :fromMillis AND :toMillis")
    fun observeSupplierPaymentsTotal(orgId: String, siteId: String, fromMillis: Long, toMillis: Long): Flow<Long>

    @Query("SELECT COUNT(*) FROM local_sales WHERE orgId = :orgId AND siteId = :siteId AND status = 'confirmed' AND createdAtMillis BETWEEN :fromMillis AND :toMillis")
    fun observeConfirmedSalesCount(orgId: String, siteId: String, fromMillis: Long, toMillis: Long): Flow<Int>

    @Query("SELECT COALESCE(SUM(costOfGoodsXaf), 0) FROM local_sales WHERE orgId = :orgId AND siteId = :siteId AND status = 'confirmed' AND costSnapshotComplete = 1 AND createdAtMillis BETWEEN :fromMillis AND :toMillis")
    fun observeCostOfGoodsTotal(orgId: String, siteId: String, fromMillis: Long, toMillis: Long): Flow<Long>

    @Query("SELECT COUNT(*) FROM local_sales WHERE orgId = :orgId AND siteId = :siteId AND status = 'confirmed' AND costSnapshotComplete = 0 AND createdAtMillis BETWEEN :fromMillis AND :toMillis")
    fun observeUncostedSalesCount(orgId: String, siteId: String, fromMillis: Long, toMillis: Long): Flow<Int>

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

    @Query("SELECT * FROM local_management_records WHERE orgId = :orgId AND siteId = :siteId AND counterparty = :staffName AND recordType IN ('staff_clock_in','staff_break_start','staff_break_end','staff_clock_out') ORDER BY createdAtMillis DESC LIMIT 1")
    suspend fun findLatestStaffTimeEvent(orgId: String, siteId: String, staffName: String): LocalManagementRecord?

    @Query("SELECT * FROM local_management_records WHERE orgId = :orgId AND siteId = :siteId ORDER BY createdAtMillis DESC")
    fun observeManagementRecords(orgId: String, siteId: String): Flow<List<LocalManagementRecord>>

    @Query("SELECT * FROM local_management_records WHERE orgId = :orgId AND siteId = :siteId AND recordType = :recordType ORDER BY createdAtMillis DESC")
    fun observeManagementRecordsByType(orgId: String, siteId: String, recordType: String): Flow<List<LocalManagementRecord>>

    @Query("SELECT * FROM local_management_records WHERE orgId = :orgId AND recordType = :recordType ORDER BY createdAtMillis DESC")
    fun observeOrganizationManagementRecordsByType(orgId: String, recordType: String): Flow<List<LocalManagementRecord>>

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertManagementRecord(record: LocalManagementRecord)

    @Query("SELECT * FROM local_management_records WHERE id = :recordId AND orgId = :orgId AND siteId = :siteId LIMIT 1")
    suspend fun findManagementRecord(orgId: String, siteId: String, recordId: String): LocalManagementRecord?

    @Update
    suspend fun updateManagementRecord(record: LocalManagementRecord)

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertWorkflowEvent(event: LocalWorkflowEvent)

    @Query("SELECT * FROM local_workflow_events WHERE orgId = :orgId AND siteId = :siteId AND aggregateType = :aggregateType AND aggregateId = :aggregateId ORDER BY createdAtMillis DESC")
    fun observeWorkflowEvents(orgId: String, siteId: String, aggregateType: String, aggregateId: String): Flow<List<LocalWorkflowEvent>>

    @Query("SELECT * FROM local_inventory_valuations WHERE orgId = :orgId AND siteId = :siteId ORDER BY updatedAtMillis DESC")
    fun observeInventoryValuations(orgId: String, siteId: String): Flow<List<LocalInventoryValuation>>

    @Query("SELECT * FROM local_inventory_valuations WHERE orgId = :orgId AND siteId = :siteId AND inventoryItemId = :itemId LIMIT 1")
    suspend fun findInventoryValuation(orgId: String, siteId: String, itemId: String): LocalInventoryValuation?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertInventoryValuation(valuation: LocalInventoryValuation)



    @Query("SELECT * FROM local_sales WHERE orgId = :orgId AND siteId IN (:siteIds) AND createdAtMillis >= :fromMillis ORDER BY createdAtMillis DESC LIMIT 50000")
    fun observeSalesForSites(orgId: String, siteIds: List<String>, fromMillis: Long): Flow<List<LocalSale>>

    @Query("SELECT * FROM local_accounting_entries WHERE orgId = :orgId AND siteId IN (:siteIds) AND occurredAtMillis >= :fromMillis ORDER BY occurredAtMillis DESC LIMIT 100000")
    fun observeAccountingEntriesForSites(orgId: String, siteIds: List<String>, fromMillis: Long): Flow<List<LocalAccountingEntry>>

    @Query("SELECT * FROM local_management_records WHERE orgId = :orgId AND siteId IN (:siteIds) AND recordType = :recordType ORDER BY createdAtMillis DESC")
    fun observeManagementRecordsForSites(orgId: String, siteIds: List<String>, recordType: String): Flow<List<LocalManagementRecord>>

    @Query("SELECT COALESCE(SUM(receivedTotalXaf - paidTotalXaf), 0) FROM local_purchase_documents WHERE orgId = :orgId AND siteId IN (:siteIds) AND status <> 'cancelled'")
    fun observeSupplierPayablesForSites(orgId: String, siteIds: List<String>): Flow<Long>

    @Query("SELECT COUNT(*) FROM local_inventory_items WHERE orgId = :orgId AND siteId IN (:siteIds) AND active = 1 AND quantity <= reorderLevel")
    fun observeLowStockCountForSites(orgId: String, siteIds: List<String>): Flow<Int>

    @Query("SELECT * FROM local_suppliers WHERE orgId = :orgId AND siteId = :siteId AND active = 1 ORDER BY name COLLATE NOCASE ASC")
    fun observeSuppliers(orgId: String, siteId: String): Flow<List<LocalSupplier>>

    @Query("SELECT * FROM local_suppliers WHERE id = :supplierId AND orgId = :orgId AND siteId = :siteId LIMIT 1")
    suspend fun findSupplier(supplierId: String, orgId: String, siteId: String): LocalSupplier?

    @Query("SELECT * FROM local_suppliers WHERE orgId = :orgId AND siteId = :siteId AND normalizedName = :normalizedName LIMIT 1")
    suspend fun findSupplierByName(orgId: String, siteId: String, normalizedName: String): LocalSupplier?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertSupplier(supplier: LocalSupplier)

    @Update
    suspend fun updateSupplier(supplier: LocalSupplier)

    @Query("SELECT * FROM local_purchase_documents WHERE orgId = :orgId AND siteId = :siteId ORDER BY createdAtMillis DESC")
    fun observePurchaseDocuments(orgId: String, siteId: String): Flow<List<LocalPurchaseDocument>>

    @Query("SELECT * FROM local_purchase_documents WHERE id = :purchaseId AND orgId = :orgId AND siteId = :siteId LIMIT 1")
    suspend fun findPurchaseDocument(purchaseId: String, orgId: String, siteId: String): LocalPurchaseDocument?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertPurchaseDocument(purchase: LocalPurchaseDocument)

    @Update
    suspend fun updatePurchaseDocument(purchase: LocalPurchaseDocument)

    @Query("SELECT * FROM local_purchase_lines WHERE purchaseId = :purchaseId AND orgId = :orgId AND siteId = :siteId ORDER BY createdAtMillis ASC")
    fun observePurchaseLines(orgId: String, siteId: String, purchaseId: String): Flow<List<LocalPurchaseLine>>

    @Query("SELECT * FROM local_purchase_lines WHERE purchaseId = :purchaseId AND orgId = :orgId AND siteId = :siteId ORDER BY createdAtMillis ASC")
    suspend fun getPurchaseLines(orgId: String, siteId: String, purchaseId: String): List<LocalPurchaseLine>

    @Query("SELECT * FROM local_purchase_lines WHERE id = :lineId AND purchaseId = :purchaseId AND orgId = :orgId AND siteId = :siteId LIMIT 1")
    suspend fun findPurchaseLine(orgId: String, siteId: String, purchaseId: String, lineId: String): LocalPurchaseLine?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertPurchaseLine(line: LocalPurchaseLine)

    @Update
    suspend fun updatePurchaseLine(line: LocalPurchaseLine)

    @Query("SELECT * FROM local_purchase_receipts WHERE purchaseId = :purchaseId AND orgId = :orgId AND siteId = :siteId ORDER BY receivedAtMillis DESC")
    fun observePurchaseReceipts(orgId: String, siteId: String, purchaseId: String): Flow<List<LocalPurchaseReceipt>>

    @Query("SELECT * FROM local_purchase_receipts WHERE orgId = :orgId AND idempotencyKey = :idempotencyKey LIMIT 1")
    suspend fun findPurchaseReceiptByKey(orgId: String, idempotencyKey: String): LocalPurchaseReceipt?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertPurchaseReceipt(receipt: LocalPurchaseReceipt)

    @Query("SELECT * FROM local_supplier_payments WHERE orgId = :orgId AND siteId = :siteId ORDER BY paidAtMillis DESC")
    fun observeSupplierPayments(orgId: String, siteId: String): Flow<List<LocalSupplierPayment>>

    @Query("SELECT * FROM local_supplier_payments WHERE orgId = :orgId AND idempotencyKey = :idempotencyKey LIMIT 1")
    suspend fun findSupplierPaymentByKey(orgId: String, idempotencyKey: String): LocalSupplierPayment?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertSupplierPayment(payment: LocalSupplierPayment)

    @Query("SELECT * FROM local_accounting_entries WHERE orgId = :orgId AND siteId = :siteId AND occurredAtMillis BETWEEN :fromMillis AND :toMillis ORDER BY occurredAtMillis DESC")
    fun observeAccountingEntries(orgId: String, siteId: String, fromMillis: Long, toMillis: Long): Flow<List<LocalAccountingEntry>>

    @Query("SELECT * FROM local_accounting_entries WHERE orgId = :orgId AND siteId = :siteId ORDER BY occurredAtMillis DESC")
    fun observeAllAccountingEntries(orgId: String, siteId: String): Flow<List<LocalAccountingEntry>>

    @Query("SELECT COUNT(*) FROM local_accounting_entries WHERE orgId = :orgId AND sourceType = :sourceType AND sourceId = :sourceId AND eventCode = :eventCode")
    suspend fun hasAccountingEntry(orgId: String, sourceType: String, sourceId: String, eventCode: String): Int

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertAccountingEntry(entry: LocalAccountingEntry)

    @Query("SELECT COALESCE(SUM(receivedTotalXaf - paidTotalXaf), 0) FROM local_purchase_documents WHERE orgId = :orgId AND siteId = :siteId AND status <> 'cancelled'")
    fun observeSupplierPayables(orgId: String, siteId: String): Flow<Long>

    @Query("SELECT * FROM local_recurring_charges WHERE orgId = :orgId AND siteId = :siteId ORDER BY nextDueAtMillis ASC")
    fun observeRecurringCharges(orgId: String, siteId: String): Flow<List<LocalRecurringCharge>>

    @Query("SELECT * FROM local_recurring_charges WHERE orgId = :orgId AND active = 1")
    suspend fun findActiveRecurringCharges(orgId: String): List<LocalRecurringCharge>

    @Query("SELECT * FROM local_recurring_charges WHERE id = :id AND orgId = :orgId AND siteId = :siteId LIMIT 1")
    suspend fun findRecurringCharge(id: String, orgId: String, siteId: String): LocalRecurringCharge?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertRecurringCharge(charge: LocalRecurringCharge)

    @Update
    suspend fun updateRecurringCharge(charge: LocalRecurringCharge)

    @Query("SELECT * FROM local_charge_payments WHERE orgId = :orgId AND siteId = :siteId ORDER BY paidAtMillis DESC LIMIT 200")
    fun observeChargePayments(orgId: String, siteId: String): Flow<List<LocalChargePayment>>

    @Query("SELECT COALESCE(SUM(amountXaf), 0) FROM local_charge_payments WHERE chargeId = :chargeId AND referenceDueAtMillis = :referenceDueAtMillis")
    suspend fun sumChargePaymentsForCycle(chargeId: String, referenceDueAtMillis: Long): Long

    @Query("SELECT COALESCE(SUM(amountXaf), 0) FROM local_charge_payments WHERE orgId = :orgId AND siteId = :siteId AND paidAtMillis BETWEEN :fromMillis AND :toMillis")
    suspend fun sumChargePaymentsForPeriod(orgId: String, siteId: String, fromMillis: Long, toMillis: Long): Long

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertChargePayment(payment: LocalChargePayment)

    @Query("SELECT * FROM local_loyalty_programs WHERE orgId = :orgId AND activityProfile = :activityProfile ORDER BY programCode ASC")
    fun observeLoyaltyPrograms(orgId: String, activityProfile: String): Flow<List<LocalLoyaltyProgram>>

    @Query("SELECT * FROM local_loyalty_programs WHERE orgId = :orgId AND activityProfile = :activityProfile AND programCode = :programCode LIMIT 1")
    suspend fun findLoyaltyProgram(orgId: String, activityProfile: String, programCode: String): LocalLoyaltyProgram?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertLoyaltyProgram(program: LocalLoyaltyProgram)

    @Query("SELECT * FROM local_loyalty_events WHERE orgId = :orgId AND siteId = :siteId AND programId = :programId ORDER BY createdAtMillis DESC LIMIT 300")
    fun observeLoyaltyEvents(orgId: String, siteId: String, programId: String): Flow<List<LocalLoyaltyEvent>>

    @Query("SELECT COALESCE(SUM(metricDelta), 0) FROM local_loyalty_events WHERE orgId = :orgId AND programId = :programId AND customerId = :customerId AND eventType = 'activity' AND createdAtMillis >= :sinceMillis")
    suspend fun sumLoyaltyMetric(orgId: String, programId: String, customerId: String, sinceMillis: Long): Long

    @Query("SELECT COALESCE(SUM(amountXaf), 0) FROM local_loyalty_events WHERE orgId = :orgId AND programId = :programId AND customerId = :customerId AND eventType = 'activity' AND createdAtMillis >= :sinceMillis")
    suspend fun sumLoyaltyAmount(orgId: String, programId: String, customerId: String, sinceMillis: Long): Long

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertLoyaltyEvent(event: LocalLoyaltyEvent)

    @Query("UPDATE local_loyalty_events SET rewardStatus = 'redeemed' WHERE id = :eventId AND orgId = :orgId AND siteId = :siteId AND eventType = 'reward_earned' AND rewardStatus = 'available'")
    suspend fun redeemLoyaltyReward(eventId: String, orgId: String, siteId: String): Int
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
        LocalCustomerFollowUp::class,
        LocalCustomerContactEvent::class,
        LocalInventoryItem::class,
        LocalInventoryMovement::class,
        LocalSupportRequest::class,
        LocalManagementRecord::class,
        LocalWorkflowEvent::class,
        LocalInventoryValuation::class,
        LocalRecurringCharge::class,
        LocalChargePayment::class,
        LocalLoyaltyProgram::class,
        LocalLoyaltyEvent::class,
        LocalSupplier::class,
        LocalPurchaseDocument::class,
        LocalPurchaseLine::class,
        LocalPurchaseReceipt::class,
        LocalSupplierPayment::class,
        LocalAccountingEntry::class
    ],
    version = 11,
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

val NS_SERVICES_MIGRATION_2_3: Migration = object : Migration(2, 3) {
    override fun migrate(database: SupportSQLiteDatabase) {
        database.execSQL("ALTER TABLE local_customers ADD COLUMN addressLine TEXT NOT NULL DEFAULT ''")
        database.execSQL("ALTER TABLE local_customers ADD COLUMN neighborhood TEXT NOT NULL DEFAULT ''")
        database.execSQL("ALTER TABLE local_customers ADD COLUMN landmark TEXT NOT NULL DEFAULT ''")
        database.execSQL("ALTER TABLE local_customers ADD COLUMN latitude REAL")
        database.execSQL("ALTER TABLE local_customers ADD COLUMN longitude REAL")
        database.execSQL("ALTER TABLE local_customers ADD COLUMN locationAccuracyMeters REAL")
        database.execSQL("ALTER TABLE local_customers ADD COLUMN locationCapturedAtMillis INTEGER")
        database.execSQL("ALTER TABLE local_customers ADD COLUMN locationConsentAtMillis INTEGER")
        database.execSQL(
            "CREATE TABLE IF NOT EXISTS local_customer_followups (" +
                "id TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, siteId TEXT NOT NULL, customerId TEXT NOT NULL, " +
                "title TEXT NOT NULL, frequency TEXT NOT NULL, channel TEXT NOT NULL, notes TEXT NOT NULL, " +
                "nextDueAtMillis INTEGER NOT NULL, status TEXT NOT NULL, createdByMemberId TEXT NOT NULL, " +
                "createdAtMillis INTEGER NOT NULL, updatedAtMillis INTEGER NOT NULL, lastCompletedAtMillis INTEGER)"
        )
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_customer_followups_orgId_siteId_nextDueAtMillis ON local_customer_followups(orgId, siteId, nextDueAtMillis)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_customer_followups_customerId ON local_customer_followups(customerId)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_customer_followups_orgId_siteId_status ON local_customer_followups(orgId, siteId, status)")
        database.execSQL(
            "CREATE TABLE IF NOT EXISTS local_customer_contact_events (" +
                "id TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, siteId TEXT NOT NULL, customerId TEXT NOT NULL, " +
                "followUpId TEXT NOT NULL, eventType TEXT NOT NULL, outcome TEXT NOT NULL, notes TEXT NOT NULL, " +
                "actorMemberId TEXT NOT NULL, happenedAtMillis INTEGER NOT NULL)"
        )
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_customer_contact_events_orgId_siteId_happenedAtMillis ON local_customer_contact_events(orgId, siteId, happenedAtMillis)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_customer_contact_events_customerId_happenedAtMillis ON local_customer_contact_events(customerId, happenedAtMillis)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_customer_contact_events_followUpId ON local_customer_contact_events(followUpId)")
    }
}

val NS_SERVICES_MIGRATION_3_4: Migration = object : Migration(3, 4) {
    override fun migrate(database: SupportSQLiteDatabase) {
        database.execSQL(
            "CREATE TABLE IF NOT EXISTS local_workflow_events (" +
                "id TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, siteId TEXT NOT NULL, " +
                "aggregateType TEXT NOT NULL, aggregateId TEXT NOT NULL, fromStatus TEXT NOT NULL, " +
                "toStatus TEXT NOT NULL, reason TEXT NOT NULL, actorMemberId TEXT NOT NULL, createdAtMillis INTEGER NOT NULL)"
        )
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_workflow_events_orgId_siteId_aggregateType_aggregateId_createdAtMillis ON local_workflow_events(orgId, siteId, aggregateType, aggregateId, createdAtMillis)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_workflow_events_actorMemberId_createdAtMillis ON local_workflow_events(actorMemberId, createdAtMillis)")
        database.execSQL("ALTER TABLE local_services ADD COLUMN category TEXT NOT NULL DEFAULT 'general'")
        database.execSQL("ALTER TABLE local_services ADD COLUMN description TEXT NOT NULL DEFAULT ''")
        database.execSQL("ALTER TABLE local_services ADD COLUMN providerMemberIdsJson TEXT NOT NULL DEFAULT '[]'")
        database.execSQL("ALTER TABLE local_services ADD COLUMN requiredWorkstationKindsJson TEXT NOT NULL DEFAULT '[]'")
        database.execSQL("ALTER TABLE local_services ADD COLUMN packageSessions INTEGER")
    }
}

val NS_SERVICES_MIGRATION_4_5: Migration = object : Migration(4, 5) {
    override fun migrate(database: SupportSQLiteDatabase) {
        database.execSQL("ALTER TABLE local_management_records ADD COLUMN workstationId TEXT")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_management_records_orgId_siteId_workstationId_createdAtMillis ON local_management_records(orgId, siteId, workstationId, createdAtMillis)")
    }
}

val NS_SERVICES_MIGRATION_5_6: Migration = object : Migration(5, 6) {
    override fun migrate(database: SupportSQLiteDatabase) {
        database.execSQL("ALTER TABLE local_pressing_status_events ADD COLUMN reason TEXT NOT NULL DEFAULT ''")
    }
}

val NS_SERVICES_MIGRATION_6_7: Migration = object : Migration(6, 7) {
    override fun migrate(database: SupportSQLiteDatabase) {
        database.execSQL("ALTER TABLE local_sales ADD COLUMN inventoryItemId TEXT")
        database.execSQL("ALTER TABLE local_sales ADD COLUMN stockQuantity REAL")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_sales_orgId_siteId_inventoryItemId_status ON local_sales(orgId, siteId, inventoryItemId, status)")
    }
}

val NS_SERVICES_MIGRATION_7_8: Migration = object : Migration(7, 8) {
    override fun migrate(database: SupportSQLiteDatabase) {
        database.execSQL("ALTER TABLE local_inventory_items ADD COLUMN supplierWhatsApp TEXT NOT NULL DEFAULT ''")
        database.execSQL("CREATE TABLE IF NOT EXISTS local_recurring_charges (id TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, siteId TEXT NOT NULL, name TEXT NOT NULL, category TEXT NOT NULL, amountXaf INTEGER NOT NULL, recurrence TEXT NOT NULL, nextDueAtMillis INTEGER NOT NULL, reminderDays INTEGER NOT NULL, active INTEGER NOT NULL, createdByMemberId TEXT NOT NULL, createdAtMillis INTEGER NOT NULL, updatedAtMillis INTEGER NOT NULL, lastReminderAtMillis INTEGER)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_recurring_charges_orgId_siteId_nextDueAtMillis ON local_recurring_charges(orgId, siteId, nextDueAtMillis)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_recurring_charges_orgId_siteId_active ON local_recurring_charges(orgId, siteId, active)")
        database.execSQL("CREATE TABLE IF NOT EXISTS local_charge_payments (id TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, siteId TEXT NOT NULL, chargeId TEXT NOT NULL, referenceDueAtMillis INTEGER NOT NULL, paidAtMillis INTEGER NOT NULL, amountXaf INTEGER NOT NULL, actorMemberId TEXT NOT NULL)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_charge_payments_orgId_siteId_paidAtMillis ON local_charge_payments(orgId, siteId, paidAtMillis)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_charge_payments_chargeId_referenceDueAtMillis ON local_charge_payments(chargeId, referenceDueAtMillis)")
        database.execSQL("CREATE TABLE IF NOT EXISTS local_loyalty_programs (id TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, activityProfile TEXT NOT NULL, programCode TEXT NOT NULL, name TEXT NOT NULL, description TEXT NOT NULL, metricCode TEXT NOT NULL, unitAmountXaf INTEGER NOT NULL, targetValue INTEGER NOT NULL, rewardDescription TEXT NOT NULL, windowDays INTEGER NOT NULL, active INTEGER NOT NULL, createdAtMillis INTEGER NOT NULL, updatedAtMillis INTEGER NOT NULL)")
        database.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_local_loyalty_programs_orgId_activityProfile_programCode ON local_loyalty_programs(orgId, activityProfile, programCode)")
        database.execSQL("CREATE TABLE IF NOT EXISTS local_loyalty_events (id TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, siteId TEXT NOT NULL, programId TEXT NOT NULL, customerId TEXT NOT NULL, eventType TEXT NOT NULL, amountXaf INTEGER NOT NULL, metricDelta INTEGER NOT NULL, waveNumber INTEGER, relatedEventId TEXT, rewardStatus TEXT, description TEXT NOT NULL, actorMemberId TEXT NOT NULL, createdAtMillis INTEGER NOT NULL)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_loyalty_events_orgId_siteId_programId_customerId_createdAtMillis ON local_loyalty_events(orgId, siteId, programId, customerId, createdAtMillis)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_loyalty_events_relatedEventId ON local_loyalty_events(relatedEventId)")
    }
}

val NS_SERVICES_MIGRATION_8_9: Migration = object : Migration(8, 9) {
    override fun migrate(database: SupportSQLiteDatabase) {
        database.execSQL("ALTER TABLE local_sales ADD COLUMN unitCostAtSaleXaf INTEGER NOT NULL DEFAULT 0")
        database.execSQL("ALTER TABLE local_sales ADD COLUMN costOfGoodsXaf INTEGER NOT NULL DEFAULT 0")
        database.execSQL("CREATE TABLE IF NOT EXISTS local_suppliers (id TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, siteId TEXT NOT NULL, name TEXT NOT NULL, normalizedName TEXT NOT NULL, phone TEXT NOT NULL, whatsapp TEXT NOT NULL, email TEXT NOT NULL, address TEXT NOT NULL, paymentTermsDays INTEGER NOT NULL, notes TEXT NOT NULL, active INTEGER NOT NULL, createdByMemberId TEXT NOT NULL, createdAtMillis INTEGER NOT NULL, updatedAtMillis INTEGER NOT NULL)")
        database.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_local_suppliers_orgId_siteId_normalizedName ON local_suppliers(orgId, siteId, normalizedName)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_suppliers_orgId_siteId_active ON local_suppliers(orgId, siteId, active)")
        database.execSQL("CREATE TABLE IF NOT EXISTS local_purchase_documents (id TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, siteId TEXT NOT NULL, supplierId TEXT NOT NULL, supplierNameSnapshot TEXT NOT NULL, reference TEXT NOT NULL, supplierInvoiceNumber TEXT NOT NULL, status TEXT NOT NULL, subtotalXaf INTEGER NOT NULL, recoverableTaxXaf INTEGER NOT NULL, nonRecoverableTaxXaf INTEGER NOT NULL, shippingXaf INTEGER NOT NULL, otherFeesXaf INTEGER NOT NULL, receivedBaseXaf INTEGER NOT NULL, recognizedNonRecoverableXaf INTEGER NOT NULL, recognizedRecoverableTaxXaf INTEGER NOT NULL, receivedTotalXaf INTEGER NOT NULL, paidTotalXaf INTEGER NOT NULL, dueAtMillis INTEGER, notes TEXT NOT NULL, actorMemberId TEXT NOT NULL, createdAtMillis INTEGER NOT NULL, updatedAtMillis INTEGER NOT NULL)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_purchase_documents_orgId_siteId_status_createdAtMillis ON local_purchase_documents(orgId, siteId, status, createdAtMillis)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_purchase_documents_supplierId_createdAtMillis ON local_purchase_documents(supplierId, createdAtMillis)")
        database.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_local_purchase_documents_siteId_reference ON local_purchase_documents(siteId, reference)")
        database.execSQL("CREATE TABLE IF NOT EXISTS local_purchase_lines (id TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, siteId TEXT NOT NULL, purchaseId TEXT NOT NULL, inventoryItemId TEXT, description TEXT NOT NULL, itemType TEXT NOT NULL, unit TEXT NOT NULL, quantityOrdered REAL NOT NULL, quantityReceived REAL NOT NULL, unitCostXaf INTEGER NOT NULL, createdAtMillis INTEGER NOT NULL)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_purchase_lines_purchaseId ON local_purchase_lines(purchaseId)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_purchase_lines_orgId_siteId_inventoryItemId ON local_purchase_lines(orgId, siteId, inventoryItemId)")
        database.execSQL("CREATE TABLE IF NOT EXISTS local_purchase_receipts (id TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, siteId TEXT NOT NULL, purchaseId TEXT NOT NULL, purchaseLineId TEXT NOT NULL, quantityReceived REAL NOT NULL, baseCostXaf INTEGER NOT NULL, nonRecoverableCostXaf INTEGER NOT NULL, recoverableTaxXaf INTEGER NOT NULL, actorMemberId TEXT NOT NULL, receivedAtMillis INTEGER NOT NULL)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_purchase_receipts_purchaseId_receivedAtMillis ON local_purchase_receipts(purchaseId, receivedAtMillis)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_purchase_receipts_orgId_siteId_receivedAtMillis ON local_purchase_receipts(orgId, siteId, receivedAtMillis)")
        database.execSQL("CREATE TABLE IF NOT EXISTS local_supplier_payments (id TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, siteId TEXT NOT NULL, purchaseId TEXT NOT NULL, supplierId TEXT NOT NULL, cashSessionId TEXT, amountXaf INTEGER NOT NULL, paymentMethod TEXT NOT NULL, paymentReference TEXT NOT NULL, idempotencyKey TEXT NOT NULL, actorMemberId TEXT NOT NULL, paidAtMillis INTEGER NOT NULL)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_supplier_payments_orgId_siteId_paidAtMillis ON local_supplier_payments(orgId, siteId, paidAtMillis)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_supplier_payments_purchaseId_paidAtMillis ON local_supplier_payments(purchaseId, paidAtMillis)")
        database.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_local_supplier_payments_orgId_idempotencyKey ON local_supplier_payments(orgId, idempotencyKey)")
        database.execSQL("CREATE TABLE IF NOT EXISTS local_accounting_entries (id TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, siteId TEXT NOT NULL, journalBatchId TEXT NOT NULL, sourceType TEXT NOT NULL, sourceId TEXT NOT NULL, eventCode TEXT NOT NULL, debitAccount TEXT NOT NULL, creditAccount TEXT NOT NULL, amountXaf INTEGER NOT NULL, description TEXT NOT NULL, actorMemberId TEXT NOT NULL, occurredAtMillis INTEGER NOT NULL)")
        database.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_local_accounting_entries_orgId_sourceType_sourceId_eventCode ON local_accounting_entries(orgId, sourceType, sourceId, eventCode)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_accounting_entries_orgId_siteId_occurredAtMillis ON local_accounting_entries(orgId, siteId, occurredAtMillis)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_accounting_entries_orgId_siteId_debitAccount_occurredAtMillis ON local_accounting_entries(orgId, siteId, debitAccount, occurredAtMillis)")
        database.execSQL("CREATE INDEX IF NOT EXISTS index_local_accounting_entries_orgId_siteId_creditAccount_occurredAtMillis ON local_accounting_entries(orgId, siteId, creditAccount, occurredAtMillis)")
        // One-time migration of existing outflows into the new journal; deterministic IDs make reruns safe.
        database.execSQL(
            "INSERT OR IGNORE INTO local_accounting_entries (id, orgId, siteId, journalBatchId, sourceType, sourceId, eventCode, debitAccount, creditAccount, amountXaf, description, actorMemberId, occurredAtMillis) " +
            "SELECT 'legacy-expense-' || id, orgId, siteId, 'legacy-expense:' || id, 'legacy_expense', id, 'expense_imported', " +
            "'OPERATING_EXPENSE:' || UPPER(category), 'TREASURY_UNSPECIFIED', amountXaf, description, actorMemberId, createdAtMillis " +
            "FROM local_expenses"
        )
        database.execSQL(
            "INSERT OR IGNORE INTO local_accounting_entries (id, orgId, siteId, journalBatchId, sourceType, sourceId, eventCode, debitAccount, creditAccount, amountXaf, description, actorMemberId, occurredAtMillis) " +
            "SELECT 'legacy-charge-payment-' || id, orgId, siteId, 'legacy-charge-payment:' || id, 'legacy_charge_payment', id, 'charge_payment_imported', " +
            "'OPERATING_EXPENSE_RECURRING', 'TREASURY_UNSPECIFIED', amountXaf, 'Ancien règlement de charge récurrente', actorMemberId, paidAtMillis " +
            "FROM local_charge_payments"
        )
    }
}


val NS_SERVICES_MIGRATION_9_10: Migration = object : Migration(9, 10) {
    override fun migrate(database: SupportSQLiteDatabase) {
        database.execSQL("ALTER TABLE local_sales ADD COLUMN costSnapshotComplete INTEGER NOT NULL DEFAULT 0")
    }
}

val NS_SERVICES_MIGRATION_10_11: Migration = object : Migration(10, 11) {
    override fun migrate(database: SupportSQLiteDatabase) {
        database.execSQL("ALTER TABLE local_purchase_receipts ADD COLUMN idempotencyKey TEXT NOT NULL DEFAULT ''")
        database.execSQL("UPDATE local_purchase_receipts SET idempotencyKey = 'legacy:' || id WHERE idempotencyKey = ''")
        database.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_local_purchase_receipts_orgId_idempotencyKey ON local_purchase_receipts(orgId, idempotencyKey)")
    }
}

class NaxaServicesLocalRepository(private val database: NsServicesDatabase) {
    val dao: NaxaServicesDao = database.naxaServicesDao()


    suspend fun saveSupplier(
        orgId: String, siteId: String, name: String, phone: String, whatsapp: String,
        email: String, address: String, paymentTermsDays: Int, notes: String, actorMemberId: String
    ): LocalSupplier = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && actorMemberId.isNotBlank())
        require(name.trim().length in 2..120 && paymentTermsDays in 0..365)
        val normalized = name.trim().lowercase(java.util.Locale.ROOT)
            .replace(Regex("\\s+"), " ")
        val current = dao.findSupplierByName(orgId, siteId, normalized)
        val now = System.currentTimeMillis()
        val supplier = if (current == null) {
            LocalSupplier(
                UUID.randomUUID().toString(), orgId, siteId, name.trim(), normalized,
                phone.trim(), whatsapp.filter(Char::isDigit), email.trim(), address.trim(),
                paymentTermsDays, notes.trim(), true, actorMemberId, now, now
            ).also { dao.insertSupplier(it) }
        } else {
            current.copy(
                name = name.trim(), phone = phone.trim(), whatsapp = whatsapp.filter(Char::isDigit),
                email = email.trim(), address = address.trim(), paymentTermsDays = paymentTermsDays,
                notes = notes.trim(), active = true, updatedAtMillis = now
            ).also { dao.updateSupplier(it) }
        }
        enqueue(orgId, "supplier", supplier.id, "supplier.saved", siteId)
        supplier
    }

    suspend fun createSupplierPurchase(
        orgId: String, siteId: String, supplierId: String, reference: String, invoiceNumber: String,
        lines: List<SupplierPurchaseLineDraft>, recoverableTaxXaf: Long, nonRecoverableTaxXaf: Long,
        shippingXaf: Long, otherFeesXaf: Long, dueAtMillis: Long?, notes: String, actorMemberId: String
    ): LocalPurchaseDocument = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && actorMemberId.isNotBlank())
        require(reference.trim().length in 3..80 && lines.isNotEmpty() && lines.size <= 100)
        require(recoverableTaxXaf >= 0L && nonRecoverableTaxXaf >= 0L && shippingXaf >= 0L && otherFeesXaf >= 0L)
        val supplier = dao.findSupplier(supplierId, orgId, siteId) ?: throw IllegalArgumentException("Fournisseur introuvable sur ce point de vente.")
        var subtotal = 0L
        lines.forEach { line ->
            require(line.description.isNotBlank() && line.quantity.isFinite() && line.quantity > 0.0)
            require(line.unitCostXaf > 0L && line.itemType in setOf("stock", "operating_expense", "fixed_asset"))
            if (line.itemType == "stock") {
                require(!line.inventoryItemId.isNullOrBlank() && dao.findInventoryItem(line.inventoryItemId, orgId, siteId) != null) {
                    "Chaque ligne de stock doit pointer vers un article actif du même site."
                }
            } else require(line.inventoryItemId == null) { "Une ligne hors stock ne doit pas référencer un article de stock." }
            val amount = (line.quantity * line.unitCostXaf).takeIf { it.isFinite() && it <= Long.MAX_VALUE.toDouble() }?.let { kotlin.math.round(it).toLong() }
                ?: throw IllegalArgumentException("Montant de ligne invalide.")
            require(amount > 0L && subtotal <= Long.MAX_VALUE - amount)
            subtotal += amount
        }
        val total = listOf(subtotal, recoverableTaxXaf, nonRecoverableTaxXaf, shippingXaf, otherFeesXaf)
            .fold(0L) { acc, value -> require(acc <= Long.MAX_VALUE - value); acc + value }
        require(total > 0L)
        val now = System.currentTimeMillis()
        val purchase = LocalPurchaseDocument(
            id = UUID.randomUUID().toString(), orgId = orgId, siteId = siteId, supplierId = supplier.id,
            supplierNameSnapshot = supplier.name, reference = reference.trim(), supplierInvoiceNumber = invoiceNumber.trim(),
            status = "ordered", subtotalXaf = subtotal, recoverableTaxXaf = recoverableTaxXaf,
            nonRecoverableTaxXaf = nonRecoverableTaxXaf, shippingXaf = shippingXaf, otherFeesXaf = otherFeesXaf,
            receivedBaseXaf = 0L, recognizedNonRecoverableXaf = 0L, recognizedRecoverableTaxXaf = 0L,
            receivedTotalXaf = 0L, paidTotalXaf = 0L, dueAtMillis = dueAtMillis,
            notes = notes.trim(), actorMemberId = actorMemberId, createdAtMillis = now, updatedAtMillis = now
        )
        dao.insertPurchaseDocument(purchase)
        lines.forEach { line ->
            dao.insertPurchaseLine(
                LocalPurchaseLine(
                    id = UUID.randomUUID().toString(), orgId = orgId, siteId = siteId,
                    purchaseId = purchase.id, inventoryItemId = line.inventoryItemId, description = line.description.trim(),
                    itemType = line.itemType, unit = line.unit.trim().ifBlank { "unité" },
                    quantityOrdered = line.quantity, quantityReceived = 0.0,
                    unitCostXaf = line.unitCostXaf, createdAtMillis = now
                )
            )
        }
        enqueue(orgId, "purchase", purchase.id, "purchase.ordered", siteId)
        purchase
    }

    suspend fun receiveSupplierPurchaseLine(
        orgId: String, siteId: String, purchaseId: String, lineId: String,
        quantityToReceive: Double, idempotencyKey: String, actorMemberId: String
    ): LocalPurchaseReceipt = database.withTransaction {
        require(quantityToReceive.isFinite() && quantityToReceive > 0.0 && actorMemberId.isNotBlank() && idempotencyKey.isNotBlank())
        dao.findPurchaseReceiptByKey(orgId, idempotencyKey)?.let { existing ->
            require(existing.siteId == siteId && existing.purchaseId == purchaseId &&
                existing.purchaseLineId == lineId &&
                kotlin.math.abs(existing.quantityReceived - quantityToReceive) <= 0.000001) {
                "Clé d'idempotence déjà utilisée pour une réception différente."
            }
            return@withTransaction existing
        }
        val purchase = dao.findPurchaseDocument(purchaseId, orgId, siteId) ?: throw IllegalArgumentException("Commande fournisseur introuvable.")
        require(purchase.status !in setOf("cancelled", "closed")) { "Cette commande est clôturée ou annulée." }
        val line = dao.findPurchaseLine(orgId, siteId, purchaseId, lineId) ?: throw IllegalArgumentException("Ligne d'achat introuvable.")
        val remaining = (line.quantityOrdered - line.quantityReceived).coerceAtLeast(0.0)
        require(quantityToReceive <= remaining + 0.000001) { "La quantité reçue dépasse le reliquat commandé." }
        val base = (quantityToReceive * line.unitCostXaf).takeIf { it.isFinite() && it <= Long.MAX_VALUE.toDouble() }?.let { kotlin.math.round(it).toLong() }
            ?: throw IllegalArgumentException("Valeur de réception invalide.")
        val nextReceivedBase = purchase.receivedBaseXaf + base
        require(nextReceivedBase <= purchase.subtotalXaf) { "La réception dépasse le montant de base de la commande." }
        fun allocate(total: Long, receivedBase: Long): Long =
            if (purchase.subtotalXaf <= 0L) 0L
            else kotlin.math.round(total.toDouble() * receivedBase.toDouble() / purchase.subtotalXaf.toDouble()).toLong()
        val newNonRecoverable = allocate(purchase.nonRecoverableTaxXaf + purchase.shippingXaf + purchase.otherFeesXaf, nextReceivedBase)
        val nonRecoverableDelta = (newNonRecoverable - purchase.recognizedNonRecoverableXaf).coerceAtLeast(0L)
        val newRecoverable = allocate(purchase.recoverableTaxXaf, nextReceivedBase)
        val recoverableDelta = (newRecoverable - purchase.recognizedRecoverableTaxXaf).coerceAtLeast(0L)
        val now = System.currentTimeMillis()
        val receiptId = UUID.randomUUID().toString()
        val receipt = LocalPurchaseReceipt(
            receiptId, orgId, siteId, purchaseId, line.id, quantityToReceive, base,
            nonRecoverableDelta, recoverableDelta, actorMemberId, now, idempotencyKey
        )
        dao.insertPurchaseReceipt(receipt)
        val expenseBase = base + nonRecoverableDelta
        when (line.itemType) {
            "stock" -> {
                val itemId = line.inventoryItemId ?: throw IllegalStateException("Article de stock manquant.")
                val item = dao.findInventoryItem(itemId, orgId, siteId) ?: throw IllegalStateException("Article de stock introuvable.")
                val currentValuation = dao.findInventoryValuation(orgId, siteId, itemId)
                val oldCost = currentValuation?.unitCostXaf ?: 0L
                val newQuantity = item.quantity + quantityToReceive
                val newAverageCost = if (newQuantity <= 0.0) oldCost else
                    kotlin.math.round((item.quantity * oldCost.toDouble() + expenseBase.toDouble()) / newQuantity).toLong()
                dao.updateInventoryItem(item.copy(quantity = newQuantity))
                val movement = LocalInventoryMovement(
                    id = receiptId, orgId = orgId, siteId = siteId, itemId = itemId, movementType = "in",
                    quantityDelta = quantityToReceive, reason = "Réception fournisseur " + purchase.reference,
                    actorMemberId = actorMemberId, createdAtMillis = now
                )
                dao.insertInventoryMovement(movement)
                dao.upsertInventoryValuation(
                    LocalInventoryValuation(
                        currentValuation?.id ?: UUID.randomUUID().toString(), orgId, siteId, itemId,
                        newAverageCost, currentValuation?.sellingPriceXaf ?: 0L, now
                    )
                )
                postAccountingEntry(orgId, siteId, "purchase_receipt", receiptId, "goods_received",
                    "INVENTORY_ASSET", "SUPPLIER_PAYABLE", expenseBase, "Réception de stock · " + line.description, actorMemberId, now)
            }
            "operating_expense" -> postAccountingEntry(
                orgId, siteId, "purchase_receipt", receiptId, "expense_received",
                "OPERATING_EXPENSE_PURCHASE", "SUPPLIER_PAYABLE", expenseBase,
                "Achat consommable/service · " + line.description, actorMemberId, now
            )
            "fixed_asset" -> postAccountingEntry(
                orgId, siteId, "purchase_receipt", receiptId, "asset_received",
                "FIXED_ASSET", "SUPPLIER_PAYABLE", expenseBase,
                "Immobilisation reçue · " + line.description, actorMemberId, now
            )
            else -> throw IllegalArgumentException("Type de ligne d'achat non reconnu.")
        }
        if (recoverableDelta > 0L) {
            postAccountingEntry(orgId, siteId, "purchase_receipt", receiptId, "recoverable_tax",
                "INPUT_TAX_RECEIVABLE", "SUPPLIER_PAYABLE", recoverableDelta,
                "Taxe récupérable estimée · " + purchase.reference, actorMemberId, now)
        }
        val updatedLine = line.copy(quantityReceived = line.quantityReceived + quantityToReceive)
        dao.updatePurchaseLine(updatedLine)
        val allLines = dao.getPurchaseLines(orgId, siteId, purchaseId)
        val receivedComplete = allLines.all { it.quantityReceived + 0.000001 >= it.quantityOrdered } &&
            nextReceivedBase >= purchase.subtotalXaf - 1L
        val nextReceivedTotal = purchase.receivedTotalXaf + expenseBase + recoverableDelta
        val nextStatus = when {
            receivedComplete && purchase.paidTotalXaf >= nextReceivedTotal -> "closed"
            receivedComplete -> "received"
            else -> "partially_received"
        }
        val updatedPurchase = purchase.copy(
            status = nextStatus,
            receivedBaseXaf = nextReceivedBase,
            recognizedNonRecoverableXaf = newNonRecoverable,
            recognizedRecoverableTaxXaf = newRecoverable,
            receivedTotalXaf = nextReceivedTotal,
            updatedAtMillis = now
        )
        dao.updatePurchaseDocument(updatedPurchase)
        dao.insertWorkflowEvent(
            LocalWorkflowEvent(UUID.randomUUID().toString(), orgId, siteId, "purchase", purchaseId,
                purchase.status, updatedPurchase.status, "Réception de " + quantityToReceive + " " + line.unit,
                actorMemberId, now)
        )
        enqueue(orgId, "purchase_receipt", receiptId, "purchase.receipt.confirmed", siteId)
        receipt
    }

    suspend fun recordSupplierPayment(
        orgId: String, siteId: String, purchaseId: String, amountXaf: Long, paymentMethod: String,
        cashSessionId: String?, paymentReference: String, idempotencyKey: String, actorMemberId: String
    ): LocalSupplierPayment = database.withTransaction {
        require(amountXaf > 0L && actorMemberId.isNotBlank() && idempotencyKey.isNotBlank())
        require(paymentMethod in setOf("cash", "bank", "mobile_money", "other"))
        dao.findSupplierPaymentByKey(orgId, idempotencyKey)?.let { existing ->
            require(existing.siteId == siteId && existing.purchaseId == purchaseId && existing.amountXaf == amountXaf &&
                existing.paymentMethod == paymentMethod && existing.paymentReference == paymentReference.trim() &&
                existing.cashSessionId == cashSessionId) {
                "Clé d'idempotence déjà utilisée pour un paiement différent."
            }
            return@withTransaction existing
        }
        val purchase = dao.findPurchaseDocument(purchaseId, orgId, siteId) ?: throw IllegalArgumentException("Achat introuvable.")
        require(purchase.status !in setOf("draft", "ordered", "cancelled")) { "Une facture ne peut être réglée qu'après réception." }
        val balance = (purchase.receivedTotalXaf - purchase.paidTotalXaf).coerceAtLeast(0L)
        require(amountXaf <= balance) { "Le règlement dépasse la dette fournisseur restante." }
        if (paymentMethod == "cash") {
            require(!cashSessionId.isNullOrBlank()) { "Une caisse ouverte est obligatoire pour un règlement en espèces." }
            val session = dao.findCashSession(cashSessionId, orgId, siteId) ?: throw IllegalArgumentException("Session de caisse introuvable.")
            require(session.status == "open") { "La caisse sélectionnée est fermée." }
        } else require(cashSessionId.isNullOrBlank()) { "Ne lie pas un règlement bancaire à une session de caisse espèces." }
        val now = System.currentTimeMillis()
        val payment = LocalSupplierPayment(
            UUID.randomUUID().toString(), orgId, siteId, purchase.id, purchase.supplierId,
            cashSessionId, amountXaf, paymentMethod, paymentReference.trim(), idempotencyKey,
            actorMemberId, now
        )
        dao.insertSupplierPayment(payment)
        if (paymentMethod == "cash") {
            dao.insertExpense(
                LocalExpense(UUID.randomUUID().toString(), orgId, siteId, cashSessionId!!, "supplier_payment",
                    "Règlement fournisseur " + purchase.reference, amountXaf, actorMemberId, now)
            )
        }
        val creditAccount = when (paymentMethod) {
            "cash" -> "CASH_REGISTER"
            "bank" -> "BANK"
            "mobile_money" -> "MOBILE_MONEY_CLEARING"
            else -> "OTHER_TREASURY"
        }
        postAccountingEntry(orgId, siteId, "supplier_payment", payment.id, "payable_settlement",
            "SUPPLIER_PAYABLE", creditAccount, amountXaf, "Règlement fournisseur " + purchase.reference, actorMemberId, now)
        val newPaid = purchase.paidTotalXaf + amountXaf
        val updated = purchase.copy(
            paidTotalXaf = newPaid,
            status = if (newPaid >= purchase.receivedTotalXaf && purchase.status == "received") "closed" else purchase.status,
            updatedAtMillis = now
        )
        dao.updatePurchaseDocument(updated)
        enqueue(orgId, "supplier_payment", payment.id, "supplier.payment.recorded", siteId)
        payment
    }

    private suspend fun postSaleAccounting(sale: LocalSale) {
        val settlementAccount = when (sale.paymentMethod) {
            "cash" -> "CASH_REGISTER"
            "mobile_money" -> "MOBILE_MONEY_CLEARING"
            else -> "OTHER_TREASURY"
        }
        postAccountingEntry(
            sale.orgId, sale.siteId, "sale", sale.id, "sale_revenue",
            settlementAccount, "SALES_REVENUE", sale.totalXaf,
            "Vente confirmée " + sale.saleNumber, sale.actorMemberId, sale.createdAtMillis
        )
        if (sale.costOfGoodsXaf > 0L) {
            postAccountingEntry(
                sale.orgId, sale.siteId, "sale", sale.id, "sale_cost_of_goods",
                "COST_OF_GOODS_SOLD", "INVENTORY_ASSET", sale.costOfGoodsXaf,
                "Sortie du stock vendu " + sale.saleNumber, sale.actorMemberId, sale.createdAtMillis
            )
        }
    }

    private suspend fun postAccountingEntry(
        orgId: String, siteId: String, sourceType: String, sourceId: String, eventCode: String,
        debitAccount: String, creditAccount: String, amountXaf: Long, description: String,
        actorMemberId: String, occurredAtMillis: Long
    ) {
        require(amountXaf > 0L && debitAccount.isNotBlank() && creditAccount.isNotBlank() && debitAccount != creditAccount)
        if (dao.hasAccountingEntry(orgId, sourceType, sourceId, eventCode) > 0) return
        val batchId = sourceType + ":" + sourceId
        dao.insertAccountingEntry(
            LocalAccountingEntry(
                UUID.randomUUID().toString(), orgId, siteId, batchId, sourceType, sourceId, eventCode,
                debitAccount, creditAccount, amountXaf, description, actorMemberId, occurredAtMillis
            )
        )
        enqueue(orgId, "accounting_entry", batchId, "accounting.entry.posted", siteId)
    }

    suspend fun saveSupplierWhatsApp(orgId: String, siteId: String, itemId: String, value: String): LocalInventoryItem = database.withTransaction {
        val phone = value.filter(Char::isDigit)
        require(phone.isBlank() || phone.length in 9..15) { "Saisis le numéro avec son indicatif pays." }
        val current = dao.findInventoryItem(itemId, orgId, siteId) ?: throw IllegalArgumentException("Article introuvable sur ce site.")
        current.copy(supplierWhatsApp = phone).also {
            dao.updateInventoryItem(it)
            enqueue(orgId, "inventory_item", itemId, "inventory_item.supplier_whatsapp_updated", siteId)
        }
    }

    suspend fun saveRecurringCharge(orgId: String, siteId: String, id: String?, name: String, category: String, amountXaf: Long, recurrence: String, nextDueAtMillis: Long, reminderDays: Int, actorMemberId: String): LocalRecurringCharge = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && actorMemberId.isNotBlank())
        require(name.isNotBlank() && name.length <= 120 && category.isNotBlank())
        require(amountXaf > 0L && recurrence in setOf("monthly", "quarterly", "annual", "one_time"))
        require(reminderDays in 0..30 && nextDueAtMillis > 0L)
        val now = System.currentTimeMillis()
        val old = id?.let { dao.findRecurringCharge(it, orgId, siteId) }
        val charge = if (old == null) {
            LocalRecurringCharge(UUID.randomUUID().toString(), orgId, siteId, name.trim(), category.trim(), amountXaf,
                recurrence, nextDueAtMillis, reminderDays, true, actorMemberId, now, now)
                .also { dao.insertRecurringCharge(it) }
        } else {
            old.copy(name = name.trim(), category = category.trim(), amountXaf = amountXaf, recurrence = recurrence,
                nextDueAtMillis = nextDueAtMillis, reminderDays = reminderDays, active = true,
                updatedAtMillis = now, lastReminderAtMillis = null).also { dao.updateRecurringCharge(it) }
        }
        enqueue(orgId, "recurring_charge", charge.id, "recurring_charge.saved", siteId)
        charge
    }

    suspend fun recordRecurringChargePayment(orgId: String, siteId: String, chargeId: String, amountXaf: Long, actorMemberId: String): LocalChargePayment = database.withTransaction {
        require(amountXaf > 0L && actorMemberId.isNotBlank())
        val charge = dao.findRecurringCharge(chargeId, orgId, siteId) ?: throw IllegalArgumentException("Charge introuvable.")
        require(charge.active) { "Cette charge est désactivée." }
        val cycleDue = charge.nextDueAtMillis
        val alreadyPaid = dao.sumChargePaymentsForCycle(charge.id, cycleDue)
        require(amountXaf <= charge.amountXaf - alreadyPaid) { "Le règlement dépasse le solde de cette échéance." }
        val now = System.currentTimeMillis()
        val payment = LocalChargePayment(UUID.randomUUID().toString(), orgId, siteId, charge.id, cycleDue, now, amountXaf, actorMemberId)
        dao.insertChargePayment(payment)
        postAccountingEntry(
            orgId, siteId, "recurring_charge_payment", payment.id, "recurring_charge_paid",
            "OPERATING_EXPENSE_RECURRING:" + charge.category.trim().uppercase(java.util.Locale.ROOT),
            "TREASURY_UNSPECIFIED", amountXaf,
            "Règlement de charge récurrente · " + charge.name, actorMemberId, now
        )
        if (alreadyPaid + amountXaf >= charge.amountXaf) {
            if (charge.recurrence == "one_time") {
                dao.updateRecurringCharge(charge.copy(active = false, updatedAtMillis = now, lastReminderAtMillis = null))
            } else {
                val calendar = Calendar.getInstance().apply { timeInMillis = cycleDue }
                when (charge.recurrence) {
                    "monthly" -> calendar.add(Calendar.MONTH, 1)
                    "quarterly" -> calendar.add(Calendar.MONTH, 3)
                    "annual" -> calendar.add(Calendar.YEAR, 1)
                }
                dao.updateRecurringCharge(charge.copy(nextDueAtMillis = calendar.timeInMillis, updatedAtMillis = now, lastReminderAtMillis = null))
            }
        }
        enqueue(orgId, "recurring_charge", charge.id, "recurring_charge.payment_recorded", siteId)
        payment
    }

    suspend fun markChargeReminderSent(charge: LocalRecurringCharge, atMillis: Long) {
        dao.updateRecurringCharge(charge.copy(lastReminderAtMillis = atMillis, updatedAtMillis = atMillis))
    }

    suspend fun deactivateRecurringCharge(orgId: String, siteId: String, chargeId: String, actorMemberId: String): Boolean = database.withTransaction {
        require(actorMemberId.isNotBlank())
        val charge = dao.findRecurringCharge(chargeId, orgId, siteId) ?: return@withTransaction false
        if (!charge.active) return@withTransaction false
        val now = System.currentTimeMillis()
        dao.updateRecurringCharge(charge.copy(active = false, updatedAtMillis = now, lastReminderAtMillis = null))
        enqueue(orgId, "recurring_charge", charge.id, "recurring_charge.deactivated", siteId)
        true
    }

    suspend fun ensureDefaultLoyaltyPrograms(orgId: String, activityProfile: String) = database.withTransaction {
        require(orgId.isNotBlank() && activityProfile.isNotBlank())
        val activity = activityProfile.replace('_', ' ').replaceFirstChar { it.uppercase() }
        val noun = when (activityProfile) {
            "pressing" -> "ticket"
            "coiffure", "beaute" -> "prestation"
            "couture", "menuiserie" -> "commande"
            "garage", "reparation" -> "intervention"
            "parfumerie" -> "achat"
            "nettoyage", "domicile" -> "mission"
            "impression" -> "commande imprimée"
            "photo_evenementiel" -> "événement"
            else -> "achat"
        }
        val now = System.currentTimeMillis()
        val defaults = listOf(
            Triple("points", "Club " + activity, "1 point par tranche de 1 000 FCFA ; récompense par cycle de 100 points."),
            Triple("visits", "Carte " + noun, "Un tampon par " + noun + " payé ; récompense après 6 passages."),
            Triple("spend", "Cercle privilège", "Une récompense par tranche cumulée de 100 000 FCFA."),
            Triple("frequency", "Rendez-vous fidèle", "Récompense après 4 visites sur 45 jours glissants.")
        )
        defaults.forEach { entry ->
            val code = entry.first
            if (dao.findLoyaltyProgram(orgId, activityProfile, code) == null) {
                val metric = when (code) { "points" -> "points"; "visits", "frequency" -> "visits"; else -> "spend" }
                val target = when (code) { "points" -> 100L; "visits" -> 6L; "spend" -> 100_000L; else -> 4L }
                val reward = when (code) {
                    "points" -> "Bon d'achat ou remise de 5 000 FCFA"
                    "visits" -> "Une remise ou " + noun + " offert, défini par le Promoteur"
                    "spend" -> "Remise de 5 000 FCFA ou avantage équivalent"
                    else -> "Remise de 10 % sur le prochain " + noun
                }
                dao.upsertLoyaltyProgram(LocalLoyaltyProgram(
                    UUID.randomUUID().toString(), orgId, activityProfile, code, entry.second, entry.third, metric,
                    if (code == "points") 1_000L else 1L, target, reward, if (code == "frequency") 45 else 0,
                    true, now, now
                ))
            }
        }
    }

    suspend fun saveLoyaltyProgram(program: LocalLoyaltyProgram, actorMemberId: String): LocalLoyaltyProgram = database.withTransaction {
        require(actorMemberId.isNotBlank() && program.name.isNotBlank() && program.name.length <= 80)
        require(program.metricCode in setOf("points", "visits", "spend"))
        require(program.unitAmountXaf > 0L && program.targetValue > 0L && program.windowDays in 0..365)
        require(program.rewardDescription.isNotBlank() && program.rewardDescription.length <= 240)
        program.copy(updatedAtMillis = System.currentTimeMillis()).also {
            dao.upsertLoyaltyProgram(it)
            enqueue(program.orgId, "loyalty_program", program.id, "loyalty_program.updated", null)
        }
    }

    suspend fun recordLoyaltyActivity(program: LocalLoyaltyProgram, siteId: String, customerId: String, amountXaf: Long, actorMemberId: String): List<LocalLoyaltyEvent> = database.withTransaction {
        require(program.active && amountXaf >= 0L && actorMemberId.isNotBlank())
        val customer = dao.findCustomer(customerId, program.orgId, siteId) ?: throw IllegalArgumentException("Client introuvable sur ce point de vente.")
        val now = System.currentTimeMillis()
        val since = if (program.windowDays > 0) now - program.windowDays * 86_400_000L else 0L
        val previous = dao.sumLoyaltyMetric(program.orgId, program.id, customer.id, since)
        val previousAmount = dao.sumLoyaltyAmount(program.orgId, program.id, customer.id, since)
        val delta = when (program.metricCode) {
            "points" -> (previousAmount + amountXaf) / program.unitAmountXaf - previousAmount / program.unitAmountXaf
            "visits" -> 1L
            "spend" -> amountXaf
            else -> throw IllegalArgumentException("Indicateur de fidélité non pris en charge.")
        }
        require(
            when (program.metricCode) {
                "visits" -> delta > 0L
                "points", "spend" -> amountXaf > 0L
                else -> false
            }
        ) { "Le montant doit être positif ; les visites comptent un passage." }
        val activityEvent = LocalLoyaltyEvent(
            UUID.randomUUID().toString(), program.orgId, siteId, program.id, customer.id,
            "activity", amountXaf, delta, null, null, null,
            if (program.metricCode == "visits") "Visite validée" else "Achat validé", actorMemberId, now
        )
        dao.insertLoyaltyEvent(activityEvent)
        val oldWaves = previous / program.targetValue
        val newWaves = (previous + delta) / program.targetValue
        val result = mutableListOf(activityEvent)
        if (newWaves > oldWaves) {
            for (wave in (oldWaves + 1)..newWaves) {
                val reward = LocalLoyaltyEvent(
                    UUID.randomUUID().toString(), program.orgId, siteId, program.id, customer.id,
                    "reward_earned", 0L, 0L, wave.toInt(), activityEvent.id, "available",
                    program.rewardDescription, actorMemberId, now
                )
                dao.insertLoyaltyEvent(reward)
                result.add(reward)
            }
        }
        enqueue(program.orgId, "loyalty_activity", activityEvent.id, "loyalty_activity.recorded", siteId)
        result
    }

    suspend fun redeemLoyaltyReward(event: LocalLoyaltyEvent, actorMemberId: String): Boolean = database.withTransaction {
        require(actorMemberId.isNotBlank())
        val changed = dao.redeemLoyaltyReward(event.id, event.orgId, event.siteId)
        if (changed > 0) enqueue(event.orgId, "loyalty_reward", event.id, "loyalty_reward.redeemed", event.siteId)
        changed > 0
    }

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

    suspend fun advancePressingOrder(order: LocalPressingOrder, actorMemberId: String, reason: String) = database.withTransaction {
        val current = dao.findPressingOrder(order.id, order.orgId, order.siteId) ?: throw IllegalStateException("Ticket introuvable.")
        require(current.orgId == order.orgId && current.siteId == order.siteId && actorMemberId.isNotBlank()) { "Périmètre du ticket invalide." }
        require(reason.trim().length >= 3 && reason.length <= 500) { "Un motif de changement de statut est obligatoire." }
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
                createdAtMillis = changedAt,
                reason = reason.trim()
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
        actorMemberId: String,
        inventoryItemId: String? = null,
        stockQuantity: Double? = null
    ): Pair<LocalSale, LocalOutboxEvent> = database.withTransaction {
        val cashSession = dao.findCashSession(cashSessionId, orgId, siteId) ?: throw IllegalStateException("Session de caisse introuvable.")
        require(cashSession.siteId == siteId && cashSession.status == "open") { "La caisse n'est pas ouverte sur ce point de vente." }
        require(description.isNotBlank() && totalXaf > 0 && actorMemberId.isNotBlank()) { "Description, montant et opérateur obligatoires." }
        require(paymentMethod in setOf("cash", "mobile_money")) { "Mode de paiement non pris en charge." }
        require((inventoryItemId == null) == (stockQuantity == null)) { "Article et quantité de stock doivent être fournis ensemble." }
        val linkedStockItem = inventoryItemId?.let {
            dao.findInventoryItem(it, orgId, siteId) ?: throw IllegalArgumentException("Article introuvable sur ce point de vente.")
        }
        val valuationSnapshot = linkedStockItem?.let { dao.findInventoryValuation(orgId, siteId, it.id) }
        val unitCostSnapshot = valuationSnapshot?.unitCostXaf ?: 0L
        val hasReliableCostSnapshot = linkedStockItem != null && valuationSnapshot != null
        val costSnapshot = if (stockQuantity != null && valuationSnapshot != null) {
            (stockQuantity * unitCostSnapshot.toDouble()).takeIf { it.isFinite() && it <= Long.MAX_VALUE.toDouble() }?.let { kotlin.math.round(it).toLong() }
                ?: throw IllegalArgumentException("Coût de revient de la vente invalide.")
        } else 0L
        if (linkedStockItem != null) {
            require(stockQuantity != null && stockQuantity.isFinite() && stockQuantity > 0.0) { "Quantité d'article invalide." }
            val reservations = dao.pendingInventoryReservations(orgId, siteId, linkedStockItem.id)
            require(linkedStockItem.quantity - reservations >= stockQuantity) {
                "Stock insuffisant après prise en compte des ventes Mobile Money en attente."
            }
        }
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
            createdAtMillis = now,
            inventoryItemId = linkedStockItem?.id,
            stockQuantity = stockQuantity,
            unitCostAtSaleXaf = unitCostSnapshot,
            costOfGoodsXaf = costSnapshot,
            costSnapshotComplete = hasReliableCostSnapshot
        )
        dao.insertSale(sale)
        if (linkedStockItem != null && paymentMethod == "cash") {
            val updatedItem = linkedStockItem.copy(quantity = linkedStockItem.quantity - (stockQuantity ?: 0.0))
            dao.updateInventoryItem(updatedItem)
            val movement = LocalInventoryMovement(
                id = UUID.randomUUID().toString(),
                orgId = orgId,
                siteId = siteId,
                itemId = linkedStockItem.id,
                movementType = "out",
                quantityDelta = -(stockQuantity ?: 0.0),
                reason = "Vente espèces " + sale.saleNumber,
                actorMemberId = actorMemberId,
                createdAtMillis = now
            )
            dao.insertInventoryMovement(movement)
            enqueue(orgId, "inventory_movement", movement.id, "inventory_movement.sale_out", siteId)
        }
        if (sale.status == "confirmed") postSaleAccounting(sale)
        val event = enqueue(cashSession.orgId, "sale", sale.id, "sale.created", siteId)
        sale to event
    }

    suspend fun cancelPendingMobileMoneySale(
        orgId: String,
        siteId: String,
        saleId: String,
        reason: String,
        actorMemberId: String
    ): LocalSale = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && actorMemberId.isNotBlank()) {
            "Organisation, point de vente et opérateur obligatoires."
        }
        require(reason.trim().length >= 3 && reason.length <= 500) {
            "Un motif d'annulation de trois caractères minimum est obligatoire."
        }
        val current = dao.findSale(orgId, siteId, saleId)
            ?: throw IllegalArgumentException("Vente introuvable sur ce point de vente.")
        require(current.paymentMethod == "mobile_money" && current.status == "pending") {
            "Seule une vente Mobile Money en attente peut être annulée."
        }
        val now = System.currentTimeMillis()
        val cancelled = current.copy(status = "cancelled")
        dao.updateSale(cancelled)
        dao.insertWorkflowEvent(
            LocalWorkflowEvent(
                id = UUID.randomUUID().toString(),
                orgId = orgId,
                siteId = siteId,
                aggregateType = "sale",
                aggregateId = current.id,
                fromStatus = current.status,
                toStatus = "cancelled",
                reason = reason.trim(),
                actorMemberId = actorMemberId,
                createdAtMillis = now
            )
        )
        // The pendingInventoryReservations query ignores cancelled rows, so
        // this operation releases the local stock reservation atomically.
        enqueue(orgId, "sale", current.id, "sale.mobile_money_cancelled", siteId)
        cancelled
    }

    /**
     * This method must only be invoked by the trusted server-sync adapter after
     * a verified provider webhook confirms payment. A user-entered reference is
     * not sufficient to call it.
     */
    suspend fun applyServerConfirmedMobileMoneySale(
        orgId: String,
        siteId: String,
        saleId: String,
        providerPaymentReference: String
    ): LocalSale = database.withTransaction {
        require(providerPaymentReference.isNotBlank() && providerPaymentReference.length <= 160) {
            "Référence serveur de paiement invalide."
        }
        val sale = dao.findSale(orgId, siteId, saleId) ?: throw IllegalArgumentException("Vente introuvable.")
        require(sale.paymentMethod == "mobile_money" && sale.status == "pending") {
            "Seule une vente Mobile Money en attente peut être confirmée par le serveur."
        }
        val now = System.currentTimeMillis()
        val itemId = sale.inventoryItemId
        val quantity = sale.stockQuantity
        if (itemId != null && quantity != null) {
            val item = dao.findInventoryItem(itemId, orgId, siteId)
                ?: throw IllegalStateException("L'article lié à cette vente n'existe plus.")
            require(item.quantity >= quantity) {
                "Stock réel insuffisant au moment de la confirmation Mobile Money."
            }
            dao.updateInventoryItem(item.copy(quantity = item.quantity - quantity))
            val movement = LocalInventoryMovement(
                id = UUID.randomUUID().toString(),
                orgId = orgId,
                siteId = siteId,
                itemId = itemId,
                movementType = "out",
                quantityDelta = -quantity,
                reason = "Vente Mobile Money confirmée par le serveur " + sale.saleNumber,
                actorMemberId = sale.actorMemberId,
                createdAtMillis = now
            )
            dao.insertInventoryMovement(movement)
            enqueue(orgId, "inventory_movement", movement.id, "inventory_movement.mobile_money_sale_out", siteId)
        }
        val confirmed = sale.copy(status = "confirmed")
        dao.updateSale(confirmed)
        postSaleAccounting(confirmed)
        dao.insertWorkflowEvent(
            LocalWorkflowEvent(
                id = UUID.randomUUID().toString(),
                orgId = orgId,
                siteId = siteId,
                aggregateType = "sale",
                aggregateId = sale.id,
                fromStatus = "pending",
                toStatus = "confirmed",
                reason = "Confirmation serveur du prestataire : " + providerPaymentReference,
                actorMemberId = sale.actorMemberId,
                createdAtMillis = now
            )
        )
        enqueue(orgId, "sale", sale.id, "sale.payment_confirmed_server", siteId)
        confirmed
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
        postAccountingEntry(
            orgId, siteId, "expense", expense.id, "expense.recorded",
            "OPERATING_EXPENSE:" + category.trim().uppercase(java.util.Locale.ROOT),
            "CASH_REGISTER", amountXaf, description.trim(), actorMemberId, expense.createdAtMillis
        )
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

    suspend fun createLocalService(
        orgId: String,
        siteId: String,
        activity: String,
        name: String,
        durationMinutes: Int?,
        priceXaf: Long,
        category: String = "general",
        description: String = "",
        providerMemberIdsJson: String = "[]",
        requiredWorkstationKindsJson: String = "[]",
        packageSessions: Int? = null
    ): LocalService = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && name.isNotBlank()) { "Point de vente et prestation obligatoires." }
        require(activity in setOf("pressing", "hair", "beauty", "treatment", "tailoring", "perfume", "repair", "part", "manufacturing", "vehicle", "cleaning", "contract", "home", "printing", "event", "package", "material", "service", "retail", "general")) { "Activité de prestation invalide." }
        require(category in setOf("pressing", "hair", "beauty", "tailoring", "repair", "manufacturing", "vehicle", "cleaning", "home", "printing", "event", "retail", "general")) { "Catégorie de prestation invalide." }
        require(durationMinutes == null || durationMinutes in 1..1440) { "Durée invalide." }
        require(priceXaf >= 0L && description.length <= 1000) { "Tarif ou description invalide." }
        require(providerMemberIdsJson.length <= 2000 && requiredWorkstationKindsJson.length <= 1000) { "Configuration de prestataires ou d'emplacements trop longue." }
        require(packageSessions == null || packageSessions in 1..100) { "Nombre de séances du forfait invalide." }
        val now = System.currentTimeMillis()
        val service = LocalService(
            id = UUID.randomUUID().toString(),
            orgId = orgId,
            siteId = siteId,
            code = "SRV-" + now.toString() + "-" + UUID.randomUUID().toString().take(6).uppercase(),
            activity = activity,
            name = name.trim(),
            durationMinutes = durationMinutes,
            priceXaf = priceXaf,
            createdAtMillis = now,
            category = category,
            description = description.trim(),
            providerMemberIdsJson = providerMemberIdsJson,
            requiredWorkstationKindsJson = requiredWorkstationKindsJson,
            packageSessions = packageSessions
        )
        dao.insertService(service)
        enqueue(orgId, "service", service.id, "service.created", siteId)
        service
    }

    suspend fun createLocalCustomer(
        orgId: String,
        siteId: String,
        name: String,
        phone: String,
        privateNotes: String,
        contactConsent: Boolean,
        addressLine: String = "",
        neighborhood: String = "",
        landmark: String = "",
        latitude: Double? = null,
        longitude: Double? = null,
        locationAccuracyMeters: Float? = null,
        locationConsent: Boolean = false
    ): LocalCustomer = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && name.isNotBlank()) { "Nom du client et point de vente obligatoires." }
        require(phone.length <= 32 && privateNotes.length <= 1000) { "Coordonnées ou note trop longues." }
        require(addressLine.length <= 240 && neighborhood.length <= 100 && landmark.length <= 160) { "Adresse ou repère trop long." }
        require((latitude == null) == (longitude == null)) { "Les coordonnées GPS doivent être renseignées ensemble." }
        require(latitude == null || latitude in -90.0..90.0) { "Latitude invalide." }
        require(longitude == null || longitude in -180.0..180.0) { "Longitude invalide." }
        require(locationAccuracyMeters == null || locationAccuracyMeters >= 0f) { "Précision GPS invalide." }
        require(locationConsent || (latitude == null && longitude == null && locationAccuracyMeters == null)) {
            "Le consentement du client est nécessaire avant d'enregistrer sa géolocalisation."
        }
        val now = System.currentTimeMillis()
        val customer = LocalCustomer(
            id = UUID.randomUUID().toString(),
            orgId = orgId,
            siteId = siteId,
            displayName = name.trim(),
            phoneContact = phone.trim(),
            notesPrivate = privateNotes.trim(),
            contactConsent = contactConsent,
            createdAtMillis = now,
            addressLine = addressLine.trim(),
            neighborhood = neighborhood.trim(),
            landmark = landmark.trim(),
            latitude = latitude,
            longitude = longitude,
            locationAccuracyMeters = locationAccuracyMeters,
            locationCapturedAtMillis = if (latitude != null) now else null,
            locationConsentAtMillis = if (locationConsent) now else null
        )
        dao.insertCustomer(customer)
        enqueue(orgId, "customer", customer.id, "customer.created", siteId)
        customer
    }

    suspend fun updateLocalCustomer(
        orgId: String,
        siteId: String,
        customerId: String,
        name: String,
        phone: String,
        privateNotes: String,
        contactConsent: Boolean,
        addressLine: String,
        neighborhood: String,
        landmark: String,
        latitude: Double?,
        longitude: Double?,
        locationAccuracyMeters: Float?,
        locationConsent: Boolean
    ): LocalCustomer = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && customerId.isNotBlank() && name.isNotBlank()) {
            "Organisation, point de vente et nom du client obligatoires."
        }
        require(phone.length <= 32 && privateNotes.length <= 1000) { "Coordonnées ou note trop longues." }
        require(addressLine.length <= 240 && neighborhood.length <= 100 && landmark.length <= 160) { "Adresse ou repère trop long." }
        require((latitude == null) == (longitude == null)) { "Les coordonnées GPS doivent être renseignées ensemble." }
        require(latitude == null || latitude in -90.0..90.0) { "Latitude invalide." }
        require(longitude == null || longitude in -180.0..180.0) { "Longitude invalide." }
        require(locationAccuracyMeters == null || locationAccuracyMeters >= 0f) { "Précision GPS invalide." }
        require(locationConsent || (latitude == null && longitude == null && locationAccuracyMeters == null)) {
            "Le consentement du client est nécessaire pour conserver ses coordonnées GPS."
        }
        val current = dao.findCustomer(customerId, orgId, siteId)
            ?: throw IllegalArgumentException("Fiche client introuvable sur ce point de vente.")
        val sameCoordinates = current.latitude == latitude && current.longitude == longitude
        val now = System.currentTimeMillis()
        val updated = current.copy(
            displayName = name.trim(),
            phoneContact = phone.trim(),
            notesPrivate = privateNotes.trim(),
            contactConsent = contactConsent,
            addressLine = addressLine.trim(),
            neighborhood = neighborhood.trim(),
            landmark = landmark.trim(),
            latitude = if (locationConsent) latitude else null,
            longitude = if (locationConsent) longitude else null,
            locationAccuracyMeters = if (locationConsent) locationAccuracyMeters else null,
            locationCapturedAtMillis = if (!locationConsent || latitude == null) null else if (sameCoordinates) current.locationCapturedAtMillis else now,
            locationConsentAtMillis = if (locationConsent) current.locationConsentAtMillis ?: now else null
        )
        dao.updateCustomer(updated)
        enqueue(orgId, "customer", customerId, "customer.updated", siteId)
        updated
    }

    suspend fun createCustomerFollowUp(
        orgId: String,
        siteId: String,
        customerId: String,
        title: String,
        frequency: String,
        channel: String,
        notes: String,
        actorMemberId: String
    ): LocalCustomerFollowUp = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && actorMemberId.isNotBlank()) { "Organisation, site et opérateur obligatoires." }
        require(title.isNotBlank() && title.length <= 120 && notes.length <= 1000) { "Titre ou note de relance invalide." }
        require(frequency in setOf("weekly", "monthly")) { "Fréquence de relance non prise en charge." }
        require(channel in setOf("in_person", "phone", "whatsapp")) { "Canal de suivi non pris en charge." }
        val customer = dao.findCustomer(customerId, orgId, siteId) ?: throw IllegalArgumentException("Client introuvable sur ce point de vente.")
        if (channel != "in_person") {
            require(customer.contactConsent && customer.phoneContact.isNotBlank()) {
                "Le consentement de contact et un numéro de téléphone sont nécessaires pour une relance à distance."
            }
        }
        val now = System.currentTimeMillis()
        val calendar = Calendar.getInstance().apply { timeInMillis = now }
        if (frequency == "weekly") calendar.add(Calendar.DAY_OF_MONTH, 7) else calendar.add(Calendar.MONTH, 1)
        val followUp = LocalCustomerFollowUp(
            id = UUID.randomUUID().toString(),
            orgId = orgId,
            siteId = siteId,
            customerId = customerId,
            title = title.trim(),
            frequency = frequency,
            channel = channel,
            notes = notes.trim(),
            nextDueAtMillis = calendar.timeInMillis,
            createdByMemberId = actorMemberId,
            createdAtMillis = now,
            updatedAtMillis = now
        )
        dao.insertCustomerFollowUp(followUp)
        dao.insertCustomerContactEvent(
            LocalCustomerContactEvent(
                id = UUID.randomUUID().toString(), orgId = orgId, siteId = siteId,
                customerId = customerId, followUpId = followUp.id, eventType = "scheduled",
                outcome = "pending", notes = notes.trim(), actorMemberId = actorMemberId, happenedAtMillis = now
            )
        )
        enqueue(orgId, "customer_followup", followUp.id, "customer_followup.created", siteId)
        followUp
    }

    suspend fun completeCustomerFollowUp(
        orgId: String,
        siteId: String,
        followUpId: String,
        outcome: String,
        notes: String,
        actorMemberId: String
    ): LocalCustomerFollowUp = database.withTransaction {
        require(outcome in setOf("completed", "no_answer", "rescheduled", "not_required")) { "Résultat de relance invalide." }
        require(notes.length <= 1000 && actorMemberId.isNotBlank()) { "Opérateur ou note invalide." }
        val current = dao.findCustomerFollowUp(followUpId, orgId, siteId)
            ?: throw IllegalArgumentException("Relance introuvable sur ce point de vente.")
        require(current.status == "active") { "Cette relance est déjà suspendue." }
        val now = System.currentTimeMillis()
        val calendar = Calendar.getInstance().apply { timeInMillis = maxOf(current.nextDueAtMillis, now) }
        if (current.frequency == "weekly") calendar.add(Calendar.DAY_OF_MONTH, 7) else calendar.add(Calendar.MONTH, 1)
        val updated = current.copy(nextDueAtMillis = calendar.timeInMillis, updatedAtMillis = now, lastCompletedAtMillis = now)
        dao.updateCustomerFollowUp(updated)
        dao.insertCustomerContactEvent(
            LocalCustomerContactEvent(
                id = UUID.randomUUID().toString(), orgId = orgId, siteId = siteId,
                customerId = current.customerId, followUpId = current.id, eventType = "completed",
                outcome = outcome, notes = notes.trim(), actorMemberId = actorMemberId, happenedAtMillis = now
            )
        )
        enqueue(orgId, "customer_followup", current.id, "customer_followup.completed", siteId)
        updated
    }

    suspend fun createInventoryItem(orgId: String, siteId: String, sku: String, name: String, unit: String, reorderLevel: Double, supplierWhatsApp: String = ""): LocalInventoryItem = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && name.isNotBlank() && unit.isNotBlank()) { "Article, unité et point de vente obligatoires." }
        require(reorderLevel >= 0.0) { "Seuil d'alerte invalide." }
        val phone = supplierWhatsApp.filter(Char::isDigit)
        require(phone.isBlank() || phone.length in 9..15) { "Le contact WhatsApp doit comporter l'indicatif pays." }
        val item = LocalInventoryItem(UUID.randomUUID().toString(), orgId, siteId, sku.trim(), name.trim(), unit.trim(), 0.0, reorderLevel, createdAtMillis = System.currentTimeMillis(), supplierWhatsApp = phone)
        dao.insertInventoryItem(item)
        enqueue(orgId, "inventory_item", item.id, "inventory_item.created", siteId)
        item
    }

    suspend fun importInventoryBatch(
        orgId: String,
        siteId: String,
        rows: List<LocalInventoryImportRow>,
        updateExisting: Boolean,
        actorMemberId: String
    ): Pair<Int, Int> = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && actorMemberId.isNotBlank()) {
            "Organisation, point de vente et opérateur obligatoires."
        }
        require(rows.isNotEmpty() && rows.size <= 5000) { "Le fichier doit contenir entre 1 et 5 000 lignes d'articles." }
        val normalizedSkus = rows.map { it.sku.trim().uppercase() }
        require(normalizedSkus.all { it.isNotBlank() }) { "Chaque article doit avoir une référence/SKU." }
        require(normalizedSkus.distinct().size == normalizedSkus.size) { "Le fichier contient des SKU en double." }
        rows.forEach {
            require(it.name.isNotBlank() && it.unit.isNotBlank()) { "Nom et unité obligatoires pour chaque article." }
            require(it.quantity.isFinite() && it.quantity >= 0.0 && it.reorderLevel.isFinite() && it.reorderLevel >= 0.0) {
                "Quantité ou seuil invalide dans le fichier."
            }
            require((it.unitCostXaf == null || it.unitCostXaf >= 0L) && (it.sellingPriceXaf == null || it.sellingPriceXaf >= 0L)) {
                "Coût d'achat ou prix de vente invalide dans le fichier."
            }
        }

        var created = 0
        var updated = 0
        val now = System.currentTimeMillis()
        rows.forEach { row ->
            val sku = row.sku.trim().uppercase()
            val matches = dao.findInventoryItemsBySku(orgId, siteId, sku)
            require(matches.size <= 1) { "Le stock contient déjà plusieurs articles avec le SKU $sku. Corrige les doublons avant l'import." }
            val existing = matches.firstOrNull()
            if (existing != null) {
                require(updateExisting) {
                    "Le SKU $sku existe déjà. Active explicitement « Mettre à jour les articles existants » après vérification de l'aperçu."
                }
                val changed = existing.copy(
                    name = row.name.trim(),
                    unit = row.unit.trim(),
                    reorderLevel = row.reorderLevel
                )
                if (row.quantity != existing.quantity) {
                    val delta = row.quantity - existing.quantity
                    val movement = LocalInventoryMovement(
                        id = UUID.randomUUID().toString(),
                        orgId = orgId,
                        siteId = siteId,
                        itemId = existing.id,
                        movementType = "adjustment",
                        quantityDelta = delta,
                        reason = "Import CSV contrôlé — ajustement de quantité",
                        actorMemberId = actorMemberId,
                        createdAtMillis = now
                    )
                    dao.insertInventoryMovement(movement)
                    enqueue(orgId, "inventory_movement", movement.id, "inventory_movement.import_adjustment", siteId)
                }
                dao.updateInventoryItem(changed.copy(quantity = row.quantity, supplierWhatsApp = row.supplierWhatsApp.filter(Char::isDigit)))
                if (row.unitCostXaf != null || row.sellingPriceXaf != null) {
                    val oldValue = dao.findInventoryValuation(orgId, siteId, existing.id)
                    dao.upsertInventoryValuation(
                        LocalInventoryValuation(
                            id = oldValue?.id ?: UUID.randomUUID().toString(),
                            orgId = orgId,
                            siteId = siteId,
                            inventoryItemId = existing.id,
                            unitCostXaf = row.unitCostXaf ?: oldValue?.unitCostXaf ?: 0L,
                            sellingPriceXaf = row.sellingPriceXaf ?: oldValue?.sellingPriceXaf ?: 0L,
                            updatedAtMillis = now
                        )
                    )
                    enqueue(orgId, "inventory_valuation", existing.id, "inventory_valuation.import_updated", siteId)
                }
                enqueue(orgId, "inventory_item", existing.id, "inventory_item.import_updated", siteId)
                updated += 1
            } else {
                val item = LocalInventoryItem(
                    id = UUID.randomUUID().toString(),
                    orgId = orgId,
                    siteId = siteId,
                    sku = sku,
                    name = row.name.trim(),
                    unit = row.unit.trim(),
                    quantity = 0.0,
                    reorderLevel = row.reorderLevel,
                    createdAtMillis = now,
                    supplierWhatsApp = row.supplierWhatsApp.filter(Char::isDigit)
                )
                dao.insertInventoryItem(item)
                enqueue(orgId, "inventory_item", item.id, "inventory_item.imported", siteId)
                if (row.quantity > 0.0) {
                    val movement = LocalInventoryMovement(
                        id = UUID.randomUUID().toString(),
                        orgId = orgId,
                        siteId = siteId,
                        itemId = item.id,
                        movementType = "in",
                        quantityDelta = row.quantity,
                        reason = "Stock initial issu de l'import CSV",
                        actorMemberId = actorMemberId,
                        createdAtMillis = now
                    )
                    dao.insertInventoryMovement(movement)
                    dao.updateInventoryItem(item.copy(quantity = row.quantity))
                    enqueue(orgId, "inventory_movement", movement.id, "inventory_movement.import_initial", siteId)
                }
                if (row.unitCostXaf != null || row.sellingPriceXaf != null) {
                    dao.upsertInventoryValuation(
                        LocalInventoryValuation(
                            id = UUID.randomUUID().toString(),
                            orgId = orgId,
                            siteId = siteId,
                            inventoryItemId = item.id,
                            unitCostXaf = row.unitCostXaf ?: 0L,
                            sellingPriceXaf = row.sellingPriceXaf ?: 0L,
                            updatedAtMillis = now
                        )
                    )
                    enqueue(orgId, "inventory_valuation", item.id, "inventory_valuation.imported", siteId)
                }
                created += 1
            }
        }
        created to updated
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

    suspend fun transitionAppointmentStatus(
        orgId: String,
        siteId: String,
        appointmentId: String,
        nextStatus: String,
        reason: String,
        actorMemberId: String
    ): LocalAppointment = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && actorMemberId.isNotBlank()) {
            "Organisation, site et opérateur obligatoires."
        }
        require(reason.trim().length >= 3 && reason.length <= 500) { "Un motif de trois caractères minimum est obligatoire." }
        val current = dao.findAppointment(orgId, siteId, appointmentId)
            ?: throw IllegalArgumentException("Rendez-vous introuvable sur ce point de vente.")
        val allowed = when (current.status) {
            "booked" -> setOf("confirmed", "cancelled", "no_show")
            "confirmed" -> setOf("cancelled", "no_show", "completed")
            else -> emptySet()
        }
        require(nextStatus in allowed) { "Transition rendez-vous interdite : ${current.status} → $nextStatus." }
        val updated = current.copy(status = nextStatus)
        dao.updateAppointment(updated)
        dao.insertWorkflowEvent(
            LocalWorkflowEvent(
                id = UUID.randomUUID().toString(), orgId = orgId, siteId = siteId,
                aggregateType = "appointment", aggregateId = current.id,
                fromStatus = current.status, toStatus = nextStatus, reason = reason.trim(),
                actorMemberId = actorMemberId, createdAtMillis = System.currentTimeMillis()
            )
        )
        enqueue(orgId, "appointment", current.id, "appointment.status_changed", siteId)
        updated
    }

    suspend fun rescheduleAppointment(
        orgId: String,
        siteId: String,
        appointmentId: String,
        newStartAtMillis: Long,
        newEndAtMillis: Long,
        reason: String,
        actorMemberId: String
    ): LocalAppointment = database.withTransaction {
        require(newStartAtMillis > 0L && newEndAtMillis > newStartAtMillis) { "Nouveau créneau invalide." }
        require(reason.trim().length >= 3 && actorMemberId.isNotBlank()) { "Motif et opérateur obligatoires." }
        val current = dao.findAppointment(orgId, siteId, appointmentId)
            ?: throw IllegalArgumentException("Rendez-vous introuvable.")
        require(current.status in setOf("booked", "confirmed")) { "Ce rendez-vous ne peut plus être déplacé." }
        val conflicts = dao.countAppointmentConflictsExcludingId(
            orgId, siteId, appointmentId, current.workstationId, current.assignedMemberId,
            newStartAtMillis, newEndAtMillis
        )
        require(conflicts == 0) { "Conflit de planning avec un autre rendez-vous pour ce poste ou ce prestataire." }
        val updated = current.copy(startsAtMillis = newStartAtMillis, endsAtMillis = newEndAtMillis)
        dao.updateAppointment(updated)
        dao.insertWorkflowEvent(
            LocalWorkflowEvent(
                id = UUID.randomUUID().toString(), orgId = orgId, siteId = siteId,
                aggregateType = "appointment", aggregateId = current.id,
                fromStatus = current.status, toStatus = "rescheduled",
                reason = reason.trim(), actorMemberId = actorMemberId,
                createdAtMillis = System.currentTimeMillis()
            )
        )
        enqueue(orgId, "appointment", current.id, "appointment.rescheduled", siteId)
        updated
    }

    suspend fun updateServiceCatalogItem(
        orgId: String,
        siteId: String,
        serviceId: String,
        name: String,
        durationMinutes: Int?,
        priceXaf: Long,
        category: String,
        description: String,
        providerMemberIdsJson: String,
        requiredWorkstationKindsJson: String,
        packageSessions: Int?,
        actorMemberId: String
    ): LocalService = database.withTransaction {
        require(name.isNotBlank() && actorMemberId.isNotBlank()) { "Nom de prestation et opérateur obligatoires." }
        require(durationMinutes == null || durationMinutes in 1..1440) { "Durée invalide." }
        require(priceXaf >= 0L) { "Tarif invalide." }
        require(category in setOf("pressing", "hair", "beauty", "tailoring", "repair", "manufacturing", "vehicle", "cleaning", "home", "printing", "event", "retail", "general")) {
            "Catégorie de prestation invalide."
        }
        require(description.length <= 1000 && providerMemberIdsJson.length <= 2000 && requiredWorkstationKindsJson.length <= 1000) {
            "Configuration trop longue."
        }
        require(packageSessions == null || packageSessions in 1..100) { "Nombre de séances du forfait invalide." }
        val current = dao.findService(orgId, siteId, serviceId) ?: throw IllegalArgumentException("Prestation introuvable sur ce point de vente.")
        val updated = current.copy(
            name = name.trim(),
            durationMinutes = durationMinutes,
            priceXaf = priceXaf,
            category = category,
            description = description.trim(),
            providerMemberIdsJson = providerMemberIdsJson,
            requiredWorkstationKindsJson = requiredWorkstationKindsJson,
            packageSessions = packageSessions
        )
        dao.updateService(updated)
        enqueue(orgId, "service", serviceId, "service.updated", siteId)
        updated
    }

    suspend fun saveServiceConfiguration(
        orgId: String,
        siteId: String,
        serviceId: String,
        category: String,
        description: String,
        providerMemberIdsJson: String,
        requiredWorkstationKindsJson: String,
        packageSessions: Int?,
        actorMemberId: String
    ): LocalService = database.withTransaction {
        require(category in setOf("pressing", "hair", "beauty", "tailoring", "repair", "manufacturing", "vehicle", "cleaning", "home", "printing", "event", "retail", "general")) {
            "Catégorie de prestation invalide."
        }
        require(description.length <= 1000 && providerMemberIdsJson.length <= 2000 && requiredWorkstationKindsJson.length <= 1000) {
            "Configuration trop longue."
        }
        require(packageSessions == null || packageSessions in 1..100) { "Nombre de séances du forfait invalide." }
        require(actorMemberId.isNotBlank()) { "Opérateur obligatoire." }
        val service = dao.findService(orgId, siteId, serviceId) ?: throw IllegalArgumentException("Prestation introuvable.")
        val updated = service.copy(
            category = category,
            description = description.trim(),
            providerMemberIdsJson = providerMemberIdsJson,
            requiredWorkstationKindsJson = requiredWorkstationKindsJson,
            packageSessions = packageSessions
        )
        dao.updateService(updated)
        enqueue(orgId, "service", serviceId, "service.configuration_updated", siteId)
        updated
    }

    suspend fun convertWaitlistToAppointment(
        orgId: String,
        siteId: String,
        waitlistRecordId: String,
        workstationId: String?,
        startsAtMillis: Long,
        durationMinutes: Int,
        depositXaf: Long,
        reason: String,
        actorMemberId: String
    ): LocalAppointment = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && actorMemberId.isNotBlank()) {
            "Organisation, site et opérateur obligatoires."
        }
        require(startsAtMillis > System.currentTimeMillis() - 60_000L && durationMinutes in 5..600 && depositXaf >= 0L) {
            "Créneau, durée ou acompte invalide."
        }
        require(reason.trim().length >= 3 && reason.length <= 500) { "Un motif de conversion est obligatoire." }
        val waitlist = dao.findManagementRecord(orgId, siteId, waitlistRecordId)
            ?: throw IllegalArgumentException("Entrée de liste d'attente introuvable.")
        require(waitlist.recordType == "appointment_waitlist" && waitlist.status in setOf("open", "contacted")) {
            "Cette entrée de liste d'attente n'est plus convertible."
        }
        val normalizedWorkstation = workstationId?.takeIf { it.isNotBlank() }
        if (normalizedWorkstation != null) {
            require(dao.findWorkstation(normalizedWorkstation, orgId, siteId) != null) {
                "L'emplacement sélectionné n'existe pas dans ce point de vente."
            }
        }
        val endsAtMillis = startsAtMillis + durationMinutes * 60_000L
        val conflicts = dao.countAppointmentConflicts(
            orgId, siteId, normalizedWorkstation, actorMemberId, startsAtMillis, endsAtMillis
        )
        require(conflicts == 0) { "Conflit de planning pour le poste ou le prestataire sélectionné." }
        val now = System.currentTimeMillis()
        val appointment = LocalAppointment(
            id = UUID.randomUUID().toString(),
            orgId = orgId,
            siteId = siteId,
            workstationId = normalizedWorkstation,
            customerName = waitlist.counterparty,
            serviceName = waitlist.title,
            assignedMemberId = actorMemberId,
            startsAtMillis = startsAtMillis,
            endsAtMillis = endsAtMillis,
            depositXaf = depositXaf,
            status = "booked",
            actorMemberId = actorMemberId,
            createdAtMillis = now
        )
        dao.insertAppointment(appointment)
        dao.updateManagementRecord(waitlist.copy(status = "booked"))
        dao.insertWorkflowEvent(
            LocalWorkflowEvent(
                id = UUID.randomUUID().toString(), orgId = orgId, siteId = siteId,
                aggregateType = "appointment_waitlist", aggregateId = waitlist.id,
                fromStatus = waitlist.status, toStatus = "booked",
                reason = reason.trim(), actorMemberId = actorMemberId, createdAtMillis = now
            )
        )
        enqueue(orgId, "appointment", appointment.id, "appointment.created_from_waitlist", siteId)
        enqueue(orgId, "appointment_waitlist", waitlist.id, "appointment_waitlist.converted", siteId)
        appointment
    }

    suspend fun recordStaffTimeEvent(
        orgId: String,
        siteId: String,
        eventType: String,
        staffName: String,
        actorMemberId: String,
        workstationId: String? = null
    ): LocalManagementRecord = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && actorMemberId.isNotBlank()) {
            "Organisation, site et opérateur obligatoires."
        }
        val staff = staffName.trim()
        require(staff.length in 2..120) { "Nom ou identifiant de collaborateur invalide." }
        require(eventType in setOf("staff_clock_in", "staff_break_start", "staff_break_end", "staff_clock_out")) {
            "Événement de pointage non pris en charge."
        }
        val latest = dao.findLatestStaffTimeEvent(orgId, siteId, staff)
        val allowed = when (eventType) {
            "staff_clock_in" -> latest == null || latest.recordType == "staff_clock_out"
            "staff_break_start" -> latest != null && latest.recordType in setOf("staff_clock_in", "staff_break_end")
            "staff_break_end" -> latest?.recordType == "staff_break_start"
            "staff_clock_out" -> latest != null && latest.recordType in setOf("staff_clock_in", "staff_break_end")
            else -> false
        }
        require(allowed) {
            val current = latest?.recordType ?: "aucun pointage"
            "Séquence de pointage invalide. Dernier événement : $current."
        }
        val normalizedWorkstation = workstationId?.takeIf { it.isNotBlank() }
        if (normalizedWorkstation != null) {
            require(dao.findWorkstation(normalizedWorkstation, orgId, siteId) != null) {
                "L'emplacement choisi ne fait pas partie de ce point de vente."
            }
        }
        val now = System.currentTimeMillis()
        val title = when (eventType) {
            "staff_clock_in" -> "Prise de service"
            "staff_break_start" -> "Début de pause"
            "staff_break_end" -> "Fin de pause"
            else -> "Fin de service"
        }
        val item = LocalManagementRecord(
            id = UUID.randomUUID().toString(),
            orgId = orgId,
            siteId = siteId,
            recordType = eventType,
            reference = "TIME-" + now.toString() + "-" + UUID.randomUUID().toString().take(6).uppercase(),
            title = title,
            counterparty = staff,
            amountXaf = 0L,
            paidXaf = 0L,
            dueAtMillis = null,
            status = "open",
            metadataJson = org.json.JSONObject()
                .put("event", eventType)
                .put("recordedLocal", true)
                .put("workstationId", normalizedWorkstation)
                .toString(),
            actorMemberId = actorMemberId,
            createdAtMillis = now,
            workstationId = normalizedWorkstation
        )
        dao.insertManagementRecord(item)
        dao.insertWorkflowEvent(
            LocalWorkflowEvent(
                id = UUID.randomUUID().toString(),
                orgId = orgId,
                siteId = siteId,
                aggregateType = eventType,
                aggregateId = item.id,
                fromStatus = latest?.recordType ?: "",
                toStatus = eventType,
                reason = "Pointage chronologique validé",
                actorMemberId = actorMemberId,
                createdAtMillis = now
            )
        )
        enqueue(orgId, eventType, item.id, eventType + ".recorded", siteId)
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
        actorMemberId: String,
        workstationId: String? = null
    ): LocalManagementRecord = database.withTransaction {
        val allowedTypes = setOf("quote", "invoice", "credit_note", "refund_due", "customer_receivable", "purchase", "supplier", "tax_estimate", "business_goal", "subscription_request", "support_chat", "work_order", "repair_order", "service_order", "appointment_waitlist", "staff_clock_in", "staff_clock_out", "staff_break_start", "staff_break_end", "staff_commission", "staff_advance", "staff_bonus")
        require(orgId.isNotBlank() && siteId.isNotBlank() && actorMemberId.isNotBlank()) { "Organisation, site et opérateur obligatoires." }
        require(recordType in allowedTypes) { "Type de registre non autorisé." }
        require(title.isNotBlank() && amountXaf >= 0L && paidXaf >= 0L && paidXaf <= amountXaf) { "Montants ou libellé incohérents." }
        val normalizedWorkstationId = workstationId?.takeIf { it.isNotBlank() }
        if (normalizedWorkstationId != null) {
            require(dao.findWorkstation(normalizedWorkstationId, orgId, siteId) != null) {
                "L'emplacement associé au dossier n'existe pas sur ce point de vente."
            }
        }
        require(status in setOf("draft", "received", "open", "diagnostic", "measurement", "quote_pending", "waiting_customer", "awaiting_approval", "contacted", "approved", "waiting_parts", "fabrication", "fitting", "proof_ready", "production", "planning", "shooting", "post_production", "on_site", "installation", "ordered", "partially_received", "in_progress", "quality_check", "ready", "delivered", "invoice_review", "closed", "partial", "paid", "cancelled", "pending_review", "rejected")) { "Statut non autorisé." }
        val now = System.currentTimeMillis()
        val item = LocalManagementRecord(
            id = UUID.randomUUID().toString(), orgId = orgId, siteId = siteId,
            recordType = recordType, reference = reference.trim(), title = title.trim(),
            counterparty = counterparty.trim(), amountXaf = amountXaf, paidXaf = paidXaf,
            dueAtMillis = dueAtMillis, status = status, metadataJson = metadataJson.take(4000),
            actorMemberId = actorMemberId, createdAtMillis = now,
            workstationId = normalizedWorkstationId
        )
        dao.insertManagementRecord(item)
        enqueue(orgId, recordType, item.id, recordType + ".created", siteId)
        item
    }

    suspend fun createInventoryTransfer(
        orgId: String,
        sourceSiteId: String,
        destinationSiteId: String,
        inventoryItemId: String,
        quantity: Double,
        actorMemberId: String,
        actorRoleCode: String
    ): LocalManagementRecord = database.withTransaction {
        require(actorRoleCode == "promoter") { "Seul le Promoteur du réseau peut initier un transfert inter-sites." }
        require(orgId.isNotBlank() && actorMemberId.isNotBlank()) { "Organisation et opérateur obligatoires." }
        require(sourceSiteId.isNotBlank() && destinationSiteId.isNotBlank() && sourceSiteId != destinationSiteId) {
            "Les deux points de vente doivent être renseignés et distincts."
        }
        require(quantity.isFinite() && quantity > 0.0) { "La quantité à transférer doit être strictement positive." }

        val sourceSite = dao.findSite(sourceSiteId, orgId)
            ?: throw IllegalArgumentException("Le point de vente source n'appartient pas à cette organisation.")
        val destinationSite = dao.findSite(destinationSiteId, orgId)
            ?: throw IllegalArgumentException("Le point de vente destination n'appartient pas à cette organisation.")
        require(sourceSite.status == "active" && destinationSite.status == "active") {
            "Les deux points de vente doivent être actifs."
        }

        val item = dao.findInventoryItem(inventoryItemId, orgId, sourceSiteId)
            ?: throw IllegalArgumentException("L'article source est introuvable dans ce point de vente.")
        require(item.active && item.quantity >= quantity) { "Stock source insuffisant ou article inactif." }

        val destinationMatches = dao.findInventoryItemsBySku(orgId, destinationSiteId, item.sku)
        require(destinationMatches.size <= 1) {
            "Le SKU existe plusieurs fois à destination ; corrige les doublons avant le transfert."
        }
        destinationMatches.singleOrNull()?.let { destinationItem ->
            require(destinationItem.unit.trim().equals(item.unit.trim(), ignoreCase = true)) {
                "L'unité de l'article destination diffère de celle du stock source."
            }
        }

        val now = System.currentTimeMillis()
        val reference = "TRF-" + now.toString() + "-" + UUID.randomUUID().toString().take(6).uppercase()
        val metadata = org.json.JSONObject()
            .put("transferVersion", 1)
            .put("sourceSiteId", sourceSite.id)
            .put("sourceSiteName", sourceSite.name)
            .put("destinationSiteId", destinationSite.id)
            .put("destinationSiteName", destinationSite.name)
            .put("inventoryItemId", item.id)
            .put("sku", item.sku)
            .put("itemName", item.name)
            .put("unit", item.unit)
            .put("quantity", quantity)
            .put("requestedAtMillis", now)
            .put("requestedBy", actorMemberId)
            .toString()

        val transfer = LocalManagementRecord(
            id = UUID.randomUUID().toString(),
            orgId = orgId,
            siteId = sourceSiteId,
            recordType = "inventory_transfer",
            reference = reference,
            title = item.name,
            counterparty = destinationSite.name,
            amountXaf = 0L,
            paidXaf = 0L,
            dueAtMillis = null,
            status = "open",
            metadataJson = metadata,
            actorMemberId = actorMemberId,
            createdAtMillis = now
        )
        dao.insertManagementRecord(transfer)
        enqueue(orgId, "inventory_transfer", transfer.id, "inventory_transfer.requested", sourceSiteId)
        transfer
    }

    suspend fun transitionManagementRecord(
        orgId: String,
        siteId: String,
        recordId: String,
        nextStatus: String,
        reason: String,
        actorMemberId: String
    ): LocalManagementRecord = database.withTransaction {
        require(orgId.isNotBlank() && siteId.isNotBlank() && actorMemberId.isNotBlank()) {
            "Organisation, site et opérateur obligatoires."
        }
        require(reason.trim().length >= 3 && reason.length <= 500) { "Un motif de trois caractères minimum est obligatoire." }
        val current = dao.findManagementRecord(orgId, siteId, recordId)
            ?: throw IllegalArgumentException("Dossier introuvable sur ce point de vente.")
        val workActivity = runCatching { org.json.JSONObject(current.metadataJson).optString("activity", "autre") }.getOrDefault("autre")
        val activityLifecycle: Map<String, Set<String>> = when (workActivity) {
            "couture" -> mapOf(
                "received" to setOf("measurement", "diagnostic", "cancelled"),
                "open" to setOf("measurement", "diagnostic", "cancelled"),
                "measurement" to setOf("quote_pending", "cancelled"),
                "diagnostic" to setOf("quote_pending", "cancelled"),
                "quote_pending" to setOf("waiting_customer", "approved", "cancelled"),
                "waiting_customer" to setOf("approved", "cancelled"),
                "approved" to setOf("waiting_parts", "in_progress"),
                "waiting_parts" to setOf("in_progress"),
                "in_progress" to setOf("fitting", "quality_check"),
                "fitting" to setOf("in_progress", "quality_check"),
                "quality_check" to setOf("fitting", "ready"),
                "ready" to setOf("delivered"),
                "delivered" to setOf("closed")
            )
            "menuiserie" -> mapOf(
                "received" to setOf("diagnostic", "quote_pending", "cancelled"),
                "open" to setOf("diagnostic", "quote_pending", "cancelled"),
                "diagnostic" to setOf("quote_pending", "cancelled"),
                "quote_pending" to setOf("waiting_customer", "approved", "cancelled"),
                "waiting_customer" to setOf("approved", "cancelled"),
                "approved" to setOf("waiting_parts", "fabrication"),
                "waiting_parts" to setOf("fabrication"),
                "fabrication" to setOf("quality_check"),
                "quality_check" to setOf("fabrication", "installation", "ready"),
                "installation" to setOf("ready"),
                "ready" to setOf("delivered"),
                "delivered" to setOf("closed")
            )
            "impression" -> mapOf(
                "received" to setOf("quote_pending", "proof_ready", "cancelled"),
                "open" to setOf("quote_pending", "proof_ready", "cancelled"),
                "quote_pending" to setOf("waiting_customer", "proof_ready", "cancelled"),
                "waiting_customer" to setOf("approved", "cancelled"),
                "proof_ready" to setOf("approved", "in_progress", "cancelled"),
                "approved" to setOf("production"),
                "production" to setOf("quality_check"),
                "quality_check" to setOf("production", "ready"),
                "ready" to setOf("delivered"),
                "delivered" to setOf("closed")
            )
            "domicile", "nettoyage" -> mapOf(
                "received" to setOf("quote_pending", "approved", "cancelled"),
                "open" to setOf("quote_pending", "approved", "cancelled"),
                "quote_pending" to setOf("waiting_customer", "approved", "cancelled"),
                "waiting_customer" to setOf("approved", "cancelled"),
                "approved" to setOf("planning", "on_site"),
                "planning" to setOf("on_site", "cancelled"),
                "on_site" to setOf("in_progress"),
                "in_progress" to setOf("quality_check"),
                "quality_check" to setOf("in_progress", "ready"),
                "ready" to setOf("delivered"),
                "delivered" to setOf("closed")
            )
            "photo_evenementiel" -> mapOf(
                "received" to setOf("quote_pending", "planning", "cancelled"),
                "open" to setOf("quote_pending", "planning", "cancelled"),
                "quote_pending" to setOf("waiting_customer", "approved", "cancelled"),
                "waiting_customer" to setOf("approved", "cancelled"),
                "approved" to setOf("planning"),
                "planning" to setOf("shooting"),
                "shooting" to setOf("post_production"),
                "post_production" to setOf("quality_check"),
                "quality_check" to setOf("post_production", "ready"),
                "ready" to setOf("delivered"),
                "delivered" to setOf("closed")
            )
            else -> emptyMap()
        }
        val allowed = when (current.recordType) {
            "work_order", "repair_order", "service_order" -> activityLifecycle[current.status]
                ?: when (current.status) {
                    "received", "open" -> setOf("diagnostic", "quote_pending", "in_progress", "cancelled")
                    "diagnostic" -> setOf("quote_pending", "awaiting_approval", "in_progress", "cancelled")
                    "quote_pending" -> setOf("waiting_customer", "approved", "cancelled")
                    "waiting_customer", "awaiting_approval" -> setOf("approved", "cancelled")
                    "approved" -> setOf("waiting_parts", "in_progress")
                    "waiting_parts" -> setOf("in_progress")
                    "in_progress" -> setOf("quality_check", "ready")
                    "quality_check" -> setOf("in_progress", "ready")
                    "ready" -> setOf("delivered")
                    "delivered" -> setOf("closed")
                    else -> emptySet()
                }
            "inventory_transfer" -> when (current.status) {
                "open" -> setOf("approved", "rejected")
                "approved" -> setOf("received", "rejected")
                else -> emptySet()
            }
            "purchase" -> when (current.status) {
                "draft", "open" -> setOf("ordered", "cancelled")
                "ordered" -> setOf("partially_received", "received", "cancelled")
                "partially_received" -> setOf("received")
                "received" -> setOf("invoice_review")
                "invoice_review" -> setOf("closed")
                else -> emptySet()
            }
            "staff_commission", "staff_advance", "staff_bonus" -> when (current.status) {
                "pending_review" -> setOf("approved", "rejected")
                else -> emptySet()
            }
            "invoice", "customer_receivable" -> when (current.status) {
                "open", "partial" -> setOf("partial", "paid", "cancelled")
                else -> emptySet()
            }
            "quote" -> when (current.status) {
                "draft", "open" -> setOf("approved", "rejected", "cancelled")
                else -> emptySet()
            }
            "appointment_waitlist" -> when (current.status) {
                "open" -> setOf("contacted", "booked", "cancelled")
                "contacted" -> setOf("booked", "cancelled")
                else -> emptySet()
            }
            else -> emptySet()
        }
        require(nextStatus in allowed) {
            "Transition interdite : ${current.status} → $nextStatus pour ${current.recordType}."
        }
        val now = System.currentTimeMillis()
        // Receiving a purchase order updates the selected site's inventory only
        // when the order contains one explicitly linked stock item and quantity.
        if (current.recordType == "purchase" && nextStatus == "received") {
            val metadata = runCatching { org.json.JSONObject(current.metadataJson) }.getOrElse {
                throw IllegalArgumentException("Les lignes d'achat doivent être corrigées avant la réception.")
            }
            val inventoryItemId = metadata.optString("inventoryItemId").takeIf { it.isNotBlank() }
            val receivedQuantity = metadata.optDouble("quantity", 0.0)
            if (inventoryItemId != null) {
                require(receivedQuantity.isFinite() && receivedQuantity > 0.0) { "Quantité reçue invalide." }
                val stockItem = dao.findInventoryItem(inventoryItemId, orgId, siteId)
                    ?: throw IllegalArgumentException("L'article lié à l'achat n'existe plus dans ce point de vente.")
                val movement = LocalInventoryMovement(
                    id = UUID.randomUUID().toString(),
                    orgId = orgId,
                    siteId = siteId,
                    itemId = stockItem.id,
                    movementType = "in",
                    quantityDelta = receivedQuantity,
                    reason = "Réception de l'achat ${current.reference}",
                    actorMemberId = actorMemberId,
                    createdAtMillis = now
                )
                dao.insertInventoryMovement(movement)
                dao.updateInventoryItem(stockItem.copy(quantity = stockItem.quantity + receivedQuantity))
                enqueue(orgId, "inventory_movement", movement.id, "inventory_movement.purchase_received", siteId)
            }
        }
        var updatedMetadataJson = current.metadataJson
        if (current.recordType == "inventory_transfer" && nextStatus == "received") {
            val metadata = runCatching { org.json.JSONObject(current.metadataJson) }.getOrElse {
                throw IllegalArgumentException("Métadonnées du transfert invalides.")
            }
            val sourceSiteId = metadata.optString("sourceSiteId")
            val destinationSiteId = metadata.optString("destinationSiteId")
            val inventoryItemId = metadata.optString("inventoryItemId")
            val expectedSku = metadata.optString("sku")
            val quantity = metadata.optDouble("quantity", 0.0)
            require(sourceSiteId == siteId && destinationSiteId.isNotBlank() && destinationSiteId != sourceSiteId) {
                "Périmètre source/destination du transfert invalide."
            }
            require(inventoryItemId.isNotBlank() && expectedSku.isNotBlank() && quantity.isFinite() && quantity > 0.0) {
                "Article, SKU ou quantité de transfert invalide."
            }
            val sourceSite = dao.findSite(sourceSiteId, orgId)
                ?: throw IllegalArgumentException("Le site source n'existe plus dans cette organisation.")
            val destinationSite = dao.findSite(destinationSiteId, orgId)
                ?: throw IllegalArgumentException("Le site destination n'existe plus dans cette organisation.")
            require(sourceSite.status == "active" && destinationSite.status == "active") {
                "Le transfert ne peut pas être réceptionné car l'un des sites est inactif."
            }
            val sourceItem = dao.findInventoryItem(inventoryItemId, orgId, sourceSiteId)
                ?: throw IllegalArgumentException("L'article source du transfert n'existe plus.")
            require(sourceItem.active && sourceItem.sku == expectedSku && sourceItem.quantity >= quantity) {
                "Stock source insuffisant ou article modifié depuis la demande."
            }

            val destinationMatches = dao.findInventoryItemsBySku(orgId, destinationSiteId, expectedSku)
            require(destinationMatches.size <= 1) {
                "Plusieurs articles portent ce SKU à destination ; réception refusée."
            }
            val destinationItem = destinationMatches.singleOrNull()
            if (destinationItem != null) {
                require(destinationItem.unit.trim().equals(sourceItem.unit.trim(), ignoreCase = true)) {
                    "Unité source/destination incompatible ; réception refusée."
                }
            }

            val receivedItem = if (destinationItem == null) {
                LocalInventoryItem(
                    id = UUID.randomUUID().toString(),
                    orgId = orgId,
                    siteId = destinationSiteId,
                    sku = sourceItem.sku,
                    name = sourceItem.name,
                    unit = sourceItem.unit,
                    quantity = quantity,
                    reorderLevel = sourceItem.reorderLevel,
                    active = true,
                    createdAtMillis = now
                ).also { dao.insertInventoryItem(it) }
            } else {
                destinationItem.copy(quantity = destinationItem.quantity + quantity)
                    .also { dao.updateInventoryItem(it) }
            }

            dao.updateInventoryItem(sourceItem.copy(quantity = sourceItem.quantity - quantity))
            val sourceMovement = LocalInventoryMovement(
                id = UUID.randomUUID().toString(),
                orgId = orgId,
                siteId = sourceSiteId,
                itemId = sourceItem.id,
                movementType = "transfer_out",
                quantityDelta = -quantity,
                reason = "Transfert reçu à " + destinationSite.name + " · " + current.reference,
                actorMemberId = actorMemberId,
                createdAtMillis = now
            )
            val destinationMovement = LocalInventoryMovement(
                id = UUID.randomUUID().toString(),
                orgId = orgId,
                siteId = destinationSiteId,
                itemId = receivedItem.id,
                movementType = "transfer_in",
                quantityDelta = quantity,
                reason = "Transfert reçu depuis " + sourceSite.name + " · " + current.reference,
                actorMemberId = actorMemberId,
                createdAtMillis = now
            )
            dao.insertInventoryMovement(sourceMovement)
            dao.insertInventoryMovement(destinationMovement)
            enqueue(orgId, "inventory_movement", sourceMovement.id, "inventory_movement.transfer_out", sourceSiteId)
            enqueue(orgId, "inventory_movement", destinationMovement.id, "inventory_movement.transfer_in", destinationSiteId)

            metadata.put("receivedAtMillis", now)
                .put("receivedBy", actorMemberId)
                .put("destinationInventoryItemId", receivedItem.id)
            updatedMetadataJson = metadata.toString()
            dao.insertWorkflowEvent(
                LocalWorkflowEvent(
                    id = UUID.randomUUID().toString(),
                    orgId = orgId,
                    siteId = destinationSiteId,
                    aggregateType = "inventory_transfer",
                    aggregateId = current.id,
                    fromStatus = "approved",
                    toStatus = "received",
                    reason = reason.trim(),
                    actorMemberId = actorMemberId,
                    createdAtMillis = now
                )
            )
            enqueue(orgId, "inventory_transfer", current.id, "inventory_transfer.received_at_destination", destinationSiteId)
        }
        val updated = current.copy(status = nextStatus, metadataJson = updatedMetadataJson)
        dao.updateManagementRecord(updated)
        dao.insertWorkflowEvent(
            LocalWorkflowEvent(
                id = UUID.randomUUID().toString(),
                orgId = orgId,
                siteId = siteId,
                aggregateType = current.recordType,
                aggregateId = current.id,
                fromStatus = current.status,
                toStatus = nextStatus,
                reason = reason.trim(),
                actorMemberId = actorMemberId,
                createdAtMillis = now
            )
        )
        enqueue(orgId, current.recordType, current.id, current.recordType + ".status_changed", siteId)
        updated
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
