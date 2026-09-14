#!/usr/bin/env bash
set -euo pipefail
umask 077
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
: "${VPN_TEST_LAUNCHER:?Set VPN_TEST_LAUNCHER to the built vpn executable}"
: "${XDG_RUNTIME_DIR:?A running user systemd session is required}"
sing_box=$(command -v sing-box)
[[ $EUID != 0 && -O $XDG_RUNTIME_DIR ]]
unit=${XDG_RUNTIME_DIR}/systemd/user/vpn-capture.service
[[ ! -e $unit && ! -d ${XDG_RUNTIME_DIR}/vpn-capture ]]
[[ $(systemctl --user show -p LoadState --value vpn-capture.service) == not-found ]]
probe=$(mktemp -d "${XDG_RUNTIME_DIR}/dotfiles-vpn-scope.XXXXXXXX")
backend='' fixture=''
cleanup() {
  if [[ -f $probe/backend.log ]]; then tail -n 5 "$probe/backend.log"; fi
  systemctl --user stop vpn-capture.service || true
  systemctl --user reset-failed vpn-capture.service 2>/dev/null || true
  rm -f -- "$unit"
  systemctl --user daemon-reload
  for pid in "$backend" "$fixture"; do
    if [[ -n $pid ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
  done
  rm -rf -- "$probe"
}
trap cleanup EXIT
mkdir "$probe/config"
printf '{"dns":{"servers":[{"type":"udp","tag":"tunnel-dns-0","server":"1.1.1.1"}]}}' > "$probe/backend.json"
bash "$repo/modules/programs/vpnized-apps/capture-config.sh" "$probe/backend.json" "$probe/config"
jq --arg runtime "$XDG_RUNTIME_DIR" '.network_namespaces[0].pid_file=($runtime + "/vpn-capture/namespace.pid") | .outbounds[0].server_port=15480' "$probe/config/config.json" > "$probe/capture.json"
printf '{"log":{"level":"warn"},"inbounds":[{"type":"mixed","listen":"127.0.0.1","listen_port":15480}],"outbounds":[{"type":"direct","tag":"echo"}],"route":{"rules":[{"action":"route","outbound":"echo","override_address":"127.0.0.1","override_port":18453}]}}' > "$probe/echo-backend.json"
sing-box check -c "$probe/echo-backend.json"
sing-box run -c "$probe/echo-backend.json" > "$probe/backend.log" 2>&1 &
backend=$!
python3 "$repo/tests/manual/vpn_echo_fixture.py" &
fixture=$!
mkdir -p "${XDG_RUNTIME_DIR}/systemd/user"
printf '[Unit]\nDescription=Temporary VPN capture lifecycle probe\nStopWhenUnneeded=true\n[Service]\nRuntimeDirectory=vpn-capture\nRuntimeDirectoryMode=0700\nNoNewPrivileges=true\nExecStart=%s run -c %s/capture.json\n' "$sing_box" "$probe" > "$unit"
systemctl --user daemon-reload
vpn=$VPN_TEST_LAUNCHER
"$vpn" /bin/sleep 15 &
keeper=$!
sleep 1
kill -0 "$backend" "$fixture"
"$vpn" timeout 5 "$(command -v python3)" "$repo/tests/manual/vpn_echo_client.py"
systemctl --user is-active --quiet vpn-capture.service
echo 'PASS: second application exit leaves first capture alive'
payload_env=$("$vpn" env)
grep -qxF "PATH=$PATH" <<<"$payload_env" || { echo 'FAIL: payload PATH differs from the caller'; exit 1; }
if grep -Eq '^VPN_(USER_PATH|ENTER|SYSTEMD_RUN)=' <<<"$payload_env"; then echo 'FAIL: launcher variables leaked into payload'; exit 1; fi
echo 'PASS: payload keeps the caller PATH without launcher variables'
kill "$backend"
wait "$backend" || true
backend=
if "$vpn" "$(command -v python3)" "$repo/tests/manual/vpn_echo_client.py" >/dev/null 2>&1; then
  echo 'FAIL: traffic succeeded with no backend'; exit 1
fi
echo 'PASS: capture fails closed with backend stopped'
sing-box run -c "$probe/echo-backend.json" > "$probe/backend.log" 2>&1 &
backend=$!
sleep 0.2
"$vpn" "$(command -v python3)" "$repo/tests/manual/vpn_echo_client.py"
echo 'PASS: same capture recovers after backend restart'
wait "$keeper"
for ((n=0;n<30;n++)); do
  [[ -d ${XDG_RUNTIME_DIR}/vpn-capture ]] || break
  sleep 0.1
done
if systemctl --user is-active --quiet vpn-capture.service; then
  echo 'FAIL: capture remained active after last application'; exit 1
fi
[[ ! -d ${XDG_RUNTIME_DIR}/vpn-capture ]]
echo 'PASS: last application exit stops capture and removes runtime namespace'
"$vpn" /bin/sleep 30 &
victim=$!
sleep 1
systemctl --user kill --signal=KILL vpn-capture.service
for ((n=0;n<50;n++)); do
  kill -0 "$victim" 2>/dev/null || break
  sleep 0.1
done
if kill -0 "$victim" 2>/dev/null; then
  echo 'FAIL: application survived capture failure'; exit 1
fi
if wait "$victim"; then
  echo 'FAIL: killed application returned success'; exit 1
fi
echo 'PASS: capture failure terminates dependent application'
