#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: mirror-website [OPTIONS] URL [-- WGET_OPTIONS...]

Save linked pages and their assets as ordinary files with local links.

  --to DIR          Output root (default: ./mirror; keeps host directories)
  --domains LIST    Also crawl these comma-separated domains and subdomains
  --depth N         Maximum link depth; 0 means unlimited (the default)
  --page            Save just this page, with assets from any host
  --dry-run         Print the command without downloading
  -h, --help        Show this help

  mirror-website https://example.com/
  mirror-website --domains cdn.example.net https://example.com/
  mirror-website --to ./reading --page https://example.com/article
  mirror-website --depth 2 URL -- --load-cookies cookies.txt
  mirror-website URL -- --no-parent
  mirror-website URL -- --wait=3
  mirror-website URL -- --wait=3 --limit-rate=2m
  mirror-website URL -- -e robots=on

A mirror follows the starting host only unless --domains is given. Extra
domains allow pages as well as assets; unrestricted --span-hosts after --
can follow links far beyond the original site. Start at the site's root to
discover its linked pages. Use --no-parent to stay below a URL's directory.

Re-running updates the same mirror using server timestamps and keeps files
that disappeared online. Open a saved index.html in your browser. Links to
pages that weren't downloaded still lead online.

JavaScript isn't executed: lazy-loaded content and streaming media may need
a browser crawler or a media downloader. TLS verification stays enabled.
Robots rules are ignored by default; use -- -e robots=on to respect them.
Wget options after -- override defaults.

Downloads are sequential. Default pacing is --wait=1 --random-wait:
roughly 0.5-1.5 seconds between retrievals, plus download time. For a large
crawl or a small site, use --wait=3 to --wait=5. --wait=3 gives roughly
1.5-4.5 seconds between retrievals. --limit-rate=2m caps bandwidth at about
2 MiB/s; it does not replace request pacing. --wait=0 removes the delay.

HTTP 429 (Too Many Requests) isn't automatically retried. If it appears,
stop the crawl and rerun with a longer wait after the server's requested
cooldown. --waitretry raises the ceiling of linear retry backoff, not the
initial retry delay. Each URL has at most three attempts.

Like download, this command uses $PROXY when set. PROXY= runs direct;
otherwise standard Wget proxy settings apply when PROXY is unset.
USAGE
}

die() {
  printf 'mirror-website: %s\n' "$1" >&2
  exit 1
}

destination=./mirror
domains=''
depth=0
page=0
dry_run=0
url=''
wget_options=()
while (($#)); do
  case $1 in
  -h | --help) usage; exit 0 ;;
  --page) page=1; shift ;;
  --dry-run) dry_run=1; shift ;;
  --to | --domains | --depth)
    [[ $# -ge 2 && -n $2 && $2 != -* ]] || die "$1 needs a value"
    case $1 in
    --to) destination=$2 ;;
    --domains) domains=$2 ;;
    --depth) depth=$2 ;;
    esac
    shift 2
    ;;
  --to=*) destination=${1#*=}; shift ;;
  --domains=*) domains=${1#*=}; [[ -n $domains ]] || die '--domains needs a value'; shift ;;
  --depth=*) depth=${1#*=}; shift ;;
  --) shift; wget_options=("$@"); break ;;
  -*) die "unknown option '$1'; put Wget options after --" ;;
  *) [[ -z $url ]] || die 'give exactly one URL'; url=$1; shift ;;
  esac
done

[[ -n $destination ]] || die '--to needs a directory'
[[ $depth =~ ^[0-9]+$ ]] || die '--depth must be a non-negative integer'
[[ $url =~ ^https?://[^/?#[:space:]]+ ]] || die 'give an http:// or https:// URL'
if ((page)); then
  [[ -z $domains && $depth == 0 ]] || die '--page cannot be combined with --domains or --depth'
fi

# Wget's domain list must retain the seed host, even when the operator only
# lists an external CDN. Ports and URL paths aren't part of a domain filter.
authority=${url#*://}
authority=${authority%%[/?#]*}
authority=${authority##*@}
if [[ $authority == \[* ]]; then
  host=${authority%%]*}]
else
  host=${authority%%:*}
fi
[[ -n $host ]] || die 'URL needs a host'

args=(
  -e robots=off
  --page-requisites --convert-links --adjust-extension --backup-converted
  --force-directories --wait=1 --random-wait --timeout=30 --tries=3
  "--directory-prefix=$destination"
)
if ((page)); then
  # Without recursion, host spanning fetches requisites, not ordinary links.
  args+=(--span-hosts)
else
  args+=(--mirror "--level=$depth")
  if [[ -n $domains ]]; then
    [[ $domains != *[[:space:]/:@?#]* && $domains != ,* && $domains != *, && $domains != *,,* ]] ||
      die '--domains expects comma-separated domain names, without URLs or ports'
    args+=(--span-hosts "--domains=${host,,},${domains,,}")
  fi
fi

# Scope the proxy to Wget, matching the download command. An explicitly empty
# PROXY defeats both inherited proxy variables and a proxy in ~/.wgetrc.
if [[ ${PROXY+x} ]]; then
  if [[ -n $PROXY ]]; then
    args+=(-e use_proxy=on -e "http_proxy=$PROXY" -e "https_proxy=$PROXY")
  else
    args+=(--no-proxy)
  fi
fi
args+=("${wget_options[@]}" -- "$url")

if ((dry_run)); then
  printf 'wget'
  printf ' %q' "${args[@]}"
  printf '\n'
  exit 0
fi

exec wget "${args[@]}"
