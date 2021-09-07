import React, { useEffect } from 'react';
import {BrowserRouter, Switch, Route, useLocation} from "react-router-dom";

import Dash from './index'
import SourcesModal from './stats/modals/sources'
import ReferrersDrilldownModal from './stats/modals/referrer-drilldown'
import GoogleKeywordsModal from './stats/modals/google-keywords'
import PagesModal from './stats/modals/pages'
import EntryPagesModal from './stats/modals/entry-pages'
import ExitPagesModal from './stats/modals/exit-pages'
import CountriesModal from './stats/modals/countries'
import ModalTable from './stats/modals/table'
import FilterModal from './stats/modals/filter'

function ScrollToTop() {
  const location = useLocation();

  useEffect(() => {
    if (location.state && location.state.scrollTop) {
      window.scrollTo(0, 0);
    }
  }, [location]);

  return null;
}

export default function Router({site, loggedIn, currentUserRole}) {
  return (
    <BrowserRouter>
      <Route path="/:domain">
        <ScrollToTop />
        <Dash site={site} loggedIn={loggedIn} currentUserRole={currentUserRole} />
        <Switch>
          <Route exact path={["/:domain/sources", "/:domain/utm_mediums", "/:domain/utm_sources", "/:domain/utm_campaigns"]}>
            <SourcesModal site={site} />
          </Route>
          <Route exact path="/:domain/referrers/Google">
            <GoogleKeywordsModal site={site} />
          </Route>
          <Route exact path="/:domain/referrers/:referrer">
            <ReferrersDrilldownModal site={site} />
          </Route>
          <Route path="/:domain/pages">
            <PagesModal site={site} />
          </Route>
          <Route path="/:domain/entry-pages">
            <EntryPagesModal site={site} />
          </Route>
          <Route path="/:domain/exit-pages">
            <ExitPagesModal site={site} />
          </Route>
          <Route path="/:domain/countries">
            <CountriesModal site={site} />
          </Route>
          <Route path="/:domain/regions">
            <ModalTable title="Top regions" site={site} endpoint={`/api/stats/${encodeURIComponent(site.domain)}/regions`} filter={{region: 'code', region_name: 'name'}} keyLabel="Region" />
          </Route>
          <Route path="/:domain/cities">
            <ModalTable title="Top cities" site={site} endpoint={`/api/stats/${encodeURIComponent(site.domain)}/cities`} filter={{city: 'code', city_name: 'name'}} keyLabel="City" />
          </Route>
          <Route path={["/:domain/filter/:field"]}>
            <FilterModal site={site} />
          </Route>
        </Switch>
      </Route>
    </BrowserRouter>
  );
}
