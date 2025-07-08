// Code for tracking tagged events, form submissions, file downloads and outbound links
import { config, scriptEl, location, document } from './config'
import { track } from './track'

export var DEFAULT_FILE_TYPES = ['pdf', 'xlsx', 'docx', 'txt', 'rtf', 'csv', 'exe', 'key', 'pps', 'ppt', 'pptx', '7z', 'pkg', 'rar', 'gz', 'zip', 'avi', 'mov', 'mp4', 'mpeg', 'wmv', 'midi', 'mp3', 'wav', 'wma', 'dmg']

var MIDDLE_MOUSE_BUTTON = 1
var PARENTS_TO_SEARCH_LIMIT = 3
var fileTypesToTrack = DEFAULT_FILE_TYPES

function getLinkEl(link) {
  while (link && (typeof link.tagName === 'undefined' || !isLink(link) || !link.href)) {
    link = link.parentNode
  }
  return link
}

function isLink(element) {
  return element && element.tagName && element.tagName.toLowerCase() === 'a'
}

function shouldFollowLink(event, link) {
  // If default has been prevented by an external script, Plausible should not intercept navigation.
  if (event.defaultPrevented) { return false }

  var targetsCurrentWindow = !link.target || link.target.match(/^_(self|parent|top)$/i)
  var isRegularClick = !(event.ctrlKey || event.metaKey || event.shiftKey) && event.type === 'click'
  return targetsCurrentWindow && isRegularClick
}

function handleLinkClickEvent(event) {
  if (event.type === 'auxclick' && event.button !== MIDDLE_MOUSE_BUTTON) { return }

  var link = getLinkEl(event.target)
  var hrefWithoutQuery = link && link.href && link.href.split('?')[0]

  if (COMPILE_TAGGED_EVENTS) {
    if (isElementOrParentTagged(link, 0)) {
      // Return to prevent sending multiple events with the same action.
      // Clicks on tagged links are handled by another function.
      return
    }
  }

  if (COMPILE_OUTBOUND_LINKS && (!COMPILE_CONFIG || config.outboundLinks)) {
    if (isOutboundLink(link)) {
      return sendLinkClickEvent(event, link, { name: 'Outbound Link: Click', props: { url: link.href } })
    }
  }

  if (COMPILE_FILE_DOWNLOADS && (!COMPILE_CONFIG || config.fileDownloads)) {
    if (isDownloadToTrack(hrefWithoutQuery)) {
      return sendLinkClickEvent(event, link, { name: 'File Download', props: { url: hrefWithoutQuery } })
    }
  }
}

function sendLinkClickEvent(event, link, eventAttrs) {
  // In some legacy variants, this block delays opening the link up to 5 seconds,
  // or until analytics request finishes, otherwise navigation prevents the analytics event from being sent.
  if (COMPILE_COMPAT) {
  var followedLink = false

  function followLink() {
    if (!followedLink) {
      followedLink = true
      window.location = link.href
    }
  }

  if (shouldFollowLink(event, link)) {
    var attrs = { props: eventAttrs.props, callback: followLink }
    if (COMPILE_REVENUE) {
      attrs.revenue = eventAttrs.revenue
    }
    track(eventAttrs.name, attrs)
    setTimeout(followLink, 5000)
    event.preventDefault()
  } else {
    var attrs = { props: eventAttrs.props }
    if (COMPILE_REVENUE) {
      attrs.revenue = eventAttrs.revenue
    }
    track(eventAttrs.name, attrs)
  }
  } else {
  var attrs = { props: eventAttrs.props }
  if (COMPILE_REVENUE) {
    attrs.revenue = eventAttrs.revenue
  }
  track(eventAttrs.name, attrs)
  }
}

function isOutboundLink(link) {
  return link && link.href && link.host && link.host !== location.host
}

function isDownloadToTrack(url) {
  if (!url) { return false }

  var fileType = url.split('.').pop();
  return fileTypesToTrack.some(function (fileTypeToTrack) {
    return fileTypeToTrack === fileType
  })
}

function isTagged(element) {
  var classList = element && element.classList
  if (classList) {
    for (var i = 0; i < classList.length; i++) {
      if (classList.item(i).match(/plausible-event-name(=|--)(.+)/)) { return true }
    }
  }
  return false
}

function isElementOrParentTagged(element, parentsChecked) {
  if (!element || parentsChecked > PARENTS_TO_SEARCH_LIMIT) { return false }
  if (isTagged(element)) { return true }
  return isElementOrParentTagged(element.parentNode, parentsChecked + 1)
}

