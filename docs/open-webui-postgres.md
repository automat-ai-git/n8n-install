# Open WebUI: SQLite or PostgreSQL

Open WebUI stores chats, users and settings in either SQLite (a single file in the `open-webui` volume) or the stack's shared PostgreSQL. SQLite allows only one writer at a time, so with several tabs or devices open you may see:

```
sqlalchemy.exc.OperationalError: (sqlite3.OperationalError) database is locked
```

PostgreSQL handles concurrent writes and puts the data in the same backup as the rest of the stack. Which one you get is controlled by `OPEN_WEBUI_DATABASE` in `.env`:

- **New installations** default to `postgres`.
- **Existing installations** stay on `sqlite`, deliberately. **Open WebUI does not migrate data between databases** — switching would give you an empty Open WebUI while your chats, users and tags stayed in `webui.db`.

## Switching an existing installation

1. **Back up the volume first** (check the exact name with `docker volume ls | grep open-webui`):
   ```bash
   docker run --rm -v localai_open-webui:/data -v "$PWD":/backup alpine \
     tar czf /backup/open-webui-backup.tar.gz -C /data .
   ```
2. Set `OPEN_WEBUI_DATABASE=postgres` in `.env`.
3. Run `make update` (not just `make restart`) — the `openwebui` database is created by `make install`/`make update`, and pointing Open WebUI at a database that does not exist gives you a container that starts and then fails every request.
4. Open WebUI comes up **empty**. If you want your old data, migrate it now, **before registering an account** — importing users into a schema that already has an admin can collide on the primary key or the unique email. Use a purpose-built tool: [open-webui-postgres-migration](https://github.com/taylorwilsdon/open-webui-postgres-migration) or [Open-WebUI-SQLite-migration](https://github.com/Digitalist-Open-Cloud/Open-WebUI-SQLite-migration). Prefer these over generic `pgloader`, which does not understand Open WebUI's JSON and blob columns.
5. Log in with your migrated account. Only register a fresh admin if you deliberately want to start empty.

To revert, set `OPEN_WEBUI_DATABASE=sqlite` and run `make restart` — the original SQLite file is left untouched.

Note that uploaded files and the vector store live in the `open-webui` volume in **either** mode, so moving the database does not make Open WebUI stateless and does not put all of its data into your PostgreSQL backup.
