#requires -Version 7.0
[CmdletBinding()]
param(
    [switch] $Prepare,
    [switch] $IncludeNegativeControl,
    [string] $V8Path,
    [ValidateRange(1, 3600)] [int] $TimeoutSeconds = 120
)

. (Join-Path $PSScriptRoot 'config-common.ps1')
$lock = $null
$result = 1
$runPath = $null
$summary = [ordered]@{
    startedAtUtc = [DateTime]::UtcNow.ToString('o')
    target = $script:Infobase
    prepare = [bool] $Prepare
    includeNegativeControl = [bool] $IncludeNegativeControl
    platformExitCode = $null
    yaxunitExitCode = $null
    tests = 0
    failures = 0
    errors = 0
    skipped = 0
    status = 'BLOCKED'
}

function Invoke-ExtensionCommand([string[]] $Arguments) {
    $output = & $script:IbCmd extension @Arguments "--db-path=$script:Infobase" "--data=$script:BuildRoot/ibcmd" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "ibcmd: $($output -join [Environment]::NewLine)" }
    return $output -join [Environment]::NewLine
}

function Get-TestExtensions {
    $text = Invoke-ExtensionCommand @('list')
    Set-Content -LiteralPath (Join-Path $runPath 'extensions.txt') -Value $text -Encoding utf8
    $extensions = @{}
    foreach ($block in ($text -split '(?:\r?\n){2,}')) {
        if ($block -match '(?m)^name\s*:\s*"([^"]+)"') {
            $name = $Matches[1]
            $extensions[$name] = $block
        }
    }
    return $extensions
}

function Assert-LoadedSource([string] $Source, [string] $Name) {
    $dump = Join-Path $runPath "observed-$Name"
    $arguments = $script:DesignerArgs + @('/DumpConfigToFiles', $dump)
    if ($Name -eq 'tests') { $arguments += @('-Extension', 'DomiaryTests') }
    $code = Invoke-ConfigStep "tests-observe-$Name" $arguments
    if ($code -ne 0) { throw "Не удалось прочитать исходники из базы: $Name ($code)" }
    $expected = @(Get-ChildItem -LiteralPath $Source -Recurse -File |
        Where-Object { $_.Name -notin @('ConfigDumpInfo.xml', 'DumpFilesIndex.txt') })
    $observed = @(Get-ChildItem -LiteralPath $dump -Recurse -File |
        Where-Object { $_.Name -notin @('ConfigDumpInfo.xml', 'DumpFilesIndex.txt') })
    if ($expected.Count -ne $observed.Count) { throw "Состав исходников в базе отличается: $Name. Используй -Prepare." }
    foreach ($file in $expected) {
        $path = Join-Path $dump ([IO.Path]::GetRelativePath($Source, $file.FullName))
        if (-not (Test-Path -LiteralPath $path) -or
            (Get-FileHash -LiteralPath $path).Hash -ne (Get-FileHash -LiteralPath $file.FullName).Hash) {
            throw "В базе другая версия $($file.Name). Используй -Prepare (исходники должны быть канонической выгрузкой 8.5)."
        }
    }
}

