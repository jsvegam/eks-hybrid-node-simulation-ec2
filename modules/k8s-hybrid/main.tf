#############################################
# modules/k8s-hybrid/main.tf
# - Mapea el rol SSM de activación en aws-auth (mapRoles)
# - Evita que aws-node se ejecute en nodos "hybrid"
#############################################

# Ejecuta en el host que corre Terraform (tu Mac)
# No requiere providers helm/kubernetes; usa AWS CLI + kubectl

# 1) Agregar/asegurar el mapeo del rol de activación en aws-auth
resource "null_resource" "aws_auth_append_role" {
  count = var.manage_aws_auth ? 1 : 0

  triggers = {
    role_arn     = var.activation_role_arn
    cluster_name = local.eff_cluster_name
    region       = local.eff_region
    profile      = local.eff_profile
  }

  provisioner "local-exec" {
    # Exporta AWS_PROFILE si viene definido
    environment = var.profile == "" ? {} : { AWS_PROFILE = var.profile }
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      KCFG="$(mktemp)"
      trap 'rm -f "$KCFG"' EXIT

      # kubeconfig local para este comando
      aws eks update-kubeconfig \
        --region ${local.eff_region} \
        --name ${local.eff_cluster_name} \
        --kubeconfig "$KCFG" >/dev/null

      export KUBECONFIG="$KCFG"

      NS="kube-system"
      CM="aws-auth"
      ROLE_ARN="${var.activation_role_arn}"

      # mapRoles actual (si no existe, devuelve vacío)
      CURRENT="$(kubectl get cm "$CM" -n "$NS" -o jsonpath='{.data.mapRoles}' 2>/dev/null || true)"

      # Bloque a insertar
      ADD_BLOCK="- rolearn: ${var.activation_role_arn}
        username: system:node:{{SessionName}}
        groups:
        - system:bootstrappers
        - system:nodes"

      if [ -z "$CURRENT" ]; then
        NEW="$ADD_BLOCK"
      elif echo "$CURRENT" | grep -q "$ROLE_ARN"; then
        NEW="$CURRENT"   # ya existe
      else
        NEW="$CURRENT"$'\n'"$ADD_BLOCK"
      fi

      PATCH="$(mktemp)"
      {
        echo "apiVersion: v1"
        echo "kind: ConfigMap"
        echo "metadata:"
        echo "  name: $CM"
        echo "  namespace: $NS"
        echo "data:"
        echo "  mapRoles: |"
        printf '%s\n' "$NEW" | sed 's/^/    /'
      } > "$PATCH"

      kubectl patch cm "$CM" -n "$NS" --type merge --patch-file "$PATCH" >/dev/null

      # opcional: muestra los primeros 120 lines del CM para auditar
      kubectl get cm "$CM" -n "$NS" -o yaml | sed -n '1,120p' 1>&2 || true
    EOT
  }
}

# 2) Evitar que aws-node (VPC CNI) se ejecute en nodos híbridos
resource "null_resource" "aws_node_avoid_hybrid" {
  triggers = {
    cluster_name = local.eff_cluster_name
    region       = local.eff_region
    profile      = local.eff_profile
  }

  provisioner "local-exec" {
    environment = var.profile == "" ? {} : { AWS_PROFILE = var.profile }
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      KCFG="$(mktemp)"
      trap 'rm -f "$KCFG"' EXIT

      aws eks update-kubeconfig \
        --region ${local.eff_region} \
        --name ${local.eff_cluster_name} \
        --kubeconfig "$KCFG" >/dev/null

      kubectl -n kube-system patch ds aws-node --type='merge' --kubeconfig "$KCFG" -p '
      spec:
        template:
          spec:
            affinity:
              nodeAffinity:
                requiredDuringSchedulingIgnoredDuringExecution:
                  nodeSelectorTerms:
                  - matchExpressions:
                    - key: eks.amazonaws.com/compute-type
                      operator: NotIn
                      values: ["hybrid"]
      ' || true
    EOT
  }
}
