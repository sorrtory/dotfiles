#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$repo/scripts/bin/vm-create.sh" <<'PY'
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import tempfile

script = sys.argv[1]

# Exercise the command's public interface, with real QCOW2 files and real SSH
# keys. The backend replaces host/guest control interfaces, not script internals.
backend = r'''
import json, os, shutil, subprocess, sys
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(os.environ["VM_TEST_ROOT"])
state_file = root / "state.json"
state = json.loads(state_file.read_text())
command, args = Path(sys.argv[1]).name, sys.argv[2:]
with (root / "calls.jsonl").open("a") as log:
    log.write(json.dumps([command, *args]) + "\n")
def save(): state_file.write_text(json.dumps(state))
def value(flag): return args[args.index(flag) + 1]
def fail(): sys.exit(1)
def qemu(*options): subprocess.run(["qemu-img", *options], check=True, stdout=subprocess.DEVNULL)

if command == "curl":
    target = Path(value("-o"))
    if args[-1].endswith("download.json"):
        shutil.copyfile(root / "metadata.json", target)
    elif os.environ.get("VM_TEST_INTERRUPT") and not target.exists():
        target.write_bytes((root / "image.img").read_bytes()[:4096]); sys.exit(18)
    elif os.environ.get("VM_TEST_CORRUPT"):
        target.write_bytes(b"corrupted download")
    else:
        shutil.copyfile(root / "image.img", target)
elif command == "virsh":
    assert args[:2] == ["--connect", "qemu:///system"], args
    args = args[2:]; action = args[0]
    volumes = root / "volumes"
    if action == "uri": print("qemu:///system")
    elif action == "list": print("\n".join(state["domains"]))
    elif action == "net-list": print("default")
    elif action == "net-dumpxml":
        print('<network><forward mode="nat"/><ip address="192.168.123.1"><dhcp><range start="192.168.123.2" end="192.168.123.254"/></dhcp></ip></network>')
    elif action == "pool-list": print("default")
    elif action == "pool-dumpxml": print(f'<pool type="dir"><target><path>{volumes}</path></target></pool>')
    elif action == "vol-list":
        assert len(args) == 2, args
        print("Name Path\n---------\n" + "\n".join(f"{p.name} {p}" for p in volumes.iterdir()))
    elif action == "vol-create-as":
        target = volumes / args[2]
        if target.exists(): fail()
        qemu("create", "-f", "qcow2", str(target), args[3])
    elif action == "vol-upload":
        if os.environ.get("VM_TEST_UPLOAD_FAIL"): fail()
        shutil.copyfile(args[2], volumes / args[1])
    elif action == "vol-download": shutil.copyfile(volumes / args[1], args[2])
    elif action == "vol-create-from":
        name = ET.parse(args[2]).findtext("name"); target = volumes / name
        if target.exists(): fail()
        qemu("convert", "-f", "qcow2", "-O", "qcow2", str(volumes / args[3]), str(target))
    elif action == "vol-resize":
        if os.environ.get("VM_TEST_RESIZE_FAIL"): fail()
        qemu("resize", str(volumes / args[1]), args[2])
    elif action == "vol-path": print(volumes / args[1])
    elif action == "vol-delete": (volumes / args[1]).unlink()
    elif action == "domifaddr":
        ip = "192.168.123.2"
        if os.environ.get("VM_TEST_ADDRESS_CHANGE") and state.get("final_boot") and value("--source") == "agent":
            state["agent_queries"] += 1; save()
            if state["agent_queries"] <= 2: fail()
            ip = "192.168.123.3"
        if not os.environ.get("VM_TEST_NO_LEASE"): print("vnet0 52:54:00:11:22:33 ipv4 " + ip + "/24")
    elif action == "domuuid": print("11111111-2222-3333-4444-555555555555")
    elif action == "shutdown": pass
    elif action == "domstate": print("shut off")
    elif action == "start":
        state["final_boot"] = True; state["agent_queries"] = 0; save()
    elif action == "qemu-agent-command": print('{"return": {}}')
    elif action == "autostart": state["autostart"].append(args[1]); save()
    else: raise AssertionError(args)
elif command == "virt-install":
    if args == ["--osinfo", "list"]:
        print("generic" if os.environ.get("VM_TEST_OLD_OSINFO") else "ubuntu24.04, ubuntunoble")
        sys.exit(0)
    if os.environ.get("VM_TEST_INSTALL_FAIL") == "before": fail()
    name = value("--name")
    if name in state["domains"]: fail()
    files = dict(x.split("=", 1) for x in value("--cloud-init").split(","))
    shutil.copyfile(files["user-data"], root / "user-data")
    shutil.copyfile(files["meta-data"], root / "meta-data")
    state["domains"].append(name); state["final_boot"] = False; save()
    if os.environ.get("VM_TEST_INSTALL_FAIL") == "after": fail()
elif command == "ssh":
    endpoint = next(x for x in args if x.endswith(("@192.168.123.2", "@192.168.123.3")))
    if os.environ.get("VM_TEST_ADDRESS_CHANGE") and state.get("final_boot") and endpoint.endswith("@192.168.123.2"): fail()
    if "-tt" not in args:
        env = os.environ.copy()
        env["VM_TEST_GUEST_USER"] = endpoint.split("@")[0]
        sys.exit(subprocess.run(["bash", "-c", args[-1]], env=env).returncode)
elif command == "sudo":
    env = os.environ.copy(); env["VM_TEST_GUEST_USER"] = "root"
    sys.exit(subprocess.run(args[1:], env=env).returncode)
elif command == "id":
    user = os.environ["VM_TEST_GUEST_USER"]
    print(("0" if user == "root" else "1000") if args == ["-u"] else user)
elif command == "cloud-init":
    if os.environ.get("VM_TEST_CLOUD_FAIL"): fail()
    print("status: done")
elif command == "systemctl":
    if args == ["get-default"]: print("graphical.target")
elif command == "loginctl":
    if args == ["list-sessions", "--no-legend"]: print("7 1000 guest seat0 tty2")
    else:
        properties = {"Name": os.environ["VM_TEST_GUEST_USER"], "Type": "wayland", "Active": "yes", "Remote": "no"}
        print(properties[next(a.split("=", 1)[1] for a in args if a.startswith("--property="))])
elif command == "gdbus":
    if args[-1] == "org.gnome.Shell": print("(':1.42',)")
    else: print("(true,)" if os.environ.get("VM_TEST_LOCKED_DESKTOP") else "(false,)")
elif command == "gsettings":
    settings = {"lock-enabled": "false", "disable-lock-screen": "true", "idle-delay": "uint32 0", "sleep-inactive-ac-type": "'nothing'", "sleep-inactive-battery-type": "'nothing'"}
    print(settings[args[-1]])
elif command == "stat": print(os.environ["VM_TEST_GUEST_USER"])
elif command in ("virt-viewer", "virt-manager"): pass
elif command == "passwd": print(args[1] + " L 2026-10-14 0 99999 7 -1")
elif command == "sshd": print("passwordauthentication no\nkbdinteractiveauthentication no")
elif command == "ufw":
    host = "0.0.0.0/0" if os.environ.get("VM_TEST_BAD_FIREWALL") else "192.168.123.1"
    print("Status: active\nDefault: deny (incoming), allow (outgoing), disabled (routed)\n\nTo Action From\n-- ------ ----\n22/tcp ALLOW IN " + host)
else: raise AssertionError(command)
'''

