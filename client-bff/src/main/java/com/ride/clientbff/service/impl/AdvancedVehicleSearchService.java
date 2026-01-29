package com.ride.clientbff.service.impl;

import com.ride.clientbff.dto.AdvancedVehicleSearchRequestDto;
import com.ride.clientbff.dto.AvailableVehicleDto;
import com.ride.clientbff.dto.PaginatedVehicleSearchResponseDto;
import com.ride.clientbff.service.IAdvancedVehicleSearchService;
import com.ride.clientbff.service.IVehicleSearchService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Service implementation for advanced vehicle search with pagination and filtering.
 * Handles sorting, filtering, and location-based prioritization.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class AdvancedVehicleSearchService implements IAdvancedVehicleSearchService {

    private final IVehicleSearchService vehicleSearchService;

    /**
     * Searches vehicles with advanced filters, sorting, and pagination.
     * <p>
     * Process:
     * 1. Perform basic search to get available vehicles
     * 2. Apply location prioritization (user location first)
     * 3. Apply filters (body type, price range)
     * 4. Apply sorting (by price, location, body type)
     * 5. Apply pagination
     * 6. Return paginated results
     *
     * @param searchRequest search criteria with filters and pagination
     * @return paginated vehicle search response
     */
    @Override
    public PaginatedVehicleSearchResponseDto searchWithAdvancedFilters(
            AdvancedVehicleSearchRequestDto searchRequest) {

        log.info("Executing advanced search for location: {}, page: {}, size: {}",
                searchRequest.getPickupLocation(), searchRequest.getPageNumber(), searchRequest.getPageSize());

        try {
            // Step 1: Get basic search results
            var basicResponse = vehicleSearchService.searchAvailableVehicles(searchRequest);

            if (!basicResponse.isSuccess() || basicResponse.getVehicles().isEmpty()) {
                return buildEmptyPaginatedResponse("No vehicles found for search criteria");
            }

            List<AvailableVehicleDto> vehicles = basicResponse.getVehicles();

            // Step 2: Prioritize by user location (user's location vehicles first)
            if (searchRequest.getUserLocation() != null && !searchRequest.getUserLocation().isEmpty()) {
                vehicles = prioritizeByUserLocation(vehicles, searchRequest.getUserLocation());
                log.debug("Vehicles prioritized by user location: {}", searchRequest.getUserLocation());
            }

            // Step 3: Apply filters
            vehicles = applyFilters(vehicles, searchRequest);
            log.debug("Filters applied. Remaining vehicles: {}", vehicles.size());

            // Step 4: Apply sorting
            vehicles = applySorting(vehicles, searchRequest);
            log.debug("Sorting applied. Sort field: {}, direction: {}",
                    searchRequest.getSortBy(), searchRequest.getSortDirection());

            // Step 5: Apply pagination
            return applyPagination(vehicles, searchRequest);

        } catch (Exception e) {
            log.error("Error in advanced search: {}", e.getMessage(), e);
            return buildErrorResponse("Error in advanced search: " + e.getMessage());
        }
    }

    /**
     * Prioritizes vehicles by user location.
     * Vehicles from user's location appear first.
     *
     * @param vehicles list of vehicles
     * @param userLocation user's location
     * @return prioritized list with user location vehicles first
     */
    private List<AvailableVehicleDto> prioritizeByUserLocation(
            List<AvailableVehicleDto> vehicles,
            String userLocation) {

        List<AvailableVehicleDto> userLocationVehicles = vehicles.stream()
                .filter(v -> userLocation.equalsIgnoreCase(v.getLocation()))
                .collect(Collectors.toList());

        List<AvailableVehicleDto> otherVehicles = vehicles.stream()
                .filter(v -> !userLocation.equalsIgnoreCase(v.getLocation()))
                .collect(Collectors.toList());

        userLocationVehicles.addAll(otherVehicles);
        log.debug("Prioritized {} vehicles from user location, {} from other locations",
                userLocationVehicles.size() - otherVehicles.size(), otherVehicles.size());

        return userLocationVehicles;
    }

    /**
     * Applies filters to vehicles list.
     *
     * @param vehicles list of vehicles
     * @param searchRequest search criteria with filters
     * @return filtered list
     */
    private List<AvailableVehicleDto> applyFilters(
            List<AvailableVehicleDto> vehicles,
            AdvancedVehicleSearchRequestDto searchRequest) {

        return vehicles.stream()
                // Filter by body type
                .filter(v -> searchRequest.getBodyTypeFilter() == null ||
                        v.getBodyType().equalsIgnoreCase(searchRequest.getBodyTypeFilter()))
                // Filter by price range
                .filter(v -> searchRequest.getMinPrice() == null ||
                        v.getPricePerDay() >= searchRequest.getMinPrice())
                .filter(v -> searchRequest.getMaxPrice() == null ||
                        v.getPricePerDay() <= searchRequest.getMaxPrice())
                .collect(Collectors.toList());
    }

    /**
     * Applies sorting to vehicles list.
     *
     * @param vehicles list of vehicles
     * @param searchRequest search criteria with sort options
     * @return sorted list
     */
    private List<AvailableVehicleDto> applySorting(
            List<AvailableVehicleDto> vehicles,
            AdvancedVehicleSearchRequestDto searchRequest) {

        Comparator<AvailableVehicleDto> comparator = switch (searchRequest.getSortBy()) {
            case "pricePerDay" -> Comparator.comparingDouble(AvailableVehicleDto::getPricePerDay);
            case "location" -> Comparator.comparing(AvailableVehicleDto::getLocation);
            case "bodyType" -> Comparator.comparing(AvailableVehicleDto::getBodyType);
            default -> Comparator.comparingDouble(AvailableVehicleDto::getPricePerDay);
        };

        if ("DESC".equalsIgnoreCase(searchRequest.getSortDirection())) {
            comparator = comparator.reversed();
        }

        return vehicles.stream()
                .sorted(comparator)
                .collect(Collectors.toList());
    }

    /**
     * Applies pagination to vehicles list.
     *
     * @param vehicles list of vehicles
     * @param searchRequest search criteria with pagination info
     * @return paginated response
     */
    private PaginatedVehicleSearchResponseDto applyPagination(
            List<AvailableVehicleDto> vehicles,
            AdvancedVehicleSearchRequestDto searchRequest) {

        int pageNumber = searchRequest.getPageNumber();
        int pageSize = searchRequest.getPageSize();

        long totalElements = vehicles.size();
        int totalPages = (int) Math.ceil((double) totalElements / pageSize);

        int startIndex = pageNumber * pageSize;
        int endIndex = Math.min(startIndex + pageSize, (int) totalElements);

        boolean isFirst = pageNumber == 0;
        boolean isLast = pageNumber >= totalPages - 1;

        List<AvailableVehicleDto> pageVehicles = vehicles.subList(startIndex, endIndex);

        return PaginatedVehicleSearchResponseDto.builder()
                .vehicles(pageVehicles)
                .pageNumber(pageNumber)
                .pageSize(pageSize)
                .totalElements(totalElements)
                .totalPages(totalPages)
                .first(isFirst)
                .last(isLast)
                .success(true)
                .message("Found " + totalElements + " vehicles (" + pageVehicles.size() + " on this page)")
                .build();
    }

    /**
     * Builds an empty paginated response.
     *
     * @param message response message
     * @return empty paginated response
     */
    private PaginatedVehicleSearchResponseDto buildEmptyPaginatedResponse(String message) {
        return PaginatedVehicleSearchResponseDto.builder()
                .vehicles(List.of())
                .pageNumber(0)
                .pageSize(0)
                .totalElements(0)
                .totalPages(0)
                .first(true)
                .last(true)
                .success(false)
                .message(message)
                .build();
    }

    /**
     * Builds an error response.
     *
     * @param message error message
     * @return error paginated response
     */
    private PaginatedVehicleSearchResponseDto buildErrorResponse(String message) {
        return PaginatedVehicleSearchResponseDto.builder()
                .vehicles(List.of())
                .pageNumber(0)
                .pageSize(0)
                .totalElements(0)
                .totalPages(0)
                .first(true)
                .last(true)
                .success(false)
                .message(message)
                .build();
    }
}
