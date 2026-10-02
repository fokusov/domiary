#requires -Version 7.0
[CmdletBinding()]
param(
    [string] $Source = 'src',
    [switch] $Clean,
    [string] $V8Path
)

. (Join-Path $PSScriptRoot 'config-common.ps1')
$lock = $null
$result = 2
try {
    $sourcePath = Resolve-ConfigSource $Source
    $script:Platform = Resolve-V8 $V8Path
    Write-Host "Платформа: $script:Platform"
    $lock = Enter-ConfigLock
    Initialize-ConfigBase -Clean:$Clean
    Import-Config $sourcePath
    $contexts = @('-ThinClient', '-Server', '-MobileAppClient', '-MobileAppServer', '-MobileClient')
    $modules = Invoke-ConfigStep 'modules' ($script:DesignerArgs + @('/CheckModules') + $contexts)
    $config = Invoke-ConfigStep 'config' ($script:DesignerArgs + @('/CheckConfig') + $contexts + @(
        '-IncorrectReferences', '-HandlersExistence', '-EmptyHandlers', '-ExtendedModulesCheck', '-CheckUseModality'))
    if ($modules -notin @(0, 101) -or $config -notin @(0, 101)) {
        throw 'Неожиданный код платформы при проверке.'
    }
    $result = if ($modules -eq 0 -and $config -eq 0) { 0 } else { 1 }
} catch {
    Write-Host "Ошибка запуска: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($lock) { $lock.Dispose() }
}
Write-Host "Итог проверки: $result"
exit $result
