package com.ride.clientbff.config;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.stereotype.Component;
import java.util.ArrayList;
import java.util.List;
/**
 * Custom JWT decoder that supports multiple Keycloak realms.
 * This allows the client-bff to accept tokens from both:
 * - user-authentication realm (for end users - web/mobile clients)
 * - service-authentication realm (for service-to-service communication)
 *
 * The decoder tries each configured realm in sequence until a valid token is found.
 * If all realms fail, it throws a JwtException with details.
 *
 * @see MultiJwtProps
 */
@Component
@Slf4j
public class MultiRealmJwtDecoder implements JwtDecoder {
    private final List<JwtDecoder> decoders;
    private final MultiJwtProps multiJwtProps;
    public MultiRealmJwtDecoder(MultiJwtProps multiJwtProps) {
        this.multiJwtProps = multiJwtProps;
        this.decoders = new ArrayList<>();
        // User realm decoder (for end users accessing the API)
        String userRealmIssuer = multiJwtProps.userIssuer();
        if (userRealmIssuer != null && !userRealmIssuer.isBlank()) {
            JwtDecoder userDecoder = createDecoder(userRealmIssuer);
            decoders.add(userDecoder);
            log.info("✅ User realm decoder configured: {}", userRealmIssuer);
        } else {
            log.warn("⚠️ User realm issuer not configured, user authentication will fail");
        }
        // Service realm decoder (for service-to-service communication)
        String serviceRealmIssuer = multiJwtProps.serviceIssuer();
        if (serviceRealmIssuer != null && !serviceRealmIssuer.isBlank()) {
            JwtDecoder serviceDecoder = createDecoder(serviceRealmIssuer);
            decoders.add(serviceDecoder);
            log.info("✅ Service realm decoder configured: {}", serviceRealmIssuer);
        } else {
            log.warn("⚠️ Service realm issuer not configured, service-to-service auth will fail");
        }
        log.info("📋 MultiRealmJwtDecoder initialized with {} realm(s)", decoders.size());
    }
    /**
     * Creates a JWT decoder for the specified issuer with validation.
     *
     * @param issuerUri Keycloak realm issuer URI
     * @return Configured JwtDecoder
     */
    private JwtDecoder createDecoder(String issuerUri) {
        NimbusJwtDecoder decoder = JwtDecoders.fromIssuerLocation(issuerUri);
        // Add issuer validator
        OAuth2TokenValidator<Jwt> validator = JwtValidators.createDefaultWithIssuer(issuerUri);
        decoder.setJwtValidator(validator);
        return decoder;
    }
    /**
     * Decodes and validates the JWT token against all configured realms.
     * Tries each realm in sequence and returns the first successful decode.
     *
     * @param token JWT token string
     * @return Decoded JWT
     * @throws JwtException if token is invalid in all realms
     */
    @Override
    public Jwt decode(String token) throws JwtException {
        List<Exception> exceptions = new ArrayList<>();
        JwtException tokenExpiredException = null;
        // Try each decoder
        for (JwtDecoder decoder : decoders) {
            try {
                Jwt jwt = decoder.decode(token);
                log.debug("✅ Successfully decoded JWT from issuer: {}", jwt.getIssuer());
                return jwt;
            } catch (JwtException e) {
                log.debug("❌ Failed to decode with decoder: {}", e.getMessage());
                exceptions.add(e);
                // Check if this is a token expiration error
                if (e.getMessage() != null && e.getMessage().contains("expired")) {
                    tokenExpiredException = e;
                }
            }
        }
        // If token is expired, throw that specific error
        if (tokenExpiredException != null) {
            log.error("🔴 JWT token has expired");
            throw tokenExpiredException;
        }
        // If all decoders failed for other reasons, throw the first exception
        log.error("🔴 Failed to decode JWT with any of the {} configured realm(s)", decoders.size());
        throw new JwtException("Unable to decode JWT with any configured realm: " + 
                (exceptions.isEmpty() ? "No decoders configured" : exceptions.get(0).getMessage()), 
                exceptions.isEmpty() ? null : exceptions.get(0));
    }
}
