from fastapi.testclient import TestClient
from orchestrator.api import app

def test_local_api_auth_and_asset_validation(tmp_path,monkeypatch):
    monkeypatch.setenv("GAME_AVIA_STATE_DIR",str(tmp_path))
    monkeypatch.setenv("GAME_AVIA_API_TOKEN","private-test-token")
    with TestClient(app) as c:
        assert c.get("/health").status_code==200
        assert c.get("/tasks").status_code==401
        headers={"Authorization":"Bearer private-test-token"}
        assert c.post("/tasks",headers=headers,json={"goal":"test","chat_id":999}).status_code==422
        r=c.post("/tasks",headers=headers,json={"goal":"test"})
        assert r.status_code==200
        assert c.get("/tasks/"+r.json()["id"],headers=headers).json()["goal"]=="test"
        r=c.post("/assets",headers=headers,json={"asset_id":"box","purpose":"test","description":"box","reference_images":["box.png"],"shell":"ls"})
        assert r.status_code==422

