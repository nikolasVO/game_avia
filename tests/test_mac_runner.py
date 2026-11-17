import pytest
from scripts.mac_unity_runner import run

@pytest.mark.parametrize("commit", ["main", "a"*39+";"])
def test_runner_requires_exact_commit(commit):
    with pytest.raises(ValueError, match="exact"):
        run(commit)

@pytest.mark.parametrize("target", ["-v", "thunder;echo bad"])
def test_runner_rejects_ssh_option_or_shell_target(target):
    with pytest.raises(ValueError, match="alias"):
        run("a"*40, target)

def test_runner_stops_before_fetch_on_deployed_commit_mismatch(tmp_path, monkeypatch):
    import scripts.mac_unity_runner as runner
    monkeypatch.setattr(runner.Path, "home", lambda: tmp_path)
    calls=[]
    monkeypatch.setattr(runner.subprocess, "check_output", lambda *a,**kw: "b"*40)
    monkeypatch.setattr(runner.subprocess, "run", lambda *a,**kw: calls.append(a))
    with pytest.raises(RuntimeError, match="deployed"):
        run("a"*40)
    assert not calls
