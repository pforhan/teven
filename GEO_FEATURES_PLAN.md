# Implementation Plan: Geographic Features

This document outlines the plan for adding geographic features to Teven, including address lookup, structured geo-data storage, map displays, and a map view for upcoming events.

## 1. Objectives
- Improve address entry with autocomplete and validation.
- Store structured geographic coordinates (latitude, longitude) for events and customers.
- Provide visual map representations of locations.
- Implement a comprehensive map view for upcoming scheduled events.

## 2. Backend Changes

### 2.1 Database Schema Updates
Add geographic fields to `Customers` and `Events` tables in `backend/data`.

**Table: `Customers`**
- `latitude`: `Double?`
- `longitude`: `Double?`
- `formatted_address`: `String?`

**Table: `Events`**
- `latitude`: `Double?`
- `longitude`: `Double?`
- `formatted_address`: `String?`

### 2.2 New Geo API
Create a new `GeoService` and `GeoRoutes` in the `backend`.

**Endpoints:**
- `GET /api/geo/autocomplete?query={query}`: Returns a list of address suggestions.
- `GET /api/geo/geocode?address={address}`: Returns coordinates and formatted address for a given string.

### 2.3 Data Model (DTO) Updates
Update `CustomerResponse`, `CreateCustomerRequest`, `UpdateCustomerRequest`, `EventResponse`, `CreateEventRequest`, and `UpdateEventRequest` to include geo fields.

```kotlin
data class GeoLocation(
  val latitude: Double,
  val longitude: Double,
  val formattedAddress: String?
)
```

## 3. Frontend Changes

### 3.1 Components
- **`AddressAutocomplete`**: A reusable input component that uses the `/api/geo/autocomplete` endpoint.
- **`LocationPicker`**: A component that allows selecting a location on a map or via search.
- **`MapDisplay`**: A simple component to show a static or interactive map for a single location (used in Event/Customer details).
- **`EventsMapView`**: A new page component providing an interactive map view:
  - **Timeframe**: Default view is **1 day (Today)**, but adjustable via **start/end date pickers**.
  - **Filtering**: Toggle between **"All Events"** (default) and **"My Events"** (only events the user has RSVP'd "Yes" to).
  - **Visualization**: Markers use a **Red-to-Green spectrum** (Red for today, with a linear gradient toward green capped at **14 days** away by default).
- **Directions**: "Get Directions" links will:
  - On **Mobile**: Trigger calls to native apps (MapKit on iOS, Google Maps intent on Android).
  - On **Web**: Open Google Maps in a new browser tab.

### 3.2 Library Selection
- **Maps**: `react-leaflet` (OpenStreetMap) or `google-map-react`. Given the "premium" requirement, Mapbox or Google Maps with custom styling is preferred.
- **External API**: Google Maps Places API or Mapbox Geocoding API.

### 3.3 New Pages
- **`/events/map`**: A full-screen map view showing markers for events in the next X days (e.g., 7 days). Clicking a marker shows a popup with event details and a link to the event page.

## 4. Implementation Steps

1.  **Phase 1: Foundation (Backend & Database)**
    - [x] Update Exposed schemas for `Customers` and `Events`.
    - [x] Update DTOs in `api` module.
    - [x] Implement `GeoService` with a placeholder or mock geocoding (can use a library like `geocoder` or call an external API).
    - [ ] Add `GeoRoutes` to Ktor application.

2.  **Phase 2: Enhanced Input (Frontend)**
    - [ ] Create `AddressAutocomplete` component.
    - [ ] Integrate `AddressAutocomplete` into `CreateEventForm`, `EditEventForm`, and Customer forms.
    - [ ] Ensure lat/lng are sent to the backend when an address is selected.

3.  **Phase 3: Visualizations (Frontend)**
    - [ ] Integrate a map library (e.g., Leaflet).
    - [ ] Add `MapDisplay` to `EventDetails` and `CustomerDetails`.
    - [ ] Implement the `EventsMapView` page.

4.  **Phase 4: Polish**
    - [ ] Add "Get Directions" links (Google Maps/Apple Maps).
    - [ ] Add "Events near me" filtering if applicable.
    - [ ] Ensure mobile responsiveness.

## 5. Design Decisions (Confirmed)
- **Denormalization**: Geographic fields (`latitude`, `longitude`, `formattedAddress`) will be stored directly in `Customers` and `Events` tables to avoid extra joins and state management complexity.
- **Provider Choice**: **Mapbox** (for premium visuals) and **Radar** (for geocoding lookup) are the preferred providers due to their generous free tiers and "premium" aesthetics.
- **Security**: The `GEO_API_KEY` will be managed via the `.env` file and never checked into version control.
- **Abstraction**: Backend will implement a `GeoProvider` interface, beginning with a `MockGeoProvider` for development testing without requiring an API key.

