package com.teven.auth

import io.ktor.server.auth.Principal

data class UserIdPrincipal(val userId: Int) : Principal
