package com.teven.api.model.customer

import kotlinx.serialization.Serializable

@Serializable
data class CreateCustomerRequest(
  val name: String,
  val contactInformation: String,
)
