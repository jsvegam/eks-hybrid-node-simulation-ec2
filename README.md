Here’s a complete README.md you can drop into the repo:

# EKS Hybrid Node Bring-Up – Runbook

Este documento describe los pasos probados para unir **nodos híbridos** (on-prem/VPC híbrida) a **Amazon EKS**, incluyendo prerequisitos, _join_ con `nodeadm`, instalación de Cilium en modo overlay **solo en híbridos**, y comprobaciones/diagnóstico.

> Tested with EKS **1.28.15** y Amazon Linux 2023 en el nodo híbrido.

---

## TL;DR

1. **Actualiza kubeconfig** y **mapea** el _activation role_ en `aws-auth`.
2. **Crea la SSM Activation** (ActivationId/Code).
3. En el **nodo híbrido (SSH)**: instala/activa **SSM agent**, descarga `nodeadm`, ejecuta `nodeadm install` y `nodeadm init` con **YAML**.
4. En tu **máquina local**: instala **Cilium** (overlay) con `nodeSelector` para aplicar **solo** a híbridos.
5. **Valida**: `kubectl get nodes -l eks.amazonaws.com/compute-type=hybrid -o wide`.

---

## Prerrequisitos

- En tu **máquina local** (Mac/Linux):
  - AWS CLI v2
  - `kubectl`
  - `helm`
  - Acceso al clúster EKS
- Infra:
  - VPC híbrida con **NAT** funcional.
  - Endpoints **SSM** (interface): `ssm`, `ssmmessages`, `ec2messages` en la VPC híbrida.
  - Conectividad (peering/rutas/DNS) hacia el **API Server** de EKS.

---

## 0) Contexto local

