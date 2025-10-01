package alphainterplanetary.teven.api.model.invitation

import kotlinx.serialization.Serializable

@Serializable
data class ValidateInvitationResponse(
    val organizationId: Int,
    val organizationName: String,
    val roleName: String,
)
