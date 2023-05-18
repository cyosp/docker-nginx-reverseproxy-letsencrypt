# Nginx reverse proxy with embedded Let's Encrypt certificates

## What is it?

This [repository](https://github.com/bh42/docker-nginx-reverseproxy-letsencrypt) contains a Docker container which embeds an Nginx as reverse-proxy, linked with Let's Encrypt (using [https://acme.sh](acme.sh)) for SSL/TLS certificates.

You can find it on Docker Hub: [bh42/nginx-reverseproxy-letsencrypt](https://hub.docker.com/r/bh42/nginx-reverseproxy-letsencrypt)

The Nginx configuration is purposedly user-defined, so you can set it just the way you want.

However, you can find an example below.

## How does it work?

This image is based upon the official Nginx repository, using the alpine version (`nginx:alpine`).

[https://acme.sh](acme.sh) is installed, and certificates are generated/requested during the first start.

First of all, self-signed certificates are generated, so Nginx can start with your SSL/TLS configuration.

Then, [https://acme.sh](acme.sh) is used to requested LE-signed certificates, which will replace the self-signed ones.

## Usage

### Configuration

#### Volumes

Two volumes are used :
* `/certs`: all the certificates will be stored here (including dhparam.pem). You do not need to put anything by yourself, the container will do it itself.
* `/conf`: place your Nginx configuration file(s) here. An `nginx.conf` is required, the rest is up to you.

#### Environment variables

The following variables can be set:
* `DRYRUN`: set it to whatever value to use the staging Let's Encrypt environment during your tests.
* `KEYLENGTH`: defines the key length of your Let's Encrypt certificates (1024, 2048, 4096, ec-256, ec-384, ec-521 [not supported by LE yet], etc). Default is set to 4096.
* `EMAIL`: e-mail address used to register with ZeroSSL ([https://github.com/acmesh-official/acme.sh/wiki/ZeroSSL.com-CA](acme.sh wiki))
* `DHPARAM`: defines the Diffie-Hellman parameters key length. Default is set to 2048. *Be aware that it can take much time, way more than just a couple minutes.*
* `x_FROM_HOST`: the domain you want certificates for. Set one per domain: `WEBSITE_FROM_HOST`, `API_FROM_HOST`, etc.
* `x_SUBJ`: the self-signed certificate subject of `SERVICE_HOST_x`. The expected format is the following: `/C=Country code/ST=State/L=City/O=Company/OU=Organization/CN=your.domain.tld`. It's not really useful, but still, it's there. Use `SERVICE_SUBJ_1` for `SERVICE_HOST_1`, etc.

### Docker cli

Here is an example with two domains:
```
docker run \
  -p 80:80 \
  -p 443:443 \
  -v /home/user/my_nginx_conf:/conf \
  -v /home/user/my_certs:/certs \
  -e KEYLENGTH=ec-384 \
  -e EMAIL=johndoe@gmail.com \
  -e DHPARAM=4096 \
  -e WEBSITE_FROM_HOST=website.mydomain.com \
  -e WEBSITE_AND_PATH=/path \
  --name reverse-proxy \
  -t -d
```

### Docker-compose

```yaml
version: '3.7'
services:
  proxy:
    container_name: "proxy"
    image: bh42/nginx-reverseproxy-letsencrypt:latest
    environment:
      - KEYLENGTH: ec-384
      - EMAIL: johndoe@gmail.com
      - DHPARAM: 4096
      - WEBSITE_FROM_HOST: website.mydomain.com
      - WEBSITE_AND_PATH: /path
    restart: unless-stopped
    tty: true
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /home/user/my_certs:/certs
      - /home/user/my_nginx_conf:/conf
```

### Nginx configuration notes

**Since the certificates will be stored in `/certs`, be sure to write your Nginx configuration file(s) accordingly!**

The configuration files in `/conf` will be placed in `/etc/nginx/conf.d` in the container.  
If you do not use any `x_FROM_HOST` environment variables, you can set the `conf` volume in read only (`:ro`) mode.
