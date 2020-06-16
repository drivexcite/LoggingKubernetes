$resourceGroup = 'LoggingGroup'
$clusterName = 'LoggingCluster'
$acrName = 'LoggingCluster'

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

# Create Azure Container Registry
az acr create --name $acrName --resource-group $resourceGroup --location westus -sku Basic --identity --admin-enabled true

# Store the ID of the recently created ACR into a variable.
$acrResourceId = az acr show --name $acrName --resource-group $resourceGroup --query id

# Attach ACR to AKS
az aks update --name $clusterName --resource-group resourceGroup --detach-acr $acrResourceId

# Store the server name
$loggingServer = az acr show --name $acrName --resource-group $resourceGroup --query loginServer

# From the server source code directory, build the image in ACR.
az acr build --resource-group $resourceGroup --registry $acrName --image server:v1 .

