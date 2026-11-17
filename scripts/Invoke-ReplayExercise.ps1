#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidatePattern('^[a-z0-9-]{1,40}$')]
    [string]$RunId = ('replay-' + [datetime]::UtcNow.ToString('yyyyMMdd-HHmmss')),
    [switch]$SkipMitigation,
    [switch]$UseManagedRunCommand
)

$ErrorActionPreference = 'Stop'
$group = 'rg-ground-station-lab'
$repo = Split-Path $PSScriptRoot -Parent
$context = Get-AzContext
if ($null -eq $context -or $context.Subscription.Name -ne 'ground-station-lab') { throw 'Select the ground-station-lab subscription first.' }
$evidence = Join-Path $repo "evidence/raw/$RunId"
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$source = Join-Path $repo 'app/telemetry_lab.py'
$source64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($source))
$tests64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $repo 'tests/test_telemetry_lab.py')))
$groundNic = $null
for ($attempt = 1; $attempt -le 3; $attempt++) {
    try { $groundNic = Get-AzNetworkInterface -ResourceGroupName $group -Name 'gsdl-ground-vm-nic' -ErrorAction Stop; break }
    catch { if ($attempt -eq 3) { throw }; Write-Warning "Read-only NIC lookup failed; retry $attempt of 2." }
}
$groundIp = $groundNic.IpConfigurations[0].PrivateIpAddress
if ($groundIp -notmatch '^10\.42\.20\.\d{1,3}$') { throw 'Receiver private IP is outside the expected lab subnet.' }
$remote = "/var/tmp/gsdl-$RunId"
$script:commandNumber = 0

function Invoke-LabGuest([string]$VM, [string]$Shell) {
    $script:commandNumber++
    $wrapped = "set -eu`n$Shell`nprintf '\nGSDL_OK\n'"
    if ($UseManagedRunCommand) {
        $resourcePath = "/subscriptions/$($context.Subscription.Id)/resourceGroups/$group/providers/Microsoft.Compute/virtualMachines/$VM/runCommands/$RunId-$script:commandNumber"
        $readPath = $resourcePath + '?api-version=2024-07-01&$expand=instanceView'
        $body = @{location='westus2'; properties=@{source=@{script=$wrapped}; timeoutInSeconds=300; asyncExecution=$false}} | ConvertTo-Json -Depth 6 -Compress
        $submitted = $false
        for ($attempt=1; $attempt -le 3; $attempt++) {
            for ($readAttempt=1; $readAttempt -le 4; $readAttempt++) {
                try { $existing = Invoke-AzRestMethod -Path $readPath -Method GET -ErrorAction Stop; break }
                catch { if ($readAttempt -eq 4) { throw } }
            }
            if ($existing.StatusCode -eq 200) {
                $old = $existing.Content | ConvertFrom-Json
                if ($old.properties.source.script -ne $wrapped) { throw 'Existing command source differs. Use a new run ID after inspecting prior guest state.' }
                $submitted = $true
                break
            }
            if ($existing.StatusCode -ne 404) { throw "Unexpected command lookup status $($existing.StatusCode)." }
            try {
                $created = Invoke-AzRestMethod -Path ($resourcePath + '?api-version=2024-07-01') -Method PUT -Payload $body -ErrorAction Stop
                if ($created.StatusCode -notin @(200,201,202)) { throw "RunCommand PUT returned $($created.StatusCode)." }
                $submitted = $true
                break
            } catch {
                Write-Warning 'RunCommand submission uncertain; next attempt checks the named command before any write.'
                if ($attempt -eq 3) { throw }
            }
        }
        if (-not $submitted) { throw 'Managed RunCommand was not submitted.' }
        $finished = $false
        for ($poll=0; $poll -lt 120; $poll++) {
            try { $response = Invoke-AzRestMethod -Path $readPath -Method GET -ErrorAction Stop }
            catch { Start-Sleep -Seconds 2; continue }
            if ($response.StatusCode -ne 200) { Start-Sleep -Seconds 2; continue }
            $command = $response.Content | ConvertFrom-Json
            $view = $command.properties.instanceView
            if ($view.executionState -in @('Succeeded','Failed','TimedOut','Canceled')) { $finished = $true; break }
            if ($command.properties.provisioningState -eq 'Failed') { throw 'Managed RunCommand provisioning failed.' }
            Start-Sleep -Seconds 2
        }
        if (-not $finished) { throw 'Managed RunCommand polling timed out; inspect its existing resource before retrying.' }
        $message = "$($view.output)`n$($view.error)"
        $message | Set-Content -LiteralPath (Join-Path $evidence ("command-{0:D2}-{1}.txt" -f $script:commandNumber,$VM)) -Encoding utf8
        if ($view.executionState -ne 'Succeeded' -or $view.exitCode -ne 0) { throw "Guest command failed on $VM with exit code $($view.exitCode)." }
    } else {
        $result = Invoke-AzVMRunCommand -ResourceGroupName $group -VMName $VM -CommandId RunShellScript -ScriptString $wrapped -ErrorAction Stop
        $message = ($result.Value | ForEach-Object { $_.Message }) -join "`n"
        if (@($result.Value | Where-Object { $_.Code -match '/failed$' }).Count) { throw "Azure reports failed guest execution on $VM; inspect private evidence." }
    }
    $message | Set-Content -LiteralPath (Join-Path $evidence ("command-{0:D2}-{1}.txt" -f $script:commandNumber,$VM)) -Encoding utf8
    if ($message -notmatch '(?m)^GSDL_OK\r?$') { throw "Guest command failed or output was truncated on $VM. Inspect private evidence command $script:commandNumber." }
    return $message
}

