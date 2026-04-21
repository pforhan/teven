package alphainterplanetary.teven.service.geo

import alphainterplanetary.teven.api.model.common.GeoLocation

/**
 * A mock implementation of [GeoProvider] for development and testing.
 */
class MockGeoProvider : GeoProvider {
  override suspend fun autocomplete(query: String): List<GeoLocation> {
    if (query.isBlank()) return emptyList()

    // Simulate some mock results based on common search prefixes
    return listOf(
      GeoLocation(34.0522, -118.2437, "Los Angeles, CA, USA"),
      GeoLocation(40.7128, -74.0060, "New York, NY, USA"),
      GeoLocation(41.8781, -87.6298, "Chicago, IL, USA"),
      GeoLocation(29.7604, -95.3698, "Houston, TX, USA"),
      GeoLocation(33.4484, -112.0740, "Phoenix, AZ, USA"),
    ).filter { it.formattedAddress?.contains(query, ignoreCase = true) == true }
  }

  override suspend fun geocode(address: String): GeoLocation? {
    if (address.isBlank()) return null

    // Mock response: pick a coordinate in Manhattan but vary it slightly for realism
    return GeoLocation(
      latitude = 40.7128 + (address.length % 100) * 0.0001,
      longitude = -74.0060 + (address.length % 50) * 0.0001,
      formattedAddress = address // Just echoing the input in the mock
    )
  }
}