```bash
export AWS_PROFILE=eks-operator
export REGION=us-east-1
export CLUSTER=my-eks-cluster

aws sts get-caller-identity
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"

1) Mapear el Activation Role en aws-auth

El kubelet del híbrido se autentica vía IAM rol ${CLUSTER}-eks-hybrid-activation-role. Debe estar en mapRoles.

ROLE_ARN=$(aws iam get-role \
  --role-name "${CLUSTER}-eks-hybrid-activation-role" \
  --query 'Role.Arn' --output text)

CUR=$(kubectl -n kube-system get cm aws-auth \
  -o jsonpath='{.data.mapRoles}' | sed -e 's/\\n/\n/g' -e 's/\\t/\t/g')

if ! grep -q "$ROLE_ARN" <<<"$CUR"; then
  cat > /tmp/new-mapRoles.yaml <<EOF
$CUR
- rolearn: ${ROLE_ARN}
  username: system:node:{{SessionName}}
  groups:
    - system:bootstrappers
    - system:nodes
EOF

  PAYLOAD=$(python3 - <<'PY'
import json
print(json.dumps({"data":{"mapRoles":open("/tmp/new-mapRoles.yaml").read()}}))
PY
)
  kubectl -n kube-system patch configmap aws-auth --type merge -p "$PAYLOAD"
  echo ">> aws-auth actualizado con ${ROLE_ARN}"
else
  echo ">> aws-auth ya contiene ${ROLE_ARN}"
fi

# Verificación visual
kubectl -n kube-system get cm aws-auth -o jsonpath='{.data.mapRoles}' \
 | sed -e 's/\\n/\n/g' -e 's/\\t/\t/g'

2) Crear Activation de SSM
ROLE_NAME="${CLUSTER}-eks-hybrid-activation-role"
aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text

read ACT_ID ACT_CODE < <(aws ssm create-activation \
  --region "$REGION" \
  --iam-role "$ROLE_NAME" \
  --registration-limit 5 \
  --default-instance-name "eks-hybrid" \
  --tags Key=eks-hybrid,Value=true \
  --query '[ActivationId,ActivationCode]' --output text)

echo "ACT_ID=$ACT_ID"
echo "ACT_CODE=$ACT_CODE"   # Guarda estos valores de forma segura


Nota: No publiques ActivationCode en repositorios públicos.

3) Preparar el nodo híbrido (vía SSH)

Conéctate (usa -J si pasas por bastion):

ssh -J ec2-user@<bastion-public-dns> -i eks-hybrid-debug.pem ec2-user@<hybrid-private-ip>


En el nodo:

set -euxo pipefail
REGION=us-east-1
CLUSTER=my-eks-cluster

# 3.1 Conectividad básica
echo "== resolv.conf =="; cat /etc/resolv.conf || true
curl -s https://ifconfig.me || true   # Debe devolver IP pública (NAT OK)

# 3.2 Instalar/registrar SSM
sudo dnf -y install amazon-ssm-agent || true
sudo systemctl enable --now amazon-ssm-agent

# Sustituye con la Activation creada en el paso 2:
ACT_ID="<<ACT_ID>>"
ACT_CODE="<<ACT_CODE>>"

sudo /usr/bin/amazon-ssm-agent -register -id "$ACT_ID" -code "$ACT_CODE" -region "$REGION" -y || true
sudo systemctl restart amazon-ssm-agent
sudo systemctl status amazon-ssm-agent --no-pager -l || true

# 3.3 nodeadm (URL correcta)
curl -fsSLo /tmp/nodeadm https://hybrid-assets.eks.amazonaws.com/releases/latest/bin/linux/amd64/nodeadm
sudo install -m 0755 /tmp/nodeadm /usr/local/bin/nodeadm

# 3.4 Configuración YAML para nodeadm
sudo mkdir -p /etc/nodeadm
printf "cluster:\n  name: %s\n  region: %s\n" "$CLUSTER" "$REGION" \
 | sudo tee /etc/nodeadm/nodeConfig.yaml >/dev/null

# 3.5 Instalar componentes y kubelet para 1.28 (ajusta si tu EKS es otra versión)
sudo /usr/local/bin/nodeadm install 1.28 --credential-provider ssm

# 3.6 Join al clúster (usando la config YAML)
sudo /usr/local/bin/nodeadm init --config-source file:///etc/nodeadm/nodeConfig.yaml

# 3.7 Estado/logs kubelet
sudo systemctl is-active kubelet || true
sudo journalctl -u kubelet -n 200 --no-pager || true


Si hubo intentos previos y quedan restos:

sudo systemctl stop kubelet || true
sudo rm -rf /var/lib/kubelet /etc/kubernetes || true
sudo /usr/local/bin/nodeadm init --config-source file:///etc/nodeadm/nodeConfig.yaml

4) CNI overlay (solo híbridos) con Cilium – desde tu máquina local
helm repo add cilium https://helm.cilium.io
helm repo update

# CIDR de pods para híbridos (ajusta si lo gestionas con Terraform)
POD_CIDR="$(terraform output -raw hybrid_pod_cidr 2>/dev/null || echo 10.200.0.0/16)"

helm upgrade --install cilium-hybrid cilium/cilium \
  --namespace kube-system \
  --version 1.14.10 \
  --set nodeSelector."eks\.amazonaws\.com/compute-type"=hybrid \
  --set routingMode=tunnel \
  --set tunnel=vxlan \
  --set ipam.mode=cluster-pool \
  --set ipam.operator.clusterPoolIPv4PodCIDRList="{${POD_CIDR}}" \
  --set ipam.operator.clusterPoolIPv4MaskSize=24 \
  --set kubeProxyReplacement=disabled \
  --set hubble.enabled=false

kubectl -n kube-system rollout status ds/cilium --timeout=180s
kubectl -n kube-system get pods -l k8s-app=cilium -o wide


El label eks.amazonaws.com/compute-type=hybrid lo añade el propio flujo de bootstrap; por eso el nodeSelector aplica solo en esos nodos.

5) Validación
# Nodo híbrido visible
kubectl get nodes -l eks.amazonaws.com/compute-type=hybrid -o wide

# Probar scheduling en híbrido
kubectl run nginx-hybrid --image=nginx \
  --overrides='{"spec":{"nodeSelector":{"eks.amazonaws.com/compute-type":"hybrid"}}}'
kubectl get pod nginx-hybrid -o wide

# SSM Online (máquina local)
aws ssm describe-instance-information --region "$REGION" \
  --query "InstanceInformationList[].{Id:InstanceId,Name:ComputerName,Ping:PingStatus,Last:LastPingDateTime}" \
  --output table

6) Comprobaciones de red/infra
# Endpoints SSM en VPC híbrida (deben existir: ssm, ssmmessages, ec2messages)
aws ec2 describe-vpc-endpoints --region "$REGION" \
  --filters Name=vpc-id,Values="$HYBRID_VPC_ID" \
           Name=service-name,Values="com.amazonaws.$REGION.ssm","com.amazonaws.$REGION.ssmmessages","com.amazonaws.$REGION.ec2messages" \
  --query 'VpcEndpoints[].{Id:VpcEndpointId,Service:ServiceName,State:State,DNSEnabled:PrivateDnsEnabled,Subnets:SubnetIds}' \
  --output table

# NAT + rutas
aws ec2 describe-route-tables --region "$REGION" \
  --filters Name=vpc-id,Values="$HYBRID_VPC_ID" \
  --query 'RouteTables[].{RT:RouteTableId,Assoc:Associations[].SubnetId,DefaultRoute:Routes[?DestinationCidrBlock==`0.0.0.0/0`].[GatewayId,NatGatewayId] | [0]}' \
  --output table

# Peering entre VPC del EKS y la híbrida
aws ec2 describe-vpc-peering-connections --region "$REGION" \
  --filters "Name=requester-vpc-info.vpc-id,Values=$EKS_VPC_ID" \
           "Name=accepter-vpc-info.vpc-id,Values=$HYBRID_VPC_ID" \
  --query 'VpcPeeringConnections[].{Id:VpcPeeringConnectionId,Status:Status.Code}' \
  --output table

# En el nodo: resolución DNS y liveness del API (403 es normal sin auth)
ENDPOINT=$(aws eks describe-cluster --name "$CLUSTER" --region "$REGION" --query 'cluster.endpoint' --output text)
getent hosts "${ENDPOINT#https://}" || nslookup "${ENDPOINT#https://}" || true
curl -skI "${ENDPOINT}/livez" || true


Tip: Para obtener EKS_VPC_ID y HYBRID_VPC_ID:

EKS_VPC_ID="$(aws eks describe-cluster --region "$REGION" --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)"
# Si usas Terraform:
HYBRID_VPC_ID="$(terraform output -raw vpc_hybrid_id 2>/dev/null || terraform output -raw hybrid_vpc_id 2>/dev/null)"

Troubleshooting

aws-auth sin activation role
Síntomas: kubelet arranca pero el nodo no se una.
Solución: paso 1 (patch de aws-auth).

SSM Offline / MI=None
Verifica en el nodo:

sudo systemctl status amazon-ssm-agent --no-pager -l
sudo tail -n 80 /var/log/amazon/ssm/amazon-ssm-agent.log


Confirma endpoints SSM en la VPC híbrida y salida vía NAT.

nodeadm init con argumentos inválidos
Usa YAML con --config-source file:///.../nodeConfig.yaml.
(Los flags --cluster-name/--region no aplican a init.)

Cilium desde el nodo falla
Ejecuta Helm/kubectl de Cilium desde tu máquina local (no en el nodo).

403 en /livez
Indica que llegas al API Server (sin auth). Es una buena señal de red/DNS.

Restos de kubelet
Si init falla repetidamente:

sudo systemctl stop kubelet || true
sudo rm -rf /var/lib/kubelet /etc/kubernetes || true
sudo /usr/local/bin/nodeadm init --config-source file:///etc/nodeadm/nodeConfig.yaml

Apéndice – Snippets útiles
# SSM Online (solo ManagedInstance)
aws ssm describe-instance-information --region "$REGION" \
  --query 'InstanceInformationList[?PingStatus==`Online` && ResourceType==`ManagedInstance`].[InstanceId,ComputerName,PlatformType]' \
  --output table

# Estado de nodos
kubectl get nodes -o wide
kubectl get nodes -l eks.amazonaws.com/compute-type=hybrid -o wide

# Conexión SSH con bastion
ssh -J ec2-user@<bastion-public-dns> -i eks-hybrid-debug.pem ec2-user@<hybrid-private-ip>

Notas

Para pull de imágenes: con NAT basta. Si bloqueas Internet, añade VPC endpoints de ECR (ecr.api, ecr.dkr) y S3 (gateway) según tu política.

Ajusta nodeadm install <k8sMinor> al minor de tu clúster (1.27, 1.28, etc.).