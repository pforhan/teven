package alphainterplanetary.teven.core.service

import alphainterplanetary.teven.api.model.auth.LoginRequest
import alphainterplanetary.teven.api.model.auth.LoginResponse

interface AuthService {
  suspend fun loginUser(loginRequest: LoginRequest): LoginResponse?
}