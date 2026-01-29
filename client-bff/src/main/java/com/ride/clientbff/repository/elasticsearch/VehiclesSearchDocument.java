package com.ride.clientbff.repository.elasticsearch;

import org.springframework.data.annotation.Id;
import lombok.*;
import org.springframework.data.elasticsearch.annotations.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/**
 * Elasticsearch document for Vehicle Search.
 * Maps to 'vehicle_search' index managed by vehicle-service.
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Document(indexName = "vehicle_search")
public class VehiclesSearchDocument {
        // elasticsearch Id , use OwnerHasVehicle id
        @Id
        private String id;

        @MultiField(mainField = @Field(type = FieldType.Text), otherFields = {
                        @InnerField(suffix = "keyword", type = FieldType.Keyword) })
        private String make;

        @MultiField(mainField = @Field(type = FieldType.Text), otherFields = {
                        @InnerField(suffix = "keyword", type = FieldType.Keyword) })
        private String model;

        @Field(type = FieldType.Keyword)
        private String year;
        @Field(type = FieldType.Keyword)
        private String submodel;

        @Field(type = FieldType.Keyword)
        private String transmission;

        @Field(type = FieldType.Keyword)
        private String fuelType;

        @Field(type = FieldType.Integer)
        private Integer seats;

        @Field(type = FieldType.Integer)
        private Integer doors;

        @Field(type = FieldType.Keyword)
        private String drivetrain;

        @Field(type = FieldType.Keyword)
        private String engineType;

        @Field(type = FieldType.Double)
        private Double engineDisplacement;

        @Field(type = FieldType.Keyword)
        private String vehicleId;
        // OPTIONAL: if you want search/filter by color names
        @Field(type = FieldType.Keyword)
        private List<String> colors;

        @Field(type = FieldType.Keyword)
        private List<String> images;

        // Structured color+image data for detailed display
        @Field(type = FieldType.Nested)
        private List<VehicleColorImageDocument> colorImages;

        // -------------------------
        // Pricing-service fields
        // -------------------------

        @Field(type = FieldType.Double)
        private Double pricePerDay;

        @Field(type = FieldType.Double)
        private Double pricePerWeek;

        @Field(type = FieldType.Double)
        private Double pricePerMonth;

        @Field(type = FieldType.Double)
        private Double discountPercent;

        @Field(type = FieldType.Keyword)
        private String currency;

        @Field(type = FieldType.Double)
        private Double commissionPercent;

        // Pricing availability flag - indicates if pricing data is available
        @Field(type = FieldType.Boolean)
        private Boolean pricingAvailable;

        // Mostly searching by
        @Field(type = FieldType.Keyword)
        private String bodyType;

        @Field(type = FieldType.Keyword)
        private LocalDate availableFrom;

        @Field(type = FieldType.Keyword)
        private LocalDate availableUntil;

        @Field(type = FieldType.Boolean)
        private Boolean active;

        // If you need user filtering (owner / renter). From pricing you already have
        // userId.
        @Field(type = FieldType.Keyword)
        private String userId;

        // Status from OwnerHasVehicle (AVAILABLE, UNAVAILABLE, MAINTENANCE)
        @Field(type = FieldType.Keyword)
        private String status;

        // Reason for last update (helps with audit trail)
        @Field(type = FieldType.Text)
        private String updateReason;

        // Location (City/Area e.g., "Colombo", "Katunayake")
        @MultiField(mainField = @Field(type = FieldType.Text), otherFields = {
                        @InnerField(suffix = "keyword", type = FieldType.Keyword) })
        private String location;

        @Field(type = FieldType.Auto)
        private org.springframework.data.elasticsearch.core.geo.GeoPoint locationGeo;

        // -------------------------
        // Timestamps (very useful)
        // -------------------------

        @Field(type = FieldType.Date)
        private Instant indexedAt;

        // per-section updated times help avoid stale overwrites
        @Field(type = FieldType.Date)
        private Instant vehicleUpdatedAt;

        @Field(type = FieldType.Date)
        private Instant pricingUpdatedAt;

        @Field(type = FieldType.Date)
        private Instant updatedAt;
}
