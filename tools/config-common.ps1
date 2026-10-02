#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:BuildRoot = Join-Path $script:ProjectRoot '.build'
$script:Infobase = Join-Path $script:BuildRoot 'ib'
$script:LogRoot = Join-Path $script:BuildRoot 'logs'

function Assert-NoLinks([string] $Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Ссылки и junction не поддерживаются: $current"
            }
        }
        $current = Split-Path $current -Parent
    }
    if (Test-Path -LiteralPath $Path -PathType Container) {
        foreach ($item in Get-ChildItem -LiteralPath $Path -Force -Recurse) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Ссылки и junction не поддерживаются: $($item.FullName)"
            }
        }
    }
}

function Test-Within([string] $Path, [string] $Parent) {
    return $Path.Equals($Parent, [StringComparison]::OrdinalIgnoreCase) -or
        $Path.StartsWith($Parent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Resolve-ConfigSource([string] $Source) {
    $path = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($Source, $script:ProjectRoot))
    Assert-NoLinks $path
    if (-not (Test-Path -LiteralPath (Join-Path $path 'Configuration.xml') -PathType Leaf)) {
        throw "Нет Configuration.xml в каталоге: $path"
    }
    if (Test-Within $script:ProjectRoot $path) { throw 'Source не должен быть корнем проекта или его родителем.' }
    foreach ($relative in @('base', 'pub', '.build/ib', '.build/dump', '.build/logs')) {
        $protected = [IO.Path]::GetFullPath((Join-Path $script:ProjectRoot $relative))
        if ((Test-Within $path $protected) -or (Test-Within $protected $path)) {
            throw "Source пересекается с защищённым каталогом: $protected"
        }
    }
    return $path
}

function Resolve-V8([string] $V8Path) {
    if (-not $V8Path) { $V8Path = $env:V8_PATH }
    if (-not $V8Path) {
        $candidates = @(Get-ChildItem 'C:\Program Files\1cv8\8.5.*\bin\1cv8.exe' -ErrorAction SilentlyContinue |
            Sort-Object { [version] $_.Directory.Parent.Name } -Descending)
        if ($candidates.Count) { $V8Path = $candidates[0].FullName }
    }
    if (-not $V8Path -or -not (Test-Path -LiteralPath $V8Path -PathType Leaf)) {
        throw 'Платформа не найдена. Укажи -V8Path или V8_PATH (путь к 1cv8.exe).'
    }
    return (Resolve-Path -LiteralPath $V8Path).ProviderPath
}

function Enter-ConfigLock {
    Assert-NoLinks $script:BuildRoot
    New-Item -ItemType Directory -Path $script:BuildRoot -Force | Out-Null
    try {
        return [IO.File]::Open((Join-Path $script:BuildRoot 'config.lock'),
            [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    } catch {
        throw "Не удалось занять .build/config.lock. Проверь, не запущен ли другой скрипт. $($_.Exception.Message)"
    }
}

function Invoke-ConfigStep([string] $Name, [string[]] $Arguments) {
    $log = Join-Path $script:LogRoot "$Name.log"
    if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log -Force }
    # Start-Process склеивает ArgumentList: кавычки нужны и для путей с пробелами.
    $quoted = foreach ($argument in ($Arguments + @('/Out', $log))) {
        if ($argument.Contains('"') -or $argument.Contains("`n") -or $argument.Contains("`r")) {
            throw 'Недопустимый символ в аргументе запуска.'
        }
        if ($argument -match '\s') { '"' + $argument + '"' } else { $argument }
    }
    $process = Start-Process -FilePath $script:Platform -ArgumentList $quoted -Wait -PassThru
    $code = $process.ExitCode
    Write-Host "[$Name] код платформы: $code; лог: $log"
    if (-not (Test-Path -LiteralPath $log -PathType Leaf)) { throw "[$Name] Платформа не создала лог." }
    $text = Get-Content -LiteralPath $log -Raw -Encoding utf8
    if ($text) { Write-Host $text.TrimEnd() }
    return $code
}

function Initialize-ConfigBase([switch] $Clean) {
    New-Item -ItemType Directory -Path $script:LogRoot -Force | Out-Null
    if ($Clean -and (Test-Path -LiteralPath $script:Infobase)) {
        Remove-Item -LiteralPath $script:Infobase -Recurse -Force
    }
    if (-not (Test-Path -LiteralPath (Join-Path $script:Infobase '1Cv8.1CD') -PathType Leaf)) {
        # В строке соединения кавычки отделяют значение File, а не весь аргумент.
        $log = Join-Path $script:LogRoot 'create.log'
        if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log -Force }
        $process = Start-Process -FilePath $script:Platform -ArgumentList @(
            'CREATEINFOBASE', ('File="{0}"' -f $script:Infobase),
            '/Out', ('"{0}"' -f $log), '/DisableStartupDialogs'
        ) -Wait -PassThru
        Write-Host "[create] код платформы: $($process.ExitCode); лог: $log"
        if (Test-Path -LiteralPath $log) { Write-Host (Get-Content -LiteralPath $log -Raw -Encoding utf8) }
        if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $script:Infobase '1Cv8.1CD'))) {
            throw 'Не удалось создать временную базу.'
        }
    } else { Write-Host '[create] используется существующая .build/ib' }
    $script:DesignerArgs = @('DESIGNER', '/F', $script:Infobase,
        '/DisableStartupDialogs', '/DisableStartupMessages')
}

function Import-Config([string] $Source) {
    $code = Invoke-ConfigStep 'load' ($script:DesignerArgs + @('/LoadConfigFromFiles', $Source, '/UpdateDBCfg'))
    if ($code -ne 0) { throw "Не удалось загрузить конфигурацию (код $code)." }
}
