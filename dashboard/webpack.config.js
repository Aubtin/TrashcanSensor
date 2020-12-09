const path = require('path');

module.exports = {
    context: path.resolve(__dirname, "src"),
    entry: "./index.js",
    devServer: {
        contentBase: "./public/",
        compress: true,
        historyApiFallback: true
    },
    output: {
        filename: 'bundle.js',
        publicPath: "/"
    },
    module: {
        rules: [
            {
                test: /.(js|jsx)$/,
                exclude: /node_modules/,
                use: {
                    loader: "babel-loader"
                }
            }
        ]
    }
}
