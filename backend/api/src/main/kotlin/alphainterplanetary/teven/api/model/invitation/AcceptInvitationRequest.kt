package alphainterplanetary.teven.api.model.invitation

import kotlinx.serialization.Serializable

@Serializable
data class AcceptInvitationRequest(
    val token: String,
    val username: String,
    val password: String,
    val email: String,
    val displayName: String,
)
