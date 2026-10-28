# getting started

(this all runs from the `backend`dir)

### Install

- install docker <!--node (and therefor npm) then run `npm install`-->

### create .env file

fill
<details><summary>example</summary>

    ```

    MAPQUEST_KEY=GETUR0WNM4PQU3STK3Y

    POSTGRES_HOST=127.0.0.1
    POSTGRES_PORT=5432
    POSTGRES_USER=me
    POSTGRES_PASSWORD=password
    POSTGRES_DATABASE=api

    API_KEY=CR34T3UR0WN4P1%K3Y

    CERT_PATH="/path/to/key_and_cert/"

    PORT=3000
    ```
</details>

and store (in backend dir)

#### if neccessary also spin up the postgres database <!--could be dockerized if wanted-->

### run

`docker-compose up -d`

### logs

API requests are logged as single-line JSON and can be correlated via
`requestId`. The same id is returned to clients in the `X-Request-ID` header.
Sync logs contain only record identifiers, not credentials or complete payloads.

Requests running longer than 10 seconds and database queries running longer
than 5 seconds emit warning logs. The thresholds can be changed in `.env`:

```
BACKEND_SLOW_REQUEST_MS=10000
BACKEND_SLOW_QUERY_MS=5000
```

### File access and downloads

Document downloads are restricted to the `Dokus` directories of inspections
assigned to the authenticated user's `KZL`. The backend obtains these directories
from the database, not from the request. Existing full document paths and
directory-plus-filename requests remain supported. Traversal with `..`, paths
outside the allowed directories, and symbolic links escaping those directories
are rejected. A `Dokus` directory must not itself be a symbolic link.
Filesystem paths in the database and server-side directory contents
must remain writable only by trusted administrators/processes.

Windows drive paths continue to use `IMG_ROOT_PATH` when configured, for example
`S:\Projekt` maps to `${IMG_ROOT_PATH}/S/Projekt`. Absolute Linux paths stay
unchanged. No additional document-root configuration is required.

Images and documents are streamed instead of buffered in full. Image MIME types
and the `x-image-filename` header are preserved. Disconnected clients and failed
transfers close their source streams. A read error after a response has started
terminates that response; clients must treat a truncated download as failed.

File endpoints distinguish these outcomes:

| HTTP status | Meaning |
| --- | --- |
| 400 | Missing/invalid path, filename or image hash |
| 403 | Document path is not allowed |
| 404 | File or cached image hash no longer exists |
| 503 | File storage is unavailable or cannot be read |

Directory listing failures now propagate as HTTP 503 with the code
`STORAGE_UNAVAILABLE`, rather than a successful empty image/document list.
An accessible empty directory still produces an empty list. An absent optional
`Dokus` subdirectory is also empty, but an inaccessible/missing parent is an error.
Detailed filesystem errors are logged server-side, without exposing server paths
in error responses.

### Metadata cleanup

Listing documents only filters Windows/macOS metadata; it never deletes files.
Run cleanup explicitly, outside request handling:

```sh
npm run cleanup:metadata -- /path/to/inspection/Dokus
```

Multiple directories can be supplied. Cleanup is non-recursive and only removes
regular files named `Thumbs.db`, `ehthumbs.db`, `ehthumbs_vista.db`, `desktop.ini`
or `.DS_Store` (case-insensitive). It leaves documents, subdirectories and symlinks
untouched and exits nonzero on errors. Review the directory paths before running;
deleted metadata is not recoverable through this command.

### Backend tests

Run from `backend` after installing dependencies:

```sh
npm ci
npm test
```

Tests use Node's built-in test runner, temporary local directories and mocked
database calls. They require no production credentials, database or mounted
network drive. Coverage includes path mapping, document authorization, symlink
escapes, storage failures, read-only listing, streamed HTTP downloads, disconnects
and metadata cleanup. The backend GitHub Actions workflow runs them on Node 22.
