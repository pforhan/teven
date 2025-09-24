package alphainterplanetary.teven.core.user

import kotlinx.serialization.Serializable

@Serializable
data class AcceptInvitationResponse(
    val success: Boolean,
    val message: String? = null,
)
