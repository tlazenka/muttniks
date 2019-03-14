// @flow

import React, { Component } from 'react'

import * as web3Helpers from "../helpers/web3Helpers";
import * as loggingHelpers from "../helpers/loggingHelpers";

import type {
  CardContainerProps,
  CardContainerState,
  EventResponse,
  Web3Type,
  Web3jsFilter,
} from '../helpers/helpers';

// $FlowFixMe
import AdoptionContract from '../build/contracts/Adoption.json'

import * as contractHelpers from "../helpers/contractHelpers"
import { isValidTimeoutMs } from "../helpers/utilities"
import Card from "../layouts/Card"
import * as apiHelpers from "../helpers/apiHelpers";

import * as messages from "../layouts/messages";

class CardStateProvider extends Component<CardContainerProps, CardContainerState> {
  state: CardContainerState = {
    nameToChange: ''
  };

  refreshTimeout: TimeoutID;

  cardStateRefreshIntervalId: IntervalID;
  cardStateRefreshInterval = (process.env.REACT_APP_CARD_STATE_REFRESH_INTERVAL_MS) ? (Number(process.env.REACT_APP_CARD_STATE_REFRESH_INTERVAL_MS)) : (5000);

  shouldWatchContractEvents = (process.env.REACT_APP_WATCH_CONTRACT_EVENTS === 'true');

  web3jsFilters: Array<Web3jsFilter> = [];

  async componentDidMount() {
    const { externalId } = this.props;

    try {
      const web3: Web3Type = (await web3Helpers.getWeb3).web3;
      this.setState({
        web3: web3,
      });

      const contract = require('truffle-contract');

      const adoptionContract = contract(AdoptionContract);
      adoptionContract.setProvider(web3.currentProvider);

      this.setState({
        adoptionContract: adoptionContract,
      });

      await contractHelpers.setCardState(this, web3, adoptionContract, externalId);

      apiHelpers.getCachedCardName(externalId)
        .then(result => {
          if ((result) && (result.name)) {
            this.setState({
              givenName: result.name,
              cachedNameLastUpdatedTime: result.lastUpdateTime,
            });
          }
        });

      await contractHelpers.registerToGetLastNameAssignedEvent(adoptionContract, externalId, this.web3jsFilters, this.handleContractEvent);

      if (this.shouldWatchContractEvents) {
        const cardEventFilters = await contractHelpers.registerToWatchCardEvents(adoptionContract, externalId, this.handleContractEvent);
        if (cardEventFilters) {
          this.web3jsFilters.push(...cardEventFilters);
        }
      }

      this.cardStateRefreshIntervalId = setInterval(async () => {
        if (this.shouldPollForContractChanges) {
          // console.log(`${logPrefix} Refreshing because of polling`);
          await this.refreshCardState();
        }
      }, this.cardStateRefreshInterval);
    }
    catch (error) {
      // console.error(error);
      loggingHelpers.logMessage({ level: 'error', tag: "", message: error, friendlyMessage: messages.ERROR_LOADING });
    }
  }

  componentWillUnmount() {
    clearInterval(this.cardStateRefreshIntervalId);
    clearTimeout(this.refreshTimeout);
    this.web3jsFilters.forEach((i) => i.stopWatching());
  }

  get shouldPollForContractChanges(): boolean {
    const { web3 } = this.state;
    const { account } = this.props;

    if (!(web3)) {
      return false;
    }

    if (typeof account !== 'string') {
      return false;
    }

    return (web3Helpers.shouldPollForContractChanges(web3));
  }

  get shouldEstimateGasLimit() {
    return web3Helpers.shouldEstimateGasLimit(this.state.web3);
  }

  setRefreshTimeout(timeoutSeconds: number) {
    /*
    const { externalId, category } = this.props;

    const logPrefix = getLogPrefix("setRefreshTimeout", externalId, category);
    */

    clearTimeout(this.refreshTimeout);

    const timeoutMs = timeoutSeconds * 1000;

    if (isValidTimeoutMs(timeoutMs)) {
      // console.log(`${logPrefix} Setting refresh timeout for ${timeoutSeconds} seconds`);

      this.refreshTimeout = setTimeout(async () => {
        await this.refreshCardState();
      }, timeoutMs);
    }
  }

