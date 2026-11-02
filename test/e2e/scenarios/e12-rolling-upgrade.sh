# E12: helm upgrade replaces every pod with no downtime. A loop requests the
# page through the Ingress during the upgrade, and must see only 200s.
# Prints the release's pods that are not being deleted.
live_pods() {
  kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/instance=upgrade -o json |
    jq -r '.items[] | select(.metadata.deletionTimestamp == null) | .metadata.name' | sort
}

scenario() {
  local routing=(--set ingress.enabled=true --set ingress.className="$INGRESS_CLASS"
    --set ingress.host=upgrade.e2e.test --set pathPrefix=/app/upgrade --set rewritePath=false)
  install upgrade "$NAMESPACE" "${routing[@]}" --set-string message=upgrade-v1
  wait_ready upgrade "$NAMESPACE" 2
  contains "$(routed "$INGRESS_URL" upgrade.e2e.test /app/upgrade/)" "upgrade-v1" "upgrade-v1 before the upgrade"
  local before after codes loop
  before=$(live_pods)
  codes=$(mktemp)
  # curl prints 000 when it can't connect, so a refused connection counts too.
  (
    set +e
    while :; do
      curl -s -o /dev/null -w '%{http_code}\n' --max-time 2 -H "Host: upgrade.e2e.test" \
        "$INGRESS_URL/app/upgrade/" >>"$codes" || true
      sleep 0.1
    done
  ) &
  loop=$!
  install upgrade "$NAMESPACE" "${routing[@]}" --set-string message=upgrade-v2
  wait_ready upgrade "$NAMESPACE" 2
  sleep 2
  kill "$loop"
  wait "$loop" 2>/dev/null || true
  info "$(wc -l <"$codes") requests during the upgrade: $(sort "$codes" | uniq -c | xargs)"
  [[ -s "$codes" ]] || die "no requests were made during the upgrade"
  if grep -qv '^200$' "$codes"; then
    die "requests failed during the upgrade: $(grep -v '^200$' "$codes" | sort | uniq -c | xargs)"
  fi
  rm -f "$codes"
  after=$(live_pods)
  [[ -z "$(comm -12 <(echo "$before") <(echo "$after"))" ]] || die "some pods were not replaced"
  info "all pods were replaced"
  contains "$(routed "$INGRESS_URL" upgrade.e2e.test /app/upgrade/)" "upgrade-v2" "upgrade-v2 after the upgrade"
}
