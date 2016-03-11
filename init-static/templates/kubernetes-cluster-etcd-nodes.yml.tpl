#cloud-config
write_files:
  - path: /etc/hosts
    permissions: '0755'
    owner: root
    content: |
${Etc_Host}
coreos:
  units:
    - name: etcd2.service
      enable: true
      command: start
    - name: etcd2.service
      drop-ins:
        - name: 50-etcd-initial-cluster.conf
          content: >
            [Service]

            ${Environment}
  etcd2:
    name: '%H'
    initial-cluster-token: etcd-cluster
    initial-advertise-peer-urls: 'http://%H:2380'
    listen-peer-urls: 'http://%H:2380'
    listen-client-urls: 'http://0.0.0.0:2379,http://0.0.0.0:4001'
    advertise-client-urls: 'http://%H:2379,http://%H:4001'
    initial-cluster-state: new
  update:
    group: stable
    reboot-strategy: 'off'
