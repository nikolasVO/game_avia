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

