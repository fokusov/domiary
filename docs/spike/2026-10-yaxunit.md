# YAxUnit на Domiary 8.5 мобильного назначения

**Дата:** 2026-10-02 · **Task: T-012**

## Вывод

**Основной вариант ADR-007 работает.** Официальный CFE YAxUnit 25.12 и
отдельное тестовое расширение подключаются к конфигурации Domiary с назначением
`MobilePlatformApplication` и совместимостью `Version8_5_1`. Пакетный запуск
в тонком клиенте создаёт JUnit и завершается без взаимодействия с интерфейсом.
Запасной вариант не потребовался. Статус самого ADR этим spike не меняется.

Проверено именно на Windows, в файловой `.build/ib` текущего worktree;
не на мобильном устройстве и не в серверной СУБД.

## Версии и происхождение

| Компонент | Проверенное значение |
|---|---|
| 1С, тонкий клиент, `ibcmd` | **8.5.1.1529**, x86_64 |
| PowerShell | **7.6.6** |
| Domiary | **0.0.1**, `MobilePlatformApplication`, `Version8_5_1` |
| XML основной конфигурации и тестов | **2.21**, иерархическая выгрузка Конфигуратора |
| Тестовое расширение | `DomiaryTests` **0.1.0**, `Customization` |
| YAxUnit | **25.12**, установленное имя `YAXUNIT`, назначение `AddOn` |
| Лицензия YAxUnit | **Apache License 2.0** |

