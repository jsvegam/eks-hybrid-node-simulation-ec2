resource "null_resource" "enable_remote_network_config" {
  triggers = {
    cluster_name = var.cluster_name
    region       = var.aws_region
    hybrid_cidr  = var.hybrid_cidr
    profile      = var.aws_profile
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      echo "[INFO] Waiting for cluster ${var.cluster_name} to be ACTIVE..."
      for i in {1..90}; do
        s=$(aws eks describe-cluster --region "${var.aws_region}" --name "${var.cluster_name}" --profile "${var.aws_profile}" --query 'cluster.status' --output text 2>/dev/null || echo "MISSING")
        [[ "$s" == "ACTIVE" ]] && break || sleep 10
      done

      echo "[INFO] Checking current remoteNetworkConfig..."
      curr=$(aws eks describe-cluster --region "${var.aws_region}" --name "${var.cluster_name}" --profile "${var.aws_profile}"         --query 'cluster.remoteNetworkConfig.remoteNodeNetworks[].cidrs[]' --output text 2>/dev/null || echo "")
      if [[ "$curr" == *"${var.hybrid_cidr}"* ]]; then
        echo "[INFO] Hybrid CIDR already present"
        exit 0
      fi

      echo "[INFO] Applying remoteNodeNetworks=${var.hybrid_cidr}"
      aws eks update-cluster-config --region "${var.aws_region}" --name "${var.cluster_name}" --profile "${var.aws_profile}"         --remote-network-config "{\"remoteNodeNetworks\":[{\"cidrs\":[\"${var.hybrid_cidr}\"]}]}"
    EOT
  }
}
