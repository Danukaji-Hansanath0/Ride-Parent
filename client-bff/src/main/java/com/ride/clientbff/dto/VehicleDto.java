package com.ride.clientbff.dto;

import lombok.*;

import java.time.LocalDate;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class VehicleDto {
    private String userId;
    private String vehicleId;
    private String bodyTypeId;
    private LocalDate vehicleAddedDate;
    private LocalDate vehicleEndDate;
    private double perDayCost;
    private double perWeekCost;
    private double perMonthCost;
}
