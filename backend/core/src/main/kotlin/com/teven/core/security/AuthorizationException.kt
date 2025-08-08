package com.teven.core.security

import io.ktor.http.HttpStatusCode

class AuthorizationException(val code: HttpStatusCode, message: String) : Exception(message)
