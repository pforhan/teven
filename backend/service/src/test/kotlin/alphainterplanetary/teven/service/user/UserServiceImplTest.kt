package alphainterplanetary.teven.service.user

import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import alphainterplanetary.teven.api.model.role.RoleResponse
import alphainterplanetary.teven.api.model.user.CreateUserRequest
import alphainterplanetary.teven.api.model.user.UpdateUserRequest
import alphainterplanetary.teven.core.Constants
import alphainterplanetary.teven.core.Constants.ROLE_STAFF
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.AuthorizationException
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.core.service.RoleService
import alphainterplanetary.teven.core.user.User
import alphainterplanetary.teven.data.user.UserDao
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows

class UserServiceImplTest {

  private val userDao: UserDao = mockk()
  private val roleService: RoleService = mockk()
  private val userService = UserServiceImpl(userDao, roleService)

  @Test
  fun `createUser should create user when caller has permission`() = runBlocking {
    // Arrange
    val createUserRequest = CreateUserRequest(
      username = "testuser",
      password = "password",
      email = "test@example.com",
      displayName = "Test User",
      roles = listOf(ROLE_STAFF),
      organizationId = 1
    )
    val authContext = AuthContext(
      userId = 1,
      organizationId = 1,
      permissions = setOf(Permission.MANAGE_USERS_ORGANIZATION, Permission.CAN_ASSIGN_STAFF)
    )
    val user = User(
      userId = 1,
      username = "testuser",
      email = "test@example.com",
      displayName = "Test User",
      passwordHash = "hashed_password"
    )
    val staffRole = RoleResponse(roleId = 1, roleName = ROLE_STAFF, permissions = emptyList())
    val organization = OrganizationResponse(1, "Test Org", "contact")

    coEvery { userDao.createUser(any()) } returns user
    coEvery { roleService.getRolesForUser(user.userId) } returns listOf(staffRole)
    coEvery { userDao.getOrganizationForUser(user.userId) } returns organization
    coEvery { roleService.getRoleByName(ROLE_STAFF) } returns staffRole
    coEvery { roleService.assignRoleToUser(user.userId, staffRole.roleId) } returns true

    // Act
    val result = userService.createUser(createUserRequest, authContext)

    // Assert
    assert(result.userId == user.userId)
    assert(result.username == user.username)
    assert(result.roles.contains(ROLE_STAFF))
    coVerify { userDao.createUser(any()) }
    coVerify { roleService.assignRoleToUser(user.userId, staffRole.roleId) }
  }

  @Test
  fun `createUser should throw exception when creating superadmin without permission`() {
    // Arrange
    val createUserRequest = CreateUserRequest(
      username = "testuser",
      password = "password",
      email = "test@example.com",
      displayName = "Test User",
      roles = listOf(Constants.ROLE_SUPERADMIN),
      organizationId = 1
    )
    val authContext = AuthContext(
      userId = 1,
      organizationId = 1,
      permissions = setOf(Permission.MANAGE_USERS_GLOBAL)
    )
    val superAdminRole = RoleResponse(roleId = 2, roleName = Constants.ROLE_SUPERADMIN, permissions = emptyList())

    coEvery { userDao.createUser(any()) } returns User(1, "", "", "", "")
    coEvery { roleService.getRoleByName(Constants.ROLE_SUPERADMIN) } returns superAdminRole

    // Act & Assert
    assertThrows<AuthorizationException> {
      runBlocking {
        userService.createUser(createUserRequest, authContext)
      }
    }
  }

  @Test
  fun `updateUser should throw exception when assigning superadmin without permission`() {
    // Arrange
    val userId = 1
    val updateUserRequest = UpdateUserRequest(
      roles = listOf(Constants.ROLE_SUPERADMIN)
    )
    val authContext = AuthContext(
      userId = 1,
      organizationId = 1,
      permissions = setOf(Permission.MANAGE_USERS_GLOBAL)
    )
    val user = User(userId, "test", "test@test.com", "Test", "")
    val superAdminRole = RoleResponse(roleId = 2, roleName = Constants.ROLE_SUPERADMIN, permissions = emptyList())

    coEvery { userDao.updateUser(userId, updateUserRequest) } returns user
    coEvery { roleService.getRolesForUser(userId) } returns emptyList()
    coEvery { roleService.getRoleByName(Constants.ROLE_SUPERADMIN) } returns superAdminRole

    // Act & Assert
    assertThrows<AuthorizationException> {
      runBlocking {
        userService.updateUser(userId, updateUserRequest, authContext)
      }
    }
  }

  @Test
  fun `can query all orgs if superAdmin`() = runBlocking {
    // Arrange
    val authContext = AuthContext(
      userId = 1,
      organizationId = 1,
      permissions = setOf(Permission.VIEW_USERS_GLOBAL)
    )
    val users = listOf(
      User(1, "user1", "email1", "display1", "pass1"),
      User(2, "user2", "email2", "display2", "pass2")
    )

    coEvery { userDao.getAllUsers() } returns users
    coEvery { roleService.getRolesForUser(any()) } returns emptyList()
    coEvery { userDao.getOrganizationForUser(any()) } returns OrganizationResponse(1, "Test Org", "contact")

    // Act
    val result = userService.getAllUsers(authContext, null)

    // Assert
    assert(result.size == 2)
    coVerify { userDao.getAllUsers() }
  }

  @Test
  fun `always uses logged-in orgId if not superAdmin`() = runBlocking {
    // Arrange
    val authContext = AuthContext(
      userId = 1,
      organizationId = 1,
      permissions = setOf(Permission.VIEW_USERS_ORGANIZATION)
    )
    val users = listOf(User(1, "user1", "email1", "display1", "pass1"))

    coEvery { userDao.getUsersByOrganization(1) } returns users
    coEvery { roleService.getRolesForUser(any()) } returns emptyList()
    coEvery { userDao.getOrganizationForUser(any()) } returns OrganizationResponse(1, "Test Org", "contact")

    // Act
    val result = userService.getAllUsers(authContext, 2) // Passing a different orgId

    // Assert
    assert(result.size == 1)
    coVerify { userDao.getUsersByOrganization(1) }
  }
}
