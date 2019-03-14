// @flow

import * as apiHelpers from '../helpers/apiHelpers';
import * as helpers from '../helpers/helpers';
import { cardsWithLoader, } from "./CardsStateProvider"

import { Component } from 'react';

import type { CardsLoaderState, CardsApiResponse, CardsApiPath } from '../helpers/helpers';

import * as messages from "../layouts/messages";

const cardsLoadMore = (path: CardsApiPath) => (component: Component<{}, CardsLoaderState>) => {
  const { page, additionalQueryParams } = component.state;

  apiHelpers.getCards(path, page, additionalQueryParams)
    .then((data: ?CardsApiResponse) => {
      if (!(data)) {
        return;
      }
      const { page: currentPage } = component.state;
      const { pets, nextPage } = data;
      if (currentPage !== nextPage) {
        if (pets.length === 0) {
          component.setState({hasMore: false})
        }
        else {
          const cardsMap = new Map(pets.map((i) => [helpers.keyForCard(i), i]));
          component.setState(state => ({
              cards: new Map([...state.cards, ...cardsMap]),
              page: nextPage
            }
          ));
        }
      }
    }).catch(error => {
    console.error(error);
  });
};

const allCardsLoadMore = cardsLoadMore("allPets");
export const AllCards = cardsWithLoader(allCardsLoadMore, messages.DISPLAY_TEXT_GALLERY);
