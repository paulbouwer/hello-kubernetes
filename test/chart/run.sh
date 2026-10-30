#!/usr/bin/env bash
# Chart tests: render the Helm chart with helm template, and check the
# resources it creates for each way of exposing the app. No cluster needed.
#
# Usage: test/chart/run.sh
#
# Scenarios:
#   C1  Defaults: no Ingress, no HTTPRoute, no path prefix.
#   C2  Ingress, no rewrite: the prefix is the Ingress path, and the app serves under it.
#   C3  Ingress with rewrite: the app serves at /, and renders links with the prefix.
#   C4  HTTPRoute with rewrite: the standard URLRewrite filter strips the prefix.
#   C5  HTTPRoute, no rewrite: no filter.
#   C6  HTTPRoute with no parentRefs: the install fails with a clear message.
#   C7  The old ingress.* names still set the prefix, with a deprecation note.
#   C8  A false rewritePath wins, in the old or the new name.
#   C9  app/hello, /app/hello and /app/hello/ render the same.
#   C10 Values with quotes render valid YAML.
#   C11 The old ingress.pathPrefix does nothing without ingress.configured.
#
# Each scenario prints PASS or FAIL. The script exits 1 if any fails.
# Needs helm.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chart="$here/../../deploy/helm/hello-kubernetes"
failures=0
problems=()

# Renders the chart's resources; NOTES=1 renders the install notes instead.
render() {
  if [[ "${NOTES:-0}" == 1 ]]; then
    helm install t "$chart" --dry-run=client "$@" 2>&1 | sed -n '/^NOTES:/,$p'
  else
    helm template t "$chart" "$@" 2>&1
  fi
}

# has TEXT WHAT, lacks TEXT WHAT: check the last render for TEXT, which can
# span lines.
has() { [[ "$out" == *"$1"* ]] || problems+=("missing $2: $1"); }
lacks() { [[ "$out" != *"$1"* ]] || problems+=("unexpected $2: $1"); }

