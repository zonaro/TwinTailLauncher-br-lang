<#
.SYNOPSIS
    Removes the TwintailLauncher Brazilian Portuguese (pt_BR) language pack on Windows.

.DESCRIPTION
    Locates every installed pt_BR.json inside TwintailLauncher locales
    directories (registry, standard install paths, then a bounded filesystem
    search) and deletes it, elevating to administrator only when the folder is
    not writable.

.PARAMETER DryRun
    Reports what would be removed without deleting anything. Flags cannot be
    bound when the script is piped to iex, so download the script first:

        irm https://raw.githubusercontent.com/zonaro/TwinTailLauncher-br-lang/main/uninstall.ps1 -OutFile uninstall.ps1
        .\uninstall.ps1 -DryRun

.PARAMETER Version
    Prints the script version and exits.

.EXAMPLE
    irm https://raw.githubusercontent.com/zonaro/TwinTailLauncher-br-lang/main/uninstall.ps1 | iex

.EXAMPLE
    .\uninstall.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch] $DryRun,
    [switch] $Version
)

$ErrorActionPreference = 'Stop'

$ScriptVersion = '1.0.0'
$LocaleFile    = 'pt_BR.json'
$LocaleDirName = 'resources\locales'
$RawBase       = 'https://raw.githubusercontent.com/zonaro/TwinTailLauncher-br-lang/main'
$ScriptUrl     = "$RawBase/uninstall.ps1"

if ($Version) {
    Write-Output "uninstall.ps1 $ScriptVersion"
    exit 0
}