with tempfile.TemporaryDirectory(prefix="vm-create-test-") as directory:
    root = Path(directory)
    (root / "volumes").mkdir()
    (root / "bin").mkdir()
    (root / "backend.py").write_text(backend)
    (root / "state.json").write_text(json.dumps({"domains": [], "autostart": []}))
    subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(root / "identity")], check=True)
    subprocess.run(["qemu-img", "create", "-f", "qcow2", str(root / "image.img"), "64M"], check=True, stdout=subprocess.DEVNULL)
    image = (root / "image.img").read_bytes()
    digest = hashlib.sha256(image).hexdigest()
    item = {"path": "server/releases/noble/release-20260926/ubuntu-24.04-server-cloudimg-amd64.img",
            "sha256": digest, "size": len(image)}
    metadata = {"products": {"com.ubuntu.cloud:server:24.04:amd64": {"versions": {
        "20260926": {"items": {"disk1.img": item}}}}}}
    (root / "metadata.json").write_text(json.dumps(metadata))
    host_commands = ["curl", "virsh", "virt-install", "ssh", "virt-viewer", "virt-manager"]
    guest_commands = ["sudo", "id", "cloud-init", "systemctl", "passwd", "sshd", "ufw", "loginctl", "gdbus", "gsettings", "stat"]
    launcher = '#!/usr/bin/env bash\nexec python3 "$VM_TEST_ROOT/backend.py" "${0##*/}" "$@"\n'
    for name in host_commands + guest_commands:
        path = root / "bin" / name
        # Keep host identity and image-size probes real.
        if name in ("id", "stat"):
            text = f'#!/usr/bin/env bash\nif [[ -z ${{VM_TEST_GUEST_USER:-}} ]]; then exec /usr/bin/{name} "$@"; fi\n' + launcher.split("\n", 1)[1]
        else: text = launcher
        path.write_text(text); path.chmod(0o755)
    env = os.environ.copy()
    env.update(VM_TEST_ROOT=str(root), PATH=str(root / "bin") + ":" + env["PATH"], XDG_CACHE_HOME=str(root / "cache"), PROXY="")
    options = ["--ssh-key", str(root / "identity.pub"), "--identity", str(root / "identity")]

    def calls():
        path = root / "calls.jsonl"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def run(name, *arguments, success=True, extra=None, keys=True):
        result = subprocess.run(["bash", script, name, *(options if keys else []), *arguments],
                                env=env | (extra or {}), text=True, capture_output=True, timeout=30)
        assert (result.returncode == 0) == success, (name, result.returncode, result.stdout, result.stderr)
        return result

    # Invalid settings stop before host control or downloads are invoked.
    for args in [("../bad",), ("bad", "--user", "root"), ("bad", "--cpus", "1+1"),
                 ("bad", "--ram", "0"), ("bad", "--disk", "20"), ("bad", "--unknown")]:
        run(*args, success=False, keys=False)
    assert not calls()
    before = len(calls())
    run("mismatch", "--identity", str(root / "image.img"), success=False)
    assert len(calls()) == before, "bad key reached host operations"
    (root / "invalid.pub").write_text((root / "identity.pub").read_text() + "ssh-ed25519 AAAA\n")
    run("invalid-key", "--ssh-key", str(root / "invalid.pub"), success=False)
    assert len(calls()) == before, "invalid extra key reached host operations"
    subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", secrets.token_hex(16), "-f", str(root / "encrypted")], check=True)
    run("encrypted", "--ssh-key", str(root / "encrypted.pub"), "--identity", str(root / "encrypted"),
        success=False, extra={"SSH_AUTH_SOCK": str(root / "no-agent")})
    assert len(calls()) == before, "locked identity reached host operations"

    # Partial bytes are tied to the immutable image checksum and resumed.
    run("interrupted", success=False, extra={"VM_TEST_INTERRUPT": "1"})
    partial = root / "cache" / "vm-create" / (digest + ".img.part")
    assert partial.exists()
    result = run("basic")
    assert "VM ready: basic" in result.stdout
    assert not partial.exists()
    data = (root / "user-data").read_text()
    public = " ".join((root / "identity.pub").read_text().split()[:2])
    assert data.count(public) == 2, "public key not installed for both accounts"
    assert "PRIVATE KEY" not in data
    assert "lock_passwd: true" in data and "ssh_pwauth: false" in data
    assert "package_upgrade: false" in data
    assert '"192.168.123.1"' in data
    info = json.loads(subprocess.check_output(["qemu-img", "info", "--output=json", str(root / "volumes" / "basic.qcow2")]))
    assert info["virtual-size"] == 20 * 1024**3 and "backing-filename" not in info
    install = next(c for c in calls() if c[0] == "virt-install" and "--name" in c)
    assert install[install.index("--memory") + 1] == "2048"
    assert install[install.index("--vcpus") + 1] == "2"
    assert install[install.index("--osinfo") + 1] == "ubuntu24.04"
    assert not any("-tt" in c for c in calls() if c[0] == "ssh")
    assert not json.loads((root / "state.json").read_text())["autostart"]
    assert install[install.index("--graphics") + 1] == "none"
    assert "ubuntu-desktop-minimal" not in data and "AutomaticLogin" not in data
    downloads = sum(c[0] == "curl" for c in calls())

    # Reuse verifies both caches, without another network request.
    run("custom", "--user", "tester", "--cpus", "3", "--ram", "3072", "--disk", "1G", "--upgrade", "--autostart", "--ssh")
    assert sum(c[0] == "curl" for c in calls()) == downloads

    assert "package_upgrade: true" in (root / "user-data").read_text()
    assert "name: tester" in (root / "user-data").read_text()
    assert json.loads((root / "state.json").read_text())["autostart"] == ["custom"]
    assert any("-tt" in c for c in calls() if c[0] == "ssh")

    # NetworkManager can obtain a new lease at the final boot while libvirt
    # still reports the old one. SSH retries must rediscover the live address.
    result = run("new-address", "--desktop", extra={"VM_TEST_ADDRESS_CHANGE": "1"})
    assert "IP: 192.168.123.3" in result.stdout

    # Desktop mode shares SSH provisioning, verifies a real user session before
    # invoking a viewer, and applies defaults only to unspecified resources.
    before = len(calls())
    result = run("desktop", "--desktop")
    desktop_calls = calls()[before:]
    install = next(c for c in desktop_calls if c[0] == "virt-install" and "--name" in c)
    assert install[install.index("--memory") + 1] == "4096"
    assert install[install.index("--vcpus") + 1] == "4"
    assert install[install.index("--graphics") + 1] == "spice,listen=none"
    assert install[install.index("--video") + 1] == "virtio"
    info = json.loads(subprocess.check_output(["qemu-img", "info", "--output=json", str(root / "volumes" / "desktop.qcow2")]))
    assert info["virtual-size"] == 40 * 1024**3
    data = (root / "user-data").read_text()
    assert "ubuntu-desktop-minimal, spice-vdagent" in data
    assert "AutomaticLogin=" + subprocess.check_output(["/usr/bin/id", "-un"], text=True).strip() in data
    assert "gnome-initial-setup-done" in data
    assert data.count(public) == 2 and data.count("lock_passwd: true") == 2
    assert "Open the GNOME desktop" in result.stdout
    assert any(c[0] == "gdbus" and "org.gnome.Shell" in c for c in desktop_calls)
    assert not any(c[0] in ("virt-viewer", "virt-manager") for c in desktop_calls)

    before = len(calls())
    run("desktop-custom", "--cpus", "3", "--view", "--ram", "3072", "--disk", "1G",
        extra={"DISPLAY": ":99"})
    desktop_calls = calls()[before:]
    install = next(c for c in desktop_calls if c[0] == "virt-install" and "--name" in c)
    assert install[install.index("--vcpus") + 1] == "3"
    assert install[install.index("--memory") + 1] == "3072"
    assert desktop_calls[-1] == ["virt-viewer", "--connect", "qemu:///system", "desktop-custom"]
    assert sum(c[0] == "curl" for c in calls()) == downloads

    # The distro bootstrap already supplies virt-manager, so --view can use it
    # without requiring another host package.
    (root / "bin" / "virt-viewer").unlink()
    before = len(calls())
    run("desktop-fallback", "--view", extra={"DISPLAY": ":99"})
    assert calls()[-1] == ["virt-manager", "--connect", "qemu:///system", "--show-domain-console", "desktop-fallback"]
    before = len(calls())
    run("headless-view", "--view", success=False, extra={"DISPLAY": "", "WAYLAND_DISPLAY": ""})
    assert len(calls()) == before, "missing graphical host session reached host operations"
    before = len(calls())
    result = run("desktop-locked", "--view", "--timeout", "5", success=False,
                 extra={"DISPLAY": ":99", "VM_TEST_LOCKED_DESKTOP": "1"})
    assert "unlocked GNOME" in result.stderr, (result.stdout, result.stderr)
    assert (root / "volumes" / "desktop-locked.qcow2").exists()
    assert not any(c[0] in ("virt-viewer", "virt-manager") for c in calls()[before:])

    # Existing domains/disks and failed first boot never cause replacement.
    before = len(calls())
    run("basic", success=False)
    assert not any(c[0] == "virt-install" and "--name" in c for c in calls()[before:])
    (root / "volumes" / "occupied.qcow2").write_text("operator-owned")
    run("occupied", success=False)
    assert (root / "volumes" / "occupied.qcow2").read_text() == "operator-owned"
    run("orphan", success=False, extra={"VM_TEST_RESIZE_FAIL": "1"})
    assert not (root / "volumes" / "orphan.qcow2").exists()
    run("predefine", success=False, extra={"VM_TEST_INSTALL_FAIL": "before"})
    assert not (root / "volumes" / "predefine.qcow2").exists()
    run("defined", success=False, extra={"VM_TEST_INSTALL_FAIL": "after"})
    assert (root / "volumes" / "defined.qcow2").exists()
    run("cloud-failed", success=False, extra={"VM_TEST_CLOUD_FAIL": "1"})
    assert (root / "volumes" / "cloud-failed.qcow2").exists()
    result = run("firewall-failed", success=False, extra={"VM_TEST_BAD_FIREWALL": "1"})
    assert "firewall verification failed" in result.stderr
    assert (root / "volumes" / "firewall-failed.qcow2").exists()
    run("no-lease", "--timeout", "1", success=False, extra={"VM_TEST_NO_LEASE": "1"})
    assert (root / "volumes" / "no-lease.qcow2").exists()
    run("old-osinfo", extra={"VM_TEST_OLD_OSINFO": "1"})
    install = next(c for c in calls() if c[0] == "virt-install" and "old-osinfo" in c)
    assert install[install.index("--osinfo") + 1] == "generic"

    # A corrupted daemon-side base is rejected even if the user cache is good.
    base = next(p for p in (root / "volumes").iterdir() if p.name.endswith(".img"))
    original = base.read_bytes(); base.write_bytes(b"corrupted base")
    run("bad-base", success=False)
    assert not (root / "volumes" / "bad-base.qcow2").exists()
    base.write_bytes(original)
    cached = root / "cache" / "vm-create" / (digest + ".img")
    cached.unlink()
    run("bad-download", success=False, extra={"VM_TEST_CORRUPT": "1"})
    assert not partial.exists() and not cached.exists()
    # Failed upload removes only the new incomplete base.
    base.unlink()
    run("bad-upload", success=False, extra={"VM_TEST_UPLOAD_FAIL": "1"})
    assert not base.exists()
    assert (root / "volumes" / "basic.qcow2").exists()
    print("vm-create public-interface tests passed")
PY
