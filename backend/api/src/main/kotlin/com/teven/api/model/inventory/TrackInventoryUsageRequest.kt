
package com.teven.api.model.inventory

import kotlinx.serialization.Serializable

@Serializable
data class TrackInventoryUsageRequest(
    val eventId: Int,
    val quantity: Int
)
