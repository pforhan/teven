package com.teven.api.model.customer

import kotlinx.serialization.Serializable

@Serializable
data class UpdateCustomerRequest(
  val name: String? = null,
  val phone: String? = null,
  val address: String? = null,
  val notes: String? = null,
  val organizationId: Int? = null,
)
