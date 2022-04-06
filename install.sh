#!/usr/bin/env bash

# Create SSH key
mkdir -p ~/.ssh

ssh-keygen -t rsa -b 4096
cat ~/.ssh/id_rsa.pub

grep -qF '172.19.181.254 ' /etc/hosts || echo "172.19.181.254  main cnat controller" | sudo tee -a /etc/hosts >/dev/null

for node in 1 2 3 4; do 
    grep -qF "172.19.181.$node " /etc/hosts || echo "172.19.181.$node    p$node" | sudo tee -a /etc/hosts >/dev/null
done

# create SSH config file
cat << EOF > ~/.ssh/config
Host p1
    Hostname 172.19.181.1
    User pi
    StrictHostKeyChecking=accept-new
Host p2
    Hostname 172.19.181.2
    User pi
    StrictHostKeyChecking=accept-new
Host p3
    Hostname 172.19.181.3
    User pi
    StrictHostKeyChecking=accept-new
Host p4
    Hostname 172.19.181.4
    User pi
    StrictHostKeyChecking=accept-new
EOF

# Copy key to each node
for host in p1 p2 p3 p4; do 
    ssh-copy-id -i ~/.ssh/id_rsa.pub $host
done

# Set Timezone Locale and keyboard on each node

# Do controller
echo "Adjusting Controller..."
echo "    Timezone..."
rm /etc/localtime 2>/dev/null
echo "America/Vancouver" | sudo tee /etc/timezone >/dev/null && \
sudo dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1

echo "    Keyboard..."
sudo cp /etc/default/keyboard /etc/default/keyboard.dist
sudo sed -i -e "/XKBLAYOUT=/s/gb/us/" /etc/default/keyboard
sudo service keyboard-setup restart >/dev/null 2>&1

echo "    Locale..."
LOCALE="en_US.UTF-8"
if LOCALE_LINE="$(grep "^$LOCALE " /usr/share/i18n/SUPPORTED)"; then
  ENCODING="$(echo $LOCALE_LINE | cut -f2 -d " ")"
  echo "$LOCALE $ENCODING" | sudo tee /etc/locale.gen >/dev/null
  sudo sed -i "s/^\s*LANG=\S*/LANG=$LOCALE/" /etc/default/locale
  sudo dpkg-reconfigure -f noninteractive locales >/dev/null 2>&1
fi

# Loop through hosts and set timezone.
for host in p1 p2 p3 p4; do 
  echo "Adjusting $host.local..."
  echo "    Timezone..."
  ssh pi@$host.local 'rm /etc/localtime 2>/dev/null; echo "America/Vancouver" | sudo tee /etc/timezone >/dev/null && sudo dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1' >/dev/null

  echo "    Keyboard..."
  ssh pi@$host.local 'sudo cp /etc/default/keyboard /etc/default/keyboard.dist; sudo sed -i -e "/XKBLAYOUT=/s/gb/us/" /etc/default/keyboard; sudo service keyboard-setup restart >/dev/null 2>&1' >/dev/null

  echo "    Locale..."
  ssh pi@$host.local 'LOCALE="en_US.UTF-8"; if LOCALE_LINE="$(grep "^$LOCALE " /usr/share/i18n/SUPPORTED)"; then ENCODING="$(echo $LOCALE_LINE | cut -f2 -d " ")"; echo "$LOCALE $ENCODING" |sudo tee /etc/locale.gen >/dev/null; sudo sed -i "s/^\s*LANG=\S*/LANG=$LOCALE/" /etc/default/locale; sudo dpkg-reconfigure -f noninteractive locales >/dev/null 2>&1;fi' >/dev/null
done

mkdir -p ~/.scripts

curl -sSL https://raw.githubusercontent.com/rodneyshupe/RPi_Bramble/main/shutdown-bramble.sh --output ~/.scripts/shutdown-bramble.sh
chmod +x ~/.scripts/shutdown-bramble.sh
sudo cp ~/.scripts/shutdown-bramble.sh /usr/local/bin/shutdown-bramble

# Setup Shared Storage
sudo mkdir -p /media/storage
sudo chown nobody:nogroup -R /media/storage
sudo chmod -R 777 /media/storage

uuid=$(blkid | grep '/dev/sd' --max-count=1 | grep --only-matching ' UUID=[^ ]*' | sed -e 's/^[ ]*//' -e 's/"//g')
type=$(blkid | grep '/dev/sd' --max-count=1 | grep --only-matching ' TYPE=[^ ]*' | sed -e 's/^[ ]*TYPE=//' -e 's/"//g')

[ $(grep -q "/media/Storage" /etc/fstab; echo $?) -ne 0 ] && echo "$uuid /media/Storage $type defaults 0 2" | sudo tee -a /etc/fstab

sudo mount -a

sudo apt-get install -y nfs-kernel-server

[ $(grep -q "/media/Storage" /etc/exports; echo $?) -ne 0 ] && echo "/media/Storage 172.19.181.0/24(rw,sync,no_root_squash,no_subtree_check)" | sudo tee -a /etc/exports

for host in p1 p2 p3 p4; do 
  echo "Install NFS client on $host.local..."
  ssh pi@$host.local 'sudo apt-get install -y nfs-common' >>/dev/null
  echo "Setup mount point..."
  ssh pi@$host.local 'sudo mkdir -p /media/Storage && sudo chown nobody:nogroup /media/Storage ; sudo chmod -R 777 /media/Storage && [ $(grep -q "/media/Storage" /etc/fstab; echo $?) -ne 0 ] && echo "172.19.181.254:/media/Storage /media/Storage nfs defaults 0 0" | sudo tee -a /etc/fstab; sudo mount -a'
done

# Install Docker
curl -sSL get.docker.com | sh && sudo usermod pi -aG docker && sudo usermod $USER -aG docker

for host in p1 p2 p3 p4; do 
  echo "Install docker on $host.local..."
  ssh pi@$host.local 'curl -sSL get.docker.com | sh && sudo usermod pi -aG docker'
done

sudo iptables -P FORWARD ACCEPT

sudo docker swarm init --advertise-addr 172.19.181.254:2377 --listen-addr 172.19.181.254:2377

worker_join_cmd="$(docker swarm join-token worker | grep 'docker swarm join' | sed 's/^[ ]*//g')"
for host in p1 p2 p3 p4; do 
  echo "Add $host.local to the docker swarm..."
  ssh pi@$host.local "$worker_join_cmd"
done

docker node list

docker node update --label-add type=3B+ bramble

for host in p1 p2 p3 p4; do 
  docker node update --label-add type=zero $host
done

docker node ls -q | xargs docker node inspect -f '{{ .ID }} [{{ .Description.Hostname }}]: {{ .Spec.Labels }}'

mkdir -p docker/portainer
curl -sSL https://raw.githubusercontent.com/rodneyshupe/RPi_Bramble/main/docker/portainer/docker-compose.yml --output docker/portainer/docker-compose/

docker-compose up -d
