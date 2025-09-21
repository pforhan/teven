package alphainterplanetary.teven.data

import alphainterplanetary.teven.data.customer.Customers
import alphainterplanetary.teven.data.event.EventInventory
import alphainterplanetary.teven.data.event.EventStaff
import alphainterplanetary.teven.data.event.Events
import alphainterplanetary.teven.data.event.Rsvps
import alphainterplanetary.teven.data.inventory.InventoryItems
import alphainterplanetary.teven.data.organization.Organizations
import alphainterplanetary.teven.data.user.UserOrganizations
import alphainterplanetary.teven.data.user.Users
import org.jetbrains.exposed.v1.core.eq
import org.jetbrains.exposed.v1.core.inList
import org.jetbrains.exposed.v1.core.like
import org.jetbrains.exposed.v1.jdbc.deleteWhere
import org.jetbrains.exposed.v1.jdbc.insert
import org.jetbrains.exposed.v1.jdbc.selectAll
import java.time.LocalDate

suspend fun populateTestData() {
  dbQuery {
    val testOrgPrefix = "TEST_ORG_"
    val testUserEmailSuffixes = listOf("@greenvistas.com", "@urbanbloom.com")

    // Find and delete existing test organizations and their associated data
    val testOrganizationIds = Organizations.selectAll()
      .where { Organizations.name like "$testOrgPrefix%" }
      .map { it[Organizations.id].value }

    testOrganizationIds.forEach { orgId ->
      // Delete dependent data first
      val eventIds = Events.selectAll()
        .where { Events.organizationId eq orgId }.map { it[Events.id] }
      if (eventIds.isNotEmpty()) {
        Rsvps.deleteWhere { Rsvps.eventId inList eventIds }
        EventInventory.deleteWhere { EventInventory.eventId inList eventIds }
        EventStaff.deleteWhere { EventStaff.eventId inList eventIds }
      }
      Events.deleteWhere { Events.organizationId eq orgId }
      Customers.deleteWhere { Customers.organizationId eq orgId }
      InventoryItems.deleteWhere { InventoryItems.organizationId eq orgId }
      UserOrganizations.deleteWhere { UserOrganizations.organizationId eq orgId }
      // Note: Users themselves are deleted based on email suffix, not organizationId directly
      // because a user might belong to multiple organizations.
      // We assume test user emails are unique to test data.
    }

    // Delete users with test email suffixes
    testUserEmailSuffixes.forEach { suffix ->
      Users.deleteWhere { Users.email like "%${suffix}" }
    }

    // Finally, delete the test organizations
    Organizations.deleteWhere { Organizations.name like "$testOrgPrefix%" }

    // Create Organizations
    val org1Id = (Organizations.insert {
      it[name] = "${testOrgPrefix}Green Vistas Landscaping"
      it[contactInformation] = "contact@greenvistas.com"
    } get Organizations.id).value
    val org2Id = (Organizations.insert {
      it[name] = "${testOrgPrefix}Urban Bloom Gardens"
      it[contactInformation] = "info@urbanbloom.com"
    } get Organizations.id).value

    // Create Users
    val user1Id = (Users.insert {
      it[username] = "alice"
      it[displayName] = "Alice"
      it[email] = "alice@greenvistas.com"
      it[passwordHash] = "password"
    } get Users.id).value
    val user2Id = (Users.insert {
      it[username] = "bob"
      it[displayName] = "Bob"
      it[email] = "bob@greenvistas.com"
      it[passwordHash] = "password"
    } get Users.id).value
    val user3Id = (Users.insert {
      it[username] = "charlie"
      it[displayName] = "Charlie"
      it[email] = "charlie@urbanbloom.com"
      it[passwordHash] = "password"
    } get Users.id).value
    val user4Id = (Users.insert {
      it[username] = "diana"
      it[displayName] = "Diana"
      it[email] = "diana@urbanbloom.com"
      it[passwordHash] = "password"
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
    InventoryItems.insert {
      it[name] = "Lawn Mower"
      it[description] = "Gas-powered"
      it[quantity] = 5
      it[organizationId] = org1Id
    }
    InventoryItems.insert {
      it[name] = "Hedge Trimmer"
      it[description] = "Electric"
      it[quantity] = 3
      it[organizationId] = org1Id
    }
    InventoryItems.insert {
      it[name] = "Shovel"
      it[description] = "Round point"
      it[quantity] = 10
      it[organizationId] = org1Id
    }
    InventoryItems.insert {
      it[name] = "Rake"
      it[description] = "Leaf rake"
      it[quantity] = 8
      it[organizationId] = org1Id
    }
    InventoryItems.insert {
      it[name] = "Gloves"
      it[description] = "Leather"
      it[quantity] = 20
      it[organizationId] = org1Id
    }
    InventoryItems.insert {
      it[name] = "Flower Pots"
      it[description] = "Terracotta"
      it[quantity] = 50
      it[organizationId] = org2Id
    }
    InventoryItems.insert {
      it[name] = "Soil"
      it[description] = "10 lb bag"
      it[quantity] = 100
      it[organizationId] = org2Id
    }
    InventoryItems.insert {
      it[name] = "Watering Can"
      it[description] = "2 gallon"
      it[quantity] = 15
      it[organizationId] = org2Id
    }
    InventoryItems.insert {
      it[name] = "Pruning Shears"
      it[description] = "Bypass"
      it[quantity] = 12
      it[organizationId] = org2Id
    }
    InventoryItems.insert {
      it[name] = "Trowel"
      it[description] = "Hand trowel"
      it[quantity] = 25
      it[organizationId] = org2Id
    }

    // Create Events
    val today = LocalDate.now()
    Events.insert {
      it[title] = "Lawn Maintenance"
      it[date] = today.plusDays(1).toString()
      it[time] = "09:00"
      it[durationMinutes] = 120
      it[location] = "123 Main St"
      it[description] = "Mow, edge, and fertilize"
      it[customerId] = cust1Id
      it[organizationId] = org1Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    }
    Events.insert {
      it[title] = "Hedge Trimming"
      it[date] = today.plusDays(2).toString()
      it[time] = "10:00"
      it[durationMinutes] = 60
      it[location] = "456 Business Ave"
      it[description] = "Trim all hedges"
      it[customerId] = cust2Id
      it[organizationId] = org1Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    }
    Events.insert {
      it[title] = "Fall Cleanup"
      it[date] = today.minusDays(1).toString()
      it[time] = "08:00"
      it[durationMinutes] = 90
      it[location] = "123 Main St"
      it[description] = "Rake leaves and clean up debris"
      it[customerId] = cust1Id
      it[organizationId] = org1Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    }
    Events.insert {
      it[title] = "Planting new flowers"
      it[date] = today.plusDays(5).toString()
      it[time] = "09:00"
      it[durationMinutes] = 180
      it[location] = "789 Park Rd"
      it[description] = "Plant seasonal flowers"
      it[customerId] = cust3Id
      it[organizationId] = org2Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    }
    Events.insert {
      it[title] = "Rooftop Garden Maintenance"
      it[date] = today.minusDays(3).toString()
      it[time] = "11:00"
      it[durationMinutes] = 45
      it[location] = "321 High St"
      it[description] = "Watering and pruning"
      it[customerId] = cust4Id
      it[organizationId] = org2Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    }
    Events.insert {
      it[title] = "Soil delivery"
      it[date] = today.plusDays(7).toString()
      it[time] = "14:00"
      it[durationMinutes] = 30
      it[location] = "789 Park Rd"
      it[description] = "Deliver 20 bags of soil"
      it[customerId] = cust3Id
      it[organizationId] = org2Id
      it[openInvitation] = false
      it[numberOfStaffNeeded] = 0
    }

    // Create 14 more events to test pagination
    for (i in 1..14) {
      val evtDate = if (i % 2 == 0) today.plusDays(i.toLong()) else today.minusDays(i.toLong())
      Events.insert {
        it[title] = "Event $i"
        it[date] = evtDate.toString()
        it[time] = "12:00"
        it[durationMinutes] = 60
        it[location] = "Location $i"
        it[description] = "Description for event $i"
        it[customerId] = if (i % 2 == 0) cust1Id else cust3Id
        it[organizationId] = if (i % 2 == 0) org1Id else org2Id
        it[openInvitation] = false
        it[numberOfStaffNeeded] = 0
      }
    }
  }
}
