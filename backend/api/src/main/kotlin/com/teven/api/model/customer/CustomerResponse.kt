package com.teven.api.model.customer

import kotlinx.serialization.Serializable

@Serializable
data class CustomerResponse(
  val customerId: Int,
  val name: String,
  val contactInformation: String,
)
