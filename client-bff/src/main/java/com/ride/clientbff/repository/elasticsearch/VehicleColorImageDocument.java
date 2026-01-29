package com.ride.clientbff.repository.elasticsearch;

import lombok.*;
import org.springframework.data.elasticsearch.annotations.Field;
import org.springframework.data.elasticsearch.annotations.FieldType;

/**
 * Nested document for storing vehicle color and associated image URLs in
 * Elasticsearch.
 * Used within VehiclesSearchDocument to provide structured color+image data for
 * search and display.
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VehicleColorImageDocument {

    @Field(type = FieldType.Keyword)
    private String colorName;

    @Field(type = FieldType.Keyword)
    private String highResImageUrl;

    @Field(type = FieldType.Keyword)
    private String thumbnailUrl;
}
