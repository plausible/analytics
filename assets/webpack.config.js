const path = require('path');
const glob = require('glob');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const TerserPlugin = require('terser-webpack-plugin');
const OptimizeCSSAssetsPlugin = require('optimize-css-assets-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');

module.exports = (env, options) => ({
  optimization: {
    minimizer: [
      new TerserPlugin(),
      new OptimizeCSSAssetsPlugin({})
    ]
  },
  entry: {
      'app': ['./js/app.js'],
      'dashboard': ['./js/dashboard/mount.js'],
      'embed.host': ['./js/embed.host.js'],
      'embed.content': ['./js/embed.content.js']
  },
  output: {
    filename: '[name].js',
    path: path.resolve(__dirname, '../priv/static/js')
  },
  module: {
    rules: [
      {
        test: /\.(js|jsx)$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader'
        }
      },
      {
        test: /\.css$/,
        use: [MiniCssExtractPlugin.loader, 'css-loader', 'postcss-loader']
      }
    ]
  },
  externals: { moment: 'moment' },
  plugins: [
    new MiniCssExtractPlugin({filename: '../css/[name].css'}),
    new CopyWebpackPlugin({patterns: [{from: 'static/', to: '../' }]}),
  ]
});
