$resourceGroup = 'LoggingGroup'
$clusterName = 'LoggingCluster'

# Login to Azure
az login

# Create resource group
az group create --name $resourceGroup --location westus

# Create a service principal
$principalObject = az ad sp create-for-rbac --skip-assignment | ConvertFrom-Json

# Add the preview extension to use cluster auto-scaling
# az extension add --name aks-preview

# Create cluster
# az aks create --resource-group $resourceGroup --name $clusterName --node-vm-size Standard_B2ms --generate-ssh-keys --service-principal $principalObject.appId --client-secret $principalObject.password --node-count 2 --enable-vmss --enable-cluster-autoscaler --min-count 1 --max-count 3
# az aks create --resource-group $resourceGroup --name $clusterName --node-vm-size Standard_B2ms --generate-ssh-keys --node-count 2 --enable-vmss --enable-cluster-autoscaler --min-count 1 --max-count 3 --service-principal $principalObject.appId --client-secret $principalObject.password
az aks create --resource-group $resourceGroup --name $clusterName --node-vm-size Standard_B2s --generate-ssh-keys --node-count 2 --service-principal $principalObject.appId --client-secret $principalObject.password

# Create local configuration file to talk to the AKS Cluster
az aks get-credentials --resource-group $resourceGroup --name $clusterName

# Assign Kubernetes Dashboard permissions to the cluster
# https://github.com/Azure/AKS/issues/1573#issuecomment-627070128
kubectl delete clusterrolebinding kubernetes-dashboard
kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard --user=clusterUser

# Display the version of Kubernetes
az aks show --resource-group $resourceGroup --name $clusterName --query kubernetesVersion

#Launch Kubernetes Dashboard
az aks browse --resource-group $resourceGroup --name $clusterName