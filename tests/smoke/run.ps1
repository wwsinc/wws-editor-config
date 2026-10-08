<#
.SYNOPSIS
    Consumes a freshly packed Wws.EditorConfig package from a throwaway solution and checks that it enforces the rules.

.EXAMPLE
    dotnet pack Wws.EditorConfig/Wws.EditorConfig.csproj -c Release -o ./nuget
    ./tests/smoke/run.ps1 -PackageDirectory ./nuget
#>
param(
    [Parameter(Mandatory)]
    [string] $PackageDirectory
)

$ErrorActionPreference = 'Stop'

$package = Get-ChildItem -Path $PackageDirectory -Filter 'Wws.EditorConfig.*.nupkg' | Select-Object -First 1
if (-not $package) {
    throw "No Wws.EditorConfig .nupkg found in '$PackageDirectory'."
}
$version = $package.BaseName.Substring('Wws.EditorConfig.'.Length)
$feed = (Resolve-Path $PackageDirectory).Path

$work = Join-Path ([IO.Path]::GetTempPath()) "wws-smoke-$([guid]::NewGuid().ToString('N'))"
Copy-Item -Path (Join-Path $PSScriptRoot 'fixture') -Destination $work -Recurse
$project = Join-Path $work 'src/Smoke/Smoke.csproj'

@"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="local" value="$feed" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
"@ | Set-Content -Path (Join-Path $work 'nuget.config')

# Isolated package cache, so a locally rebuilt package with the same version is never served stale
$env:NUGET_PACKAGES = Join-Path $work '.packages'
$packagedEditorConfig = Join-Path $env:NUGET_PACKAGES "wws.editorconfig/$($version.ToLowerInvariant())/content/rules/.editorconfig"
$solutionEditorConfig = Join-Path $work '.editorconfig'
$projectEditorConfig = Join-Path $work 'src/Smoke/.editorconfig'

dotnet new sln --name Smoke --output $work | Out-Null
$solution = Get-ChildItem -Path $work -Filter 'Smoke.sln*' | Select-Object -First 1
dotnet sln $solution.FullName add $project | Out-Null

$failures = [System.Collections.Generic.List[string]]::new()

function Assert([bool] $condition, [string] $message) {
    if ($condition) {
        Write-Host "  PASS  $message" -ForegroundColor Green
    }
    else {
        Write-Host "  FAIL  $message" -ForegroundColor Red
        $failures.Add($message)
    }
}

# Violations.cs breaks exactly one rule configured as an error (S121), so the build is expected to fail with only that error.
# Anything else failing (restore, MSBuild, other rules) shows up as an unexpected error.
function Invoke-Build([string] $target, [bool] $ci) {
    $env:CI_BUILD = if ($ci) { 'true' } else { $null }
    $env:TF_BUILD = if ($ci) { 'true' } else { $null }
    $output = dotnet build $target --no-incremental -nodeReuse:false -p:WwsEditorConfigVersion=$version 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $errors = @([regex]::Matches($output, 'error ([A-Z]+\d+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $unexpected = @($errors | Where-Object { $_ -ne 'S121' })
    if ($unexpected.Count -gt 0 -or ($exitCode -ne 0 -and $errors -notcontains 'S121')) {
        Write-Host $output
        throw "Build of '$target' failed unexpectedly (exit code $exitCode, errors: $($errors -join ', '))."
    }
    return $output
}

function Get-Hash([string] $path) {
    return (Get-FileHash -Path $path).Hash
}

Write-Host "Smoke testing Wws.EditorConfig $version in $work"

Write-Host 'Solution build copies .editorconfig to the solution folder and reports package rules'
$output = Invoke-Build $solution.FullName $false
Assert (Test-Path $solutionEditorConfig) '.editorconfig copied to the solution folder'
Assert ((Test-Path $solutionEditorConfig) -and (Get-Hash $solutionEditorConfig) -eq (Get-Hash $packagedEditorConfig)) 'copied .editorconfig matches the packaged one'
Assert ($output -match 'warning S1481') 'SonarAnalyzer rule S1481 reported'
Assert ($output -match 'error S121') 'SonarAnalyzer rule S121 raised to error by the package rules'
Assert ($output -match 'warning IDE0011') 'code style rule IDE0011 reported'
Assert ($output -notmatch 'IDE0005') 'IDE0005 (an error elsewhere) stays off for **/Shared/**'

Write-Host 'Project build (no solution context) overwrites an edited .editorconfig in the solution folder before compiling'
Set-Content -Path $solutionEditorConfig -Value "root = true`r`n[*.cs]`r`ndotnet_diagnostic.IDE0011.severity = none"
$output = Invoke-Build $project $false
Assert ((Get-Hash $solutionEditorConfig) -eq (Get-Hash $packagedEditorConfig)) 'edited .editorconfig replaced with the packaged one'
Assert ($output -match 'warning IDE0011') 'restored rules applied in the same build'
Assert (-not (Test-Path $projectEditorConfig)) 'nothing copied next to the project'

Write-Host 'CI build copies .editorconfig too, so folder-specific overrides apply exactly as locally'
Remove-Item $solutionEditorConfig
$output = Invoke-Build $solution.FullName $true
Assert ((Test-Path $solutionEditorConfig) -and (Get-Hash $solutionEditorConfig) -eq (Get-Hash $packagedEditorConfig)) '.editorconfig copied in CI'
Assert ($output -match 'warning S1481') 'SonarAnalyzer rule S1481 reported in CI'
Assert ($output -match 'error S121') 'SonarAnalyzer rule S121 raised to error in CI'
Assert ($output -match 'warning IDE0011') 'code style rule IDE0011 reported in CI'
Assert ($output -notmatch 'IDE0005') 'IDE0005 (an error elsewhere) stays off for **/Shared/** in CI'

Write-Host 'Project without any solution gets .editorconfig next to the project'
Remove-Item $solution.FullName
$output = Invoke-Build $project $false
Assert (Test-Path $projectEditorConfig) '.editorconfig copied to the project folder'

$env:CI_BUILD = $null
$env:TF_BUILD = $null
if ($failures.Count -gt 0) {
    Write-Host "$($failures.Count) smoke check(s) failed. Fixture left in $work" -ForegroundColor Red
    exit 1
}

Remove-Item -Path $work -Recurse -Force
Write-Host 'All smoke checks passed.' -ForegroundColor Green
exit 0
