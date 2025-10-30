#!/usr/bin/env pwsh
param (
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $ForwardArgs
)

function Write-Info {
    param([string] $Message)
    Write-Host "[install] $Message"
}

function Throw-Error {
    param([string] $Message)
    throw "[install] $Message"
}

$manifestUrl = $env:LCOD_RELEASE_MANIFEST_URL
if ([string]::IsNullOrWhiteSpace($manifestUrl)) {
    $manifestUrl = "https://github.com/lcod-team/lcod-release/releases/latest/download/release-manifest.json"
}

$cliArchiveUrl = $env:LCOD_CLI_ARCHIVE_URL
$tempRoot = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath()) -Name ("lcod-cli-" + [System.Guid]::NewGuid())

try {
    $manifestPath = Join-Path $tempRoot "manifest.json"
    $archivePath = Join-Path $tempRoot "lcod-cli.zip"
    $extractRoot = Join-Path $tempRoot "cli"
    New-Item -ItemType Directory -Path $extractRoot | Out-Null

    if ([string]::IsNullOrWhiteSpace($cliArchiveUrl)) {
        Write-Info "Fetching release manifest"
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $manifestUrl -OutFile $manifestPath | Out-Null
        } catch {
            Throw-Error "Unable to download manifest from $manifestUrl"
        }

        try {
            $manifest = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json
        } catch {
            Throw-Error "Unable to parse release manifest ($manifestUrl)"
        }

        $asset = $manifest.cli.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
        if (-not $asset) {
            Throw-Error "No CLI ZIP archive defined in release manifest"
        }
        $cliArchiveUrl = $asset.download_url
    }

    Write-Info "Downloading CLI bundle"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $cliArchiveUrl -OutFile $archivePath | Out-Null
    } catch {
        Throw-Error "Failed to download CLI archive from $cliArchiveUrl"
    }

    Write-Info "Unpacking CLI bundle"
    try {
        Expand-Archive -Path $archivePath -DestinationPath $extractRoot -Force
    } catch {
        Throw-Error "Failed to extract CLI archive"
    }

    $installScript = Join-Path $extractRoot "install.ps1"
    if (-not (Test-Path $installScript)) {
        Throw-Error "CLI archive does not contain install.ps1"
    }

    Write-Info "Installing lcod CLI"
    $previousSource = $env:LCOD_SOURCE
    try {
        $env:LCOD_SOURCE = $extractRoot
        & $installScript @ForwardArgs
    } finally {
        if ($null -eq $previousSource) {
            Remove-Item Env:LCOD_SOURCE -ErrorAction SilentlyContinue
        } else {
            $env:LCOD_SOURCE = $previousSource
        }
    }

    Write-Info "Installation completed successfully."
}
finally {
    Remove-Item -Recurse -Force -Path $tempRoot -ErrorAction SilentlyContinue
}
