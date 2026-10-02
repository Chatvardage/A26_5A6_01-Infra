param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InfraDir = Split-Path -Parent $ScriptDir
$Template = Join-Path $InfraDir '.env.example'
$Target = Join-Path $InfraDir '.env'

if (-not (Test-Path -LiteralPath $Template)) {
    throw "Modèle introuvable: $Template"
}

if ((Test-Path -LiteralPath $Target) -and -not $Force) {
    throw "$Target existe déjà. Relancez avec -Force pour le remplacer."
}

function New-HexSecret {
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($bytes)
    }
    finally {
        $rng.Dispose()
    }
    return ([System.BitConverter]::ToString($bytes)).Replace('-', '').ToLowerInvariant()
}

$secretNames = @(
    'POSTGRES_SUPERPASS',
    'AUTH_DB_PASSWORD',
    'ROOMS_DB_PASSWORD',
    'MESSAGES_DB_PASSWORD',
    'CONFIG_DB_PASSWORD',
    'REDIS_PASSWORD',
    'JWT_SECRET',
    'INTERNAL_SERVICE_TOKEN',
    'DASHBOARD_COOKIE_SECRET',
    'DASHBOARD_SESSION_SECRET'
)

$values = @{}
foreach ($name in $secretNames) {
    $values[$name] = New-HexSecret
}

$content = [System.IO.File]::ReadAllText($Template)
# Normaliser les fins de ligne avant remplacement pour produire un fichier cohérent.
$content = $content -replace "`r`n", "`n" -replace "`r", "`n"
foreach ($name in $secretNames) {
    $escaped = [regex]::Escape($name)
    $replacement = "$name=$($values[$name])"
    if ($content -notmatch "(?m)^$escaped=.*$") {
        throw "Clé manquante dans le template : $name"
    }
    $content = [regex]::Replace($content, "(?m)^$escaped=.*$", $replacement)
}

foreach ($name in $secretNames) {
    $escaped = [regex]::Escape($name)
    if ($content -notmatch "(?m)^$escaped=.+$") {
        throw "Secret non généré correctement : $name"
    }
}

# UTF-8 sans BOM pour éviter qu'un BOM soit interprété dans le premier nom de variable.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($Target, $content, $utf8NoBom)

Write-Host 'OK: .env créé avec des secrets aléatoires distincts.'
Write-Host "Fichier: $Target"
Write-Host 'Ne jamais committer ni partager ce fichier.'
