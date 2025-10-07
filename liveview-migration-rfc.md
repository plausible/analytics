- Feature Name: dashboard_liveview_migration
- Start Date: 2025-10-07
- RFC PR: [RFC#0000](https://github.com/plausible/knowledge_base/pr/...)

# Summary
[summary]: #summary

Migrate the Plausible analytics dashboard from React to Phoenix LiveView through a two-phase approach: (1) incrementally replace individual reports using iframe widgets, then (2) migrate the remaining UI state management, routing, and interactive components in a single coordinated change.

# Motivation
[motivation]: #motivation

The current React-based dashboard creates several challenges:
- Testing requires separate frontend and backend test suites
- Adding integration tests is difficult
- Maintaining two technology stacks (React + Elixir) increases cognitive load and onboarding time
- Glue code between frontend/backend adds complexity and maintenance burden
- UI components cannot be shared between dashboard and rest of application

LiveView migration enables:
- Full-stack integration testing of dashboard features with backend logic
- Shared component library across entire application (dashboard, settings, /sites)
- Single technology stack for faster onboarding and development
- Unified query building with `Query.build()` (does not necessarily depend on liveview migration)

**What is the expected outcome?**

A fully LiveView-based dashboard that:
- Maintains feature parity with current React implementation
- Provides equivalent or better user experience
- Reduces codebase complexity and maintenance burden
- Enables faster feature development through unified stack
- Cleans up Query.from() technical debt

# Guide-level explanation
[guide-level-explanation]: #guide-level-explanation

## Phase 1: Incremental Report Migration

In Phase 1, we convert individual reports to LiveView while keeping React in control of overall dashboard state. This allows us to migrate incrementally with lower risk.

**How it works:**

1. React embeds each LiveView report in an `<iframe>`
2. URL parameters pass query state (filters, dates, comparisons) to the iframe
3. React shows loading spinner while waiting for LiveView to load in hidden state
4. The iframe sends messages back to React via `postMessage`:
   - Report loading state
   - User interactions that change UI state
7. React updates URL parameters when state changes, triggering iframe reload

Loading states must remain controlled by React because the initial page render is done by React.
If spinners were shown via LiveView, there would be a blank empty state, then a server roundtrip, and only then would the spinner appear - creating a poor user experience.

:Example in companion PR:

**Reports to migrate in Phase 1:**
- Top Stats
- Main Graph
- Sources (all tabs: sources, channels, UTM parameters)
- Pages (top pages, entry pages, exit pages)
- Locations (countries, regions, cities, map)
- Devices (browsers, OS, screen sizes)
- Goals/Conversions
- Custom Props
- Funnels
- All drilldown modal contents (sources, pages, locations, devices, etc.)

**Other that can be migrated early:**
- Realtime visitor widget (not involved in routing)
- Site picker (independent component)

## Phase 2: Complete Migration

Phase 2 migrates all remaining UI state management and routing in a single coordinated change. This phase cannot be split up because routing, modals, filters, and date selection are interdependent.

**Features that need to be replicated in LiveView:**
- Frontend routing and URL state management
- Modal open/closed states and transitions
- Filter management (add, remove, display pills)
- Date picker and comparison controls
- Segment creation/editing
- Loading states and error handling
- Keyboard shortcuts
- User preferences in localStorage
- Incremental report loading based on report visibility in viewport (doable in liveview? if so, is it worth it?)

**Components to migrate:**
- Date picker with calendar UI
- Filter/Segments dropdown
- Filter modals

These components are very interactive, deal with internals of UI state and depend heavily on it. This is why they're planned in phase 2.

# Reference-level explanation
[reference-level-explanation]: #reference-level-explanation

## Architecture Overview

### Current React Architecture

```
Browser
├── React App (assets/js/dashboard.tsx)
│   ├── Router (react-router-dom)
│   ├── Context Providers
│   │   ├── QueryContext (URL-based state)
│   │   ├── SiteContext
│   │   ├── UserContext
│   │   ├── ThemeContext
│   │   ├── SegmentsContext
│   │   └── LastLoadContext
│   ├── Dashboard Layout
│   │   ├── TopBar
│   │   │   ├── SiteSwitcher
│   │   │   ├── CurrentVisitors
│   │   │   ├── FiltersBar
│   │   │   ├── FilterMenu
│   │   │   ├── SegmentMenu
│   │   │   └── QueryPeriodsPicker
│   │   └── Reports
│   │       ├── VisitorGraph
│   │       ├── Sources
│   │       ├── Pages
│   │       ├── Locations
│   │       ├── Devices
│   │       └── Behaviours
│   └── Modals (React Router routes)
└── API calls to /api/stats/*
```

### Target LiveView Architecture (sketch)

```
Phoenix LiveView
├── DashboardLive (lib/plausible_web/live/dashboard_live.ex)
│   ├── Mount & Handle Params (URL state)
│   ├── Socket Assigns
│   │   ├── query (filters, dates, comparison)
│   │   ├── site
│   │   ├── user
│   │   ├── segments
│   │   └── preferences
│   ├── LiveComponents
│   │   ├── TopBarComponent
│   │   │   ├── SiteSwitcherComponent
│   │   │   ├── CurrentVisitorsComponent
│   │   │   ├── FiltersBarComponent
│   │   │   ├── FilterMenuComponent
│   │   │   ├── SegmentMenuComponent
│   │   │   └── DatePickerComponent
│   │   └── Report Components
│   │       ├── VisitorGraphComponent
│   │       ├── SourcesComponent
│   │       ├── PagesComponent
│   │       ├── LocationsComponent
│   │       ├── DevicesComponent
│   │       └── BehavioursComponent
│   └── Modal Components (live_patch routes)
└── Query.build() for data fetching
```

## Phase 1 Implementation Details

### LiveViewIframe Component

**Location:** `assets/js/dashboard/stats/liveview-iframe.tsx`

```typescript
export function LiveViewIframe({
  src,
  onMessage,
  minHeight
}: LiveViewIframeProps) {
  // Auto-resizes based on content
  // Forwards postMessage events to React
}
```

### Communication Protocol

**React → LiveView (via URL params):**
```
/live/:domain/:report?
  period=30d
  &filters=[["visit:country","is","US"]]
  &comparison=previous_period
  &match_day_of_week=true
  &from=2024-01-01
  &to=2024-01-31
```

**LiveView → React (via postMessage):**
```javascript
{ type: "EMBEDDED_LV_LOADED" }   // Sent after data fetched and rendered
{ type: "EMBEDDED_LV_LOADING_ERROR" }   // Sent after data fetched and rendered

// User interactions
{ type: "EMBEDDED_LV_TOP_STATS_SELECT", metric: "visitors" }
{ type: "EMBEDDED_LV_FILTER_CLICK", dimension: "visit:country", value: "US" }
```

### TODO: Main graph, funnel visualizations, maps

## Phase 2 Implementation Details

This section attempts to sketch out possible implementation strategies for managing UI state and migrating complex components.

### Localstorage preferences migration

Keep user preferences in localStorage and pass them to LiveView on initial connection using `connect_params`.

**Implementation:**

1. **Client-side hook** reads localStorage on LiveView socket connection:

```javascript
// app.js
let liveSocket = new LiveSocket("/live", Socket, {
  params: (liveViewName) => {
    const domain = getDomainSomehow()
    return {
      _csrf_token: csrfToken,
      user_prefs: {
        period: localStorage.getItem(`period__${domain}`),
        comparison_mode: localStorage.getItem(`comparison_mode__${domain}`),
        match_day_of_week: localStorage.getItem(`comparison_match_day_of_week__${domain}`),
        metric: localStorage.getItem(`metric__${domain}`)
        // etc
      }
    }
  }
})
```

2. **LiveView mount** receives preferences via `get_connect_params`:

```elixir
defmodule PlausibleWeb.DashboardLive do
  use PlausibleWeb, :live_view

  def mount(_params, _session, socket) do
    user_prefs = get_connect_params(socket)["user_prefs"] || %{}

    socket =
      socket
      |> assign(:user_prefs, user_prefs)

    {:ok, socket}
  end
end
```

3. **Updating preferences** - Use JS commands to update localStorage:

```elixir
def handle_event("update_period", %{"period" => period}, socket) do
  domain = socket.assigns.site.domain

  socket =
    socket
    |> assign(:period, period)
    |> push_event("update_local_storage", %{
      key: "period__#{domain}",
      value: period
    })

  {:noreply, socket}
end
```

```javascript
// Client hook
window.addEventListener("phx:update_local_storage", (e) => {
  localStorage.setItem(e.detail.key, e.detail.value)
})
```

### Date Picker Component

Use a JS hook to integrate existing flatpickr library. Prior art: https://gist.github.com/mcrumm/88313d9f210ea17a640e673ff0d0232b

### Loading States & Optimistic UI

In order to keep the UX as good as it is with React, we need to ensure the UI gets updated optimistically and loading states are handled well.

https://hexdocs.pm/phoenix_live_view/syncing-changes.html

* Display loading states
* Optimistically update datepicker text, so we don't show stale date period while server is loading
* Optmimistically update filter pills, so adding filters gives immediate UX feedback
* Modals open/close with immediate UX feedback
* Switching between report tabs updates the report title immediately
* Other UI interactions I've missed here

## Testing Strategy

### Phase 1
- Unit test each LiveView report module
- Visual regression testing for UI consistency
- Test with various query combinations (filters, dates, comparisons)

### Phase 2
- Full-stack integration tests with LiveView testing helpers
- Test routing and modal navigation
- Test keyboard shortcuts
- Test error states and loading states
- Test embedded mode

## Rollout Strategy

**Phase 1:**
- Deploy each report migration independently
- Feature flag per report for safe rollback

**Phase 2:**
- Cannot be deployed incrementally (interdependent changes)
- Thorough staging environment testing
- Use feature flag to roll out gradually for a percentage of users

# Drawbacks
[drawbacks]: #drawbacks

**Why should we *not* do this?**

1. **Large time investment** - Many weeks of focused work for full migration
2. **Risk of regressions** - Complex dashboard with many edge cases, high chance of introducing bugs
9. **Iframe overhead in Phase 1** - Communication latency and complexity during transition
10. **All-or-nothing Phase 2** - Large coordinated change with high risk

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

The rationale is explained at the top of the RFC. The main alternative is staying on React. We still need to deal with the `Query.from()` debt
anyways by refactoring the Api.StatsController.

### Iframe vs LiveViewPortal

Instead of iframes, consider using [LiveViewPortal](https://github.com/doofinder/live_view_portal) for the incremental
migration path. Seems more complex due to lack of complete isolation, but has some benefits.


# Unresolved questions
[unresolved-questions]: #unresolved-questions

I tried to consider everything that comes to mind, but this project has tons of 'unknown unknowns'. For the readers, if there's something that feels unresolved, please comment
below.

# Future possibilities
[future-possibilities]: #future-possibilities

Moving to Liveview means we could potentially render SVG charts on the backend like we do on the /sites page, replacing canvas-based frontend charting.
I'm not sure if it's a good idea or not. SVG charts can look sharper on modern screens because they basically scale to any pixel density.
