// @flow

import React from 'react'

import {
  addressAsString,
  isValidName,
} from "../helpers/helpers"

import type { CardProps } from '../helpers/helpers';

const Card = ({
                externalId,
                imageSource,
                title,
                givenName,
                cachedNameLastUpdatedTime,
                adopter,
                isAdopted,
                handleInputChange,
                handleChangeName,
                nameToChange,
                handleAdopt,
                account,
              }: CardProps) => {

  const hasAccount = (typeof account === 'string');

  let canAdopt = (typeof isAdopted === 'boolean') && (!(isAdopted)) && (hasAccount);
  const isAdopter = (typeof account === 'string') && (typeof adopter === 'string') && (account.toLowerCase() === adopter.toLowerCase());
  const canRename = isAdopter;

  let adopterLabel;

  if (adopter instanceof Error) {
    adopterLabel = 'Unknown';
  }
  else if (adopter) {
    if (isAdopter) {
      adopterLabel = "Me";
    }
    else {
      adopterLabel = addressAsString(adopter);
    }
  }
  else {
    adopterLabel = 'None yet!';
  }

  const showNameWarning = (!(isValidName(nameToChange)));

  let nameLastUpdatedString: ?string;
  if (typeof cachedNameLastUpdatedTime === 'number') {
    const d = new Date(0);
    d.setUTCSeconds(cachedNameLastUpdatedTime / 1000);
    nameLastUpdatedString = d.toLocaleString();
  }

  return (
    <div className="card">
      <img className="card-img-top" src={imageSource} alt={givenName}/>
      <div className="card-body">
        <div className={`form-group`}>
          <h5 className="card-title"> {givenName}</h5>
          <strong>Adopter</strong>: <span>{adopterLabel}</span>
        </div>

        {
          (typeof nameLastUpdatedString === 'string') &&
          <div className={`form-group`}>
            <strong>Name last refreshed</strong>: <span>{nameLastUpdatedString}</span>
          </div>
        }
        {
          canAdopt &&
          <div className="form-group">
            <button className="btn btn-primary" type="button" onClick={handleAdopt}>Adopt</button>
          </div>
        }
        {
          canRename &&
          <div className="form-group">
            <div className="form-group">
              <input name="nameToChange" className="form-control nameToChange" type="text" pattern="[\x00-\x7F]+" maxLength="32" placeholder="Enter name" value={nameToChange} onChange={handleInputChange}/>
              {
                showNameWarning &&
                <div className="alert alert-secondary mb-3 form-group" role="alert">
                  Currently we limit names to 32 alphanumerics (A-Z, 0-9), but this will change soon!
                </div>
              }
            </div>
            <div className="form-group">
              <button className="btn btn-primary" type="button" onClick={handleChangeName}>Change name</button>
            </div>
          </div>
        }
      </div>
    </div>
  )
};

export default Card
