import React from 'react';
import ReactDOM from 'react-dom';
import App from './App';
import * as utilties from "./helpers/utilities";
import * as helpers from "./helpers/helpers";

it('renders without crashing', () => {
  const div = document.createElement('div');
  ReactDOM.render(<App />, div);
  ReactDOM.unmountComponentAtNode(div);
});

it('runs utilities', () => {
  expect(utilties.isEmpty({})).toBeTruthy();
  expect(utilties.isEmpty({ a: 1})).toBeFalsy();
  expect(utilties.isEmpty({ a: 1, a2: { b: 2 }})).toBeFalsy();
  expect(utilties.isAsciiString("Strelka")).toBeTruthy();
  expect(utilties.isAsciiString("Die Bären")).toBeFalsy();
  expect(utilties.removeNullCharacters("test\0")).toEqual("test");
  expect(utilties.removeNullCharacters("test 2")).toEqual("test 2");
  expect(utilties.removeNullCharacters("test\0 3")).toEqual("test 3");

  const o = utilties.objectToQueryParams({a:1, b:2});
  const split = o.split("&");
  expect(o.indexOf("a=1")).not.toEqual(-1);
  expect(o.indexOf("b=2")).not.toEqual(-1);

  expect(utilties.isValidTimeoutMs(0)).toBeTruthy();
  expect(utilties.isValidTimeoutMs(1000)).toBeTruthy();
  expect(utilties.isValidTimeoutMs(-1)).toBeFalsy();
  expect(utilties.isValidTimeoutMs(2147483648)).toBeFalsy();

  expect(helpers.isValidName("Strelka")).toBeTruthy();
  expect(helpers.isValidName("Die Bären")).toBeFalsy();
  expect(helpers.isValidName("This is an extremely long name that doesn't fit into the limits")).toBeFalsy();
  expect(helpers.isValidName("12345678901234567890123456789012")).toBeTruthy();
  expect(helpers.isValidName("123456789012345678901234567890123")).toBeFalsy();
  expect(helpers.isValidName("")).toBeTruthy();
  expect(helpers.isValidName(null)).toBeFalsy();
  expect(helpers.isValidName(undefined)).toBeFalsy();
});

