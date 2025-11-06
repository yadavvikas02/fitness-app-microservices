# Troubleshooting Guide - 404 Errors

## Issue: Gateway returning 404 for `/api/activities`

### Root Cause
The gateway routes might not be matching the service names correctly, or services aren't registered in Eureka.

### Solutions to Try

#### 1. **Restart Config Server** (MOST IMPORTANT)
The gateway configuration is stored in Config Server. After updating `api-gateway.yml`, you MUST restart:
- Config Server
- API Gateway

```powershell
# Stop all services
# Then restart in this order:
# 1. Config Server (port 8888)
# 2. Eureka Server (port 8761)
# 3. User Service (port 8081)
# 4. Activity Service (port 8082)
# 5. AI Service (port 8083)
# 6. API Gateway (port 8080)
```

#### 2. **Verify Service Registration in Eureka**
1. Open browser: http://localhost:8761
2. Check if services are registered:
   - `ACTIVITY-SERVICE` or `activity-service`
   - `USER-SERVICE` or `user-service`
   - `AI-SERVICE` or `ai-service`

3. **If services show uppercase names** → Gateway routes should use `lb://ACTIVITY-SERVICE`
4. **If services show lowercase names** → Gateway routes should use `lb://activity-service`

#### 3. **Current Configuration**
I've updated the gateway to use **lowercase service names** to match the local `application.yml` files:
- `lb://activity-service`
- `lb://user-service`
- `lb://ai-service`

**If your services are registered with uppercase names**, change the gateway config back to:
- `lb://ACTIVITY-SERVICE`
- `lb://USER-SERVICE`
- `lb://AI-SERVICE`

#### 4. **Check Service Discovery**
The gateway uses Spring Cloud LoadBalancer with Eureka. Verify:
- Eureka is running on port 8761
- All services can connect to Eureka
- Services are "UP" in Eureka dashboard

#### 5. **Test Gateway Routes Directly**
After restarting services, test if gateway can reach services:

```bash
# Test activity service through gateway
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/api/activities

# Check gateway logs for routing information
```

#### 6. **Verify Config Server is Working**
Check if services are reading from Config Server:
- Look for log messages like: "Located property source: Config resource"
- Check if services are using the correct ports (8081, 8082, 8083)

#### 7. **Check Service Application Names**
The service registration name comes from `spring.application.name`:

**Local files (fallback):**
- `activityservice/src/main/resources/application.yml` → `activity-service`
- `userservice/src/main/resources/application.yml` → `user-service`
- `aiservice/src/main/resources/application.yml` → `ai-service`

**Config Server overrides:**
- `configserver/src/main/resources/config/activity-service.yml` → `ACTIVITY-SERVICE`
- `configserver/src/main/resources/config/user-service.yml` → `USER-SERVICE`
- `configserver/src/main/resources/config/ai-service.yml` → `AI-SERVICE`

**If Config Server is working**, services register with **uppercase** names.
**If Config Server isn't working**, services register with **lowercase** names.

### Quick Fix Command Sequence

```powershell
# 1. Stop all running services (Ctrl+C in each terminal)

# 2. Start Config Server
cd configserver
java -jar target\configserver-0.0.1-SNAPSHOT.jar

# 3. Wait 5 seconds, then start Eureka (new terminal)
cd eureka
java -jar target\eureka-0.0.1-SNAPSHOT.jar

# 4. Wait 10 seconds, then start services (new terminals)
cd userservice
java -jar target\userservice-0.0.1-SNAPSHOT.jar

cd activityservice
java -jar target\activityservice-0.0.1-SNAPSHOT.jar

cd aiservice
java -jar target\aiservice-0.0.1-SNAPSHOT.jar

# 5. Wait 10 seconds, then start Gateway (new terminal)
cd gateway
java -jar target\gateway-0.0.1-SNAPSHOT.jar

# 6. Check Eureka dashboard: http://localhost:8761
# Verify all services are registered

# 7. Test your frontend again
```

### Alternative: Use Direct Service URLs (For Testing)

If service discovery isn't working, you can temporarily test by using direct URLs in gateway config:

```yaml
routes:
  - id: activity-service
    uri: http://localhost:8082  # Direct URL instead of lb://
    predicates:
      - Path=/api/activities/**
```

**Note:** This bypasses load balancing and is only for testing.

### Expected Behavior After Fix

1. Frontend calls: `GET http://localhost:8080/api/activities`
2. Gateway matches route: `/api/activities/**` → `activity-service`
3. Gateway resolves service: `lb://activity-service` → finds service in Eureka
4. Gateway forwards: `http://activity-service:8082/api/activities`
5. Activity Service receives: `/api/activities` (matches `@RequestMapping("/api/activities")`)
6. Response returns successfully

### Still Getting 404?

1. **Check Gateway Logs**: Look for route matching information
2. **Check Eureka**: Verify service is registered and UP
3. **Check Service Logs**: Verify service is receiving requests
4. **Test Direct Service**: Try `http://localhost:8082/api/activities` directly (with auth token)

