!function(){"use strict";var t,e,r,s=window.location,f=window.document,d=f.getElementById("plausible"),g=d.getAttribute("data-api")||(t=d.src.split("/"),e=t[0],r=t[2],e+"//"+r+"/api/event");function v(t){console.warn("Ignoring Event: "+t)}function a(t,e){try{if("true"===window.localStorage.plausible_ignore)return v("localStorage flag")}catch(t){}var r=d&&d.getAttribute("data-include"),a=d&&d.getAttribute("data-exclude");if("pageview"===t){var i=!r||r&&r.split(",").some(l),n=a&&a.split(",").some(l);if(!i||n)return v("exclusion rule")}function l(t){var e=s.pathname;return(e+=s.hash).match(new RegExp("^"+t.trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$"))}var o={};o.n=t,o.u=e&&e.u?e.u:s.href,o.d=d.getAttribute("data-domain"),o.r=f.referrer||null,o.w=window.innerWidth,e&&e.meta&&(o.m=JSON.stringify(e.meta)),e&&e.props&&(o.p=e.props);var p=d.getAttributeNames().filter(function(t){return"event-"===t.substring(0,6)}),u=o.p||{};p.forEach(function(t){var e=t.replace("event-",""),r=d.getAttribute(t);u[e]=u[e]||r}),o.p=u,o.h=1;var c=new XMLHttpRequest;c.open("POST",g,!0),c.setRequestHeader("Content-Type","text/plain"),c.send(JSON.stringify(o)),c.onreadystatechange=function(){4===c.readyState&&e&&e.callback&&e.callback()}}var i=window.plausible&&window.plausible.q||[];window.plausible=a;for(var n=0;n<i.length;n++)a.apply(this,i[n]);var u=1;function l(t){if("auxclick"!==t.type||t.button===u){var e,r,a,i,n,l=function(t){for(;t&&(void 0===t.tagName||"a"!==t.tagName.toLowerCase()||!t.href);)t=t.parentNode;return t}(t.target),o=l&&l.href&&l.href.split("?")[0];if(function(t){if(!t)return!1;var e=t.split(".").pop();return w.some(function(t){return t===e})}(o)){return i={url:o},n=!(a="File Download"),void(!function(t,e){if(!t.defaultPrevented){var r=!e.target||e.target.match(/^_(self|parent|top)$/i),a=!(t.ctrlKey||t.metaKey||t.shiftKey)&&"click"===t.type;return r&&a}}(e=t,r=l)?plausible(a,{props:i}):(plausible(a,{props:i,callback:p}),setTimeout(p,5e3),e.preventDefault()))}}function p(){n||(n=!0,window.location=r.href)}}f.addEventListener("click",l),f.addEventListener("auxclick",l);var o=["pdf","xlsx","docx","txt","rtf","csv","exe","key","pps","ppt","pptx","7z","pkg","rar","gz","zip","avi","mov","mp4","mpeg","wmv","midi","mp3","wav","wma"],p=d.getAttribute("file-types"),c=d.getAttribute("add-file-types"),w=p&&p.split(",")||c&&c.split(",").concat(o)||o}();