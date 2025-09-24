import alphainterplanetary.teven.api.model.role.RoleResponse
import alphainterplanetary.teven.api.model.user.UpdateUserRequest
import alphainterplanetary.teven.core.Constants
import alphainterplanetary.teven.core.security.AuthorizationException
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.core.security.UserPermissions
import alphainterplanetary.teven.core.service.PermissionService
import alphainterplanetary.teven.core.service.RoleService
import alphainterplanetary.teven.core.user.User
import alphainterplanetary.teven.data.user.UserDao
import alphainterplanetary.teven.service.invitation.InvitationService
import alphainterplanetary.teven.service.user.UserServiceImpl
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows

class UserServiceImplTest {

  private val userDao: UserDao = mockk()
  private val roleService: RoleService = mockk()
  private val invitationService: InvitationService = mockk()
  private val permissionService: PermissionService = mockk()

  private val userService =
    UserServiceImpl(userDao, roleService, invitationService)

  @Test
  fun `createUser should create user`() = runBlocking {
    val username = "testuser"
    val email = "test@test.com"
    val password = "password"
    val displayName = "Test User"
    val organizationId = 1
    val roleId = 1

    val newUser = User(
      userId = 2,
      username = username,
      email = email,
      passwordHash = password,
      displayName = displayName,
    )

    coEvery { userDao.createUser(username, password, email, displayName, organizationId) } returns newUser
    coEvery { roleService.assignRoleToUser(newUser.userId, roleId) } returns true
    coEvery { roleService.getRolesForUser(newUser.userId) } returns emptyList()
    coEvery { userDao.getOrganizationForUser(newUser.userId) } returns null

    val result = userService.createUser(username, password, email, displayName, organizationId, roleId)

    assert(result == newUser.userId)
  }

  @Test
  fun `getUserByEmail should return user when found`() = runBlocking {
    val email = "test@test.com"
    val user = User(
      userId = 1,
      username = "testuser",
      email = email,
      passwordHash = "password",
      displayName = "Test User"
    )
    coEvery { userDao.getUserByEmail(email) } returns user
    coEvery { roleService.getRolesForUser(user.userId) } returns emptyList()
    coEvery { userDao.getOrganizationForUser(user.userId) } returns null

    val result = userService.getUserByEmail(email)

    assert(result?.email == email)
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
