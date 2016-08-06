#!/bin/bash

function usage()
 {
    echo "INFO:"
    echo "Usage: config-ansible.sh [number of Masters] [number of Minions] [number of Etdc Nodes]"
	echo "       [Masters subnet] [Minions subnet] [Etcd Subnet] [vm prefix] [fqdn of ansible control vm]"
	echo "       [ansible user] [Key storage account name] [Key storage account key]"
}

function error_log()
{
    if [ "$?" != "0" ]; then
        log "$1" "1"
        log "Deployment ends with an error" "1"
        exit 1
    fi
}

function log()
{
	
  x=":ok:"

  if [ "$2" = "x" ]; then
    x=":question:"
  fi

  if [ "$2" != "0" ]; then
    if [ "$2" = "N" ]; then
       x=""
    else
       x=":japanese_goblin:"
    fi
  fi
  mess="$(date) - $(hostname): $1 $x"

  payload="payload={\"icon_emoji\":\":cloud:\",\"text\":\"$mess\"}"
  curl -s -X POST --data-urlencode "$payload" "$LOG_URL" > /dev/null 2>&1
    
  echo "$(date) : $1"
}

function install_epel_repo()
{
   rpm -iUvh "${EPEL_REPO}"
}

function install_curl()
{
  # Installation of curl for logging
  until yum install -y curl 
  do
    log "Lock detected on yum install VM init Try again..."
    sleep 2
  done
}

function generate_sshkeys()
{
  echo -e 'y\n'|ssh-keygen -b 4096 -f idgen_rsa -t rsa -q -N ''
}


function ssh_config()
{
  # log "tld is ${tld}"
  log "Configure ssh..." "0"
  
  mkdir -p ~/.ssh

  # Root User
  # No host Checking for root 

  log "Create ssh configuration for root" "0"
  cat << 'EOF' >> ~/.ssh/config
Host *
    user devops
    StrictHostKeyChecking no
EOF

  error_log "Unable to create ssh config file for root"

  log "Copy generated keys..." "0"

  cp idgen_rsa ~/.ssh/idgen_rsa
  error_log "Unable to copy idgen_rsa key to root .ssh directory"

  cp idgen_rsa.pub ~/.ssh/idgen_rsa.pub
  error_log "Unable to copy idgen_rsa.pub key to root .ssh directory"

  chmod 700 ~/.ssh
  error_log "Unable to chmod root .ssh directory"

  chmod 400 ~/.ssh/idgen_rsa
  error_log "Unable to chmod root idgen_rsa file"

  chmod 644 ~/.ssh/idgen_rsa.pub
  error_log "Unable to chmod root idgen_rsa.pub file"

  ## Devops User
  # No host Checking for sshu 

  log "Create ssh configuration for ${sshu}" "0"
  cat << 'EOF' >> /home/${sshu}/.ssh/config
Host *
    user devops
    StrictHostKeyChecking no
EOF

  error_log "Unable to create ssh config file for user ${sshu}"

  cp idgen_rsa "/home/${sshu}/.ssh/idgen_rsa"
  error_log "Unable to copy idgen_rsa key to $sshu .ssh directory"

  cp idgen_rsa.pub "/home/${sshu}/.ssh/idgen_rsa.pub"
  error_log "Unable to copy idgen_rsa.pub key to $sshu .ssh directory"

  chmod 700 "/home/${sshu}/.ssh"
  error_log "Unable to chmod $sshu .ssh directory"

  chown -R "${sshu}:" "/home/${sshu}/.ssh"
  error_log "Unable to chown to $sshu .ssh directory"

  chmod 400 "/home/${sshu}/.ssh/idgen_rsa"
  error_log "Unable to chmod $sshu idgen_rsa file"

  chmod 644 "/home/${sshu}/.ssh/idgen_rsa.pub"
  error_log "Unable to chmod $sshu idgen_rsa.pub file"
  
  # remove when debugging
  # rm idgen_rsa idgen_rsa.pub 
}


