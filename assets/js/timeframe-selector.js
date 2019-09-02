const selector = document.querySelector('[data-timeframe-select]')

if (selector) {
  selector.addEventListener('change', function(e) {
    if (e.target.value === 'Day') {
      document.location = '?period=day'
    } else if (e.target.value === 'Week') {
      document.location = '?period=week'
    } else if (e.target.value === 'Month') {
      document.location = '?period=month'
    } else if (e.target.value === 'Last 3 Months') {
      document.location = '?period=3mo'
    } else if (e.target.value === 'Last 6 Months') {
      document.location = '?period=6mo'
    } else if (e.target.value === 'Custom') {
      const parent = e.target.closest('div')
      parent.classList.add('hidden')
      parent.nextElementSibling.classList.remove('hidden')
    }
  })
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

function dateToISOString(date) {
  const year = date.getFullYear();
  let month = date.getMonth()+1;
  let dt = date.getDate();

  if (dt < 10) {
    dt = '0' + dt;
  }
  if (month < 10) {
    month = '0' + month;
  }

  return year + '-' + month + '-'+ dt;
}

const dateRangeTrigger = document.querySelector('#custom-daterange-trigger')

if (dateRangeTrigger) {
  const picker = flatpickr('#custom-daterange-trigger', {
    mode: "range",
    dateFormat: "M j",
    maxDate: 'today',
    onChange: function(selectedDates, dateStr) {
      if (selectedDates.length === 2) {
        dateRangeTrigger.innerHTML = dateStr
        const from = dateToISOString(selectedDates[0])
        const to = dateToISOString(selectedDates[1])
        document.location = '?period=custom&from=' + from + '&to=' + to
      }
    },
  })
}
