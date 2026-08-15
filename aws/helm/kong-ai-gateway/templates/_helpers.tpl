{{- define "kong-ai-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "kong-ai-gateway.labels" -}}
app.kubernetes.io/name: {{ include "kong-ai-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: kong-ai-gateway
{{- end }}
