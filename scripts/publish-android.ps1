param(
    [Parameter(Mandatory=$true)][string]$ReleaseNotes,
    [string]$Flutter = 'C:\Users\ASUS\dev\flutter_sdk\bin\flutter.bat',
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$app = Join-Path $repo 'laundry_app_flutter'
$projectRef = (Get-Content (Join-Path $repo 'supabase/.temp/project-ref') -Raw).Trim()
$base = "https://$projectRef.supabase.co"
$versionMatch = [regex]::Match((Get-Content (Join-Path $app 'pubspec.yaml') -Raw), '(?m)^version:\s*([0-9.]+)\+(\d+)')
if (-not $versionMatch.Success) { throw 'Set versionName+versionCode in pubspec.yaml first.' }
$version = $versionMatch.Groups[1].Value
$build = [int]$versionMatch.Groups[2].Value
$toolsDir = Get-ChildItem -LiteralPath "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Directory | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$signerTool = Join-Path $toolsDir.FullName 'apksigner.bat'
$aaptTool = Join-Path $toolsDir.FullName 'aapt.exe'
# Preserve continuity with APKs already installed on Ratna, Yani and Owner phones.
$expectedSigner = 'ad35e77c429a49be539baf341ee18645195058abf65bbb9561e40c2b43da2794'

Push-Location $repo
try {
    $keys = supabase projects api-keys --project-ref $projectRef --output json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw 'Supabase authentication failed.' }
    $anonKey = ($keys | Where-Object { $_.name -eq 'anon' } | Select-Object -First 1).api_key
    $serviceKey = ($keys | Where-Object { $_.name -eq 'service_role' } | Select-Object -First 1).api_key
    if (-not $anonKey -or -not $serviceKey) { throw 'Deployment credentials unavailable.' }
    $headers = @{ apikey=$serviceKey; Authorization="Bearer $serviceKey" }
    $manifestUrl = "$base/storage/v1/object/public/app-releases/android/latest.json"
    $oldManifest = $null
    try { $oldManifest = Invoke-RestMethod -Uri "${manifestUrl}?t=$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())" }
    catch {
        if ([int]$_.Exception.Response.StatusCode -notin @(400,404)) { throw }
    }
    if ($oldManifest -and $oldManifest.build -ge $build) { throw 'Increase versionCode before publishing a new release.' }
    $outputDir = Join-Path $app 'build/release-artifacts'
    $null = New-Item -ItemType Directory -Path $outputDir -Force
    if (-not $SkipBuild) {
        Push-Location $app
        try {
            # Build each target independently: --split-per-abi adds ABI offsets
            # to versionCode, preventing universal/ABI update continuity.
            foreach ($target in @(
                @{ abi='arm64-v8a'; platform='android-arm64' },
                @{ abi='armeabi-v7a'; platform='android-arm' },
                @{ abi='x86_64'; platform='android-x64' }
            )) {
                & $Flutter build apk --release "--target-platform=$($target.platform)" "--dart-define=SUPABASE_URL=$base" "--dart-define=SUPABASE_ANON_KEY=$anonKey"
                if ($LASTEXITCODE -ne 0) { throw 'Device APK build failed.' }
                Copy-Item -LiteralPath (Join-Path $app 'build/app/outputs/flutter-apk/app-release.apk') -Destination (Join-Path $outputDir "app-$($target.abi)-release.apk") -Force
            }
            & $Flutter build apk --release "--dart-define=SUPABASE_URL=$base" "--dart-define=SUPABASE_ANON_KEY=$anonKey"
            if ($LASTEXITCODE -ne 0) { throw 'Universal APK build failed.' }
            Copy-Item -LiteralPath (Join-Path $app 'build/app/outputs/flutter-apk/app-release.apk') -Destination (Join-Path $outputDir 'app-release.apk') -Force
        } finally { Pop-Location }
    }
    function Verify-Apk([string]$path) {
        $signature = & $signerTool verify --print-certs $path
        if ($LASTEXITCODE -ne 0 -or ($signature -join "`n") -notmatch $expectedSigner) { throw "APK signing key mismatch: $path" }
        $identity = & $aaptTool dump badging $path | Select-Object -First 1
        if ($LASTEXITCODE -ne 0 -or $identity -notmatch "name='com.idolalaundry.laundry_app_flutter'" -or
            $identity -notmatch "versionCode='$build'" -or $identity -notmatch "versionName='$([regex]::Escape($version))'") {
            throw "APK identity/version mismatch: $path"
        }
    }
    Verify-Apk (Join-Path $outputDir 'app-release.apk')
    $assets = @{}
    foreach ($abi in @('arm64-v8a','armeabi-v7a','x86_64')) {
        $path = Join-Path $outputDir "app-$abi-release.apk"
        Verify-Apk $path
        $file = Get-Item -LiteralPath $path
        if ($file.Length -gt 52428800) { throw 'APK exceeds cloud bucket limit.' }
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        # Content-addressed paths: never replace an APK behind an existing manifest.
        $object = "android/$build/$abi-$hash.apk"
        $url = "$base/storage/v1/object/public/app-releases/$object"
        $uploadHeaders = $headers.Clone()
        $uploadHeaders['x-upsert'] = 'false'
        $uploadHeaders['Cache-Control'] = 'max-age=31536000'
        try {
            $null = Invoke-RestMethod -Method Post -Uri "$base/storage/v1/object/app-releases/$object" -Headers $uploadHeaders -ContentType 'application/vnd.android.package-archive' -InFile $path
        } catch {
            # A retry may encounter an immutable object already uploaded. Verify below.
            if ([int]$_.Exception.Response.StatusCode -notin @(400,409)) { throw }
        }
        $verifyPath = Join-Path $outputDir "verify-$abi.apk"
        try {
            Invoke-WebRequest -Uri $url -OutFile $verifyPath
            if ((Get-FileHash -LiteralPath $verifyPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw 'Cloud APK hash mismatch.' }
        } finally { if (Test-Path -LiteralPath $verifyPath) { Remove-Item -LiteralPath $verifyPath } }
        $assets[$abi] = @{ url=$url; sha256=$hash; size=$file.Length }
        Write-Output "Verified cloud APK: $abi ($($file.Length) bytes)"
    }
    $manifest = @{ schema=1; package='com.idolalaundry.laundry_app_flutter'; build=$build; version=$version; notes=$ReleaseNotes; published_at=[DateTime]::UtcNow.ToString('o'); assets=$assets }
    $manifestPath = Join-Path $outputDir 'latest.json'
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    $manifestHeaders = $headers.Clone()
    $manifestHeaders['x-upsert'] = 'true'
    $manifestHeaders['Cache-Control'] = 'max-age=0'
    # Commit point: devices can discover the release only after all APK checks pass.
    $null = Invoke-RestMethod -Method Post -Uri "$base/storage/v1/object/app-releases/android/latest.json" -Headers $manifestHeaders -ContentType 'application/json' -InFile $manifestPath
    $published = Invoke-RestMethod -Uri "${manifestUrl}?t=$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
    if ($published.build -ne $build) { throw 'Published manifest verification failed.' }
    $export = Join-Path $repo "Idola One - $(Get-Date -Format 'yyyy-MM-dd').apk"
    Copy-Item -LiteralPath (Join-Path $outputDir 'app-release.apk') -Destination $export -Force
    Write-Output "Published $version+$build. Bootstrap APK: $export"
} finally { Pop-Location }
