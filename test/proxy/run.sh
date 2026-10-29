#!/usr/bin/env bash
# Proxy tests: serve the app under a path behind NGINX, and check that the
# page and the assets it links to load through the proxy (#38).
#
# Usage: test/proxy/run.sh IMAGE
#
# Scenarios:
#   P1  The proxy strips /hello/, and no prefix is set (#38).
#   P2  The proxy passes /hello/ through, and both prefixes are /hello.
#   P3  The proxy strips /hello/, and both prefixes are only "/".
#
# Each scenario prints PASS or FAIL. The script exits 1 if any fails.
# Needs docker, curl and node (to resolve URLs the way a browser does).

set -euo pipefail

image="${1:?usage: $0 IMAGE}"
nginx_image="nginx:1.30.5-alpine@sha256:0985e772fb9f729e6fa0980da05fca5d9c468e870eed43071545afa9d2e27d94"
id="hk-proxy-$$"
network="$id"
port="${PROXY_TEST_PORT:-18090}"
workdir=$(mktemp -d)
failures=0

cleanup() {
  docker rm -f "$id-app" "$id-nginx" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
  rm -rf "$workdir"
}
trap cleanup EXIT

docker network create "$network" >/dev/null

# Starts the app and an NGINX proxy in front of it.
# start SCENARIO UPSTREAM_PATH [docker run env args...]
#   UPSTREAM_PATH "/" strips /hello/; "/hello/" passes it through.
start() {
  local upstream_path="$1"
  shift
  docker rm -f "$id-app" "$id-nginx" >/dev/null 2>&1 || true
  docker run -d --pull never --name "$id-app" --network "$network" "$@" "$image" >/dev/null
  cat >"$workdir/default.conf" <<EOF
server {
  listen 80;
  location /hello/ {
    proxy_pass http://$id-app:8080$upstream_path;
  }
}
EOF
  docker run -d --name "$id-nginx" --network "$network" -p "127.0.0.1:$port:80" \
    -v "$workdir/default.conf:/etc/nginx/conf.d/default.conf:ro" "$nginx_image" >/dev/null
  for _ in $(seq 1 40); do
    curl -fs -o /dev/null "http://127.0.0.1:$port/hello/" && return 0
    sleep 0.25
  done
  return 1
}

# Fetches the page at /hello/, resolves each stylesheet and image URL the way a
# browser does, and checks that each one loads through the proxy.
# check SCENARIO DESCRIPTION
check() {
  local name="$1" description="$2" page="http://127.0.0.1:$port/hello/"
  local html urls url status problems=()
  if ! html=$(curl -fsS "$page"); then
    echo "FAIL $name: $description: the page did not load"
    failures=$((failures + 1))
    return
  fi
  urls=$(grep -oE '(href|src)="[^"]+"' <<<"$html" | sed -E 's/^(href|src)="//; s/"$//' | grep -vE '^https?:' || true)
  if [[ -z "$urls" ]]; then
    problems+=("no asset URLs found in the page")
  fi
  for url in $urls; do
    if [[ "$url" == //* ]]; then
      problems+=("$url points to another host")
      continue
    fi
    # Resolve the URL against the page URL, like a browser.
    resolved=$(node -e 'console.log(new URL(process.argv[1], process.argv[2]).href)' "$url" "$page")
    status=$(curl -s -o /dev/null -w '%{http_code}' "$resolved")
    [[ "$status" == 200 ]] || problems+=("$url -> $resolved returned $status")
  done
  if ((${#problems[@]} == 0)); then
    echo "PASS $name: $description ($(echo $urls | tr ' ' ','))"
  else
    echo "FAIL $name: $description: ${problems[*]}"
    failures=$((failures + 1))
  fi
}

start / && check P1 "path stripped, no prefix" ||
  { echo "FAIL P1: the proxy did not start"; failures=$((failures + 1)); }

start /hello/ -e RENDER_PATH_PREFIX=/hello -e HANDLER_PATH_PREFIX=/hello && check P2 "path passed through, prefixes /hello" ||
  { echo "FAIL P2: the proxy did not start"; failures=$((failures + 1)); }

start / -e RENDER_PATH_PREFIX=/ -e HANDLER_PATH_PREFIX=/ && check P3 "path stripped, prefixes only /" ||
  { echo "FAIL P3: the proxy did not start"; failures=$((failures + 1)); }

if ((failures > 0)); then
  echo "$failures proxy test(s) failed"
  exit 1
fi
echo "All proxy tests passed"
