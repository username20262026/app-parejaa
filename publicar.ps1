# Compila una versión nueva, la sube a Firebase Hosting y avisa a los celulares.
# Ejecutar:  powershell -ExecutionPolicy Bypass -File .\publicar.ps1
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding($false)

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  throw 'Falta firebase-tools. Ejecuta:  npm install -g firebase-tools   y luego:  firebase login'
}

# 1) Subir el número de versión
$gradle = Join-Path $PSScriptRoot 'android\app\build.gradle'
$g = [System.IO.File]::ReadAllText($gradle)
$m = [regex]::Match($g, 'versionCode\s+(\d+)')
if (-not $m.Success) { throw 'No encontré versionCode en android\app\build.gradle' }
$code = [int]$m.Groups[1].Value + 1
$name = "1.$code"
$g = [regex]::Replace($g, 'versionCode\s+\d+', "versionCode $code")
$g = [regex]::Replace($g, 'versionName\s+"[^"]*"', "versionName `"$name`"")
[System.IO.File]::WriteAllText($gradle, $g, $utf8)
Write-Host "Versión nueva: $name (código $code)" -ForegroundColor Cyan

# 2) Compilar
npm run build
npx cap sync android
Push-Location (Join-Path $PSScriptRoot 'android')
.\gradlew.bat assembleDebug
if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'Falló la compilación de Gradle' }
Pop-Location

# 3) Preparar lo que se publica
$pub = Join-Path $PSScriptRoot 'hosting'
New-Item -ItemType Directory -Force $pub | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'android\app\build\outputs\apk\debug\app-debug.apk') (Join-Path $pub 'pareja-gps.apk') -Force
$notes = Read-Host '¿Qué trae esta versión? (opcional, Enter para omitir)'
$json = [ordered]@{
  versionCode = $code
  versionName = $name
  url         = 'https://app-pareja-c1579.web.app/pareja-gps.apk'
  notes       = $notes
} | ConvertTo-Json
[System.IO.File]::WriteAllText((Join-Path $pub 'version.json'), $json, $utf8)

# 4) Publicar
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { throw 'Falló la publicación en Firebase. Revisa el error de arriba (¿hiciste firebase login? ¿es la cuenta correcta?).' }
Write-Host ''
Write-Host "Publicada la versión $name. Los celulares la recibirán al abrir la app." -ForegroundColor Green
Write-Host 'Descarga directa: https://app-pareja-c1579.web.app/pareja-gps.apk'
