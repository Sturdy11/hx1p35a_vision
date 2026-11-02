param(
    [string]$TdPath = 'td_commands_prompt.exe',
    [string]$BuildDirectory = (Join-Path $PSScriptRoot 'out'),
    [switch]$PrepareOnly,
    [switch]$ElaborateOnly
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Split-Path -Parent $PSScriptRoot).Replace('\','/')
New-Item -ItemType Directory -Path $BuildDirectory -Force | Out-Null
$buildRoot = (Resolve-Path -LiteralPath $BuildDirectory).Path.Replace('\','/')
if ($buildRoot -match '[{}\r\n]' -or $repoRoot -match '[{}\r\n]') { throw 'Braces and line breaks are unsupported in build paths' }
$encoding = [Text.UTF8Encoding]::new($false)
$projectText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'project.al') -Raw
$projectText = [regex]::Replace($projectText, '<File Path="([^"]+)"', {
    param($match)
    $ref = [Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
    $path = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $ref)).Replace('\','/')
    if (-not (Test-Path -LiteralPath $path)) { throw ('Missing project input: '+$path) }
    return '<File Path="'+$path+'"'
})
$projectText = [regex]::Replace($projectText, '(<Project[^>]* Path=")[^"]*', ('${1}'+$buildRoot))
[IO.File]::WriteAllText((Join-Path $buildRoot 'project.al'), $projectText, $encoding)
foreach ($phase in @('place','route')) {
    $text = Get-Content -LiteralPath (Join-Path $PSScriptRoot ($phase+'.template.tcl')) -Raw
    $text = $text.Replace('__PROJECT_ROOT__',$repoRoot).Replace('__BUILD_ROOT__',$buildRoot)
    [IO.File]::WriteAllText((Join-Path $buildRoot ($phase+'.tcl')), $text, $encoding)
}
$elab = @"
if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
open_project {$buildRoot/project.al}
elaborate -top design_top_wrapper116
puts {ELABORATION COMPLETE}
} failure]} {puts "ELABORATION FAILED: `$failure";exit 1}
exit 0
"@
[IO.File]::WriteAllText((Join-Path $buildRoot 'elaborate.tcl'), $elab, $encoding)
if ($PrepareOnly) { Write-Output ('Prepared '+$buildRoot); return }
if (Test-Path -LiteralPath $TdPath) { $tdExecutable = (Resolve-Path -LiteralPath $TdPath).Path }
elseif ($env:TD_HOME -and (Test-Path -LiteralPath (Join-Path $env:TD_HOME 'APP/bin/td_commands_prompt.exe'))) {
    $tdExecutable = Join-Path $env:TD_HOME 'APP/bin/td_commands_prompt.exe'
} else { $tdExecutable = (Get-Command $TdPath -ErrorAction Stop).Source }
$phases = if ($ElaborateOnly) { @('elaborate') } else { @('place','route') }
foreach ($phase in $phases) {
    $log = Join-Path $buildRoot ($phase+'.log')
    $process = Start-Process -FilePath $tdExecutable -ArgumentList ($phase+'.tcl') -WorkingDirectory $buildRoot -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError (Join-Path $buildRoot ($phase+'.err')) -Wait -PassThru
    $text = Get-Content -LiteralPath $log -Raw
    if ($process.ExitCode -ne 0 -or $text -match '(?m)^ERROR:|Oops!|ELABORATION FAILED|BUILD116 FAILED') {
        throw ($phase+' failed; see '+$log)
    }
    if ($phase -eq 'elaborate' -and $text -notmatch 'ELABORATION COMPLETE') { throw 'Elaboration completion marker missing' }
    Write-Output ('Completed '+$phase)
}
