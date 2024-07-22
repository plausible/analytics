import React, { useEffect } from 'react';
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

import {
  QueryClient,
  QueryClientProvider,
} from '@tanstack/react-query'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false
    }
  }
})

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
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter basename={site.shared ? `/share/${encodeURIComponent(site.domain)}` : encodeURIComponent(site.domain)}>
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
    </QueryClientProvider>
  );
}
