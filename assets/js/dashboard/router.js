import React from 'react';
import Dash from './index'
import Modal from './stats/modals/modal'
import ReferrersModal from './stats/modals/referrers'
import PagesModal from './stats/modals/pages'
import CountriesModal from './stats/modals/countries'
import BrowsersModal from './stats/modals/browsers'
import OperatingSystemsModal from './stats/modals/operating-systems'

import {
  BrowserRouter,
  Switch,
  Route
} from "react-router-dom";

export default function Router({site}) {
  return (
    <BrowserRouter>
      <Route path="/:domain">
        <Dash site={site} />
        <Switch>
          <Route path="/:domain/referrers">
            <Modal site={site}>
              <ReferrersModal site={site} />
            </Modal>
          </Route>
          <Route path="/:domain/pages">
            <Modal site={site}>
              <PagesModal site={site} />
            </Modal>
          </Route>
          <Route path="/:domain/countries">
            <Modal site={site}>
              <CountriesModal site={site} />
            </Modal>
          </Route>
          <Route path="/:domain/browsers">
            <Modal site={site}>
              <BrowsersModal site={site} />
            </Modal>
          </Route>
          <Route path="/:domain/operating-systems">
            <Modal site={site}>
              <OperatingSystemsModal site={site} />
            </Modal>
          </Route>
        </Switch>
      </Route>
    </BrowserRouter>
  );
}
