import db from '../postgresql/client'
import sql from '../postgresql/sql/root'
import { Loaders } from '../dataloader/root'
import { Viewer } from './schemas/users/Viewer'

export class Context {
    constructor(request, response, viewer) {
        this.res = response
        this.req = request
        this.viewer = viewer
        this.db = db
        this.sql = sql
        this.dl = new Loaders(this)
    }

    static async gen(req, res) {
        let viewer = req.session._id ? await Viewer.gen(req.session._id) : null
        return new Context(req, res, viewer)
    }
}