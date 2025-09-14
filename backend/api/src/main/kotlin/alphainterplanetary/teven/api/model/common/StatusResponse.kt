package alphainterplanetary.teven.api.model.common

import kotlinx.serialization.Serializable

@Serializable
data class StatusResponse(val status: String) // "OK" on success
