# Param
export AZURE_DEFAULTS_GROUP=<ResourceGroupName>
export AZURE_DEFAULTS_LOCATION=<Location>
export CLUSTER=<AKSClusterName>

# Create public domain
export DOMAIN_NAME=<DomainName>

# Create a DNS zone for the domain
az network dns zone create --name $DOMAIN_NAME

# Configure the domain registrar to use Azure DNS
az network dns zone show --name $DOMAIN_NAME --output yaml

# test the DNS configuration
dig $DOMAIN_NAME ns +trace +nodnssec

# Install Cert Manager
kubectl create namespace cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --version v1.17.2 \
    --set crds.enabled=true

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  selfSigned: {}
EOF

kubectl apply -f - <<EOF
# certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: www
spec:
  secretName: www-tls
  privateKey:
    rotationPolicy: Always
  commonName: www.akms-dev.shop
  dnsNames:
    - www.akms-dev.shop
  usages:
    - digital signature
    - key encipherment
    - server auth
  issuerRef:
    name: selfsigned
    kind: ClusterIssuer
EOF

# Check the certificate
kubectl get secret www-tls -o yaml

# deploy a sample app
kubectl apply -f - <<EOF
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloweb
  labels:
    app: hello
spec:
  selector:
    matchLabels:
      app: hello
      tier: web
  template:
    metadata:
      labels:
        app: hello
        tier: web
    spec:
      containers:
      - name: hello-app
        image: us-docker.pkg.dev/google-samples/containers/gke/hello-app-tls:1.0
        imagePullPolicy: Always
        ports:
        - containerPort: 8443
        volumeMounts:
          - name: tls
            mountPath: /etc/tls
            readOnly: true
        env:
          - name: TLS_CERT
            value: /etc/tls/tls.crt
          - name: TLS_KEY
            value: /etc/tls/tls.key
      volumes:
      - name: tls
        secret:
          secretName: www-tls
EOF

export AZURE_LOADBALANCER_DNS_LABEL_NAME=lb-$(uuidgen)

# Create a service with a azure-dns-label-name annotation
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
    name: helloweb
    annotations:
        service.beta.kubernetes.io/azure-dns-label-name: ${AZURE_LOADBALANCER_DNS_LABEL_NAME}
spec:
    ports:
    - port: 443
      protocol: TCP
      targetPort: 8443
    selector:
        app: hello
        tier: web
    type: LoadBalancer
EOF

# Create a CNAME record for www to point to the Azure Load Balancer DNS name
az network dns record-set cname set-record \
    --zone-name $DOMAIN_NAME \
    --cname $AZURE_LOADBALANCER_DNS_LABEL_NAME.$AZURE_DEFAULTS_LOCATION.cloudapp.azure.com \
    --record-set-name www

# Check the domain name resolution
dig www.$DOMAIN_NAME A 
# --> it should return the IP address of the Azure Load Balancer

# test the TLS connection
curl --insecure -v https://www.$DOMAIN_NAME
# --> --insecure is used to ignore the self-signed certificate

# Clean up
# Delete the Kubernetes resources
kubectl delete service helloweb
kubectl delete deployment helloweb
kubectl delete certificate www
kubectl delete clusterissuer selfsigned
helm uninstall cert-manager -n cert-manager
kubectl delete namespace cert-manager

#Delete the DNS record
az network dns record-set cname delete \
    --zone-name $DOMAIN_NAME \
    --name www \
    --yes

#Delete the DNS zone
az network dns zone delete --name $DOMAIN_NAME --yes

#Optionally, delete the resource group (uncomment if you want to remove everything)
#az group delete --name $AZURE_DEFAULTS_GROUP --yes --no-wait
