from orchestrator.settings import load_environment,environment_proof

def test_service_environment_is_scoped(tmp_path,monkeypatch):
    values={"TELEGRAM_BOT_TOKEN":"fake:token","OPENLUX_CODEX_API_KEY":"fake-key","OPENLUX_IMAGE_API_KEY":"fake-image-key","GAME_AVIA_API_TOKEN":"fake-auth"}
    file=tmp_path/"private.env";file.write_text("\n".join(k+"="+v for k,v in values.items()))
    import os
    for k,v in values.items():monkeypatch.setenv(k,v)
    load_environment(file,role="api")
    assert os.environ["GAME_AVIA_API_TOKEN"]=="fake-auth"
    assert "OPENLUX_CODEX_API_KEY" not in os.environ
    assert "TELEGRAM_BOT_TOKEN" not in os.environ
    assert environment_proof("api")["scoped"]
    for k,v in values.items():monkeypatch.setenv(k,v)
    load_environment(file,role="executor")
    assert os.environ["OPENLUX_CODEX_API_KEY"]=="fake-key"
    assert "TELEGRAM_BOT_TOKEN" not in os.environ
    assert "OPENLUX_IMAGE_API_KEY" not in os.environ
    assert "GAME_AVIA_API_TOKEN" not in os.environ
    assert environment_proof("executor")["scoped"]
