param([string]$Version = '')
$ErrorActionPreference = 'Stop'
$projectDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$releaseDirectory = [System.IO.Path]::GetFullPath((Join-Path $projectDirectory 'build/windows/x64/runner/Release'))
$artifactDirectory = [System.IO.Path]::GetFullPath((Join-Path $projectDirectory 'artifacts'))
if ([string]::IsNullOrWhiteSpace($Version)) {
    $versionMatch = [regex]::Match([System.IO.File]::ReadAllText((Join-Path $projectDirectory 'pubspec.yaml')), '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)')
    if (!$versionMatch.Success) { throw 'Cannot determine the project release version.' }
    $Version = $versionMatch.Groups[1].Value
}
if (!$releaseDirectory.StartsWith($projectDirectory + [System.IO.Path]::DirectorySeparatorChar) -or
    !$artifactDirectory.StartsWith($projectDirectory + [System.IO.Path]::DirectorySeparatorChar)) {
    throw 'Package paths must stay in the project.'
}
if (!(Test-Path -LiteralPath (Join-Path $releaseDirectory 'detergent_factory.exe'))) {
    throw 'Build Windows release first: flutter build windows --release --no-pub'
}
if (!(Test-Path -LiteralPath (Join-Path $releaseDirectory 'data')) -or
    !(Test-Path -LiteralPath (Join-Path $releaseDirectory 'flutter_windows.dll'))) {
    throw 'Incomplete Windows release directory.'
}
if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Use a semantic version.' }
$binaryVersion = (Get-Item -LiteralPath (Join-Path $releaseDirectory 'detergent_factory.exe')).VersionInfo.ProductVersion
if (!$binaryVersion -or $binaryVersion.Split('+')[0] -ne $Version) {
    throw 'Executable version does not match the package version. Build the requested release first.'
}
[System.IO.Directory]::CreateDirectory($artifactDirectory) | Out-Null
$archivePath = Join-Path $artifactDirectory "detergent-factory-erp-windows-$Version.zip"
if (Test-Path -LiteralPath $archivePath) { throw 'Archive already exists; use a new version or filename.' }
$packageDirectory = Join-Path $artifactDirectory "ERP-Test-$Version"
if (Test-Path -LiteralPath $packageDirectory) { throw 'Package folder already exists; preserve it and use a new version.' }
[System.IO.Directory]::CreateDirectory($packageDirectory) | Out-Null
# Stage a fresh package so old generated acceptance files cannot ship again.
Get-ChildItem -LiteralPath $releaseDirectory | Where-Object { $_.Name -notmatch '^ERP_Test_Pack_.*\.html$' } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $packageDirectory -Recurse
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
Copy-Item -LiteralPath (Join-Path $projectDirectory 'RELEASE_GUIDE.md') -Destination $packageDirectory
Copy-Item -LiteralPath (Join-Path $projectDirectory 'ERP_ASSESSMENT.md') -Destination $packageDirectory
if (Test-Path -LiteralPath (Join-Path $projectDirectory 'BUSINESS_CYCLE_TEST.md')) {
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'BUSINESS_CYCLE_TEST.md') -Destination $packageDirectory
}
if (Test-Path -LiteralPath (Join-Path $projectDirectory 'COSTING_GUIDE.md')) {
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'COSTING_GUIDE.md') -Destination $packageDirectory
}
if (Test-Path -LiteralPath (Join-Path $projectDirectory 'DEVELOPMENT_PHASES.md')) {
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'DEVELOPMENT_PHASES.md') -Destination $packageDirectory
}
Copy-Item -LiteralPath (Join-Path $projectDirectory 'WAREHOUSE_UPGRADE_GUIDE_AR.md') -Destination $packageDirectory
Copy-Item -LiteralPath (Join-Path $projectDirectory 'WINDOWS_TEST_LOGIN.md') -Destination $packageDirectory
$launcher = [System.IO.File]::ReadAllText((Join-Path $projectDirectory 'scripts/windows/START-TEST.cmd')) -replace '\r?\n', "`r`n"
[System.IO.File]::WriteAllText((Join-Path $packageDirectory 'START-TEST.cmd'), $launcher, [System.Text.Encoding]::ASCII)
$checklistPath = Join-Path $artifactDirectory "ERP_Test_Pack_$Version.html"
if (Test-Path -LiteralPath $checklistPath) { Copy-Item -LiteralPath $checklistPath -Destination $packageDirectory }
[System.IO.Compression.ZipFile]::CreateFromDirectory($packageDirectory, $archivePath)
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
@{file = [System.IO.Path]::GetFileName($archivePath); sha256 = $archiveHash;
  createdAt = [DateTime]::UtcNow.ToString('o'); version = $Version;
  platform = 'windows-x64'; signed = $false;
  testLauncher = 'START-TEST.cmd'; testProfile = 'test-profile-v1'} |
  ConvertTo-Json | Set-Content -LiteralPath ($archivePath + '.manifest.json') -Encoding utf8
Write-Output $archivePath
Write-Output "SHA256: $archiveHash"
