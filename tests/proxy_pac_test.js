// Run locally; keep the private PAC in the pipe, out of files and the Nix store:
// sops --decrypt --input-type binary --output-type binary secrets/proxy.pac \
//   | node tests/proxy_pac_test.js
// Failures deliberately omit PAC source, stack traces, and private hostnames.
const { readFileSync } = require("node:fs");
const vm = require("node:vm");

const proxy = "PROXY 127.0.0.1:1080";
const blocked = "PROXY 0.0.0.0:0";
let currentCheck = "load PAC from stdin";
let assertions = 0;

function expect(actual, expected, description) {
  currentCheck = description;
  if (actual !== expected) throw new Error("check failed");
  assertions++;
}

try {
  const source = readFileSync(0, "utf8");
  if (!source.trim()) throw new Error("empty PAC");
  const script = new vm.Script(source, { filename: "private-proxy.pac" });

  function browser() {
    let timestamp = 0;
    class ClockDate extends Date {
      constructor(...args) {
        super(...(args.length ? args : [timestamp]));
      }
      static now() {
        return timestamp;
      }
    }

    const context = vm.createContext({
      Date: ClockDate,
      dnsDomainIs: (host, domain) => host.endsWith(domain),
    });
    script.runInContext(context, { timeout: 1000 });

    return (at, host = "www.youtube.com") => {
      currentCheck = "evaluate PAC routing decision";
      timestamp = Date.parse(at);
      if (!Number.isFinite(timestamp)) throw new Error("invalid test date");
      context.requestHost = host;
      context.requestUrl = `https://${host}/`;
      return vm.runInContext("FindProxyForURL(requestUrl, requestHost)", context, {
        timeout: 1000,
      });
    };
  }

  let route = browser();
  expect(route("2026-10-14T14:29:59.999"), blocked, "no start before :30");
  expect(route("2026-10-14T14:30:00"), proxy, "start exactly at :30");
  expect(route("2026-10-14T14:39:59.999"), proxy, "full ten minutes");
  expect(route("2026-10-14T14:40:00"), blocked, "deadline is exclusive");
  expect(route("2026-10-14T14:59:59.999"), blocked, "no second pass that hour");

  route = browser();
  expect(route("2026-10-14T14:57:37.250"), proxy, "start late in the hour");
  expect(route("2026-10-14T15:07:37.249"), proxy, "carry full pass across :00");
  expect(route("2026-10-14T15:07:37.250"), blocked, "late pass expires exactly");
  expect(route("2026-10-14T15:29:59.999"), blocked, "next hour waits until :30");
  expect(route("2026-10-14T15:30:00"), proxy, "new hour can start a new pass");

  route = browser();
  expect(route("2026-10-14T14:30:00", "ordinary.example.invalid"), proxy,
    "ordinary traffic stays proxied");
  expect(route("2026-10-14T14:31:00", "music.youtube.com"), proxy,
    "Music stays available");
  expect(route("2026-10-14T14:45:00"), proxy,
    "ordinary and Music traffic did not start the pass");
  expect(route("2026-10-14T14:54:59.999", "youtube.com"), proxy,
    "apex host shares the original deadline");
  expect(route("2026-10-14T14:55:00", "m.youtube.com"), blocked,
    "switching subdomains cannot extend or restart the pass");
  expect(route("2026-10-14T14:56:00", "music.youtube.com"), proxy,
    "Music remains available after the pass");

  route = browser();
  expect(route("2026-10-14T14:00:00", "notyoutube.com"), proxy,
    "domain suffix must have a label boundary");
  expect(route("2026-10-14T14:00:00", "youtube.com.example.invalid"), proxy,
    "unrelated suffix is not YouTube");
  expect(route("2026-10-14T14:00:00", "MUSIC.YOUTUBE.COM."), proxy,
    "Music exception handles case and trailing dot");
  expect(route("2026-10-14T14:00:00", "WWW.YOUTUBE.COM."), blocked,
    "YouTube restriction handles case and trailing dot");
  expect(route("2026-10-14T14:00:00", "media.googlevideo.com"), proxy,
    "shared media hosts are not newly restricted");
  expect(route("2026-10-14T14:00:00", "i.ytimg.com"), proxy,
    "shared image hosts are not newly restricted");

  route = browser();
  expect(route("2026-10-14T21:00:00"), blocked, "evening starts at 22:00");
  expect(route("2026-10-14T22:00:00"), proxy, "unrestricted from 22:00");
  expect(route("2026-10-14T23:59:59.999"), proxy, "unrestricted before midnight");
  expect(route("2026-10-15T00:00:00"), proxy, "unrestricted across midnight");
  expect(route("2026-10-15T01:59:59.999"), proxy, "unrestricted until 02:00");
  expect(route("2026-10-15T02:00:00"), blocked, "night access ends at 02:00");
  expect(route("2026-10-15T02:30:00"), proxy, "night access did not spend a pass");
  expect(route("2026-10-15T02:40:00"), blocked, "normal rules resume after night");

  route = browser();
  expect(route("2026-10-14T14:30:00"), proxy, "start on first date");
  expect(route("2026-10-14T14:40:00"), blocked, "finish on first date");
  expect(route("2026-10-15T14:30:00"), proxy, "same hour on another date is new");

  route = browser();
  expect(route("2026-10-17T21:00:00"), blocked, "Saturday still uses the schedule");
  expect(route("2026-10-17T22:00:00"), proxy, "Saturday evening is unrestricted");
  for (const time of ["00:00:00", "02:00:00", "14:00:00", "14:30:00",
                      "14:40:00", "14:59:59", "21:59:59", "23:59:59.999"]) {
    expect(route(`2026-10-18T${time}`), proxy, "Sunday is unrestricted all day");
  }
  expect(route("2026-10-19T01:59:59.999"), proxy, "Monday keeps normal night access");
  expect(route("2026-10-19T02:00:00"), blocked, "Sunday bypass ends before Monday daytime");
  expect(route("2026-10-19T02:30:00"), proxy, "Sunday did not spend Monday allowance");
  expect(route("2026-10-19T02:40:00"), blocked, "Monday pass still expires normally");

  console.log(`proxy.pac: ${assertions} routing and schedule checks passed`);
} catch {
  console.error(`proxy.pac: FAIL: ${currentCheck} (private details withheld)`);
  process.exitCode = 1;
}
