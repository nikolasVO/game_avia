"""Failure fixtures exercise package guards, not actual Android gameplay/builds."""
import importlib.util
import json
import struct
import subprocess
import sys
import zipfile
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]

def run_archive(tmp_path, members):
    archive = tmp_path / 'fixture.apk'
    with zipfile.ZipFile(archive, 'w') as z:
        for name, data in members.items():
            z.writestr(name, data)
    report = tmp_path / 'inspection.json'
    p = subprocess.run([sys.executable, str(ROOT/'tools/inspect_apk.py'), str(archive), '--out', str(report)], capture_output=True, text=True, timeout=10)
    return p.returncode, json.loads(report.read_text())

def aligned_header():
    # Structural ELF fixture only; never executable/game/runtime evidence.
    data = bytearray(120)
    data[:6] = b'\x7fELF\x02\x01'
    struct.pack_into('<Q', data, 32, 64)
    struct.pack_into('<HH', data, 54, 56, 1)
    struct.pack_into('<I', data, 64, 1)
    struct.pack_into('<Q', data, 112, 16384)
    return bytes(data)

def test_archive_without_native_library_is_not_vacuous_pass(tmp_path):
    code, report = run_archive(tmp_path, {'assets/icon.svg': b'fixture'})
    assert code != 0 and report['status'] == 'FAIL'

def test_owned_ai_mesh_name_is_allowed(tmp_path):
    code, report = run_archive(tmp_path, {'lib/arm64-v8a/libgodot_android.so': aligned_header(), 'assets/trellis_owned_plane.glb': b'fixture'})
    assert code == 0 and not report['prohibited_paths']

def test_server_key_and_weights_are_rejected(tmp_path):
    code, report = run_archive(tmp_path, {'lib/arm64-v8a/libgodot_android.so': aligned_header(), 'assets/server.key': b'NOT_A_KEY_fixture', 'assets/model.safetensors': b'NOT_WEIGHTS_fixture'})
    assert code != 0 and set(report['prohibited_paths']) == {'assets/server.key', 'assets/model.safetensors'}

def test_library_without_load_segment_is_rejected(tmp_path):
    data = bytearray(aligned_header())
    struct.pack_into('<H', data, 56, 0)
    code, report = run_archive(tmp_path, {'lib/arm64-v8a/libempty.so': data})
    assert code != 0 and not report['native_libraries'][0]['16kb_elf_alignment']

def test_4kb_library_is_rejected(tmp_path):
    data = bytearray(aligned_header())
    struct.pack_into('<Q', data, 112, 4096)
    code, report = run_archive(tmp_path, {'lib/arm64-v8a/libold.so': data})
    assert code != 0 and report['status'] == 'FAIL'

def test_private_paths_are_rejected_without_blocking_game_models(tmp_path):
    private = ['assets/.env.production', 'assets/.git/config', 'assets/SIGNING.JKS', 'assets/state.sqlite3']
    members = {name: b'fixture' for name in private}
    members.update({'lib/arm64-v8a/libgodot_android.so': aligned_header(), 'assets/models/plane.glb': b'fixture'})
    code, report = run_archive(tmp_path, members)
    assert code != 0 and set(report['prohibited_paths']) == set(private)

def test_build_low_space_stops_before_tools_or_file_writes(tmp_path, monkeypatch):
    monkeypatch.syspath_prepend(str(ROOT/'tools'))
    spec = importlib.util.spec_from_file_location('mobile_build_guard_test', ROOT/'tools/build_android_surface.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    monkeypatch.setattr(module.shutil, 'disk_usage', lambda p: SimpleNamespace(free=15*1024**3))
    out = tmp_path/'must-not-exist'
    monkeypatch.setattr(sys, 'argv', ['build', '--godot', '/not-executed', '--jdk', '/not-read', '--sdk', '/not-read', '--templates', '/not-read', '--out', str(out)])
    import pytest
    with pytest.raises(SystemExit, match='10GiB reserve'):
        module.main()
    assert not out.exists()
