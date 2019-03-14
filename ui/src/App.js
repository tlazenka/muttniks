// @flow

import React, { Component } from 'react'
import DocumentTitle from 'react-document-title';

import MainStateProvider from './containers/MainStateProvider'

class App extends Component<{}> {
  render() {
    return (
      <div className="App">
        <DocumentTitle title='Muttniks'>
          <MainStateProvider />
        </DocumentTitle>
      </div>
    );
  }
}

export default App
