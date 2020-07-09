import React, { useEffect } from 'react';
import Realtime from './realtime'
import Dash from './index'
import Modal from './stats/modals/modal'
import ReferrersModal from './stats/modals/referrers'
import ReferrersDrilldownModal from './stats/modals/referrer-drilldown'
import GoogleKeywordsModal from './stats/modals/google-keywords'
import PagesModal from './stats/modals/pages'
import CountriesModal from './stats/modals/countries'

import {BrowserRouter, Switch, Route, useLocation} from "react-router-dom";

function ScrollToTop() {
  const location = useLocation();

  useEffect(() => {
    if (location.state && location.state.scrollTop) {
      window.scrollTo(0, 0);
    }
  }, [location]);

  return null;
}

export default function Router({site}) {
  return (
    <BrowserRouter>
      <Route path="/:domain/realtime">
        <Realtime site={site} />
      </Route>
      <Route path="/:domain">
        <ScrollToTop />
        <Dash site={site} />
        <Switch>
          <Route exact path="/:domain/referrers">
            <ReferrersModal site={site} />
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
          <Route path="/:domain/countries">
            <CountriesModal site={site} />
          </Route>
        </Switch>
      </Route>
    </BrowserRouter>
  );
}
