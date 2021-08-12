const bcrypt = require("bcrypt");
const pool = require('./pool').db.pool;

const isValidUser = (user, onValid, onInvalid) => {
  pool.query('SELECT * FROM users WHERE name = $1', [user.name], (error, results) => {
    if (error) {
      throw error
    }
    bcrypt.compare(user.pass, results.rows[0].pass)
      .then(onValid)
      .catch(onInvalid)
  })
}


/// stuff below is just for trial
const getUsers = (request, response) => {
  pool.query('SELECT * FROM users ORDER BY id ASC', (error, results) => {
    if (error) {
      throw error
    }
    response.status(200).json(results.rows)
  })
}

/**
 * 
 * @param {*} request 
 * @param {*} response 
 * returns all the users with matching id
 */
const getUserById = (request, response) => {
  const id = parseInt(request.params.id)

  pool.query('SELECT * FROM users WHERE id = $1', [id], (error, results) => {
    if (error) {
      throw error
    }
    response.status(200).json(results.rows)
  })
}

//TODO: add the actual queries
const createUser = (request, response) => {
  const { name, email } = request.body

  pool.query('INSERT INTO users (name, email) VALUES ($1, $2)', [name, email], (error, results) => {
    if (error) {
      throw error
    }
    response.status(201).send(`User added with ID: ${result.insertId}`)
  })
}

const updateUser = (request, response) => {
  const id = parseInt(request.params.id)
  const { name, email } = request.body

  pool.query(
    'UPDATE users SET name = $1, email = $2 WHERE id = $3',
    [name, email, id],
    (error, results) => {
      if (error) {
        throw error
      }
      response.status(200).send(`User modified with ID: ${id}`)
    }
  )
}

const deleteUser = (request, response) => {
  const id = parseInt(request.params.id)

  pool.query('DELETE FROM users WHERE id = $1', [id], (error, results) => {
    if (error) {
      throw error
    }
    response.status(200).send(`User deleted with ID: ${id}`)
  })
}

module.exports = {
  isValidUser,
  getUsers,
  getUserById,
  createUser,
  updateUser,
  deleteUser,
}