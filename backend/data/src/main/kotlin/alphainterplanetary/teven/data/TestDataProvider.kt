package alphainterplanetary.teven.data

import alphainterplanetary.teven.core.security.PasswordHasher
import alphainterplanetary.teven.data.customer.Customers
import alphainterplanetary.teven.data.event.EventInventory
import alphainterplanetary.teven.data.event.Events
import alphainterplanetary.teven.data.event.Rsvps
import alphainterplanetary.teven.data.inventory.InventoryItems
import alphainterplanetary.teven.data.inventory.InventoryUsage
import alphainterplanetary.teven.data.invitation.Invitations
import alphainterplanetary.teven.data.organization.Organizations
import alphainterplanetary.teven.data.role.Roles
import alphainterplanetary.teven.data.role.UserRoles
import alphainterplanetary.teven.data.user.UserOrganizations
import alphainterplanetary.teven.data.user.Users
import org.jetbrains.exposed.v1.core.eq
import org.jetbrains.exposed.v1.core.inList
import org.jetbrains.exposed.v1.core.like
import org.jetbrains.exposed.v1.jdbc.deleteWhere
import org.jetbrains.exposed.v1.jdbc.insert
import org.jetbrains.exposed.v1.jdbc.selectAll
import java.time.LocalDate
import java.time.LocalTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZoneOffset

/**
 * The plaintext password every seeded account is created with.
 *
 * Named so it appears once rather than four times, and so a reader looking for
 * "how do I log in as alice" finds it in one place.
 */
const val SEEDED_PASSWORD = "password"

private fun eventInstant(date: LocalDate, time: LocalTime, zone: String): OffsetDateTime =
    OffsetDateTime.ofInstant(date.atTime(time).atZone(ZoneId.of(zone)).toInstant(), ZoneOffset.UTC)

