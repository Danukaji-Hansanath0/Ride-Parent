package com.ride.clientbff.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * DTO for pricing information from pricing-service.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PricingDto {
    private String id;
    private String vehicleId;
    private BigDecimal pricePerDay;
    private BigDecimal pricePerWeek;
    private BigDecimal pricePerMonth;
    private String currency;
}
