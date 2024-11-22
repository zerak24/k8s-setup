{{- define "config.etcdLocal" -}}
{{- $etcdString := "" }}
{{- range $key, $val := . }}
{{- $etcdString = printf "%s%s=https://%s:2380," $etcdString $key $val }}
{{- end }}
{{- print $etcdString | trimSuffix "," }}   
{{- end }}

{{- define "config.etcdExternal" -}}
{{- range $key, $val := . }}
{{- printf "- https://%s:2379\n" $val }}
{{- end }}
{{- end }}
