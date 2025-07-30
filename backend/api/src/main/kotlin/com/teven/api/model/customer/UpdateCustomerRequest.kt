package com.teven.api.model.customer

import kotlinx.serialization.Serializable

@Serializable
data class UpdateCustomerRequest(
  val name: String? = null,
  val contactInformation: String? = null,
)
