import * as jwt from '../jwt'

let token = jwt.sign({ test: "1", sub: { id_lobby: 1, id_viewer: 2 } }, { expiresIn: "2d" })
console.log(token)
let payload = jwt.verify(token)
console.log(payload)