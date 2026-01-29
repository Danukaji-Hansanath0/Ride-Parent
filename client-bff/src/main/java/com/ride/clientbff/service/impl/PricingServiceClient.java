package com.ride.clientbff.service.impl;

import com.ride.clientbff.dto.AvailableVehicleDto;
import com.ride.clientbff.dto.PriceResponseDto;
import com.ride.clientbff.service.IPricingServiceClient;
import com.ride.clientbff.service.ServiceTokenService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import javax.annotation.Resource;

/**
 * Service client for interacting with the Pricing Service API.
 * Retrieves pricing information for vehicles using the OwnersHasVehicle ID.
 */
@Service
@Slf4j
public class PricingServiceClient implements IPricingServiceClient {

    @Resource(name = "pricingServiceWebClient")
    private WebClient pricingServiceWebClient;

    private final ServiceTokenService serviceTokenService;

    public PricingServiceClient(ServiceTokenService serviceTokenService) {
        this.serviceTokenService = serviceTokenService;
    }

    /**
     * Retrieves pricing information for a vehicle.
     * <p>
     * Uses the OwnersHasVehicle ID as the vehicleId in the Pricing Service
     * because pricing is tied to each owner-vehicle relationship.
     *
     * @param ownerHasVehicleId the OwnersHasVehicle ID (vehicleId in pricing service)
     * @return Mono emitting the vehicle with pricing information populated
     */
    @Override
    public Mono<AvailableVehicleDto> getPricingForVehicle(String ownerHasVehicleId) {
        log.info("Fetching pricing for vehicle: {}", ownerHasVehicleId);

        return serviceTokenService.getAccessToken()
                .flatMap(token -> {
                    log.debug("Access token obtained for pricing service");

                    return pricingServiceWebClient.get()
                            .uri("/api/v1/prices/{vehicleId}", ownerHasVehicleId)
                            .headers(headers -> headers.setBearerAuth(token))
                            .accept(MediaType.APPLICATION_JSON)
                            .retrieve()
                            .bodyToMono(PriceResponseDto.class)
                            .map(priceResponse -> enrichVehicleWithPricing(priceResponse))
                            .doOnSuccess(vehicle -> log.debug("Pricing retrieved for vehicle: {}", ownerHasVehicleId))
                            .doOnError(e -> log.error("Error fetching pricing: {}", e.getMessage(), e));
                })
                .onErrorResume(e -> {
                    log.error("Error retrieving pricing: {}", e.getMessage(), e);
                    return Mono.error(e);
                });
    }

    /**
     * Maps pricing response to vehicle DTO.
     * This is a helper method to convert pricing data to the vehicle DTO format.
     *
     * @param priceResponse the pricing response from service
     * @return AvailableVehicleDto with pricing information populated
     */
    private AvailableVehicleDto enrichVehicleWithPricing(PriceResponseDto priceResponse) {

        AvailableVehicleDto vehicle = new AvailableVehicleDto();

        if (priceResponse.getPriceRange() != null) {
            vehicle.setPricePerDay(priceResponse.getPriceRange().getPerDay());
            vehicle.setPricePerWeek(priceResponse.getPriceRange().getPerWeek());
            vehicle.setPricePerMonth(priceResponse.getPriceRange().getPerMonth());
        }

        vehicle.setCurrencyCode(priceResponse.getCurrencyCode());

        return vehicle;
    }
}
