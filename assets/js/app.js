import css from "../css/app.css"
import "flatpickr/dist/flatpickr.min.css"
import "./polyfills/closest"
import 'abortcontroller-polyfill/dist/polyfill-patch-fetch'
import "phoenix_html"
import 'alpinejs'

const triggers = document.querySelectorAll('[data-dropdown-trigger]')

for (const trigger of triggers) {
  trigger.addEventListener('click', function(e) {
    e.stopPropagation()
    e.currentTarget.nextElementSibling.classList.remove('hidden')
  })
}

if (triggers.length > 0) {
  document.addEventListener('click', function(e) {
    const dropdown = e.target.closest('[data-dropdown]')

    if (dropdown && e.target.tagName === 'A') {
      dropdown.classList.add('hidden')
    }
  })

  document.addEventListener('click', function(e) {
    const clickedInDropdown = e.target.closest('[data-dropdown]')

    if (!clickedInDropdown) {
      for (const dropdown of document.querySelectorAll('[data-dropdown]')) {
        dropdown.classList.add('hidden')
      }
    }
  })
}

const registerForm = document.getElementById('register-form')

if (registerForm) {
  registerForm.addEventListener('submit', function(e) {
    e.preventDefault();
    setTimeout(submitForm, 1000);
    var formSubmitted = false;

    function submitForm() {
      if (!formSubmitted) {
        formSubmitted = true;
        registerForm.submit();
      }
    }

    plausible('Signup', {callback: submitForm});
  })
}

const changelogNotification = document.getElementById('changelog-notification')

if (changelogNotification) {
  showChangelogNotification(changelogNotification)

  fetch('https://plausible.io/changes.txt', {headers: {'Content-Type': 'text/plain'}})
    .then((res) => res.text())
    .then((res) => {
      localStorage.lastChangelogUpdate = new Date(res).getTime()
      showChangelogNotification(changelogNotification)
  })
}

function showChangelogNotification(el) {
  const lastUpdated = Number(localStorage.lastChangelogUpdate)
  const lastChecked = Number(localStorage.lastChangelogClick)

  if (lastChecked) {
    const hasNewUpdateSinceLastClicked = lastUpdated > lastChecked
    const notOlderThanThreeDays = Date.now() - lastUpdated <  1000 * 60 * 60 * 72
    if (hasNewUpdateSinceLastClicked && notOlderThanThreeDays) {
      el.innerHTML = `
        <a href="https://plausible.io/changelog" target="_blank">
          <svg class="w-5 h-5 text-gray-600 " fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v13m0-13V6a2 2 0 112 2h-2zm0 0V5.5A2.5 2.5 0 109.5 8H12zm-7 4h14M5 12a2 2 0 110-4h14a2 2 0 110 4M5 12v7a2 2 0 002 2h10a2 2 0 002-2v-7"></path>
          </svg>
          <svg class="w-4 h-4 text-pink-500 absolute" style="left: 14px; top: 2px;" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <circle cx="8" cy="8" r="4" fill="currentColor" />
          </svg>
        </a>
        `
      const link = el.getElementsByTagName('a')[0]
      link.addEventListener('click', function() {
        localStorage.lastChangelogClick = Date.now()
        setTimeout(() => { link.remove() }, 100)
      })
    }
  } else {
    localStorage.lastChangelogClick = Date.now()
  }
}
