param()

$ErrorActionPreference = 'Stop'

# Simple cleanup and exit function
function Exit-WithError {
    param($message, $statusCode = 1, $errorType = "general")

    Write-Host "ERROR: $message" -ForegroundColor Red

    if ($errorType -eq "env_name") {
        # For environment name errors, remove .azure folder to force re-setup
        Write-Host "Clearing environment configuration..." -ForegroundColor Yellow
        if (Test-Path ".azure") {
            Remove-Item ".azure" -Recurse -Force
            Write-Host "Environment configuration cleared" -ForegroundColor Yellow
        }
        if (Test-Path ".env") {
            Remove-Item ".env" -Force
            Write-Host "Removed .env file" -ForegroundColor Yellow
        }
        Write-Host "Please run 'azd up' again and choose a valid environment name." -ForegroundColor Green
    } else {
        # General error - completely clean up the environment
        Write-Host "Cleaning up failed deployment environment..." -ForegroundColor Yellow

        try {
            # Get current environment info
            $envName = azd env get-value "AZURE_ENV_NAME" 2>$null
            $resourceGroup = azd env get-value "AZURE_RESOURCE_GROUP" 2>$null

            if ($resourceGroup) {
                Write-Host "Deleting resource group: $resourceGroup" -ForegroundColor Yellow
                az group delete --name $resourceGroup --yes --no-wait 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Resource group deletion initiated (running in background)" -ForegroundColor Green
                } else {
                    Write-Host "Could not delete resource group (it may not exist yet)" -ForegroundColor Yellow
                }
            }

            # Remove environment folder
            if ($envName -and (Test-Path ".azure/$envName")) {
                Remove-Item ".azure/$envName" -Recurse -Force
                Write-Host "Removed environment folder: .azure/$envName" -ForegroundColor Yellow
            }

            # Remove .env file
            if (Test-Path ".env") {
                Remove-Item ".env" -Force
                Write-Host "Removed .env file" -ForegroundColor Yellow
            }

        } catch {
            Write-Host "Error during cleanup: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "=============================================" -ForegroundColor Red
        Write-Host "   DEPLOYMENT STOPPED - QUOTA VALIDATION FAILED" -ForegroundColor Red
        Write-Host "=============================================" -ForegroundColor Red
        Write-Host "Environment has been completely cleaned up!" -ForegroundColor Green
        Write-Host ""
        Write-Host "TO CONTINUE:" -ForegroundColor Cyan
        Write-Host "  1. Run 'azd env new' and create a new environment" -ForegroundColor Yellow
        Write-Host "  2. Run 'azd up' and choose one of the recommended regions" -ForegroundColor Yellow
        Write-Host "=============================================" -ForegroundColor Red
        Write-Host ""
    }

    exit $statusCode
}

function Test-EnvironmentName {
    Write-Host "Validating environment name..." -ForegroundColor Cyan

    try {
        $envName = azd env get-value "AZURE_ENV_NAME" 2>$null
    } catch {
        Exit-WithError "Failed to get environment name. Please ensure azd is properly configured." "general"
    }

    if ($envName) {
        Write-Host "Environment name: $envName" -ForegroundColor Yellow

        # Check for invalid characters in environment name
        if ($envName -match '[^a-zA-Z0-9-]' -or $envName.Length -gt 50) {
            Write-Host "Invalid environment name detected!" -ForegroundColor Red
            Write-Host "Environment names must:" -ForegroundColor Yellow
            Write-Host "  - Only contain letters, numbers, and hyphens" -ForegroundColor Yellow
            Write-Host "  - Be 50 characters or less" -ForegroundColor Yellow
            Write-Host "  - Current name: '$envName'" -ForegroundColor Red
            Exit-WithError "Environment name '$envName' contains invalid characters or is too long" "env_name"
        }

        Write-Host "Environment name is valid" -ForegroundColor Green
    }
}

