<#
.SYNOPSIS
    Turnkey Windows VPS Seed & Bootstrap for Hermes Agent.
.DESCRIPTION
    Bootstraps a brand-new Windows VPS into a fully operational Hermes Agent Discord bot
    with Supabase task synchronization in a single command.
    Reads configuration directly from .env.
#>

[CmdletBinding()]
param (
    [string]$EnvFile = ".env"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       Hermes Agent - Windows VPS Quickstart Seed         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Parse .env file
$envPath = Join-Path $PSScriptRoot $EnvFile
$config = @{}

if (Test-Path $envPath) {
    Write-Host "[+] Loading configuration from $EnvFile..." -ForegroundColor Green
    Get-Content $envPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $key = $parts[0].Trim()
            $val = $parts[1].Trim().Trim('"').Trim("'")
            $config[$key] = $val
        }
    }
} else {
    Write-Host "[!] No $EnvFile file found. Checking .env.example..." -ForegroundColor Yellow
    $examplePath = Join-Path $PSScriptRoot ".env.example"
    if (Test-Path $examplePath) {
        Write-Host "[!] Tip: Run 'Copy-Item .env.example .env' and paste your API keys." -ForegroundColor Yellow
    }
}

function Get-Val {
    param ([string]$Key, [string]$Default = "")
    if ($config.ContainsKey($Key) -and $config[$Key] -ne "") { return $config[$Key] }
    $envVal = [System.Environment]::GetEnvironmentVariable($Key, "User")
    if ($envVal -and $envVal -ne "") { return $envVal }
    $envProcess = [System.Environment]::GetEnvironmentVariable($Key, "Process")
    if ($envProcess -and $envProcess -ne "") { return $envProcess }
    return $Default
}

$deepseekKey = Get-Val "DEEPSEEK_API_KEY"
$deepseekModel = Get-Val "DEEPSEEK_MODEL" "deepseek-chat"
$deepseekBaseUrl = Get-Val "DEEPSEEK_BASE_URL" "https://api.deepseek.com"
$supabaseUrl = Get-Val "SUPABASE_URL" "https://wlzhcjogingzpvudlaze.supabase.co"
$supabaseKey = Get-Val "SUPABASE_SECRET_KEY"
$discordToken = Get-Val "DISCORD_BOT_TOKEN"
$discordUserId = Get-Val "DISCORD_USER_ID"

# 2. Verify / Install Hermes CLI
Write-Host ""
Write-Host "[1/5] Verifying Hermes CLI runtime..." -ForegroundColor Cyan
$hermesCmd = Get-Command hermes -ErrorAction SilentlyContinue

