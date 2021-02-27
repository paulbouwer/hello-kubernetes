{{/*
Expand the name of the chart.
*/}}
{{- define "hello-kubernetes.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "hello-kubernetes.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hello-kubernetes.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
