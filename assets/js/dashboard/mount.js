import React from 'react';
import ReactDOM from 'react-dom';
import 'url-search-params-polyfill';

import Router from './router'

const container = document.getElementById('stats-react-container')

if (container) {
  const site = {
    domain: container.dataset.domain,
    offset: container.dataset.offset,
    hasGoals: container.dataset.hasGoals === 'true'
  }

  ReactDOM.render(<Router site={site} />, container);
}
