const path = require('path');
const webpack = require('webpack');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const TerserPlugin = require('terser-webpack-plugin');
const CssMinimizerWebpackPlugin = require('css-minimizer-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');

/** @type {import('webpack').Configuration} */
module.exports = (_env, _options) => ({
  optimization: {
    minimizer: [
      new TerserPlugin(),
      new CssMinimizerWebpackPlugin()
    ]
  },
  entry: {
      'app': ['./js/app.tsx'],
      'dashboard': ['./js/dashboard/mount.tsx'],
      'embed.host': ['./js/embed.host.tsx'],
      'embed.content': ['./js/embed.content.tsx']
  },
  output: {
    filename: '[name].js',
    path: path.resolve(__dirname, '../priv/static/js')
  },
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        use: 'ts-loader',
        exclude: /node_modules/,
      },
      {
        test: /\.css$/,
        use: [MiniCssExtractPlugin.loader, 'css-loader', 'postcss-loader']
      }
    ]
  },
  resolve: {
    extensions: ['.tsx', '.ts', '.js'],
  },
  externals: { moment: 'moment' },
  plugins: [
    new MiniCssExtractPlugin({filename: '../css/[name].css'}),
    new CopyWebpackPlugin({patterns: [{from: 'static/', to: '../' }]}),
    new webpack.ProvidePlugin({
      ResizeObserver: ['@juggle/resize-observer', 'ResizeObserver'] // https://caniuse.com/?search=ResizeObserver
    })
  ]
});
