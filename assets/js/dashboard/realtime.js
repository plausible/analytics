import React from 'react';

import Datepicker from './datepicker'
import SiteSwitcher from './site-switcher'
import Filters from './filters'
import VisitorGraph from './stats/graph/visitor-graph'
import Sources from './stats/sources'
import Pages from './stats/pages'
import Locations from './stats/locations'
import Devices from './stats/devices'
import Behaviours from './stats/behaviours'
import { withPinnedHeader } from './pinned-header-hoc';
import { statsBoxClass } from './index';

function Realtime(props) {
  const {site, query, history, stuck, loggedIn, currentUserRole, lastLoadTimestamp} = props
  const navClass = site.embedded ? 'relative' : 'sticky'

  return (
    <div className="mb-12">
      <div id="stats-container-top"></div>
      <div className={`${navClass} top-0 sm:py-3 py-2 z-10 ${stuck && !site.embedded ? 'fullwidth-shadow bg-gray-50 dark:bg-gray-850' : ''}`}>
        <div className="items-center w-full flex">
          <div className="flex items-center w-full">
            <SiteSwitcher site={site} loggedIn={loggedIn} currentUserRole={currentUserRole} />
            <Filters className="flex" site={site} query={query} history={history} />
          </div>
          <Datepicker site={site} query={query} />
        </div>
      </div>
      <VisitorGraph site={site} query={query} lastLoadTimestamp={lastLoadTimestamp} />
      <div className="w-full md:flex">
        <div className={ statsBoxClass }>
          <Sources site={site} query={query} />
        </div>
        <div className={ statsBoxClass }>
          <Pages site={site} query={query} />
        </div>
      </div>
      <div className="w-full md:flex">
        <div className={ statsBoxClass }>
          <Locations site={site} query={query} />
        </div>
        <div className={ statsBoxClass }>
          <Devices site={site} query={query} />
        </div>
      </div>
      <Behaviours site={site} query={query} currentUserRole={currentUserRole} />
    </div>
  )
}

export default withPinnedHeader(Realtime, '#stats-container-top');
