export const schema = `
type Viewer {
  id: ID!
}

extend type Query {
  viewer: Viewer
}
`

export const resolvers = {
  Query: {
    viewer: async (root, args, context, info) => context.viewer
  }
}

export class Viewer {
  constructor(id) {
    this.id = id
  }

  static gen(id) {
    return new Viewer(id)
  }
}