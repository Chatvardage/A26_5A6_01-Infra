$ErrorActionPreference = 'Stop'

$Repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$Root = Join-Path ([System.IO.Path]::GetTempPath()) ("chatvardage-env-ps-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Root | Out-Null

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function New-Fixture([string]$MissingKey = '') {
    $dir = Join-Path $Root ([Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts') -Force | Out-Null
    Copy-Item (Join-Path $Repo 'scripts/generer-env.ps1') (Join-Path $dir 'scripts/generer-env.ps1')
    $content = [IO.File]::ReadAllText((Join-Path $Repo '.env.example'))
    if ($MissingKey) {
        $escaped = [regex]::Escape($MissingKey)
        $content = [regex]::Replace($content, "(?m)^$escaped=.*(?:`r?`n|$)", '')
    }
    [IO.File]::WriteAllText((Join-Path $dir '.env.example'), $content)
    return $dir
}

try {
    $dir = New-Fixture
    & (Join-Path $dir 'scripts/generer-env.ps1')
    $target = Join-Path $dir '.env'
    Assert-True (Test-Path $target) 'Le .env doit être créé.'
    $content = [IO.File]::ReadAllText($target)
    Assert-True (-not $content.Contains("`r")) 'Le .env doit être normalisé en LF.'

    $names = @('POSTGRES_SUPERPASS','AUTH_DB_PASSWORD','ROOMS_DB_PASSWORD','MESSAGES_DB_PASSWORD','CONFIG_DB_PASSWORD','REDIS_PASSWORD','JWT_SECRET','INTERNAL_SERVICE_TOKEN','DASHBOARD_COOKIE_SECRET','DASHBOARD_SESSION_SECRET')
    $values = foreach ($name in $names) {
        $match = [regex]::Match($content, "(?m)^$name=([0-9a-f]{64})$")
        Assert-True $match.Success "$name doit contenir 64 caractères hexadécimaux."
        $match.Groups[1].Value
    }
    Assert-True (($values | Sort-Object -Unique).Count -eq $names.Count) 'Tous les secrets doivent être distincts.'

    $acl = Get-Acl -LiteralPath $target
    Assert-True $acl.AreAccessRulesProtected 'Le .env ne doit pas hériter des ACL du dossier parent.'
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $allowed = @($acl.Access | Where-Object { $_.IdentityReference.Value -eq $identity -and $_.AccessControlType -eq 'Allow' })
    Assert-True ($allowed.Count -ge 1) 'Le compte courant doit conserver un accès au .env.'

    $before = [IO.File]::ReadAllText($target)
    $refused = $false
    try { & (Join-Path $dir 'scripts/generer-env.ps1') } catch { $refused = $true }
    Assert-True $refused 'Un .env existant doit être refusé sans -Force.'
    Assert-True ([IO.File]::ReadAllText($target) -eq $before) 'Le refus ne doit pas modifier le .env existant.'

    & (Join-Path $dir 'scripts/generer-env.ps1') -Force
    Assert-True ([IO.File]::ReadAllText($target) -ne $before) '-Force doit régénérer les secrets.'
    Assert-True (@(Get-ChildItem $dir -Filter '.env.tmp.*').Count -eq 0) 'Aucun fichier temporaire ne doit rester après succès.'

    $missing = New-Fixture 'JWT_SECRET'
    $failed = $false
    try { & (Join-Path $missing 'scripts/generer-env.ps1') } catch { $failed = $_.Exception.Message -match 'JWT_SECRET' }
    Assert-True $failed 'Une clé obligatoire absente doit provoquer une erreur explicite.'
    Assert-True (-not (Test-Path (Join-Path $missing '.env'))) 'Aucun .env ne doit être publié si le template est invalide.'

    Write-Host 'Tests generer-env.ps1 : OK'
}
finally {
    Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue
}
