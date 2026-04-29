# GitLab Stack — Traefik + GitLab CE + PostgreSQL + Runner + Registry

## 1. /etc/hosts entries
Add both lines on your host machine:
```
127.0.0.1  gitlab.test.domain
127.0.0.1  registry.test.domain
```

## 2. Start the stack
```bash
docker compose up -d
```
GitLab takes ~5–10 minutes on first boot. Track it with:
```bash
docker logs -f gitlab
```
Wait until you see: `gitlab Reconfigured!`

## 3. Get the initial root password
```bash
docker exec gitlab cat /etc/gitlab/initial_root_password
```
Login at http://gitlab.test.domain with user `root`.

## 4. Register the GitLab Runner
After GitLab is up, go to: Admin → CI/CD → Runners → New instance runner
```bash
docker exec -it gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "http://gitlab.test.domain" \
  --token "<YOUR_RUNNER_TOKEN>" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --description "local-docker-runner" \
  --docker-volumes "/var/run/docker.sock:/var/run/docker.sock"
```

## 5. Container Registry
Registry is available at: http://registry.test.domain

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

## 6. Traefik dashboard
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
