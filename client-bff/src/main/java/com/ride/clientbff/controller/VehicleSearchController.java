package com.ride.clientbff.controller;

import com.ride.clientbff.dto.VehicleSearchRequestDto;
import com.ride.clientbff.dto.VehicleSearchResponseDto;
import com.ride.clientbff.service.IVehicleSearchService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * REST Controller for vehicle search endpoints.
 * Provides endpoints for clients to search for available vehicles.
 */
@RestController
@RequestMapping("/api/v1/client/search")
@RequiredArgsConstructor
@Slf4j
public class VehicleSearchController {

    private final IVehicleSearchService vehicleSearchService;

    /**
     * Searches for available vehicles based on pickup location, date range, and time.
     * <p>
     * Request body should contain:
     * - pickupLocation: Where customer wants to pick up the vehicle
     * - pickupDate: Start date of rental
     * - pickupTime: Start time of rental
     * - dropOffDate: End date of rental
     * - dropOffTime: End time of rental
     * <p>
     * Response includes:
     * - List of available vehicles with pricing
     * - Total rental cost for the specified date range
     * - Number of rental days
     * - Vehicle details (body type, location, etc.)
     *
     * @param searchRequest the vehicle search criteria
     * @return ResponseEntity with available vehicles and pricing information
     */
    @PostMapping("/vehicles")
    public ResponseEntity<VehicleSearchResponseDto> searchVehicles(
            @RequestBody VehicleSearchRequestDto searchRequest) {

        log.info("Received vehicle search request for location: {}, from {} to {}",
                searchRequest.getPickupLocation(),
                searchRequest.getPickupDate(),
                searchRequest.getDropOffDate());

        try {
            VehicleSearchResponseDto response = vehicleSearchService.searchAvailableVehicles(searchRequest);

            if (response.isSuccess()) {
                log.info("Search completed successfully. Found {} vehicles", response.getTotalVehicles());
                return ResponseEntity.ok(response);
            } else {
                log.warn("Search completed with no results: {}", response.getMessage());
                return ResponseEntity.status(HttpStatus.NOT_FOUND).body(response);
            }
        } catch (Exception e) {
            log.error("Error processing vehicle search: {}", e.getMessage(), e);

            VehicleSearchResponseDto errorResponse = VehicleSearchResponseDto.builder()
                    .success(false)
                    .message("Error processing search: " + e.getMessage())
                    .build();

            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }
}
