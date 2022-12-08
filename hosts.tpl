[nginx_hosts]
%{ for ip in nginx_workers ~}
${ip}
%{ endfor ~}

[backend_hosts]
%{ for ip in backend_workers ~}
${ip}
%{ endfor ~}

[db_hosts]
%{ for ip in db_workers ~}
${ip}
%{ endfor ~}