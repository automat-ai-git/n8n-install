# Keelflow: Moving from Flowise

[Keelflow](https://github.com/Perruer/keelflow) is a continuation of Flowise 3.1.4 (Flowise was archived upstream on 2026-08-13 and reached end of life on 2026-08-31, so it gets no more security fixes). Keelflow is a separate `keelflow` profile at `keelflow.yourdomain.com`; Flowise stays available, and both can run side by side with their own data.

Keelflow keeps its data in the `localai_keelflow_data` volume, which starts empty: you create the account on first login. It does not pick up Flowise data on its own, but it can use a copied Flowise data folder as is (SQLite database, encryption key, flows, credentials, API keys). If Flowise ran with `FLOWISE_SECRETKEY_OVERWRITE` or an external database (`DATABASE_*`), give Keelflow the same variables with the same values in `docker-compose.override.yml`; Keelflow reads them under the Flowise names.

## Moving from Flowise

The copy replaces Keelflow's data with Flowise's, so anything already created in Keelflow is lost. Do it before you start using Keelflow.

1. Select Keelflow with `make update` and keep Flowise selected for now: the commands below read the data folder from the `flowise` container, so it has to exist.
2. Copy the Flowise folder (the host side of Flowise's `/root/.flowise` mount) into the Keelflow volume. The block stops Flowise and Keelflow, empties the Keelflow volume, copies the data, gives it to `node` (the user Keelflow runs as) and starts Keelflow. It stops at the first error and then leaves Keelflow stopped; fix the cause and run it again.
   ```bash
   FLOWISE_DIR=$(docker inspect flowise --format '{{ range .Mounts }}{{ if eq .Destination "/root/.flowise" }}{{ .Source }}{{ end }}{{ end }}')
   if [ -z "$FLOWISE_DIR" ]; then
     echo "No flowise container with a /root/.flowise mount found"
   else
     docker stop flowise keelflow &&
     docker run --rm --user root --entrypoint sh \
       -v "$FLOWISE_DIR":/from:ro -v localai_keelflow_data:/to \
       ghcr.io/perruer/keelflow:latest \
       -c 'find /to -mindepth 1 -delete && cp -a /from/. /to/ && chown -R node:node /to' &&
     docker start keelflow
   fi
   ```
3. Log into Keelflow with your Flowise account and check your flows and credentials.
4. Flowise stays stopped. Deselect it with the next `make update` (or bring it back with `make start`). The Flowise folder stays on the host until you remove it yourself.
