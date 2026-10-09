param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^https://[^/]+/?$')]
    [string]$ApiBaseUrl
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$mobileRoot = Join-Path $projectRoot 'mobile'
$artifactRoot = Join-Path $projectRoot 'artifacts'
$outputApk = Join-Path $artifactRoot 'BLE-Attendance-MVP-release.apk'

Push-Location $mobileRoot
try {
    flutter pub get
    flutter build apk --release --dart-define="API_BASE_URL=$($ApiBaseUrl.TrimEnd('/'))"
    New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
    Copy-Item -Force 'build\app\outputs\flutter-apk\app-release.apk' $outputApk
    Write-Host "APK ready: $outputApk"
}
finally {
    Pop-Location
}
