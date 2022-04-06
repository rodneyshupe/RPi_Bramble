#!/usr/bin/env bash

function waitfor() {
  local waitfor_host=$1
  hostup=1
  echo -n "Waiting for $waitfor_host"
  while (($hostup == 1))
  do
    if ping -c 1 -W 0.2 $waitfor_host &> /dev/null
    then
        echo -n "."
    else
        echo ""
        hostup=0
    fi
  done
}

for host in $(seq --format='p%g' 1 $(/usr/sbin/clusterctrl maxpi)); do 
  echo "Shutting down $host.local..."
  ssh pi@$host.local 'sudo shutdown now' >/dev/null
done

for host in $(seq --format='p%g' 1 $(/usr/sbin/clusterctrl maxpi)); do 
  waitfor $host.local
done

sleep 5

echo "Shutting down ClusterHat..."
clusterhat off
