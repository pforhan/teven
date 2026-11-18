package alphainterplanetary.teven.data.inventory

import alphainterplanetary.teven.api.model.common.PaginatedResponse
import alphainterplanetary.teven.api.model.event.EventSummaryResponse
import alphainterplanetary.teven.api.model.inventory.CreateInventoryItemRequest
import alphainterplanetary.teven.api.model.inventory.InventoryItemResponse
import alphainterplanetary.teven.api.model.inventory.TrackInventoryUsageRequest
import alphainterplanetary.teven.api.model.inventory.UpdateInventoryItemRequest
import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import alphainterplanetary.teven.core.Pagination
import alphainterplanetary.teven.data.dbQuery
import alphainterplanetary.teven.data.event.EventInventory
import alphainterplanetary.teven.data.event.Events
import alphainterplanetary.teven.data.organization.Organizations
import java.time.Clock
import java.time.ZoneId
import org.jetbrains.exposed.v1.core.Count
import org.jetbrains.exposed.v1.core.Op
import org.jetbrains.exposed.v1.core.ResultRow
import org.jetbrains.exposed.v1.core.SortOrder
import org.jetbrains.exposed.v1.core.and
import org.jetbrains.exposed.v1.core.eq
import org.jetbrains.exposed.v1.core.inList
import org.jetbrains.exposed.v1.core.like
import org.jetbrains.exposed.v1.core.lowerCase
import org.jetbrains.exposed.v1.jdbc.deleteWhere
import org.jetbrains.exposed.v1.jdbc.insert
import org.jetbrains.exposed.v1.jdbc.select
import org.jetbrains.exposed.v1.jdbc.selectAll
import org.jetbrains.exposed.v1.jdbc.update

class InventoryDao(private val clock: Clock) {
  private fun toOrganizationResponse(row: ResultRow): OrganizationResponse =
    OrganizationResponse(
      organizationId = row[Organizations.id].value,
      name = row[Organizations.name],
      contactInformation = row[Organizations.contactInformation],
      timezone = row[Organizations.timezone],
    )

  private fun eventsFor(inventoryId: Int): List<EventSummaryResponse> =
    EventInventory.selectAll()
      .where { EventInventory.inventoryItemId eq inventoryId }
      .map { EventSummaryResponse(it[EventInventory.eventId], "", it[EventInventory.quantity]) }

  private fun toInventoryItemDetailResponse(row: ResultRow): InventoryItemResponse {
    val inventoryId = row[InventoryItems.id].value
    val events = eventsFor(inventoryId)
    val organization = Organizations.selectAll()
      .where { Organizations.id eq row[InventoryItems.organizationId] }
      .single()
      .let(::toOrganizationResponse)

    return InventoryItemResponse(
      inventoryId = inventoryId,
      name = row[InventoryItems.name],
      description = row[InventoryItems.description],
      quantity = row[InventoryItems.quantity],
      eventCount = events.size,
      events = events,
      organization = organization,
    )
  }

  private fun toInventoryItemListResponse(
    row: ResultRow,
    eventCount: Int,
  ): InventoryItemResponse {
    val organization = Organizations.selectAll()
      .where { Organizations.id eq row[InventoryItems.organizationId] }
      .single()
      .let(::toOrganizationResponse)

    return InventoryItemResponse(
      inventoryId = row[InventoryItems.id].value,
      name = row[InventoryItems.name],
      description = row[InventoryItems.description],
      quantity = row[InventoryItems.quantity],
      eventCount = eventCount,
      events = emptyList(),
      organization = organization,
    )
  }

  suspend fun getInventoryItems(
    organizationId: Int?,
    search: String?,
    limit: Int?,
    offset: Long?,
    sortBy: String?,
    sortOrder: String?,
  ): PaginatedResponse<InventoryItemResponse> = dbQuery {
    val conditions = mutableListOf<Op<Boolean>>()
    organizationId?.let { conditions.add(InventoryItems.organizationId eq it) }
    search?.let { conditions.add(InventoryItems.name.lowerCase() like "%${it.lowercase()}%") }

    val query = if (conditions.isEmpty()) {
      InventoryItems.selectAll()
    } else {
      val combinedCondition = conditions.reduce { acc, op -> acc and op }
      InventoryItems.selectAll().where { combinedCondition }
    }

    val total = query.count()

    val sort = if (sortOrder == "desc") SortOrder.DESC else SortOrder.ASC
    when (sortBy) {
      "name" -> query.orderBy(InventoryItems.name, sort)
      "quantity" -> query.orderBy(InventoryItems.quantity, sort)
      else -> query.orderBy(InventoryItems.id, sort)
    }

    val effectiveOffset = offset ?: 0
    val effectiveLimit = Pagination.effectiveLimit(limit)
    query.offset(effectiveOffset)
    query.limit(effectiveLimit)

    val rows = query.toList()
    val ids = rows.map { it[InventoryItems.id].value }
    val eventCounts = if (ids.isEmpty()) {
      emptyMap()
    } else {
      val countExpr = Count(EventInventory.eventId)
      EventInventory
        .select(EventInventory.inventoryItemId, countExpr)
        .where { EventInventory.inventoryItemId inList ids }
        .groupBy(EventInventory.inventoryItemId)
        .associate { it[EventInventory.inventoryItemId] to it[countExpr].toInt() }
    }

    val items = rows.map { row ->
      val id = row[InventoryItems.id].value
      toInventoryItemListResponse(row, eventCounts[id] ?: 0)
    }

    PaginatedResponse(
      items = items,
      total = total,
      offset = effectiveOffset,
      limit = effectiveLimit,
    )
  }

