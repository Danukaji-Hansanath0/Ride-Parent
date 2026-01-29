package com.ride.clientbff.service;

import com.ride.clientbff.dto.AdvancedVehicleSearchRequestDto;
import com.ride.clientbff.dto.PaginatedVehicleSearchResponseDto;

/**
 * Interface for Advanced Vehicle Search Service.
 * Provides methods for advanced search with pagination, filtering, and sorting.
 */
public interface IAdvancedVehicleSearchService {

    /**
     * Searches for available vehicles with advanced filtering, sorting, and pagination.
     * <p>
     * Features:
     * - Pagination support (page number, page size)
     * - Sorting (by price, location, body type)
     * - Filtering (by body type, price range)
     * - Location-based prioritization (user location appears first)
     *
     * @param searchRequest advanced search criteria with pagination and filters
     * @return PaginatedVehicleSearchResponseDto with paginated results
     */
    PaginatedVehicleSearchResponseDto searchWithAdvancedFilters(AdvancedVehicleSearchRequestDto searchRequest);
}
