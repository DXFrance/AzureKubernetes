#!/bin/bash

privateIP=$1
role=$2
FACTS=/etc/ansible/facts

mkdir -p $FACTS
echo "${privateIP},${role}" > $FACTS/private-ip-role.fact 

chmod 755 /etc/ansible
chmod 755 /etc/ansible/facts
chmod a+r $FACTS/private-ip.fact 

exit 0
