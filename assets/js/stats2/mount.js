import React from 'react';
import ReactDOM from 'react-dom';

import Stats from './index'

const container = document.getElementById('stats-react-container')

const site = {
  domain: container.dataset.domain,
  timezone: container.dataset.timezone,
  hasGoals: container.dataset.hasGoals === 'true'
}

ReactDOM.render(<Stats site={site} />, container);
