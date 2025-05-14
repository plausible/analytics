// This snippet is shown to users to install plausible tracker script

//<script>
window.plausible = window.plausible || function() {
  (window.plausible.q = window.plausible.q || []).push(arguments)
}
window.plausible.init = function(overrides) {
  window.plausible.o = overrides || {}
}

var script = document.createElement("script")
script.type="text/javascript"
script.defer=true
script.src="<%= plausible_script_url %>"
var r = document.getElementsByTagName("script")[0]
r.parentNode.insertBefore(script, r);

//   plausible.init()
//</script>
