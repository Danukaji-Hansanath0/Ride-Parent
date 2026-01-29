package com.ride.clientbff.dto;

import lombok.*;

/**
 * DTO for pricing response from Pricing Service.
 * Used internally to parse the pricing service API response.
 */
@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class PriceResponseDto {

    /**
     * Price range details (daily, weekly, monthly prices).
     */
    private PriceRangeDto priceRange;

    /**
     * Currency code for the pricing.
     */
    private String currencyCode;
}