  async refreshCardState() {
    const { externalId } = this.props;
    const { web3, adoptionContract } = this.state;

    if ((typeof web3 === 'undefined') || (typeof adoptionContract === 'undefined')) {
      return;
    }

    await contractHelpers.setCardState(this, web3, adoptionContract, externalId);

    await contractHelpers.registerToGetLastNameAssignedEvent(adoptionContract, externalId, this.web3jsFilters, this.handleContractEvent);
  }

  handleContractEvent = async (eventResponse: EventResponse) => {
    const { externalId, title } = this.props;
    const { web3 } = this.state;

    switch (eventResponse.name) {
      case 'NameAssigned':
        if ((!(eventResponse.error)) && (typeof web3 !== 'undefined') && (eventResponse.event) && (typeof eventResponse.event !== 'undefined')) {
          const nameFromEvent = contractHelpers.getCardNameFromEvent(web3, eventResponse.event);
          this.setState({
            givenName: nameFromEvent
          });
        }
        else {
          const { adoptionContract } = this.state;

          if ((typeof web3 === 'undefined') || (typeof adoptionContract === 'undefined')) {
            this.setState({ givenName: title });
          }
          else {
            await apiHelpers.setCardNameState(this, externalId, title);
          }
        }
        break;
      case 'Adopted':
        if (eventResponse.error) {
          return;
        }

        if ((typeof eventResponse.event === 'undefined') || (!(eventResponse.event))) {
          return;
        }

        const { adoptionContract } = this.state;

        if ((typeof web3 === 'undefined') || (typeof adoptionContract === 'undefined')) {
          return;
        }

        await contractHelpers.setCardState(this, web3, adoptionContract, externalId);

        break;
      default:
        break;
    }
  };

  handleInputChange = (event: SyntheticInputEvent<HTMLInputElement>) => {
    this.setState({ [event.target.name]: event.target.value })
  };

  handleChangeName: () => Promise<void> = async () => {
    const { externalId, account } = this.props;
    const { adoptionContract, nameToChange } = this.state;

    if (typeof account !== 'string') {
      return;
    }

    if ((typeof adoptionContract === 'undefined')) {
      return;
    }

    if ((typeof nameToChange === 'undefined') || (typeof account === 'undefined')) {
      return;
    }

    try {
      const result = await contractHelpers.changeName(
        account,
        adoptionContract,
        externalId,
        nameToChange,
        this.shouldEstimateGasLimit,
        web3Helpers.gasLimitMultiplier);

      if (typeof result === 'string') {
        loggingHelpers.logMessage({ level: 'info', tag: "", message: `Want to change name to ${nameToChange}`, friendlyMessage: messages.TRANSACTION_CHANGE_NAME });
      }
    }
    catch (error) {
      loggingHelpers.logMessage({ level: 'error', tag: "", message: error, friendlyMessage: messages.ERROR_CHANGE_NAME });
    }
  };

  handleAdopt: () => Promise<void> = async () => {
    const { externalId, account } = this.props;
    const { web3, adoptionContract } = this.state;

    if (typeof account !== 'string') {
      return;
    }

    if ((typeof web3 === 'undefined') || (typeof adoptionContract === 'undefined')) {
      return;
    }

    try {
      const result = await contractHelpers.adopt(
        web3,
        account,
        adoptionContract,
        externalId,
        this.shouldEstimateGasLimit,
        web3Helpers.gasLimitMultiplier);

      if (typeof result === 'string') {
        loggingHelpers.logMessage({ level: 'info', tag: "", message: 'Want to adopt', friendlyMessage: messages.TRANSACTION_BUY_NOW });
      }
    }
    catch (error) {
      loggingHelpers.logMessage({ level: 'error', tag: "", message: error, friendlyMessage: messages.ERROR_ADOPT });
    }
  };

  render() {
    const {
      isAdopted,
      givenName,
      adopter,
      nameToChange,
      cachedNameLastUpdatedTime,
    } = this.state;
    const { externalId, title, imageSource, account, returnsInEther } = this.props;

    return (
      <Card
       externalId={externalId}
       account={account}
       isAdopted={isAdopted}
       adopter={adopter}
       givenName={givenName}
       cachedNameLastUpdatedTime={cachedNameLastUpdatedTime}
       title={title}
       nameToChange={nameToChange}
       returnsInEther={returnsInEther}
       handleInputChange={this.handleInputChange}
       handleAdopt={this.handleAdopt}
       handleChangeName={this.handleChangeName}
       imageSource={imageSource} />
    );
  }

}

export default CardStateProvider
