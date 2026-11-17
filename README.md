# Game Avia

Нативный Godot4.7.2 прототип мобильной многопользовательской игры. Текущая разработка **не принята по полному ТЗ**: внешний UDP и физические Android/iPhone не подтверждены, карьерные миссии и большая часть нового объёма ещё не реализованы. [STATUS](STATUS.md), [backlog](docs/backlog.md), [полный текущий бриф](docs/briefs/game-avia-development-20261117.md).

В текущем коде работают отдельный авторитетный ENet/DTLS-сервер, свободный полёт, гонка, минимальный аркадный PvP, публичные/приватные комнаты, touch controls и EN/RU. Девять лётных прототипов: три оригинальных самолёта и F-16C, Су-27, F-15C, Су-35С, Rafale C, Gripen C. У шести истребителей различаются реальные параметры общей симуляции; есть форсаж, воздушный тормоз, закрылки, шасси, три профиля помощи и нативный ангар сравнения. Настройки конкурсов закрепляет сервер. Ещё18 вариантов настроены в каталоге, но недоступны для полёта до реализации.

Все шесть P1-истребителей в текущем исходном коде используют настоящие кандидаты корпусов TRELLIS с процедурными шасси/эффектами. Производственная приёмка, узнаваемость конкретных вариантов, анимации и телефонные замеры не завершены. Три оригинальных самолёта остаются процедурными. Су-35С имеет явно отмеченные процедурные сопла; Gripen использует импорт без сжатия вершин. APK R2 содержит только F-16C и Су-27; все шесть новых корпусов вместе проверены пока в native desktop. AI-пропсы аэродрома и припаркованный ранний кандидат отмечены отдельно. [Происхождение F-16C](assets/catalog/f16c_candidate_20261117_v1/provenance.json), [каталог/игровой баланс](docs/design/aircraft-catalog.md), [источники](docs/design/aircraft-sources.md). Игровые характеристики не являются паспортными.

Для чистой копии сначала получите настоящие LFS-ресурсы:

```sh
git clone https://github.com/nikolasVO/game_avia.git
cd game_avia
git checkout task/game-implementation-20261117
git lfs install --local
git lfs pull
git lfs fsck
```

Установите Godot `4.7.2.stable.official.ed1daf0bf` и соответствующие export templates. Запуск отдельного сервера требует защищённый существующий DTLS-ключ, соответствующий `game/avia/net/server.crt`; ключ не входит в Git. Не заменяйте сертификат или защищённую конфигурацию рабочего сервера случайной новой парой.

```sh
export GODOT=/path/to/Godot
AVIA_DTLS_KEY=/protected/server.key "$GODOT" --headless --path game/avia -- --server --port=24567
"$GODOT" --path game/avia
```

Запустите второй клиент отдельным процессом, выберите адрес/самолёт/режим и нажмите «Начать полёт». На одной машине используйте `127.0.0.1`. Приватная комната: одинаковые режим и код4–12 заглавных букв/цифр. Новый клиент использует **протокол4**; текущий вручную обновлённый сервер5c0df28 использует4, локальные сессии/реальный rollback подтверждены. Исторические сборкиr2 используют3. Внешний UDP по-прежнему недоступен; публичная совместная игра не принята.

Клавиатура: Shift/Ctrl — тяга, W/S — тангаж, A/D — крен, Q/E — руль, Space — тормоз, B — форсаж, R — восстановление, F — огонь только в PvP. На экране слева стик, справа тяга и действие; кнопки систем доступны истребителям. Начинайте на Kite; для реактивного самолёта смотрите скорость отрыва/посадки в ангаре и уменьшайте тягу после взлёта. Границы мира показаны предупреждением. Гонка проходит кольца по порядку, результаты определяет сервер. Свободный полёт мирный.

Проверки и ручные сборки:

```sh
python3 tools/godot_script_check.py --godot "$GODOT" --out /tmp/avia-scripts
AVIA_DTLS_KEY=/protected/server.key python3 tools/game_check.py --godot "$GODOT" --render --planes 3,4 --systems-cycle --seconds 25 --out /tmp/avia-two-clients
AVIA_DTLS_KEY=/protected/server.key python3 tools/protocol_check.py --godot "$GODOT" --out /tmp/avia-protocol
python3 tools/build_game.py --godot "$GODOT" --target apk
python3 tools/build_game.py --godot "$GODOT" --target aab
```

Android SDK/JDK/debug key задаются вне Git в Godot editor settings. APK использует debug-подпись, AAB — без release-подписи. Полный Xcode/SDK/Team ID/подпись iOS пока недоступны; Xcode-проект/IPA не заявлены. Эмулятор не доказывает30FPS на телефоне. Шестнадцать активных ботов прошли1850с на точном f702 сервере; публичный мультиплеер не готов до двух внешних играющих клиентов. [Измерения](docs/evidence/native-fighter-load-f702.json), [Android fb610](docs/evidence/android-f16-fb610.json).

Текущие тестовые APK/AAB/Linux/macOS протокола4 и реальное видео: [P1 prerelease](https://github.com/nikolasVO/game_avia/releases/tag/game-avia-development-p1-20261117-r1), [SHA256/исходник](docs/evidence/artifact-index-p1.json). APK5c0df28 прошёл120с эмулятора с AI-корпусом, системными кнопками и отдельный85с Home/resume/rejoin; телефонная приёмка не закрыта.

Исторические проверенные сборкиr2/c1922c7 и откат: [GitHub Release](https://github.com/nikolasVO/game_avia/releases/tag/game-avia-prototype-20261117-r2), [операции/rollback](docs/game-operations.md). Они не являются текущим новым клиентом. [Сеть](docs/network.md), [mobile](docs/mobile.md), [privacy draft](docs/privacy-draft.md).

Существующие Store/API/coordinator/outbox и GPU lease сохранены; отчёты доставляет единственный координатор. Новых платных вызовов нет, Point и чужие модели сохранены. Секреты, базы, веса и подписи находятся вне Git. Деплой только вручную; автоматических Actions/таймеров и публикации в магазинах нет.

Текущий [Android debug R2](https://github.com/nikolasVO/game_avia/releases/tag/game-avia-development-p1-20261117-r2) собран из чистого f010781: реальный эмулятор120с/3372команды/1798снимков/Home/rejoin с Су-27 PASS, FPS FAIL. APK включает явно отмеченное Java-исправление жизненного цикла поверхности; native Godot4.7.2 не изменён. [Воспроизводимая отдельная сборка и лицензии](third_party/godot_android_surface/README.md), [SHA и проверка скачанных файлов](docs/evidence/artifact-index-p1-r2.json). AAB/Linux/macOS в R1 относятся к предыдущему исходному коду; новых iOS-артефактов нет.
