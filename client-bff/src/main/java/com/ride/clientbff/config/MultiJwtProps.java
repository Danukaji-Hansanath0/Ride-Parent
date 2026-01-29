package com.ride.clientbff.config;
import org.springframework.boot.context.properties.ConfigurationProperties;
/**
 * Configuration properties for multi-realm JWT authentication.
 * Supports both user-authentication and service-authentication realms.
 *
 * @param userIssuer    Issuer URI for user-authentication realm (end users)
 * @param serviceIssuer Issuer URI for service-authentication realm (services)
 */
@ConfigurationProperties(prefix = "spring.security.oauth2.multi-jwt")
public record MultiJwtProps(
        String userIssuer,
        String serviceIssuer
) {
}
