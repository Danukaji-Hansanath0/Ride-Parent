package com.ride.clientbff.service.impl;

import com.ride.clientbff.dto.AdvancedVehicleSearchRequestDto;
import com.ride.clientbff.dto.AvailableVehicleDto;
import com.ride.clientbff.dto.PaginatedVehicleSearchResponseDto;
import com.ride.clientbff.repository.elasticsearch.VehiclesSearchDocument;
import com.ride.clientbff.repository.elasticsearch.VehicleSearchRepository;
import com.ride.clientbff.service.IElasticsearchVehicleService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.elasticsearch.core.ElasticsearchOperations;
import org.springframework.data.elasticsearch.core.SearchHit;
import org.springframework.data.elasticsearch.core.SearchHits;
import org.springframework.data.elasticsearch.core.geo.GeoPoint;
import org.springframework.data.elasticsearch.core.query.Criteria;
import org.springframework.data.elasticsearch.core.query.CriteriaQuery;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

/**
 * Implementation of Elasticsearch Vehicle Service.
 * Uses Spring Data Elasticsearch Repository to query the vehicle index.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ElasticsearchVehicleService implements IElasticsearchVehicleService {

    private final VehicleSearchRepository vehicleSearchRepository;
    private final ElasticsearchOperations elasticsearchOperations;

    @Override
    public PaginatedVehicleSearchResponseDto searchVehicles(AdvancedVehicleSearchRequestDto searchRequest) {
        log.info("Searching vehicles in Elasticsearch. Location: {}, Lat: {}, Lon: {}",
                searchRequest.getPickupLocation(), searchRequest.getLatitude(), searchRequest.getLongitude());

        // Build Criteria
        Criteria criteria = new Criteria("status").is("AVAILABLE"); // Default to available

        // Location - Text based
        if (searchRequest.getPickupLocation() != null && !searchRequest.getPickupLocation().isEmpty()) {
            criteria = criteria.and(new Criteria("location").contains(searchRequest.getPickupLocation()));
        }

        // Geospatial Search
        if (searchRequest.getLatitude() != null && searchRequest.getLongitude() != null) {
            double radius = searchRequest.getRadiusKm() != null ? searchRequest.getRadiusKm() : 50.0;
            criteria = criteria.and(new Criteria("locationGeo")
                    .within(new GeoPoint(searchRequest.getLatitude(), searchRequest.getLongitude()), radius + "km"));
        }

        // Basic Filters
        if (searchRequest.getBodyTypeFilter() != null && !searchRequest.getBodyTypeFilter().isEmpty()) {
            criteria = criteria.and(new Criteria("bodyType").is(searchRequest.getBodyTypeFilter()));
        }
        if (searchRequest.getMinPrice() != null) {
            criteria = criteria.and(new Criteria("pricePerDay").greaterThanEqual(searchRequest.getMinPrice()));
        }
        if (searchRequest.getMaxPrice() != null) {
            criteria = criteria.and(new Criteria("pricePerDay").lessThanEqual(searchRequest.getMaxPrice()));
        }

        // Pagination & Sorting
        Sort sort = createSort(searchRequest.getSortBy(), searchRequest.getSortDirection());
        Pageable pageable = PageRequest.of(searchRequest.getPageNumber(), searchRequest.getPageSize(), sort);

        CriteriaQuery query = new CriteriaQuery(criteria);
        query.setPageable(pageable);

        // Execute Search
        SearchHits<VehiclesSearchDocument> searchHits = elasticsearchOperations.search(query,
                VehiclesSearchDocument.class);

        return mapToResponse(searchHits, pageable);
    }

    private Sort createSort(String sortBy, String sortDirection) {
        Sort.Direction direction = Sort.Direction.ASC;
        if (sortDirection != null && sortDirection.equalsIgnoreCase("DESC")) {
            direction = Sort.Direction.DESC;
        }

        String sortField = "pricePerDay"; // default
        if (sortBy != null && !sortBy.isEmpty()) {
            sortField = sortBy;
        }

        return Sort.by(direction, sortField);
    }

    private PaginatedVehicleSearchResponseDto mapToResponse(SearchHits<VehiclesSearchDocument> searchHits,
            Pageable pageable) {
        List<AvailableVehicleDto> vehicles = searchHits.getSearchHits().stream()
                .map(SearchHit::getContent)
                .map(this::mapToDto)
                .collect(Collectors.toList());

        long totalHits = searchHits.getTotalHits();
        int totalPages = (int) Math.ceil((double) totalHits / pageable.getPageSize());

        return PaginatedVehicleSearchResponseDto.builder()
                .vehicles(vehicles)
                .pageNumber(pageable.getPageNumber())
                .pageSize(pageable.getPageSize())
                .totalElements(totalHits)
                .totalPages(totalPages)
                .first(pageable.getPageNumber() == 0)
                .last(pageable.getPageNumber() >= totalPages - 1)
                .success(true)
                .message("Found " + totalHits + " vehicles")
                .build();
    }

    private AvailableVehicleDto mapToDto(VehiclesSearchDocument doc) {
        return AvailableVehicleDto.builder()
                // Map fields from doc to dto
                .vehicleId(java.util.UUID.fromString(doc.getVehicleId())) // Use correct IDs
                .make(doc.getMake())
                .model(doc.getModel())
                .year(doc.getYear())
                .bodyType(doc.getBodyType())
                .pricePerDay(doc.getPricePerDay() != null ? doc.getPricePerDay() : 0.0)
                .location("N/A") // Location isn't explicit in doc except maybe implicit from search? Add if
                                 // needed.
                // Address other fields...
                .imageUrl(doc.getImages() != null && !doc.getImages().isEmpty() ? doc.getImages().get(0) : null)
                .build();
    }
}
