package com.ride.clientbff.dto;

import lombok.*;

/**
 * DTO for price range details from Pricing Service.
 * Contains daily, weekly, and monthly prices.
 */
@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class PriceRangeDto {

    /**
     * Daily rental price (with commission applied).
     */
    private double perDay;

    /**
     * Weekly rental price (with commission applied).
     */
    private double perWeek;

    /**
     * Monthly rental price (with commission applied).
     */
    private double perMonth;
}
