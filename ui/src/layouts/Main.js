// @flow

import React from 'react'

import { HashRouter as Router, Route } from 'react-router-dom'

import { AllCards } from '../containers/CardsLoaders'
import AccountHeader from '../layouts/AccountHeader'

import type { MainProps } from "../helpers/helpers";

const Main = ({account}: MainProps) => {

  const RouteWithAccountHeader = ({ component: Component, ...rest }) => (
    <Route {...rest} render={props => (
      <div>
        <AccountHeader account={account}/>
        <Component currentAccount={account} {...props}/>
      </div>
    )}/>
  );

  return (
    <div>
      <main>
        <Router>
          <div>
            <div className="container">
              <RouteWithAccountHeader exact path="/" component={AllCards}/>
            </div>
          </div>
        </Router>
      </main>
    </div>
  );
};

export default Main
