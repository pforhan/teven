
package com.teven.api.model.event

import kotlinx.serialization.Serializable

@Serializable
data class UpdateEventRequest(
    val title: String? = null,
    val date: String? = null,
    val time: String? = null,
    val location: String? = null,
    val description: String? = null,
    val inventoryIds: List<Int>? = null,
    val customerId: Int? = null,
    val staffInvites: StaffInviteDetails? = null
)
