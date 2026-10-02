param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InfraDir = Split-Path -Parent $ScriptDir
$Template = Join-Path $InfraDir '.env.example'
$Target = Join-Path $InfraDir '.env'
$TempTarget = Join-Path $InfraDir ('.env.tmp.' + [Guid]::NewGuid().ToString('N'))

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
# Normaliser volontairement en LF, même sous Windows : Docker et les scripts Unix
# consomment ainsi exactement le même format de .env sur toutes les plateformes.
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

try {
    # Écrire dans le même répertoire puis renommer évite de laisser un .env tronqué
    # si le processus est interrompu pendant l'écriture.
    [System.IO.File]::WriteAllText($TempTarget, $content, $utf8NoBom)

    # Équivalent Windows du umask 077 de generer-env.sh : le fichier contenant
    # les secrets n'est accessible qu'au compte qui l'a généré.
    $isWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
        [System.Runtime.InteropServices.OSPlatform]::Windows
    )
    if ($isWindows) {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $acl = Get-Acl -LiteralPath $TempTarget
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($existingRule in @($acl.Access)) {
            [void]$acl.RemoveAccessRuleAll($existingRule)
        }
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $identity,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        $acl.SetAccessRule($rule)
        Set-Acl -LiteralPath $TempTarget -AclObject $acl
    }

    Move-Item -LiteralPath $TempTarget -Destination $Target -Force
}
finally {
    if (Test-Path -LiteralPath $TempTarget) {
        Remove-Item -LiteralPath $TempTarget -Force -ErrorAction SilentlyContinue
    }
}

Write-Host 'OK: .env créé avec des secrets aléatoires distincts.'
Write-Host "Fichier: $Target"
Write-Host 'Ne jamais committer ni partager ce fichier.'
