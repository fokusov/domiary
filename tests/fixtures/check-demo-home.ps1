# Проверка демо-фикстуры demo-home.json.
# Проверяет валидность JSON, ссылки по id, состав набора и связные инварианты
# (дерево мест хранения, разницу показаний, расчёт следующего срока обслуживания).
param(
    [string]$Path = (Join-Path $PSScriptRoot 'demo-home.json')
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

function Add-Error {
    param([string]$Message)
    $script:errors.Add($Message)
}

function Test-IsoDate {
    param([string]$Value)
    if ($Value -notmatch '^\d{4}-\d{2}-\d{2}$') { return $false }
    try {
        $null = [datetime]::ParseExact($Value, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        return $true
    }
    catch { return $false }
}

function ConvertTo-Date {
    param([string]$Value)
    [datetime]::ParseExact($Value, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
}

function Add-Interval {
    param([datetime]$Date, [string]$Unit, [int]$Count)
    switch ($Unit) {
        'day'   { $Date.AddDays($Count) }
        'week'  { $Date.AddDays(7 * $Count) }
        'month' { $Date.AddMonths($Count) }
        'year'  { $Date.AddYears($Count) }
    }
}

function Test-Recurrence {
    param($Recurrence)
    if ($null -eq $Recurrence) { return $false }
    return ($Recurrence.unit -in @('day', 'week', 'month', 'year')) -and
        ($Recurrence.count -is [int] -or $Recurrence.count -is [long]) -and
        ($Recurrence.count -ge 1)
}

function Test-Number {
    param($Value)
    if ($Value -isnot [double] -and $Value -isnot [int] -and $Value -isnot [long]) { return $false }
    return [double]::IsFinite([double]$Value)
}

function Test-PositiveNumber {
    param($Value)
    return (Test-Number $Value) -and ($Value -gt 0)
}

# --- Разбор файла -----------------------------------------------------------

if (-not (Test-Path $Path)) {
    Write-Output "FATAL: файл не найден: $Path"
    exit 1
}

try {
    $data = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
}
catch {
    Write-Output "FATAL: JSON не разбирается: $($_.Exception.Message)"
    exit 1
}

Write-Output "Файл: $Path"
Write-Output "formatVersion = $($data['formatVersion']), description задано: $([bool]$data['description'])"
if ($data['formatVersion'] -ne 1) { Add-Error 'formatVersion должен быть равен 1' }
if ([string]::IsNullOrWhiteSpace($data['description'])) { Add-Error 'description не задано' }

# --- Коллекции и уникальность id --------------------------------------------

$sections = 'properties', 'locations', 'assets', 'maintenanceRules', 'meters',
    'obligations', 'savingsGoals', 'debts', 'plannedPurchases'

foreach ($section in $sections) {
    if ($data[$section] -isnot [array]) { Add-Error "секция '$section' отсутствует или не является списком" }
}

$allIds = @{}
foreach ($section in $sections) {
    foreach ($item in @($data[$section])) {
        $id = $item['id']
        if ([string]::IsNullOrWhiteSpace($id)) { Add-Error "$section`: элемент без id"; continue }
        if ($allIds.ContainsKey($id)) { Add-Error "id '$id' встречается более одного раза ($($allIds[$id]) и $section)" }
        else { $allIds[$id] = $section }
    }
}

$properties = $data['properties']
$locations  = $data['locations']
$assets     = $data['assets']
$rules      = $data['maintenanceRules']
$meters     = $data['meters']

$propertyIds = @($properties | ForEach-Object { $_['id'] })
$locationIds = @($locations | ForEach-Object { $_['id'] })
$assetIds    = @($assets | ForEach-Object { $_['id'] })
$goalIds     = @($data['savingsGoals'] | ForEach-Object { $_['id'] })

# --- Объекты недвижимости ---------------------------------------------------

foreach ($p in $properties) {
    if ([string]::IsNullOrWhiteSpace($p['name'])) { Add-Error "property '$($p['id'])': пустое name" }
}

# --- Места хранения: ссылки, дерево, циклы ----------------------------------

$locationById = @{}
foreach ($l in $locations) { $locationById[$l['id']] = $l }

foreach ($l in $locations) {
    if ($propertyIds -notcontains $l['property']) {
        Add-Error "location '$($l['id'])': property '$($l['property'])' не найден"
    }
    if ($null -ne $l['parent']) {
        if ($locationIds -notcontains $l['parent']) {
            Add-Error "location '$($l['id'])': parent '$($l['parent'])' не найден"
        }
        else {
            if ($locationById[$l['parent']]['property'] -ne $l['property']) {
                Add-Error "location '$($l['id'])': parent принадлежит другому объекту недвижимости"
            }
            # Проверка на цикл: подъём по цепочке родителей не должен вернуться в себя.
            $seen = @{}
            $seen[$l['id']] = $true
            $cur = $l['parent']
            while ($null -ne $cur) {
                if ($seen.ContainsKey($cur)) { Add-Error "location '$($l['id'])': цикл в дереве мест хранения"; break }
                $seen[$cur] = $true
                $cur = $locationById[$cur]['parent']
            }
        }
    }
}

# --- Вещи ---------------------------------------------------------------------

$assetStatuses = 'Используется', 'Хранится', 'Требует ремонта', 'Передано', 'Списано', 'Продано'
$today = (Get-Date).Date
$windowStart = $today.AddYears(-6)

foreach ($a in $assets) {
    $id = $a['id']
    if ($locationIds -notcontains $a['location']) {
        Add-Error "asset '$id': location '$($a['location'])' не найден"
    }
    else {
        if ($locationById[$a['location']]['property'] -ne $a['property']) {
            Add-Error "asset '$id': property не совпадает с property места хранения"
        }
    }
    if ($propertyIds -notcontains $a['property']) {
        Add-Error "asset '$id': property '$($a['property'])' не найден"
    }
    $purchaseDate = $null
    if (-not (Test-IsoDate $a['purchaseDate'])) {
        Add-Error "asset '$id': purchaseDate '$($a['purchaseDate'])' не в формате ISO 8601"
    }
    else {
        $purchaseDate = ConvertTo-Date $a['purchaseDate']
        if ($purchaseDate -lt $windowStart -or $purchaseDate -gt $today) {
            Add-Error "asset '$id': purchaseDate вне диапазона ($($windowStart.ToString('yyyy-MM-dd')) .. $($today.ToString('yyyy-MM-dd')))"
        }
    }
    if (-not (Test-Number $a['purchasePrice']) -or $a['purchasePrice'] -lt 0) {
        Add-Error "asset '$id': purchasePrice должен быть неотрицательным числом"
    }
    if ($assetStatuses -notcontains $a['status']) {
        Add-Error "asset '$id': неизвестный статус '$($a['status'])'"
    }
    $w = $a['warranty']
    if ($null -ne $w) {
        if (-not (Test-IsoDate $w['startDate']) -or -not (Test-IsoDate $w['endDate'])) {
            Add-Error "asset '$id': даты гарантии не в формате ISO 8601"
        }
        elseif ($null -ne $purchaseDate) {
            $ws = ConvertTo-Date $w['startDate']
            $we = ConvertTo-Date $w['endDate']
            $pd = $purchaseDate
            if ($ws -gt $we) { Add-Error "asset '$id': гарантия заканчивается раньше, чем начинается" }
            if ($ws -lt $pd) { Add-Error "asset '$id': гарантия начинается раньше покупки" }
        }
    }
}

# --- Правила обслуживания -----------------------------------------------------

foreach ($r in $rules) {
    $id = $r['id']
    if ($assetIds -notcontains $r['asset']) {
        Add-Error "maintenanceRule '$id': asset '$($r['asset'])' не найден"
    }
    if (-not (Test-Recurrence $r['recurrence'])) {
        Add-Error "maintenanceRule '$id': некорректная периодичность"
    }
    elseif ((Test-IsoDate $r['lastPerformedAt']) -and (Test-IsoDate $r['nextDueAt'])) {
        $expected = Add-Interval (ConvertTo-Date $r['lastPerformedAt']) $r['recurrence']['unit'] $r['recurrence']['count']
        if ((ConvertTo-Date $r['nextDueAt']) -ne $expected) {
            Add-Error "maintenanceRule '$id': nextDueAt не равен lastPerformedAt + периодичность"
        }
    }
    else {
        Add-Error "maintenanceRule '$id': даты не в формате ISO 8601"
    }
}

# --- Счётчики -----------------------------------------------------------------

foreach ($m in $meters) {
    $id = $m['id']
    if ($propertyIds -notcontains $m['property']) {
        Add-Error "meter '$id': property '$($m['property'])' не найден"
    }
    if (-not (Test-Recurrence $m['readingRecurrence'])) {
        Add-Error "meter '$id': некорректная периодичность снятия показаний"
    }
    if (-not (Test-IsoDate $m['nextReadingDate'])) {
        Add-Error "meter '$id': nextReadingDate не в формате ISO 8601"
    }
    $readings = @($m['readings'])
    if ($readings.Count -ne 12) {
        Add-Error "meter '$id': ожидается 12 показаний, найдено $($readings.Count)"
    }
    $prevDate = $null
    $prevValue = $null
    foreach ($r in $readings) {
        if (-not (Test-IsoDate $r['date'])) {
            Add-Error "meter '$id': дата показания '$($r['date'])' не в формате ISO 8601"; continue
        }
        if (-not (Test-Number $r['value'])) {
            Add-Error "meter '$id': показание за $($r['date']) должно быть числом"; continue
        }
        if ($null -ne $r['consumption'] -and -not (Test-Number $r['consumption'])) {
            Add-Error "meter '$id': consumption за $($r['date']) должен быть числом или null"; continue
        }
        $d = ConvertTo-Date $r['date']
        if ($null -ne $prevDate -and $d -le $prevDate) {
            Add-Error "meter '$id': даты показаний не возрастают ($($r['date']))"
        }
        if ($null -ne $prevValue -and $r['value'] -le $prevValue) {
            Add-Error "meter '$id': показание за $($r['date']) не больше предыдущего"
        }
        if ($null -eq $prevValue) {
            if ($null -ne $r['consumption']) {
                Add-Error "meter '$id': у первого показания consumption должен быть null"
            }
        }
        else {
            $diff = $r['value'] - $prevValue
            if ($r['consumption'] -ne $diff) {
                Add-Error "meter '$id': consumption за $($r['date']) равен $($r['consumption']), разница показаний $diff"
            }
        }
        $prevDate = $d
        $prevValue = $r['value']
    }
}

# --- Обязательства --------------------------------------------------------------

foreach ($o in $data['obligations']) {
    $id = $o['id']
    if (-not (Test-Recurrence $o['recurrence'])) { Add-Error "obligation '$id': некорректная периодичность" }
    if (-not (Test-PositiveNumber $o['amount'])) { Add-Error "obligation '$id': amount должен быть положительным числом" }
    if ($null -ne $o['property'] -and $propertyIds -notcontains $o['property']) {
        Add-Error "obligation '$id': property '$($o['property'])' не найден"
    }
    if (-not (Test-IsoDate $o['nextDueDate'])) { Add-Error "obligation '$id': nextDueDate не в формате ISO 8601" }
}

# --- Цели накоплений --------------------------------------------------------------

foreach ($g in $data['savingsGoals']) {
    $id = $g['id']
    if (-not (Test-PositiveNumber $g['targetAmount'])) { Add-Error "savingsGoal '$id': targetAmount должен быть положительным числом" }
    if (-not (Test-IsoDate $g['targetDate'])) { Add-Error "savingsGoal '$id': targetDate не в формате ISO 8601" }
    $pc = $g['plannedContribution']
    if ($null -eq $pc -or -not (Test-PositiveNumber $pc['amount']) -or -not (Test-Recurrence $pc['recurrence'])) {
        Add-Error "savingsGoal '$id': некорректное плановое пополнение"
    }
    $prevDate = $null
    foreach ($c in @($g['contributions'])) {
        if (-not (Test-IsoDate $c['date'])) { Add-Error "savingsGoal '$id': дата пополнения не в формате ISO 8601"; continue }
        $d = ConvertTo-Date $c['date']
        if ($null -ne $prevDate -and $d -le $prevDate) {
            Add-Error "savingsGoal '$id': даты пополнений не возрастают ($($c['date']))"
        }
        if (-not (Test-PositiveNumber $c['amount'])) { Add-Error "savingsGoal '$id': сумма пополнения должна быть положительным числом" }
        $prevDate = $d
    }
}

# --- Долги -------------------------------------------------------------------------

foreach ($dbt in $data['debts']) {
    $id = $dbt['id']
    if (@('Мне должны', 'Я должен') -notcontains $dbt['direction']) {
        Add-Error "debt '$id': неизвестное направление '$($dbt['direction'])'"
    }
    if (-not (Test-IsoDate $dbt['date'])) { Add-Error "debt '$id': date не в формате ISO 8601" }
    if (-not (Test-IsoDate $dbt['dueDate'])) { Add-Error "debt '$id': dueDate не в формате ISO 8601" }
    if (-not (Test-PositiveNumber $dbt['initialAmount'])) { Add-Error "debt '$id': initialAmount должен быть положительным числом" }
    $prevDate = $null
    $repaid = 0
    foreach ($r in @($dbt['repayments'])) {
        if (-not (Test-IsoDate $r['date'])) { Add-Error "debt '$id': дата возврата не в формате ISO 8601"; continue }
        if (-not (Test-PositiveNumber $r['amount'])) { Add-Error "debt '$id': сумма возврата должна быть положительным числом"; continue }
        $d = ConvertTo-Date $r['date']
        if ($null -ne $prevDate -and $d -le $prevDate) {
            Add-Error "debt '$id': даты возвратов не возрастают ($($r['date']))"
        }
        $repaid += $r['amount']
        $prevDate = $d
    }
    if ((Test-Number $dbt['initialAmount']) -and $repaid -gt $dbt['initialAmount']) {
        Add-Error "debt '$id': сумма возвратов ($repaid) больше initialAmount ($($dbt['initialAmount']))"
    }
}

# --- Планируемые покупки --------------------------------------------------------------

foreach ($pp in $data['plannedPurchases']) {
    $id = $pp['id']
    if (@('Высокий', 'Средний', 'Низкий') -notcontains $pp['priority']) {
        Add-Error "plannedPurchase '$id': неизвестный приоритет '$($pp['priority'])'"
    }
    if (-not (Test-PositiveNumber $pp['estimatedCost'])) { Add-Error "plannedPurchase '$id': estimatedCost должен быть положительным числом" }
    if (-not (Test-IsoDate $pp['targetDate'])) { Add-Error "plannedPurchase '$id': targetDate не в формате ISO 8601" }
    if ($null -ne $pp['savingsGoal'] -and $goalIds -notcontains $pp['savingsGoal']) {
        Add-Error "plannedPurchase '$id': savingsGoal '$($pp['savingsGoal'])' не найден"
    }
}

# --- Состав набора ---------------------------------------------------------------------

$expected = [ordered]@{
    'properties'        = 2
    'locations'         = '12..15'
    'assets'            = '40..50'
    'maintenanceRules'  = 10
    'meters'            = 3
    'obligations'       = 6
    'savingsGoals'      = 2
    'debts'             = 2
    'plannedPurchases'  = 3
}

foreach ($section in $sections) {
    $count = @($data[$section]).Count
    $exp = $expected[$section]
    $ok = if ($exp -is [string]) {
        $min, $max = ($exp -split '\.\.' | ForEach-Object { [int]$_ })
        ($count -ge $min) -and ($count -le $max)
    }
    else { $count -eq $exp }
    if (-not $ok) { Add-Error "секция '$section': ожидается $exp, найдено $count" }
}

# --- Итоги --------------------------------------------------------------------------------

Write-Output ''
Write-Output "Состав: properties=$(@($properties).Count), locations=$(@($locations).Count), assets=$(@($assets).Count), maintenanceRules=$(@($rules).Count), meters=$(@($meters).Count), obligations=$(@($data['obligations']).Count), savingsGoals=$(@($data['savingsGoals']).Count), debts=$(@($data['debts']).Count), plannedPurchases=$(@($data['plannedPurchases']).Count)"

$readingsTotal = ($meters | ForEach-Object { @($_['readings']).Count } | Measure-Object -Sum).Sum
# Суммируем только корректные суммы: испорченная строка не должна ломать отчёт.
$contribTotal = 0
foreach ($g in $data['savingsGoals']) {
    foreach ($c in @($g['contributions'])) {
        if (Test-Number $c['amount']) { $contribTotal += $c['amount'] }
    }
}
Write-Output "Показаний: $readingsTotal; суммарно пополнено: $contribTotal руб."

Write-Output ''
if ($errors.Count -gt 0) {
    Write-Output "ОШИБКИ ($($errors.Count)):"
    $errors | ForEach-Object { Write-Output "  - $_" }
    Write-Output ''
    Write-Output 'FAIL'
    exit 1
}

Write-Output 'Все проверки пройдены: JSON валиден, ссылки по id разрешаются, инварианты соблюдены.'
Write-Output 'PASS'
exit 0
