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

function fix_etc_hosts()
{
	log "Add hostame and ip in hosts file ..."
	IP=$(ip addr show eth0 | grep inet | grep -v inet6 | awk '{ print $2; }' | sed 's?/.*$??')
	HOST=$(hostname)
	echo "${IP}" "${HOST}" >> "${HOST_FILE}"
}

function install_packages()
{
    log "Install easy_install: ..."
    until yum install python-setuptools python-setuptools-devel
    do
      log "Lock detected on yum easy_install Try again..."
      sleep 2
    done
	error_log "Unable to get easy_install packages"

    log "Install pip ..."
    until easy_install pip
    do
      log "Lock detected on easy_install pip Try again..."
      sleep 2
    done
	error_log "Unable to get pip packages"
}


function get_sshkeys()
 {
   
    c=0;
    log "Install azure storage python module ..."
    pip install azure-storage

    # Pull both Private and Public Key
    log "Get ssh keys from Azure Storage"
    until python GetSSHFromPrivateStorage.py "${STORAGE_ACCOUNT_NAME}" "${STORAGE_ACCOUNT_KEY}" idgen_rsa
    do
        log "Fails to Get idgen_rsa key trying again ..."
        sleep 60
        let c=${c}+1
        if [ "${c}" -gt 4 ]; then
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

GIT_KUB8_URL="https://github.com/DXFrance/AzureKubernetes.git"

LOG_URL="https://hooks.slack.com/services/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"

# Slack notification
SLACK_TOKEN="$(get_slack_token)"
SLACK_CHANNEL="clusternodes"

export SLACK_TOKEN SLACK_CHANNEL

## Repos Variables
repo_name="ansible-kubernetes-centos"
slack_repo="slack-ansible-plugin"

## Call functions
fix_etc_hosts
install_packages
get_sshkeys
ssh_config
privateIP_for_ansible

# Script Wait for the wait_module from ansible playbook
start_nc

log "Success : End of Execution of Install Script from config-node CustomScript"

exit 0
