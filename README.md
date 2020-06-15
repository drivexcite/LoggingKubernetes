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

## Namespace
Resources deployed in a cluster are better organized if they are deployed in a specific namespace, as opposed to the default namespace.

## Elastic Search.
The cluster is comprised of three elements: a master node, a data node and a client node. The master node is a coordinator role, analogous to ZooKeeper in the world of Solr, but in this case, the image is the exact same as for the data and the client nodes.

### Master node
Analogous to what ZooKeeper does for some cluster configurations, the master node contols the cluster. It has a registry of other nodes and indices and propagates configuration in the cluster, etc. It is not necessary to have a master node, since by default all nodes are master eligible, however, it's much easier to conceptually grasp what it does by separating it.

The most relevant configuration is located in the elasticsearch.yaml defined in the ConfigMap (02.elasticsearch-master.yaml).
```yaml
    node:
      master: true
      data: false
      ingest: false
```

### Data node
Data nodes take care of the persistent aspect of the search engine. They are in charge of reading and writing documents into indices, etc. As with the master node, it is not necessary to have a dedicated data node, since all nodes are data nodes by default too. As the component of the cluster in charge of persistent data, it needs a dedicated volume mount for the /data directory. In my example, it creates an Azure Disk on demand, via AKS, the relevant configuration, located in 03.elasticsearch-data.yaml:

```yaml
    node:
      master: false
      data: true
      ingest: false
```

And in order to configure automatic persistent volume allocation provided by Azure, it's necessary to set an AKS specific storage class (managed-premium):
```yaml
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data-persistent-storage
        annotations:
          volume.beta.kubernetes.io/storage-class: "managed-premium"
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: standard
        resources:
          requests:
            storage: 10Gi
```

Also, unlike the master and the client nodes wich are simple Deployments, it is deployed in Kubernetes as a StatefulSet in combination with volumeClaimTemplates.

### Client node
The Client node or Ingest is an Elastic Search dedicated load balancer that forwards requests to other (data) nodes.

```yaml
    node:
      master: false
      data: false
      ingest: true
```


## Generating master passwords
After installing all the Elastic Search resources, but before installing the Kibana UI, it is necessary to autogenerate passwords to connect to Elastic from Kiabana, using Basic Authentication. The following script, will select the client pod, invoke the `elasticsearch-setup-passwords` command and retrieve the list of generated userIds and passwords to a variable. Then we take the kibana password and set it up as a Kubernetes Secret in the same namespace as the other components.

```powershell
$clientPod = kubectl get pods -n logging | grep elasticsearch-client | sed -n 1p | awk '{print $1}'
$passwords = kubectl exec -it $clientPod -n logging -- bin/elasticsearch-setup-passwords auto -b
$kibanaPassword = echo $passwords | grep 'PASSWORD kibana' | awk '{print $4}'
$elasticPassword = echo $passwords | grep 'PASSWORD elastic' | awk '{print $4}'

# Create the Kibana secret for use in the Kibana Setup.
kubectl create secret generic kibana-password -n logging --from-literal password=$kibanaPassword

# Create the Elastic secret for later use in the Fluentd Setup.
kubectl create secret generic elastic-password -n logging --from-literal password=$elasticPassword
```

## Kibana.
Kibana is a data visualization and management web application for the Elastic Search engine. In the use case of log aggregation in a Kubernetes cluster, Kiabana is used to replace a user interface like Splunk, and make use of the visual tools to compose the queries against the indices.

The only notable configuration are the references to the Elastic Search service (proxy'd by the Client node) and the reference to the Kubernetes secret set up above.

```yaml
- name: kibana
    image: docker.elastic.co/kibana/kibana:7.7.0
    ports:
    - containerPort: 5601
        name: webinterface
    env:
    - name: ELASTICSEARCH_HOSTS
        value: "http://elasticsearch-client.logging.svc.cluster.local:9200"
    - name: ELASTICSEARCH_USER
        value: "kibana"
    - name: ELASTICSEARCH_PASSWORD
        valueFrom:
        secretKeyRef:
            name: kibana-password
            key: password
```

## Fluentd
Fluentd is a log agreggator service that mediates between different data sources and destinations. Fluentd is a graduated project form the CNCF, so it's considered safe in production. In the case of the overall example, the source will be the stdout of the nodes where our applications will be deployed and the destination will be Elastic Search.

In order for Fluentd to aggregate and pipe the console output in workloads deployed in the cluster, the most sensible option is to deploy this component as a DaemonSet, so that it is tied to the lifecycle of nodes instead of pods, as it would be the case with log aggregation provided by service mesh, which is done at the pod level.

The most relevant configuration is:
```yaml
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: logging
  labels:
    k8s-app: fluentd-logging
    version: v1
    kubernetes.io/cluster-service: "true"
```

Also notice the use of the secret that was created earlier with the elastic password:
```yaml
env:
    - name: FLUENT_ELASTICSEARCH_HOST
        value: "elasticsearch-client.logging.svc.cluster.local"
    - name: FLUENT_ELASTICSEARCH_PORT
        value: "9200"
    - name: FLUENT_ELASTICSEARCH_SCHEME
        value: "http"
    - name: FLUENT_ELASTICSEARCH_USER
        value: "elastic"
    - name: FLUENT_ELASTICSEARCH_PASSWORD
        valueFrom:
        secretKeyRef:
            name: elastic-password
            key: password
```