function Save-GuestEvidence([string]$Phase, [string]$Directory) {
    $shell = @"
python3 '$remote/telemetry_lab.py' analyze --log '$Directory/events.jsonl' > '$Directory/analysis.json'
python3 - <<'PY'
import base64,gzip,json,pathlib
p=pathlib.Path('$Directory')
data={name:base64.b64encode((p/name).read_bytes()).decode() for name in ['events.jsonl','received.bin','analysis.json']}
encoded=base64.b64encode(gzip.compress(json.dumps(data).encode(),mtime=0)).decode()
if len(encoded)>3400: raise RuntimeError('Evidence exceeds safe RunCommand output size')
print('GSDL_EVIDENCE:'+encoded)
PY
"@
    $output = Invoke-LabGuest 'gsdl-ground-vm' $shell
    $match = [regex]::Match($output, 'GSDL_EVIDENCE:([A-Za-z0-9+/=]+)')
    if (-not $match.Success) { throw 'Evidence payload missing.' }
    $bytes = [Convert]::FromBase64String($match.Groups[1].Value)
    $memory = [IO.MemoryStream]::new($bytes)
    $gzip = [IO.Compression.GZipStream]::new($memory, [IO.Compression.CompressionMode]::Decompress)
    $reader = [IO.StreamReader]::new($gzip)
    try { $files = $reader.ReadToEnd() | ConvertFrom-Json -AsHashtable } finally { $reader.Dispose(); $gzip.Dispose(); $memory.Dispose() }
    $folder = Join-Path $evidence $Phase
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    foreach ($name in @('events.jsonl','received.bin','analysis.json')) {
        [IO.File]::WriteAllBytes((Join-Path $folder $name), [Convert]::FromBase64String($files[$name]))
    }
    $analysis = Get-Content (Join-Path $folder 'analysis.json') -Raw | ConvertFrom-Json
    Write-Host "$Phase evidence saved; D1 alerts: $(@($analysis.alerts).Count)."
    return $folder
}

