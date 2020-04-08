import { QueryFile } from 'pg-promise'
import path from 'path'

const sql = (file) => {
    const fullPath = path.join(__dirname, file)
    const options = {
        minify: true
    }
    const qf = new QueryFile(fullPath, options);
    if (qf.error) {
        console.error(qf.error)
    }
    return qf
}

const root = {
    request: sql('./request.sql'),
    member: sql('./member.sql'),
    team: sql('./team.sql')
}

export default root