stream {
  upstream kubernetes_api {
#######
  }
  server {
    listen ${lb_port};
    proxy_next_upstream_timeout 3;
    proxy_pass kubernetes_api;
  }
}