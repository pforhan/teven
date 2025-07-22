
package com.teven.service.user

import com.teven.api.model.auth.LoginRequest
import com.teven.api.model.auth.LoginResponse
import com.teven.api.model.auth.RegisterRequest
import com.teven.api.model.auth.UserContextResponse
import com.teven.api.model.auth.UserResponse
import com.teven.api.model.organization.OrganizationDetails
import com.teven.core.security.PasswordHasher
import com.teven.data.user.UserDao

class UserService(private val userDao: UserDao) {
    fun registerUser(registerRequest: RegisterRequest): UserResponse {
        // TODO: Add business logic, e.g., password hashing, validation
        return userDao.createUser(registerRequest)
    }

    fun loginUser(loginRequest: LoginRequest): LoginResponse? {
        val user = userDao.findByUsername(loginRequest.username)
        return if (user != null && PasswordHasher.checkPassword(loginRequest.password, user.passwordHash)) {
            // TODO: Generate JWT token
            LoginResponse("dummy_token", user.userId, user.username, user.role)
        } else {
            null
        }
    }

    fun getUserById(userId: Int): UserResponse? {
        return userDao.findById(userId)
    }

    fun updateUser(userId: Int, updateUserRequest: com.teven.api.model.auth.UpdateUserRequest): Boolean {
        return userDao.updateUser(userId, updateUserRequest)
    }

    fun getUserContext(userId: Int): UserContextResponse? {
        val user = userDao.findById(userId)
        return if (user != null) {
            UserContextResponse(
                user = user,
                organization = OrganizationDetails(1, "Teven Inc.", "contact@teven.com"), // Dummy data
                permissions = listOf("read:event", "create:event") // Dummy data
            )
        } else {
            null
        }
    }
}
