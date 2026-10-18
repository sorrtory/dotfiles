// Real Obsidian on a headless display, with synthetic notes on real gocryptfs.
// Needs Node (built-in WebSocket), Xvfb, script(1), and VAULT_TEST_COMMAND.
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, readdirSync, rmSync, openSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { createServer } from 'node:net';

process.umask(0o077);
const vault = process.env.VAULT_TEST_COMMAND;
assert(vault, 'Set VAULT_TEST_COMMAND to the built vault executable');
const root = mkdtempSync(join(tmpdir(), 'vault-notes-test-'));
const mount = join(root, 'Vault');
const profile = join(mount, '.obsidian-profile');
const ordinary = join(root, 'ordinary-profile');
const knowledge = join(root, 'Knowledge-Database');
const ordinaryId = '1111111111111111';
const runtime = join(root, 'runtime');
const bin = join(root, 'bin');
const home = join(root, 'home');
for (const dir of [ordinary, knowledge, runtime, bin, home]) mkdirSync(dir, { mode: 0o700 });
const log = openSync(join(root, 'test.log'), 'a');
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const quote = text => `'${text.replaceAll("'", "'\\''")}'`;
const executable = name => {
  const result = spawnSync('sh', ['-c', 'command -v "$1"', 'sh', name], { encoding: 'utf8' });
  assert.equal(result.status, 0, `${name} must be on PATH`);
  return result.stdout.trim();
};
const obsidian = executable('obsidian');
const xvfbCommand = executable('Xvfb');
const freePort = () => new Promise(resolve => {
  const server = createServer();
  server.listen(0, '127.0.0.1', () => {
    const port = server.address().port;
    server.close(() => resolve(port));
  });
});
const ordinaryPort = await freePort();
const privatePort = await freePort();
let xvfb, ordinaryProcess, env;

async function until(check, message) {
  for (let attempt = 0; attempt < 100; attempt++) {
    try { if (await check()) return; } catch {}
    await sleep(100);
  }
  throw new Error(message);
}

async function evaluate(port, expression) {
  const pages = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
  const page = pages.find(page => page.type === 'page' && page.url.endsWith('/index.html'));
  assert(page, 'Obsidian must have a vault window');
  const socket = new WebSocket(page.webSocketDebuggerUrl);
  return await new Promise((resolve, reject) => {
    const timer = setTimeout(() => { socket.close(); reject(new Error('CDP timed out')); }, 3000);
    socket.onopen = () => socket.send(JSON.stringify({
      id: 1, method: 'Runtime.evaluate', params: { expression, returnByValue: true, awaitPromise: true },
    }));
    socket.onerror = error => { clearTimeout(timer); reject(error); };
    socket.onmessage = event => {
      const reply = JSON.parse(event.data);
      if (reply.id !== 1) return;
      clearTimeout(timer);
      socket.close();
      if (reply.error || reply.result.exceptionDetails) reject(new Error(`${expression}: ${JSON.stringify(reply)}`));
      else resolve(reply.result.result.value);
    };
  });
}

const ready = (port, name) => until(
  async () => await evaluate(port, 'globalThis.app?.workspace?.layoutReady && app.vault.getName()') === name,
  `${name} did not open`,
);
function run(command, args, overrides = {}, options = {}) {
  const result = spawnSync(command, args, {
    env: { ...env, ...overrides }, cwd: root, encoding: 'utf8', timeout: 20000, ...options,
  });
  assert.equal(result.status, 0, `${command} ${args.join(' ')} (${result.signal || result.error || ''}): ${result.stderr || result.stdout}`);
  return result;
}
const headless = { DISPLAY: '', WAYLAND_DISPLAY: '' };
const notesPids = () => readdirSync('/proc').filter(pid => {
  if (!/^\d+$/.test(pid)) return false;
  try {
    const title = readFileSync(`/proc/${pid}/comm`, 'utf8');
    if (!/electron|obsidian/i.test(title)) return false;
    const titleArgs = readFileSync(`/proc/${pid}/cmdline`, 'utf8').replaceAll('\0', ' ');
    return ` ${titleArgs} `.includes(` --user-data-dir=${profile} `);
  } catch { return false; }
});

