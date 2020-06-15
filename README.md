# Logging in Kubernetes

## Preparing the cluster.
In preparation for this exercise, it is necessary to create an AKS Cluster, follow this steps to create a 2-node cluster.
```powershell
# Set environment variables
$resourceGroup = 'LoggingGroup'
$clusterName = 'LoggingCluster'

# Login to Azure
az login

# Create resource group
az group create --name $resourceGroup --location westus

# Create a service principal
$principalObject = az ad sp create-for-rbac --skip-assignment | ConvertFrom-Json

# Create the cluster
az aks create --resource-group $resourceGroup --name $clusterName --node-vm-size Standard_B2s --generate-ssh-keys --node-count 2 --service-principal $principalObject.appId --client-secret $principalObject.password

# Create local configuration file to talk to the AKS Cluster
az aks get-credentials --resource-group $resourceGroup --name $clusterName

# Assign Kubernetes Dashboard permissions to the cluster
kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard --user=clusterUser

#Launch Kubernetes Dashboard
az aks browse --resource-group $resourceGroup --name $clusterName
```

## Creating a namespace
The first step is to create a namespace in the cluster.
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: logging
---
```

## Creating an elastic search cluster.
The cluster is comprised of three elements: a master node, a data node and a client node. The master node is a coordinator role, analogous to ZooKeeper in the world of Solr, but in this case, the image is the exact same as for the data and the client nodes.
