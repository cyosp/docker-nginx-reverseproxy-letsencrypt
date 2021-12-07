#!/bin/bash

# Inspired from:
# https://github.com/Paldom/docker-nginx-letsencrypt-proxy
# https://raw.githubusercontent.com/wmnnd/nginx-certbot/master/init-letsencrypt.sh

i="1"

# Define a default key length for the certificate, and use the parameter if set
keyLength=4096
if [ -n "$KEYLENGTH" ]; then
  keyLength=$KEYLENGTH
fi

# Should we execute everything on LE's staging platform?
test=""
if [ -n "$DRYRUN" ]; then
  test="--test"
fi

# Define a default DH params length, and use the parameter if set
# 1024 length is set for test purposes only, please set it to 2048 at least!
dhParamLength=1024
if [ -n "$DHPARAM" ]; then
  dhParamLength=$DHPARAM
fi

# Generating self-signed certificates for each host, mandatory for Nginx and LE
# to execute properly
while : ; do
  host="SERVICE_HOST_$i"
  subj="SERVICE_SUBJ_$i"
  if [ -z "${!host}" ]; then
    i=$[$i-1]
    break
  fi
  if [[ ! -d "/certs/${!host}"  || ! -s "/certs/${!host}/cert.pem" ]]; then
    echo ""
    echo "Generating a self-signed certificate for ${!host}..."
    certSubj="/C=EU/ST=My State/L=My City/O=My Organization/OU=My Domain/CN=${!host}"
    if [ -n "${!subj}" ]; then
      certSubj=${!subj}
    fi
    mkdir -vp /certs/${!host}
    /usr/bin/openssl genrsa -out /certs/${!host}/key.pem 1024
    /usr/bin/openssl req -new -key /certs/${!host}/key.pem \
            -out /certs/${!host}/cert.csr \
            -subj "$certSubj"
    /usr/bin/openssl x509 -req -days 365 -in /certs/${!host}/cert.csr \
            -signkey /certs/${!host}/key.pem \
            -out /certs/${!host}/cert.pem
    rm /certs/${!host}/cert.csr
    cp /certs/${!host}/cert.pem /certs/${!host}/fullchain.pem
    echo "Self-signed certificate for ${!host} successfully created."
    echo ""
  fi
  i=$[$i+1]
done

# Generate the DH params file if it does not exist
if [ ! -s "/certs/dhparam.pem" ]; then
  echo ""
  echo "Generating DH Parameters (length: $dhParamLength)..."
  echo "It can be quite long (several minutes), and no log will be displayed."
  echo "Do not worry, and wait for the generation to be done."
  /usr/bin/openssl dhparam -out /certs/dhparam.pem $dhParamLength
  echo "DH Parameters generated."
  echo ""
fi

# Starting Nginx in daemon mode
/usr/sbin/nginx

if [ -n "$EMAIL" ]; then
  /root/.acme.sh/acme.sh  --register-account  -m $EMAIL --server zerossl
fi

# Request and install a Let's Encrypt certificate for each host
i="1"
while : ; do
  host="SERVICE_HOST_$i"
  if [ -z "${!host}" ]; then
      i=$[$i-1]
      break
  fi
  certSubject=`/usr/bin/openssl x509 -subject -noout -in /certs/${!host}/cert.pem | /usr/bin/cut -c9-999`
  certIssuer=`/usr/bin/openssl x509 -issuer -noout -in /certs/${!host}/cert.pem | /usr/bin/cut -c8-999`
  # Checking whether the existent certificate is self-signed or not
  # If self-signed: remove the le-ok file
  if [[ -e /certs/${!host}/le-ok && "$certSubject" = "$certIssuer" ]]; then
    rm /certs/${!host}/le-ok
  fi
  # Replace the existing self-signed certificate with a LE one
  if [ ! -e /certs/${!host}/le-ok ]; then
    ecc=""
    keyLengthTest=`echo "$keyLength" | /usr/bin/cut -c1-2`
    if [ "$keyLengthTest" = "ec" ]; then
      ecc="--ecc"
    fi
    echo ""
    echo "Requesting a certificate from Let's Encrypt certificate for ${!host}..."
    /root/.acme.sh/acme.sh $test --log --issue -w /var/www/html/ -d ${!host} -k $keyLength
    /root/.acme.sh/acme.sh $test --log --installcert $ecc -d ${!host} \
                           --key-file /certs/${!host}/key.pem \
                           --fullchain-file /certs/${!host}/fullchain.pem \
			   --cert-file /certs/${!host}/cert.pem \
                           --reloadcmd '/usr/sbin/nginx -s stop && /bin/sleep 5s && /usr/sbin/nginx'
    touch /certs/${!host}/le-ok
    echo "Let's Encrypt certificate for ${!host} installed."
    echo ""
  fi
  i=$[$i+1]
done

chmod -R 600 /certs

/usr/sbin/nginx -s stop

/bin/sleep 5s

echo ""
echo "Restarting Nginx, if no errors appear below, it is ready!"
echo ""

exec /usr/sbin/nginx -g 'daemon off;'