Последний stable release из официального API `releases/latest` на момент
проверки — [25.12](https://github.com/bia-technologies/yaxunit/releases/tag/25.12).
Скачан только
[официальный release asset](https://github.com/bia-technologies/yaxunit/releases/download/25.12/YAxUnit-25.12.cfe).
SHA-256 совпал с `digest` GitHub:
`805a2277c997a3c24be0b0d080696479e91e4a15ed7e27aaf3991a7346522d70`.
Лицензия проверена по [LICENSE тега 25.12](https://github.com/bia-technologies/yaxunit/blob/25.12/LICENSE).
Сам CFE не включён в коммит; кэш — `.build/vendor/`.

## Что пришлось учесть

1. Шаблон тестового расширения с `PlatformApplication` не подходит: загрузка
   вернула 101 с сообщением о несовпадении контролируемого `НазначениеИспользования`.
   **Только в тестовом расширении** установлено `MobilePlatformApplication`.
   Официальный YAxUnit не модифицировался; его CFE загрузился без такой правки.
2. После загрузки оба расширения имели `safe-mode: yes` и
   `unsafe-action-protection: yes` (проверено read-only `ibcmd extension list`).
   Первый запуск не смог прочитать JSON: «Расширение выполняется в безопасном
   режиме. Чтение конфигурационного файла недоступно»; JUnit отсутствовал.
   Согласно официальной инструкции установки, оба признака сняты **только
   для YAXUNIT и DomiaryTests во временной базе**. После настройки запуск пакетный.
3. Ошибка первоначальной тестовой заготовки (`СТегом` не существует в API
   этой версии) дала ошибки чтения набора. Исправлена регистрация; отрицательный
   контроль исключается из обычного прогона через документированный `filter.tests`.
   Это ошибка заготовки, не несовместимость Domiary/YAxUnit.
4. **Код процесса `1cv8c.exe` — 0 даже при падающих assertion.** YAxUnit пишет
   свой результат в файл `exitCode`. Runner читает его и JUnit, проверяет точные
   имена/контексты/количество выполнений, ошибки и пропуски, а затем возвращает 0/1.
5. Изолированный `/CheckModules -Extension DomiaryTests` не видит модули
   соседнего YAxUnit и сообщает неопределённые `ЮТест`/`ЮТТесты`. Проверка
   **совместного состава** `/CheckConfig -AllExtensions -ExtendedModulesCheck`
   в тонком клиенте и на сервере вернула 0: «Ошибок не обнаружено».

## Воспроизведение

```powershell
# Основную конфигурацию можно предварительно проверить существующим инструментом:
pwsh -NoProfile -File tools/check-config.ps1

# Установить/обновить тестовое окружение и выполнить зелёный контроль:
pwsh -NoProfile -File tools/run-tests.ps1 -Prepare

# Повторить без загрузки конфигурации и изменения свойств расширений:
pwsh -NoProfile -File tools/run-tests.ps1

# Выполнить также намеренно падающий контроль, ожидать код 1:
pwsh -NoProfile -File tools/run-tests.ps1 -IncludeNegativeControl
```

`-Prepare` не пересоздаёт/не удаляет существующую базу. Свежая установка также
проверена: первоначальная база сохранена в `.build/ib-pilot-preserved`, после
чего runner создал новую `.build/ib`, загрузил основной `src/`, официальный
YAxUnit и тестовое расширение и успешно выполнил тесты.

Использованные нативные команды (переменные указывают только на текущий worktree):

```powershell
$bin = 'C:\Program Files\1cv8\8.5.1.1529\bin'
$root = (Get-Location).Path
$ib = "$root\.build\ib"
$cfe = "$root\.build\vendor\YAxUnit-25.12.cfe"

# Загрузка официального CFE и собственных тестов:
& "$bin\1cv8.exe" DESIGNER /F $ib /DisableStartupDialogs /DisableStartupMessages `
    /LoadCfg $cfe -Extension YAXUNIT /UpdateDBCfg
& "$bin\1cv8.exe" DESIGNER /F $ib /DisableStartupDialogs /DisableStartupMessages `
    /LoadConfigFromFiles "$root\tests\DomiaryTests" -Extension DomiaryTests /UpdateDBCfg

# Read-only инвентаризация; затем явно меняются только два тестовых расширения:
& "$bin\ibcmd.exe" extension list "--db-path=$ib" "--data=$root\.build\ibcmd"
foreach ($name in @('YAXUNIT', 'DomiaryTests')) {
    & "$bin\ibcmd.exe" extension update "--db-path=$ib" "--data=$root\.build\ibcmd" `
        "--name=$name" --safe-mode=no --unsafe-action-protection=no
}

# $config — абсолютный путь к сохранённому JSON конкретного прогона:
& "$bin\1cv8c.exe" ENTERPRISE /F $ib /DisableStartupDialogs /DisableStartupMessages `
    /C "RunUnitTests=$config" /Out "$root\.build\client.log"

# Статическая проверка обоих расширений вместе:
& "$bin\1cv8.exe" DESIGNER /F $ib /DisableStartupDialogs /DisableStartupMessages `
    /CheckConfig -ThinClient -Server -ExtendedModulesCheck -AllExtensions `
    /Out "$root\.build\all-extensions.log"
```

Нативные команды для пояснения контракта; штатный runner обеспечивает ожидание
процесса, lock, уникальные пути логов и интерпретацию результата. Пример JSON
для зелёного прогона (пути здесь заменены условными):

```json
{
  "filter": {
    "extensions": ["DomiaryTests"],
    "tests": ["Тесты_ПилотКлиентСервер.ПроверкаСложения"],
    "contexts": ["КлиентУправляемоеПриложение", "Сервер"]
  },
  "reportFormat": "jUnit",
  "reportPath": "C:\\path\\to\\junit.xml",
  "exitCode": "C:\\path\\to\\exit-code.txt",
  "closeAfterTests": true,
  "showReport": false
}
```

Схема параметров сверена с
[документацией релиза](https://github.com/bia-technologies/yaxunit/blob/25.12/documentation/docs/getting-started/run/configuration.md).

## Наблюдения и evidence

| Проверка | Фактический результат |
|---|---|
| Основной `check-config.ps1`, пять контекстов | 0; `/CheckModules` и `/CheckConfig`: 0 |
| Зелёный контроль | 2 выполнения, 0 failures/errors/skipped; процесс 0, YAxUnit 0, runner **0** |
| Оба контроля | 4 выполнения, **2 assertion failures**, 0 errors/skipped; процесс 0, YAxUnit 1, runner **1** |
| Круговая выгрузка тестового расширения | 2.21; файлы `tests/DomiaryTests` канонизированы только из временной базы |
| Сверка загруженных исходников перед запуском | SHA-256 и состав основной конфигурации и тестов совпадают с файлами проекта |
| Структурный `cfe-validate` с `ConfigPath=src` | OK, 13 проверок |
| Совместная нативная проверка расширений | 0, ошибок нет |
| Отсутствующая платформа / занятый `config.lock` | runner 1, клиент не запущен |
| Расхождение исходников тестов и базы | runner 1, `BLOCKED`, тестовый клиент не запущен; загрузка не повторялась |

Последние контрольные прогоны:

- `20261002T150705714Z-add2fd2e`: зелёный;
- `20261002T150727123Z-6dce1189`: отрицательный.

Оригинальные JUnit и JSON результата скопированы в
[`evidence/2026-10-yaxunit/`](evidence/2026-10-yaxunit/).
Они содержат версии, точную выборку, клиентский/серверный контексты, времена,
код процесса, код YAxUnit, итог runner и SHA-256 файлов. Ожидаемое падение
отрицательного контроля остаётся `FAIL` в raw result — его не переименовывали в PASS.
Полные логи/JSON запуска/контрольные выгрузки сохранены в игнорируемой `.build/`;
неудачные первоначальные попытки `pilot-1`/`pilot-2` также сохранены.

## Ограничения

- `unica.runtime.execute(operation: test, testRunner: yaxunit)` **не проверен**:
  инструмента нет в доступном каталоге MCP этой сессии, CLI `unica` также
  не обнаружен. Настройка дополнительного MCP не выполнялась. Это не блокирует
  подтверждённый нативный путь ADR-007, но ничего не доказывает о запуске через unica.
- Runner пока выбирает именно пилотные тесты, не все будущие модули автоматически.
- Это проверка движка и пакетного исполнения, не тесты реальной доменной логики,
  интеграционных сценариев, UI, APK или мобильных API. Мобильный сборщик не запускался.
- `src/`, `base/`, `pub/`, `AGENTS.md` и ADR не изменены.

Принять или отклонить ADR-007 должен Игорь; техническое условие для основного
варианта выполнено на указанной платформе.
