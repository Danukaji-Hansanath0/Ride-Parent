package com.ride.clientbff.service;

import com.ride.clientbff.dto.AvailableVehicleDto;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.time.LocalDate;
import java.util.List;

/**
 * Interface for Vehicle Service Client.
 * Provides methods to interact with the Vehicle Service API.
 */
public interface IVehicleServiceClient {

    /**
     * Retrieves all available vehicles for a given location and date range.
     * <p>
     * Searches the OwnersHasVehicle table for vehicles that:
     * - Are available at the specified pickup location
     * - Have availability start date <= pickupDate
     * - Have availability end date >= dropOffDate
     *
     * @param location the pickup location
     * @param pickupDate the start date of rental
     * @param dropOffDate the end date of rental
     * @return Flux emitting available vehicles as AvailableVehicleDto
     */
    Flux<AvailableVehicleDto> getAvailableVehicles(String location, LocalDate pickupDate, LocalDate dropOffDate);
}
