// @flow

import { Component } from 'react'

import type {
  CardContainerProps,
  CardContainerState,
  Web3Type,
  AdoptionContractType,
  AdoptionType,
  NameAssignedEvent,
  EventResponse,
  TransactionProperties,
  Web3jsFilter
} from '../helpers/helpers';

import {
  numberAsDecimalString
} from "./helpers"
import { removeNullCharacters } from "./utilities"

export function getCardNameFromEvent(web3: Web3Type, event: NameAssignedEvent): string {
  return removeNullCharacters(web3.toAscii(event.args.name));
}

export async function registerToWatchCardEvents(adoptionContract: AdoptionContractType,
                                                externalId: number,
                                                eventHandler: (EventResponse) => Promise<void>):Promise<?Array<Web3jsFilter>> {

  try {

    const adoption: AdoptionType = await adoptionContract.deployed();

    return [
      adoption.NameAssigned({"petId": externalId}, 'latest')
        .watch(async (error, eventResult) => {
          await eventHandler({name: "NameAssigned", range: 'latest', event: eventResult, error: error});
        }),
      adoption.Adopted({"petId": externalId}, 'latest')
        .watch(async (error, eventResult) => {
          await eventHandler({name: "Adopted", range: 'latest', event: eventResult, error: error});
        }),
    ];
  }
  catch (error) {
    console.error(`${error}`);
  }
}

export async function registerToGetLastNameAssignedEvent(adoptionContract: AdoptionContractType,
                                                         externalId: number,
                                                         watchArray: Array<Web3jsFilter> = [],
                                                         eventHandler: (EventResponse) => Promise<void>) {
  try {

    const adoption: AdoptionType = await adoptionContract.deployed();

    const nameAssignedEvent = adoption.NameAssigned({ "petId" : externalId }, { fromBlock: 0, toBlock: 'latest' });
    nameAssignedEvent.get(async (error, eventResult) => {
      try {
        nameAssignedEvent.stopWatching();
      }
      catch (err) {
        console.error(`${err}`);
      }
      const index = watchArray.indexOf(nameAssignedEvent);
      if (index > -1) {
        watchArray.splice(index, 1);
      }
      if ((error) || (typeof eventResult === 'undefined') || (!(eventResult)) || (eventResult.length <= 0)) {
        await eventHandler({range: 'all', name: "NameAssigned", event: undefined, error: error});
      }
      else {
        const lastNameAssignedEvent = eventResult[eventResult.length - 1];
        await eventHandler({range: 'all', name: "NameAssigned", event: lastNameAssignedEvent, error: undefined});
      }
    });
    watchArray.push(nameAssignedEvent);
  }
  catch (error) {
    console.error(`${error}`);
  }
}

export async function setCardState(component: Component<CardContainerProps, CardContainerState>,
                                   web3: Web3Type,
                                   adoptionContract: AdoptionContractType,
                                   externalId: number) {
  try {

    const adoption: AdoptionType = await adoptionContract.deployed();

    const isAdopted = await adoption.isAdopted(externalId);
    component.setState({
      isAdopted: isAdopted
    });

    component.setState({
      adopter: ((isAdopted) ? (await adoption.adopterOf(externalId)) : (undefined)),
    });
  }
  catch (error) {
    console.error(`${error}`);
    component.setState({
      adopter: error,
      isAdopted: undefined,
    });
  }
}

export function getTransactionProperties(gasEstimate: number, gasLimitMultiplier: number): TransactionProperties {
  const gasEstimateToUse = gasEstimate * gasLimitMultiplier;

  return { gas: numberAsDecimalString(gasEstimateToUse) };

}

export async function adopt(web3: Web3Type,
                             account: string,
                             adoptionContract: AdoptionContractType,
                             externalId: number,
                             shouldEstimateGasLimit: bool,
                             gasLimitMultiplier: number): Promise<?string> {
  try {
    const adoption: AdoptionType = await adoptionContract.deployed();

    let transactionProperties = {};
    if (shouldEstimateGasLimit) {
      const gasEstimate: number = await adoption.adopt.estimateGas(externalId, {from: account});
      transactionProperties = getTransactionProperties(gasEstimate, gasLimitMultiplier);
    }

    return await adoption.adopt.sendTransaction(externalId, {...{from: account}, ...transactionProperties});
  }
  catch (error) {
    console.error(`${error}`);
  }
}

export async function changeName(account: string,
                                 adoptionContract: AdoptionContractType,
                                 externalId: number,
                                 cardName: string,
                                 shouldEstimateGasLimit: bool,
                                 gasLimitMultiplier: number): Promise<?string> {
  try {
    const adoption: AdoptionType = await adoptionContract.deployed();

    let transactionProperties = {};
    if (shouldEstimateGasLimit) {
      const gasEstimate: number = await adoption.assignName.estimateGas(externalId, cardName, {from: account});
      transactionProperties = getTransactionProperties(gasEstimate, gasLimitMultiplier);
    }

    return await adoption.assignName.sendTransaction(externalId, cardName, {...{from: account}, ...transactionProperties});
  }
  catch (error) {
    console.error(`${error}`);
  }
}
