# game_avia

Базовый контур разработки мобильной Unity-игры: личный Telegram, SQLite/WAL, устойчивый outbox, ограниченные GPT/Claude workers, локальный Ollama, типизированный asset API и подготовленный TRELLIS/Blender runner.

Это проверенный промежуточный этап. Полная цепочка reference → TRELLIS → Unity и официальный Codex Responses ещё не приняты. Описание самой игры пока не получено.

Проверено: 31 тестов инфраструктуры, два изолированных теста сгенерированного кода, настоящий tool-use и продолжение на OpenLux/WhatsToken/Claude/Ollama, восстановление SQLite/outbox после перезапуска, GitHub/LFS, зашифрованный off-server backup с восстановлением. Первый кодовый smoke потребовал восстановления тестового этапа интегратором; полностью автономный повтор остаётся отдельной проверкой.

Полученный OpenLux-референс сохранён оригиналом: 1254×1254 вместо запрошенных 1024×1024. Точная размерность маршрута заблокирована; [обращение поддержке](docs/provider-support-openlux-image-size.md) подготовлено и не отправлено. Процедурный куб Blender — отдельный технический тест, не результат TRELLIS.

Новые задания принимаются обычным текстом в личном чате бота. Начните с /status, /providers, /budget и реального описания игрового цикла. Платный bootstrap ограничен 12 облачными текстовыми попытками и одной генерацией изображения; этот лимит исчерпан. Денежный бюджет не настроен, стоимость остаётся cost_unknown. Большой автономный backlog не запускается.

- [Отчёт этапа и ограничения](reports/milestone-20261117.md)
- [Эксплуатация, обновление и восстановление](docs/operations.md)
- [Маршруты и доказательства](docs/providers.md)
- [Ассеты и runner](docs/assets.md)
- [Матрица точных моделей](config/providers.yaml)
- [GLB, превью и манифест](assets/catalog/blender-fixture/manifest.json)

На сервере из корня репозитория:

    ./scripts/doctor
    /srv/game-avia/venvs/core/bin/python -m pytest -q
    /srv/game-avia/venvs/core/bin/python -m scripts.acceptance_check

API доступен только на loopback; task/asset endpoints защищены токеном. Секреты, operational DB, веса и кэши исключены из Git. Службы запускаются под ubuntu через существующий s6; systemd units сохранены для другого совместимого хоста. Автодеплой и GitHub Actions не настроены.
