package alphainterplanetary.teven.api.model.role

import kotlinx.serialization.Serializable

@Serializable
data class UpdateRoleRequest(
  val roleName: String? = null,
  val permissions: List<String>? = null,
)
