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
#   C12 The schema accepts the defaults and the values of C1-C11.
#   C13 The schema rejects a wrong type, an unknown key and a value not allowed.
#   C14 message must be a string; the image tag can be a number.
#   C15 The schema accepts the old ingress.* names and global.
#   C16 Every value has a description, and the schema matches values.yaml.
#   C17 The values table in docs/deploy-using-helm.md lists every value.
#
# Each scenario prints PASS or FAIL. The script exits 1 if any fails.
# Needs helm and node.

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

out=$(render) || true
lacks "kind: Ingress" "Ingress"
lacks "kind: HTTPRoute" "HTTPRoute"
lacks "PATH_PREFIX" "prefix variable"
has 'path: "/"' "probe path"
result "C1 defaults: no Ingress, no HTTPRoute, no prefix"

out=$(render --set ingress.enabled=true --set ingress.className=traefik --set ingress.host=hello.example \
  --set 'ingress.tls[0].secretName=hello-tls' --set 'ingress.annotations.example\.com/a=b' \
  --set pathPrefix=/app/hello --set rewritePath=false) || true
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

out=$(render --set ingress.enabled=true --set pathPrefix=/app/hello) || true
has '- path: "/app/hello"' "Ingress path"
has $'- name: HANDLER_PATH_PREFIX\n            value: ""' "empty handler prefix"
has $'- name: RENDER_PATH_PREFIX\n            value: "/app/hello"' "render prefix"
has 'path: "/"' "probe path"
lacks "ingressClassName" "class"
lacks "host:" "host"
out=$(NOTES=1 render --set ingress.enabled=true --set pathPrefix=/app/hello) || true
has "Add your" "note about the rewrite annotation"
has "Set service.type=ClusterIP" "note about the service type"
result "C3 Ingress with rewrite"