if (-not $hermesCmd) {
    Write-Host "[+] Hermes not detected in PATH. Downloading and installing official Hermes CLI..." -ForegroundColor Yellow
    try {
        Invoke-Expression (Invoke-RestMethod https://hermes-agent.nousresearch.com/install.ps1)
        Write-Host "[OK] Installation completed." -ForegroundColor Green
    } catch {
        Write-Host "[!] Installer note: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "[OK] Hermes CLI detected at: $($hermesCmd.Source)" -ForegroundColor Green
}

# Ensure Hermes bin directories are in current process PATH and User PATH permanently
$binPaths = @(
    (Join-Path $env:LOCALAPPDATA "hermes\bin"),
    (Join-Path $env:USERPROFILE ".hermes\bin")
)

foreach ($bp in $binPaths) {
    if (Test-Path $bp) {
        if ($env:PATH -notlike "*$bp*") {
            $env:PATH = $bp + ";" + $env:PATH
            Write-Host "[OK] Added $bp to current session PATH." -ForegroundColor Green
        }
        $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
        if ($userPath -notlike "*$bp*") {
            [System.Environment]::SetEnvironmentVariable("PATH", "$bp;$userPath", "User")
            Write-Host "[OK] Permanently added $bp to User PATH." -ForegroundColor Green
        }
    }
}

# 3. Configure LLM Provider (DeepSeek)
Write-Host ""
Write-Host "[2/5] Configuring LLM Provider (DeepSeek)..." -ForegroundColor Cyan
try {
    hermes config set providers.custom.base_url $deepseekBaseUrl
    hermes config set model.default $deepseekModel
    Write-Host "[OK] Configured provider base_url ($deepseekBaseUrl) and model ($deepseekModel)." -ForegroundColor Green
} catch {
    Write-Host "[!] Note on provider configuration: $_" -ForegroundColor Yellow
}

if ($deepseekKey -ne "") {
    try {
        hermes config set providers.custom.api_key $deepseekKey
        Write-Host "[OK] Configured DeepSeek API key in Hermes config." -ForegroundColor Green
    } catch {
        Write-Host "[!] Could not set API key: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "[!] DEEPSEEK_API_KEY is empty in .env. Run: hermes config set providers.custom.api_key <KEY>" -ForegroundColor Yellow
}

# 4. Deploy Custom Skills & Python Environment
Write-Host ""
Write-Host "[3/5] Deploying Custom Skills and Python SDK..." -ForegroundColor Cyan

# Locate Hermes internal Python or system python
$hermesPython = $null
$pythonCandidate = Join-Path $env:LOCALAPPDATA "hermes\tools\python-3.14.7+20260901-win32-x64\python.exe"
if (Test-Path $pythonCandidate) {
    $hermesPython = $pythonCandidate
} else {
    $foundPy = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA "hermes") -Filter "python.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($foundPy) { $hermesPython = $foundPy.FullName }
}

if ($hermesPython) {
    Write-Host "[+] Hermes Python detected: $hermesPython"
    $pyDir = Split-Path -Parent $hermesPython
    $scriptsDir = Join-Path $pyDir "Scripts"

    # Add Hermes Python and Scripts to session and User PATH (prepending before WindowsApps)
    foreach ($p in @($pyDir, $scriptsDir)) {
        if (Test-Path $p) {
            if ($env:PATH -notlike "*$p*") {
                $env:PATH = $p + ";" + $env:PATH
            }
            $currentUserPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
            $uParts = ($currentUserPath -split ";") | Where-Object { $_ -ne "" }
            if ($uParts -notcontains $p) {
                $newU = (@($p) + $uParts) -join ";"
                [System.Environment]::SetEnvironmentVariable("PATH", $newU, "User")
                Write-Host "[OK] Registered $p in User PATH." -ForegroundColor Green
            }
        }
    }

    # Install supabase package into Python tool runtime
    & $hermesPython -m pip install supabase --quiet
    Write-Host "[OK] Supabase SDK installed into Hermes Python runtime." -ForegroundColor Green

    # Also install into Hermes runtime venv if present using uv or direct python
    $foundVenvPy = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA "hermes\installs") -Filter "python.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($foundVenvPy) {
        $uvExe = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA "hermes") -Filter "uv.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($uvExe) {
            & $uvExe.FullName pip install supabase --python $foundVenvPy.FullName --quiet 2>$null
        }
    }

    # Create .vscode/settings.json and pyrightconfig.json in workspace to resolve LSP imports
    $vscodeDir = Join-Path $PSScriptRoot ".vscode"
    if (-not (Test-Path $vscodeDir)) { New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null }
    $sitePackages = Join-Path $pyDir "Lib\site-packages"
    
    $vscodeSettings = @{
        "python.defaultInterpreterPath" = $hermesPython
        "python.analysis.extraPaths" = @($sitePackages)
    } | ConvertTo-Json -Depth 4
    Set-Content -Path (Join-Path $vscodeDir "settings.json") -Value $vscodeSettings -Encoding UTF8

    $pyrightConfig = @{
        "pythonPath" = $hermesPython
        "extraPaths" = @($sitePackages, "skills/supabase_tasks")
    } | ConvertTo-Json -Depth 4
    Set-Content -Path (Join-Path $PSScriptRoot "pyrightconfig.json") -Value $pyrightConfig -Encoding UTF8
    Write-Host "[OK] Workspace IDE settings (.vscode/settings.json & pyrightconfig.json) configured." -ForegroundColor Green
} else {
    try {
        pip install supabase --quiet
        Write-Host "[OK] Supabase SDK installed via system pip." -ForegroundColor Green
    } catch {
        Write-Host "[!] Note on pip install: $_" -ForegroundColor Yellow
    }
}

