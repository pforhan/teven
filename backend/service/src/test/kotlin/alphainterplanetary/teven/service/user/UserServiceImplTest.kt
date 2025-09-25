package alphainterplanetary.teven.service.user

import alphainterplanetary.teven.api.model.organization.OrganizationResponse
import alphainterplanetary.teven.api.model.role.RoleResponse
import alphainterplanetary.teven.api.model.user.CreateUserRequest
import alphainterplanetary.teven.api.model.user.UpdateUserRequest
import alphainterplanetary.teven.core.Constants
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.AuthorizationException
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.core.service.PermissionService
import alphainterplanetary.teven.core.service.RoleService
import alphainterplanetary.teven.core.user.User
import alphainterplanetary.teven.data.organization.OrganizationDao
import alphainterplanetary.teven.data.user.UserDao
import alphainterplanetary.teven.service.invitation.InvitationService
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows

class UserServiceImplTest {

  private val userDao: UserDao = mockk()
  private val roleService: RoleService = mockk()
  private val userService = UserServiceImpl(userDao, roleService)

  @Test
  fun `createUser should create user when caller has permission`() {
    TODO("not yet implemented")
  }

  @Test
  fun `createUser should throw exception when creating superadmin without permission`() {
    TODO("not yet implemented")
  }

  @Test
  fun `updateUser should throw exception when assigning superadmin without permission`() {
    TODO("not yet implemented")
  }

  @Test
  fun `can query all orgs if superAdmin`() {
    TODO("Not yet implemented")
  }

  @Test
  fun `always uses logged-in orgId if not superAdmin`() {
    TODO("Not yet implemented")
  }
}
