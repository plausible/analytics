import './polyfills/closest'
import 'abortcontroller-polyfill/dist/polyfill-patch-fetch'
import Alpine from 'alpinejs'
import './liveview/live_socket'
import comboBox from './liveview/combo-box'
import dropdown from './liveview/dropdown'
import './liveview/phx_events'

Alpine.data('dropdown', dropdown)
Alpine.data('comboBox', comboBox)
Alpine.start()

if (document.querySelectorAll('[data-modal]').length > 0) {
  window.addEventListener(`phx:close-modal`, (e) => {
    document
      .getElementById(e.detail.id)
      .dispatchEvent(
        new CustomEvent('close-modal', { bubbles: true, detail: e.detail.id })
      )
  })
  window.addEventListener(`phx:open-modal`, (e) => {
    document
      .getElementById(e.detail.id)
      .dispatchEvent(
        new CustomEvent('open-modal', { bubbles: true, detail: e.detail.id })
      )
  })
}

const triggers = document.querySelectorAll('[data-dropdown-trigger]')

for (const trigger of triggers) {
  trigger.addEventListener('click', function (e) {
    e.stopPropagation()
    e.currentTarget.nextElementSibling.classList.remove('hidden')
  })
}

if (triggers.length > 0) {
  document.addEventListener('click', function (e) {
    const dropdown = e.target.closest('[data-dropdown]')

    if (dropdown && e.target.tagName === 'A') {
      dropdown.classList.add('hidden')
    }
  })

  document.addEventListener('click', function (e) {
    const clickedInDropdown = e.target.closest('[data-dropdown]')

    if (!clickedInDropdown) {
      for (const dropdown of document.querySelectorAll('[data-dropdown]')) {
        dropdown.classList.add('hidden')
      }
    }
  })
}

const changelogNotification = document.getElementById('changelog-notification')

if (changelogNotification) {
  showChangelogNotification(changelogNotification)

  fetch('https://plausible.io/changes.txt', {
    headers: { 'Content-Type': 'text/plain' }
  })
    .then((res) => res.text())
    .then((res) => {
      localStorage.lastChangelogUpdate = new Date(res).getTime()
      showChangelogNotification(changelogNotification)
    })
}

function showChangelogNotification(el) {
  const lastUpdated = Number(localStorage.lastChangelogUpdate)
  const lastChecked = Number(localStorage.lastChangelogClick)

  const hasNewUpdateSinceLastClicked = lastUpdated > lastChecked
  const notOlderThanThreeDays = Date.now() - lastUpdated < 1000 * 60 * 60 * 72
  if ((!lastChecked || hasNewUpdateSinceLastClicked) && notOlderThanThreeDays) {
    el.innerHTML = `
      <a href="https://plausible.io/changelog" target="_blank">
        <svg class="w-5 h-5 text-gray-600 dark:text-gray-100" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v13m0-13V6a2 2 0 112 2h-2zm0 0V5.5A2.5 2.5 0 109.5 8H12zm-7 4h14M5 12a2 2 0 110-4h14a2 2 0 110 4M5 12v7a2 2 0 002 2h10a2 2 0 002-2v-7"></path>
        </svg>
        <svg class="w-4 h-4 text-pink-500 absolute" style="left: 14px; top: 2px;" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
        <circle cx="8" cy="8" r="4" fill="currentColor" />
        </svg>
      </a>
      `
    const link = el.getElementsByTagName('a')[0]
    link.addEventListener('click', function () {
      localStorage.lastChangelogClick = Date.now()
      setTimeout(() => {
        link.remove()
      }, 100)
    })
  }
}

const embedButton = document.getElementById('generate-embed')

if (embedButton) {
  embedButton.addEventListener('click', function (_e) {
    const baseUrl = document.getElementById('base-url').value
    const embedCode = document.getElementById('embed-code')
    const theme = document.getElementById('theme').value.toLowerCase()
    const background = document.getElementById('background').value

    try {
      const embedLink = new URL(document.getElementById('embed-link').value)
      embedLink.searchParams.set('embed', 'true')
      embedLink.searchParams.set('theme', theme)
      if (background) {
        embedLink.searchParams.set('background', background)
      }

      embedCode.value = `<iframe plausible-embed src="${embedLink.toString()}" scrolling="no" frameborder="0" loading="lazy" style="width: 1px; min-width: 100%; height: 1600px;"></iframe>
<div style="font-size: 14px; padding-bottom: 14px;">Stats powered by <a target="_blank" style="color: #4F46E5; text-decoration: underline;" href="https://plausible.io">Plausible Analytics</a></div>
<script async src="${baseUrl}/js/embed.host.js"></script>`
    } catch (e) {
      console.error(e)
      embedCode.value =
        'ERROR: Please enter a valid URL in the shared link field'
    }
  })
}
