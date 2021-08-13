# getting started

### Install
- install node (and therefor npm) then run `npm install`

###  create .env file

fill with
```
POSTGRES_HOST=xxx
POSTGRES_PORT=xxx
POSTGRES_USER=xxx
POSTGRES_PASSWORD=xxx
POSTGRES_DATABASE=xxx

API_KEY=xxx
INSECURE=1 (only for testing)

PORT=xxx
```
<details><summary>example</summary>
    ```
    POSTGRES_HOST=127.0.0.1
    POSTGRES_PORT=5432
    POSTGRES_USER=me
    POSTGRES_PASSWORD=password
    POSTGRES_DATABASE=api

    API_KEY=AE*%kXy2@WqCxNpm+^zz4V*eM93_B3P7

    PORT=3000
    ```
</details>

and store in backend dir

#### if neccessary also spin up the postgres database

to use the app a database `users` with `name`and `pass` should be available. The pass should be a hash than can be generated with [this generator](https://bcrypt-generator.com/) for example.

### run
`node index.js`
