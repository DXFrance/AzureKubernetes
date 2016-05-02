#!/bin/bash

error_log()
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

  if [ "x$2" = "x" ]; then
    x=":question:"
  fi

  if [ "$2" != "0" ]; then
    x=":hankey:"
  fi
  mess="$(date) - $(hostname): $1 $x"


  payload="payload={\"icon_emoji\":\":cloud:\",\"text\":\"$mess\"}"
  curl -s -X POST --data-urlencode "$payload" "$LOG_URL" > /dev/null 2>&1
    
  echo "$(date) : $1"
}


function usage()
 {
    echo "INFO:"
    echo "Usage: deploy.sh [number of nodes] [prefix des vm] [fqdn of ansible control vm] [ansible user]"
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
function ssh_config()
{
  # log "tld is ${tld}"
  log "configure ssh..." "0"
  
  mkdir -p ~/.ssh

  # Root User
  # No host Checking for root 

  log "Create ssh configuration for root" "0"
  cat << 'EOF' >> ~/.ssh/config
Host *
    user devops
    StrictHostKeyChecking no
EOF

  error_log "unable to create ssh config file for root"

  cp id_rsa ~/.ssh/id_rsa
  error_log "unable to copy id_rsa key to root .ssh directory"

  cp id_rsa.pub ~/.ssh/id_rsa.pub
  error_log "unable to copy id_rsa.pub key to root .ssh directory"

  chmod 700 ~/.ssh
  error_log "unable to chmod root .ssh directory"

  chmod 400 ~/.ssh/id_rsa
  error_log "unable to chmod root id_rsa file"

  chmod 644 ~/.ssh/id_rsa.pub
  error_log "unable to chmod root id_rsa.pub file"

  ## Devops User
  # No host Checking for sshu 

  log "Create ssh configuration for ${sshu}" "0"
  cat << 'EOF' >> /home/${sshu}/.ssh/config
Host *
    user devops
    StrictHostKeyChecking no
EOF

  error_log "unable to create ssh config file for user ${sshu}"

  cp id_rsa "/home/${sshu}/.ssh/id_rsa"
  error_log "unable to copy id_rsa key to $sshu .ssh directory"

  cp id_rsa.pub "/home/${sshu}/.ssh/id_rsa.pub"
  error_log "unable to copy id_rsa.pub key to $sshu .ssh directory"

  chmod 700 "/home/${sshu}/.ssh"
  error_log "unable to chmod $sshu .ssh directory"

  chown -R "${sshu}:" "/home/${sshu}/.ssh"
  error_log "unable to chown to $sshu .ssh directory"

  chmod 400 "/home/${sshu}/.ssh/id_rsa"
  error_log "unable to chmod $sshu id_rsa file"

  chmod 644 "/home/${sshu}/.ssh/id_rsa.pub"
  error_log "unable to chmod $sshu id_rsa.pub file"
  
  # remove when debugging
  # rm id_rsa id_rsa.pub 
}


function get_private_ip()
{
  log "Get private Ips..." "0"

  # Masters
  let numberOfMasters=$numberOfMasters-1
  
  for i in $(seq 0 $numberOfMasters)
  do
    let j=4+$i
  	su - "${sshu}" -c "ssh -l ${sshu} ${subnetMasters3}.${j} cat $FACTS/private-ip-role.fact" >> /tmp/hosts.inv 
    error_log "unable to ssh -l ${sshu} ${subnetMasters3}.${j}"
    su - "${sshu}" -c "scp /home/${sshu}/.ssh/id_rsa ${sshu}@${subnetMasters3}.${j}:/home/${sshu}/.ssh/id_rsa"
    error_log "unable to scp id_rsa to ${subnetMasters3}.${j}"
    su - "${sshu}" -c "scp /home/${sshu}/.ssh/id_rsa.pub ${sshu}@${subnetMasters3}.${j}:/home/${sshu}/.ssh/id_rsa.pub"
    error_log "unable to scp id_rsa.pub to ${subnetMasters3}.${j}"
    su - "${sshu}" -c "ssh -l ${sshu} ${subnetMasters3}.${j} chmod 400 /home/${sshu}/.ssh/id_rsa"
    error_log "unable to chmod id_rsa to ${subnetMasters3}.${j}"
  done

  # Minions
  let numberOfMinions=$numberOfMinions-1
  
  for i in $(seq 0 $numberOfMinions)
  do
    let j=4+$i
  	su - "${sshu}" -c "ssh -l ${sshu} ${subnetMinions3}.${j} cat $FACTS/private-ip-role.fact" >> /tmp/hosts.inv 
    error_log "unable to ssh -l ${sshu} ${subnetMinions3}.${j}"
    su - "${sshu}" -c "scp /home/${sshu}/.ssh/id_rsa ${sshu}@${subnetMinions3}.${j}:/home/${sshu}/.ssh/id_rsa"
    error_log "unable to scp id_rsa to ${subnetMinions3}.${j}"
    su - "${sshu}" -c "scp /home/${sshu}/.ssh/id_rsa.pub ${sshu}@${subnetMinions3}.${j}:/home/${sshu}/.ssh/id_rsa.pub"
    error_log "unable to scp id_rsa.pub to ${subnetMinions3}.${j}"
    su - "${sshu}" -c "ssh -l ${sshu} ${subnetMinions3}.${j} chmod 400 /home/${sshu}/.ssh/id_rsa"
    error_log "unable to chmod id_rsa to ${subnetMinions3}.${j}"
  done

  # Etcd
  let numberOfEtcd=$numberOfEtcd-1
  
  for i in $(seq 0 $numberOfEtcd)
  do
    let j=4+$i
  	su - "${sshu}" -c "ssh -l ${sshu} ${subnetEtcd3}.${j} cat $FACTS/private-ip-role.fact" >> /tmp/hosts.inv 
    error_log "unable to ssh -l ${sshu} ${subnetEtcd3}.${j}"
    su - "${sshu}" -c "scp /home/${sshu}/.ssh/id_rsa ${sshu}@${subnetEtcd3}.${j}:/home/${sshu}/.ssh/id_rsa"
    error_log "unable to scp id_rsa to ${subnetEtcd3}.${j}"
    su - "${sshu}" -c "scp /home/${sshu}/.ssh/id_rsa.pub ${sshu}@${subnetEtcd3}.${j}:/home/${sshu}/.ssh/id_rsa.pub"
    error_log "unable to scp id_rsa.pub to ${subnetEtcd3}.${j}"
    su - "${sshu}" -c "ssh -l ${sshu} ${subnetEtcd3}.${j} chmod 400 /home/${sshu}/.ssh/id_rsa"
    error_log "unable to chmod id_rsa to ${subnetEtcd3}.${j}"
  done
  
}

function install_epel_repo()
{
   rpm -iUvh "${EPEL_REPO}"
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
  error_log "unable to get system packages"
}

function install_python_modules()
{
  log "Install ansible required python modules..." "0"
  pip install PyYAML jinja2 paramiko
  error_log "unable to install python packages via pip"
}

function install_ansible()
{
  log "Clone ansible repo..." "0"
  rm -rf ansible
  error_log "unable to remove ansible directory"

  git clone https://github.com/ansible/ansible.git
  error_log "unable to clone ansible repo"

  cd ansible || error_log "unable to cd to ansible directory"

  log "Clone ansible submodules..." "0"
  git submodule update --init --recursive
  error_log "unable to clone ansible submodules"

  log "Install ansible..." "0"
  make install
  error_log "unable to install ansible"
}
function configure_ansible()
{
  log "Generate ansible files..." "0"
  rm -rf /etc/ansible
  error_log "unable to remove /etc/ansible directory"
  mkdir -p /etc/ansible
  error_log "unable to create /etc/ansible directory"

  cp examples/hosts /etc/ansible/.
  error_log "unable to copy hosts file to /etc/ansible"

  #printf "[localhost]\n127.0.0.1\n\n"                      >> "${ANSIBLE_HOST_FILE}"
  printf "[defaults]\ndeprecation_warnings=False\n\n"      >> "${ANSIBLE_CONFIG_FILE}"
  
  # Accept ssh keys by default    
  printf  "[defaults]\nhost_key_checking = False\n\n" >> "${ANSIBLE_CONFIG_FILE}"   
  # Shorten the ControlPath to avoid errors with long host names , long user names or deeply nested home directories
  echo  $'[ssh_connection]\ncontrol_path = ~/.ssh/ansible-%%h-%%r' >> "${ANSIBLE_CONFIG_FILE}"   
}

function test_ansible()
{
  mess=$(ansible cluster -m ping)
  log "$mess" "0"
}


function create_inventory()
{
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
  cd "$CWD" || error_log "unable to back with cd .."  
  rm -f kub8
  git clone "${GIT_KUB8_URL}" "$local_kub8"
}

function deploy()
{
  cd "$CWD" || error_log "unable to back with cd $CWD"  
  cd "$local_kub8" || error_log "unable to back with cd $local_kub8"  
  log "Playing playbook" "0"
  ansible-playbook -i "${ANSIBLE_HOST_FILE}" integrated-deploy.yml | tee -a /tmp/deploy-"${LOG_DATE}".log
  error_log "playbook kubernetes integrated-deploy.yml had errors"

  log "END Installation on Azure parameters : numberOfMasters=$numberOfMasters -  numberOfMinions=$numberOfMinions - numberOfEtcd=$numberOfEtcd" "0" 
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

LOG_DATE=$(date +%s)
FACTS="/etc/ansible/facts"
ANSIBLE_HOST_FILE="/etc/ansible/hosts"
ANSIBLE_CONFIG_FILE="/etc/ansible/ansible.cfg"
GIT_KUB8_URL="https://github.com/herveleclerc/ansible-kubernetes-centos.git"
EPEL_REPO="http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-6.noarch.rpm"

LOG_URL="https://rocket.alterway.fr/hooks/44vAPspqqtD7Jtmtv/k4Tw89EoXiT5GpniG/HaxMfijFFi5v1YTEN68DOe5fzFBBxB4YeTQz6w3khFE%3D"
#LOG_URL="https://hooks.slack.com/services/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"

local_kub8="kub8"

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

log "Begin Installation on Azure parameters : numberOfMasters=$numberOfMasters -  numberOfMinions=$numberOfMinions - numberOfEtcd=$numberOfEtcd" "0"
log ">>>subnetMasters=$subnetMasters - subnetMinions=$subnetMinions - numberOfEtcd=$numberOfEtcd" "0"
log ">>>vmNamePrefix=$vmNamePrefix ansiblefqdn=$ansiblefqdn sshu=$sshu viplb=$viplb" "0"


install_epel_repo
install_curl
ssh_config
get_private_ip
update_centos_distribution
install_required_groups
install_required_packages
install_python_modules
install_ansible
configure_ansible
test_ansible
create_inventory
get_kube_playbook
deploy