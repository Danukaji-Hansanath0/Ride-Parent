package com.ride.clientbff.dto;

import lombok.*;

import java.time.LocalDate;
import java.util.UUID;

/**
 * DTO for available vehicle in search results.
 * Contains vehicle details including pricing information.
 * Uses OwnersHasVehicle ID from Vehicle Service as the unique identifier.
 */
@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class AvailableVehicleDto {

    /**
     * OwnersHasVehicle ID (primary identifier for pricing).
     * This is the ID returned from Vehicle Service when registering a vehicle to an
     * owner.
     * Used as vehicleId in the Pricing Service.
     */
    private UUID ownerHasVehicleId;

    /**
     * Actual vehicle ID (from vehicles table).
     */
    private UUID vehicleId;

    /**
     * Owner/User ID (vehicle owner).
     */
    private UUID ownerId;

    /**
     * Vehicle body type (e.g., "SUV", "SEDAN", "HATCHBACK").
     */
    private String bodyType;

    /**
     * Vehicle make (e.g., "Toyota", "Tesla").
     */
    private String make;

    /**
     * Vehicle model (e.g., "Camry", "Model 3").
     */
    private String model;

    /**
     * Vehicle year.
     */
    private String year;

    /**
     * URL of the main vehicle image.
     */
    private String imageUrl;

    /**
     * Pickup location of the vehicle (where owner made it available).
     */
    private String location;

    /**
     * Vehicle availability start date.
     */
    private LocalDate availableFrom;

    /**
     * Vehicle availability end date.
     */
    private LocalDate availableUntil;

    /**
     * Daily rental price (with commission applied).
     */
    private double pricePerDay;

    /**
     * Weekly rental price (with commission applied).
     */
    private double pricePerWeek;

    /**
     * Monthly rental price (with commission applied).
     */
    private double pricePerMonth;

    /**
     * Currency code for pricing (e.g., "USD", "LKR", "EUR").
     */
    private String currencyCode;

    /**
     * Total rental cost for the search date range.
     * Calculated based on number of days and applicable pricing tier.
     */
    private double totalCost;

    /**
     * Number of rental days for the search period.
     */
    private int rentalDays;
}