function add_hosts()
{
  log "Add cluster hosts private Ips..." "0"

  # Masters
  let numberOfMasters=$numberOfMasters-1
  
  for i in $(seq 0 $numberOfMasters)
  do
    let j=4+$i
	echo "${subnetMasters3}.${j},masters" >>  /tmp/hosts.inv 
  done

  # Minions
  let numberOfMinions=$numberOfMinions-1
  
  for i in $(seq 0 $numberOfMinions)
  do
    let j=4+$i
	echo "${subnetMinions3}.${j},minions" >>  /tmp/hosts.inv 
  done

  # Etcd
  let numberOfEtcd=$numberOfEtcd-1
  
  for i in $(seq 0 $numberOfEtcd)
  do
    let j=4+$i
	echo "${subnetEtcd3}.${j},etcd" >>  /tmp/hosts.inv 
  done
  
}

function update_centos_distribution()
{
log "Update Centos distribution..." "0"
until yum -y update --exclude=WALinuxAgent
do
log "Lock detected on VM init Try again..." "0"
sleep 2
done
error_log "unable to update system"
}

function fix_etc_hosts()
{
	log "Add hostame and ip in hosts file ..." "0"
	IP=$(ip addr show eth0 | grep inet | grep -v inet6 | awk '{ print $2; }' | sed 's?/.*$??')
	HOST=$(hostname)
	echo "${IP}" "${HOST}" | sudo tee -a "${HOST_FILE}"
}

function install_required_groups()
{
  log "Install ansible required groups..." "0"
  until yum -y group install "Development Tools"
  do
    log "Lock detected on VM init Try again..." "0"
    sleep 2
  done
  error_log "unable to get group packages"
}

function install_required_packages()
{

  log "Install ansible required packages..." "0"
  until yum install -y git python2-devel python-pip libffi-devel libssl-dev openssl-devel
  do
    log "Lock detected on VM init Try again..." "0"
    sleep 2
  done
  error_log "Unable to get system packages"
}

function install_python_modules()
{
  log "Install ansible required python modules..." "0"
  pip install PyYAML jinja2 paramiko
  error_log "Unable to install python packages via pip"

  log "upgrading pip" "0"
  pip install --upgrade pip
  log "Install azure storage python module via pip..." "0"
  pip install azure-storage
}

function put_sshkeys()
 {
  
  log "Push ssh keys to Azure Storage" "0"
  python WriteSSHToPrivateStorage.py "${STORAGE_ACCOUNT_NAME}" "${STORAGE_ACCOUNT_KEY}" idgen_rsa
  error_log "Unable to write idgen_rsa to storage account ${STORAGE_ACCOUNT_NAME}"
  python WriteSSHToPrivateStorage.py "${STORAGE_ACCOUNT_NAME}" "${STORAGE_ACCOUNT_KEY}" idgen_rsa.pub
  error_log "Unable to write idgen_rsa.pub to storage account ${STORAGE_ACCOUNT_NAME}"
}

function install_ansible()
{
  log "Clone ansible repo..." "0"
  rm -rf ansible
  error_log "Unable to remove ansible directory"

  git clone https://github.com/ansible/ansible.git --depth 1
  error_log "Unable to clone ansible repo"

  cd ansible || error_log "Unable to cd to ansible directory"

  log "Clone ansible submodules..." "0"
  git submodule update --init --recursive
  error_log "Unable to clone ansible submodules"

  log "Install ansible..." "0"
  make install
  error_log "Unable to install ansible"
}


