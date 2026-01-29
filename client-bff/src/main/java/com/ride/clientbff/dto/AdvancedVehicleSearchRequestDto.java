package com.ride.clientbff.dto;

import lombok.*;
import lombok.experimental.SuperBuilder;

/**
 * DTO for advanced vehicle search request with pagination and filtering.
 * Extends basic search with sorting, pagination, and advanced filters.
 */
@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
@SuperBuilder
public class AdvancedVehicleSearchRequestDto extends VehicleSearchRequestDto {

    /**
     * Page number (0-indexed).
     */
    private Integer pageNumber = 0;

    /**
     * Number of items per page.
     */
    private Integer pageSize = 10;

    /**
     * Sort field (e.g., "pricePerDay", "location", "bodyType").
     */
    private String sortBy = "pricePerDay";

    /**
     * Sort direction: "ASC" or "DESC".
     */
    private String sortDirection = "ASC";

    /**
     * Filter by body type (e.g., "SUV", "SEDAN").
     */
    private String bodyTypeFilter;

    /**
     * Filter by minimum price.
     */
    private Double minPrice;

    /**
     * Filter by maximum price.
     */
    private Double maxPrice;

    /**
     * Search by owner location (for listing vehicles from preferred locations
     * first).
     * If provided, vehicles from this location appear first.
     */
    private String userLocation;

    /**
     * User latitude for geospatial search.
     */
    private Double latitude;

    /**
     * User longitude for geospatial search.
     */
    private Double longitude;

    /**
     * Search radius in kilometers (default: 50km).
     */
    @Builder.Default
    private Double radiusKm = 50.0;
}
