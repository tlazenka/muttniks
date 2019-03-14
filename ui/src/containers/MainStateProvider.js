// @flow

import React, { Component } from 'react'

import { AccountContext } from '../containers/Contexts'

// $FlowFixMe
import AdoptionContract from '../build/contracts/Adoption.json'

import * as web3Helpers from "../helpers/web3Helpers";
import type {
  Web3Type,
  MainStateProviderState,
  Web3jsFilter,
  AdoptionContractType
} from "../helpers/helpers";
import Main from "../layouts/Main";

class MainStateProvider extends Component<{}, MainStateProviderState> {

  state: MainStateProviderState = {
  };

  accountRefreshIntervalId: IntervalID;

  accountRefreshInterval = (process.env.REACT_APP_ACCOUNT_REFRESH_INTERVAL_MS) ? (Number(process.env.REACT_APP_ACCOUNT_REFRESH_INTERVAL_MS)) : (1000);

  web3jsFilters: Array<Web3jsFilter> = [];

  refreshAccount = async (web3: Web3Type, adoptionContract: AdoptionContractType) => {
    const accounts: ?Array<string> = await web3Helpers.getAccounts(web3);
    let account;
    if ((accounts) && (typeof accounts !== undefined)) {
      account = accounts[0];
    }

    const { account: currentAccount } = this.state;

    if (currentAccount !== account) {
      this.setState({ account: account });
    }
  };

  handleSignIn = async () => {
    const { adoptionContract, web3 } = this.state;

    if ((typeof adoptionContract === 'undefined') || (typeof web3 === undefined) || (!(web3))) {
      return;
    }

    await this.refreshAccount(web3, adoptionContract);
  };

  async componentDidMount() {
    try {
      const web3: Web3Type = (await web3Helpers.getWeb3).web3;
      this.setState({
        web3: web3,
      });

      const contract = require('truffle-contract');

      const adoptionContract = contract(AdoptionContract);
      adoptionContract.setProvider(web3.currentProvider);

      this.setState({
        adoptionContract: adoptionContract
      });

      if (web3Helpers.canSilentlyGetAccounts(web3)) {
        await this.refreshAccount(web3, adoptionContract);
      }
      this.accountRefreshIntervalId = setInterval(async () => {
        const { account } = this.state;

        if ((web3Helpers.canSilentlyGetAccounts(web3)) || (typeof account === 'string')) {
          await this.refreshAccount(web3, adoptionContract);
        }
      }, this.accountRefreshInterval);

    }
    catch (error) {
      console.error(error);
    }
  }

  componentWillUnmount() {
    clearInterval(this.accountRefreshIntervalId);
    this.web3jsFilters.forEach((i) => i.stopWatching());
  }

  render() {
    const { account, web3 } = this.state;

    let canSilentlyGetAccounts: ?bool;

    if ((web3 != null) && (typeof web3 !== 'undefined')) {
      canSilentlyGetAccounts = web3Helpers.canSilentlyGetAccounts(web3);
    }

    return(
      <AccountContext.Provider value={{ account }}>
        <Main
          account={account}
          canSilentlyGetAccounts={canSilentlyGetAccounts}
          handleSignIn={this.handleSignIn}
        />
      </AccountContext.Provider>

    )
  }
}

export default MainStateProvider
