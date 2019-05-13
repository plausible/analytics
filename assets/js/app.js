import css from "../css/app.css"
import "./polyfills/closest"
import "./stats-modal"
import "./timeframe-selector"
import "phoenix_html"

const trigger = document.querySelector('[data-dropdown-trigger]')

if (trigger) {
  trigger.addEventListener('click', function(e) {
    e.stopPropagation()
    e.currentTarget.nextElementSibling.classList.remove('hidden')
  })

  document.addEventListener('click', function(e) {
    const clickedInDropdown = e.target.closest('[data-dropdown]')
    if (!clickedInDropdown) {
      document.querySelector('[data-dropdown]').classList.add('hidden')
    }
  })
}

const flash = document.getElementById('flash')

if (flash) {
  setTimeout(function() {
    flash.style.display = 'none'
  }, 2500)
}
