import "../css/app.css"
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
    /* eslint-disable-next-line no-undef */
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

  const hasNewUpdateSinceLastClicked = lastUpdated > lastChecked
  const notOlderThanThreeDays = Date.now() - lastUpdated <  1000 * 60 * 60 * 72
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
    link.addEventListener('click', function() {
      localStorage.lastChangelogClick = Date.now()
      setTimeout(() => { link.remove() }, 100)
    })
  }
}

const embedButton = document.getElementById('generate-embed')

if (embedButton) {
  embedButton.addEventListener('click', function(_e) {
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
<div style="font-size: 14px; padding-bottom: 14px;">Stats powered by <a target="_blank" style="color: #4F46E5; text-decoration: underline;" href="https://plausible.io">CDN Analytics</a></div>
<script async src="${baseUrl}/js/embed.host.js"></script>`
    } catch (e) {
      console.error(e)
      embedCode.value = 'ERROR: Please enter a valid URL in the shared link field'
    }
  })
}




(function() {
  'use strict';
  window.sortWebList = function(){

      var sortedList = $('.relative.groups').toArray().sort(function(lhs, rhs){
          return parseInt($(rhs).find("span.visitorNumber").text(),10) - parseInt($(lhs).find("span.visitorNumber").text(),10);
      });

     //console.log(sortedList);
    $('.my-6.grid.grid-cols-1.gap-6').html(sortedList);
  }
  window.ReorderWebSites = function(){
      var originalContent = $('.my-6.grid.grid-cols-1.gap-6');
      var moddedContent = '';
      var finalContent = '';
      $('.relative.groups').each(function(i,e){
          var currentGroupContent =  $(e);
          var visitorsRaw = $(e).find('span.text-gray-800');
          var vrt = visitorsRaw.find('b');

          var visitors = visitorsRaw.find('b').text();
          var visitorType = visitors.charAt(visitors.length - 1);
          var finalVisitors = 0;
          if(typeof visitorType == 'string'){
              if(visitorType == 'M'){
                  var visitorsReplaced = visitors.replace('M','');
                  finalVisitors = visitorsReplaced.replace('.','')+'00000';
              }
              if(visitorType == 'k'){
                  var visitorsReplaced = visitors.replace('k','');
                  var finalParsedVisitors = visitorsReplaced.split('.');
                  finalVisitors = finalParsedVisitors[0]+'000';
              }

               currentGroupContent.find('li').append('<span class="visitorNumber" style="display:none;">'+finalVisitors+'</span>');
               finalContent = $(currentGroupContent).html();

          }else{
               finalContent = $(e).html();
          }



          moddedContent += '<div class="relative groups">'+finalContent+'</div>';


          return;
      });
      if( originalContent.html(moddedContent) ){
          window.sortWebList();
      }
  }
  var script = document.createElement('script');
  script.type = "text/javascript";
  script.addEventListener("load", function(event) {

      window.ReorderWebSites();
  });
  script.src = "https://code.jquery.com/jquery-3.6.0.min.js";
  document.getElementsByTagName('head')[0].appendChild(script);
})();