import React  from 'react';
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
import { useSiteContext } from './site-context';
import { useUserContext } from './user-context';
import { useQueryContext } from './query-context';

function Realtime({ stuck }) {
  const site = useSiteContext();
  const user = useUserContext();
  const { query } = useQueryContext();
  const navClass = site.embedded ? 'relative' : 'sticky'

  return (
    <div className="mb-12">
      <div id="stats-container-top"></div>
      <div className={`${navClass} top-0 sm:py-3 py-2 z-10 ${stuck && !site.embedded ? 'fullwidth-shadow bg-gray-50 dark:bg-gray-850' : ''}`}>
        <div className="items-center w-full flex">
          <div className="flex items-center w-full">
            <SiteSwitcher site={site} loggedIn={user.loggedIn} currentUserRole={user.role} />
            <Filters className="flex" />
          </div>
          <Datepicker />
        </div>
      </div>
      <VisitorGraph />
      <div className="w-full md:flex">
        <div className={statsBoxClass}>
          <Sources />
        </div>
        <div className={statsBoxClass}>
          <Pages />
        </div>
      </div>
      <div className="w-full md:flex">
        <div className={statsBoxClass}>
          <Locations site={site} query={query} />
        </div>
        <div className={statsBoxClass}>
          <Devices />
        </div>
      </div>
      <Behaviours />
    </div>
  )
}

export default withPinnedHeader(Realtime, '#stats-container-top');