function Get-InfraLocation {
    # Check azd environment values first (this is where azd stores the location)
    try {
        $location = azd env get-value "AZURE_LOCATION" 2>$null
        if ($location -and $location.Trim() -ne "") {
            return $location.Trim()
        }
    } catch { }

    # Check azd environment config
    try {
        $envName = azd env get-value "AZURE_ENV_NAME" 2>$null
        if ($envName -and (Test-Path ".azure/$envName/config.json")) {
            $config = Get-Content ".azure/$envName/config.json" -Raw | ConvertFrom-Json
            if ($config.infra.parameters.location) {
                return $config.infra.parameters.location
            }
        }
    } catch { }

    # Check environment variable
    if ($env:AZURE_LOCATION) {
        return $env:AZURE_LOCATION
    }

    # Check parameters file
    if (Test-Path "infra/main.parameters.json") {
        try {
            $params = Get-Content "infra/main.parameters.json" -Raw | ConvertFrom-Json
            if ($params.parameters.location.value) {
                $location = $params.parameters.location.value
                if ($location -match '\$\{([^}]+)\}') {
                    # Extract environment variable name and get its value
                    $envVar = $matches[1] -replace '=.*$', ''
                    return [Environment]::GetEnvironmentVariable($envVar)
                }
                return $location
            }
        } catch { }
    }

    Exit-WithError "Cannot determine infrastructure location"
}

