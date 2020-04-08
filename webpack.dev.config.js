const path = require('path');
const webpack = require('webpack');

module.exports = {
    mode: 'development',
    entry: [
        'webpack-hot-middleware/client',
        path.join(__dirname, '/frontend/src/index.jsx'),
    ],
    output: {
        path: path.join(__dirname, '/frontend/public/build'),
        filename: 'bundle.js',
        publicPath: '/build/'
    },
    resolve: {
        extensions: ['.mjs', '.js', '.jsx']
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
    },
    plugins: [
        new webpack.HotModuleReplacementPlugin()
    ]
};