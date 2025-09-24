package alphainterplanetary.teven.api.model.invitation

import kotlinx.serialization.Serializable

@Serializable
data class CreateInvitationRequest(
    val roleId: Int,
    val expiresAt: String? = null,
    val organizationId: Int? = null,
)
