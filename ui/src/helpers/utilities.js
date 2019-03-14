// @flow

export function removeNullCharacters(s: string): string {
  return s.replace(/\0/g, '');
}

export function isAsciiString(s: string): boolean {
  return (/^[\x00-\x7F]*$/.test(s));
}

export function isEmpty(obj: {}): boolean {
  return Object.keys(obj).length === 0;
}

export function objectToQueryParams(o: {}): string {
  return Object.keys(o).map(key => `${key}=${o[key]}`).join('&');
}

export function handleErrors(response: Response): Response {
  if (!(response.ok)) {
    throw Error(response.statusText);
  }
  return response;
}

export function currentSecondsFromEndTime(endTime: number): number {
  const currentSeconds = new Date().getTime() / 1000;
  return endTime - currentSeconds;
}

export function isValidTimeoutMs(timeoutMs: number): boolean {
  return (!(isNaN(timeoutMs))) && (timeoutMs >= 0) && (timeoutMs < 2147483648);
}

// see https://ethereum.stackexchange.com/a/24238
export const web3Promisify: any = (inner) =>
  new Promise((resolve, reject) =>
    inner((err, res) => {
      if (err) { reject(err) }

      resolve(res);
    })
  );

