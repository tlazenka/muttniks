// @flow

import React from 'react';

// $FlowFixMe
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
// $FlowFixMe
import { faExclamationTriangle } from '@fortawesome/free-solid-svg-icons'

import type { AccountHeaderProps } from "../helpers/helpers";

const AccountHeader = ({account}: AccountHeaderProps) => {
  const hasAccount = (typeof account === 'string');

  return (
    <div className="form-group">
      {
        (!(hasAccount)) &&
        <div className="alert alert-warning mb-3" role="alert">
          <FontAwesomeIcon icon={faExclamationTriangle}/> To participate please <a href="https://metamask.io/" className="alert-link">install MetaMask</a>.
        </div>
      }
    </div>);
};

export default AccountHeader;
