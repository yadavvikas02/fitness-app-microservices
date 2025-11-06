package com.fitness.gateway;

import com.fitness.gateway.user.RegisterRequest;
import com.fitness.gateway.user.UserService;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import org.springframework.web.server.WebFilter;
import org.springframework.web.server.WebFilterChain;
import reactor.core.publisher.Mono;

@Slf4j
@Component
@RequiredArgsConstructor
public class KeycloakUserSyncFilter implements WebFilter {

    private final UserService userService;

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
        String token = exchange.getRequest().getHeaders().getFirst("Authorization");

        if (token == null || !token.startsWith("Bearer ")) {
            log.warn("No valid Bearer token found. Continuing request without Keycloak sync.");
            return chain.filter(exchange);
        }

        RegisterRequest registerRequest = getUserDetails(token);
        if (registerRequest == null) {
            log.error("Failed to parse Keycloak token into RegisterRequest.");
            return chain.filter(exchange);
        }

        String userId = exchange.getRequest().getHeaders().getFirst("X-User-ID");
        if (userId == null) {
            userId = registerRequest.getKeycloakId();
        }

        String finalUserId = userId;

        return userService.validateUser(finalUserId)
                .flatMap(exists -> {
                    if (!exists) {
                        log.info("User does not exist. Registering new user: {}", registerRequest.getEmail());
                        return userService.registerUser(registerRequest).then();
                    } else {
                        log.info("User already exists, skipping registration.");
                        return Mono.empty();
                    }
                })
                .onErrorResume(e -> {
                    log.error("Error validating or registering user: {}", e.getMessage());
                    return Mono.empty();
                })
                .then(Mono.defer(() -> {
                    ServerHttpRequest mutatedRequest = exchange.getRequest()
                            .mutate()
                            .header("X-User-ID", finalUserId)
                            .build();
                    return chain.filter(exchange.mutate().request(mutatedRequest).build());
                }));
    }

    private RegisterRequest getUserDetails(String token) {
        try {
            String tokenWithoutBearer = token.replace("Bearer ", "").trim();
            SignedJWT signedJWT = SignedJWT.parse(tokenWithoutBearer);
            JWTClaimsSet claims = signedJWT.getJWTClaimsSet();

            RegisterRequest registerRequest = new RegisterRequest();
            registerRequest.setEmail(claims.getStringClaim("email"));
            registerRequest.setKeycloakId(claims.getStringClaim("sub"));
            registerRequest.setPassword("dummy@123123");
            registerRequest.setFirstName(claims.getStringClaim("given_name"));
            registerRequest.setLastName(claims.getStringClaim("family_name"));
            return registerRequest;
        } catch (Exception e) {
            log.error("Failed to extract user details from token: {}", e.getMessage());
            return null;
        }
    }
}
