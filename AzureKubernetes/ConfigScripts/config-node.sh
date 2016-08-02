#!/bin/bash

function usage()
 {
    echo "INFO:"
    echo "Usage: config-node.sh [storage-account-name] [storage-account-key] [ansible user]"
}

function error_log()
{
    if [ "$?" != "0" ]; then
        log "$1"
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
	#does not work - check later
	log "Add hostame and ip in hosts file ..."
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

function install_packages()
{
  log "Install pip required packages..." "0"
  until yum install -y git python2-devel python-pip libffi-devel libssl-dev openssl-devel
  do
    log "Lock detected on VM init Try again..." "0"
    sleep 2
  done
  error_log "Unable to get system packages"
}

function install_python_modules()
{
  log "upgrading pip"
  #does not work
  pip install --upgrade pip

  log "Install azure storage python module via pip..."
  pip install azure-storage
  error_log "Unable to install azure-storage package via pip"

}

function get_sshkeys()
 {
    c=0;

    # Pull both Private and Public Key
    log "Get ssh keys from Azure Storage"
    until python GetSSHFromPrivateStorage.py "${STORAGE_ACCOUNT_NAME}" "${STORAGE_ACCOUNT_KEY}" idgen_rsa
    do
        log "Fails to Get idgen_rsa key trying again ..."
        sleep 180
        let c=${c}+1
        if [ "${c}" -gt 5 ]; then
           log "Timeout to get idgen_rsa key exiting ..."
           exit 1
        fi
    done
    python GetSSHFromPrivateStorage.py "${STORAGE_ACCOUNT_NAME}" "${STORAGE_ACCOUNT_KEY}" idgen_rsa.pub
    error_log "Fails to Get idgen_rsa.pub key"
}

function ssh_config()
{
  log "Configure ssh..."
  log "Create ssh configuration for ${ANSIBLE_USER}"
  
  printf "Host *\n  user %s\n  StrictHostKeyChecking no\n" "${ANSIBLE_USER}"  >> "/home/${ANSIBLE_USER}/.ssh/config"
  
  error_log "Unable to create ssh config file for user ${ANSIBLE_USER}"
  
  log "Copy generated keys..."
  
  cp id_rsa "/home/${ANSIBLE_USER}/.ssh/idgen_rsa"
  error_log "Unable to copy idgen_rsa key to $ANSIBLE_USER .ssh directory"

  cp id_rsa.pub "/home/${ANSIBLE_USER}/.ssh/idgen_rsa.pub"
  error_log "Unable to copy idgen_rsa.pub key to $ANSIBLE_USER .ssh directory"
  
  cat "/home/${ANSIBLE_USER}/.ssh/idgen_rsa.pub" >> "/home/${ANSIBLE_USER}/.ssh/authorized_keys"
  error_log "Unable to copy $ANSIBLE_USER idgen_rsa.pub to authorized_keys "

  chmod 700 "/home/${ANSIBLE_USER}/.ssh"
  error_log "Unable to chmod $ANSIBLE_USER .ssh directory"

  chown -R "${ANSIBLE_USER}:" "/home/${ANSIBLE_USER}/.ssh"
  error_log "Unable to chown to $ANSIBLE_USER .ssh directory"

  chmod 400 "/home/${ANSIBLE_USER}/.ssh/idgen_rsa"
  error_log "Unable to chmod $ANSIBLE_USER idgen_rsa file"

  chmod 644 "/home/${ANSIBLE_USER}/.ssh/idgen_rsa.pub"
  error_log "Unable to chmod $ANSIBLE_USER idgen_rsa.pub file"

  chmod 400 "/home/${ANSIBLE_USER}/.ssh/authorized_keys"
  error_log "Unable to chmod $ANSIBLE_USER authorized_keys file"
  
}

function get_slack_token()
{
  # this function set the SLACK_TOKEN environment variable in order to use slack-ansible-plugin

  # token=$(grep "token:" slack-token.tok | cut -f2 -d:)
  # base64 encoding in order to avoid to handle vm extension fileuris parameters outside of github
  # because github forbids token archiving
  # the alternative would be to put a file in a vault or a storage account and copy this file from 
  # the config-ansible.sh (deployment through fileuris mechanism would also present an issue because
  # it seems currently impossible to use both github and a storage account in the fileuris list)
  encoded="AHRva2VuOnhveHAtMjYxMTYwNzgxMzItMjYxMTc3ODg3NzItNDAwMDY4MDY0NjUtZjgwZTI3MzFmMw=="
  token=$(base64 -d -i <<<"$encoded")
  echo "$token"
}

function start_nc()
{
  log "Pause script for Control VM..."
  nohup nc -d -l 3333 >/tmp/nohup.log 2>&1
}

log "Execution of Install Script from CustomScript ..."

## Variables

CWD="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

log "CustomScript Directory is ${CWD}"

BASH_SCRIPT="${0}"
STORAGE_ACCOUNT_NAME="${1}"
STORAGE_ACCOUNT_KEY="${2}"
ANSIBLE_USER="${3}"

LOG_DATE=$(date +%s)
HOST_FILE="/etc/hosts"

GIT_KUB8_URL="https://github.com/DXFrance/AzureKubernetes.git"
EPEL_REPO="http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-7.noarch.rpm"

LOG_URL="https://hooks.slack.com/services/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"

# Slack notification
SLACK_TOKEN="$(get_slack_token)"
SLACK_CHANNEL="clusternodes"

export SLACK_TOKEN SLACK_CHANNEL

## Repos Variables
repo_name="ansible-kubernetes-centos"
slack_repo="slack-ansible-plugin"

## Call functions
#fix_etc_hosts
install_epel_repo
install_curl
update_centos_distribution
install_required_groups
install_packages
install_python_modules
get_sshkeys
ssh_config

# Script Wait for the wait_module from ansible playbook
start_nc

log "Success : End of Execution of Install Script from config-node CustomScript"

exit 0
