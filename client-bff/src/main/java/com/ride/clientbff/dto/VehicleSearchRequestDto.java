package com.ride.clientbff.dto;

import lombok.*;
import lombok.experimental.SuperBuilder;

import java.time.LocalDate;
import java.time.LocalTime;

/**
 * DTO for vehicle search request from client.
 * Contains search criteria: location, pickup time, drop-off time, and date
 * range.
 */
@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
@SuperBuilder
public class VehicleSearchRequestDto {

    /**
     * Pickup location (city, address, or location code).
     * Example: "Colombo", "New York", "123 Main St"
     */
    private String pickupLocation;

    /**
     * Pickup date (start date of rental).
     */
    private LocalDate pickupDate;

    /**
     * Pickup time (what time the customer wants to pick up the vehicle).
     * Example: "09:00", "14:30"
     */
    private LocalTime pickupTime;

    /**
     * Drop-off date (end date of rental).
     */
    private LocalDate dropOffDate;

    /**
     * Drop-off time (what time the customer wants to return the vehicle).
     * Example: "17:00", "10:00"
     */
    private LocalTime dropOffTime;
}
