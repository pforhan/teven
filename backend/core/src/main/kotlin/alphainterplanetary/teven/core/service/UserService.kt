package alphainterplanetary.teven.core.service

import alphainterplanetary.teven.api.model.auth.LoggedInContextResponse
import alphainterplanetary.teven.api.model.invitation.AcceptInvitationRequest
import alphainterplanetary.teven.api.model.user.CreateUserRequest
import alphainterplanetary.teven.api.model.user.UpdateUserRequest
import alphainterplanetary.teven.api.model.user.UserResponse
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.user.Invitation
import alphainterplanetary.teven.core.user.User

interface UserService {
  suspend fun toUserResponse(user: User): UserResponse
  suspend fun createUser(createUserRequest: CreateUserRequest, authContext: AuthContext): UserResponse
  suspend fun createUserFromInvitation(request: AcceptInvitationRequest, invitation: Invitation): Int
  suspend fun getAllUsers(authContext: AuthContext, organizationId: Int? = null): List<UserResponse>
  suspend fun getUserById(userId: Int): UserResponse?
  suspend fun getUserContext(userId: Int): LoggedInContextResponse
  suspend fun areInSameOrganization(userId1: Int?, userId2: Int?): Boolean
  suspend fun updateUser(userId: Int, updateUserRequest: UpdateUserRequest): UserResponse?
  suspend fun getUserByUsername(username: String): UserResponse?
  suspend fun getUserByEmail(email: String): UserResponse?
}