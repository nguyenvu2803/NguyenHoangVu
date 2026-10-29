$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '../mobile')
if (!(Test-Path 'config/production.json')) { throw 'Copy config/production.example.json to config/production.json and set HTTPS API URL.' }
$config = Get-Content 'config/production.json' | ConvertFrom-Json
$url = [Uri]$config.API_BASE_URL
if ($url.Scheme -ne 'https' -or $url.IsLoopback -or $url.Host.ToLowerInvariant().Contains('your-')) { throw 'API URL must be deployed HTTPS.' }
if ($config.DEMO_MODE -ne 'false') { throw 'DEMO_MODE must be false.' }
if ($config.SHOW_DEMO -ne 'false') { throw 'SHOW_DEMO must be false.' }
if ($config.ALLOW_INSECURE_DEV -ne 'false') { throw 'ALLOW_INSECURE_DEV must be false.' }
python '../scripts/check_deployment.py' $config.API_BASE_URL
if ($LASTEXITCODE -ne 0) { throw 'Public API deployment check failed' }
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
flutter build apk --release --dart-define-from-file=config/production.json
if ($LASTEXITCODE -ne 0) { throw 'Android build failed' }
New-Item -ItemType Directory -Force '../dist' | Out-Null
Copy-Item 'build/app/outputs/flutter-apk/app-release.apk' '../dist/NguyenHoangVu.apk'
