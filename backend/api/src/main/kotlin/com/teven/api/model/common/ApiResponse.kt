package com.teven.api.model.common

import kotlinx.serialization.Serializable

fun <T> success(data: T): ApiResponse<T> = ApiResponse(success = true, data = data)

fun failure(message: String, details: String? = null): ApiResponse<Unit> =
  ApiResponse(success = false, data = Unit, error = ApiError(message, details))

/** Do not construct manually, use success or failure methods instead. */
@Serializable
data class ApiResponse<T>(
  val success: Boolean,
  val data: T? = null,
  val error: ApiError? = null,
)

/** Do not construct manually, use success or failure methods instead. */
@Serializable
data class ApiError(
  val message: String,
  val details: String? = null,
)
