stream {
  upstream kubernetes_api {
#######
  }
  server {
    listen ${lb_port};
    real_ip_header X-Forwarded-For;
    proxy_next_upstream error timout http_500;
    proxy_next_upstream_timeout 3;
    proxy_pass kubernetes_api;
  }
}