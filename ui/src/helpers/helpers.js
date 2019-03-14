// @flow

import { isAsciiString } from "./utilities";

export function isValidName(name: ?string): boolean {
  return (typeof name !== 'undefined') && (name != null) && (isAsciiString(name)) && (name.length <= 32);
}

opaque type address = string;

export function addressAsString(a: address): string {
  return a;
}

export opaque type DecimalString = string;

export function numberAsDecimalString(n: number): DecimalString {
  return (n).toString();
}

// see https://github.com/frozeman/bignumber.js-nolookahead/blob/master/doc/API.html
export interface BigNumberType {
  toNumber(): number;
  toString(): string;

  isNaN(): bool;
  isZero(): bool;
  equals(n: number|string|BigNumberType): bool;
  greaterThan(n: number|string|BigNumberType): bool;
  greaterThanOrEqualTo(n: number|string|BigNumberType): bool;
  lessThan(n: number|string|BigNumberType): bool;
  lessThanOrEqualTo(n: number|string|BigNumberType): bool;

  times(n: number|string|BigNumberType): BigNumberType;
  dividedBy(n: number|string|BigNumberType): BigNumberType;
  plus(n: number|string|BigNumberType): BigNumberType;
  minus(n: number|string|BigNumberType): BigNumberType;

  ceil(): BigNumberType;
}

export interface Web3Type {
  toWei(number|string|BigNumberType|DecimalString, string): string|BigNumberType;
  fromWei(number|string|BigNumberType|DecimalString, string): string|BigNumberType;
  toAscii(string): string;
  currentProvider: any;
  eth: any;
}

export interface NameAssignedEvent {
  args: { petId: BigNumberType, name: string };
}

export interface AdoptedEvent {
  args: { petId: BigNumberType };
}

export interface Web3jsFilter {
  stopWatching(): void;
}

export interface NameEventResult {
  get((Error, ?Array<NameAssignedEvent>) => void|Promise<void>): Web3jsFilter;
  watch((Error, NameAssignedEvent) => void|Promise<void>): Web3jsFilter;
}

export interface AdoptedEventResult {
  get((Error, ?Array<AdoptedEvent>) => void|Promise<void>): Web3jsFilter;
  watch((Error, AdoptedEvent) => void|Promise<void>): Web3jsFilter;
}

export type EventRange = "all" | "latest";

export type EventResponse =
  ({ name : "NameAssigned", event: ?NameAssignedEvent, error: ?Error, range: EventRange, }) |
  ({ name : "Adopted", event: ?AdoptedEvent, error: ?Error, range: EventRange, });

type AdopterResult = address | Error;

export interface AdoptionType {
  transfer(number, address, { from: address }): Promise<void>;
  adopterOf(number): Promise<address>;
  adopt(number, { from: address }): Promise<void>;
  isAdopted(number): Promise<bool>;
  assignName(number, address, { from: address }): Promise<void>;
  NameAssigned({petId: number}, string | { fromBlock: number, toBlock: string }): NameEventResult & Web3jsFilter;
  Adopted({petId: number}, string | { fromBlock: number, toBlock: string }): AdoptedEventResult & Web3jsFilter;
}

export interface AdoptionContractType {
  deployed():  Promise<AdoptionType>;
}

// Container types

export type TransactionProperties = {
  gasPrice?: DecimalString,
  gas?: DecimalString,
};

export type BaseCardProps = {
  externalId: number,
  title: string,
  imageSource: string,
};

export type CardProps = {
  account: ?address,
  isAdopted?: bool,
  givenName?: string,
  adopter?: AdopterResult,
  cachedNameLastUpdatedTime: ?number,
  nameToChange?: string,
  handleInputChange: (SyntheticInputEvent<HTMLInputElement>) => void,
  handleChangeName: () => Promise<void>,
  handleAdopt: () => Promise<void>,
} & BaseCardProps;

export type CardContainerState = {
  web3?: Web3Type,
  adoptionContract?: AdoptionContractType,
  account?: address,
  givenName?: string,
  adopter?: AdopterResult,
  isAdopted?: bool,
  nameToChange: string,
  cachedNameLastUpdatedTime?: ?number,
};

export type AccountContextProps = {
  account: ?address,
  returnsInEther: ?DecimalString
};

export type CardContainerProps = BaseCardProps & AccountContextProps;

export type DisplayText = {
  title: string,
  subtitle ?: string,
  description ?: string,
  emptyText ?: string,
};

export type CardsProps = {
  hasMore: bool,
  page: number,
  cards: Map<string, BaseCardProps>,
  text: DisplayText,
  loadMore: () => void,
};

export type CardsLoaderState = {
  hasMore: bool,
  page: number,
  cards: Map<string, BaseCardProps>,
  additionalQueryParams: ?{ [string]: string },
};

export type AccountHeaderProps = {
  account: ?string,
};

export type MainProps = {
  account: ?string,
  canSilentlyGetAccounts: ?bool,
  handleSignIn: () => Promise<void>,
};

export type MainStateProviderState = {
  web3?: Web3Type,
  adoptionContract?: AdoptionContractType,
  account?: ?string,
};

export type CardsApiResponse = {
  pets: Array<BaseCardProps>,
  nextPage: number
};

export type LatestNameApiResponse = {
  latestName: ?string,
};

export type CachedCardNameApiResponse = {
  name: ?string,
  lastUpdateTime: ?number,
};

export type CachedCardNamesLastUpdateTimeApiResponse = {
  lastUpdateTime: ?number,
};

export type CardsApiPath = "allPets";


// Utils

export function keyForCard(card: BaseCardProps): string {
  return `card-${card.externalId}`;
}
