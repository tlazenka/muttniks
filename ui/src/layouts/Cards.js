// @flow

import React from 'react'

import DocumentTitle from 'react-document-title';

import InfiniteScroll from 'react-infinite-scroller';

import { CardStateProviderWithAccount } from '../containers/Contexts'

import type { CardsProps } from '../helpers/helpers';
import * as messages from "./messages";

export const Cards = ({
                 hasMore,
                 loadMore,
                 cards,
                 page,
                 text,
               }: CardsProps) => {

  const showEmptyText = (page === 0) && (!(hasMore)) && (cards.entries.length === 0);
  const emptyText = (typeof text.emptyText === 'string') ? (text.emptyText) : (messages.EMPTY_TEXT_GENERIC);

  return (
    <DocumentTitle title={`${messages.DOCUMENT_TITLE_PREFIX}${text.title}`}>
      <div>
        <h2 className="text-uppercase">{text.title}</h2>
        {
          (typeof text.subtitle === 'string') &&
          <div className="card card-body form-group">
            <span>{text.subtitle}</span>
          </div>
        }
        {
          (showEmptyText) ?
            <div className="form-group">
              <em>{emptyText}</em>
            </div> :

            <InfiniteScroll
              className="card-columns"
              hasMore={hasMore}
              loader={
                <div className="container" key={0}>Loading ...</div>
              }
              loadMore={loadMore}>
                {
                  [...cards.entries()].map((entry) => {
                    const key = entry[0];
                    const card = entry[1];
                    return (
                      <CardStateProviderWithAccount
                        key={key}
                        externalId={card.externalId}
                        title={card.title}
                        imageSource={`${process.env.REACT_APP_API_BASE_IMAGE_SOURCE_URL || ''}${card.imageSource}`}
                      >
                      </CardStateProviderWithAccount>)
                  })
                }
            </InfiniteScroll>
        }
      </div>
    </DocumentTitle>
  );
};
