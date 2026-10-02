#requires -Version 7.0
[CmdletBinding()]
param(
    [string] $Source = 'src',
    [string] $V8Path
)

. (Join-Path $PSScriptRoot 'config-common.ps1')
$lock = $null
$result = 2
try {
    $sourcePath = Resolve-ConfigSource $Source
    $script:Platform = Resolve-V8 $V8Path
    Write-Host "Платформа: $script:Platform"
    Get-Command robocopy.exe, git -ErrorAction Stop | Out-Null
    $lock = Enter-ConfigLock
    # Чистая база исключает попадание объектов предыдущей конфигурации в выгрузку.
    Initialize-ConfigBase -Clean
    Import-Config $sourcePath
    $dump = Join-Path $script:BuildRoot 'dump'
    if (Test-Path -LiteralPath $dump) { Remove-Item -LiteralPath $dump -Recurse -Force }
    New-Item -ItemType Directory -Path $dump | Out-Null
    $code = Invoke-ConfigStep 'dump' ($script:DesignerArgs + @('/DumpConfigToFiles', $dump, '-Format', 'Hierarchical'))
    if ($code -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $dump 'Configuration.xml'))) {
        throw 'Не удалось получить полную выгрузку; исходники не изменены.'
    }
    Assert-NoLinks $sourcePath
    & robocopy.exe $dump $sourcePath /MIR /XF ConfigDumpInfo.xml DumpFilesIndex.txt /XJ /R:0 /W:0 /NP /NJH /NJS
    if ($LASTEXITCODE -ge 8) { throw "Ошибка зеркалирования robocopy: $LASTEXITCODE. Проверь исходники и .build/dump." }
    & git -C $script:ProjectRoot status --short -- src
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось получить git status.' }
    if ($sourcePath -ne (Join-Path $script:ProjectRoot 'src') -and (Test-Within $sourcePath $script:ProjectRoot)) {
        & git -C $script:ProjectRoot status --short -- $sourcePath
    }
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось получить git status.' }
    $result = 0
} catch {
    Write-Host "Ошибка нормализации: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($lock) { $lock.Dispose() }
}
Write-Host "Итог нормализации: $result"
exit $result
