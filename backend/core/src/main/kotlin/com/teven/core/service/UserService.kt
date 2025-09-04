package com.teven.core.service

import com.teven.api.model.auth.LoggedInContextResponse
import com.teven.api.model.user.CreateUserRequest
import com.teven.api.model.user.UpdateUserRequest
import com.teven.api.model.user.UserResponse
import com.teven.core.user.User

interface UserService {
  suspend fun toUserResponse(user: User): UserResponse
  suspend fun createUser(createUserRequest: CreateUserRequest): UserResponse
  suspend fun getAllUsers(callerId: Int): List<UserResponse>
  suspend fun getUserById(userId: Int): UserResponse?
  suspend fun getUserContext(userId: Int): LoggedInContextResponse?
  suspend fun areInSameOrganization(userId1: Int?, userId2: Int?): Boolean
  suspend fun updateUser(userId: Int, updateUserRequest: UpdateUserRequest): UserResponse?
  suspend fun getUserByUsername(username: String): UserResponse?
}