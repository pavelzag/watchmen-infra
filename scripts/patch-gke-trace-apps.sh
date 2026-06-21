#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:-watchmen}"
go_image="${TRACE_TEST_IMAGE:-golang:1.24-alpine}"
runtime_image="${TRACE_TEST_RUNTIME_IMAGE:-alpine:3.20}"

deployments=(
  watchmen-trace-main
  watchmen-trace-worker-a
  watchmen-trace-worker-b
)

for deployment in "${deployments[@]}"; do
  echo "Patching deployment/$deployment in namespace $namespace"
  kubectl -n "$namespace" patch deployment "$deployment" --type strategic --patch "$(cat <<EOF
{
  "spec": {
    "template": {
      "spec": {
        "initContainers": [
          {
            "name": "build",
            "image": "$go_image",
            "command": ["go", "build", "-o", "/bin-app/watchmen-trace-app", "/app/main.go"],
            "resources": {
              "requests": {
                "cpu": "100m",
                "memory": "128Mi"
              },
              "limits": {
                "cpu": "1000m",
                "memory": "768Mi"
              }
            },
            "volumeMounts": [
              {
                "name": "app-source",
                "mountPath": "/app",
                "readOnly": true
              },
              {
                "name": "app-bin",
                "mountPath": "/bin-app"
              }
            ]
          }
        ],
        "containers": [
          {
            "name": "app",
            "image": "$runtime_image",
            "command": ["/bin-app/watchmen-trace-app"],
            "volumeMounts": [
              {
                "name": "app-bin",
                "mountPath": "/bin-app",
                "readOnly": true
              }
            ]
          }
        ],
        "volumes": [
          {
            "name": "app-bin",
            "emptyDir": {}
          }
        ]
      }
    }
  }
}
EOF
)"
done

for deployment in "${deployments[@]}"; do
  kubectl -n "$namespace" rollout status "deployment/$deployment"
done
