// @flow

import React, { Component } from 'react';

import { Cards } from '../layouts/Cards'

import type { CardsLoaderState, DisplayText } from '../helpers/helpers'

export function cardsWithLoader(loader: (Component<{}, CardsLoaderState>) => void,
                                text: DisplayText,
                                additionalQueryParams: ?{ [string]: string },) {
  return class extends Component<{}, CardsLoaderState> {
    state: CardsLoaderState = {
      hasMore: true,
      page: 0,
      cards: new Map(),
      additionalQueryParams: additionalQueryParams,
    };

    loadMore = () => {
      loader(this);
    };

    handleInputChange = (event: SyntheticInputEvent<HTMLInputElement>) => {
      this.setState({ [event.target.name]: event.target.value })
    };

    render() {
      const { hasMore, cards, page, } = this.state;
      return (
        <Cards
          hasMore={hasMore}
          page={page}
          loadMore={this.loadMore}
          cards={cards}
          text={text}
          handleInputChange={this.handleInputChange}
        />
      );
    }
  }
}
