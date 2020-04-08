const path = require('path');

module.exports = {
    mode: 'production',
    entry: [
        path.join(__dirname, '/frontend/src/index.jsx')
    ],
    output: {
        path: path.join(__dirname, '/frontend/public/build'),
        filename: "bundle.js"
    },
    resolve: {
        extensions: ['.js', '.jsx']
    },
    module: {
        rules: [
            {
                test: /\.jsx?$/,
                exclude: [
                    path.join(__dirname, '/frontend/public/'),
                    path.join(__dirname, '/node_modules/')
                ],
                use: ['babel-loader']
            }
        ]
    }
};
