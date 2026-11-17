# Game Avia — передача prototype r2, 17 ноября 2026

Работающая нативная игра на Godot4.7.2: свободный полёт, взлёт/авария/recovery, две полосы, три оригинальных процедурных самолёта, серверная гонка, минимальный отдельный PvP, private/public rooms, EN/RU, touch, настройки и серверная статистика. **Версия0.1 НЕ ПРИНЯТА**: внешняя сеть, физические телефоны, iOS и AI-пайплайн не закрыты; есть открытая игровая/QA работа.

Код/build/deploy: **c1922c74a29112818ce9ee523a9cdc81eb211180**, protocol3, Godot **4.7.2.stable.official.ed1daf0bf** и соответствующие templates. Следующие commits обновляют evidence/тестовые наблюдатели, не экспортированный gameplay. [Ветка](https://github.com/nikolasVO/game_avia/tree/task/game-implementation-20261117), [prerelease r2](https://github.com/nikolasVO/game_avia/releases/tag/game-avia-prototype-20261117-r2), [STATUS](../../STATUS.md). Первый3417828 комплект и его FAIL evidence сохранены отдельно.

| Артефакт | Bytes | SHA256 |
|---|---:|---|
| [game-avia-0.1.0-debug.apk](https://github.com/nikolasVO/game_avia/releases/download/game-avia-prototype-20261117-r2/game-avia-0.1.0-debug.apk) | 57084430 | `c365fc7ee47dc3c735813efc83a35a92e60dd5e4c057a7ae73f8cc3ea145a98b` |
| [game-avia-0.1.0-unsigned.aab](https://github.com/nikolasVO/game_avia/releases/download/game-avia-prototype-20261117-r2/game-avia-0.1.0-unsigned.aab) | 52374487 | `4b3fde1a95a51b222e09f8012ec53a3b8003e58d719a330b295f3ee7f1bd2fdb` |
| [game-avia-c1922c7.mp4](https://github.com/nikolasVO/game_avia/releases/download/game-avia-prototype-20261117-r2/game-avia-c1922c7.mp4) | 343995 | `7b2180dcb28a9711493aa0c9645bdd1ab2e44b3bd8d480b9ec8a8dba5e606ae2` |
| [game-avia-server.x86_64](https://github.com/nikolasVO/game_avia/releases/download/game-avia-prototype-20261117-r2/game-avia-server.x86_64) | 73656080 | `f6b1aea7fc5790e538d75eeafd69a0361cdd9013249208242be05fb8c2e1ed63` |
| [GameAvia.zip](https://github.com/nikolasVO/game_avia/releases/download/game-avia-prototype-20261117-r2/GameAvia.zip) | 64508331 | `c7747a1237f57ec0daa733fc078c53a65883192ce02b4dca2682ce80bea2c861` |

Все5 удалённых digest/размеров совпали; APK реально скачан обратно и SHA проверен. APK подписан debug-ключом, versionName0.1.0/versionCode1. AAB действительно собран и проверен bundletool, но **без release-подписи**. macOS не подписан/notarized. iOS-артефактов нет. Подписи APKv2/v3 и16KB ELF/ZIP alignment проверены статически; это не16KB device runtime.

Что исправлено и проверено:

- Обнаружена реальная ошибка Godot4.7.2: create_server превращал max_channels в6bytes/s incoming bandwidth, throttle limit падал до1/32 и команды исчезали до validator. Явные host.bandwidth_limit/channel_limit восстановили32/32. Все6 отдельных неверных команд и поддельный ticket фактически получены и отклонены; replay/expiry наблюдаются по sender.9 сценариев PASS,150 принятых peaceful-fire inputs не дали выстрелов. [Причина/проверка](../evidence/enet-bandwidth-defect.md).
- Disconnect/timeout/background сохраняют понятную причину, очищают самолёты/звук/prediction/controls.7 lifecycle checks и настоящий Android Home/возврат/rejoin PASS. Ошибки входа видны в меню, есть повторный вход.
- Отдельный экспортированный9412be7 сервер:16 активных клиентов минимум1850s,887989 accepted inputs за этот интервал (~29.9996Hz/client), p95 **тела симуляции** максимум3.352ms, RSS максимум92MiB, CPU максимум8.197% одного core. [Полные данные](../evidence/native-load16-9412be7.json). Это loopback/control bots. Уc192 byte-identical authority files; его реальный бинарник отдельно прошёл native/post-deploy smoke. Не выдаётся второй31-minute тестc192 binary.
- Текущий c192: две повторные гонки у каждого из двух клиентов (~48.6s); PvP5 клиентов дал156 hits/39 scores/36 recoveries. RTT100/200ms+jitter±30/50ms+loss1/3% оба клиента выдержали. Не physical handover.
- Clean9412 APK300s: touch-взлёт/recovery, Home/rejoin,8115 команд/4045 snapshots. Clean c192 APK120s:2971 команд/1552 snapshots,2 peers, touch-взлёт/Home/rejoin. FPS target **FAIL**: c192 p50 кадра69.338ms/p95152.468ms в SwiftShader. Телефонные FPS не заявлены. [Runtime](../evidence/android-runtime-c1922c7.json).
- Видеоc192 — обычный Android screenrecord18.7417s,640×360, без ускорения; кадр декодирован и просмотрен. Это эмулятор/scripted input, не physical/human session.
- Три улучшенные модели — **procedural**, не AI:276/276/304 near triangles,96 far, animated props, manifests/source hashes. Убраны полностью подводные terrain triangles, увеличен camera near, добавлены context brake/прицел, локализованные ошибки и предупреждения границ.23 shared/synthetic checks и rendered two-client flight PASS.
- APK повторно экспортирован из отдельного clean checkoutc192. Byte SHA отличается: generated scene resource/node IDs, ZIP timestamps, подпись и sparse index; остальной payload и source hashes совпадают. Это воспроизводимость экспорта, не побайтно детерминированный архив. [Сравнение](../evidence/clean-rebuild-c1922c7.json).

Запуск и сборка из checkout с LFS:

```sh
git lfs pull
"$GODOT" --headless --path game/avia --editor --import --quit
AVIA_DTLS_KEY=/protected/server.key "$GODOT" --headless --path game/avia -- --server --port=24567
"$GODOT" --path game/avia -- --connect=127.0.0.1
"$GODOT" --path game/avia -- --connect=127.0.0.1
python3 tools/build_game.py --godot "$GODOT" --target apk
python3 tools/build_game.py --godot "$GODOT" --target aab
```

GODOT — закреплённый standard binary, SDK/JDK/debug key настроены вне Git. Приватный ключ существующего dev-сервера находится в защищённой конфигурации Mac/Thunder; он должен соответствовать public server.crt. Для независимого сервера создайте свою trust pair и клиент с соответствующим публичным сертификатом, не отключайте проверку. В Android Emulator Mac доступен как10.0.2.2. Для физического телефона нужен реально доступный адрес сервера. APK можно установить `adb install -r <apk>`. iOS preset сам по себе не означает Xcode project/IPA.

В полёте слева pitch/roll, справа сохраняемая тяга; круг — тормоз в мирном режиме, огонь в PvP. Recover — восстановление, в гонке повтор. Desktop: Shift/Ctrl тяга, W/S pitch, A/D bank, Q/E rudder, Space brake, R recovery, F PvP fire. Частные комнаты требуют одинаковый режим и код4–12 заглавных букв/цифр. Публичный quick-match ограничен16 участниками на комнату.

Сервер Thunder: отдельный s6/supervisor **game-avia-flight**, UDP24567, ubuntu. Текущий binary расположен `/srv/game-avia/releases/c1922c74a29112818ce9ee523a9cdc81eb211180/game-avia-server.x86_64`. Health/диагностика:

```sh
/srv/game-avia/venvs/core/bin/supervisorctl -c /srv/game-avia/state/flight/supervisord.conf status
tail -n 30 /srv/game-avia/logs/flight.log
```

Обновление было **ручным**: immutable release/hash, защищённый backup progress/config, замена только flight config path, reread/update, два клиента. Progress114→116 flights сохранён. API/coordinator/executor остались97bd7dd, healthy; provider credentials в game process0. Point процессы/модели сохранены. Для rollback есть проверенный9412 binary с тем же protocol/authority; не откатывайте подтверждённый progress. [Полный runbook](../game-operations.md), [deploy evidence](../evidence/deployment-c1922c7.json).

Что остаётся:

- **External FAIL:** новый прямой Mac→Thunder UDP24567 даёт joined=false/snapshots0; echo тоже timeout. Нужен настроенный существующий UDP mapping/firewall path либо уже разрешённый подходящий endpoint после реальной проверки. SSH/TCP не считается UDP. Новый платный хостинг не заказан.
- **BLOCKED:** Meta approval DINOv3; HF_TOKEN владелец настроит после одобрения. Gate не опрашивается/не обходится, paid bootstrap не переоткрыт. Все AI aircraft/production pipeline остаются pending. Платных вызовов реализации0.
- **BLOCKED / NOT VERIFIED:** полный Xcode/iOS SDK/TeamID/provisioning, release signing/internal-testing права; физические Android/iPhone20–30-minute полёты, multi-touch/thermals/safe area/handovers и16KB runtime. ADB не видит Android; USB iOS enumeration вернул ошибки и не доказывает отсутствие iPhone.
- **OPEN code/QA:** bounded-history PvP lag compensation, hostile RPC/resource audit, production AI LOD/audio, flight feel/manual landing QA. Нынешние globals не являются per-user persistent account; accounts требуют secure tokens/deletion. Для будущего RC нужны name clearance, privacy operator/contact/retention, реальные store материалы/рейтинг и актуальные требования магазинов.

Telegram отчёты/видео помещаются через существующий Store/outbox, доставляет единственный coordinator. Старый handoff_final доставлен родителем и не повторялся. Код/конфиги/очищенные evidence в Git; ключи, credentials, БД, weights/cache исключены. Store submission, новые покупки/terms, Actions, timers и autodeploy не выполнялись.
