#Requires -Version 7.0
# Download a pinned standalone compiler; no Azure CLI or global installation.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$version = 'v0.49.2'
$toolDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) '.tools/bicep'
if ($IsWindows) {
    $asset = 'bicep-win-x64.exe'
    $fileName = 'bicep.exe'
    $expectedHash = 'acfff0453c9bcf442aa97103acbcd845ef366634e6ea2a2ba5734514409ce9c3'
} elseif ($IsLinux) {
    $asset = 'bicep-linux-x64'
    $fileName = 'bicep'
    $expectedHash = '0ab9de90c2493f206f8281bae74f9ee2d5ed3605548dab1adf41fef185e1f7c5'
} else {
    throw 'This lab bootstrap currently supports Windows x64 and Linux x64.'
}
if ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -ne 'X64') {
    throw 'The pinned compiler assets require an x64 process.'
}

New-Item -ItemType Directory -Path $toolDirectory -Force | Out-Null
$compiler = Join-Path $toolDirectory $fileName
if (-not (Test-Path -LiteralPath $compiler)) {
    Invoke-WebRequest -Uri "https://github.com/Azure/bicep/releases/download/$version/$asset" -OutFile $compiler
}
$actualHash = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedHash) {
    throw "Bicep checksum mismatch at $compiler. Do not execute this file."
}
if ($IsLinux) {
    [System.IO.File]::SetUnixFileMode($compiler, [System.IO.UnixFileMode]::UserRead -bor [System.IO.UnixFileMode]::UserWrite -bor [System.IO.UnixFileMode]::UserExecute)
}
return $compiler
