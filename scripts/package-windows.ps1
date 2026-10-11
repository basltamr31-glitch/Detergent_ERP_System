param([string]$Version = '1.0.0')
$ErrorActionPreference = 'Stop'
$projectDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$releaseDirectory = [System.IO.Path]::GetFullPath((Join-Path $projectDirectory 'build/windows/x64/runner/Release'))
$artifactDirectory = [System.IO.Path]::GetFullPath((Join-Path $projectDirectory 'artifacts'))
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
[System.IO.Directory]::CreateDirectory($artifactDirectory) | Out-Null
$archivePath = Join-Path $artifactDirectory "detergent-factory-erp-windows-$Version.zip"
if (Test-Path -LiteralPath $archivePath) { throw 'Archive already exists; use a new version or filename.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
Copy-Item -LiteralPath (Join-Path $projectDirectory 'RELEASE_GUIDE.md') -Destination $releaseDirectory
Copy-Item -LiteralPath (Join-Path $projectDirectory 'ERP_ASSESSMENT.md') -Destination $releaseDirectory
if (Test-Path -LiteralPath (Join-Path $projectDirectory 'BUSINESS_CYCLE_TEST.md')) {
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'BUSINESS_CYCLE_TEST.md') -Destination $releaseDirectory
}
if (Test-Path -LiteralPath (Join-Path $projectDirectory 'COSTING_GUIDE.md')) {
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'COSTING_GUIDE.md') -Destination $releaseDirectory
}
[System.IO.Compression.ZipFile]::CreateFromDirectory($releaseDirectory, $archivePath)
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
@{file = [System.IO.Path]::GetFileName($archivePath); sha256 = $archiveHash;
  createdAt = [DateTime]::UtcNow.ToString('o'); version = $Version;
  platform = 'windows-x64'; signed = $false} |
  ConvertTo-Json | Set-Content -LiteralPath ($archivePath + '.manifest.json') -Encoding utf8
Write-Output $archivePath
Write-Output "SHA256: $archiveHash"
