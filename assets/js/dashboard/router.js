import React, { useEffect, useMemo } from 'react';
import { BrowserRouter, Switch, Route, useLocation } from "react-router-dom";

import Dashboard from './index'
import SourcesModal from './stats/modals/sources'
import ReferrersDrilldownModal from './stats/modals/referrer-drilldown'
import GoogleKeywordsModal from './stats/modals/google-keywords'
import PagesModal from './stats/modals/pages'
import EntryPagesModal from './stats/modals/entry-pages'
import ExitPagesModal from './stats/modals/exit-pages'
import LocationsModal from './stats/modals/locations-modal';
import PropsModal from './stats/modals/props'
import ConversionsModal from './stats/modals/conversions'
import FilterModal from './stats/modals/filter-modal'
import QueryContextProvider from './query-context';
import { useSiteContext } from './site-context';

function ScrollToTop() {
  const location = useLocation();

  useEffect(() => {
    if (location.state && location.state.scrollTop) {
      window.scrollTo(0, 0);
    }
  }, [location]);

  return null;
}

export default function Router() {
  const site = useSiteContext()
  const { shared, domain } = site;
  const basename = useMemo(() => shared ? `/share/${encodeURIComponent(domain)}` : encodeURIComponent(domain), [domain, shared])
  return (
    <BrowserRouter basename={basename}>
      <QueryContextProvider>
        <Route path="/">
          <ScrollToTop />
          <Dashboard />
          <Switch>
            <Route exact path={["/sources", "/utm_mediums", "/utm_sources", "/utm_campaigns", "/utm_contents", "/utm_terms"]}>
              <SourcesModal />
            </Route>
            <Route exact path="/referrers/Google">
              <GoogleKeywordsModal site={site} />
            </Route>
            <Route exact path="/referrers/:referrer">
              <ReferrersDrilldownModal />
            </Route>
            <Route path="/pages">
              <PagesModal />
            </Route>
            <Route path="/entry-pages">
              <EntryPagesModal />
            </Route>
            <Route path="/exit-pages">
              <ExitPagesModal />
            </Route>
            <Route exact path={["/countries", "/regions", "/cities"]}>
              <LocationsModal />
            </Route>
            <Route path="/custom-prop-values/:prop_key">
              <PropsModal />
            </Route>
            <Route path="/conversions">
              <ConversionsModal />
            </Route>
            <Route path={["/filter/:field"]}>
              <FilterModal site={site} />
            </Route>
          </Switch>
        </Route>
      </QueryContextProvider>
    </BrowserRouter>
  );
}
