package com.ride.clientbff.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;

import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * Security Configuration for Client BFF Service
 * Supports dual JWT authentication from both user-authentication and service-authentication realms
 *
 * @author Ride Platform Team
 * @version 1.0.0
 * @since 2026-01-26
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {

    @Value("${keycloak.user-realm.issuer-uri:http://57.128.201.210:8083/realms/user-authentication}")
    private String userRealmIssuerUri;

    @Value("${keycloak.service-realm.issuer-uri:http://57.128.201.210:8083/realms/service-authentication}")
    private String serviceRealmIssuerUri;

    private static final String[] PUBLIC_ENDPOINTS = {
            "/actuator/health",
            "/actuator/info",
            "/v3/api-docs/**",
            "/swagger-ui/**",
            "/swagger-ui.html",
            "/swagger/**",
            "/docs/**",
            "/webjars/**",
            "/swagger-resources/**"
    };

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .csrf(AbstractHttpConfigurer::disable)
                .cors(cors -> cors.configure(http))
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(authz -> authz
                        .requestMatchers(PUBLIC_ENDPOINTS).permitAll()
                        // All client-bff endpoints require CUSTOMER role
                        .anyRequest().hasAnyRole("CUSTOMER", "ADMIN", "SERVICE")
                )
                .oauth2ResourceServer(oauth2 -> oauth2
                        .jwt(jwt -> jwt
                                .decoder(multiRealmJwtDecoder())
                                .jwtAuthenticationConverter(jwtAuthenticationConverter())
                        )
                );

        return http.build();
    }

    /**
     * Multi-realm JWT decoder supporting both user and service authentication realms
     */
    @Bean
    public JwtDecoder multiRealmJwtDecoder() {
        NimbusJwtDecoder userRealmDecoder = NimbusJwtDecoder.withIssuerLocation(userRealmIssuerUri).build();
        NimbusJwtDecoder serviceRealmDecoder = NimbusJwtDecoder.withIssuerLocation(serviceRealmIssuerUri).build();

        return token -> {
            try {
                return userRealmDecoder.decode(token);
            } catch (JwtException userRealmException) {
                try {
                    return serviceRealmDecoder.decode(token);
                } catch (JwtException serviceRealmException) {
                    throw new JwtException("Token validation failed for both realms", serviceRealmException);
                }
            }
        };
    }

    /**
     * JWT Authentication Converter extracts roles from both realm_access and resource_access claims
     */
    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(jwt -> {
            // Extract realm roles
            Map<String, Object> realmAccess = jwt.getClaimAsMap("realm_access");
            List<String> realmRoles = realmAccess != null && realmAccess.get("roles") != null
                    ? (List<String>) realmAccess.get("roles")
                    : Collections.emptyList();

            // Extract resource/client roles
            Map<String, Object> resourceAccess = jwt.getClaimAsMap("resource_access");
            List<String> resourceRoles = new ArrayList<>();
            if (resourceAccess != null) {
                resourceAccess.values().forEach(resource -> {
                    if (resource instanceof Map) {
                        Map<String, Object> resourceMap = (Map<String, Object>) resource;
                        List<String> roles = (List<String>) resourceMap.get("roles");
                        if (roles != null) {
                            resourceRoles.addAll(roles);
                        }
                    }
                });
            }

            // Combine and convert to Spring authorities
            return Stream.concat(realmRoles.stream(), resourceRoles.stream())
                    .distinct()
                    .map(role -> new SimpleGrantedAuthority("ROLE_" + role.toUpperCase()))
                    .collect(Collectors.toList());
        });
        return converter;
    }
}
