"""Actual installed Blender checks; skipped without an explicit executable."""
import json
import os
from pathlib import Path
import subprocess
import pytest

BLENDER=os.getenv('BLENDER_EXE')
pytestmark=pytest.mark.skipif(not BLENDER,reason='actual Blender executable required')


def test_actual_blender_staged_manifest_and_import_license(tmp_path):
    script=Path(__file__).resolve().parents[1]/'scripts/blender_optimize.py'
    fixture=tmp_path/'fixture';imported=tmp_path/'imported';rotated=tmp_path/'rotated'
    for out,source in ((fixture,['--fixture']),(imported,['--input',str(fixture/'original.glb')]),(rotated,['--input',str(fixture/'original.glb'),'--rotate-z-degrees','-90'])):
        result=subprocess.run([BLENDER,'--background','--factory-startup','--threads','2','--python',str(script),'--',*source,'--output-dir',str(out),'--manifest-name','geometry-manifest.json'],capture_output=True,text=True,timeout=120)
        assert result.returncode==0,result.stdout[-2000:]+result.stderr[-2000:]
        assert not (out/'manifest.json').exists()
        manifest=json.loads((out/'geometry-manifest.json').read_text())
        assert manifest['verified']
        assert manifest['geometry']['finite_vertices_and_normals']
        assert manifest['geometry']['degenerate_triangles']==0
        assert all((out/name).is_file() for name in ('lod0.glb','lod1.glb','lod2.glb'))
    assert json.loads((fixture/'geometry-manifest.json').read_text())['license']=='CC0 procedural fixture'
    assert json.loads((imported/'geometry-manifest.json').read_text())['license']=='see source manifest'

    assert (rotated/'lod0.glb').read_bytes()!=(imported/'lod0.glb').read_bytes()
    assert json.loads((rotated/'geometry-manifest.json').read_text())['source_yaw_degrees']==-90


def test_actual_blender_repairs_asymmetric_reference(tmp_path):
    script=Path(__file__).resolve().parents[1]/'scripts/blender_optimize.py'
    before=tmp_path/'before';after=tmp_path/'after'
    for out,extra in ((before,[]),(after,['--symmetry-x'])):
        r=subprocess.run([BLENDER,'--background','--factory-startup','--threads','2','--python',str(script),'--','--fixture','--fixture-asymmetric','--output-dir',str(out),*extra],capture_output=True,text=True,timeout=120)
        assert r.returncode==0,r.stdout[-2000:]+r.stderr[-2000:]
    a=json.loads((before/'manifest.json').read_text());b=json.loads((after/'manifest.json').read_text())
    assert a['geometry']['symmetry']['max_distance_m']>.01
    assert b['verified'] and b['geometry']['symmetry']['max_distance_m']<1e-4
    assert b['symmetry_enforced_x'] and b['geometry']['degenerate_triangles']==0
    assert b['triangles_lod0']<=5000
