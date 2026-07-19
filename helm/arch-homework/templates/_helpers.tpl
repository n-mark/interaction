{{/*
Common helpers
*/}}

{{- define "arch.namespace" -}}
{{- .Values.global.namespace -}}
{{- end -}}

{{- define "arch.host" -}}
{{- .Values.global.host -}}
{{- end -}}

{{/* FQDN of a service in the chart namespace, e.g. postgres.arch-hw.svc.cluster.local */}}
{{- define "arch.svc.fqdn" -}}
{{- $name := .name -}}
{{- printf "%s.%s.svc.cluster.local" $name (include "arch.namespace" .) -}}
{{- end -}}

{{/* Compose a ConfigMap/Secret name with a stable suffix */}}
{{- define "arch.cmName" -}}
{{- printf "%s-%s" .root.Name .suffix -}}
{{- end -}}
