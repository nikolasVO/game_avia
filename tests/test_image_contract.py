import base64
import io
import json
import httpx
import pytest
from PIL import Image
from orchestrator.store import Store
from workers.assets.images import generate_reference

async def test_image_size_mismatch_preserves_original_and_stops_retries(tmp_path,monkeypatch):
    im=Image.new("RGB",(16,16));buffer=io.BytesIO();im.save(buffer,format="PNG");raw=buffer.getvalue()
    requests=[]
    def handler(request):
        body=json.loads(request.content)
        assert body["size"]=="1024x1024" and body["model"]=="gpt-image-2"
        requests.append(body)
        return httpx.Response(200,json={"data":[{"b64_json":base64.b64encode(raw).decode()}]})
    client=httpx.AsyncClient
    monkeypatch.setattr(httpx,"AsyncClient",lambda **kwargs:client(transport=httpx.MockTransport(handler),**kwargs))
    monkeypatch.setenv("OPENLUX_IMAGE_BASE_URL","https://api.example.test/v1")
    monkeypatch.setenv("OPENLUX_IMAGE_API_KEY","fake-test-key")
    s=Store(tmp_path/"s.db");output=tmp_path/"original.png"
    r=await generate_reference(s,"OPENLUX_IMAGE","gpt-image-2","neutral test",output)
    assert r["status"]=="received_parameter_mismatch" and not r["parameters_verified"]
    assert output.read_bytes()==raw
    assert s.list_tasks()[0]["status"]=="blocked"
    with pytest.raises(RuntimeError):
        await generate_reference(s,"OPENLUX_IMAGE","gpt-image-2","neutral test",output)
    assert len(requests)==1

