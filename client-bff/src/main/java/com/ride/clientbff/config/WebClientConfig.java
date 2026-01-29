package com.ride.clientbff.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;
import io.netty.channel.ChannelOption;

import java.time.Duration;

/**
 * WebClient configuration for Client BFF external service integrations.
 * Configures WebClients for Vehicle Service and Pricing Service APIs.
 */
@Configuration
@Slf4j
public class WebClientConfig {

    @Value("${services.vehicleServiceUrl:http://vehicle-service:8084}")
    private String vehicleServiceUrl;

    @Value("${services.pricingServiceUrl:http://pricing-service:8082}")
    private String pricingServiceUrl;

    /**
     * Creates a WebClient bean for Vehicle Service API calls.
     *
     * @param builder WebClient builder
     * @return configured WebClient for vehicle service
     */
    @Bean(name = "vehicleServiceWebClient")
    public WebClient vehicleServiceWebClient(WebClient.Builder builder) {
        log.info("Configuring WebClient for Vehicle Service at: {}", vehicleServiceUrl);

        HttpClient httpClient = createHttpClient();

        return builder
                .baseUrl(vehicleServiceUrl)
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .defaultHeader("Content-Type", "application/json")
                .defaultHeader("Accept", "application/json")
                .build();
    }

    /**
     * Creates a WebClient bean for Pricing Service API calls.
     *
     * @param builder WebClient builder
     * @return configured WebClient for pricing service
     */
    @Bean(name = "pricingServiceWebClient")
    public WebClient pricingServiceWebClient(WebClient.Builder builder) {
        log.info("Configuring WebClient for Pricing Service at: {}", pricingServiceUrl);

        HttpClient httpClient = createHttpClient();

        return builder
                .baseUrl(pricingServiceUrl)
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .defaultHeader("Content-Type", "application/json")
                .defaultHeader("Accept", "application/json")
                .build();
    }

    /**
     * Creates a configured HttpClient with timeout settings.
     *
     * @return configured HttpClient
     */
    private HttpClient createHttpClient() {
        return HttpClient.create()
                .responseTimeout(Duration.ofSeconds(30))
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 10000);
    }
}
