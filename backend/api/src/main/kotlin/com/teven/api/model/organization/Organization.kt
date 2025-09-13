package com.teven.api.model.organization

import kotlinx.serialization.Serializable

@Serializable
data class Organization(
  val name: String,
  val id: Int
)
