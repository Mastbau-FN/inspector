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
