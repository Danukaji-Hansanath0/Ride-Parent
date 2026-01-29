package com.ride.clientbff.dto;

import lombok.*;

import java.util.List;

/**
 * DTO for vehicle search response.
 * Contains list of available vehicles matching search criteria and metadata.
 */
@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class VehicleSearchResponseDto {

    /**
     * List of available vehicles matching the search criteria.
     */
    private List<AvailableVehicleDto> vehicles;

    /**
     * Total number of available vehicles found.
     */
    private int totalVehicles;

    /**
     * Search was successful.
     */
    private boolean success;

    /**
     * Message describing the search result.
     */
    private String message;
}
