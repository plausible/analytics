import React from 'react';
import Dash from './index'
import Modal from './stats/modals/modal'
import ReferrersModal from './stats/modals/referrers'

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
        </Switch>
      </Route>
    </BrowserRouter>
  );
}
