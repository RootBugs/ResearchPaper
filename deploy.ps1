<#
.SYNOPSIS
    Deploy the ResearchPaper site to Vercel.

.DESCRIPTION
    Uses environment variables for authentication and project targeting.
    Set VERCEL_TOKEN and VERCEL_PROJECT_ID in your .env file or environment.

.PARAMETER Mode
    Deploy mode: 'cli' (default) uses vercel CLI, 'api' uses REST API.

.PARAMETER Production
    Deploy to production (default: true).

.EXAMPLE
    .\deploy.ps1
    .\deploy.ps1 -Mode api
    .\deploy.ps1 -Mode cli -Production:$false
#>
param(
    [ValidateSet('cli', 'api')]
    [string]$Mode = 'cli',
    [switch]$Production = $true
)

# --- Load .env if present ---
$envFile = Join-Path $PSScriptRoot '.env'
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.+)$') {
            $key = $matches[1].Trim()
            $val = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($key, $val, 'Process')
        }
    }
}

# --- Validate env vars ---
if (-not $env:VERCEL_TOKEN) {
    Write-Error "VERCEL_TOKEN is not set. Add it to .env or export it."
    exit 1
}

$token = $env:VERCEL_TOKEN
$projectId = $env:VERCEL_PROJECT_ID

Set-Location $PSScriptRoot

if ($Mode -eq 'cli') {
    # --- CLI-based deploy ---
    if ($projectId) {
        Write-Output "=== Linking project ($projectId) ==="
        vercel link --yes --project $projectId --token $token 2>&1 | ForEach-Object { Write-Output $_ }
    } else {
        Write-Output "=== Linking project (auto-detect) ==="
        vercel link --yes --token $token 2>&1 | ForEach-Object { Write-Output $_ }
    }

    $deployArgs = @('deploy', '--yes', '--token', $token)
    if ($Production) { $deployArgs += '--prod' }

    Write-Output "=== Deploying (CLI) ==="
    & vercel @deployArgs 2>&1 | ForEach-Object { Write-Output $_ }
}
else {
    # --- API-based deploy ---
    $headers = @{
        Authorization  = "Bearer $token"
        'Content-Type' = 'application/json'
    }

    $filePath = Join-Path $PSScriptRoot 'index.html'
    if (-not (Test-Path $filePath)) {
        Write-Error "index.html not found at $filePath"
        exit 1
    }

    $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
    $fileBase64 = [Convert]::ToBase64String($fileBytes)

    $body = @{
        name  = 'research-paper'
        files = @(
            @{
                file     = 'index.html'
                data     = $fileBase64
                encoding = 'base64'
            }
        )
        projectSettings = @{ framework = $null }
    }

    if ($Production) { $body['target'] = 'production' }

    $jsonBody = $body | ConvertTo-Json -Depth 10

    Write-Output "=== Deploying (API) ==="
    try {
        $response = Invoke-WebRequest `
            -Uri 'https://api.vercel.com/v13/deployments' `
            -Method POST `
            -Headers $headers `
            -Body $jsonBody `
            -UseBasicParsing
        Write-Output "Deploy succeeded:"
        Write-Output $response.Content
    }
    catch {
        Write-Error "Deploy failed: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            Write-Output $reader.ReadToEnd()
        }
        exit 1
    }
}
