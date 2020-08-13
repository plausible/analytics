import React from 'react';
import ReactDOM from 'react-dom';
import 'url-search-params-polyfill';

import Router from './router'
import ErrorBoundary from './error-boundary'

const container = document.getElementById('stats-react-container')

if (container) {
  const site = {
    domain: container.dataset.domain,
    offset: container.dataset.offset,
    hasGoals: container.dataset.hasGoals === 'true'
  }

  const loggedIn = container.dataset.loggedIn === 'true'

  const app = (
    <ErrorBoundary>
      <Router site={site} loggedIn={loggedIn} />
    </ErrorBoundary>
  )

  ReactDOM.render(app, container);
}
