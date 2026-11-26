[web]
%{ for ip_address in ips }
${ip_address} ansible_user=ubuntu
%{ endfor ~}
