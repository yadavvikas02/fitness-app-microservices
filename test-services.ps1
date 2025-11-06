# PowerShell script to start all services and test endpoints

Write-Host "Starting Fitness App Microservices Testing..." -ForegroundColor Green

# Function to wait for service to be ready
function Wait-ForService {
    param($Url, $ServiceName, $TimeoutSeconds = 60)
    $elapsed = 0
    Write-Host "Waiting for $ServiceName to start..." -ForegroundColor Yellow
    while ($elapsed -lt $TimeoutSeconds) {
        try {
            $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Host "$ServiceName is ready!" -ForegroundColor Green
                Start-Sleep -Seconds 2
                return $true
            }
        } catch {
            Start-Sleep -Seconds 2
            $elapsed += 2
            Write-Host "." -NoNewline
        }
    }
    Write-Host ""
    Write-Host "$ServiceName failed to start within $TimeoutSeconds seconds" -ForegroundColor Red
    return $false
}

# Build all services
Write-Host "`nBuilding all services..." -ForegroundColor Cyan
$services = @("configserver", "eureka", "userservice", "activityservice", "aiservice", "gateway")
foreach ($service in $services) {
    Write-Host "Building $service..." -ForegroundColor Yellow
    Set-Location $service
    mvn clean package -DskipTests -q
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to build $service" -ForegroundColor Red
        exit 1
    }
    Set-Location ..
}

# Start Config Server
Write-Host "`nStarting Config Server..." -ForegroundColor Cyan
Set-Location configserver
$configServer = Start-Process -FilePath "java" -ArgumentList "-jar","target\configserver-0.0.1-SNAPSHOT.jar" -PassThru -WindowStyle Hidden
Set-Location ..
Start-Sleep -Seconds 5

# Start Eureka Server
Write-Host "Starting Eureka Server..." -ForegroundColor Cyan
Set-Location eureka
$eurekaServer = Start-Process -FilePath "java" -ArgumentList "-jar","target\eureka-0.0.1-SNAPSHOT.jar" -PassThru -WindowStyle Hidden
Set-Location ..
Start-Sleep -Seconds 10

# Start User Service
Write-Host "Starting User Service..." -ForegroundColor Cyan
Set-Location userservice
$userService = Start-Process -FilePath "java" -ArgumentList "-jar","target\userservice-0.0.1-SNAPSHOT.jar" -PassThru -WindowStyle Hidden
Set-Location ..
Start-Sleep -Seconds 10

# Start Activity Service
Write-Host "Starting Activity Service..." -ForegroundColor Cyan
Set-Location activityservice
$activityService = Start-Process -FilePath "java" -ArgumentList "-jar","target\activityservice-0.0.1-SNAPSHOT.jar" -PassThru -WindowStyle Hidden
Set-Location ..
Start-Sleep -Seconds 10

# Start AI Service
Write-Host "Starting AI Service..." -ForegroundColor Cyan
Set-Location aiservice
$aiService = Start-Process -FilePath "java" -ArgumentList "-jar","target\aiservice-0.0.1-SNAPSHOT.jar" -PassThru -WindowStyle Hidden
Set-Location ..
Start-Sleep -Seconds 10

# Start Gateway
Write-Host "Starting Gateway..." -ForegroundColor Cyan
Set-Location gateway
$gateway = Start-Process -FilePath "java" -ArgumentList "-jar","target\gateway-0.0.1-SNAPSHOT.jar" -PassThru -WindowStyle Hidden
Set-Location ..
Start-Sleep -Seconds 10

Write-Host "`nAll services started. Waiting for them to be ready..." -ForegroundColor Green
Start-Sleep -Seconds 15

# Test endpoints
Write-Host "`n=== Testing Endpoints ===" -ForegroundColor Green

$testResults = @()

# Test User Service endpoints directly
Write-Host "`nTesting User Service (port 8081)..." -ForegroundColor Cyan

# Test POST /api/users/register
$registerPayload = @{
    email = "test@example.com"
    password = "password123"
    keycloakId = "test-keycloak-id"
    firstName = "Test"
    lastName = "User"
} | ConvertTo-Json

