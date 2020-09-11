const purgecss = require('@fullhuman/postcss-purgecss')({
  content: [
    './js/**/*.js',
    '../lib/plausible_web/templates/**/*.html.eex',
  ],
  defaultExtractor: content => content.match(/[\w-/.:]+(?<!:)/g) || [],
  whitelistPatterns: [/flatpickr\S+/],
  whitelistPatternsChildren: [/flatpickr\S+/]
})

module.exports = {
  plugins: [
    require('tailwindcss'),
    require('autoprefixer'),
    ...process.env.NODE_ENV === 'production'
    ? [purgecss]
    : []
  ]
}
