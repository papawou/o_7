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
    lobby: {
        table: sql('../../../../_bin/sql/table/lobby.sql'),
        func: sql('../../../../_bin/sql/func/lobby.sql')
    },
    user: {
        table: sql('../../../../_bin/sql/table/user.sql')
    },
    game: {
        table: sql('../../../../_bin/sql/table/game.sql')
    },
    utils: {
        populate: sql('../../../../_bin/sql/utils/populate.sql'),
    },
    test: {
        test_api: sql('../../../../_bin/sql/_test/utils/test_api.sql')
    }
}

export default root