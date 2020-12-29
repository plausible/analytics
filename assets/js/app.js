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
