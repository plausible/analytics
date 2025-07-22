# Plausible Analytics tracker

[![NPM](https://flat.badgen.net/npm/v/macobo-test-tracker)](https://www.npmjs.com/package/macobo-test-tracker)
[![MIT License](https://img.shields.io/badge/License-MIT-red.svg?style=flat-square)](https://opensource.org/licenses/MIT)

**Notice:** This library is currently under development and will be released as an official library later this year.

Add [Plausible Analytics](https://plausible.io/) to your website.

## Features
- Small package size
- Same features and codebase as the official script, but as an NPM module
- Automatically track page views in your SPA apps
- Track goals and custom events
- Provide manual values that will be bound to the event
- Full typescript support

> **Important:** This library only works in browser environments. When using server-side rendering (SSR), the `init` and `track` functions will not work as they rely on browser APIs. Make sure to only initialize and track events on the client side.

## Package Installation

With npm:

```bash
npm install macobo-test-tracker
```

## Usage

To begin tracking events, you must initialize the tracker:

```javascript
import { init } from 'macobo-test-tracker'

init({
  domain: 'my-app.com'
})
```

### Configuration options

See also [plausible.d.ts](https://github.com/plausible/analytics/blob/master/tracker/npm_package/plausible.d.ts) for typescript types.

| Option | Description | Default |
| --- | --- | --- |
| `domain` | **Required** Your site's domain, as declared by you in Plausible's settings. | |
| `endpoint` | The URL of the Plausible API endpoint. See proxying guide at https://plausible.io/docs/proxy/introduction | `"https://plausible.io/api/event"` |
| `autoCapturePageviews` | Whether to automatically capture pageviews. | `true` |
| `hashBasedRouting` | Whether the page uses hash based routing. Read more at https://plausible.io/docs/hash-based-routing | `false` |
| `outboundLinks` | Whether to track outbound link clicks. | `false` |
| `fileDownloads` |  Whether to track file downloads. | `false` |
| `formSubmissions` | Whether to track form submissions. | `false` |
| `captureOnLocalhost` | Whether to capture events on localhost. | `false` |
| `logging` | Whether to log on ignored events. | `true` |
| `customProperties` | Object or function that returns custom properties for a given event. | `{}` |
| `transformRequest` | Function that allows transforming or ignoring requests | |
| `bindToWindow` | Binds `track` to `window.plausible` which is used by Plausible installation verification tool to detect whether Plausible has been installed correctly. If `bindToWindow` is set to false, the installation verification tool won't be able to automatically detect it on your site.  | `true` |

#### Using `customProperties`

To track a custom property with every page view, you can use the `customProperties` configuration option:

```javascript
init({
  domain: 'my-app.com',
  customProperties: { "content_category": "news" }
})
```

`customProperties` can also be a dynamic function:

```javascript
init({
  domain: 'my-app.com',
  customProperties: (eventName) => ({ "title": document.title })
})
```

### Tracking custom events

To track a custom event, call `track` and give it the name of the event. Custom properties can be passed as a second argument:

```javascript
import { track } from 'macobo-test-tracker'

track('signup', { props: { tier: "startup" } })
```

To mark an event as non-interactive so it would not be counted towards bounce rate calculations, set `interactive` option:

```javascript
track('autoplay', { interactive: false })
```

### Revenue tracking

To track an event with revenue information, do:

```javascript
import { track } from 'macobo-test-tracker'

track('Purchase', { revenue: { amount: 15.99, currency: 'USD' } })
```

More information can be found in [ecommerce revenue tracking docs](https://plausible.io/docs/ecommerce-revenue-tracking)

### Callbacks

When calling `track`, you can pass in a custom callback.

```javascript
import { track } from 'macobo-test-tracker'

track('some-event', {
  callback: (result) => {
    if (result?.status) {
      console.debug("Request to plausible done. Status:", result.status)
    } else if (result?.error) {
      console.log("Error handling request:", result.error)
    } else {
      console.log("Request was ignored")
    }
  }
})
```

### Opt out and exclude yourself from the analytics

Since plausible-tracker is bundled with your application code, using an ad-blocker to exclude your visits isn't an option. Fortunately Plausible has an alternative for this scenario: plausible-tracker will not send events if `localStorage.plausible_ignore` is set to `"true"`.

More information about this method can be found in the [Plausible documentation](https://plausible.io/docs/excluding-localstorage).