function Write-Info { param([string] $Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Ok   { param([string] $Message) Write-Host "[OK]   $Message" -ForegroundColor Green }
function Write-Warn { param([string] $Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Fail { param([string] $Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

function Test-Administrator {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Download {
    param([string] $Url, [string] $OutFile)

    $parameters = @{ Uri = $Url; OutFile = $OutFile; ErrorAction = 'Stop' }
    if ($PSVersionTable.PSVersion.Major -lt 6) { $parameters.UseBasicParsing = $true }
    Invoke-WebRequest @parameters
}

function Get-RegistryInstallDirs {
    $paths = @(
        'Software\twintaillauncher\twintaillauncher',
        'Software\Microsoft\Windows\CurrentVersion\Uninstall\twintaillauncher'
    )
    $hives = @([Microsoft.Win32.RegistryHive]::CurrentUser, [Microsoft.Win32.RegistryHive]::LocalMachine)
    $views = @([Microsoft.Win32.RegistryView]::Registry64, [Microsoft.Win32.RegistryView]::Registry32)

    $results = New-Object System.Collections.Generic.List[string]

    foreach ($hive in $hives) {
        foreach ($view in $views) {
            foreach ($path in $paths) {
                $key  = $null
                $base = $null
                try {
                    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, $view)
                    $key  = $base.OpenSubKey($path)
                    if ($null -eq $key) { continue }

                    foreach ($valueName in @('', 'InstallLocation')) {
                        $raw = $key.GetValue($valueName)
                        if ([string]::IsNullOrWhiteSpace([string] $raw)) { continue }

                        $dir = ([string] $raw).Trim().Trim('"')
                        if ($dir) { $results.Add($dir) }
                    }
                } catch {
                    continue
                } finally {
                    if ($null -ne $key)  { $key.Dispose() }
                    if ($null -ne $base) { $base.Dispose() }
                }
            }
        }
    }

    return $results.ToArray()
}

function Get-CandidateInstallDirs {
    $candidates = New-Object System.Collections.Generic.List[string]

    foreach ($dir in (Get-RegistryInstallDirs)) { $candidates.Add($dir) }

    foreach ($base in @($env:LOCALAPPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432)) {
        if (-not $base) { continue }
        $candidates.Add((Join-Path $base 'twintaillauncher'))
        $candidates.Add((Join-Path $base 'Programs\twintaillauncher'))
    }

    $exeDir = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
    if ($exeDir) { $candidates.Add($exeDir) }

    return $candidates.ToArray()
}

function Get-InstalledLocaleFiles {
    $found = New-Object System.Collections.Generic.List[string]

    foreach ($root in (Get-CandidateInstallDirs)) {
        $file = Join-Path (Join-Path $root $LocaleDirName) $LocaleFile
        if ($found.Contains($file)) { continue }
        if (Test-Path -LiteralPath $file -PathType Leaf) { $found.Add($file) }
    }

    if ($found.Count -gt 0) { return $found.ToArray() }

    Write-Warn "No $LocaleFile found via candidates, searching the filesystem (this may take a few seconds)..."

    $roots = @($env:LOCALAPPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)}) |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }

    if ($roots.Count -gt 0) {
        $needle = (Join-Path 'x' $LocaleDirName).Substring(1)
        $markers = Get-ChildItem -Path $roots -Filter $LocaleFile -Recurse -Depth 4 -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.DirectoryName.EndsWith($needle) }

        foreach ($marker in ($markers | Select-Object -First 20)) {
            if ($found.Contains($marker.FullName)) { continue }
            Write-Info "Found via search: $($marker.FullName)"
            $found.Add($marker.FullName)
        }
    }

    return $found.ToArray()
}

function Test-TargetWritable {
    param([string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }

    $probe = Join-Path $Path ".ttl-write-probe-$([System.Guid]::NewGuid().ToString('N'))"
    try {
        New-Item -ItemType File -Path $probe -Force -ErrorAction Stop | Out-Null
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

function Restart-Elevated {
    $tempScript = Join-Path ([System.IO.Path]::GetTempPath()) "ttl-uninstall-$([System.Guid]::NewGuid().ToString('N')).ps1"

    Write-Warn 'Administrator access is required. A UAC prompt will appear - accept it to continue.'

    try {
        Invoke-Download -Url $ScriptUrl -OutFile $tempScript
        $hostExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tempScript)
        $process = Start-Process -FilePath $hostExe -ArgumentList $arguments -Verb RunAs -Wait -PassThru
        return $process.ExitCode
    } catch {
        Write-Fail "Elevation failed or was cancelled: $($_.Exception.Message)"
        return 1
    } finally {
        Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue
    }
}

Write-Info "TwintailLauncher pt_BR language uninstaller $ScriptVersion"
if ($DryRun) { Write-Info 'Dry run: no file will be deleted.' }
Write-Info "Looking for $LocaleFile in TwintailLauncher locales directories..."

$files = @(Get-InstalledLocaleFiles)

if ($files.Count -eq 0) {
    Write-Ok "Nothing to remove - no $LocaleFile found. The language pack does not appear to be installed."
    Write-Host ''
    Write-Host 'Next steps:'
    Write-Host '  Nothing to do. If the launcher still shows Portuguese, fully close'
    Write-Host '  it (system tray -> Quit) and reopen it.'
    exit 0
}

Write-Info "Found $($files.Count) installed file(s):"
foreach ($file in $files) { Write-Host "  - $file" }
Write-Host ''

$writable = @($files | Where-Object { Test-TargetWritable -Path (Split-Path -Parent $_) })

if (-not $DryRun -and $writable.Count -eq 0 -and -not (Test-Administrator)) {
    $code = Restart-Elevated
    if ($code -eq 0) { exit 0 }
    Write-Fail 'Administrator removal failed or was cancelled.'
    exit 1
}

$removedCount = 0
foreach ($file in $files) {
    if ($DryRun) {
        Write-Info "[dry-run] Would remove $file"
        $removedCount++
        continue
    }

    Write-Info "Removing $file..."
    try {
        Remove-Item -LiteralPath $file -Force -ErrorAction Stop
    } catch {
        Write-Warn "Failed to remove ${file}: $($_.Exception.Message)"
        continue
    }

    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        Write-Ok "Removed $file"
        $removedCount++
    }
}

Write-Host ''
if ($removedCount -eq 0) {
    Write-Fail 'Failed to remove the language pack from any location.'
    Write-Host ''
    Write-Host 'Manual removal:'
    Write-Host '  1. Locate the file:'
    Write-Host '     Get-ChildItem "$env:LOCALAPPDATA","$env:ProgramFiles" -Filter pt_BR.json -Recurse -Depth 4 -ErrorAction SilentlyContinue'
    Write-Host '  2. Delete it (right-click > Run as administrator if needed):'
    Write-Host "     Remove-Item '<path>\resources\locales\$LocaleFile' -Force"
    exit 1
}

if ($DryRun) {
    Write-Ok "Dry run finished: $removedCount file(s) would be removed."
} else {
    Write-Ok "Successfully removed $LocaleFile from $removedCount location(s)!"
}

Write-Host ''
Write-Host 'Next steps:'
Write-Host '  1. Fully close TwintailLauncher (system tray -> Quit) and reopen it'
Write-Host '  2. Go to Launcher Settings > General > Application language'
Write-Host '  3. Select another language (English is the default)'
Write-Host ''
Write-Host 'To verify:'
Write-Host "  Get-ChildItem `"$env:LOCALAPPDATA`" -Filter $LocaleFile -Recurse -Depth 4 -ErrorAction SilentlyContinue"
Write-Host '  # should print nothing'