function configure_ansible()
{
  log "Generate ansible files..." "0"
  rm -rf /etc/ansible
  error_log "Unable to remove /etc/ansible directory"
  mkdir -p /etc/ansible
  error_log "Unable to create /etc/ansible directory"

  cp examples/hosts /etc/ansible/.
  error_log "Unable to copy hosts file to /etc/ansible"

  #printf "[localhost]\n127.0.0.1\n\n"                      >> "${ANSIBLE_HOST_FILE}"
  printf "[defaults]\ndeprecation_warnings=False\n\n"      >> "${ANSIBLE_CONFIG_FILE}"
  
  # Accept ssh keys by default    
  printf  "[defaults]\nhost_key_checking = False\n\n" >> "${ANSIBLE_CONFIG_FILE}"   
  # Shorten the ControlPath to avoid errors with long host names , long user names or deeply nested home directories
  echo  $'[ssh_connection]\ncontrol_path = ~/.ssh/ansible-%%h-%%r' >> "${ANSIBLE_CONFIG_FILE}"   
}

function test_ansible()
{
  log "Test ansible..." "0"
  mess=$(ansible masters -m ping)
  log "$mess" "0"
  mess=$(ansible minions -m ping)
  log "$mess" "0"
  mess=$(ansible etcd -m ping)
  log "$mess" "0"
}

function install_ansible_slack_callback()
{
  log "Install ansible callback..." "0"

  mkdir -p "/usr/share/ansible_plugins/callback_plugins"
  error_log "Unable to create callback plugin"
  cd "$CWD" || error_log "unable to back with cd .."
  cd "$local_kub8/$slack_repo" || error_log "unable to back with cd $local_kub8/$slack_repo"
  pip install -r requirements.txt
  cp slack-logger.py /usr/share/ansible_plugins/callback_plugins/slack-logger.py
}

function create_inventory()
{
  log "Create ansible inventory..." "0"

  masters=""
  etcd=""
  minions=""

  for i in $(cat /tmp/hosts.inv)
  do
    ip=$(echo "$i"|cut -f1 -d,)
    role=$(echo "$i"|cut -f2 -d,)

    if [ "$role" = "masters" ]; then
      masters=$(printf "%s\n%s" "${masters}" "${ip}")
    elif [ "$role" = "etcd" ]; then
      etcd=$(printf "%s\n%s" "${etcd}" "${ip}")
    elif [ "$role" = "minions" ]; then
      minions=$(printf "%s\n%s" "${minions}" "${ip}")
    fi
  done

  printf "[masters]%s\n" "${masters}" >> "${ANSIBLE_HOST_FILE}"
  printf "[minions]%s\n" "${minions}" >> "${ANSIBLE_HOST_FILE}"
  printf "[etcd]%s\n" "${etcd}"       >> "${ANSIBLE_HOST_FILE}"

  error_log "unable to create hosts file entries to /etc/ansible"

}

function get_kube_playbook()
{
  log "Get kubernetes playbook from $local_kub8/$repo_name" "0"

  cd "$CWD" || error_log "unable to back with cd .."  
  rm -f kub8
  git clone "${GIT_KUB8_URL}" "$local_kub8"
  cd "$local_kub8" || error_log "unable to change to directory $local_kub8"
  git submodule update --init --recursive
  error_log "Error fetching submodules"
}

function get_slack_token()
{
  # this function get the slack incoming WebHook token in order to set the SLACK_TOKEN 
  # environment variable in order to use slack-ansible-plugin

  # token=$(grep "token:" slack-token.tok | cut -f2 -d:)
  # base64 encoding in order to avoid to handle vm extension fileuris parameters outside of github
  # because github forbids token archiving
  # the alternative would be to put a file in a vault or a storage account and copy this file from 
  # the config-ansible.sh (deployment through fileuris mechanism would also present an issue because
  # it seems currently impossible to use both github and a storage account in the fileuris list)
  log "Get slack token for incoming WebHook" "0"
  encoded="AHRva2VuOnhveHAtMjYxMTYwNzgxMzItMjYxMTc3ODg3NzItNDAwMDY4MDY0NjUtZjgwZTI3MzFmMw=="
  token=$(base64 -d -i <<<"$encoded")
  echo "$token"
}

