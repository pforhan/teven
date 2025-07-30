package com.teven.api.model.role

import kotlinx.serialization.Serializable

@Serializable
data class CreateRoleRequest(
  val roleName: String,
  val permissions: List<String>,
)
