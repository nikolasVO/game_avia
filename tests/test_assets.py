import pytest
from workers.assets.pipeline import AssetSpec,reference_path,readiness,compact_config
def test_spec_rejects_commands_and_non512():
    base={"asset_id":"cube","purpose":"test","description":"test","reference_images":["cube.png"]}
    with pytest.raises(ValueError):AssetSpec(**base,shell="rm")
    with pytest.raises(ValueError):AssetSpec(**base,pipeline_type="1024")
def test_reference_escape(tmp_path):
    outside=tmp_path/"secret.png";outside.write_bytes(b"x")
    root=tmp_path/"refs";root.mkdir()
    (root/"link.png").symlink_to(outside)
    with pytest.raises(ValueError):reference_path(root,"link.png")
    with pytest.raises(ValueError):reference_path(root,"../secret.png")
def test_missing_weights_honest(tmp_path):
    assert readiness(tmp_path)["blocked"]
    assert not readiness(tmp_path)["tested"]



def test_verified_asset_reuses_identical_json_roundtrip(tmp_path):
    import json
    from workers.assets.pipeline import AssetRunner
    refs=tmp_path/"repo/assets/source";refs.mkdir(parents=True)
    (refs/"cube.png").write_bytes(b"owned-reference")
    task={"id":"test","spec":{"asset_id":"cube","purpose":"test","description":"test","reference_images":["cube.png"],"dimensions_m":[1,1,1]}}
    runner=AssetRunner(None,tmp_path)
    first=runner.prepare(task)
    output=tmp_path/"artifacts/cube";request=(output/"request.json").read_bytes()
    (output/"manifest.json").write_text(json.dumps({"verified":True,"proof":"existing-result"}))
    repeated=runner.prepare(task)
    assert repeated["state"]=="reused"
    assert repeated["input_hash"]==first["input_hash"]
    assert repeated["existing_manifest"]["proof"]=="existing-result"
    assert (output/"request.json").read_bytes()==request
    task["spec"]["dimensions_m"]=[2,1,1]
    with pytest.raises(RuntimeError,match="asset_id_conflict"):runner.prepare(task)
    assert (output/"request.json").read_bytes()==request


def test_verified_asset_rejects_changed_reference(tmp_path):
    import json
    from workers.assets.pipeline import AssetRunner
    refs=tmp_path/"repo/assets/source";refs.mkdir(parents=True)
    source=refs/"cube.png";source.write_bytes(b"original")
    task={"id":"test","spec":{"asset_id":"cube","purpose":"test","description":"test","reference_images":["cube.png"]}}
    runner=AssetRunner(None,tmp_path);runner.prepare(task)
    output=tmp_path/"artifacts/cube";(output/"manifest.json").write_text(json.dumps({"verified":True}))
    source.write_bytes(b"changed")
    with pytest.raises(RuntimeError,match="asset_id_conflict"):runner.prepare(task)
    assert json.loads((output/"manifest.json").read_text())["verified"]


def test_verified_asset_rejects_changed_model_revision(tmp_path):
    import json
    from workers.assets.pipeline import AssetRunner
    refs=tmp_path/"repo/assets/source";refs.mkdir(parents=True);(refs/"cube.png").write_bytes(b"reference")
    models=tmp_path/"models/trellis512";models.mkdir(parents=True)
    manifest=models/"model-manifest.json";manifest.write_text(json.dumps({"revisions":{"trellis":"revision-a"}}))
    task={"id":"test","spec":{"asset_id":"cube","purpose":"test","description":"test","reference_images":["cube.png"]}}
    runner=AssetRunner(None,tmp_path);runner.prepare(task)
    result=tmp_path/"artifacts/cube/manifest.json";result.write_text(json.dumps({"verified":True}))
    assert runner.prepare(task)["state"]=="reused"
    manifest.write_text(json.dumps({"revisions":{"trellis":"revision-b"}}))
    with pytest.raises(RuntimeError,match="asset_id_conflict"):runner.prepare(task)
    assert json.loads(result.read_text())["verified"]
