package com.teven.core.service

import com.teven.api.model.auth.LoginRequest
import com.teven.api.model.auth.LoginResponse

interface AuthService {
  suspend fun loginUser(loginRequest: LoginRequest): LoginResponse?
}