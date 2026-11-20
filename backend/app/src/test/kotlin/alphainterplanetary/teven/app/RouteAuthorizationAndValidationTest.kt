package alphainterplanetary.teven.app

import alphainterplanetary.teven.api.model.common.PaginatedResponse
import alphainterplanetary.teven.api.model.common.success
import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import alphainterplanetary.teven.app.invitation.invitationRoutes
import alphainterplanetary.teven.app.invitation.publicInvitationRoutes
import alphainterplanetary.teven.app.organization.organizationRoutes
import alphainterplanetary.teven.auth.withPermission
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.core.security.UserPermissions
import alphainterplanetary.teven.service.invitation.InvitationService
import alphainterplanetary.teven.service.organization.OrganizationService
import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.put
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpStatusCode
import io.ktor.server.auth.authenticate
import io.ktor.server.response.respond
import io.ktor.server.routing.post
import io.ktor.server.routing.route
import io.ktor.server.testing.testApplication
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Test
import org.koin.dsl.module
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class RouteAuthorizationAndValidationTest {
  @Test
  fun `authenticated invitation create rejects malformed expiresAt with 400 envelope before service call`() = testApplication {
    val invitationService = mockk<InvitationService>(relaxed = true)
    val authContext = AuthContext(userId = 7, organizationId = 3, permissions = emptySet())

    routeTestApplication(
      authContext = authContext,
      koinModules = listOf(module { single { invitationService } }),
      configureRouting = {
        authenticate("auth-jwt") {
          invitationRoutes()
        }
      },
    ) { client ->
      val response = client.post("/api/invitations") {
        asTestUser()
        jsonBody(
          """
          {
            "organizationId": null,
            "roleId": 2,
            "expiresAt": "not-a-date",
            "note": "hello"
          }
          """.trimIndent()
        )
      }

      assertEquals(HttpStatusCode.BadRequest, response.status)
      val body = Json.parseToJsonElement(response.bodyAsText()).jsonObject
      assertFalse(body["success"]!!.jsonPrimitive.boolean)
      assertEquals("Invalid invitation expiry", body["error"]!!.jsonObject["message"]!!.jsonPrimitive.content)
      coVerify(exactly = 0) { invitationService.generateInvitation(any(), any(), any(), any(), any()) }
    }
  }

  @Test
  fun `withPermission denies request with 403 envelope and does not execute handler`() = testApplication {
    var handlerExecuted = false
    val authContext = AuthContext(userId = 11, organizationId = 5, permissions = emptySet())
    val permissionService = TestPermissionService(
      permissionsByUserId = mapOf(
        11 to UserPermissions(
          roles = listOf("Staff"),
          permissions = emptyList(),
        )
      )
    )

    routeTestApplication(
      authContext = authContext,
      permissionService = permissionService,
      configureRouting = {
        route("/api/test") {
          withPermission(Permission.MANAGE_USERS_GLOBAL) {
            post("/protected") {
              handlerExecuted = true
              call.respond(HttpStatusCode.OK, success("ok"))
            }
          }
        }
      },
    ) { client ->
      val response = client.post("/api/test/protected") {
        asTestUser()
      }

      assertEquals(HttpStatusCode.Forbidden, response.status)
      val body = Json.parseToJsonElement(response.bodyAsText()).jsonObject
      assertFalse(body["success"]!!.jsonPrimitive.boolean)
      assertEquals(
        "User does not have the required permission",
        body["error"]!!.jsonObject["message"]!!.jsonPrimitive.content,
      )
      assertFalse(handlerExecuted, "Denied request must not execute the route handler")
    }
  }

  @Test
  fun `withPermission allows request when any required permission matches and returns success envelope`() = testApplication {
    var handlerExecuted = false
    val authContext = AuthContext(
      userId = 12,
      organizationId = 5,
      permissions = setOf(Permission.VIEW_USERS_ORGANIZATION),
    )
    val permissionService = TestPermissionService(
      permissionsByUserId = mapOf(
        12 to UserPermissions(
          roles = listOf("Organizer"),
          permissions = listOf(Permission.VIEW_USERS_ORGANIZATION),
        )
      )
    )

    routeTestApplication(
      authContext = authContext,
      permissionService = permissionService,
      configureRouting = {
        route("/api/test") {
          withPermission(Permission.VIEW_USERS_GLOBAL, Permission.VIEW_USERS_ORGANIZATION) {
            post("/protected") {
              handlerExecuted = true
              call.respond(HttpStatusCode.OK, success(mapOf("value" to "ok")))
            }
          }
        }
      },
    ) { client ->
      val response = client.post("/api/test/protected") {
        asTestUser()
      }

      assertEquals(HttpStatusCode.OK, response.status)
      val body = Json.parseToJsonElement(response.bodyAsText()).jsonObject
      assertTrue(body["success"]!!.jsonPrimitive.boolean)
      assertEquals("ok", body["data"]!!.jsonObject["value"]!!.jsonPrimitive.content)
      assertTrue(handlerExecuted, "Allowed request must execute the route handler")
    }
  }

  @Test
  fun `public invitation validation returns 400 envelope when token is missing`() = testApplication {
    val invitationService = mockk<InvitationService>(relaxed = true)

    routeTestApplication(
      koinModules = listOf(module { single { invitationService } }),
      configureRouting = {
        publicInvitationRoutes()
      },
    ) { client ->
      val response = client.get("/api/invitations/validate")

      assertEquals(HttpStatusCode.BadRequest, response.status)
      val body = Json.parseToJsonElement(response.bodyAsText()).jsonObject
      assertFalse(body["success"]!!.jsonPrimitive.boolean)
      assertEquals("Invitation token is missing", body["error"]!!.jsonObject["message"]!!.jsonPrimitive.content)
      coVerify(exactly = 0) { invitationService.validateInvitation(any()) }
    }
  }

  @Test
  fun `organization list denies MANAGE_ORGANIZATION without global org permissions`() = testApplication {
    val organizationService = mockk<OrganizationService>(relaxed = true)
    val authContext = AuthContext(userId = 21, organizationId = 5, permissions = setOf(Permission.MANAGE_ORGANIZATION))
    val permissionService = TestPermissionService(
      permissionsByUserId = mapOf(
        21 to UserPermissions(
          roles = listOf("Organizer"),
          permissions = listOf(Permission.MANAGE_ORGANIZATION),
        )
      )
    )

    routeTestApplication(
      authContext = authContext,
      permissionService = permissionService,
      koinModules = listOf(module { single { organizationService } }),
      configureRouting = { organizationRoutes() },
    ) { client ->
      val response = client.get("/api/organizations") { asTestUser() }

      assertEquals(HttpStatusCode.Forbidden, response.status)
      val body = Json.parseToJsonElement(response.bodyAsText()).jsonObject
      assertFalse(body["success"]!!.jsonPrimitive.boolean)
      coVerify(exactly = 0) { organizationService.getOrganizations(any(), any(), any(), any(), any()) }
    }
  }

  @Test
  fun `organization own-org read and update allow MANAGE_ORGANIZATION but create and delete are denied`() = testApplication {
    val organizationService = mockk<OrganizationService>()
    val authContext = AuthContext(userId = 22, organizationId = 5, permissions = setOf(Permission.MANAGE_ORGANIZATION))
    val permissionService = TestPermissionService(
      permissionsByUserId = mapOf(
        22 to UserPermissions(
          roles = listOf("Organizer"),
          permissions = listOf(Permission.MANAGE_ORGANIZATION),
        )
      )
    )
    val ownOrg = OrganizationResponse(
      organizationId = 5,
      name = "Own Org",
      contactInformation = "contact@example.com",
      timezone = "UTC",
    )
    coEvery { organizationService.getOrganizationById(5, 22) } returns ownOrg
    coEvery { organizationService.updateOrganization(5, any(), 22) } returns ownOrg

    routeTestApplication(
      authContext = authContext,
      permissionService = permissionService,
      koinModules = listOf(module { single { organizationService } }),
      configureRouting = { organizationRoutes() },
    ) { client ->
      val getResponse = client.get("/api/organizations/5") { asTestUser() }
      assertEquals(HttpStatusCode.OK, getResponse.status)
      val getBody = Json.parseToJsonElement(getResponse.bodyAsText()).jsonObject
      assertTrue(getBody["success"]!!.jsonPrimitive.boolean)

      val putResponse = client.put("/api/organizations/5") {
        asTestUser()
        jsonBody(
          """
          {
            "name": "Own Org",
            "contactInformation": "contact@example.com",
            "timezone": "UTC"
          }
          """.trimIndent()
        )
      }
      assertEquals(HttpStatusCode.OK, putResponse.status)

      val postResponse = client.post("/api/organizations") {
        asTestUser()
        jsonBody(
          """
          {
            "name": "New Org",
            "contactInformation": "new@example.com",
            "timezone": "UTC"
          }
          """.trimIndent()
        )
      }
      assertEquals(HttpStatusCode.Forbidden, postResponse.status)

      val deleteResponse = client.delete("/api/organizations/5") { asTestUser() }
      assertEquals(HttpStatusCode.Forbidden, deleteResponse.status)

      coVerify(exactly = 1) { organizationService.getOrganizationById(5, 22) }
      coVerify(exactly = 1) { organizationService.updateOrganization(5, any(), 22) }
      coVerify(exactly = 0) { organizationService.createOrganization(any()) }
      coVerify(exactly = 0) { organizationService.deleteOrganization(any()) }
    }
  }
}
