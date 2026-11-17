import sys
import pytest
from tools.build_validation import check_materialized_assets,checked_godot


def test_lfs_pointer_refused_before_export(tmp_path):
    assets=tmp_path/'assets';assets.mkdir();p=assets/'aircraft.glb'
    p.write_text('version https://git-lfs.github.com/spec/v1\noid sha256:dead\nsize 100\n')
    with pytest.raises(RuntimeError,match='unmaterialized_LFS_asset'):check_materialized_assets(tmp_path)
    p.write_bytes(b'glTF materialized data');check_materialized_assets(tmp_path)


def test_exit_zero_with_engine_error_refused():
    with pytest.raises(RuntimeError,match='Godot import/export failed'):
        checked_godot([sys.executable,'-c','print("ERROR: corrupt imported asset")'],timeout=5)
    assert checked_godot([sys.executable,'-c','print("clean process output")'],timeout=5).returncode==0
