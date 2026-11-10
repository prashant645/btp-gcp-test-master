{{/*
Expand the name of the chart.
*/}}
{{- define "demoapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name.
*/}}
{{- define "demoapp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "demoapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "demoapp.labels" -}}
helm.sh/chart: {{ include "demoapp.chart" . }}
{{ include "demoapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "demoapp.selectorLabels" -}}
app: {{ include "demoapp.fullname" . }}
app.kubernetes.io/name: {{ include "demoapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Fully qualified image reference. Fails the render if the pipeline forgot to
pass a tag - an untagged image would silently resolve to :latest.
*/}}
{{- define "demoapp.image" -}}
{{- $tag := required "image.tag must be set by the pipeline (--set image.tag=...)" .Values.image.tag -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository $tag -}}
{{- end }}
