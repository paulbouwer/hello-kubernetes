{{/*
Create a unique app name
*/}}
{{- define "hello-kubernetes.name" -}}
{{- printf "%s-%s" .Chart.Name .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "hello-kubernetes.labels" -}}
{{ include "hello-kubernetes.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "hello-kubernetes.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
The container image: the repository, and the tag or the chart appVersion. The
tag can be a number, such as 1 from --set or 1.11 in a values file, so it is
turned into text after the default is chosen.
*/}}
{{- define "hello-kubernetes.image" -}}
{{- $tag := .Values.deployment.container.image.tag | default .Chart.AppVersion | toString -}}
{{- printf "%s:%s" .Values.deployment.container.image.repository $tag }}
{{- end }}

{{/*
The path prefix, normalised to "/app/hello", or "" for none. It comes from
pathPrefix, or from the old ingress.pathPrefix when ingress.configured is true.
*/}}
{{- define "hello-kubernetes.pathPrefix" -}}
{{- $prefix := .Values.pathPrefix | default "" | toString -}}
{{- if and (not $prefix) .Values.ingress.configured -}}
{{- $prefix = .Values.ingress.pathPrefix | default "" | toString -}}
{{- end -}}
{{- $prefix = trimAll "/" $prefix -}}
{{- if $prefix }}/{{ $prefix }}{{ end -}}
{{- end }}

{{/*
"true" when the proxy strips the prefix. A false value of rewritePath or of the
old ingress.rewritePath wins, so a user's false is never ignored.
*/}}
{{- define "hello-kubernetes.rewritePath" -}}
{{- $old := true -}}
{{- if hasKey .Values.ingress "rewritePath" -}}
{{- $old = .Values.ingress.rewritePath -}}
{{- end -}}
{{- and .Values.rewritePath $old | toString -}}
{{- end }}
