module.exports = {
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
  corePlugins: {},
  plugins: [
    require('@tailwindcss/ui')
  ],
}
