### Setup Nginx Load Balancing for APIs Server

- **install nginx:** `apt-get install -y nginx libnginx-mod-stream`
- **config nginx:**

_/etc/nginx/nginx.conf_

```
http {
...
}
stream {
  upstream kubernetes_apis {
    least_conn;
    server [k8s-apis-server-ip|domain]:[port];
    server [k8s-apis-server-ip|domain]:[port];
  }
  server {
    listen [lb-port];
    proxy_pass kubernetes_apis;
  }
}
```