result() {
  if ((${#problems[@]} == 0)); then
    echo "PASS $1"
  else
    echo "FAIL $1"
    printf '    %s\n' "${problems[@]}"
    failures=$((failures + 1))
  fi
  problems=()
}

out=$(render)
lacks "kind: Ingress" "Ingress"
lacks "kind: HTTPRoute" "HTTPRoute"
lacks "PATH_PREFIX" "prefix variable"
has 'path: "/"' "probe path"
result "C1 defaults: no Ingress, no HTTPRoute, no prefix"

out=$(render --set ingress.enabled=true --set ingress.className=traefik --set ingress.host=hello.example \
  --set 'ingress.tls[0].secretName=hello-tls' --set 'ingress.annotations.example\.com/a=b' \
  --set pathPrefix=/app/hello --set rewritePath=false)
has "apiVersion: networking.k8s.io/v1" "Ingress API version"
has "kind: Ingress" "Ingress"
has 'ingressClassName: "traefik"' "class"
has 'host: "hello.example"' "host"
has "secretName: hello-tls" "TLS"
has "example.com/a: b" "annotation"
has '- path: "/app/hello"' "Ingress path"
has "pathType: Prefix" "path type"
has $'- name: HANDLER_PATH_PREFIX\n            value: "/app/hello"' "handler prefix"
has $'- name: RENDER_PATH_PREFIX\n            value: "/app/hello"' "render prefix"
has 'path: "/app/hello/"' "probe path under the prefix"
lacks "kind: HTTPRoute" "HTTPRoute"
result "C2 Ingress, no rewrite"

out=$(render --set ingress.enabled=true --set pathPrefix=/app/hello)
has '- path: "/app/hello"' "Ingress path"
has $'- name: HANDLER_PATH_PREFIX\n            value: ""' "empty handler prefix"
has $'- name: RENDER_PATH_PREFIX\n            value: "/app/hello"' "render prefix"
has 'path: "/"' "probe path"
lacks "ingressClassName" "class"
lacks "host:" "host"
out=$(NOTES=1 render --set ingress.enabled=true --set pathPrefix=/app/hello)
has "Add your" "note about the rewrite annotation"
has "Set service.type=ClusterIP" "note about the service type"
result "C3 Ingress with rewrite"

out=$(render --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gw' \
  --set 'httpRoute.parentRefs[0].namespace=gateway-system' --set 'httpRoute.hostnames[0]=hello.example' \
  --set pathPrefix=/app/hello)
has "apiVersion: gateway.networking.k8s.io/v1" "HTTPRoute API version"
has "kind: HTTPRoute" "HTTPRoute"
has "name: gw" "parent ref"
has "namespace: gateway-system" "parent ref namespace"
has "- hello.example" "hostname"
has $'type: PathPrefix\n            value: "/app/hello"' "path match"
has "type: URLRewrite" "rewrite filter"
has $'type: ReplacePrefixMatch\n              replacePrefixMatch: /' "prefix replacement"
has "port: 80" "backend port"
lacks "kind: Ingress" "Ingress"
result "C4 HTTPRoute with rewrite"

out=$(render --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gw' --set pathPrefix=/app/hello --set rewritePath=false)
has $'type: PathPrefix\n            value: "/app/hello"' "path match"
lacks "URLRewrite" "rewrite filter"
has 'path: "/app/hello/"' "probe path under the prefix"
result "C5 HTTPRoute, no rewrite"

out=$(render --set httpRoute.enabled=true) || true
has "httpRoute.parentRefs must name at least one Gateway" "error message"
result "C6 HTTPRoute with no parentRefs fails"

out=$(render --set ingress.configured=true --set ingress.pathPrefix=hello --set ingress.rewritePath=false)
has $'- name: HANDLER_PATH_PREFIX\n            value: "/hello"' "handler prefix"
has $'- name: RENDER_PATH_PREFIX\n            value: "/hello"' "render prefix"
has 'path: "/hello/"' "probe path under the prefix"
lacks "kind: Ingress" "Ingress"
out=$(NOTES=1 render --set ingress.configured=true --set ingress.pathPrefix=hello --set ingress.rewritePath=false)
has "DEPRECATED: ingress.configured, ingress.pathPrefix, ingress.rewritePath." "deprecation note"
out=$(NOTES=1 render --set pathPrefix=/hello --set ingress.enabled=true --set rewritePath=false)
lacks "DEPRECATED" "deprecation note"
result "C7 old ingress.* names"

out=$(render --set pathPrefix=/hello --set ingress.rewritePath=false)
has $'- name: HANDLER_PATH_PREFIX\n            value: "/hello"' "handler prefix from the old false"
out=$(render --set ingress.configured=true --set ingress.pathPrefix=hello --set rewritePath=false)
has $'- name: HANDLER_PATH_PREFIX\n            value: "/hello"' "handler prefix from the new false"
result "C8 a false rewritePath wins"

a=$(render --set ingress.enabled=true --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gw' --set pathPrefix=app/hello)
b=$(render --set ingress.enabled=true --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gw' --set pathPrefix=/app/hello)
c=$(render --set ingress.enabled=true --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gw' --set pathPrefix=/app/hello/)
[[ "$a" == "$b" && "$b" == "$c" ]] || problems+=("the three forms render differently")
out=$(render --set pathPrefix=/)
lacks "PATH_PREFIX" "prefix variable for /"
result "C9 the prefix is normalised"

if ! out=$(helm lint --strict "$chart" --set-string message='<b>Hi</b> & "you"' --set pathPrefix='a"b' \
  --set ingress.enabled=true --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gw' --set rewritePath=false 2>&1); then
  problems+=("helm lint failed: $(tail -n 2 <<<"$out")")
fi
result "C10 values with quotes render valid YAML"

out=$(render --set ingress.pathPrefix=hello)
lacks "PATH_PREFIX" "prefix variable"
result "C11 old ingress.pathPrefix needs ingress.configured"

if ((failures > 0)); then
  echo "$failures scenario(s) failed"
  exit 1
fi
echo "All chart tests passed"