try {
    $response = Invoke-WebRequest -Uri "http://localhost:8081/api/users/register" -Method POST -Body $registerPayload -ContentType "application/json" -ErrorAction Stop
    $testResults += [PSCustomObject]@{
        Service = "User Service"
        Endpoint = "POST /api/users/register"
        Method = "POST"
        Status = $response.StatusCode
        ResponseTime = "N/A"
        Result = "PASS"
        Notes = "User registered successfully"
    }
    $userId = ($response.Content | ConvertFrom-Json).id
    Write-Host "  ✓ POST /api/users/register - PASS" -ForegroundColor Green
} catch {
    $testResults += [PSCustomObject]@{
        Service = "User Service"
        Endpoint = "POST /api/users/register"
        Method = "POST"
        Status = "ERROR"
        ResponseTime = "N/A"
        Result = "FAIL"
        Notes = $_.Exception.Message
    }
    Write-Host "  ✗ POST /api/users/register - FAIL: $($_.Exception.Message)" -ForegroundColor Red
    $userId = "test-user-id"
}

# Test GET /api/users/{userId}
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8081/api/users/$userId" -Method GET -ErrorAction Stop
    $testResults += [PSCustomObject]@{
        Service = "User Service"
        Endpoint = "GET /api/users/{userId}"
        Method = "GET"
        Status = $response.StatusCode
        ResponseTime = "N/A"
        Result = "PASS"
        Notes = "User profile retrieved"
    }
    Write-Host "  ✓ GET /api/users/{userId} - PASS" -ForegroundColor Green
} catch {
    $testResults += [PSCustomObject]@{
        Service = "User Service"
        Endpoint = "GET /api/users/{userId}"
        Method = "GET"
        Status = "ERROR"
        ResponseTime = "N/A"
        Result = "FAIL"
        Notes = $_.Exception.Message
    }
    Write-Host "  ✗ GET /api/users/{userId} - FAIL: $($_.Exception.Message)" -ForegroundColor Red
}

# Test GET /api/users/{userId}/validate
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8081/api/users/$userId/validate" -Method GET -ErrorAction Stop
    $testResults += [PSCustomObject]@{
        Service = "User Service"
        Endpoint = "GET /api/users/{userId}/validate"
        Method = "GET"
        Status = $response.StatusCode
        ResponseTime = "N/A"
        Result = "PASS"
        Notes = "User validation successful"
    }
    Write-Host "  ✓ GET /api/users/{userId}/validate - PASS" -ForegroundColor Green
} catch {
    $testResults += [PSCustomObject]@{
        Service = "User Service"
        Endpoint = "GET /api/users/{userId}/validate"
        Method = "GET"
        Status = "ERROR"
        ResponseTime = "N/A"
        Result = "FAIL"
        Notes = $_.Exception.Message
    }
    Write-Host "  ✗ GET /api/users/{userId}/validate - FAIL: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Activity Service endpoints
Write-Host "`nTesting Activity Service (port 8082)..." -ForegroundColor Cyan

$activityPayload = @{
    userId = $userId
    type = "RUNNING"
    duration = 30
    caloriesBurned = 300
    startTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    additionalMetrics = @{
        distance = 5.0
        pace = "6:00"
    }
} | ConvertTo-Json

# Test POST /api/activities
try {
    $headers = @{
        "X-User-ID" = $userId
        "Content-Type" = "application/json"
    }
    $response = Invoke-WebRequest -Uri "http://localhost:8082/api/activities" -Method POST -Body $activityPayload -Headers $headers -ErrorAction Stop
    $activityId = ($response.Content | ConvertFrom-Json).id
    $testResults += [PSCustomObject]@{
        Service = "Activity Service"
        Endpoint = "POST /api/activities"
        Method = "POST"
        Status = $response.StatusCode
        ResponseTime = "N/A"
        Result = "PASS"
        Notes = "Activity tracked successfully"
    }
    Write-Host "  ✓ POST /api/activities - PASS" -ForegroundColor Green
} catch {
    $testResults += [PSCustomObject]@{
        Service = "Activity Service"
        Endpoint = "POST /api/activities"
        Method = "POST"
        Status = "ERROR"
        ResponseTime = "N/A"
        Result = "FAIL"
        Notes = $_.Exception.Message
    }
    Write-Host "  ✗ POST /api/activities - FAIL: $($_.Exception.Message)" -ForegroundColor Red
    $activityId = "test-activity-id"
}

# Test GET /api/activities
try {
    $headers = @{"X-User-ID" = $userId}
    $response = Invoke-WebRequest -Uri "http://localhost:8082/api/activities" -Method GET -Headers $headers -ErrorAction Stop
    $testResults += [PSCustomObject]@{
        Service = "Activity Service"
        Endpoint = "GET /api/activities"
        Method = "GET"
        Status = $response.StatusCode
        ResponseTime = "N/A"
        Result = "PASS"
        Notes = "Activities retrieved successfully"
    }
    Write-Host "  ✓ GET /api/activities - PASS" -ForegroundColor Green
} catch {
    $testResults += [PSCustomObject]@{
        Service = "Activity Service"
        Endpoint = "GET /api/activities"
        Method = "GET"
        Status = "ERROR"
        ResponseTime = "N/A"
        Result = "FAIL"
        Notes = $_.Exception.Message
    }
    Write-Host "  ✗ GET /api/activities - FAIL: $($_.Exception.Message)" -ForegroundColor Red
}

# Test GET /api/activities/{activityId}
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8082/api/activities/$activityId" -Method GET -ErrorAction Stop
    $testResults += [PSCustomObject]@{
        Service = "Activity Service"
        Endpoint = "GET /api/activities/{activityId}"
        Method = "GET"
        Status = $response.StatusCode
        ResponseTime = "N/A"
        Result = "PASS"
        Notes = "Activity retrieved successfully"
    }
    Write-Host "  ✓ GET /api/activities/{activityId} - PASS" -ForegroundColor Green
} catch {
    $testResults += [PSCustomObject]@{
        Service = "Activity Service"
        Endpoint = "GET /api/activities/{activityId}"
        Method = "GET"
        Status = "ERROR"
        ResponseTime = "N/A"
        Result = "FAIL"
        Notes = $_.Exception.Message
    }
    Write-Host "  ✗ GET /api/activities/{activityId} - FAIL: $($_.Exception.Message)" -ForegroundColor Red
}

