/** @format */

import React, { ReactNode } from 'react'
import { createRoot } from 'react-dom/client'
import 'url-search-params-polyfill'

import { RouterProvider } from 'react-router-dom'
import { createAppRouter } from './dashboard/router'
import ErrorBoundary from './dashboard/error/error-boundary'
import * as api from './dashboard/api'
import * as timer from './dashboard/util/realtime-update-timer'
import { redirectForLegacyParams } from './dashboard/util/url-search-params'
import SiteContextProvider, {
  parseSiteFromDataset
} from './dashboard/site-context'
import UserContextProvider, { Role } from './dashboard/user-context'
import ThemeContextProvider from './dashboard/theme-context'
import {
  GoBackToDashboard,
  GoToSites,
  SomethingWentWrongMessage
} from './dashboard/error/something-went-wrong'

timer.start()

const container = document.getElementById('stats-react-container')

if (container && container.dataset) {
  let app: ReactNode

  try {
    const site = parseSiteFromDataset(container.dataset)

    const sharedLinkAuth = container.dataset.sharedLinkAuth

    if (sharedLinkAuth) {
      api.setSharedLinkAuth(sharedLinkAuth)
    }

    try {
      redirectForLegacyParams(window.location, window.history)
    } catch (e) {
      console.error('Error redirecting in a backwards compatible way', e)
    }

    const router = createAppRouter(site)

    app = (
      <ErrorBoundary
        renderFallbackComponent={({ error }) => (
          <SomethingWentWrongMessage
            error={error}
            callToAction={<GoBackToDashboard site={site} />}
          />
        )}
      >
        <ThemeContextProvider>
          <SiteContextProvider site={site}>
            <UserContextProvider
              user={
                container.dataset.loggedIn === 'true'
                  ? {
                      loggedIn: true,
                      id: parseInt(container.dataset.currentUserId!, 10),
                      role: container.dataset.currentUserRole as Role
                    }
                  : {
                      loggedIn: false,
                      id: null,
                      role: container.dataset.currentUserRole as Role
                    }
              }
            >
              <RouterProvider router={router} />
            </UserContextProvider>
          </SiteContextProvider>
        </ThemeContextProvider>
      </ErrorBoundary>
    )
  } catch (err) {
    console.error('Error loading dashboard', err)
    app = <SomethingWentWrongMessage error={err} callToAction={<GoToSites />} />
  }

  const root = createRoot(container)
  root.render(app)
}
