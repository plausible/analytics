module.exports = {
  purge: [
    './js/**/*.js',
    '../lib/plausible_web/templates/**/*.html.eex',
  ],
  darkMode: false,
  theme: {
    container: {
      center: true,
      padding: '1rem',
    },
    extend: {
      spacing: {
        '44': '11rem'
      },
      width: {
        '31percent': '31%',
      }
    },
  },
  variants: {
    textColor: ['responsive', 'hover', 'focus', 'group-hover'],
    display: ['responsive', 'hover', 'focus', 'group-hover']
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/aspect-ratio'),
  ]
}
