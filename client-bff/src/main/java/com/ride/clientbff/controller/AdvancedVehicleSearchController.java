package com.ride.clientbff.controller;

import com.ride.clientbff.dto.AdvancedVehicleSearchRequestDto;
import com.ride.clientbff.dto.PaginatedVehicleSearchResponseDto;
import com.ride.clientbff.service.IAdvancedVehicleSearchService;
import com.ride.clientbff.service.IElasticsearchVehicleService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST Controller for advanced vehicle search endpoints.
 * Provides endpoints for searching vehicles with advanced filters, sorting, and
 * pagination.
 * Powered by Elasticsearch for fast, scalable search with pricing integration.
 */
@RestController
@RequestMapping("/api/v1/client/search/advanced")
@RequiredArgsConstructor
@Slf4j
public class AdvancedVehicleSearchController {

    private final IAdvancedVehicleSearchService advancedVehicleSearchService;
    private final IElasticsearchVehicleService elasticsearchService;

    /**
     * Searches for available vehicles with advanced filters and pagination.
     * <p>
     * Request body should contain:
     * - pickupLocation: Where customer wants to pick up the vehicle
     * - pickupDate: Start date of rental
     * - pickupTime: Start time of rental
     * - dropOffDate: End date of rental
     * - dropOffTime: End time of rental
     * - pageNumber: Page number (0-indexed, optional, default: 0)
     * - pageSize: Items per page (optional, default: 10)
     * - sortBy: Sort field - "pricePerDay", "location", "bodyType" (optional,
     * default: "pricePerDay")
     * - sortDirection: "ASC" or "DESC" (optional, default: "ASC")
     * - bodyTypeFilter: Filter by body type (optional)
     * - minPrice: Minimum price filter (optional)
     * - maxPrice: Maximum price filter (optional)
     * - userLocation: User's location for prioritizing nearby vehicles (optional)
     * <p>
     * Response includes:
     * - Paginated list of vehicles
     * - Sorting applied
     * - Filters applied
     * - User location vehicles prioritized first
     * - Pagination metadata (total pages, current page, etc.)
     *
     * @param searchRequest the advanced vehicle search criteria with pagination and
     *                      filters
     * @return ResponseEntity with paginated vehicles and pricing information
     */
    @PostMapping("/vehicles")
    public ResponseEntity<PaginatedVehicleSearchResponseDto> searchWithAdvancedFilters(
            @RequestBody AdvancedVehicleSearchRequestDto searchRequest) {

        log.info("Received advanced search request for location: {}, page: {}, size: {}",
                searchRequest.getPickupLocation(),
                searchRequest.getPageNumber(),
                searchRequest.getPageSize());

        try {
            PaginatedVehicleSearchResponseDto response = elasticsearchService
                    .searchVehicles(searchRequest);

            if (response.isSuccess()) {
                log.info("Advanced search completed successfully. Found {} vehicles",
                        response.getTotalElements());
                return ResponseEntity.ok(response);
            } else {
                log.warn("Advanced search completed with no results: {}", response.getMessage());
                return ResponseEntity.status(HttpStatus.NOT_FOUND).body(response);
            }
        } catch (Exception e) {
            log.error("Error processing advanced search: {}", e.getMessage(), e);

            PaginatedVehicleSearchResponseDto errorResponse = PaginatedVehicleSearchResponseDto.builder()
                    .success(false)
                    .message("Error processing search: " + e.getMessage())
                    .build();

            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }
}
