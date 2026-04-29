# GitLab Stack — Traefik + GitLab CE + PostgreSQL + Runner + Registry

## 1. /etc/hosts entries
Add both lines on your host machine:
```
127.0.0.1  gitlab.test.domain
127.0.0.1  registry.test.domain
```

## 2. Generate local TLS certificates
This HTTPS setup uses Traefik TLS termination with a local development CA.

Generate the certificates:
```bash
./scripts/generate-local-certs.sh
```

What the script does:
- Creates a local CA and a server certificate for `gitlab.test.domain` and `registry.test.domain`
- Copies the CA certificate into `~/.docker/certs.d/registry.test.domain/ca.crt` and `~/.docker/certs.d/gitlab.test.domain/ca.crt`
- This is required because Docker pushes authenticate against `https://gitlab.test.domain/jwt/auth`, not only `registry.test.domain`

Browser trust on macOS:
If you want Safari/Chrome to trust the local certificate without warnings, import the CA into the System keychain:
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain traefik/certs/local-dev-ca.crt
```

Docker trust on macOS:
If Docker still shows an x509 error for `https://gitlab.test.domain/jwt/auth` after the `certs.d` files are in place, import the CA into your login keychain too:
```bash
security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain-db traefik/certs/local-dev-ca.crt
```

After generating the certificates, restart Docker Desktop once so Docker reloads trust for both hosts.

## 3. Start the stack
```bash
docker compose up -d
```
GitLab takes ~5–10 minutes on first boot. Track it with:
```bash
docker logs -f gitlab
```
Wait until you see: `gitlab Reconfigured!`

HTTPS checks:
```bash
curl -k https://gitlab.test.domain
curl -k https://registry.test.domain/v2/
```

## 4. Get the initial root password
```bash
docker exec gitlab cat /etc/gitlab/initial_root_password
```
Login at https://gitlab.test.domain with user `root`.

## 5. Register the GitLab Runner
After GitLab is up, go to: Admin → CI/CD → Runners → New instance runner
```bash
docker exec -it gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.test.domain" \
  --token "<YOUR_RUNNER_TOKEN>" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --description "local-docker-runner" \
  --docker-privileged \
  --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
  --docker-volumes "/cache" \
  --docker-pull-policy "if-not-present"
```

## 6. Container Registry
Registry is available at: https://registry.test.domain

Docker login:
```bash
docker login registry.test.domain
# Username: root (or your GitLab user)
# Password: your GitLab password
```

Push an image:
```bash
docker tag myimage registry.test.domain/root/myproject/myimage:latest
docker push registry.test.domain/root/myproject/myimage:latest
```

Expected behavior check:
`curl -k https://registry.test.domain/v2/` should return `401` before login. That means the registry is reachable and waiting for authentication.

In .gitlab-ci.yml:
```yaml
image: registry.test.domain/root/myproject/myimage:latest

build:
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  variables:
    CI_REGISTRY: registry.test.domain
```

## 7. Traefik dashboard
Available at http://localhost:8080

## SSH clone
Use port 2222:
```bash
git clone ssh://git@gitlab.test.domain:2222/group/repo.git
```

## Stop / teardown
```bash
docker compose down          # keep volumes
docker compose down -v       # destroy volumes (full reset)
```