function Start-Receiver([string]$Phase, [switch]$RejectDuplicates) {
    $directory = "$remote/$Phase"
    $reject = if ($RejectDuplicates) { '--reject-duplicates' } else { '' }
    Invoke-LabGuest 'gsdl-ground-vm' @"
mkdir -p '$directory'
chmod 755 '$remote'
chown nobody:nogroup '$directory'
systemd-run --unit 'gsdl-$RunId-$Phase' --uid=nobody --property=RuntimeMaxSec=1200 --property=NoNewPrivileges=yes /usr/bin/python3 '$remote/telemetry_lab.py' receive --bind '$groundIp' --log '$directory/events.jsonl' --capture '$directory/received.bin' --duration 1100 --max-events 100 $reject
sleep 2
systemctl is-active --quiet 'gsdl-$RunId-$Phase'
"@ | Out-Null
}

Write-Host "Run ${RunId}: uploading the bounded exercise to both VMs."
foreach ($vm in @('gsdl-ground-vm','gsdl-sim-vm')) {
    Invoke-LabGuest $vm @"
mkdir -p '$remote'
printf '%s' '$source64' | base64 --decode > '$remote/telemetry_lab.py'
python3 -m py_compile '$remote/telemetry_lab.py'
python3 --version
"@ | Out-Null
}
Write-Host 'Running isolated loopback tests before live traffic.'
Invoke-LabGuest 'gsdl-sim-vm' @"
mkdir -p '$remote/testsuite/app' '$remote/testsuite/tests'
cp '$remote/telemetry_lab.py' '$remote/testsuite/app/telemetry_lab.py'
printf '%s' '$tests64' | base64 --decode > '$remote/testsuite/tests/test_telemetry_lab.py'
cd '$remote/testsuite'
python3 -m unittest discover -s tests -v
"@ | Out-Null

Write-Host 'Starting receiver and sending five normal messages plus one documented benign retry.'
Start-Receiver 'unmitigated'
Invoke-LabGuest 'gsdl-sim-vm' @"
python3 '$remote/telemetry_lab.py' send --destination '$groundIp' --run-id '$RunId' --count 5 --capture '$remote/original.bin' > '$remote/sender.jsonl'
python3 '$remote/telemetry_lab.py' replay --destination '$groundIp' --capture '$remote/original.bin' --count 1 >> '$remote/sender.jsonl'
"@ | Out-Null
$baseline = Save-GuestEvidence 'baseline' "$remote/unmitigated"
$received64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $baseline 'received.bin')))
Write-Host 'Replaying five copies of the exact bytes captured at the receiver.'
Invoke-LabGuest 'gsdl-sim-vm' @"
printf '%s' '$received64' | base64 --decode > '$remote/receiver-captured.bin'
sleep 11
python3 '$remote/telemetry_lab.py' replay --destination '$groundIp' --capture '$remote/receiver-captured.bin' --count 5 >> '$remote/sender.jsonl'
"@ | Out-Null
$attack = Save-GuestEvidence 'attack' "$remote/unmitigated"
Invoke-LabGuest 'gsdl-ground-vm' "systemctl stop 'gsdl-$RunId-unmitigated'" | Out-Null

if (-not $SkipMitigation) {
    Write-Host 'Repeating with duplicate rejection, then verifying fresh telemetry is accepted.'
    Start-Receiver 'mitigated' -RejectDuplicates
    Invoke-LabGuest 'gsdl-sim-vm' @"
python3 '$remote/telemetry_lab.py' replay --destination '$groundIp' --capture '$remote/receiver-captured.bin' --count 1 >> '$remote/sender.jsonl'
python3 '$remote/telemetry_lab.py' replay --destination '$groundIp' --capture '$remote/receiver-captured.bin' --count 5 >> '$remote/sender.jsonl'
python3 '$remote/telemetry_lab.py' send --destination '$groundIp' --run-id '$RunId' --start-sequence 100 --count 3 >> '$remote/sender.jsonl'
"@ | Out-Null
    $mitigated = Save-GuestEvidence 'mitigated' "$remote/mitigated"
    Invoke-LabGuest 'gsdl-ground-vm' "systemctl stop 'gsdl-$RunId-mitigated'" | Out-Null
}

