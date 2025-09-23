package alphainterplanetary.teven.service.user

import alphainterplanetary.teven.api.model.role.RoleResponse
import alphainterplanetary.teven.api.model.user.CreateUserRequest
import alphainterplanetary.teven.api.model.user.UpdateUserRequest
import alphainterplanetary.teven.core.Constants
import alphainterplanetary.teven.core.security.AuthorizationException
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.core.security.UserPermissions
import alphainterplanetary.teven.core.service.PermissionService
import alphainterplanetary.teven.core.service.RoleService
import alphainterplanetary.teven.core.user.User
import alphainterplanetary.teven.data.organization.OrganizationDao
import alphainterplanetary.teven.data.user.UserDao
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows

class UserServiceImplTest {

  private val userDao: UserDao = mockk()
  private val organizationDao: OrganizationDao = mockk()
  private val roleService: RoleService = mockk()
  private val permissionService: PermissionService = mockk()

  private val userService =
    UserServiceImpl(userDao, organizationDao, roleService, permissionService)

  @Test
  fun `createUser should create user when caller has permission`() = runBlocking {
    val createUserRequest = CreateUserRequest(
      username = "testuser",
      email = "test@test.com",
      password = "password",
      displayName = "Test User",
      roles = listOf("User"),
      organizationId = 1 // Dummy organizationId for test
    )
    val callerId = 1
    val newUser = User(
      userId = 2,
      username = "testuser",
      email = "test@test.com",
      passwordHash = "password",
      displayName = "Test User"
    )
    val roleResponse = mockk<RoleResponse>()

    coEvery { permissionService.getPermissions(callerId) } returns UserPermissions(
      roles = listOf("Admin"),
      permissions = listOf(Permission.ASSIGN_ROLES_ORGANIZATION)
    )
    coEvery { userDao.createUser(createUserRequest) } returns newUser
    every { roleResponse.roleId } returns 1
    every { roleResponse.roleName } returns "User"
    coEvery { roleService.getRoleByName("User") } returns roleResponse
    coEvery { roleService.assignRoleToUser(2, 1) } returns true
    coEvery { roleService.getRolesForUser(2) } returns emptyList()
    coEvery { userDao.getOrganizationForUser(2) } returns null

    val result = userService.createUser(createUserRequest, callerId)

    assert(result.username == "testuser")
  }

  @Test
  fun `createUser should throw exception when creating superadmin without permission`() {
    runBlocking {
      val createUserRequest = CreateUserRequest(
        username = "testuser",
        email = "test@test.com",
        password = "password",
        displayName = "Test User",
        roles = listOf(Constants.ROLE_SUPERADMIN)
      )
      val callerId = 1

      coEvery { permissionService.getPermissions(callerId) } returns UserPermissions(
        roles = listOf("Admin"),
        permissions = listOf(Permission.ASSIGN_ROLES_ORGANIZATION)
      )

      assertThrows<AuthorizationException> {
        userService.createUser(createUserRequest, callerId)
      }
    }
  }

  @Test
  fun `updateUser should throw exception when assigning superadmin without permission`() {
    return runBlocking {
      val updateUserRequest = UpdateUserRequest(
        roles = listOf(Constants.ROLE_SUPERADMIN)
      )
      val callerId = 1
      val userId = 2

      coEvery { permissionService.getPermissions(callerId) } returns UserPermissions(
        roles = listOf("Admin"),
        permissions = listOf(Permission.ASSIGN_ROLES_ORGANIZATION)
      )
      coEvery { roleService.getRolesForUser(userId) } returns emptyList()

      assertThrows<AuthorizationException> {
        userService.updateUser(userId, updateUserRequest, callerId)
      }
    }
  }

  @Test
  fun `getAllUsers should throw exception when no permission`() {
    runBlocking {
      val callerId = 1

      coEvery { permissionService.getPermissions(callerId) } returns UserPermissions(
        roles = listOf("User"),
        permissions = emptyList()
      )

      assertThrows<SecurityException> {
        userService.getAllUsers(callerId)
      }
    }
  }
}
