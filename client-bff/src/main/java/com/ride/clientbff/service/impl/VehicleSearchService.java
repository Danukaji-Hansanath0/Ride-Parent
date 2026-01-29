package com.ride.clientbff.service.impl;

import com.ride.clientbff.dto.AvailableVehicleDto;
import com.ride.clientbff.dto.VehicleSearchRequestDto;
import com.ride.clientbff.dto.VehicleSearchResponseDto;
import com.ride.clientbff.service.IVehicleSearchService;
import com.ride.clientbff.service.IVehicleServiceClient;
import com.ride.clientbff.service.IPricingServiceClient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;

/**
 * Service implementation for vehicle search operations.
 * Orchestrates the search process by fetching available vehicles and their pricing.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class VehicleSearchService implements IVehicleSearchService {

    private final IVehicleServiceClient vehicleServiceClient;
    private final IPricingServiceClient pricingServiceClient;

    /**
     * Searches for available vehicles based on search criteria.
     * <p>
     * Process:
     * 1. Get available vehicles from Vehicle Service based on location and date range
     * 2. For each vehicle, fetch pricing using OwnersHasVehicle ID
     * 3. Calculate total rental cost based on number of days
     * 4. Return all vehicles with pricing information
     *
     * @param searchRequest search criteria (location, dates, times)
     * @return VehicleSearchResponseDto with available vehicles and pricing
     */
    @Override
    public VehicleSearchResponseDto searchAvailableVehicles(VehicleSearchRequestDto searchRequest) {
        log.info("Searching vehicles for location: {}, from {} to {}",
                searchRequest.getPickupLocation(),
                searchRequest.getPickupDate(),
                searchRequest.getDropOffDate());

        try {
            // Validate request
            validateSearchRequest(searchRequest);

            // Step 1: Get available vehicles from Vehicle Service
            List<AvailableVehicleDto> availableVehicles = vehicleServiceClient
                    .getAvailableVehicles(
                            searchRequest.getPickupLocation(),
                            searchRequest.getPickupDate(),
                            searchRequest.getDropOffDate()
                    )
                    .collectList()
                    .block();

            if (availableVehicles == null || availableVehicles.isEmpty()) {
                log.warn("No vehicles found for location: {}", searchRequest.getPickupLocation());
                return buildEmptyResponse("No vehicles available for the selected criteria");
            }

            log.info("Found {} available vehicles", availableVehicles.size());

            // Step 2: Enrich vehicles with pricing information
            List<AvailableVehicleDto> vehiclesWithPricing = new ArrayList<>();

            for (AvailableVehicleDto vehicle : availableVehicles) {
                try {
                    // Fetch pricing using OwnersHasVehicle ID
                    AvailableVehicleDto vehicleWithPrice = pricingServiceClient
                            .getPricingForVehicle(vehicle.getOwnerHasVehicleId().toString())
                            .block();

                    if (vehicleWithPrice != null) {
                        // Calculate rental duration and total cost
                        long rentalDays = calculateRentalDays(
                                searchRequest.getPickupDate(),
                                searchRequest.getDropOffDate()
                        );

                        vehicleWithPrice.setRentalDays((int) rentalDays);
                        vehicleWithPrice.setTotalCost(calculateTotalCost(vehicleWithPrice, rentalDays));

                        vehiclesWithPricing.add(vehicleWithPrice);
                        log.debug("Added vehicle with pricing: {}", vehicle.getOwnerHasVehicleId());
                    }
                } catch (Exception e) {
                    log.warn("Failed to fetch pricing for vehicle {}: {}",
                            vehicle.getOwnerHasVehicleId(), e.getMessage());
                    // Continue with next vehicle if pricing fetch fails
                }
            }

            if (vehiclesWithPricing.isEmpty()) {
                log.warn("No vehicles with pricing found");
                return buildEmptyResponse("Could not retrieve pricing for available vehicles");
            }

            log.info("Search completed. Found {} vehicles with pricing", vehiclesWithPricing.size());

            return VehicleSearchResponseDto.builder()
                    .vehicles(vehiclesWithPricing)
                    .totalVehicles(vehiclesWithPricing.size())
                    .success(true)
                    .message("Found " + vehiclesWithPricing.size() + " available vehicles")
                    .build();

        } catch (IllegalArgumentException e) {
            log.error("Invalid search request: {}", e.getMessage());
            return buildErrorResponse("Invalid search criteria: " + e.getMessage());
        } catch (Exception e) {
            log.error("Error searching vehicles: {}", e.getMessage(), e);
            return buildErrorResponse("Error searching vehicles: " + e.getMessage());
        }
    }

    /**
     * Validates search request parameters.
     *
     * @param searchRequest the search request to validate
     * @throws IllegalArgumentException if validation fails
     */
    private void validateSearchRequest(VehicleSearchRequestDto searchRequest) {
        if (searchRequest.getPickupLocation() == null || searchRequest.getPickupLocation().isEmpty()) {
            throw new IllegalArgumentException("Pickup location is required");
        }

        if (searchRequest.getPickupDate() == null) {
            throw new IllegalArgumentException("Pickup date is required");
        }

        if (searchRequest.getDropOffDate() == null) {
            throw new IllegalArgumentException("Drop-off date is required");
        }

        if (searchRequest.getPickupDate().isAfter(searchRequest.getDropOffDate())) {
            throw new IllegalArgumentException("Pickup date cannot be after drop-off date");
        }

        if (searchRequest.getPickupTime() == null) {
            throw new IllegalArgumentException("Pickup time is required");
        }

        if (searchRequest.getDropOffTime() == null) {
            throw new IllegalArgumentException("Drop-off time is required");
        }
    }

    /**
     * Calculates the number of days between pickup and drop-off dates.
     *
     * @param pickupDate the rental start date
     * @param dropOffDate the rental end date
     * @return number of rental days
     */
    private long calculateRentalDays(LocalDate pickupDate, LocalDate dropOffDate) {
        long days = ChronoUnit.DAYS.between(pickupDate, dropOffDate);
        return Math.max(days, 1); // At least 1 day
    }

    /**
     * Calculates total rental cost based on vehicle pricing and rental duration.
     * <p>
     * Logic:
     * - 1-3 days: Use daily price × days
     * - 4-30 days: Use weekly price for full weeks + daily price for remaining days
     * - 30+ days: Use monthly price for full months + weekly/daily for remaining days
     *
     * @param vehicle the vehicle with pricing information
     * @param rentalDays the number of rental days
     * @return total rental cost
     */
    private double calculateTotalCost(AvailableVehicleDto vehicle, long rentalDays) {
        if (rentalDays <= 3) {
            // Use daily pricing for short rentals
            return vehicle.getPricePerDay() * rentalDays;
        } else if (rentalDays <= 30) {
            // Use weekly pricing for medium rentals
            long weeks = rentalDays / 7;
            long remainingDays = rentalDays % 7;
            return (vehicle.getPricePerWeek() * weeks) + (vehicle.getPricePerDay() * remainingDays);
        } else {
            // Use monthly pricing for long rentals
            long months = rentalDays / 30;
            long remainingDays = rentalDays % 30;
            long remainingWeeks = remainingDays / 7;
            long finalDays = remainingDays % 7;
            return (vehicle.getPricePerMonth() * months)
                    + (vehicle.getPricePerWeek() * remainingWeeks)
                    + (vehicle.getPricePerDay() * finalDays);
        }
    }

    /**
     * Builds an empty response.
     *
     * @param message the response message
     * @return VehicleSearchResponseDto with no vehicles
     */
    private VehicleSearchResponseDto buildEmptyResponse(String message) {
        return VehicleSearchResponseDto.builder()
                .vehicles(new ArrayList<>())
                .totalVehicles(0)
                .success(false)
                .message(message)
                .build();
    }

    /**
     * Builds an error response.
     *
     * @param message the error message
     * @return VehicleSearchResponseDto with error status
     */
    private VehicleSearchResponseDto buildErrorResponse(String message) {
        return VehicleSearchResponseDto.builder()
                .vehicles(new ArrayList<>())
                .totalVehicles(0)
                .success(false)
                .message(message)
                .build();
    }
}
