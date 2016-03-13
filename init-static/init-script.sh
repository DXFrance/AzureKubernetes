#!/bin/bash

function dummy()
{
  echo "$*" > /dev/null
}

# Pocess Template
render_template() {
  eval "echo \"$(cat "$1")\""
}

# Generate etcd template
function gen_tpl_etcd()
{
  str="Environment=ETCD_INITIAL_CLUSTER="
  Etc_Host=""
  Etc_Host=$(printf " \n")
  j=0
  for i in $(seq 1 "${etcd_node}")
  do
   let j=$i-1
   let ip=$i+3
   str="$str${prefix}-etcd0${j}=http://${prefix}-etcd0${j}:2380,"
   Etc_Host=$(printf "      %s  %s\n%s" "172.16.0.${ip}"  "${prefix}-etcd0${j}" "$Etc_Host")
  done
   Environment="${str::-1}"
   export Environment
   export Etc_Host
   render_template "${tpl_etcd}" > "${cust_etcd}"
}

# Generate kube template
function gen_tpl_kube()
{
  ConditionHost="${prefix}-kube00"
  cp /dev/null "${tmp_wave}"
  j=0
  str="Environment=ETCD_INITIAL_CLUSTER="
  for i in $(seq 1 "${kube_node}")
  do
   let j=$i-1
   BREAKOUT_ROUTE="10.2.0.0/16"
   BRIDGE_ADDRESS_CIDR="10.2.${j}.1/24"
   if [ "$i" = "0" ]; then
    WEAVE_PEERS=""
   else
    WEAVE_PEERS="${prefix}-kube00"
   fi
   render_template "${tpl_wave}" >> "${tmp_wave}"
   str="$str${prefix}-kube0${j}=http://${prefix}-kube0${j}:4001,"
  done

  Environment="${str::-1}"

  render_template "${tpl_sky_rc}"  >> "${tmp_sky_rc}"
  render_template "${tpl_sky_svc}" >> "${tmp_sky_svc}"

  cat "${tmp_sky_rc}"  >> "${tmp_wave}"
  cat "${tmp_sky_svc}" >> "${tmp_wave}"

  Wave_Env=$(cat "${tmp_wave}")

  export Wave_Env
  render_template "${tpl_kube}" > "${cust_kube}"
}

#  Create resource group
function create_resource_group()
{
  azure group create "${prefix}" "${location}"
}

# Cretae availset 
function create_avail_set()
{
  azure availset create "${prefix}" "${prefix}-av-etcd" "${location}"
  azure availset create "${prefix}" "${prefix}-av-kube" "${location}"
}

# create vnet
function create_vnet()
{
  azure network vnet create "${prefix}" -n "${prefix}-vnet" -l "${location}" -a "172.16.0.0/12" -d "8.8.8.8"
}

# create subnet
function create_subnet()
{
  azure network vnet subnet create "${prefix}" "${prefix}-vnet" -n "${prefix}-sn" -a "172.16.0.0/24" 
}

# create Public IP  etcd / kube
function create_public_ip()
{
  azure network public-ip create "${prefix}" "${prefix}-pip-etcd" "${location}" -a Dynamic -d "${prefix}-etcd"
  azure network public-ip create "${prefix}" "${prefix}-pip-kube" "${location}" -a Dynamic -d "${prefix}-kube"
}

# Create Load balancer for etcd /kube
function create_lb()
{
  azure network lb create "${prefix}" "${prefix}-lb-etcd" "${location}"
  azure network lb create "${prefix}" "${prefix}-lb-kube" "${location}"
}

# create front-ip etcd / kubernetes
function create_front_ip()
{
  azure network lb frontend-ip create \
      "${prefix}" "${prefix}-lb-etcd" "${prefix}-fip-etcd"  --public-ip-name "${prefix}-pip-etcd"

  azure network lb frontend-ip create \
      "${prefix}" "${prefix}-lb-kube" "${prefix}-fip-kube"  --public-ip-name "${prefix}-pip-kube"
}
function create_bk_pool()
{
  # Create backend pool for etcd /kube
  azure network lb address-pool create "${prefix}" "${prefix}-lb-etcd" "${prefix}-bp-etcd"
  azure network lb address-pool create "${prefix}" "${prefix}-lb-kube" "${prefix}-bp-kube"
}

  # inbound nat for etcd  / ssh
function create_inbound_nat_rules()
{
  j=0
  for i in $(seq 1 "${etcd_node}")
  do
    let j=$i-1
    azure network lb inbound-nat-rule create -g "${prefix}" -l "${prefix}-lb-etcd" -n "ssh-etcd${i}" -p tcp -f 220${j} -b 22
  done

  # inbound nat for kube  / ssh
  j=0
  for i in $(seq 1 "${kube_node}")
  do
    let j=$i-1
    azure network lb inbound-nat-rule create -g "${prefix}" -l "${prefix}-lb-kube" -n "ssh-kube${i}" -p tcp -f 220${j} -b 22
  done
}

