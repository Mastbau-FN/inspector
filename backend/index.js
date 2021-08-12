const express = require('express')
const bodyParser = require('body-parser')

require('dotenv').config();

const db = require('./db/queries')
const auth = require('./auth/auth')

const app = express()
const port = process.env.port

app.use(bodyParser.json())
app.use(
  bodyParser.urlencoded({
    extended: true,
  })
)

app.get('/', (request, response) => {
    response.json({ info: 'API for the inspections app, not meant for human consumption' })
})

/** 
 * everything at this path (/api/secure/) is hidden behind an auth-wall currently requiring the correct authentication header (API-Key)
 * can be disabled for testing purposes
*/
if (!process.env.insecure){
    app.use('/api/secure/', auth.api_wall);
    app.use('/api/secure/',auth.login_wall);
}

//TODO: remove these tests
app.get('/users', db.getUsers)
app.get('/users/:id', db.getUserById)
app.post('/users', db.createUser)
app.put('/users/:id', db.updateUser)
app.delete('/users/:id', db.deleteUser)

app.listen(port, () => {
    console.log(`App running on port ${port}.`)
})
