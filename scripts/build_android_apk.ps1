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

if (-not $env:JAVA_HOME -or -not (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
    $jdkRegistry = Get-ItemProperty 'HKLM:\SOFTWARE\JavaSoft\JDK' -ErrorAction SilentlyContinue
    if ($jdkRegistry.CurrentVersion) {
        $jdkVersionKey = "HKLM:\SOFTWARE\JavaSoft\JDK\$($jdkRegistry.CurrentVersion)"
        $env:JAVA_HOME = (Get-ItemProperty $jdkVersionKey).JavaHome
    }
}

if (-not $env:JAVA_HOME -or -not (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
    $jdkCandidates = @(
        'D:\AndroidDev\Jdk\jdk-21.0.12.1+1',
        "$env:ProgramFiles\Android\Android Studio\jbr",
        "$env:LOCALAPPDATA\Programs\Android Studio\jbr",
        'D:\codex-temp\codex-jdk-21\jdk-21.0.12.1+1'
    )
    $env:JAVA_HOME = $jdkCandidates |
        Where-Object { Test-Path (Join-Path $_ 'bin\java.exe') } |
        Select-Object -First 1
}

if (-not $env:JAVA_HOME -or -not (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
    throw 'A Java JDK is required. Install Android Studio or set JAVA_HOME before building.'
}

Push-Location $mobileRoot
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed with exit code $LASTEXITCODE" }
    flutter build apk --release --dart-define="API_BASE_URL=$($ApiBaseUrl.TrimEnd('/'))"
    if ($LASTEXITCODE -ne 0) { throw "Flutter APK build failed with exit code $LASTEXITCODE" }
    New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
    Copy-Item -Force 'build\app\outputs\flutter-apk\app-release.apk' $outputApk
    Write-Host "APK ready: $outputApk"
}
finally {
    Pop-Location
}
