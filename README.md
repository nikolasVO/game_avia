# Game Avia

Нативный прототип Godot **4.7.2 stable**: отдельный авторитетный ENet/DTLS-сервер, три процедурных самолёта, остров с двумя полосами, свободный полёт, гонка и аркадный PvP. Есть touch controls, EN/RU, выбор самолёта, приватные комнаты и настройки. Рабочий подзаголовок Tidal Wings пока не прошёл проверку названия для публикации.

**Это проверяемый прототип, версия 0.1 ещё НЕ ПРИНЯТА.** После исправления реального ограничения ENet проверены16 клиентов минимум1850 секунд при~30 accepted input/s каждый: p95 тела симуляции3.352ms, RSS92MiB. Измерение относится к серверу9412be7; authority-файлы текущегоc1922c7 идентичны и его бинарник отдельно проверен. Это loopback и управляющие боты, не телефоны/люди.

Текущие исходники, развёрнутый игровой сервер и [новый prerelease APK/AAB/macOS/server](https://github.com/nikolasVO/game_avia/releases/tag/game-avia-prototype-20261117-r2): `c1922c74a29112818ce9ee523a9cdc81eb211180`. [Хеши](docs/evidence/artifact-index-r2.json), [handoff r2](docs/handoffs/game-prototype-r2-20261117.md), [STATUS](STATUS.md), [backlog](docs/backlog.md). Первый3417828 release/FAIL evidence сохранён отдельно. Main содержит интегрированные проверенные milestones.

Для запуска из checkout с Git LFS:

```sh
git lfs pull
# GODOT — путь к стандартной версии4.7.2, не .NET/beta.
"$GODOT" --headless --path game/avia --editor --import --quit
AVIA_DTLS_KEY=/protected/server.key "$GODOT" --headless --path game/avia -- --server
"$GODOT" --path game/avia -- --connect=127.0.0.1
"$GODOT" --path game/avia -- --connect=127.0.0.1
```

Ключ сервера должен соответствовать публичному `game/avia/net/server.crt`. Приватный ключ владельца уже хранится вне Git на Mac/Thunder; тестеры получают APK, а не ключ. Для другого независимого dev-сервера нужно создать свою пару сертификат/ключ и собрать клиент с соответствующим публичным сертификатом. Не отключайте проверку сертификата для обхода ошибки.

С телефона укажите адрес доступного сервера в меню; для Android Emulator сервер Mac доступен как `10.0.2.2`. Установка APK не создаёт внешний UDP mapping. Приватная комната: одинаковые режим и код из4–12 заглавных букв/цифр. Публичные комнаты подбираются автоматически, максимум16 на комнату.

Управление: слева тангаж/крен, справа сохраняемая тяга и тормоз (огонь в PvP); Recover восстанавливает самолёт. На desktop Shift/Ctrl — тяга, W/S — тангаж, A/D — крен, Q/E — руль, Space — тормоз, R — восстановление, F — огонь только в PvP. В гонке проходите золотые кольца по порядку; время и результат считает сервер. Все три самолёта бесплатны.

Проверки и ручные сборки:

```sh
"$GODOT" --headless --path game/avia --script res://tests/flight_check.gd
AVIA_DTLS_KEY=/protected/server.key python3 tools/game_check.py --godot "$GODOT" --render --seconds 20 --out /tmp/avia-two-clients
AVIA_DTLS_KEY=/protected/server.key python3 tools/protocol_check.py --godot "$GODOT" --out /tmp/avia-protocol
python3 tools/build_game.py --godot "$GODOT" --target apk
python3 tools/build_game.py --godot "$GODOT" --target aab
```

Android SDK/JDK/debug key задаются во внешних Godot editor settings. APK подписан debug-ключом, release AAB собран без release-подписи; это не готовая магазинная публикация. iOS заблокирован отсутствием полного Xcode/SDK/Team ID/подписи; Xcode-проект и IPA не заявлены. Физические Android/iPhone, тепловые20–30-минутные замеры и16KB runtime пока NOT VERIFIED.

APK9412be7 прошёл300s, APKc1922c7 —120s реального эмулятора с touch-взлётом, вторым участником и Home/возвратом/rejoin. Есть нормальный18.74s screenrecord без ускорения. Это **не физический телефон и не принятая производительность**: уc1922c7 p50 кадра69ms/p95152ms в SwiftShader, цель30FPS FAIL. Прямое подключение Mac→Thunder UDP24567 после нового deploy снова FAIL:0 snapshots; для внешнего тестирования нужен доступный UDP mapping/путь. [Точные результаты](docs/evidence/android-runtime-c1922c7.json).

- [Движок и renderer](docs/decisions/engine.md), [сеть](docs/network.md), [mobile](docs/mobile.md)
- [Полный бриф](docs/briefs/game-avia-20261117.md), [backlog](docs/backlog.md), [privacy/data map](docs/privacy-draft.md)
- [Сервер, обновление и rollback](docs/game-operations.md), [реальные доказательства](docs/evidence/)

Все игровые самолёты сейчас **процедурные placeholders**, не AI-модели. Image→TRELLIS→Blender заблокирован закрытым paid bootstrap и производством целевых самолётов; DINO доступ/weights теперь подтверждены родителем, первый настоящий AI safety block импортирован в Godot desktop; три задания сохранены в существующем Store. Платных вызовов за реализацию0. Point GPU-процессы/модели сохранены.

Существующие API, coordinator, outbox, GPU lease и инструменты сохранены.36 инфраструктурных тестов снова PASS; они учитываются отдельно от23 проверок Godot. Отчёты идут через Store/event/outbox единственному координатору. Зашифрованная off-server копия восстановлена с integrity_check (20 задач); ключ/БД не входят в Git. Ни автодеплоя, ни Actions, ни публикации в магазинах нет.