try {
    $script:Platform = Resolve-V8 $V8Path
    $bin = Split-Path $script:Platform -Parent
    $client = Join-Path $bin '1cv8c.exe'
    $script:IbCmd = Join-Path $bin 'ibcmd.exe'
    foreach ($path in @($client, $script:IbCmd)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Не найден $path" }
    }
    $lock = Enter-ConfigLock
    $runId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $runPath = Join-Path $script:BuildRoot "reports/tests/$runId"
    New-Item -ItemType Directory -Path $runPath -Force | Out-Null
    $script:LogRoot = Join-Path $runPath 'designer-logs'
    New-Item -ItemType Directory -Path $script:LogRoot -Force | Out-Null
    $summary.platform = (Get-Item -LiteralPath $script:Platform).VersionInfo.ProductVersion
    $summary.yaxunit = '25.12'
    $summary.testExtension = '0.1.0'
    $testSource = Join-Path $script:ProjectRoot 'tests/DomiaryTests'
    Assert-NoLinks $testSource
    Assert-NoLinks (Join-Path $script:ProjectRoot 'src')
    $summary.sources = @(Get-ChildItem -LiteralPath $testSource -Recurse -File | ForEach-Object {
        @{ path = [IO.Path]::GetRelativePath($script:ProjectRoot, $_.FullName); sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash }
    })
    $summary.baseSources = @(Get-ChildItem -LiteralPath (Join-Path $script:ProjectRoot 'src') -Recurse -File |
        Where-Object { $_.Name -notin @('ConfigDumpInfo.xml', 'DumpFilesIndex.txt') } | ForEach-Object {
            @{ path = [IO.Path]::GetRelativePath($script:ProjectRoot, $_.FullName); sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash }
        })
    if ($Prepare) {
        Initialize-ConfigBase
    } elseif (-not (Test-Path -LiteralPath (Join-Path $script:Infobase '1Cv8.1CD'))) {
        throw 'Нет временной базы. Выполни первый запуск с -Prepare.'
    }
    $extensions = Get-TestExtensions
    foreach ($name in $extensions.Keys) {
        if ($name -notin @('YAXUNIT', 'DomiaryTests')) { throw "Неизвестное расширение $name; база не изменена." }
    }
    if ($extensions.ContainsKey('YAXUNIT') -and $extensions.YAXUNIT -notmatch '(?m)^version\s*:\s*"25\.12"') {
        throw 'В базе другая версия YAxUnit; автоматическая замена запрещена.'
    }
    if ($extensions.ContainsKey('YAXUNIT') -and
        $extensions.YAXUNIT -notmatch '(?m)^hash-sum\s*:\s*"lra4BrMlENhV9lrqMu3kkKDdsoI="') {
        throw 'Установлен изменённый YAxUnit; подготовка остановлена до загрузки исходников.'
    }
    if ($Prepare) {
        $vendor = Join-Path $script:BuildRoot 'vendor/YAxUnit-25.12.cfe'
        Assert-NoLinks (Split-Path $vendor -Parent)
        New-Item -ItemType Directory -Path (Split-Path $vendor -Parent) -Force | Out-Null
        if (-not (Test-Path -LiteralPath $vendor)) {
            Invoke-WebRequest 'https://github.com/bia-technologies/yaxunit/releases/download/25.12/YAxUnit-25.12.cfe' -OutFile $vendor
        }
        $digest = (Get-FileHash -LiteralPath $vendor -Algorithm SHA256).Hash
        if ($digest -ne '805a2277c997a3c24be0b0d080696479e91e4a15ed7e27aaf3991a7346522d70') {
            throw 'SHA-256 YAxUnit не совпадает с официальным release asset.'
        }
        $summary.yaxunitAssetSha256 = $digest
        Import-Config (Resolve-ConfigSource 'src')
        if (-not $extensions.ContainsKey('YAXUNIT')) {
            $code = Invoke-ConfigStep 'yaxunit-load' ($script:DesignerArgs + @('/LoadCfg', $vendor, '-Extension', 'YAXUNIT', '/UpdateDBCfg'))
            if ($code -ne 0) { throw "Загрузка YAxUnit: $code" }
        }
        $code = Invoke-ConfigStep 'tests-load' ($script:DesignerArgs + @('/LoadConfigFromFiles', $testSource, '-Extension', 'DomiaryTests', '/UpdateDBCfg'))
        if ($code -ne 0) { throw "Загрузка тестов: $code" }
        # Только два тестовых расширения в изолированной .build/ib, по инструкции YAxUnit.
        foreach ($name in @('YAXUNIT', 'DomiaryTests')) {
            Invoke-ExtensionCommand @('update', "--name=$name", '--safe-mode=no', '--unsafe-action-protection=no') | Write-Host
        }
        $extensions = Get-TestExtensions
    }
    foreach ($name in @('YAXUNIT', 'DomiaryTests')) {
        if (-not $extensions.ContainsKey($name)) { throw "Не установлено $name. Используй -Prepare." }
        foreach ($property in @('active\s*:\s*yes', 'safe-mode\s*:\s*no', 'unsafe-action-protection\s*:\s*no')) {
            if ($extensions[$name] -notmatch "(?m)^$property\s*$") { throw "Неверные свойства $name. Используй -Prepare." }
        }
    }
    # Внутренний hash-sum получен при загрузке проверенного официального CFE 25.12.
    if ($extensions.YAXUNIT -notmatch '(?m)^hash-sum\s*:\s*"lra4BrMlENhV9lrqMu3kkKDdsoI="') {
        throw 'Содержимое установленного YAxUnit отличается от официального CFE 25.12; замена не выполняется.'
    }
    $script:DesignerArgs = @('DESIGNER', '/F', $script:Infobase, '/DisableStartupDialogs', '/DisableStartupMessages')
    Assert-LoadedSource (Join-Path $script:ProjectRoot 'src') 'base'
    Assert-LoadedSource $testSource 'tests'
    $summary.loadedSourcesMatch = $true
    $tests = @('Тесты_ПилотКлиентСервер.ПроверкаСложения')
    $recurrenceTests = @(
        'СозданиеПравил', 'НекорректныеПравила', 'ПравилоИзПеречисления', 'НекорректноеПеречисление',
        'СледующаяДатаДниИНедели', 'СледующаяДатаМесяцы', 'СледующаяДатаГоды',
        'БлижайшаяДоОтсчетаИНаОтсчете', 'БлижайшаяДниИНедели', 'БлижайшаяМесяцыБезДрейфа',
        'БлижайшаяГодыБезДрейфа', 'БлижайшаяДалекоВБудущем',
        'ПредставленияЕдиничныхПравил', 'СклоненияКоличества', 'ОшибкиАргументов'
    )
    $tests += @($recurrenceTests | ForEach-Object { "Тесты_ПовторяемостьКлиентСервер.$_" })
    if ($IncludeNegativeControl) { $tests += 'Тесты_ПилотКлиентСервер.ЗаведомоПадающий' }
    $contexts = @('КлиентУправляемоеПриложение', 'Сервер')
    $summary.selection = $tests
    $summary.contexts = $contexts
    $summary.expectedTests = $tests.Count * $contexts.Count
    $report = Join-Path $runPath 'junit.xml'
    $exitFile = Join-Path $runPath 'exit-code.txt'
    $config = Join-Path $runPath 'config.json'
    @{
        filter = @{ extensions = @('DomiaryTests'); tests = $tests; contexts = $contexts }
        reportPath = $report; reportFormat = 'jUnit'; exitCode = $exitFile
        closeAfterTests = $true; showReport = $false
        logging = @{ file = (Join-Path $runPath 'yaxunit.log'); level = 'info' }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $config -Encoding utf8
    $arguments = @('ENTERPRISE', '/F', $script:Infobase, '/DisableStartupDialogs', '/DisableStartupMessages',
        '/C', "RunUnitTests=$config", '/Out', (Join-Path $runPath 'platform.log'))
    $psi = [Diagnostics.ProcessStartInfo]::new($client)
    $psi.UseShellExecute = $false
    foreach ($argument in $arguments) { $psi.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($psi)
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        # Завершаем только собственный клиент, не другие сеансы 1С.
        $process.Kill()
        $process.WaitForExit()
        throw "Тайм-аут $TimeoutSeconds с; собственный клиент завершён. Повторно загрузка не запускается."
    }
    $summary.platformExitCode = $process.ExitCode
    if (-not (Test-Path -LiteralPath $exitFile) -or -not (Test-Path -LiteralPath $report)) {
        throw 'Нет свежего exitCode или JUnit. См. platform.log и yaxunit.log.'
    }
    $exitText = (Get-Content -LiteralPath $exitFile -Raw -Encoding utf8).Trim()
    if ($exitText -notin @('0', '1')) { throw "Некорректный exitCode: $exitText" }
    $summary.yaxunitExitCode = [int] $exitText
    $document = [xml]::new()
    $document.XmlResolver = $null
    $document.Load($report)
    $cases = @($document.SelectNodes('//testcase'))
    $summary.tests = $cases.Count
    $summary.failures = $document.SelectNodes('//failure').Count
    $summary.errors = $document.SelectNodes('//error').Count
    $summary.skipped = $document.SelectNodes('//skipped').Count
    if ($cases.Count -ne $summary.expectedTests) { throw "Ожидалось $($summary.expectedTests) выполнений, получено $($cases.Count)." }
    foreach ($test in $tests) {
        foreach ($context in $contexts) {
            $matches = @($cases | Where-Object { $_.GetAttribute('classname') -eq $test -and $_.GetAttribute('context') -eq $context })
            if ($matches.Count -ne 1) { throw "Неверный состав JUnit: $test [$context]" }
        }
    }
    # Ошибки чтения набора могут быть отражены в атрибутах suite, а не только testcase.
    foreach ($suite in $document.SelectNodes('//testsuite')) {
        foreach ($attribute in @('errors', 'skipped', 'failures')) {
            if ($suite.HasAttribute($attribute) -and [int] $suite.GetAttribute($attribute) -gt 0) {
                if ($attribute -eq 'errors') { $summary.errors = [Math]::Max($summary.errors, [int] $suite.GetAttribute($attribute)) }
                if ($attribute -eq 'skipped') { $summary.skipped = [Math]::Max($summary.skipped, [int] $suite.GetAttribute($attribute)) }
                if ($attribute -eq 'failures') { $summary.failures = [Math]::Max($summary.failures, [int] $suite.GetAttribute($attribute)) }
            }
        }
    }
    $result = if ($process.ExitCode -eq 0 -and $summary.yaxunitExitCode -eq 0 -and
        $summary.failures -eq 0 -and $summary.errors -eq 0 -and $summary.skipped -eq 0) { 0 } else { 1 }
    $summary.status = if ($result -eq 0) { 'PASS' } else { 'FAIL' }
} catch {
    $summary.error = $_.Exception.Message
    Write-Host "Ошибка запуска тестов: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($runPath) {
        $summary.finishedAtUtc = [DateTime]::UtcNow.ToString('o')
        $summary.scriptExitCode = $result
        $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runPath 'result.json') -Encoding utf8
        Write-Host "JUnit: $(Join-Path $runPath 'junit.xml')"
        Write-Host "Результат: $(Join-Path $runPath 'result.json')"
    }
    if ($lock) { $lock.Dispose() }
}
Write-Host "Итог тестов: $result"
exit $result
