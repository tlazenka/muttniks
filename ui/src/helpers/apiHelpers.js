// @flow

import { Component } from 'react'

import { handleErrors, objectToQueryParams } from "./utilities";
import type {
  CardContainerState,
  BaseCardProps,
  CardsApiResponse,
  CardsApiPath,
  CachedCardNameApiResponse,
  CachedCardNamesLastUpdateTimeApiResponse,
} from "./helpers";

export const baseUrl =
  (() => {
    const baseUrl = process.env.REACT_APP_API_BASE_URL;

    if (typeof baseUrl !== 'string') {
      return "";
    }
    else {
      return baseUrl;
    }
  })();

export function setCardNameState(component: Component<$Subtype<BaseCardProps>, $Shape<CardContainerState>>, externalId: number, defaultName: string): Promise<void> {
  return getCachedCardName(externalId)
    .then((data: ?CachedCardNameApiResponse) => {
      component.setState({
        givenName: ((data) && (typeof data.name === 'string')) ? (data.name) : (defaultName),
        cachedNameLastUpdatedTime: (data) ? (data.lastUpdateTime) : (null),
      });
      // console.log(`${logPrefix}: ${data}`);
    }).catch(error => {
      component.setState({
        givenName: defaultName,
        cachedNameLastUpdatedTime: null
      });
      console.error(`${error}`);
    });
}

export function getCards(path: CardsApiPath, page: number, additionalQueryParams: ?{ [string]: string }): Promise<?CardsApiResponse> {
  let url = `${baseUrl}api/${path}?page=${page}`;

  if ((additionalQueryParams) && (typeof additionalQueryParams !== 'undefined')) {
    url += `&${objectToQueryParams(additionalQueryParams)}`;
  }

  return fetch(url)
    .then(handleErrors)
    .then(response => response.json())
    .then((data: CardsApiResponse) => {
      return data;
    }).catch(error => {
      console.error(`${error}`);
    });
}

export const cacheBaseUrl =
  (() => {
    const cacheBaseUrl = process.env.REACT_APP_CACHE_BASE_URL;

    if (typeof cacheBaseUrl !== 'string') {
      return "";
    }
    else {
      return cacheBaseUrl;
    }
  })();

export function getCachedCardName(tokenId: number): Promise<?CachedCardNameApiResponse> {
  const url = `${cacheBaseUrl}/petName/${tokenId.toString()}`;

  return fetch(url)
    .then(handleErrors)
    .then(response => response.json())
    .then((data: CachedCardNameApiResponse) => {
      // console.log(`${logPrefix}: ${JSON.stringify(data)}`);
      return data;
    }).catch(error => {
      console.error(`${error}`);
    });
}

export function getCachedCardNamesLastUpdateTime(): Promise<?CachedCardNamesLastUpdateTimeApiResponse> {
  const url = `${cacheBaseUrl}/lastUpdateTime`;

  return fetch(url)
    .then(handleErrors)
    .then(response => response.json())
    .then((data: ?CachedCardNamesLastUpdateTimeApiResponse) => {
      // console.log(`${logPrefix}: ${JSON.stringify(data)}`);
      return data;
    }).catch(error => {
      console.error(`${error}`);
    });
}
