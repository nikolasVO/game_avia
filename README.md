# Game Avia

Нативный прототип Godot **4.7.2 stable**: отдельный авторитетный ENet/DTLS-сервер, три процедурных самолёта, остров с двумя полосами, свободный полёт, гонка и аркадный PvP. Есть touch controls, EN/RU, выбор самолёта, приватные комнаты и настройки. Рабочий подзаголовок Tidal Wings пока не прошёл проверку названия для публикации.

**Это проверяемый вертикальный срез, а не принятая версия 0.1.** На Thunder 16 активных протокольных клиентов непрерывно работали 1850 s: максимальный отчётный p95 симуляции 3.398 ms, RSS 103.7 MiB. Приватная комната на16 мест, отказ17-му и изоляция публичной комнаты проверены отдельными процессами. Это loopback и боты, не16 человек/телефонов. Внешний UDP24567 с Mac до публичного endpoint Thunder не прошёл.

Исходники и собранные APK/AAB/macOS/server относятся к `3417828170d35a3ab2acac0c3fc1ad5ab2bf1046`. Ветка: [task/game-implementation-20261117](https://github.com/nikolasVO/game_avia/tree/task/game-implementation-20261117). Итоговая матрица — [STATUS](STATUS.md), артефакты/хеши — [handoff](docs/handoffs/game-prototype-20261117.md).

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

Управление: слева тангаж/крен, справа сохраняемая тяга и действие; Recover восстанавливает самолёт. На desktop Shift/Ctrl — тяга, W/S — тангаж, A/D — крен, Q/E — руль, Space — тормоз, R — восстановление, F — огонь только в PvP. В гонке проходите золотые кольца по порядку; время и результат считает сервер. Все три самолёта бесплатны.

Проверки и ручные сборки:

```sh
"$GODOT" --headless --path game/avia --script res://tests/flight_check.gd
AVIA_DTLS_KEY=/protected/server.key python3 tools/game_check.py --godot "$GODOT" --render --seconds 20 --out /tmp/avia-two-clients
AVIA_DTLS_KEY=/protected/server.key python3 tools/protocol_check.py --godot "$GODOT" --out /tmp/avia-protocol
python3 tools/build_game.py --godot "$GODOT" --target apk
python3 tools/build_game.py --godot "$GODOT" --target aab
```

Android SDK/JDK/debug key задаются во внешних Godot editor settings. APK подписан debug-ключом, release AAB собран без release-подписи; это не готовая магазинная публикация. iOS заблокирован отсутствием полного Xcode/SDK/Team ID/подписи; Xcode-проект и IPA не заявлены. Физические Android/iPhone, тепловые20–30-минутные замеры и16KB runtime пока NOT VERIFIED.

Android-эмулятор действительно установил APK и показал второй desktop-самолёт. Поздняя проверка сборки3417828 выявила остановку клиентского цикла в перегруженном SwiftShader-окружении; видео со статичной сценой не принято как доказательство полёта. Точная текущая оценка и последующая попытка с аппаратным renderer фиксируются в handoff. Ранний successful takeoff protocol2 не заменяет проверку финального APK.

- [Движок и renderer](docs/decisions/engine.md), [сеть](docs/network.md), [mobile](docs/mobile.md)
- [Полный бриф](docs/briefs/game-avia-20261117.md), [backlog](docs/backlog.md), [privacy/data map](docs/privacy-draft.md)
- [Сервер, обновление и rollback](docs/game-operations.md), [реальные доказательства](docs/evidence/)

Все игровые самолёты сейчас **процедурные placeholders**, не AI-модели. Image→TRELLIS→Blender заблокирован закрытым paid bootstrap и gated DINOv3; три задания сохранены в существующем Store. Платных вызовов за реализацию0. Point GPU-процессы/модели сохранены.

Существующие API, coordinator, outbox, GPU lease и инструменты сохранены.36 инфраструктурных тестов снова PASS; они учитываются отдельно от21 проверки Godot. Отчёты идут через Store/event/outbox единственному координатору. Зашифрованная off-server копия восстановлена с integrity_check (20 задач); ключ/БД не входят в Git. Ни автодеплоя, ни Actions, ни публикации в магазинах нет.
