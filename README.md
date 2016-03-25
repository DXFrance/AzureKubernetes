# AzureKubernetes
Kubernetes provisioning template

                          ┌───────────────────────────────┐
                          │                            ┌─┐│
                          │                            │1││
                          │      ┌─────────────────┐   └─┘│
                          │      │┌────────────────┴┐     │
                          │      └┤┌────────────────┴┐    │
             ┌────────────┼───────▶┤    etcd srv     │    │
             │            │        └─────────────────┘    │
             │            │                               │
             │            │                               │
             │            │      ┌─────────────────┐      │
             │            │      │┌────────────────┴┐     │
             │            │      └┤┌────────────────┴┐    │◀─┐
             │            │ ┌────▶└┤  k8 master srv  │    │  │
             │            │ │      └─────────────────┘    │  │
    ┌─────────────────┐   │ │                             │  │
    │azuredeploy.json │───┼─┤                             │  │
    └─────────────────┘   │ │    ┌─────────────────┐      │  │
             │            │ │    │┌────────────────┴┐     │  │
             │            │ │    └┤┌────────────────┴┐    │  │
             │            │ └────▶└┤ k8 minions srv  │    │  │
             │            │        └─────────────────┘    │  │
             │            │                               │  │
             │            │                               │  │
             │            └───────────────────────────────┘  │
             │                                               │
             │            ┌───────────────────────────────┐  │
             │            │                            ┌─┐│  │
             │            │        ┌─────────────────┐ │2││  │
             └────────────┼───────▶│ Ansible Bastion │ └─┘│  │
                          │        └─────────────────┘    │──┘
                          │         ansible playbook      │
                          │       to deploy k8 cluster    │
                          └───────────────────────────────┘

arm:  
  - first deploy:
    - n etcd servers  
    - n masters kubernetes masters  
    - n minions kubernetes minions  
    on each node the script first-boot.sh is played to register the ip and the role of the node  
  - then deploy:  
    - 1 ansible command control vm  




### azure-cli : 
```bash
azure group create kuber8grp northeurope
azure group deployment create kuber8grp kuber8cluster --template-uri https://raw.githubusercontent.com/DXFrance/AzureKubernetes/master/Kubernetes-Ansible-Centos-Azure/azuredeploy.json

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FDXFrance%2FAzureKubernetes%2Fmaster%2FKubernetes-Ansible-Centos-Azure%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https://raw.githubusercontent.com/DXFrance/AzureKubernetes/master/Kubernetes-Ansible-Centos-Azure/azuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>