package com.ride.clientbff.service.client;

import com.ride.clientbff.dto.PricingDto;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

/**
 * HTTP client for communication with pricing-service.
 * Fetches pricing information for vehicle indexing.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class PricingServiceClient {

    private final WebClient webClient;

    @Value("${pricing-service.url:http://localhost:8089}")
    private String pricingServiceUrl;

    /**
     * Get pricing for a specific owner-has-vehicle ID.
     *
     * @param ownerHasVehicleId the owner-has-vehicle ID
     * @return pricing information
     */
    public PricingDto getPricing(String ownerHasVehicleId) {
        try {
            log.debug("Fetching pricing for ownerHasVehicleId: {}", ownerHasVehicleId);

            return webClient.get()
                    .uri(pricingServiceUrl + "/api/v1/pricing/{id}", ownerHasVehicleId)
                    .retrieve()
                    .bodyToMono(PricingDto.class)
                    .doOnError(e -> log.error("Failed to fetch pricing: {}", e.getMessage()))
                    .block();

        } catch (Exception e) {
            log.error("Error fetching pricing for vehicle: {}", ownerHasVehicleId, e);
            return null;
        }
    }

    /**
     * Check if vehicle pricing exists.
     *
     * @param ownerHasVehicleId the owner-has-vehicle ID
     * @return true if pricing exists
     */
    public boolean pricingExists(String ownerHasVehicleId) {
        try {
            PricingDto pricing = getPricing(ownerHasVehicleId);
            return pricing != null;
        } catch (Exception e) {
            log.error("Error checking pricing existence: {}", e.getMessage());
            return false;
        }
    }
}