suspend fun populateTestData() {
  dbQuery {
    val testOrgPrefix = "TEST_ORG_"

    // Find and delete existing test organizations and their associated data
    val testOrganizationIds = Organizations.selectAll()
      .where { Organizations.name like "$testOrgPrefix%" }
      .map { it[Organizations.id].value }

    // Grab all user IDs associated with these test organizations before we delete the mappings
    val testUserIds = UserOrganizations.selectAll()
      .where { UserOrganizations.organizationId inList testOrganizationIds }
      .map { it[UserOrganizations.userId] }
      .distinct()

    testOrganizationIds.forEach { orgId ->
      // Delete dependent data first
      val eventIds = Events.selectAll()
        .where { Events.organizationId eq orgId }.map { it[Events.id] }
      if (eventIds.isNotEmpty()) {
        Rsvps.deleteWhere { Rsvps.eventId inList eventIds }
        EventInventory.deleteWhere { EventInventory.eventId inList eventIds }
      }
      Events.deleteWhere { Events.organizationId eq orgId }
      Customers.deleteWhere { Customers.organizationId eq orgId }
      InventoryItems.deleteWhere { InventoryItems.organizationId eq orgId }
      UserOrganizations.deleteWhere { UserOrganizations.organizationId eq orgId }
      Invitations.deleteWhere { Invitations.organizationId eq orgId }
    }

    // Delete the users found in test organizations
    if (testUserIds.isNotEmpty()) {
      UserRoles.deleteWhere { UserRoles.userId inList testUserIds }
      Users.deleteWhere { Users.id inList testUserIds }
    }

    // Finally, delete the test organizations
    Organizations.deleteWhere { Organizations.name like "$testOrgPrefix%" }

    // Create Organizations
    val org1Id = (Organizations.insert {
      it[name] = "${testOrgPrefix}Green Vistas Landscaping"
      it[contactInformation] = "contact@greenvistas.com"
      it[Organizations.timezone] = "America/New_York"
    } get Organizations.id).value
    val org2Id = (Organizations.insert {
      it[name] = "${testOrgPrefix}Urban Bloom Gardens"
      it[contactInformation] = "info@urbanbloom.com"
      it[Organizations.timezone] = "Pacific/Auckland"
    } get Organizations.id).value

    // Create Users
    //
    // The password goes through `PasswordHasher`, as `UserDao.createUser` does.
    // It used to be written as the literal string `"password"`, which
    // `BCrypt.checkpw` throws `IllegalArgumentException: Invalid salt version`
    // on -- so every seeded account answered HTTP 500 with a stack trace
    // instead of logging in. The accounts existed and looked right in the
    // database; nothing could authenticate as any of them.
    //
    // Hashed once and shared rather than per user: bcrypt is deliberately slow
    // (~100ms at cost 10), four hashes at boot is a third of a second of
    // startup in dev, and the cost is only worthwhile if a seeded password is
    // ever a real one. `PasswordHasher.checkPassword` is what protects the
    // login path now, not the salt being unique.
    val seededPasswordHash = PasswordHasher.hashPassword(SEEDED_PASSWORD)

    val user1Id = (Users.insert {
      it[username] = "alice"
      it[displayName] = "Alice"
      it[email] = "alice@greenvistas.com"
      it[passwordHash] = seededPasswordHash
    } get Users.id).value
    val user2Id = (Users.insert {
      it[username] = "bob"
      it[displayName] = "Bob"
      it[email] = "bob@greenvistas.com"
      it[passwordHash] = seededPasswordHash
    } get Users.id).value
    val user3Id = (Users.insert {
      it[username] = "charlie"
      it[displayName] = "Charlie"
      it[email] = "charlie@urbanbloom.com"
      it[passwordHash] = seededPasswordHash
    } get Users.id).value
    val user4Id = (Users.insert {
      it[username] = "diana"
      it[displayName] = "Diana"
      it[email] = "diana@urbanbloom.com"
      it[passwordHash] = seededPasswordHash
    } get Users.id).value

    // Associate Users with Organizations
    UserOrganizations.insert {
      it[userId] = user1Id
      it[organizationId] = org1Id
    }
    UserOrganizations.insert {
      it[userId] = user2Id
      it[organizationId] = org1Id
    }
    UserOrganizations.insert {
      it[userId] = user3Id
      it[organizationId] = org2Id
    }
    UserOrganizations.insert {
      it[userId] = user4Id
      it[organizationId] = org2Id
    }

    // Assign Roles
    val organizerRoleId = Roles.selectAll().where { Roles.roleName eq "Organizer" }.single()[Roles.id].value
    val staffRoleId = Roles.selectAll().where { Roles.roleName eq "Staff" }.single()[Roles.id].value

    UserRoles.insert {
      it[userId] = user1Id
      it[roleId] = organizerRoleId
    }
    UserRoles.insert {
      it[userId] = user2Id
      it[roleId] = staffRoleId
    }
    UserRoles.insert {
      it[userId] = user3Id
      it[roleId] = organizerRoleId
    }
    UserRoles.insert {
      it[userId] = user4Id
      it[roleId] = staffRoleId
    }

    // Create Customers
    val cust1Id = Customers.insert {
      it[name] = "Smith Residence"
      it[phone] = "555-1234"
      it[address] = "123 Main St"
      it[notes] = "Large backyard"
      it[organizationId] = org1Id
    } get Customers.id
    val cust2Id = Customers.insert {
      it[name] = "Jones Corporation"
      it[phone] = "555-5678"
      it[address] = "456 Business Ave"
      it[notes] = "Corporate campus"
      it[organizationId] = org1Id
    } get Customers.id
    val cust3Id = Customers.insert {
      it[name] = "City Park"
      it[phone] = "555-9012"
      it[address] = "789 Park Rd"
      it[notes] = "Public space"
      it[organizationId] = org2Id
    } get Customers.id
    val cust4Id = Customers.insert {
      it[name] = "Rooftop Bar"
      it[phone] = "555-3456"
      it[address] = "321 High St"
      it[notes] = "Rooftop garden"
      it[organizationId] = org2Id
    } get Customers.id

    // Create Inventory Items
    val lawnMowerId = (InventoryItems.insert {
      it[name] = "Lawn Mower"
      it[description] = "Gas-powered"
      it[quantity] = 5
      it[organizationId] = org1Id
    } get InventoryItems.id).value
    val hedgeTrimmerId = (InventoryItems.insert {
      it[name] = "Hedge Trimmer"
      it[description] = "Electric"
      it[quantity] = 3
      it[organizationId] = org1Id
    } get InventoryItems.id).value
    val shovelId = (InventoryItems.insert {
      it[name] = "Shovel"
      it[description] = "Round point"
      it[quantity] = 10
      it[organizationId] = org1Id
    } get InventoryItems.id).value
    val rakeId = (InventoryItems.insert {
      it[name] = "Rake"
      it[description] = "Leaf rake"
      it[quantity] = 8
      it[organizationId] = org1Id
    } get InventoryItems.id).value
    val glovesId = (InventoryItems.insert {
      it[name] = "Gloves"
      it[description] = "Leather"
      it[quantity] = 20
      it[organizationId] = org1Id
    } get InventoryItems.id).value
    val flowerPotsId = (InventoryItems.insert {
      it[name] = "Flower Pots"
      it[description] = "Terracotta"
      it[quantity] = 50
      it[organizationId] = org2Id
    } get InventoryItems.id).value
    val soilId = (InventoryItems.insert {
      it[name] = "Soil"
      it[description] = "10 lb bag"
      it[quantity] = 100
      it[organizationId] = org2Id
    } get InventoryItems.id).value
    val wateringCanId = (InventoryItems.insert {
      it[name] = "Watering Can"
      it[description] = "2 gallon"
      it[quantity] = 15
      it[organizationId] = org2Id
    } get InventoryItems.id).value
    val pruningShearsId = (InventoryItems.insert {
      it[name] = "Pruning Shears"
      it[description] = "Bypass"
      it[quantity] = 12
      it[organizationId] = org2Id
    } get InventoryItems.id).value
    val trowelId = (InventoryItems.insert {
      it[name] = "Trowel"
      it[description] = "Hand trowel"
      it[quantity] = 25
      it[organizationId] = org2Id
    } get InventoryItems.id).value

    // Create Events
    val today = LocalDate.now()
    val lawnMaintenanceEventId = Events.insert {
      it[title] = "Lawn Maintenance"
      it[startsAt] = eventInstant(today.plusDays(1), LocalTime.of(9, 0), "America/New_York")
      it[timezone] = "America/New_York"
      it[durationMinutes] = 120
      it[location] = "123 Main St"
      it[description] = "Mow, edge, and fertilize"
      it[customerId] = cust1Id
      it[organizationId] = org1Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    } get Events.id
    val hedgeTrimmingEventId = Events.insert {
      it[title] = "Hedge Trimming"
      it[startsAt] = eventInstant(today.plusDays(2), LocalTime.of(10, 0), "America/New_York")
      it[timezone] = "America/New_York"
      it[durationMinutes] = 60
      it[location] = "456 Business Ave"
      it[description] = "Trim all hedges"
      it[customerId] = cust2Id
      it[organizationId] = org1Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    } get Events.id
    val fallCleanupEventId = Events.insert {
      it[title] = "Fall Cleanup"
      it[startsAt] = eventInstant(today.minusDays(1), LocalTime.of(8, 0), "America/New_York")
      it[timezone] = "America/New_York"
      it[durationMinutes] = 90
      it[location] = "123 Main St"
      it[description] = "Rake leaves and clean up debris"
      it[customerId] = cust1Id
      it[organizationId] = org1Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    } get Events.id
    val plantingFlowersEventId = Events.insert {
      it[title] = "Planting new flowers"
      it[startsAt] = eventInstant(today.plusDays(5), LocalTime.of(9, 0), "Europe/Berlin")
      it[timezone] = "Europe/Berlin"
      it[durationMinutes] = 180
      it[location] = "789 Park Rd"
      it[description] = "Plant seasonal flowers"
      it[customerId] = cust3Id
      it[organizationId] = org2Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    } get Events.id
    val rooftopGardenEventId = Events.insert {
      it[title] = "Rooftop Garden Maintenance"
      it[startsAt] = eventInstant(today.minusDays(3), LocalTime.of(11, 0), "Europe/Berlin")
      it[timezone] = "Europe/Berlin"
      it[durationMinutes] = 45
      it[location] = "321 High St"
      it[description] = "Watering and pruning"
      it[customerId] = cust4Id
      it[organizationId] = org2Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    } get Events.id
    val soilDeliveryEventId = Events.insert {
      it[title] = "Soil delivery"
      it[startsAt] = eventInstant(today.plusDays(7), LocalTime.of(14, 0), "Pacific/Auckland")
      it[timezone] = "Pacific/Auckland"
      it[durationMinutes] = 30
      it[location] = "789 Park Rd"
      it[description] = "Deliver 20 bags of soil"
      it[customerId] = cust3Id
      it[organizationId] = org2Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    } get Events.id

    // Events that share a day, so the "Other events on {date}" panel has
    // something to show.
    //
    // **Every event seeded above is alone on its day**, so the panel was
    // always empty: the one screen it exists on had nothing to list, and the
    // feature could not be checked by hand at all. Two clusters, one per
    // organization, so the organization scoping is visible too -- signing in as
    // alice (Green Vistas) and as charlie (Urban Bloom) gives different lists
    // for the same day.
    //
    // **On `today` rather than a fixed date**, because the create form
    // defaults its date to today (`CreateEventForm.tsx:47`), which is where a
    // user meets the panel first.
    //
    // The times are deliberately spread and one event carries no location, so
    // the panel's three visible behaviours are all exercisable at a glance:
    // the sort by time, the duration, and the location that is only rendered
    // when there is one.
    val morningIrrigationEventId = Events.insert {
      it[title] = "Morning Irrigation Check"
      it[startsAt] = eventInstant(today, LocalTime.of(7, 30), "America/New_York")
      it[timezone] = "America/New_York"
      it[durationMinutes] = 45
      it[location] = "123 Main St"
      it[description] = "Check every sprinkler head"
      it[customerId] = cust1Id
      it[organizationId] = org1Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    } get Events.id
    val fenceRepairEventId = Events.insert {
      it[title] = "Fence Repair"
      it[startsAt] = eventInstant(today, LocalTime.of(10, 0), "America/New_York")
      it[timezone] = "America/New_York"
      it[durationMinutes] = 120
      it[location] = "456 Business Ave"
      it[description] = "Replace two broken panels"
      it[customerId] = cust2Id
      it[organizationId] = org1Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    } get Events.id
    val mulchDeliveryEventId = Events.insert {
      it[title] = "Mulch Delivery"
      it[startsAt] = eventInstant(today, LocalTime.of(13, 15), "America/New_York")
      it[timezone] = "America/New_York"
      it[durationMinutes] = 30
      // **No location, on purpose.** The panel renders the location only when
      // the event has one (`OtherEventsPanel.tsx:88`), and without an event
      // that lacks it the branch is never exercised by hand.
      it[description] = "Drop eight bags at the depot"
      it[customerId] = cust2Id
      it[organizationId] = org1Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    } get Events.id
    val gutterCleaningEventId = Events.insert {
      it[title] = "Gutter Cleaning"
      it[startsAt] = eventInstant(today, LocalTime.of(16, 0), "America/New_York")
      it[timezone] = "America/New_York"
      it[durationMinutes] = 90
      it[location] = "123 Main St"
      it[description] = "Clear the downspouts"
      it[customerId] = cust1Id
      it[organizationId] = org1Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    } get Events.id
    val planterMaintenanceEventId = Events.insert {
      it[title] = "Planter Maintenance"
      it[startsAt] = eventInstant(today, LocalTime.of(9, 0), "Europe/Berlin")
      it[timezone] = "Europe/Berlin"
      it[durationMinutes] = 60
      it[location] = "789 Park Rd"
      it[description] = "Weed and re-stake the planters"
      it[customerId] = cust3Id
      it[organizationId] = org2Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    } get Events.id
    val greenhouseRepottingEventId = Events.insert {
      it[title] = "Greenhouse Repotting"
      it[startsAt] = eventInstant(today, LocalTime.of(14, 0), "Europe/Berlin")
      it[timezone] = "Europe/Berlin"
      it[durationMinutes] = 120
      it[location] = "321 High St"
      it[description] = "Move the seedlings into larger pots"
      it[customerId] = cust4Id
      it[organizationId] = org2Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    } get Events.id

    // Associate inventory with Green Vistas and Urban Bloom events so inventory
    // details and event views have realistic usage to display.
    EventInventory.insert {
      it[eventId] = lawnMaintenanceEventId
      it[inventoryItemId] = lawnMowerId
      it[quantity] = 1
    }
    EventInventory.insert {
      it[eventId] = lawnMaintenanceEventId
      it[inventoryItemId] = glovesId
      it[quantity] = 2
    }
    EventInventory.insert {
      it[eventId] = hedgeTrimmingEventId
      it[inventoryItemId] = hedgeTrimmerId
      it[quantity] = 1
    }
    EventInventory.insert {
      it[eventId] = hedgeTrimmingEventId
      it[inventoryItemId] = glovesId
      it[quantity] = 2
    }
    EventInventory.insert {
      it[eventId] = fallCleanupEventId
      it[inventoryItemId] = rakeId
      it[quantity] = 2
    }
    EventInventory.insert {
      it[eventId] = fallCleanupEventId
      it[inventoryItemId] = glovesId
      it[quantity] = 2
    }
    EventInventory.insert {
      it[eventId] = morningIrrigationEventId
      it[inventoryItemId] = shovelId
      it[quantity] = 1
    }
    EventInventory.insert {
      it[eventId] = fenceRepairEventId
      it[inventoryItemId] = shovelId
      it[quantity] = 2
    }
    EventInventory.insert {
      it[eventId] = fenceRepairEventId
      it[inventoryItemId] = glovesId
      it[quantity] = 2
    }
    EventInventory.insert {
      it[eventId] = mulchDeliveryEventId
      it[inventoryItemId] = shovelId
      it[quantity] = 1
    }
    EventInventory.insert {
      it[eventId] = gutterCleaningEventId
      it[inventoryItemId] = rakeId
      it[quantity] = 1
    }
    EventInventory.insert {
      it[eventId] = gutterCleaningEventId
      it[inventoryItemId] = glovesId
      it[quantity] = 2
    }
    EventInventory.insert {
      it[eventId] = plantingFlowersEventId
      it[inventoryItemId] = flowerPotsId
      it[quantity] = 12
    }
    EventInventory.insert {
      it[eventId] = plantingFlowersEventId
      it[inventoryItemId] = soilId
      it[quantity] = 5
    }
    EventInventory.insert {
      it[eventId] = plantingFlowersEventId
      it[inventoryItemId] = trowelId
      it[quantity] = 3
    }
    EventInventory.insert {
      it[eventId] = rooftopGardenEventId
      it[inventoryItemId] = wateringCanId
      it[quantity] = 1
    }
    EventInventory.insert {
      it[eventId] = rooftopGardenEventId
      it[inventoryItemId] = pruningShearsId
      it[quantity] = 2
    }
    EventInventory.insert {
      it[eventId] = soilDeliveryEventId
      it[inventoryItemId] = soilId
      it[quantity] = 20
    }
    EventInventory.insert {
      it[eventId] = planterMaintenanceEventId
      it[inventoryItemId] = wateringCanId
      it[quantity] = 1
    }
    EventInventory.insert {
      it[eventId] = planterMaintenanceEventId
      it[inventoryItemId] = trowelId
      it[quantity] = 2
    }
    EventInventory.insert {
      it[eventId] = greenhouseRepottingEventId
      it[inventoryItemId] = flowerPotsId
      it[quantity] = 8
    }
    EventInventory.insert {
      it[eventId] = greenhouseRepottingEventId
      it[inventoryItemId] = soilId
      it[quantity] = 4
    }
    EventInventory.insert {
      it[eventId] = greenhouseRepottingEventId
      it[inventoryItemId] = trowelId
      it[quantity] = 2
    }

    // Create 14 more events to test pagination
    for (i in 1..14) {
      val evtDate = if (i % 2 == 0) today.plusDays(i.toLong()) else today.minusDays(i.toLong())
      Events.insert {
        it[title] = "Event $i"
        it[startsAt] = eventInstant(evtDate, LocalTime.of(12, 0), if (i % 2 == 0) "America/New_York" else "Europe/Berlin")
        it[timezone] = if (i % 2 == 0) "America/New_York" else "Europe/Berlin"
        it[durationMinutes] = 60
        it[location] = "Location $i"
        it[description] = "Description for event $i"
        it[customerId] = if (i % 2 == 0) cust1Id else cust3Id
        it[organizationId] = if (i % 2 == 0) org1Id else org2Id
        it[openInvitation] = false
        it[numberOfStaffNeeded] = 0
      }
    }

    // Scenario-focused seed data for recent manual testing (soft delete/restore,
    // RSVP states, and inventory associations/usage counts). Uses a clearly
    // named TEST_ORG_* org so populateTestData cleanup remains idempotent.
    val scenarioOrgId = (Organizations.insert {
      it[name] = "${testOrgPrefix}Scenario Lab (Soft Delete, RSVP, Usage)"
      it[contactInformation] = "scenario-lab@example.test"
      it[Organizations.timezone] = "UTC"
    } get Organizations.id).value

    val scenarioManagerId = (Users.insert {
      it[username] = "scenario.manager"
      it[displayName] = "Scenario Manager (Org Admin)"
      it[email] = "scenario.manager@scenariolab.test"
      it[passwordHash] = seededPasswordHash
    } get Users.id).value
    val scenarioStaffId = (Users.insert {
      it[username] = "scenario.staff"
      it[displayName] = "Scenario Staff"
      it[email] = "scenario.staff@scenariolab.test"
      it[passwordHash] = seededPasswordHash
    } get Users.id).value
    val scenarioDeactivatedStaffId = (Users.insert {
      it[username] = "scenario.deactivated"
      it[displayName] = "Scenario Deactivated Staff"
      it[email] = "scenario.deactivated@scenariolab.test"
      it[passwordHash] = seededPasswordHash
      it[Users.deletedAt] = OffsetDateTime.now(ZoneOffset.UTC)
    } get Users.id).value

    UserOrganizations.insert {
      it[userId] = scenarioManagerId
      it[organizationId] = scenarioOrgId
    }
    UserOrganizations.insert {
      it[userId] = scenarioStaffId
      it[organizationId] = scenarioOrgId
    }
    UserOrganizations.insert {
      it[userId] = scenarioDeactivatedStaffId
      it[organizationId] = scenarioOrgId
    }

    UserRoles.insert {
      it[userId] = scenarioManagerId
      it[roleId] = organizerRoleId
    }
    UserRoles.insert {
      it[userId] = scenarioStaffId
      it[roleId] = staffRoleId
    }
    UserRoles.insert {
      it[userId] = scenarioDeactivatedStaffId
      it[roleId] = staffRoleId
    }

    val scenarioActiveCustomerId = Customers.insert {
      it[name] = "Scenario Active Customer (Today/Upcoming/All)"
      it[phone] = "555-7001"
      it[address] = "100 Scenario Ave"
      it[notes] = "Active customer for 10.20 details and event filtering"
      it[organizationId] = scenarioOrgId
    } get Customers.id
    val scenarioDeactivatedCustomerId = Customers.insert {
      it[name] = "Scenario Deactivated Customer (Restore/History)"
      it[phone] = "555-7002"
      it[address] = "200 Scenario Ave"
      it[notes] = "Deactivated customer for 10.19 restore and historical event resolution"
      it[organizationId] = scenarioOrgId
      it[Customers.deletedAt] = OffsetDateTime.now(ZoneOffset.UTC)
    } get Customers.id

    val scenarioInventoryUsedId = (InventoryItems.insert {
      it[name] = "Scenario Inventory (Used on Events)"
      it[description] = "Has event associations and usage records for 10.21"
      it[quantity] = 12
      it[organizationId] = scenarioOrgId
    } get InventoryItems.id).value
    val scenarioInventoryAssociatedId = (InventoryItems.insert {
      it[name] = "Scenario Inventory (Associated Only)"
      it[description] = "Associated to events for eventCount display"
      it[quantity] = 4
      it[organizationId] = scenarioOrgId
    } get InventoryItems.id).value
    val scenarioInventoryUnusedId = (InventoryItems.insert {
      it[name] = "Scenario Inventory (Unused)"
      it[description] = "Control item with no associations"
      it[quantity] = 7
      it[organizationId] = scenarioOrgId
    } get InventoryItems.id).value

    val scenarioTodayEventId = Events.insert {
      it[title] = "Scenario Today Event (RSVP Mix)"
      it[startsAt] = eventInstant(today, LocalTime.of(15, 0), "UTC")
      it[timezone] = "UTC"
      it[durationMinutes] = 60
      it[location] = "Scenario Site Today"
      it[description] = "Mixed RSVP states for 10.17/10.26 testing"
      it[customerId] = scenarioActiveCustomerId
      it[organizationId] = scenarioOrgId
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 2
    } get Events.id
    val scenarioUpcomingEventId = Events.insert {
      it[title] = "Scenario Upcoming Event (Customer Filter)"
      it[startsAt] = eventInstant(today.plusDays(3), LocalTime.of(9, 30), "UTC")
      it[timezone] = "UTC"
      it[durationMinutes] = 90
      it[location] = "Scenario Site Upcoming"
      it[description] = "Upcoming event for active customer details/filtering"
      it[customerId] = scenarioActiveCustomerId
      it[organizationId] = scenarioOrgId
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 1
    } get Events.id
    val scenarioPastEventId = Events.insert {
      it[title] = "Scenario Past Event (History)"
      it[startsAt] = eventInstant(today.minusDays(5), LocalTime.of(11, 0), "UTC")
      it[timezone] = "UTC"
      it[durationMinutes] = 120
      it[location] = "Scenario Site Past"
      it[description] = "Past event for active customer history"
      it[customerId] = scenarioActiveCustomerId
      it[organizationId] = scenarioOrgId
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 1
    } get Events.id
    val scenarioDeactivatedCustomerEventId = Events.insert {
      it[title] = "Scenario Event for Deactivated Customer"
      it[startsAt] = eventInstant(today.plusDays(1), LocalTime.of(13, 0), "UTC")
      it[timezone] = "UTC"
      it[durationMinutes] = 60
      it[location] = "Scenario Site Deactivated Customer"
      it[description] = "Historical event should remain resolvable while customer is deactivated"
      it[customerId] = scenarioDeactivatedCustomerId
      it[organizationId] = scenarioOrgId
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 1
    } get Events.id

    EventInventory.insert {
      it[eventId] = scenarioTodayEventId
      it[inventoryItemId] = scenarioInventoryUsedId
      it[quantity] = 2
    }
    EventInventory.insert {
      it[eventId] = scenarioUpcomingEventId
      it[inventoryItemId] = scenarioInventoryUsedId
      it[quantity] = 1
    }
    EventInventory.insert {
      it[eventId] = scenarioPastEventId
      it[inventoryItemId] = scenarioInventoryAssociatedId
      it[quantity] = 3
    }
    EventInventory.insert {
      it[eventId] = scenarioDeactivatedCustomerEventId
      it[inventoryItemId] = scenarioInventoryAssociatedId
      it[quantity] = 1
    }

    InventoryUsage.insert {
      it[inventoryId] = scenarioInventoryUsedId
      it[eventId] = scenarioTodayEventId
      it[quantityUsed] = 2
      it[usageDate] = today
    }
    InventoryUsage.insert {
      it[inventoryId] = scenarioInventoryUsedId
      it[eventId] = scenarioPastEventId
      it[quantityUsed] = 1
      it[usageDate] = today.minusDays(5)
    }

    Rsvps.insert {
      it[eventId] = scenarioTodayEventId
      it[userId] = scenarioManagerId
      it[availability] = "accepted"
    }
    Rsvps.insert {
      it[eventId] = scenarioTodayEventId
      it[userId] = scenarioStaffId
      it[availability] = "tentative"
    }
    Rsvps.insert {
      it[eventId] = scenarioTodayEventId
      it[userId] = scenarioDeactivatedStaffId
      it[availability] = "needs_action"
    }
    Rsvps.insert {
      it[eventId] = scenarioUpcomingEventId
      it[userId] = scenarioStaffId
      it[availability] = "declined"
    }
    Rsvps.insert {
      it[eventId] = scenarioUpcomingEventId
      it[userId] = scenarioManagerId
      it[availability] = "needs_action"
    }
    Rsvps.insert {
      it[eventId] = scenarioDeactivatedCustomerEventId
      it[userId] = scenarioManagerId
      it[availability] = "accepted"
    }

    // Pagination-focused seed data: enough active rows in one org/scope to exceed
    // the default server page size (25) for common lists.
    val paginationOrgId = (Organizations.insert {
      it[name] = "${testOrgPrefix}Pagination Lab (30+ Customers/Inventory/Users)"
      it[contactInformation] = "pagination-lab@example.test"
      it[Organizations.timezone] = "UTC"
    } get Organizations.id).value

    val paginationManagerId = (Users.insert {
      it[username] = "pagination.manager"
      it[displayName] = "Pagination Manager"
      it[email] = "pagination.manager@paginationlab.test"
      it[passwordHash] = seededPasswordHash
    } get Users.id).value

    UserOrganizations.insert {
      it[userId] = paginationManagerId
      it[organizationId] = paginationOrgId
    }
    UserRoles.insert {
      it[userId] = paginationManagerId
      it[roleId] = organizerRoleId
    }

    for (i in 1..30) {
      val n = i.toString().padStart(2, '0')
      Customers.insert {
        it[name] = "Pagination Customer $n"
        it[phone] = "555-8${n}00"
        it[address] = "${100 + i} Pagination St"
        it[notes] = "Seeded customer $n for pagination testing"
        it[organizationId] = paginationOrgId
      }
    }

    for (i in 1..30) {
      val n = i.toString().padStart(2, '0')
      InventoryItems.insert {
        it[name] = "Pagination Inventory Item $n"
        it[description] = "Seeded inventory item $n for pagination testing"
        it[quantity] = i
        it[organizationId] = paginationOrgId
      }
    }

    for (i in 1..29) {
      val n = i.toString().padStart(2, '0')
      val paginationStaffId = (Users.insert {
        it[username] = "pagination.staff$n"
        it[displayName] = "Pagination Staff $n"
        it[email] = "pagination.staff$n@paginationlab.test"
        it[passwordHash] = seededPasswordHash
      } get Users.id).value
      UserOrganizations.insert {
        it[userId] = paginationStaffId
        it[organizationId] = paginationOrgId
      }
      UserRoles.insert {
        it[userId] = paginationStaffId
        it[roleId] = staffRoleId
      }
    }
  }
}
