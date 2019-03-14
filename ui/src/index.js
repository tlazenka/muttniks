// @flow

import 'es5-shim';
import 'es6-shim';

import React from 'react'
import ReactDOM from 'react-dom'
import App from './App'

// $FlowFixMe
import 'bootstrap/dist/css/bootstrap.min.css';

import registerServiceWorker from './registerServiceWorker';

const root = document.getElementById('root');

if (root != null) {
  ReactDOM.render(
    <App/>,
    root
  );

  registerServiceWorker();
}
