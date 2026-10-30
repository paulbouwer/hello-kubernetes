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
The container image: the repository, and the tag or the chart appVersion
*/}}
{{- define "hello-kubernetes.image" -}}
{{- printf "%s:%s" .Values.deployment.container.image.repository (.Values.deployment.container.image.tag | default .Chart.AppVersion) }}
{{- end }}
