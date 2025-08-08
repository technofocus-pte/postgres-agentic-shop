param()

# Fail on any error
$ErrorActionPreference = 'Stop'

# Function to prompt and read input for Azure Container Apps deployment

$input = $null
$validInput = $false

while (-not $validInput) {
    # Prompt the user
    $input = Read-Host "Do you want to deploy Azure Container Apps? (y/n)"

    # Convert input to lowercase
    $input = $input.ToLower()

    switch ($input) {
        'y' {
            $deployApps = $true
            $validInput = $true
            azd env set "DEPLOY_AZURE_CONTAINERAPPS" $deployApps
        }
        'yes' {
            $deployApps = $true
            $validInput = $true
            azd env set "DEPLOY_AZURE_CONTAINERAPPS" $deployApps
        }
        'n' {
            $deployApps = $false
            $validInput = $true
            azd env set "DEPLOY_AZURE_CONTAINERAPPS" $deployApps
        }
        'no' {
            $deployApps = $false
            $validInput = $true
            azd env set "DEPLOY_AZURE_CONTAINERAPPS" $deployApps
        }
        default {
            Write-Host "Invalid input. Please enter 'y', 'yes', 'n', or 'no'."
        }
    }
}

# To control the deployment of Azure Container Apps
if ($deployApps -eq 'false') {
    # Run azd auth login --check-status and capture the output
    $userOutput = azd auth login --check-status

    # Extract the first email address found in the output
    # In case some users may have multiple Entra ID principals associated to their logged in account.
    # It takes the string of the return text of the command and
    # extracts the first email address it finds in the string.

    if ($userOutput -match "[\w\.\-]+@[\w\.\-]+\.\w+")
    {
        $email = $matches[0]
        $env:AZURE_PRINCIPAL_NAME = $email

        Write-Host "Extracted email: $env:AZURE_PRINCIPAL_NAME"

        # Write to azd env
        azd env set "AZURE_PRINCIPAL_NAME" "$env:AZURE_PRINCIPAL_NAME"

        Write-Host "User Principal Name Set: $env:AZURE_PRINCIPAL_NAME"
    }
    else
    {
        $errorMessage = "ERROR: No email address found in azd auth output."
        Write-Host $errorMessage
        throw $errorMessage
    }
}
