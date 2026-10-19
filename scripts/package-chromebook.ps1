param([string]$AndroidSdkPath = (Join-Path $env:LOCALAPPDATA 'Android/Sdk'))
$ErrorActionPreference = 'Stop'
$projectDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$versionMatch = [regex]::Match([System.IO.File]::ReadAllText((Join-Path $projectDirectory 'pubspec.yaml')), '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)')
if (!$versionMatch.Success) { throw 'Cannot determine the project version and build number.' }
$version = $versionMatch.Groups[1].Value
$versionPattern = [regex]::Escape($version)
$buildNumber = $versionMatch.Groups[2].Value
$apkPath = Join-Path $projectDirectory 'build/app/outputs/flutter-apk/app-debug.apk'
$checklistPath = Join-Path $projectDirectory "artifacts/ERP_Test_Pack_$version.html"
$inventory = Get-Content -LiteralPath (Join-Path $projectDirectory 'qa/automated_inventory.json') -Raw | ConvertFrom-Json
if ($inventory.version -ne "$version+$buildNumber") { throw 'Regenerate the checklist for this project version.' }
if (!$inventory.verification.testRunSuccess -or $inventory.verification.analysisStatus -ne 'No issues found') {
    throw 'Complete the automated suite and clean static analysis before packaging.'
}
if (!(Test-Path -LiteralPath $apkPath) -or !(Test-Path -LiteralPath $checklistPath)) {
    throw 'Build the Android debug APK and generate the test checklist first.'
}
$embedded = [regex]::Match([System.IO.File]::ReadAllText($checklistPath), '<script id="test-data" type="application/json">(.*?)</script>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (!$embedded.Success) { throw 'Checklist is missing embedded verification data.' }
$checklistData = $embedded.Groups[1].Value | ConvertFrom-Json
if ($checklistData.release -ne $inventory.version -or
    $checklistData.verification.resultsSha256 -ne $inventory.verification.resultsSha256 -or
    $checklistData.automated.Count -ne $inventory.tests.Count) {
    throw 'Checklist and automated inventory are from different verification snapshots.'
}
$aapt = Get-ChildItem -LiteralPath (Join-Path $AndroidSdkPath 'build-tools') -Directory |
    Sort-Object { [version]($_.Name -replace '-.*$', '') } -Descending |
    ForEach-Object { Join-Path $_.FullName 'aapt.exe' } |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (!$aapt) { throw 'Android SDK aapt.exe is required to inspect the APK.' }
$badging = (& $aapt dump badging $apkPath) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'APK inspection failed.' }
if ($badging -notmatch "package: name='com.example.detergent_factory' versionCode='$buildNumber' versionName='$versionPattern'") {
    throw 'APK identity or version differs from the expected test build.'
}
$abiLine = ($badging -split "`n" | Where-Object { $_.StartsWith('native-code:') }) -join ''
foreach ($abi in @('arm64-v8a', 'armeabi-v7a', 'x86_64')) {
    if (!$abiLine.Contains("'$abi'")) { throw "APK is missing required architecture $abi." }
}
$manifest = (& $aapt dump xmltree $apkPath AndroidManifest.xml) -join "`n"
if ($LASTEXITCODE -ne 0 -or $manifest -notmatch 'resizeableActivity[^\r\n]*0xffffffff' -or
    $manifest -notmatch 'debuggable[^\r\n]*0xffffffff' -or
    $manifest -notmatch '(?s)android.hardware.touchscreen[^\r\n]*\n\s*A: android:required[^\r\n]*0x0' -or
    $manifest -notmatch '(?s)android.hardware.faketouch[^\r\n]*\n\s*A: android:required[^\r\n]*0x0') {
    throw 'APK must be a resizable debug test build with optional touchscreen/faketouch.'
}
$artifactDirectory = Join-Path $projectDirectory 'artifacts'
$packageDirectory = Join-Path $artifactDirectory "ChromeOS-Test-$version"
$archivePath = Join-Path $artifactDirectory "detergent-factory-erp-chromeos-test-$version.zip"
if ((Test-Path -LiteralPath $packageDirectory) -or (Test-Path -LiteralPath $archivePath)) {
    throw 'Package already exists; preserve it and use a new project version.'
}
[System.IO.Directory]::CreateDirectory($packageDirectory) | Out-Null
Copy-Item -LiteralPath $apkPath -Destination (Join-Path $packageDirectory "Detergent_ERP_ChromeOS_Test_$version.apk")
Copy-Item -LiteralPath $checklistPath -Destination $packageDirectory
foreach ($guide in @('CHROMEBOOK_GUIDE.md','BUSINESS_CYCLE_TEST.md','COSTING_GUIDE.md','RELEASE_GUIDE.md','WAREHOUSE_UPGRADE_GUIDE_AR.md')) {
    Copy-Item -LiteralPath (Join-Path $projectDirectory $guide) -Destination $packageDirectory
}
$checksums = @(Get-ChildItem -LiteralPath $packageDirectory -File | Sort-Object Name | ForEach-Object {
    @{file = $_.Name; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
})
@{version = "$version+$buildNumber"; applicationId = 'com.example.detergent_factory';
  distribution = 'ChromeOS Android development test'; signing = 'debug';
  architectures = @('armeabi-v7a','arm64-v8a','x86_64');
  physicalChromebookVerified = $false; createdAt = [DateTime]::UtcNow.ToString('o');
  automated = $inventory.verification; files = $checksums} |
    ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $packageDirectory 'manifest.json') -Encoding utf8
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($packageDirectory, $archivePath)
@{file = [System.IO.Path]::GetFileName($archivePath);
  sha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash;
  version = "$version+$buildNumber"; createdAt = [DateTime]::UtcNow.ToString('o')} |
    ConvertTo-Json | Set-Content -LiteralPath ($archivePath + '.manifest.json') -Encoding utf8
Write-Output $packageDirectory
Write-Output $archivePath
