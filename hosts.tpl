[nginx_hosts]
%{ for ip in nginx_workers ~}
${ip}
%{ endfor ~}

[php_hosts]
%{ for ip in php_workers ~}
${ip}
%{ endfor ~}

[db_hosts]
%{ for ip in db_workers ~}
${ip}
%{ endfor ~}