function deploy()
{
  log "Ansible deploy integrated-wait-deploy.yml playbook (git submodule)" "0"
  cd "$CWD" || error_log "unable to back with cd $CWD"  
  cd "$local_kub8/$repo_name" || error_log "unable to back with cd $local_kub8/$repo_name"
  log "Playing playbook" "0"
  ansible-playbook -i "${ANSIBLE_HOST_FILE}" integrated-wait-deploy.yml | tee -a /tmp/deploy-"${LOG_DATE}".log
  error_log "playbook kubernetes integrated-wait-deploy.yml had errors"
}


### PARAMETERS

numberOfMasters="${1}"
numberOfMinions="${2}"
numberOfEtcd="${3}"

subnetMasters="${4}"
subnetMinions="${5}"
subnetEtcd="${6}"

vmNamePrefix="${7}"
ansiblefqdn="${8}"
sshu="${9}"
viplb="${10}"

STORAGE_ACCOUNT_NAME="${11}"
STORAGE_ACCOUNT_KEY="${12}"

LOG_DATE=$(date +%s)
FACTS="/etc/ansible/facts"
ANSIBLE_HOST_FILE="/etc/ansible/hosts"
ANSIBLE_CONFIG_FILE="/etc/ansible/ansible.cfg"

GIT_KUB8_URL="https://github.com/DXFrance/AzureKubernetes.git"

EPEL_REPO="http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-7.noarch.rpm"

#LOG_URL="https://rocket.alterway.fr/hooks/44vAPspqqtD7Jtmtv/k4Tw89EoXiT5GpniG/HaxMfijFFi5v1YTEN68DOe5fzFBBxB4YeTQz6w3khFE%3D"
LOG_URL="https://hooks.slack.com/services/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"

# Slack notification
SLACK_TOKEN="$(get_slack_token)"
SLACK_CHANNEL="ansible"

export SLACK_TOKEN SLACK_CHANNEL

## Repos Variables
local_kub8="kub8"
repo_name="ansible-kubernetes-centos"
slack_repo="slack-ansible-plugin"

ansible_hostname=$(echo "$ansiblefqdn" | cut -f1 -d.)
tld=$(echo "$ansiblefqdn"  | sed "s?${ansible_hostname}\.??")

CWD="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
export FACTS

subnetMasters=$(echo "${subnetMasters}"| cut -f1 -d/)
subnetMinions=$(echo "${subnetMinions}"| cut -f1 -d/)
subnetEtcd=$(echo "${subnetEtcd}"| cut -f1 -d/)

subnetMasters3=$(echo "${subnetMasters}"| cut -f1,2,3 -d.)
subnetMinions3=$(echo "${subnetMinions}"| cut -f1,2,3 -d.)
subnetEtcd3=$(echo "${subnetEtcd}"| cut -f1,2,3 -d.)


### It begins here

log "*BEGIN* Installation Kubernetes Cluster on Azure" "N"
log "  Parameters : " "N"
log "    - Number Of Masters  $numberOfMasters" "N"
log "    - Number Of Minions  $numberOfMinions" "N"
log "    - Number Of Etcd     $numberOfEtcd" "N"
log "    - Masters Subnet is  $subnetMasters" "N"
log "    - Minions Subnet is  $subnetMinions" "N"
log "    - Etcd Subnet    is  $subnetEtcd" "N"
log "    - VM Suffix          $vmNamePrefix" "N"
log "    - Ansible Jumpbox VM $ansiblefqdn" "N"
log "    - STORAGE_ACCOUNT_NAME $STORAGE_ACCOUNT_NAME" "N"
log "    - STORAGE_ACCOUNT_KEY  $STORAGE_ACCOUNT_KEY" "N"


install_epel_repo
install_curl
generate_sshkeys
ssh_config
add_hosts
update_centos_distribution
fix_etc_hosts
install_required_groups
install_required_packages
install_python_modules
put_sshkeys
install_ansible
configure_ansible
create_inventory
test_ansible
get_kube_playbook
install_ansible_slack_callback
deploy

log "Success : End of Execution of Install Script from config-ansible" "0"
