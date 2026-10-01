<#
.SYNOPSIS
    Installs the TwintailLauncher Brazilian Portuguese (pt_BR) language pack on Windows.

.DESCRIPTION
    Downloads pt_BR.json, validates it, auto-detects the TwintailLauncher
    locales directory (registry, standard install paths, then a bounded
    filesystem search) and copies the file into place, elevating to
    administrator only when the target folder is not writable.

.PARAMETER Version
    Prints the script version and exits.

.EXAMPLE
    irm https://raw.githubusercontent.com/zonaro/TwinTailLauncher-br-lang/main/install.ps1 | iex

.EXAMPLE
    .\install.ps1
#>
[CmdletBinding()]
param(
    [switch] $Version
)

$ErrorActionPreference = 'Stop'

$ScriptVersion = '1.0.0'
$LocaleFile    = 'pt_BR.json'
$MarkerFile    = 'en_US.json'
$LocaleDirName = 'resources\locales'
$RawBase       = 'https://raw.githubusercontent.com/zonaro/TwinTailLauncher-br-lang/main'
$LocaleUrl     = "$RawBase/$LocaleFile"
$ScriptUrl     = "$RawBase/install.ps1"

if ($Version) {
    Write-Output "install.ps1 $ScriptVersion"
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

function Test-JsonSyntax {
    param([string] $Path)

    $stream = [System.IO.MemoryStream]::new([System.IO.File]::ReadAllBytes($Path))
    $reader = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader(
        $stream, [System.Xml.XmlDictionaryReaderQuotas]::Max)

    try {
        while ($reader.Read()) { }
        return $null
    } catch {
        $reason = $_.Exception.Message
        if ($_.Exception.InnerException) { $reason = $_.Exception.InnerException.Message }
        return $reason
    } finally {
        $reader.Close()
        $stream.Dispose()
    }
}

function Assert-LocaleFile {
    param([string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) { return "Downloaded file was not created: $Path" }
    if ((Get-Item -LiteralPath $Path).Length -eq 0) { return 'Downloaded file is empty' }

    $invalid = Test-JsonSyntax -Path $Path
    if ($invalid) { return "Downloaded file is not valid JSON: $invalid" }
    return $null
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
                $key = $null
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

function Get-LocalesDirs {
    $validated = New-Object System.Collections.Generic.List[string]

    foreach ($root in (Get-CandidateInstallDirs)) {
        $locales = Join-Path $root $LocaleDirName
        if ($validated.Contains($locales)) { continue }
        if (Test-Path -LiteralPath (Join-Path $locales $MarkerFile) -PathType Leaf) { $validated.Add($locales) }
    }

    if ($validated.Count -gt 0) { return $validated.ToArray() }

    Write-Warn 'No locales directory found via candidates, searching the filesystem (this may take a few seconds)...'

    $roots = @($env:LOCALAPPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)}) |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }

    if ($roots.Count -gt 0) {
        $needle = (Join-Path 'x' $LocaleDirName).Substring(1)
        $markers = Get-ChildItem -Path $roots -Filter $MarkerFile -Recurse -Depth 4 -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.DirectoryName.EndsWith($needle) }

        foreach ($marker in ($markers | Select-Object -First 10)) {
            $dir = $marker.DirectoryName
            if ($validated.Contains($dir)) { continue }
            Write-Info "Found via search: $dir"
            $validated.Add($dir)
        }
    }

    return $validated.ToArray()
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
    $tempScript = Join-Path ([System.IO.Path]::GetTempPath()) "ttl-install-$([System.Guid]::NewGuid().ToString('N')).ps1"

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

Write-Info "TwintailLauncher pt_BR language installer $ScriptVersion"
Write-Info "Downloading $LocaleFile from $LocaleUrl..."

$tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) $LocaleFile
Invoke-Download -Url $LocaleUrl -OutFile $tmpFile

$invalid = Assert-LocaleFile -Path $tmpFile
if ($invalid) { Write-Fail $invalid; exit 1 }

$size = (Get-Item -LiteralPath $tmpFile).Length
Write-Ok "Downloaded and validated $LocaleFile ($size bytes)"

$localesDirs = @(Get-LocalesDirs)

if ($localesDirs.Count -eq 0) {
    Write-Fail 'Could not find a TwintailLauncher installation.'
    Write-Host ''
    Write-Host 'Manual installation:'
    Write-Host '  1. Locate your TwintailLauncher installation (where en_US.json lives):'
    Write-Host '     Get-ChildItem "$env:LOCALAPPDATA","$env:ProgramFiles" -Filter en_US.json -Recurse -Depth 4 -ErrorAction SilentlyContinue'
    Write-Host '  2. Copy the file next to it:'
    Write-Host "     Copy-Item `"$tmpFile`" '<path>\resources\locales\$LocaleFile'"
    Write-Host '  3. Restart TwintailLauncher and select Portuguese (Brazil) in Settings > Language'
    exit 1
}

Write-Info "Found $($localesDirs.Count) locales directory(ies):"
foreach ($dir in $localesDirs) { Write-Host "  - $dir" }
Write-Host ''

$writable = @($localesDirs | Where-Object { Test-TargetWritable -Path $_ })

if ($writable.Count -eq 0 -and -not (Test-Administrator)) {
    $code = Restart-Elevated
    if ($code -eq 0) { exit 0 }
    Write-Fail 'Administrator installation failed or was cancelled.'
    exit 1
}

$successCount = 0
foreach ($dir in $localesDirs) {
    $destFile = Join-Path $dir $LocaleFile
    Write-Info "Installing to $destFile..."

    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        if (Test-Administrator) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        } else {
            Write-Warn "Skipped $dir (directory does not exist and elevation is required)"
            continue
        }
    }

    try {
        Copy-Item -LiteralPath $tmpFile -Destination $destFile -Force
    } catch {
        Write-Warn "Failed to copy to $destFile : $($_.Exception.Message)"
        continue
    }

    if (Test-Path -LiteralPath $destFile -PathType Leaf) {
        $installedSize = (Get-Item -LiteralPath $destFile).Length
        Write-Ok "Installed $destFile ($installedSize bytes)"
        $successCount++
    }
}

Write-Host ''
if ($successCount -eq 0) {
    Write-Fail 'Failed to install to any location.'
    exit 1
}

Write-Ok "Successfully installed $LocaleFile to $successCount location(s)!"
Write-Host ''
Write-Host 'Next steps:'
Write-Host '  1. Fully close TwintailLauncher (system tray -> Quit)'
Write-Host '  2. Go to Launcher Settings > General > Application language'
Write-Host '  3. Select "Portuguese (Brazil)" and restart if prompted'
Write-Host ''
Write-Host 'To verify:'
Write-Host "  Get-Item `"$($localesDirs[0])\$LocaleFile`" | Format-List Name,Length"