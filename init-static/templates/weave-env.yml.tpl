  - path: /etc/weave."${Current_Host}".env
    owner: root
    permissions: '0600'
    content: >
      WEAVE_PASSWORD="aa28e88e522463246cc79cdae6705cdd92e41f75d2db781104f23209293d5757"
      WEAVE_PEERS="${WEAVE_PEERS}"
      BREAKOUT_ROUTE="${BREAKOUT_ROUTE}"
      BRIDGE_ADDRESS_CIDR="${BRIDGE_ADDRESS_CIDR}"
    