# Copy skills to ~/.hermes/skills and ~/AppData/Local/hermes/skills
$skillsSource = Join-Path $PSScriptRoot "skills"
$targetSkillDirs = @(
    (Join-Path $env:USERPROFILE ".hermes\skills"),
    (Join-Path $env:LOCALAPPDATA "hermes\skills")
)

if (Test-Path $skillsSource) {
    foreach ($td in $targetSkillDirs) {
        if (-not (Test-Path $td)) {
            New-Item -ItemType Directory -Path $td -Force | Out-Null
        }
        Copy-Item -Path "$skillsSource\*" -Destination $td -Recurse -Force
        Write-Host "[OK] Skills deployed to: $td" -ForegroundColor Green
    }
}

# 5. Configure Persistent Environment Variables
Write-Host ""
Write-Host "[4/5] Setting persistent environment variables..." -ForegroundColor Cyan
[System.Environment]::SetEnvironmentVariable("SUPABASE_URL", $supabaseUrl, "User")
$env:SUPABASE_URL = $supabaseUrl
Write-Host "[OK] Set User environment variable: SUPABASE_URL = $supabaseUrl" -ForegroundColor Green

if ($supabaseKey -ne "") {
    [System.Environment]::SetEnvironmentVariable("SUPABASE_SECRET_KEY", $supabaseKey, "User")
    $env:SUPABASE_SECRET_KEY = $supabaseKey
    Write-Host "[OK] Set User environment variable: SUPABASE_SECRET_KEY" -ForegroundColor Green
} else {
    Write-Host "[!] SUPABASE_SECRET_KEY is empty in .env." -ForegroundColor Yellow
}

# 6. Discord Gateway Configuration
Write-Host ""
Write-Host "[5/5] Configuring Discord Gateway..." -ForegroundColor Cyan

if ($discordToken -ne "") {
    $tokenLine = "DISCORD_BOT_TOKEN=$discordToken"
    $hermesEnvPaths = @(
        (Join-Path $env:LOCALAPPDATA "hermes\.env"),
        (Join-Path $env:USERPROFILE ".hermes\.env")
    )
    foreach ($hep in $hermesEnvPaths) {
        $parent = Split-Path $hep
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        if (Test-Path $hep) {
            $existing = Get-Content $hep -Raw
            if ($existing -notmatch "DISCORD_BOT_TOKEN") {
                Add-Content -Path $hep -Value "`n$tokenLine"
            }
        } else {
            Set-Content -Path $hep -Value $tokenLine
        }
    }
    Write-Host "[OK] Injected Discord Bot Token into Hermes runtime environment." -ForegroundColor Green
} else {
    Write-Host "[!] DISCORD_BOT_TOKEN is empty in .env. Run 'hermes gateway setup' to bind interactively." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "       Windows VPS Quickstart Seed Complete!              " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "To bring the Discord Bot online and start the daemon:"
Write-Host "1. (Optional) Run interactive gateway setup to allowlist your user ID:" -ForegroundColor Cyan
Write-Host "   hermes gateway setup"
Write-Host "2. Start the Hermes Gateway daemon in the background:" -ForegroundColor Cyan
Write-Host "   hermes gateway start"
Write-Host "3. Inspect connection status:" -ForegroundColor Cyan
Write-Host "   hermes gateway status"
