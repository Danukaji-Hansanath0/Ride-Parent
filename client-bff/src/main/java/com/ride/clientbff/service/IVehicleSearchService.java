package com.ride.clientbff.service;

import com.ride.clientbff.dto.VehicleSearchRequestDto;
import com.ride.clientbff.dto.VehicleSearchResponseDto;

/**
 * Interface for Vehicle Search Service.
 * Provides methods to search for available vehicles based on search criteria.
 */
public interface IVehicleSearchService {

    /**
     * Searches for available vehicles based on pickup location, date range, and time.
     * <p>
     * The search:
     * 1. Finds vehicles available for the specified date range at pickup location
     * 2. Retrieves pricing information from Pricing Service using OwnersHasVehicle ID
     * 3. Calculates total rental cost based on rental duration
     * 4. Returns sorted list of available vehicles with pricing
     *
     * @param searchRequest containing:
     *                      - pickupLocation: Where customer wants to pick up the vehicle
     *                      - pickupDate: Start date of rental
     *                      - pickupTime: Start time of rental
     *                      - dropOffDate: End date of rental
     *                      - dropOffTime: End time of rental
     * @return VehicleSearchResponseDto containing list of available vehicles with pricing
     */
    VehicleSearchResponseDto searchAvailableVehicles(VehicleSearchRequestDto searchRequest);
}
