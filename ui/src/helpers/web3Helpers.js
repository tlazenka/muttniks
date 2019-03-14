// @flow

import Web3 from 'web3-old';
import type { Web3Type } from '../helpers/helpers';
import * as utilities from './utilities'

export let getWeb3: Promise<{ web3: Web3Type }> = new Promise((resolve, reject) => {
  // Wait for loading completion to avoid race conditions with web3 injection timing.
  window.addEventListener('load', () => {
    let results;
    let web3 = window.web3;

    // Checking if Web3 has been injected by the browser (Mist/MetaMask)
    if (typeof web3 !== 'undefined') {
      // Use Mist/MetaMask's provider.
      web3 = new Web3(web3.currentProvider);

      results = {
        web3: web3
      };

      console.log('Injected web3 detected.');

      resolve(results)
    }
    else {

      const provider = new Web3.providers.HttpProvider(process.env.REACT_APP_FALLBACK_WEB3_HTTP_PROVIDER);
      web3 = new Web3(provider);

      results = {
        web3: web3
      };

      console.log('No web3 instance injected, using fallback.');

      resolve(results)
    }
  })
});

export function getTransactionUrl(transactionHash: string): string {
  return `https://etherscan.io/tx/${transactionHash}`
}

export const gasLimitMultiplier = (process.env.REACT_APP_GAS_LIMIT_MULTIPLIER) ? (Number(process.env.REACT_APP_GAS_LIMIT_MULTIPLIER)) : (1);

export async function getAccounts(web3: Web3Type): Promise<?Array<string>> {
  try {
    return await utilities.web3Promisify(cb => web3.eth.getAccounts(cb));
  }
  catch (error) {
    console.error(error);
    return undefined;
  }
}

export function canSilentlyGetAccounts(web3: Web3Type): bool {
  return true;
}

export function shouldPollForContractChanges(web3: Web3Type): bool {
  return true;
}

export function shouldEstimateGasLimit(web3: ?Web3Type): bool {
  if ((!(web3)) || (typeof web3 === 'undefined')) {
    return false;
  }

  return false;
}

