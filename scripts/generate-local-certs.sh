#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "${script_dir}/.." && pwd)"
cert_dir="${root_dir}/traefik/certs"
docker_cert_hosts=(registry.test.domain gitlab.test.domain)
tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "${tmp_dir}"
}

trap cleanup EXIT

ca_key="${cert_dir}/local-dev-ca.key"
ca_crt="${cert_dir}/local-dev-ca.crt"
server_key="${cert_dir}/local-dev-tls.key"
server_csr="${tmp_dir}/local-dev-tls.csr"
server_crt="${cert_dir}/local-dev-tls.crt"
server_ext="${tmp_dir}/local-dev-tls.ext"

mkdir -p "${cert_dir}"

if [ -e "${ca_key}" ] || [ -e "${ca_crt}" ] || [ -e "${server_key}" ] || [ -e "${server_crt}" ]; then
  echo "Certificates already exist in ${cert_dir}. Remove them first to regenerate." >&2
  exit 1
fi

cat > "${server_ext}" <<'EOF'
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=@alt_names

[alt_names]
DNS.1=gitlab.test.domain
DNS.2=registry.test.domain
EOF

openssl genrsa -out "${ca_key}" 4096
openssl req -x509 -new -nodes -key "${ca_key}" -sha256 -days 3650 \
  -out "${ca_crt}" -subj "/CN=GitLab Local Dev CA"

openssl genrsa -out "${server_key}" 4096
openssl req -new -key "${server_key}" -out "${server_csr}" \
  -subj "/CN=gitlab.test.domain"
openssl x509 -req -in "${server_csr}" -CA "${ca_crt}" -CAkey "${ca_key}" -CAcreateserial \
  -out "${server_crt}" -days 825 -sha256 -extfile "${server_ext}"

chmod 600 "${ca_key}" "${server_key}"
for host in "${docker_cert_hosts[@]}"; do
  docker_cert_dir="${HOME}/.docker/certs.d/${host}"
  mkdir -p "${docker_cert_dir}"
  cp "${ca_crt}" "${docker_cert_dir}/ca.crt"
done

echo "Created local CA and TLS certificates in ${cert_dir}."
echo "Copied Docker trust CA to ~/.docker/certs.d/registry.test.domain/ca.crt."
echo "Copied Docker trust CA to ~/.docker/certs.d/gitlab.test.domain/ca.crt."
echo "Restart Docker Desktop before pushing images to registry.test.domain."
echo "If Docker on macOS still reports x509 trust errors, import the CA into your login keychain:"
echo "  security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain-db ${ca_crt}"
echo "Optional macOS browser trust:"
echo "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ${ca_crt}"