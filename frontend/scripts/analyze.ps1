$ErrorActionPreference = "Stop"

$frontendDir = Split-Path -Parent $PSScriptRoot
Push-Location $frontendDir

try {
    $dart = Get-Command dart -ErrorAction SilentlyContinue
    if ($null -eq $dart) {
        throw "Dart executable was not found. Add the Flutter SDK bin directory to PATH."
    }

    & dart analyze
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}
