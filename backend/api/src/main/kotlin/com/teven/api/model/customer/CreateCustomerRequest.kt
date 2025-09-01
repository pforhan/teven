package com.teven.api.model.customer

import kotlinx.serialization.Serializable

@Serializable
data class CreateCustomerRequest(
  val name: String,
  val phone: String,
  val address: String,
  val notes: String,
)
