// @flow

function getMessageForTransactionType(transactionType: string) {
  return `${transactionType} transaction sent! `;
}

export const TRANSACTION_BUY_NOW = getMessageForTransactionType("Adopt");
export const TRANSACTION_CHANGE_NAME = getMessageForTransactionType("Change name");

export const ERROR_LOADING = "Loading";
export const ERROR_ADOPT = "Adopt";
export const ERROR_CHANGE_NAME = "Change name";

export const DOCUMENT_TITLE_PREFIX = "Muttniks | ";

export const EMPTY_TEXT_GENERIC = 'Nothing to display.';

export const DISPLAY_TEXT_GALLERY = {
  title: 'Pets',
  emptyText: EMPTY_TEXT_GENERIC
};
