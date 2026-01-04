{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "kubevirt-oms.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kubevirt-oms.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kubevirt-oms.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kubevirt-oms.labels" -}}
helm.sh/chart: {{ include "kubevirt-oms.chart" . }}
{{ include "kubevirt-oms.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kubevirt-oms.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubevirt-oms.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Generate cloud-init user data
*/}}
{{- define "kubevirt-oms.cloudinit.userData" -}}
#cloud-config
ssh_pwauth: {{ .Values.cloudinit.sshPasswordAuth }}
disable_root: {{ .Values.cloudinit.disableRoot }}
timezone: {{ .Values.cloudinit.timezone }}
{{- if .Values.cloudinit.users }}
users:
{{- range .Values.cloudinit.users }}
  - name: {{ .name }}
    lock_passwd: {{ .lockPassword }}
{{- if .sshAuthorizedKeys }}
    ssh_authorized_keys:
{{- range .sshAuthorizedKeys }}
      - {{ . | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- if .Values.cloudinit.diskSetup }}
disk_setup:
{{ toYaml .Values.cloudinit.diskSetup | indent 2 }}
{{- end }}
{{- if .Values.cloudinit.fsSetup }}
fs_setup:
{{- range .Values.cloudinit.fsSetup }}
  - {{ toYaml . | nindent 4 }}
{{- end }}
{{- end }}
{{- if .Values.cloudinit.mounts }}
mounts:
{{- range .Values.cloudinit.mounts }}
  - {{ toYaml . | nindent 4 }}
{{- end }}
{{- end }}
{{- if .Values.cloudinit.runCommands }}
runcmd:
{{- range .Values.cloudinit.runCommands }}
  - {{ . | quote }}
{{- end }}
{{- end }}
{{- end }}