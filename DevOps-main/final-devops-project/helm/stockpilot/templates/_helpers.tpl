{{- define "stockpilot.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "stockpilot.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: stockpilot
{{- end -}}

{{/* selector labels: call with (dict "ctx" $ "component" "backend") */}}
{{- define "stockpilot.selectorLabels" -}}
app.kubernetes.io/name: {{ .ctx.Chart.Name }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* image reference: call with (dict "ctx" $ "image" .Values.backend.image) */}}
{{- define "stockpilot.image" -}}
{{- if .ctx.Values.global.imageRegistry -}}
{{ printf "%s/%s:%s" .ctx.Values.global.imageRegistry .image.repository (toString .image.tag) }}
{{- else -}}
{{ printf "%s:%s" .image.repository (toString .image.tag) }}
{{- end -}}
{{- end -}}

{{- define "stockpilot.secretName" -}}
{{- default (printf "%s-db" (include "stockpilot.fullname" .)) .Values.auth.existingSecret -}}
{{- end -}}

{{- define "stockpilot.podSecurity" -}}
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{- define "stockpilot.containerSecurity" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end -}}