# Test AI Service endpoints
Write-Host "`nTesting AI Service (port 8083)..." -ForegroundColor Cyan

# Test GET /api/recommendations/user/{userId}
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8083/api/recommendations/user/$userId" -Method GET -ErrorAction Stop
    $testResults += [PSCustomObject]@{
        Service = "AI Service"
        Endpoint = "GET /api/recommendations/user/{userId}"
        Method = "GET"
        Status = $response.StatusCode
        ResponseTime = "N/A"
        Result = "PASS"
        Notes = "Recommendations retrieved"
    }
    Write-Host "  ✓ GET /api/recommendations/user/{userId} - PASS" -ForegroundColor Green
} catch {
    $testResults += [PSCustomObject]@{
        Service = "AI Service"
        Endpoint = "GET /api/recommendations/user/{userId}"
        Method = "GET"
        Status = "ERROR"
        ResponseTime = "N/A"
        Result = "FAIL"
        Notes = $_.Exception.Message
    }
    Write-Host "  ✗ GET /api/recommendations/user/{userId} - FAIL: $($_.Exception.Message)" -ForegroundColor Red
}

# Test GET /api/recommendations/activity/{activityId}
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8083/api/recommendations/activity/$activityId" -Method GET -ErrorAction Stop
    $testResults += [PSCustomObject]@{
        Service = "AI Service"
        Endpoint = "GET /api/recommendations/activity/{activityId}"
        Method = "GET"
        Status = $response.StatusCode
        ResponseTime = "N/A"
        Result = "PASS"
        Notes = "Activity recommendation retrieved"
    }
    Write-Host "  ✓ GET /api/recommendations/activity/{activityId} - PASS" -ForegroundColor Green
} catch {
    $testResults += [PSCustomObject]@{
        Service = "AI Service"
        Endpoint = "GET /api/recommendations/activity/{activityId}"
        Method = "GET"
        Status = "ERROR"
        ResponseTime = "N/A"
        Result = "FAIL"
        Notes = $_.Exception.Message
    }
    Write-Host "  ✗ GET /api/recommendations/activity/{activityId} - FAIL: $($_.Exception.Message)" -ForegroundColor Red
}

# Generate Report
Write-Host "`n=== TEST REPORT ===" -ForegroundColor Green
$testResults | Format-Table -AutoSize

$totalTests = $testResults.Count
$passedTests = ($testResults | Where-Object {$_.Result -eq "PASS"}).Count
$failedTests = ($testResults | Where-Object {$_.Result -eq "FAIL"}).Count

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  Total Endpoints Tested: $totalTests" -ForegroundColor White
Write-Host "  Passed: $passedTests" -ForegroundColor Green
Write-Host "  Failed: $failedTests" -ForegroundColor Red

# Export to CSV
$testResults | Export-Csv -Path "test-results.csv" -NoTypeInformation
Write-Host "`nDetailed results exported to test-results.csv" -ForegroundColor Yellow

Write-Host "`nPress any key to stop all services..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Stop all services
Write-Host "`nStopping all services..." -ForegroundColor Yellow
Stop-Process -Id $configServer.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $eurekaServer.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $userService.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $activityService.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $aiService.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $gateway.Id -Force -ErrorAction SilentlyContinue

Write-Host "All services stopped." -ForegroundColor Green