  suspend fun getAllInventoryItems(): List<InventoryItemResponse> = dbQuery {
    InventoryItems.selectAll().map { toInventoryItemDetailResponse(it) }
  }

  suspend fun getAllInventoryItemsByOrganization(organizationId: Int): List<InventoryItemResponse> =
    dbQuery {
      InventoryItems.selectAll()
        .where { InventoryItems.organizationId eq organizationId }
        .map { toInventoryItemDetailResponse(it) }
    }

  suspend fun getInventoryItemById(inventoryId: Int): InventoryItemResponse? = dbQuery {
    InventoryItems.selectAll()
      .where { InventoryItems.id eq inventoryId }
      .mapNotNull { toInventoryItemDetailResponse(it) }
      .singleOrNull()
  }

  suspend fun createInventoryItem(createInventoryItemRequest: CreateInventoryItemRequest): InventoryItemResponse =
    dbQuery {
      val id = InventoryItems.insert { insertStatement ->
        insertStatement[name] = createInventoryItemRequest.name
        insertStatement[description] = createInventoryItemRequest.description
        insertStatement[quantity] = createInventoryItemRequest.quantity
        insertStatement[organizationId] = createInventoryItemRequest.organizationId!!
      } get InventoryItems.id

      InventoryItemResponse(
        inventoryId = id.value,
        name = createInventoryItemRequest.name,
        description = createInventoryItemRequest.description,
        quantity = createInventoryItemRequest.quantity,
        eventCount = 0,
        events = emptyList(),
        organization = Organizations.selectAll()
          .where { Organizations.id eq createInventoryItemRequest.organizationId }
          .single()
          .let(::toOrganizationResponse),
      )
    }

  suspend fun updateInventoryItem(
    inventoryId: Int,
    updateInventoryItemRequest: UpdateInventoryItemRequest,
  ): InventoryItemResponse? = dbQuery {
    val updated = InventoryItems.update({ InventoryItems.id eq inventoryId }) {
      updateInventoryItemRequest.name?.let { name -> it[InventoryItems.name] = name }
      updateInventoryItemRequest.description?.let { description ->
        it[InventoryItems.description] = description
      }
      updateInventoryItemRequest.quantity?.let { quantity ->
        it[InventoryItems.quantity] = quantity
      }
      updateInventoryItemRequest.organizationId?.let { organizationId ->
        it[InventoryItems.organizationId] = organizationId
      }
    } > 0
    if (!updated) return@dbQuery null

    InventoryItems.selectAll()
      .where { InventoryItems.id eq inventoryId }
      .mapNotNull { toInventoryItemDetailResponse(it) }
      .singleOrNull()
  }

  suspend fun deleteInventoryItem(inventoryId: Int): Boolean = dbQuery {
    return@dbQuery InventoryItems.deleteWhere { InventoryItems.id eq inventoryId } > 0
  }

  suspend fun trackInventoryUsage(
    inventoryId: Int,
    trackInventoryUsageRequest: TrackInventoryUsageRequest,
  ): InventoryItemResponse? = dbQuery {
    // 7.24: usage_date is the event's date in the event's own zone (not the
    // server's wall clock). The event carries its zone; a PK lookup is enough.
    val event =
      Events.selectAll()
        .where { Events.id eq trackInventoryUsageRequest.eventId }
        .single()
    val usageDate =
      event[Events.startsAt].toInstant().atZone(ZoneId.of(event[Events.timezone])).toLocalDate()

    InventoryUsage.insert {
      it[InventoryUsage.inventoryId] = inventoryId
      it[InventoryUsage.eventId] = trackInventoryUsageRequest.eventId
      it[InventoryUsage.quantityUsed] = trackInventoryUsageRequest.quantity
      it[InventoryUsage.usageDate] = usageDate
    }

    InventoryItems.selectAll()
      .where { InventoryItems.id eq inventoryId }
      .mapNotNull { toInventoryItemDetailResponse(it) }
      .singleOrNull()
  }

  suspend fun getInventoryItemsForEvent(eventId: Int): List<InventoryItemResponse> = dbQuery {
    (EventInventory innerJoin InventoryItems)
      .select(InventoryItems.columns)
      .where { EventInventory.eventId eq eventId }
      .map { toInventoryItemDetailResponse(it) }
  }
}