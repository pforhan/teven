package alphainterplanetary.teven.service.geo

import alphainterplanetary.teven.api.model.common.GeoLocation

interface GeoProvider {
  /**
   * Returns a list of address suggestions for a query.
   */
  suspend fun autocomplete(query: String): List<GeoLocation>

  /**
   * Returns coordinates and formatted address for a given address string.
   */
  suspend fun geocode(address: String): GeoLocation?
}
