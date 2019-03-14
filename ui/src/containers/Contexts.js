// @flow

import * as React from 'react'

import CardStateProvider from "./CardStateProvider";

import type { AccountContextProps, } from "../helpers/helpers";

const initialAccountState: { account: ?string } = {account: undefined};

export const AccountContext = React.createContext(initialAccountState);

export function withAccount<Props: {}>(Component: React.ComponentType<Props>): React.ComponentType<$Diff<Props, AccountContextProps>> {
  return function ComponentWithAccounts(props: Props) {
    return (
      <AccountContext.Consumer>
        {({account}) => <Component {...props} account={account} />}
      </AccountContext.Consumer>
    );
  };
}

export const CardStateProviderWithAccount = withAccount(CardStateProvider);