// Finds event attributes by iterating over the given element's (or its
// parent's) classList. Returns an object with `name` and `props` keys.
function getTaggedEventAttributes(htmlElement) {
  var taggedElement = isTagged(htmlElement) ? htmlElement : htmlElement && htmlElement.parentNode
  var eventAttrs = { name: null, props: {} }
  if (COMPILE_REVENUE) {
    eventAttrs.revenue = {}
  }

  var classList = taggedElement && taggedElement.classList
  if (!classList) { return eventAttrs }

  for (var i = 0; i < classList.length; i++) {
    var className = classList.item(i)

    var matchList = className.match(/plausible-event-(.+)(=|--)(.+)/)
    if (matchList) {
      var key = matchList[1]
      var value = matchList[3].replace(/\+/g, ' ')

      if (key.toLowerCase() == 'name') {
        eventAttrs.name = value
      } else {
        eventAttrs.props[key] = value
      }
    }

    if (COMPILE_REVENUE) {
      var revenueMatchList = className.match(/plausible-revenue-(.+)(=|--)(.+)/)
      if (revenueMatchList) {
        var key = revenueMatchList[1]
        var value = revenueMatchList[3]
        eventAttrs.revenue[key] = value
      }
    }
  }

  return eventAttrs
}

export function init() {
  document.addEventListener('click', handleLinkClickEvent)
  document.addEventListener('auxclick', handleLinkClickEvent)

  if (COMPILE_FILE_DOWNLOADS && (!COMPILE_CONFIG || config.fileDownloads)) {
    if (COMPILE_CONFIG) {
      if (typeof config.fileDownloads === 'object' && Array.isArray(config.fileDownloads.fileExtensions)) {
        fileTypesToTrack = config.fileDownloads.fileExtensions
      }
    } else {
      var fileTypesAttr = scriptEl.getAttribute('file-types')
      var addFileTypesAttr = scriptEl.getAttribute('add-file-types')

      if (fileTypesAttr) {
        fileTypesToTrack = fileTypesAttr.split(",")
      }
      if (addFileTypesAttr) {
        fileTypesToTrack = addFileTypesAttr.split(",").concat(DEFAULT_FILE_TYPES)
      }
    }

  }

  if (COMPILE_CONFIG && config.formSubmissions) {
    function trackFormSubmission(e) {
      if (e.target.hasAttribute('novalidate') || e.target.checkValidity()) {
        if (COMPILE_TAGGED_EVENTS && isElementOrParentTagged(e.target, 0)) {
          // If the form is tagged, we don't track it as a generic form submission.
          return
        }
        track('Form: Submission');
      }
    }

    document.addEventListener('submit', trackFormSubmission, true);
  }

  if (COMPILE_TAGGED_EVENTS) {
    function handleTaggedFormSubmitEvent(event) {
      var form = event.target
      var eventAttrs = getTaggedEventAttributes(form)
      if (!eventAttrs.name) { return }

      // In some legacy variants, this block delays submitting the form for up to 5 seconds,
      // or until analytics request finishes, otherwise form-related navigation can prevent the analytics event from being sent.
      if (COMPILE_COMPAT) {
      event.preventDefault()
      var formSubmitted = false

      function submitForm() {
        if (!formSubmitted) {
          formSubmitted = true
          form.submit()
        }
      }

      setTimeout(submitForm, 5000)

      var attrs = { props: eventAttrs.props, callback: submitForm }
      if (COMPILE_REVENUE) {
        attrs.revenue = eventAttrs.revenue
      }
      track(eventAttrs.name, attrs)
      } else {
      var attrs = { props: eventAttrs.props }
      if (COMPILE_REVENUE) {
        attrs.revenue = eventAttrs.revenue
      }
      track(eventAttrs.name, attrs)
      }
    }

    function isForm(element) {
      return element && element.tagName && element.tagName.toLowerCase() === 'form'
    }

    function handleTaggedElementClickEvent(event) {
      if (event.type === 'auxclick' && event.button !== MIDDLE_MOUSE_BUTTON) { return }

      var clicked = event.target

      var clickedLink
      var taggedElement
      // Iterate over parents to find the tagged element. Also search for
      // a link element to call for different tracking behavior if found.
      for (var i = 0; i <= PARENTS_TO_SEARCH_LIMIT; i++) {
        if (!clicked) { break }

        // Clicks inside forms are not tracked. Only form submits are.
        if (isForm(clicked)) { return }
        if (isLink(clicked)) { clickedLink = clicked }
        if (isTagged(clicked)) { taggedElement = clicked }
        clicked = clicked.parentNode
      }

      if (taggedElement) {
        var eventAttrs = getTaggedEventAttributes(taggedElement)

        if (clickedLink) {
          // if the clicked tagged element is a link, we attach the `url` property
          // automatically for user convenience
          eventAttrs.props.url = clickedLink.href
          sendLinkClickEvent(event, clickedLink, eventAttrs)
        } else {
          var attrs = {}
          attrs.props = eventAttrs.props
          if (COMPILE_REVENUE) {
            attrs.revenue = eventAttrs.revenue
          }
          track(eventAttrs.name, attrs)
        }
      }
    }

    document.addEventListener('submit', handleTaggedFormSubmitEvent)
    document.addEventListener('click', handleTaggedElementClickEvent)
    document.addEventListener('auxclick', handleTaggedElementClickEvent)
  }
}
