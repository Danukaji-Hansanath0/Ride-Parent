package com.ride.clientbff.dto;

import lombok.*;

import java.util.List;

/**
 * DTO for paginated vehicle search response.
 * Contains paginated results with pagination metadata.
 */
@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class PaginatedVehicleSearchResponseDto {

    /**
     * List of available vehicles for this page.
     */
    private List<AvailableVehicleDto> vehicles;

    /**
     * Current page number (0-indexed).
     */
    private int pageNumber;

    /**
     * Number of items per page.
     */
    private int pageSize;

    /**
     * Total number of available vehicles across all pages.
     */
    private long totalElements;

    /**
     * Total number of pages.
     */
    private int totalPages;

    /**
     * Whether this is the last page.
     */
    private boolean last;

    /**
     * Whether this is the first page.
     */
    private boolean first;

    /**
     * Whether search was successful.
     */
    private boolean success;

    /**
     * Response message.
     */
    private String message;
}
