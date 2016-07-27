#!/bin/bash

function usage()
 {
    echo "INFO:"
    echo "Usage: config-node.sh [storage-account-name] [storage-account-key] [ansible user]"
}

error_log()
{
    if [ "$?" != "0" ]; then
        log "$1"
        log "Deployment ends with an error" "1"
        exit 1
    fi
}

function log()
{
	
  mess="$(hostname): $1"

  logger -t "${BASH_SCRIPT}" "${mess}"

}
function ssh_config()
{
  log "Configure ssh..."
  log "Create ssh configuration for ${ANSIBLE_USER}"
  
  printf "Host *\n  user %s\n  StrictHostKeyChecking no\n" "${ANSIBLE_USER}"  >> "/home/${ANSIBLE_USER}/.ssh/config"
  
  error_log "Unable to create ssh config file for user ${ANSIBLE_USER}"
  
  log "Copy generated keys..."
  
  cp id_rsa "/home/${ANSIBLE_USER}/.ssh/id_rsa"
  error_log "Unable to copy id_rsa key to $ANSIBLE_USER .ssh directory"

  cp id_rsa.pub "/home/${ANSIBLE_USER}/.ssh/id_rsa.pub"
  error_log "Unable to copy id_rsa.pub key to $ANSIBLE_USER .ssh directory"
  
  cat "/home/${ANSIBLE_USER}/.ssh/id_rsa.pub" >> "/home/${ANSIBLE_USER}/.ssh/authorized_keys"
  error_log "Unable to copy $ANSIBLE_USER id_rsa.pub to authorized_keys "

  chmod 700 "/home/${ANSIBLE_USER}/.ssh"
  error_log "Unable to chmod $ANSIBLE_USER .ssh directory"

  chown -R "${ANSIBLE_USER}:" "/home/${ANSIBLE_USER}/.ssh"
  error_log "Unable to chown to $ANSIBLE_USER .ssh directory"

  chmod 400 "/home/${ANSIBLE_USER}/.ssh/id_rsa"
  error_log "Unable to chmod $ANSIBLE_USER id_rsa file"

  chmod 644 "/home/${ANSIBLE_USER}/.ssh/id_rsa.pub"
  error_log "Unable to chmod $ANSIBLE_USER id_rsa.pub file"

  chmod 400 "/home/${ANSIBLE_USER}/.ssh/authorized_keys"
  error_log "Unable to chmod $ANSIBLE_USER authorized_keys file"
  
}

function install_packages()
{
    log "Install software-properties-common ..."
    until apt-get --yes install software-properties-common
    do
      log "Lock detected on apt-get while install Try again..."
      sleep 2
    done
    
    log "Update System ..."
    until apt-get --yes update
    do
      log "Lock detected on apt-get while install Try again..."
      sleep 2
    done
    
    log "Install git ..."
    until apt-get --yes install git
    do
      log "Lock detected on apt-get while install Try again..."
      sleep 2
    done
    
    log "Install pip ..."
    until apt-get --yes install python-pip
    do
      log "Lock detected on apt-get while install Try again..."
      sleep 2
    done
}


function get_sshkeys()
 {
   
    c=0;
    log "Install azure storage python module ..."
    pip install azure-storage

    # Push both Private and Public Key
    log "Push ssh keys to Azure Storage"
    until python GetSSHFromPrivateStorage.py "${STORAGE_ACCOUNT_NAME}" "${STORAGE_ACCOUNT_KEY}" id_rsa
    do
        log "Fails to Get id_rsa key trying again ..."
        sleep 60
        let c=${c}+1
        if [ "${c}" -gt 4 ]; then
           log "Timeout to get id_rsa key exiting ..."
           exit 1
        fi
    done
    python GetSSHFromPrivateStorage.py "${STORAGE_ACCOUNT_NAME}" "${STORAGE_ACCOUNT_KEY}" id_rsa.pub
    error_log "Fails to Get id_rsa.pub key"
}

function fix_etc_hosts()
{
	log "Add hostame and ip in hosts file ..."
	IP=$(ip addr show eth0 | grep inet | grep -v inet6 | awk '{ print $2; }' | sed 's?/.*$??')
	HOST=$(hostname)
	echo "${IP}" "${HOST}" >> "${HOST_FILE}"
}

function privateIP_for_ansible()
{
	FACTS=/etc/ansible/facts

	mkdir -p $FACTS
	echo "${privateIP},${role}" > $FACTS/private-ip-role.fact 

	chmod 755 /etc/ansible
	chmod 755 /etc/ansible/facts
	chmod a+r $FACTS/private-ip.fact 
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
privateIP="${1}"
role="${2}"

STORAGE_ACCOUNT_NAME="${3}"
STORAGE_ACCOUNT_KEY="${4}"
ANSIBLE_USER="${5}"

## Call functions
fix_etc_hosts
install_packages
get_sshkeys
ssh_config
privateIP_for_ansible

# Script Wait for the wait_module from ansible playbook
start_nc

log "Success : End of Execution of Install Script from CustomScript"

exit 0
