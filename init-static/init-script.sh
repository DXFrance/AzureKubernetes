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
   
}

function gen_tpl_kub()
{
  j=0
  str="Environment=ETCD_INITIAL_CLUSTER="
  for i in $(seq 1 $etcd_node)
  do
   let j=$i-1
   BREAKOUT_ROUTE="10.2.0.0/16"
   BRIDGE_ADDRESS_CIDR="10.2.${j}.1/24"
   if [ "$i" = "0" ]; then
    WEAVE_PEERS=""
   else
    WEAVE_PEERS="${prefix}-kub00"
   fi
   render_template ${tpl_wave} >> ${tmp_wave}
   str="$str${prefix}-etcd0${j}=http://${prefix}-etcd0${j}:4001,"
  done
  
  Environment=$(echo "${str:
  Wave_Env=$(cat "${tmp_wave}")

  ConditionHost="${prefix}-kub00"

  export Wave_Env
  render_template ${tpl_kub} > ${cust_kub}
}

# Variables
prefix="zwkubernetes"
sub="fb79eb46-411c-4097-86ba-801dca0ff5d5"
ssh_pub="/Users/hleclerc/.ssh/id_rsa.pub"
location="northeurope"
user="devops"
password="VeL0c1RaPt0R#"
tpl_etcd="templates/kubernetes-cluster-etcd-nodes.yml.tpl"
cust_etcd="custom-data/kubernetes-cluster-etcd-nodes.yml"
tpl_kub="templates/kubernetes-cluster-main-nodes-template.yml.tpl"
cust_kub="custom-data/kubernetes-cluster-main-nodes-template.yml"
tpl_wave="templates/weave-env.yml.tpl"
tmp_wave="/tmp/weave-env.yml"



etcd_node=3
kub_node=3

# Generate custom data from template
gen_tpl_etcd
gen_tpl_kub

exit 0

#  Create resource group
azure group create ${prefix} ${location}

# availset 
azure availset create ${prefix} ${prefix}-av-etcd ${location}
azure availset create ${prefix} ${prefix}-av-kub ${location}

# create vnet
azure network vnet create ${prefix} -n ${prefix}-vnet -l ${location} -a "172.16.0.0/12" -d "8.8.8.8"

# create subnet
azure network vnet subnet create "${prefix}" "${prefix}-vnet" -n "${prefix}-sn" -a "172.16.0.0/24" 

# create Public IP  etcd / kub
azure network public-ip create "${prefix}" "${prefix}"-pip-etcd ${location} -a Dynamic -d "${prefix}"-etcd

azure network public-ip create "${prefix}" "${prefix}"-pip-kub ${location} -a Dynamic -d "${prefix}"-kub

# Create Load balancer for etcd
azure network lb create "${prefix}" "${prefix}"-lb-etcd ${location}

# Create Load balancer for kub
azure network lb create "${prefix}" "${prefix}"-lb-kub ${location}

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
j=0
for i in $(seq 1 $etcd_node)
do
  let j=$i-1
  azure network lb inbound-nat-rule create -g "${prefix}" -l "${prefix}"-lb-etcd -n ssh-etcd${i} -p tcp -f 220${j} -b 22
done

# inbound nat for kub  / ssh
j=0
for i in $(seq 1 $etcd_node)
do
  let j=$i-1
  azure network lb inbound-nat-rule create -g "${prefix}" -l "${prefix}"-lb-kub -n ssh-kub${i} -p tcp -f 220${j} -b 22
done
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
     ${location}
done 

j=0
# create VM
for i in $(seq 1 $etcd_node)
do
let j=$i-1     
azure vm create \
      -g ${prefix} \
      -l ${location} \
      -n ${prefix}-etcd0${j} \
      -u ${user} \
      -p ${password} \
      -w ${prefix}-etcd0${j} \
      -M ${ssh_pub} \
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

