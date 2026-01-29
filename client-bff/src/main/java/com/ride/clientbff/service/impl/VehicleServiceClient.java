package com.ride.clientbff.service.impl;

import com.ride.clientbff.dto.AvailableVehicleDto;
import com.ride.clientbff.service.IVehicleServiceClient;
import com.ride.clientbff.service.ServiceTokenService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Flux;

import javax.annotation.Resource;
import java.time.LocalDate;

/**
 * Service client for interacting with the Vehicle Service API.
 * Handles retrieval of available vehicles based on search criteria.
 */
@Service
@Slf4j
public class VehicleServiceClient implements IVehicleServiceClient {

    @Resource(name = "vehicleServiceWebClient")
    private WebClient vehicleServiceWebClient;

    private final ServiceTokenService serviceTokenService;

    public VehicleServiceClient(ServiceTokenService serviceTokenService) {
        this.serviceTokenService = serviceTokenService;
    }

    /**
     * Retrieves available vehicles for a location and date range.
     * <p>
     * Searches the OwnersHasVehicle table for vehicles matching:
     * - Pickup location
     * - Availability window that includes pickup and drop-off dates
     *
     * @param location the pickup location
     * @param pickupDate the rental start date
     * @param dropOffDate the rental end date
     * @return Flux emitting available vehicles
     */
    @Override
    public Flux<AvailableVehicleDto> getAvailableVehicles(String location, LocalDate pickupDate, LocalDate dropOffDate) {
        log.info("Fetching available vehicles for location: {}, from {} to {}",
                location, pickupDate, dropOffDate);

        return serviceTokenService.getAccessToken()
                .flatMapMany(token -> {
                    log.debug("Access token obtained for vehicle service");

                    return vehicleServiceWebClient.get()
                            .uri(uriBuilder -> uriBuilder
                                    .path("/api/v1/vehicles/available")
                                    .queryParam("location", location)
                                    .queryParam("pickupDate", pickupDate)
                                    .queryParam("dropOffDate", dropOffDate)
                                    .build()
                            )
                            .headers(headers -> headers.setBearerAuth(token))
                            .accept(MediaType.APPLICATION_JSON)
                            .retrieve()
                            .bodyToFlux(AvailableVehicleDto.class)
                            .doOnNext(vehicle -> log.debug("Retrieved vehicle: {}", vehicle.getOwnerHasVehicleId()))
                            .doOnError(e -> log.error("Error fetching vehicles: {}", e.getMessage(), e));
                })
                .onErrorResume(e -> {
                    log.error("Error retrieving access token or fetching vehicles: {}", e.getMessage(), e);
                    return Flux.error(e);
                });
    }
}
