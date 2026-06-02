global:
  checkNewVersion: false
  sendAnonymousUsage: false

log:
  level: INFO

api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    address: ":443"

certificatesResolvers:
  letsencrypt:
    acme:
      email: calvin.au@tribalorigin.com
      storage: /letsencrypt/acme.json
      tlsChallenge: {}
      httpChallenge:
        entryPoint: web

providers:
  docker:
    exposedByDefault: false
    network: ${environment}
    watch: true

http:
  middlewares:
    compress:
      compress: {}