$baselineAnalysis = Get-Content (Join-Path $baseline 'analysis.json') -Raw | ConvertFrom-Json
$attackAnalysis = Get-Content (Join-Path $attack 'analysis.json') -Raw | ConvertFrom-Json
if (@(Get-Content (Join-Path $baseline 'events.jsonl')).Count -ne 6 -or @(Get-Content (Join-Path $attack 'events.jsonl')).Count -ne 11) {
    throw 'Packet delivery assessment failed: expected six baseline and eleven cumulative attack events. Preserve evidence and investigate UDP loss.'
}
if (@($baselineAnalysis.alerts).Count -ne 0 -or @($attackAnalysis.alerts).Count -lt 1) {
    throw 'Detection assessment failed: expected no baseline alert and at least one replay alert. Preserve evidence and investigate.'
}
if (-not $SkipMitigation) {
    $events = @(Get-Content (Join-Path $mitigated 'events.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
    $rejected = @($events | Where-Object { $_.event_type -eq 'duplicate_sequence' -and $_.outcome -eq 'rejected' })
    $recovered = @($events | Where-Object { $_.sequence -ge 100 -and $_.outcome -eq 'accepted' })
    if ($rejected.Count -ne 5 -or $recovered.Count -ne 3) { throw 'Mitigation assessment failed; expected five rejected duplicates and three fresh accepted messages.' }
}
$senderOutput = Invoke-LabGuest 'gsdl-sim-vm' @"
python3 - <<'PY'
import base64,gzip,json,pathlib
p=pathlib.Path('$remote')
data={name:base64.b64encode((p/name).read_bytes()).decode() for name in ['sender.jsonl','original.bin','receiver-captured.bin']}
encoded=base64.b64encode(gzip.compress(json.dumps(data).encode(),mtime=0)).decode()
if len(encoded)>3400: raise RuntimeError('Sender evidence exceeds safe RunCommand output size')
print('GSDL_EVIDENCE:'+encoded)
PY
"@
$senderMatch = [regex]::Match($senderOutput, 'GSDL_EVIDENCE:([A-Za-z0-9+/=]+)')
if (-not $senderMatch.Success) { throw 'Sender evidence payload missing.' }
$senderMemory = [IO.MemoryStream]::new([Convert]::FromBase64String($senderMatch.Groups[1].Value))
$senderGzip = [IO.Compression.GZipStream]::new($senderMemory, [IO.Compression.CompressionMode]::Decompress)
$senderReader = [IO.StreamReader]::new($senderGzip)
try { $senderFiles = $senderReader.ReadToEnd() | ConvertFrom-Json -AsHashtable } finally { $senderReader.Dispose(); $senderGzip.Dispose(); $senderMemory.Dispose() }
foreach ($name in @('sender.jsonl','original.bin','receiver-captured.bin')) {
    [IO.File]::WriteAllBytes((Join-Path $evidence $name), [Convert]::FromBase64String($senderFiles[$name]))
}
[pscustomobject]@{run_id=$RunId; source_sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant(); runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant(); collected_utc=[datetime]::UtcNow.ToString('o'); baseline_alerts=@($baselineAnalysis.alerts).Count; attack_alerts=@($attackAnalysis.alerts).Count; mitigation_included=(-not $SkipMitigation)} | ConvertTo-Json | Set-Content (Join-Path $evidence 'run-summary.json') -Encoding utf8
$manifest = Get-ChildItem -LiteralPath $evidence -Recurse -File | ForEach-Object {
    [pscustomobject]@{ path = [IO.Path]::GetRelativePath($evidence,$_.FullName); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $evidence 'manifest.json') -Encoding utf8
Write-Host "Private evidence: $evidence. Review before publishing. VMs remain running; use Lab.ps1 to deallocate or remove compute when finished."
