package com.ride.clientbff.repository.elasticsearch;

import org.springframework.data.elasticsearch.repository.ElasticsearchRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface VehicleSearchRepository extends ElasticsearchRepository<VehiclesSearchDocument, String> {
}
