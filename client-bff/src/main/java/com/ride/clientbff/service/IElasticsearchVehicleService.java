package com.ride.clientbff.service;

import com.ride.clientbff.dto.AdvancedVehicleSearchRequestDto;
import com.ride.clientbff.dto.PaginatedVehicleSearchResponseDto;

/**
 * Interface for Elasticsearch Vehicle Service.
 * Provides high-performance search capabilities using Elasticsearch.
 */
public interface IElasticsearchVehicleService {

    /**
     * Searches vehicles using Elasticsearch with advanced filtering options.
     *
     * @param searchRequest the search criteria
     * @return paginated search results
     */
    PaginatedVehicleSearchResponseDto searchVehicles(AdvancedVehicleSearchRequestDto searchRequest);
}
