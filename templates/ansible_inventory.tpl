[managers]
%{ for idx in mgr_idxs ~}
manager${idx} ansible_host=${mgr_hosts[idx].public_ip}
%{ endfor ~}

[workers]
%{ for idx in wkr_idxs ~}
worker${idx} ansible_host=${wkr_hosts[idx].public_ip}
%{ endfor ~}

[msrs]
%{ for idx in msr_idxs ~}
msr${idx} ansible_host=${msr_hosts[idx].public_ip}
%{ endfor ~}

[windows]
%{ for idx in win_wkr_idxs ~}
win${idx} ansible_host=${win_wkr_hosts[idx].public_ip}
%{ endfor ~}

[linux:vars]
ansible_user=${linux_user}

[windows:vars]
ansible_user=administrator
ansible_password=${win_passwd}
ansible_connection=winrm
ansible_winrm_server_cert_validation=ignore

[all:vars]
ansible_ssh_private_key_file=${key_file}

[linux:children]
managers
workers
msrs
