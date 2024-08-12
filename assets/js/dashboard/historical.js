import React from 'react';

import Datepicker from './datepicker'
import SiteSwitcher from './site-switcher'
import Filters from './filters'
import CurrentVisitors from './stats/current-visitors'
import VisitorGraph from './stats/graph/visitor-graph'
import Sources from './stats/sources'
import Pages from './stats/pages'
import Locations from './stats/locations';
import Devices from './stats/devices'
import Behaviours from './stats/behaviours'
import ComparisonInput from './comparison-input'
import { withPinnedHeader } from './pinned-header-hoc';
import { statsBoxClass } from './index';
import { useSiteContext } from './site-context';
import { useQueryContext } from './query-context';
import { useUserContext } from './user-context';

function Historical({ stuck, importedDataInView, updateImportedDataInView }) {
  const site = useSiteContext();
  const user = useUserContext();
  const { query } = useQueryContext();
  const tooltipBoundary = React.useRef(null)

  return (
    <div className="mb-12">
      <div id="stats-container-top"></div>
      <div className={`relative top-0 sm:py-3 py-2 z-10 ${stuck && !site.embedded ? 'sticky fullwidth-shadow bg-gray-50 dark:bg-gray-850' : ''}`}>
        <div className="items-center w-full flex">
          <div className="flex items-center w-full" ref={tooltipBoundary}>
            <SiteSwitcher site={site} loggedIn={user.loggedIn} currentUserRole={user.role} />
            <CurrentVisitors tooltipBoundary={tooltipBoundary.current} />
            <Filters className="flex" />
          </div>
          <Datepicker />
          <ComparisonInput />
        </div>
      </div>
      <VisitorGraph updateImportedDataInView={updateImportedDataInView} />

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

      <Behaviours importedDataInView={importedDataInView} />
    </div>
  )
}

export default withPinnedHeader(Historical, '#stats-container-top');
