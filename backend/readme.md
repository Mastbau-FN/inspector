# getting started

### Install
- install node (and therefor npm) then run `npm install`

###  create .env file

fill 
<details><summary>example</summary>

    ```
    POSTGRES_HOST=127.0.0.1
    POSTGRES_PORT=5432
    POSTGRES_USER=me
    POSTGRES_PASSWORD=password
    POSTGRES_DATABASE=api

    API_KEY=AE*%kXy2@WqCxNpm+^zz4V*eM93_B3P7

    CERT_PATH="/path/to/key_and_cert/"

    PORT=3000
    ```
</details>

and store in backend dir

#### if neccessary also spin up the postgres database

to use the app a database `users` with `name`and `pass` should be available. 

### run
`node index.js`
