package com.ride.clientbff.service;

import com.ride.clientbff.dto.AvailableVehicleDto;
import reactor.core.publisher.Mono;

/**
 * Interface for Pricing Service Client.
 * Provides methods to interact with the Pricing Service API.
 */
public interface IPricingServiceClient {

    /**
     * Retrieves pricing information for a vehicle using the OwnersHasVehicle ID.
     * <p>
     * The OwnersHasVehicle ID is used as the vehicleId in the Pricing Service
     * because each owner-vehicle pair has its own pricing configuration.
     *
     * @param ownerHasVehicleId the OwnersHasVehicle ID (used as vehicleId in pricing service)
     * @return Mono emitting the AvailableVehicleDto with pricing information populated
     */
    Mono<AvailableVehicleDto> getPricingForVehicle(String ownerHasVehicleId);
}
