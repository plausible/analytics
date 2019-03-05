import css from "../css/app.css"
import "./polyfills/closest"
import "./stats-modal"
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

function getQueryVariable(variable) {
  var query = window.location.search.substring(1);
  var vars = query.split('&');
  for (var i = 0; i < vars.length; i++) {
    var pair = vars[i].split('=');
    if (decodeURIComponent(pair[0]) == variable) {
      return decodeURIComponent(pair[1]);
    }
  }
}

function defaultDate() {
  const from = getQueryVariable("from")
  const to = getQueryVariable("to")
  return [Date.parse(from), Date.parse(to)]
}

const dateRangeTrigger = document.querySelector('#custom-daterange-trigger')

if (dateRangeTrigger) {
  const picker = flatpickr('#custom-daterange-trigger', {
    mode: "range",
    dateFormat: "M j",
    maxDate: 'today',
    defaultDate: defaultDate(),
    onChange: function(selectedDates, dateStr) {
      if (selectedDates.length === 2) {
        dateRangeTrigger.innerHTML = dateStr.replace("to", "-")
        const from = selectedDates[0].toISOString().substring(0, 10)
        const to = selectedDates[1].toISOString().substring(0, 10)
        document.location = '?period=custom&from=' + from + '&to=' + to
      }
    },
    onOpen: function() {
      dateRangeTrigger.classList.add('text-indigo-darkest')
    },
    onClose: function(selectedDates) {
      if (selectedDates.length !== 2) {
        dateRangeTrigger.classList.remove('text-indigo-darkest')
      }
    }
  })
}
