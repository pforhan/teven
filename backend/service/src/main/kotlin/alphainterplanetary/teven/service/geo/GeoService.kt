package alphainterplanetary.teven.service.geo

import alphainterplanetary.teven.api.model.common.GeoLocation

/**
 * Common service for handling geographic lookups.
 */
class GeoService {
  private val provider: GeoProvider = when (System.getenv("GEO_PROVIDER")?.uppercase() ?: "MOCK") {
    "MAPBOX" -> {
      // MapboxProvider(System.getenv("GEO_API_KEY")) 
      MockGeoProvider() // TODO: Implement MapboxProvider
    }
    "RADAR" -> {
      // RadarProvider(System.getenv("GEO_API_KEY"))
      MockGeoProvider() // TODO: Implement RadarProvider
    }
    else -> MockGeoProvider()
  }

  suspend fun autocomplete(query: String): List<GeoLocation> = provider.autocomplete(query)

  suspend fun geocode(address: String): GeoLocation? = provider.geocode(address)
}
