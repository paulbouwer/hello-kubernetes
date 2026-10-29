# E3: a custom message with HTML and quotes is installed, and shown escaped.
EXPECTED_FAILURE="4.1: the chart doesn't quote the message, so a double quote breaks the YAML"
scenario() {
  install custom-message "$NAMESPACE" --set-string message='<b>Hi</b> & "you"'
  wait_ready custom-message "$NAMESPACE" 2
  local html
  html=$(page custom-message "$NAMESPACE")
  contains "$html" '&lt;b&gt;Hi&lt;/b&gt; &amp; &quot;you&quot;' "the escaped message"
  not_contains "$html" '<b>Hi</b>' "a raw <b> tag"
}
