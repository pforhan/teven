package alphainterplanetary.teven.core.service

import alphainterplanetary.teven.api.model.auth.LoginRequest
import alphainterplanetary.teven.api.model.auth.LoginResponse

interface AuthService {
  suspend fun loginUser(loginRequest: LoginRequest): LoginResult
}

sealed class LoginResult {
  data class Success(val response: LoginResponse) : LoginResult()
  data object UserNotFound : LoginResult()
  data object InvalidPassword : LoginResult()
}