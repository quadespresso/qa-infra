#!/bin/bash

apply_taint() {
  nodes=$(kubectl get nodes -l node-role.kubernetes.io/master= | awk '{if(NR>1)print $1}')
  kubectl taint nodes $nodes type=master:NoSchedule
  printf "Taint applied to nodes:\n$nodes\n"
}

remove_taint() {
  kubectl taint nodes -l node-role.kubernetes.io/master= type=master:NoSchedule-
  echo "Taint removed from nodes with the label [node-role.kubernetes.io/master=]"
}

if [ "$1" == "-r" ] || [ "$1" == "--remove" ]; then
  remove_taint
else
  apply_taint
fi