# Get allowed regions (general function for both PostgreSQL and Container Apps)
function Get-AllowedRegions {
    param($failedRegion)

    if (-not (Test-Path "infra/main.bicep")) {
        Exit-WithError "Cannot find infra/main.bicep file"
    }

    try {
        # Read the bicep file line by line and parse the @allowed section
        $bicepLines = Get-Content "infra/main.bicep"
        $regions = @()
        $inAllowedSection = $false
        $foundLocationParam = $false

        for ($i = 0; $i -lt $bicepLines.Count; $i++) {
            $line = $bicepLines[$i].Trim()

            # Look for @allowed([
            if ($line -match '^@allowed\(\[') {
                $inAllowedSection = $true
                continue
            }

            # If we're in the allowed section, collect region names
            if ($inAllowedSection) {
                # Check if this is the end of the allowed section
                if ($line -match '^\]\)') {
                    $inAllowedSection = $false
                    # Check if the next several lines contain "param location string"
                    for ($j = $i+1; $j -lt [Math]::Min($i+10, $bicepLines.Count); $j++) {
                        $nextLine = $bicepLines[$j].Trim()
                        if ($nextLine -match '^param location string') {
                            $foundLocationParam = $true
                            Write-Host "Found location parameter at line $($j+1)" -ForegroundColor Green
                            break
                        }
                    }
                    if ($foundLocationParam) { break }
                    # Reset regions if this wasn't the location parameter
                    $regions = @()
                    continue
                }

                # Extract region name from lines like '  'regionname''
                if ($line -match "^\s*'([^']+)'") {
                    $regions += $matches[1]
                }
            }
        }        if ($regions.Count -gt 0 -and $foundLocationParam) {
            Write-Host "Found $($regions.Count) allowed regions in bicep file" -ForegroundColor Cyan
            # Return all regions except the failed one
            return $regions | Where-Object { $_ -ne $failedRegion.ToLower() }
        } else {
            Write-Host "Could not parse allowed regions from bicep file (found $($regions.Count) regions, location param: $foundLocationParam)" -ForegroundColor Yellow
            Exit-WithError "Failed to parse allowed regions from main.bicep file"
        }

    } catch {
        Exit-WithError "Error parsing main.bicep file: $($_.Exception.Message)"
    }
}# Check Container Apps quota for a specific region
function Test-ContainerAppsQuotaInRegion {
    param($region)

    try {
        # Check if Container Apps provider is registered and available in the region
        $providerInfo = az provider show --namespace Microsoft.App --query "registrationState" -o tsv 2>$null

        if ($providerInfo -ne "Registered") {
            Write-Host "Microsoft.App provider is not registered: $providerInfo" -ForegroundColor Yellow
            return $false
        }

        # Check if the region supports Container Apps by listing available locations
        $locations = az provider show --namespace Microsoft.App --query "resourceTypes[?resourceType=='managedEnvironments'].locations[]" -o tsv 2>$null

        if ($locations) {
            $locationsList = $locations -split "`n" | ForEach-Object { $_.Trim().ToLower().Replace(' ', '') }
            $regionNormalized = $region.ToLower().Replace(' ', '')

            # Check if region is in the supported locations
            $isSupported = $locationsList -contains $regionNormalized

            if ($isSupported) {
                Write-Host "Container Apps is supported in $region" -ForegroundColor Green
                return $true
            } else {
                Write-Host "Container Apps is not supported in $region" -ForegroundColor Yellow
                return $false
            }
        } else {
            Write-Host "Could not retrieve Container Apps location information" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "Error checking Container Apps availability: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Get PostgreSQL SKU configuration from parameters file
function Get-PostgreSQLSkuConfig {
    # First try to get from bicep file (default configuration)
    $defaultSku = "Standard_D2ds_v4"

    if (Test-Path "infra/main.bicep") {
        try {
            $bicepContent = Get-Content "infra/main.bicep" -Raw
            # Look for the postgresServerSku parameter block and extract the name value
            if ($bicepContent -match "param postgresServerSku object = \{[^}]*name:\s*'([^']+)'") {
                $defaultSku = $matches[1]
                Write-Host "Found PostgreSQL SKU in bicep file: $defaultSku" -ForegroundColor Gray
            } elseif ($bicepContent -match 'param postgresServerSku object = \{[^}]*name:\s*"([^"]+)"') {
                $defaultSku = $matches[1]
                Write-Host "Found PostgreSQL SKU in bicep file: $defaultSku" -ForegroundColor Gray
            } else {
                Write-Host "Could not parse PostgreSQL SKU from bicep file, using default: $defaultSku" -ForegroundColor Gray
            }
        } catch {
            Write-Host "Error parsing bicep file: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # Check if overridden in parameters file
    if (Test-Path "infra/main.parameters.json") {
        try {
            $params = Get-Content "infra/main.parameters.json" -Raw | ConvertFrom-Json
            if ($params.parameters.postgresServerSku.value.name) {
                Write-Host "Found PostgreSQL SKU override in parameters file: $($params.parameters.postgresServerSku.value.name)" -ForegroundColor Gray
                return $params.parameters.postgresServerSku.value.name
            }
        } catch { }
    }

    return $defaultSku
}

# Test PostgreSQL SKU availability in a specific region
function Test-PostgreSQLSkuInRegion {
    param($region, $targetSku)

    Write-Host "Checking PostgreSQL SKU availability in $region..." -ForegroundColor Gray

    # Use cmd.exe to properly capture stderr and avoid PowerShell treating az errors as exceptions
    $tempStdOut = [System.IO.Path]::GetTempFileName()
    $tempStdErr = [System.IO.Path]::GetTempFileName()

    try {
        # Execute the command via cmd.exe and capture both stdout and stderr to separate files
        $result = pwsh /c "az postgres flexible-server list-skus --location $region --output json --only-show-errors 1>$tempStdOut 2>$tempStdErr"
        $exitCode = $LASTEXITCODE

        $capabilitiesJson = ""
        $errorOutput = ""

        if (Test-Path $tempStdOut) {
            $capabilitiesJson = Get-Content $tempStdOut -Raw -ErrorAction SilentlyContinue
        }
        if (Test-Path $tempStdErr) {
            $errorOutput = Get-Content $tempStdErr -Raw -ErrorAction SilentlyContinue
        }

        if ($exitCode -ne 0) {
            # Check if this is a "region not supported" error vs general API issue
            if (($errorOutput -match "NoRegisteredProviderFound" -and $errorOutput -match $region) -or
                $errorOutput -match "No registered resource provider found for location.*$region" -or
                $errorOutput -match "Location.*$region.*is not supported" -or
                $errorOutput -match "not available in.*$region") {
                Write-Host "Region $region does not support PostgreSQL Flexible Server" -ForegroundColor Red
                return @{
                    Available = $false
                    VCores = $null
                    Memory = $null
                    Edition = $null
                    AllSkus = $null
                    Reason = "Region $region does not support PostgreSQL Flexible Server"
                }
            } else {
                Write-Host "Could not query PostgreSQL capabilities for $region" -ForegroundColor Yellow
                if ($errorOutput.Length -gt 0) {
                    Write-Host "Error details: $($errorOutput.Substring(0, [Math]::Min(150, $errorOutput.Length)))" -ForegroundColor Gray
                }
                return @{
                    Available = $true  # Assume available to avoid blocking deployments
                    VCores = "Unknown"
                    Memory = "Unknown"
                    Edition = "Unknown"
                    AllSkus = $null
                    Reason = "Could not verify SKU availability"
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($capabilitiesJson)) {
            Write-Host "No capabilities data returned" -ForegroundColor Yellow
            return @{
                Available = $true
                VCores = "Unknown"
                Memory = "Unknown"
                Edition = "Unknown"
                AllSkus = $null
                Reason = "Could not verify SKU availability - proceeding with deployment"
            }
        }

        $capabilities = $capabilitiesJson | ConvertFrom-Json

        # The response is an array with the first element containing all the capabilities
        if ($capabilities -and $capabilities.Count -gt 0 -and $capabilities[0].supportedServerEditions) {
            $allServerEditions = $capabilities[0].supportedServerEditions
            $allSkus = @()

            # Extract all SKUs from all editions
            foreach ($edition in $allServerEditions) {
                if ($edition.supportedServerSkus) {
                    foreach ($sku in $edition.supportedServerSkus) {
                        $allSkus += [PSCustomObject]@{
                            name = $sku.name
                            vCores = $sku.vCores
                            memoryPerVcoreMb = $sku.supportedMemoryPerVcoreMb
                            tier = $edition.name
                            supportedZones = $sku.supportedZones
                        }
                    }
                }
            }

            Write-Host "Found $($allSkus.Count) total server SKUs across all editions" -ForegroundColor Gray

            # Look for our target SKU
            $targetSkuObj = $allSkus | Where-Object { $_.name -eq $targetSku }

            if ($targetSkuObj) {
                Write-Host "Found target SKU: $targetSku in $($targetSkuObj.tier) edition" -ForegroundColor Green
                return @{
                    Available = $true
                    VCores = $targetSkuObj.vCores
                    Memory = "$($targetSkuObj.memoryPerVcoreMb)MB per vCore"
                    Edition = $targetSkuObj.tier
                    AllSkus = $null
                    Reason = $null
                }
            } else {
                Write-Host "Target SKU $targetSku not found" -ForegroundColor Yellow

                # Show some available SKUs for debugging
                $sampleSkus = $allSkus | Where-Object { $_.tier -eq "GeneralPurpose" } | Select-Object -First 5
                if ($sampleSkus) {
                    Write-Host "Available GeneralPurpose SKUs:" -ForegroundColor Gray
                    $sampleSkus | ForEach-Object {
                        Write-Host "   $($_.name) ($($_.vCores) vCores, $($_.memoryPerVcoreMb)MB/vCore)" -ForegroundColor Gray
                    }
                }

                return @{
                    Available = $false
                    VCores = $null
                    Memory = $null
                    Edition = $null
                    AllSkus = $allSkus
                    Reason = "SKU $targetSku not found in available configurations"
                }
            }
        } else {
            # Check if we got a response but with restrictions or empty editions
            if ($capabilities -and $capabilities.Count -gt 0 -and $capabilities[0].reason) {
                $restrictionReason = $capabilities[0].reason
                Write-Host "Region has restrictions: $restrictionReason" -ForegroundColor Yellow
                return @{
                    Available = $true
                    VCores = "Unknown"
                    Memory = "Unknown"
                    Edition = "Unknown"
                    AllSkus = $null
                    Reason = "Region temporarily restricted"
                }
            } else {
                # No capabilities returned - assume available to avoid blocking valid deployments
                Write-Host "No server capabilities returned, proceeding with deployment" -ForegroundColor Yellow
                return @{
                    Available = $true
                    VCores = "Unknown"
                    Memory = "Unknown"
                    Edition = "Unknown"
                    AllSkus = $null
                    Reason = "Could not verify SKU availability - proceeding with deployment"
                }
            }
        }
    } catch {
        # On error parsing JSON, assume available to avoid blocking valid deployments
        Write-Host "Error parsing capabilities data: $($_.Exception.Message)" -ForegroundColor Yellow
        return @{
            Available = $true
            VCores = "Unknown"
            Memory = "Unknown"
            Edition = "Unknown"
            AllSkus = $null
            Reason = "JSON parsing error - proceeding with deployment"
        }
    } finally {
        # Clean up temp files
        if (Test-Path $tempStdOut) {
            Remove-Item $tempStdOut -ErrorAction SilentlyContinue
        }
        if (Test-Path $tempStdErr) {
            Remove-Item $tempStdErr -ErrorAction SilentlyContinue
        }
    }
}

# Find alternative regions with PostgreSQL SKU availability
function Find-PostgreSQLAlternativeRegions {
    param($failedRegion, $targetSku)

    $alternativeRegions = Get-AllowedRegions -failedRegion $failedRegion
    $availableRegions = [System.Collections.ArrayList]::new()

    Write-Host "Checking alternative regions for PostgreSQL SKU availability..." -ForegroundColor Yellow

    foreach ($region in $alternativeRegions) {
        $skuCheck = Test-PostgreSQLSkuInRegion -region $region -targetSku $targetSku

        if ($skuCheck.Available) {
            # Only include regions where we definitively verified availability
            # Exclude regions with "Could not verify", or "Region temporarily restricted" status
            if (-not ($skuCheck.Reason -and ($skuCheck.Reason -match "Could not verify" -or $skuCheck.Reason -match "Region temporarily restricted"))) {
                $null = $availableRegions.Add($region)
                Write-Host "$region has $targetSku available" -ForegroundColor Green
            } else {
                Write-Host "${region}: $($skuCheck.Reason) - excluding from alternatives" -ForegroundColor Gray
            }
        }
    }

    return $availableRegions.ToArray()
}

# Find alternative regions with Container Apps quota
function Find-ContainerAppsAlternativeRegions {
    param($failedRegion)

    $alternativeRegions = Get-AllowedRegions -failedRegion $failedRegion
    $availableRegions = [System.Collections.ArrayList]::new()

    Write-Host "Checking alternative regions for Container Apps quota..." -ForegroundColor Yellow

    foreach ($region in $alternativeRegions) {
        $quotaCheck = Test-ContainerAppsQuotaInRegion -region $region

        if ($quotaCheck) {
            $null = $availableRegions.Add($region)
            Write-Host "$region has sufficient Container Apps quota" -ForegroundColor Green
        } else {
            Write-Host "${region}: Container Apps not available - excluding from alternatives" -ForegroundColor Gray
        }
    }

    return $availableRegions.ToArray()
}

function Test-ContainerAppsQuota {
    Write-Host "Checking Azure Container Apps quota..." -ForegroundColor Cyan

    $infraLocation = Get-InfraLocation
    Write-Host "Checking region: $infraLocation" -ForegroundColor Yellow

    try {
        # Check if Container Apps is available in the region
        $quotaCheck = Test-ContainerAppsQuotaInRegion -region $infraLocation

        if ($quotaCheck) {
            Write-Host "Container Apps quota sufficient in $infraLocation" -ForegroundColor Green
            return
        } else {
            Write-Host "Insufficient Container Apps quota in $infraLocation" -ForegroundColor Red

            # Look for alternative regions
            $alternatives = Find-ContainerAppsAlternativeRegions -failedRegion $infraLocation

            if ($alternatives.Count -gt 0) {
                Write-Host ""
                Write-Host "Alternative regions with sufficient Container Apps quota:" -ForegroundColor Green
                $alternatives | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
                Write-Host ""
                Exit-WithError "Please use one of the above alternative regions for your deployment"
            }
        }
    } catch {
        Write-Host "Could not retrieve Container Apps quota information" -ForegroundColor Yellow
        Write-Host "This might indicate that Container Apps is not available in this region" -ForegroundColor Yellow

        # Still try to find alternative regions
        $alternatives = Find-ContainerAppsAlternativeRegions -failedRegion $infraLocation

        if ($alternatives.Count -gt 0) {
            Write-Host ""
            Write-Host "Alternative regions with Container Apps available:" -ForegroundColor Green
            $alternatives | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
            Write-Host ""
            Exit-WithError "Please use one of the above alternative regions for your deployment"
        }
    }

    Write-Host "Could not retrieve Container Apps quota information" -ForegroundColor Yellow
    Exit-WithError "Error checking Container Apps quota: $($_.Exception.Message)"
}

function Test-PostgreSQLSku {
    Write-Host "Checking PostgreSQL SKU availability..." -ForegroundColor Cyan

    $infraLocation = Get-InfraLocation
    $targetSku = Get-PostgreSQLSkuConfig

    Write-Host "Checking region: $infraLocation" -ForegroundColor Yellow
    Write-Host "Target SKU: $targetSku" -ForegroundColor Yellow

    $skuCheck = Test-PostgreSQLSkuInRegion -region $infraLocation -targetSku $targetSku

    if ($skuCheck.Available) {
        # Check if this is truly available or just "proceeding despite issues"
        if ($skuCheck.Reason -and ($skuCheck.Reason -match "Could not verify" -or $skuCheck.Reason -match "Region temporarily restricted")) {
            # This is not truly available - it's restricted/unverified
            if ($skuCheck.Reason -match "Region temporarily restricted") {
                # For temporarily restricted regions, search for alternatives like we do for unsupported regions
                Write-Host "PostgreSQL is temporarily restricted in $infraLocation" -ForegroundColor Red
                Write-Host "   Reason: Region has temporary restrictions" -ForegroundColor Red

                # Search for alternative regions
                Write-Host "Searching for alternative regions with $targetSku availability..." -ForegroundColor Yellow
                $alternativeRegions = Find-PostgreSQLAlternativeRegions -failedRegion $infraLocation -targetSku $targetSku

                if ($alternativeRegions.Count -gt 0) {
                    Write-Host ""
                    Write-Host "Alternative regions with $targetSku available:" -ForegroundColor Green
                    $alternativeRegions | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
                    Write-Host ""
                    Exit-WithError "Please use one of the above alternative regions for your deployment"
                } else {
                    Write-Host ""
                    Write-Host "No alternative regions found with $targetSku available" -ForegroundColor Red
                    Write-Host ""
                    Write-Host "Suggestions:" -ForegroundColor Cyan
                    Write-Host "  1. Check Azure documentation for PostgreSQL SKU availability by region" -ForegroundColor Yellow
                    Write-Host "  2. Consider using a different PostgreSQL SKU with similar specifications" -ForegroundColor Yellow
                    Write-Host "  3. Request SKU availability in your preferred region through Azure support" -ForegroundColor Yellow
                    Write-Host ""
                    Exit-WithError "PostgreSQL SKU $targetSku is not available in any supported regions"
                }
            } else {
                # Could not verify - proceed with deployment but don't search alternatives
                Write-Host "PostgreSQL SKU $targetSku status in ${infraLocation}: Proceeding with deployment" -ForegroundColor Yellow
                Write-Host "   Note: Could not verify availability but deployment will be attempted" -ForegroundColor Yellow
                return
            }
        } else {
            # This is truly available
            Write-Host "PostgreSQL SKU $targetSku is available in $infraLocation" -ForegroundColor Green
            if ($skuCheck.VCores -ne "Unknown") {
                Write-Host "   Specs: $($skuCheck.VCores) vCores, $($skuCheck.Memory), $($skuCheck.Edition) edition" -ForegroundColor Green
            }
            return
        }
    }

    # Check if this is a definitive "not available" vs "couldn't verify"
    $isDefinitivelyUnavailable = ($skuCheck.Reason -eq "SKU $targetSku not found in available configurations") -or
                                ($skuCheck.Reason -match "Region .* does not support PostgreSQL Flexible Server") -or
                                ($skuCheck.Reason -match "Region temporarily restricted")

    if ($isDefinitivelyUnavailable) {
        # SKU was definitively not found OR region doesn't support PostgreSQL OR region is temporarily restricted - search alternative regions
        if ($skuCheck.Reason -match "Region .* does not support PostgreSQL Flexible Server") {
            # Don't duplicate the message - it was already shown by Test-PostgreSQLSkuInRegion
        } elseif ($skuCheck.Reason -match "Region temporarily restricted") {
            Write-Host "PostgreSQL is temporarily restricted in $infraLocation" -ForegroundColor Red
        } else {
            Write-Host "PostgreSQL SKU $targetSku is not available in $infraLocation" -ForegroundColor Red
        }

        if ($skuCheck.Reason) {
            Write-Host "   Reason: $($skuCheck.Reason)" -ForegroundColor Red
        }

        # Show some available SKUs for debugging if we have them
        if ($skuCheck.AllSkus -and $skuCheck.AllSkus.Count -gt 0) {
            $sampleSkus = $skuCheck.AllSkus | Where-Object { $_.tier -eq "GeneralPurpose" } | Select-Object -First 5
            if ($sampleSkus) {
                Write-Host "Available GeneralPurpose SKUs in ${infraLocation}:" -ForegroundColor Yellow
                $sampleSkus | ForEach-Object {
                    Write-Host "   $($_.name) ($($_.vCores) vCores, $($_.memoryPerVcoreMb)MB/vCore)" -ForegroundColor Yellow
                }
            }
        }

        # Look for alternative regions (same logic as Container Apps)
        Write-Host "Searching for alternative regions with $targetSku availability..." -ForegroundColor Yellow
        $alternativeRegions = Find-PostgreSQLAlternativeRegions -failedRegion $infraLocation -targetSku $targetSku

        if ($alternativeRegions.Count -gt 0) {
            Write-Host ""
            Write-Host "Alternative regions with $targetSku available:" -ForegroundColor Green
            $alternativeRegions | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
            Write-Host ""
            Exit-WithError "Please use one of the above alternative regions for your deployment"
        } else {
            Write-Host ""
            Write-Host "No alternative regions found with $targetSku available" -ForegroundColor Red
            Write-Host ""
            Write-Host "Suggestions:" -ForegroundColor Cyan
            Write-Host "  1. Check Azure documentation for PostgreSQL SKU availability by region" -ForegroundColor Yellow
            Write-Host "  2. Consider using a different PostgreSQL SKU with similar specifications" -ForegroundColor Yellow
            Write-Host "  3. Request SKU availability in your preferred region through Azure support" -ForegroundColor Yellow
            Write-Host ""
            Exit-WithError "PostgreSQL SKU $targetSku is not available in any supported regions"
        }
    } else {
        # Couldn't verify (API issues, etc.) - preserve existing behavior (proceed with deployment)
        Write-Host "PostgreSQL SKU $targetSku could not be verified in $infraLocation" -ForegroundColor Yellow
        if ($skuCheck.Reason) {
            Write-Host "   Details: $($skuCheck.Reason)" -ForegroundColor Yellow
        }

        # Show some available SKUs for debugging if we have them
        if ($skuCheck.AllSkus -and $skuCheck.AllSkus.Count -gt 0) {
            $sampleSkus = $skuCheck.AllSkus | Where-Object { $_.tier -eq "GeneralPurpose" } | Select-Object -First 5
            if ($sampleSkus) {
                Write-Host "Available GeneralPurpose SKUs in ${infraLocation}:" -ForegroundColor Yellow
                $sampleSkus | ForEach-Object {
                    Write-Host "   $($_.name) ($($_.vCores) vCores, $($_.memoryPerVcoreMb)MB/vCore)" -ForegroundColor Yellow
                }
            }
        }

        Write-Host ""
        Write-Host "Proceeding with deployment - Azure will validate the actual SKU availability during provisioning." -ForegroundColor Cyan
        Write-Host ""
    }
}# Run the checks
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Azure Deployment Validation" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

# First validate environment name
Test-EnvironmentName

Write-Host ""

# Check PostgreSQL SKU availability first
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "PostgreSQL SKU Availability Check" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

Test-PostgreSQLSku

Write-Host ""

# Check Container Apps quota
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Container Apps Quota Check" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

Test-ContainerAppsQuota

Write-Host ""
Write-Host "===========================================" -ForegroundColor Green
Write-Host "All infrastructure validations successful!" -ForegroundColor Green
Write-Host "Note: OpenAI quota checking is handled automatically by azd" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Green
