#!/bin/bash

render_template() {
  eval "echo \"$(cat $1)\""
}

function gen_tpl_etcd()
{
  str="Environment=ETCD_INITIAL_CLUSTER="
  Etc_Host=""
  Etc_Host=$(printf " \n")
  j=0
  for i in $(seq 1 $etcd_node)
  do
   let j=$i-1
   let ip=$i+3
   str="$str${prefix}-etcd0${j}=http://${prefix}-etcd0${j}:2380,"
   Etc_Host=$(printf "      172.16.0.${ip}  ${prefix}-etcd0${j}\n$Etc_Host")
  done
   Environment=$(echo "${str::-1}")
   export Environment
   export Etc_Host
   render_template templates/kubernetes-cluster-etcd-nodes.yml.tpl > custom-data/kubernetes-cluster-etcd-nodes.yml
}


prefix="zwkubernetes"
sub="fb79eb46-411c-4097-86ba-801dca0ff5d5"


etcd_node=3
kub_node=3


gen_tpl_etcd

#  Create resource group
azure group create ${prefix} northeurope

# availset 
azure availset create ${prefix} ${prefix}-av-etcd northeurope
azure availset create ${prefix} ${prefix}-av-kub northeurope

# create vnet
azure network vnet create ${prefix} -n ${prefix}-vnet -l northeurope -a "172.16.0.0/12" -d "8.8.8.8"

# create subnet
azure network vnet subnet create "${prefix}" "${prefix}-vnet" -n "${prefix}-sn" -a "172.16.0.0/24" 

# create Public IP  etcd / kub
azure network public-ip create "${prefix}" "${prefix}"-pip-etcd northeurope -a Dynamic -d "${prefix}"-etcd

azure network public-ip create "${prefix}" "${prefix}"-pip-kub northeurope -a Dynamic -d "${prefix}"-kub

# Create Load balancer for etcd
azure network lb create "${prefix}" "${prefix}"-lb-etcd northeurope

# Create Load balancer for kub
azure network lb create "${prefix}" "${prefix}"-lb-kub northeurope

# create front-ip etcd
azure network lb frontend-ip create \
      "${prefix}" "${prefix}"-lb-etcd "${prefix}"-fip-etcd  --public-ip-name "${prefix}"-pip-etcd

# create front-ip kubernetes
azure network lb frontend-ip create \
      "${prefix}" "${prefix}"-lb-kub "${prefix}"-fip-kub  --public-ip-name "${prefix}"-pip-kub

# Create backend pool for etcd
azure network lb address-pool create "${prefix}" "${prefix}"-lb-etcd "${prefix}"-bp-etcd

# Create backend pool for kub
azure network lb address-pool create "${prefix}" "${prefix}"-lb-kub "${prefix}"-bp-kub


# inbound nat for etcd  / ssh
azure network lb inbound-nat-rule create -g "${prefix}" -l "${prefix}"-lb-etcd -n ssh-etcd1 -p tcp -f 2200 -b 22
azure network lb inbound-nat-rule create -g "${prefix}" -l "${prefix}"-lb-etcd -n ssh-etcd2 -p tcp -f 2201 -b 22
azure network lb inbound-nat-rule create -g "${prefix}" -l "${prefix}"-lb-etcd -n ssh-etcd3 -p tcp -f 2202 -b 22

# inbound nat for kub  / ssh
azure network lb inbound-nat-rule create -g "${prefix}" -l "${prefix}"-lb-kub -n ssh-kub1 -p tcp -f 2200 -b 22
azure network lb inbound-nat-rule create -g "${prefix}" -l "${prefix}"-lb-kub -n ssh-kub2 -p tcp -f 2201 -b 22
azure network lb inbound-nat-rule create -g "${prefix}" -l "${prefix}"-lb-kub -n ssh-kub3 -p tcp -f 2202 -b 22

# create etcd nics

for i in $(seq 1 $etcd_node)
do
  azure network nic create \
      -g "${prefix}" \
      -n "${prefix}"-nic-etcd-$i \
      --subnet-name "${prefix}-sn" \
      --subnet-vnet-name "${prefix}-vnet" \
      -d "/subscriptions/${sub}/resourceGroups/${prefix}/providers/Microsoft.Network/loadbalancers/${prefix}-lb-etcd/backendAddressPools/${prefix}-bp-etcd" \
      -e "/subscriptions/${sub}/resourceGroups/${prefix}/providers/Microsoft.Network/loadBalancers/${prefix}-lb-etcd/inboundNatRules/ssh-etcd${i}" \
     northeurope
done 

j=0
# create VM
for i in $(seq 1 $etcd_node)
do
let j=$i-1     
azure vm create \
      -g ${prefix} \
      -l northeurope \
      -n ${prefix}-etcd0${j} \
      -u devops \
      -p VeL0c1RaPt0R# \
      -w ${prefix}-etcd0${j} \
      -M /Users/hleclerc/.ssh/id_rsa.pub \
      -z standard_a1 \
      -y linux \
      -Q "CoreOs:CoreOS:Beta:899.6.0" \
      -N ${prefix}-nic-etcd-${i} \
      --availset-name ${prefix}-av-etcd \
      --vnet-name ${prefix}-vnet \
      --vnet-subnet-name ${prefix}-sn \
      --custom-data "./custom-data/kubernetes-cluster-etcd-nodes.yml"
done


azure vm extension set zwkubernetes zwkubernetes-etcd00  CustomScriptForLinux Microsoft.OSTCExtensions 1.4