# create nics
function create_nics()
{
  # create etcd nics
  for i in $(seq 1 "${etcd_node}")
  do
    azure network nic create \
      -g "${prefix}" \
      -n "${prefix}-nic-etcd-${i}" \
      --subnet-name "${prefix}-sn" \
      --subnet-vnet-name "${prefix}-vnet" \
      -d "/subscriptions/${sub}/resourceGroups/${prefix}/providers/Microsoft.Network/loadbalancers/${prefix}-lb-etcd/backendAddressPools/${prefix}-bp-etcd" \
      -e "/subscriptions/${sub}/resourceGroups/${prefix}/providers/Microsoft.Network/loadBalancers/${prefix}-lb-etcd/inboundNatRules/ssh-etcd${i}" \
      "${location}"
  done 

  # create kube  nics
  for i in $(seq 1 "${kube_node}")
  do
    azure network nic create \
      -g "${prefix}" \
      -n "${prefix}-nic-kube-${i}" \
      --subnet-name "${prefix}-sn" \
      --subnet-vnet-name "${prefix}-vnet" \
      -d "/subscriptions/${sub}/resourceGroups/${prefix}/providers/Microsoft.Network/loadbalancers/${prefix}-lb-kube/backendAddressPools/${prefix}-bp-kube" \
      -e "/subscriptions/${sub}/resourceGroups/${prefix}/providers/Microsoft.Network/loadBalancers/${prefix}-lb-kube/inboundNatRules/ssh-kube${i}" \
      "${location}"
  done 
}

function create_vm()
{
  j=0
  # create etcd VM
  for i in $(seq 1 "${etcd_node}")
  do
  let j=$i-1     
  azure vm create \
      -g "${prefix}" \
      -l "${location}" \
      -n "${prefix}-etcd0${j}" \
      -u "${user}" \
      -p "${password}" \
      -w "${prefix}-etcd0${j}" \
      -M "${ssh_pub}" \
      -z standard_a1 \
      -y linux \
      -Q "CoreOs:CoreOS:Beta:899.6.0" \
      -N "${prefix}-nic-etcd-${i}" \
      --availset-name "${prefix}-av-etcd" \
      --vnet-name "${prefix}-vnet" \
      --vnet-subnet-name "${prefix}-sn" \
      --custom-data "./custom-data/kubernetes-cluster-etcd-nodes.yml"
  done

  j=0
  # create kube VM
  for i in $(seq 1 "${kube_node}")
  do
  let j=$i-1     
  azure vm create \
      -g "${prefix}" \
      -l "${location}" \
      -n "${prefix}-kube0${j}" \
      -u "${user}" \
      -p "${password}" \
      -w "${prefix}-kube0${j}" \
      -M "${ssh_pub}" \
      -z standard_a1 \
      -y linux \
      -Q "CoreOs:CoreOS:Beta:899.6.0" \
      -N "${prefix}-nic-kube-${i}" \
      --availset-name "${prefix}-av-kube" \
      --vnet-name "${prefix}-vnet" \
      --vnet-subnet-name "${prefix}-sn" \
      --custom-data "./custom-data/kubernetes-cluster-main-nodes-template.yml"
  done
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
tpl_kube="templates/kubernetes-cluster-main-nodes-template.yml.tpl"
cust_kube="custom-data/kubernetes-cluster-main-nodes-template.yml"
tpl_wave="templates/weave-env.yml.tpl"
tmp_wave="/tmp/weave-env.yml"

tpl_sky_rc="templates/addons/skydns-rc.yaml.tpl"
tpl_sky_svc="templates/addons/skydns-svc.yaml.tpl"
tmp_sky_rc="/tmp/sky-rc.yml"
tmp_sky_svc="/tmp/sky-svc.yml"

# Number of nodes
etcd_node=3
kube_node=3

# just to avoid shellcheck warning
ConditionHost=""
BREAKOUT_ROUTE=""
BRIDGE_ADDRESS_CIDR=""
WEAVE_PEERS=""
dummy "${ConditionHost}" "${BREAKOUT_ROUTE}" "${BRIDGE_ADDRESS_CIDR}" "${WEAVE_PEERS}"


### IT BEGINS HERE !
# Generate custom data from template
gen_tpl_etcd
gen_tpl_kube

create_resource_group
create_avail_set
create_vnet
create_subnet
create_public_ip
create_lb
create_front_ip
create_bk_pool
create_inbound_nat_rules
create_nics
create_vm



#azure vm extension set zwkubernetes zwkubernetes-etcd00  CustomScriptForLinux Microsoft.OSTCExtensions 1.4

