import json

from workers.coding.provider_runtime import configure_provider, select_route


ROUTES = [
    {"id": "openlux", "env_prefix": "OPENLUX_CODEX", "model": "gpt-6.1-sol"},
    {"id": "whatstoken", "env_prefix": "WHATSTOKEN_CODEX", "model": "gpt-6.1-sol-pro"},
]


def test_credentials_are_not_written_to_cli_arguments_or_other_environment(tmp_path):
    secret = "sk-test-" + "x" * 24
    path = tmp_path / "credentials.json"
    path.write_text(json.dumps({"WHATSTOKEN_CODEX": {"base_url": "https://www.whatstoken.ai/v1", "api_key": secret}}))
    args, env = configure_provider(["codex", "exec"], ROUTES[1], path,
                                   {"PATH": "/usr/bin", "HOME": "/owner", "OTHER_API_KEY": "unrelated", "TELEGRAM_BOT_TOKEN": "private"})
    assert secret not in " ".join(args)
    assert 'model="gpt-6.1-sol-pro"' in args
    assert env["GAME_AVIA_ROUTE_API_KEY"] == secret and env["HOME"] == "/owner"
    assert "OTHER_API_KEY" not in env and "TELEGRAM_BOT_TOKEN" not in env
    assert any('requires_openai_auth=false' in arg for arg in args)


def test_account_quota_does_not_block_independent_authorized_provider():
    route, cooldowns = select_route(ROUTES, {"account_mode": "ChatGPT"}, {},
                                   [{"type": "turn.failed", "error": {"message": "usage limit"}}], "subscription-turn", 100)
    assert route == ROUTES[0] and not cooldowns


def test_failed_route_rotates_and_persists_cooldown_without_repeating_failure():
    events = [{"type": "turn.failed", "error": {"message": "usage limit 429"}}]
    process = {"account_mode": "provider_api", "api_route": "openlux"}
    route, cooldowns = select_route(ROUTES, process, {}, events, "failure", 100)
    assert route == ROUTES[1] and cooldowns["openlux"] == 3700
    route, same = select_route(ROUTES, process, {"api_cooldowns": cooldowns, "api_failure_signature": "failure"},
                              events, "failure", 200)
    assert route == ROUTES[1] and same == cooldowns


def test_all_blocked_routes_wait_and_success_keeps_healthy_route():
    route, _ = select_route(ROUTES, {}, {"api_cooldowns": {"openlux": 1000, "whatstoken": 2000}}, [], "none", 100)
    assert route is None
    route, _ = select_route(ROUTES, {"api_route": "whatstoken"}, {}, [{"type": "turn.completed"}], "ok", 100)
    assert route == ROUTES[1]
