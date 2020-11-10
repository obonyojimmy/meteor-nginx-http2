#!/bin/bash

domain_name=''
certs_path=/etc/nginx/ssl-certs

brew install mkcert nss
sudo mkcert -install
mkcert $domain_name
sudo mv $domain_name.pem ${certs_path}/${domain_name}.pem # cert
sudo mv ${domain_name}-key.pem ${certs_path}/${domain_name}-key.pem # key

# Auto-generate the localhost nginx config
cat <<EOT >> /etc/nginx/conf.d/$domain_name.conf
  upstream meteor_app {
    server localhost:3000;
    keepalive 256;
  }

  server {
    listen 80;
    server_name $domain_name;

    return 301 https://$host$request_uri;
  }

  # HTTPS server
  server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $domain_name;

    ## Nginx response compression
    gzip on;
    gzip_min_length 1000;
    gzip_comp_level 4;
    gzip_types text/html text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
    
    ssl_certificate      $certs_path/$domain_name;
    ssl_certificate_key  $certs_path/$domain_name-key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:20m;
    ssl_session_tickets off;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    

    ## HSTS
    add_header Strict-Transport-Security "max-age=15768000" always;
    
    #location ~ \.(css|js|png|jpeg|jpg|mp4)$ {
    #  root <TODO>
    #  access_log off;
    #}

    location / {
      proxy_pass  http://meteor_app;
      http2_push_preload on;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection $connection_upgrade;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP  $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forward-Proto http;
      proxy_set_header X-Nginx-Proxy true;
      proxy_redirect off;
    }
  }
EOT

nginx -s reload