try {
  xvfb = spawn(xvfbCommand, ['-displayfd', '3', '-screen', '0', '1024x768x24', '-nolisten', 'tcp'], {
    stdio: ['ignore', log, log, 'pipe'],
  });
  const display = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Xvfb did not start')), 5000);
    xvfb.stdio[3].once('data', data => { clearTimeout(timer); resolve(`:${data.toString().trim()}`); });
    xvfb.once('error', reject);
  });
  env = {
    ...process.env, HOME: home, XDG_CONFIG_HOME: join(home, '.config'),
    XDG_CACHE_HOME: join(home, '.cache'), XDG_DATA_HOME: join(home, '.local/share'),
    XDG_RUNTIME_DIR: runtime, DISPLAY: display, WAYLAND_DISPLAY: '', VAULT_DESKTOP_ENTRY: '',
    VAULT_ASKPASS: join(bin, 'askpass'), PATH: `${bin}:${process.env.PATH}`,
  };
  // Keep every application and notification on the disposable display/profile.
  writeFileSync(join(bin, 'askpass'), '#!/bin/sh\nprintf "fixture-password\\n"\n', { mode: 0o700 });
  writeFileSync(join(bin, 'notify-send'), '#!/bin/sh\nexit 0\n', { mode: 0o700 });
  writeFileSync(join(bin, 'zenity'), '#!/bin/sh\nexit 1\n', { mode: 0o700 });
  writeFileSync(join(bin, 'obsidian'),
    `#!/bin/sh\nexec ${quote(obsidian)} --ozone-platform=x11 --disable-gpu --remote-debugging-port=${privatePort} "$@"\n`,
    { mode: 0o700 });
  writeFileSync(join(ordinary, 'obsidian.json'), JSON.stringify({
    updateDisabled: true, vaults: { [ordinaryId]: { path: knowledge, open: true } },
  }));
  ordinaryProcess = spawn(obsidian, [
    '--ozone-platform=x11', '--disable-gpu', `--remote-debugging-port=${ordinaryPort}`,
    `--user-data-dir=${ordinary}`, `obsidian://open?vault=${ordinaryId}`,
  ], { env, stdio: ['ignore', log, log], detached: true });
  await ready(ordinaryPort, 'Knowledge-Database');

  run('script', ['-qec', `${quote(resolve(vault))} init`, '/dev/null'], {}, {
    input: 'fixture-password\nfixture-password\n',
  });
  // Keep this check on the installed package across restarts, rather than an
  // auto-downloaded app update. No settings from the operator are copied.
  run(vault, ['notes', mount], headless);
  const registry = join(profile, 'obsidian.json');
  writeFileSync(registry, JSON.stringify({ ...JSON.parse(readFileSync(registry, 'utf8')), updateDisabled: true }));
  run(vault, ['notes', mount]);
  await ready(privatePort, 'Notes');
  assert.equal(await evaluate(privatePort, "require('@electron/remote').app.getPath('userData')"), profile);
  assert.equal(await evaluate(ordinaryPort, "require('@electron/remote').app.getPath('userData')"), ordinary);
  await evaluate(privatePort, 'app.vault.create("private-fixture.md", "encrypted fixture").then(() => true)');
  assert.equal(readFileSync(join(mount, 'Notes/private-fixture.md'), 'utf8'), 'encrypted fixture');
  assert.equal(readFileSync(join(ordinary, 'obsidian.json'), 'utf8').includes(mount), false);
  const appPid = await evaluate(privatePort, "require('@electron/remote').process.pid");

  // Repeat launch routing must work in both directions, with one Notes window.
  run(vault, ['notes', mount]);
  await ready(privatePort, 'Notes');
  assert.equal(await evaluate(privatePort, "require('@electron/remote').process.pid"), appPid);
  assert.equal(await evaluate(privatePort, "require('@electron/remote').BrowserWindow.getAllWindows().length"), 1);
  run(obsidian, ['--ozone-platform=x11', '--disable-gpu', `--user-data-dir=${ordinary}`, `obsidian://open?vault=${ordinaryId}`]);
  await ready(ordinaryPort, 'Knowledge-Database');
  assert.equal(await evaluate(privatePort, "require('@electron/remote').BrowserWindow.getAllWindows().length"), 1);

  // Even if it happens to hold no descriptor, Notes must block a normal lock.
  const blocked = spawnSync(vault, ['lock', mount], { env: { ...env, ...headless }, encoding: 'utf8', timeout: 20000 });
  assert.equal(blocked.status, 1);
  assert.match(blocked.stdout, /still unlocked/);
  await ready(privatePort, 'Notes');

  // A normal window close saves state and allows an ordinary lock.
  await evaluate(privatePort, 'setTimeout(() => window.close(), 50); true');
  await until(() => notesPids().length === 0, 'Notes did not exit after closing its window');
  run(vault, ['lock', mount], headless);
  assert.deepEqual(readdirSync(mount), []);
  run(vault, ['notes', mount]);
  await ready(privatePort, 'Notes');
  assert.equal(await evaluate(privatePort, 'app.vault.read(app.vault.getAbstractFileByPath("private-fixture.md"))'), 'encrypted fixture');

  // Forced locking stops only the private process before exposing the mount dir.
  run(vault, ['lock', '--force', mount], headless);
  assert.deepEqual(notesPids(), []);
  await sleep(500);
  assert.deepEqual(readdirSync(mount), [], 'An app wrote plaintext after unmounting');
  await ready(ordinaryPort, 'Knowledge-Database');
  assert.equal(readFileSync(join(ordinary, 'obsidian.json'), 'utf8').includes(mount), false);
  console.log('PASS: private registration, repeat launches, profile isolation, reopen, normal and forced locking');
} catch (error) {
  console.error(readFileSync(join(root, 'test.log'), 'utf8').slice(-4000));
  throw error;
} finally {
  if (env) spawnSync(vault, ['lock', '--force', mount], { env: { ...env, ...headless }, stdio: 'ignore', timeout: 15000 });
  if (ordinaryProcess) {
    try { process.kill(-ordinaryProcess.pid, 'SIGTERM'); } catch {}
  }
  if (xvfb) xvfb.kill();
  // Refuse to traverse a mount if a failed test could not clean it up.
  const mounts = readFileSync('/proc/self/mountinfo', 'utf8');
  if (mounts.includes(` ${mount} `)) console.error(`Test mount still present: ${mount}; artifacts retained at ${root}`);
  else rmSync(root, { recursive: true, force: true });
}