out=$(render --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gw' \
  --set 'httpRoute.parentRefs[0].namespace=gateway-system' --set 'httpRoute.hostnames[0]=hello.example' \
  --set pathPrefix=/app/hello) || true
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

out=$(render --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gw' --set pathPrefix=/app/hello --set rewritePath=false) || true
has $'type: PathPrefix\n            value: "/app/hello"' "path match"
lacks "URLRewrite" "rewrite filter"
has 'path: "/app/hello/"' "probe path under the prefix"
result "C5 HTTPRoute, no rewrite"

out=$(render --set httpRoute.enabled=true) || true
has "at '/httpRoute/parentRefs': minItems: got 0, want 1" "schema error"
out=$(render --set httpRoute.enabled=true --skip-schema-validation) || true
has "httpRoute.parentRefs must name at least one Gateway" "template error without the schema"
result "C6 HTTPRoute with no parentRefs fails"

out=$(render --set ingress.configured=true --set ingress.pathPrefix=hello --set ingress.rewritePath=false) || true
has $'- name: HANDLER_PATH_PREFIX\n            value: "/hello"' "handler prefix"
has $'- name: RENDER_PATH_PREFIX\n            value: "/hello"' "render prefix"
has 'path: "/hello/"' "probe path under the prefix"
lacks "kind: Ingress" "Ingress"
out=$(NOTES=1 render --set ingress.configured=true --set ingress.pathPrefix=hello --set ingress.rewritePath=false) || true
has "DEPRECATED: ingress.configured, ingress.pathPrefix, ingress.rewritePath." "deprecation note"
out=$(NOTES=1 render --set pathPrefix=/hello --set ingress.enabled=true --set rewritePath=false) || true
lacks "DEPRECATED" "deprecation note"
result "C7 old ingress.* names"

out=$(render --set pathPrefix=/hello --set ingress.rewritePath=false) || true
has $'- name: HANDLER_PATH_PREFIX\n            value: "/hello"' "handler prefix from the old false"
out=$(render --set ingress.configured=true --set ingress.pathPrefix=hello --set rewritePath=false) || true
has $'- name: HANDLER_PATH_PREFIX\n            value: "/hello"' "handler prefix from the new false"
result "C8 a false rewritePath wins"

a=$(render --set ingress.enabled=true --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gw' --set pathPrefix=app/hello) || true
b=$(render --set ingress.enabled=true --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gw' --set pathPrefix=/app/hello) || true
c=$(render --set ingress.enabled=true --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gw' --set pathPrefix=/app/hello/) || true
[[ "$a" == "$b" && "$b" == "$c" ]] || problems+=("the three forms render differently")
out=$(render --set pathPrefix=/) || true
lacks "PATH_PREFIX" "prefix variable for /"
result "C9 the prefix is normalised"

if ! out=$(helm lint --strict "$chart" --set-string message='<b>Hi</b> & "you"' --set pathPrefix='a"b' \
  --set ingress.enabled=true --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gw' --set rewritePath=false 2>&1); then
  problems+=("helm lint failed: $(tail -n 2 <<<"$out")")
fi
result "C10 values with quotes render valid YAML"

out=$(render --set ingress.pathPrefix=hello) || true
lacks "PATH_PREFIX" "prefix variable"
result "C11 old ingress.pathPrefix needs ingress.configured"

# rejects NAME SCHEMA_ERROR VALUES...: the schema must reject the values, with
# an error that names the value.
rejects() {
  local what="$1" error="$2"
  shift 2
  if out=$(render "$@"); then
    problems+=("accepted $what: $*")
  else
    has "$error" "schema error for $what"
  fi
}
# accepts NAME VALUES...: the schema must accept the values.
accepts() {
  local what="$1"
  shift
  out=$(render "$@") || problems+=("rejected $what: $(grep -m1 "at '" <<<"$out")")
}

accepts "defaults"
accepts "C2 values" --set ingress.enabled=true --set ingress.className=traefik --set ingress.host=hello.example \
  --set 'ingress.tls[0].secretName=hello-tls' --set 'ingress.annotations.example\.com/a=b' \
  --set pathPrefix=/app/hello --set rewritePath=false
accepts "C4 values" --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gw' \
  --set 'httpRoute.parentRefs[0].namespace=gateway-system' --set 'httpRoute.hostnames[0]=hello.example'
accepts "no security contexts" --set deployment.podSecurityContext=null --set deployment.container.securityContext=null
accepts "a ClusterIP service on another port" --set service.type=ClusterIP --set service.port=8080 --set deployment.container.port=9090
result "C12 the schema accepts valid values"

rejects "an unknown key" "additional properties 'pathPrefx' not allowed" --set pathPrefx=/app/hello
rejects "an unknown ingress key" "additional properties 'path' not allowed" --set ingress.path=/app/hello
rejects "a wrong type" "at '/deployment/replicaCount': got string, want integer" --set deployment.replicaCount=two
rejects "a service type not allowed" "at '/service/type': value must be one of" --set service.type=Foo
rejects "a pull policy not allowed" "at '/deployment/container/image/pullPolicy': value must be one of" --set deployment.container.image.pullPolicy=Sometimes
rejects "a port out of range" "at '/service/port': maximum" --set service.port=70000
rejects "a non-string annotation" "at '/ingress/annotations/a': got boolean, want string" --set ingress.annotations.a=true
result "C13 the schema rejects invalid values"

rejects "a number as the message" "at '/message': got number, want string" --set message=42
rejects "a boolean as the message" "at '/message': got boolean, want string" --set message=true
accepts "a number as a string message" --set-string message=42
accepts "a number as the image tag" --set deployment.container.image.tag=1.11
out=$(render --set deployment.container.image.tag=1.11) || true
has 'image: "paulbouwer/hello-kubernetes:1.11"' "the tag as written"
result "C14 message is text; the image tag can be a number"

accepts "the old names" --set ingress.configured=true --set ingress.pathPrefix=hello --set ingress.rewritePath=false
accepts "global" --set global.imageRegistry=example.com
result "C15 the schema accepts the old names and global"

# Compare the keys in values.yaml with the schema's properties. A schema
# property with no properties of its own (an object passed through, such as
# resources) stops the walk.
if ! out=$(helm install t "$chart" --dry-run=client -o json 2>&1 | node -e '
  const schema = require(process.argv[1]);
  let input = "";
  process.stdin.on("data", d => input += d).on("end", () => {
    let values;
    try { values = JSON.parse(input).chart.values; } catch (e) {
      console.log("helm could not render the defaults: " + input.split("\n").slice(0, 3).join(" "));
      process.exit(1);
    }
    const problems = [];
    const optional = new Set(["global", "ingress.configured", "ingress.pathPrefix", "ingress.rewritePath"]);
    const walk = (v, s, path) => {
      if (!s.description) problems.push("no description: " + (path.replace(/\.$/, "") || "(root)"));
      if (!s.properties) return;
      for (const key of Object.keys(v || {})) {
        if (!s.properties[key]) problems.push("not in the schema: " + path + key);
      }
      for (const [key, sub] of Object.entries(s.properties)) {
        const p = path + key;
        if (v && key in v) walk(v[key], sub, p + ".");
        else if (!optional.has(p)) problems.push("not in values.yaml: " + p);
        else if (!sub.description) problems.push("no description: " + p);
      }
    };
    walk(values, schema, "");
    if (problems.length) { console.log(problems.join("\n")); process.exit(1); }
  });' "$chart/values.schema.json"); then
  problems+=("$out")
fi
result "C16 every value has a description, and the schema matches values.yaml"

# Every value the schema describes, except global, must be in the values table.
if ! out=$(node -e '
  const fs = require("fs");
  const schema = require(process.argv[1]), docs = fs.readFileSync(process.argv[2], "utf8");
  const missing = [];
  const walk = (s, path) => {
    for (const [key, sub] of Object.entries(s.properties || {})) {
      const p = path + key;
      if (p === "global") continue;
      if (sub.properties) walk(sub, p + ".");
      else if (!docs.includes("`" + p + "`")) missing.push(p);
    }
  };
  walk(schema, "");
  if (missing.length) { console.log("not in the values table: " + missing.join(", ")); process.exit(1); }
' "$chart/values.schema.json" "$here/../../docs/deploy-using-helm.md" 2>&1); then
  problems+=("$out")
fi
result "C17 the docs list every value"

if ((failures > 0)); then
  echo "$failures scenario(s) failed"
  exit 1
fi
echo "All chart tests passed"
