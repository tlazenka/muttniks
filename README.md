# Muttniks: An open source dapp to show you how we built Astro Ledger

Launching a dapp may not be as hard as launching a rocket...but it’s no moonwalk, either. A dapp, portmanteau of "decentralized app," is any app that runs on decentralized infrastructure, like on Ethereum. For your coding pleasure, our team is happy to present Muttniks, a friendly Ethereum space doggo "kernel" (or kennel) that you can build from the comfort of your spacecraft. Muttniks is an open source sample dapp, built to guide you through our exciting journey with [Astro Ledger](https://www.astroledger.org). Like the real stars and planets featured on astroledger.org, you can securely adopt, name, and trade Ethereum space doggos with Muttniks (and then donate your testnet ETH to build more Laika monuments).

[_Read More_](https://hackernoon.com/muttniks-an-open-source-dapp-to-show-you-how-we-built-astro-ledger-8a063b788d0b)

# Cheat sheet

If it's not installed, you'll need to install [Docker](https://www.docker.com/get-started) first. Then, run each of these commands in separate Terminal windows.

First, we need to start our blockchain:

- `docker-compose up ganache`

When it's ready, you'll see `Listening on 0.0.0.0:7545` a few lines down in the Terminal output.

Then, we need to deploy our smart contract:

- `docker-compose run --rm truffle truffle migrate --network development`

When it's done, you'll see:

```
Saving successful migration to network...
  ... 0x36b7b157b468782e6eec6ab0b093dbbd5301c8cb5622fde8dff4c5b5c9e9a707
Saving artifacts...
```

in the output, and it will quit.

Next, let's start up our main server

- `docker-compose up app`

When it's ready, you'll see `[info] p.c.s.AkkaHttpServer - Listening for HTTP on /0.0.0.0:9000` in the output.

To start the card name cache, run:

- `docker-compose up jobs`

When that is ready, you'll see `*** Start update cache` in the output.

To then view the single-page application, run:

- `docker-compose up react`

When that is ready, you'll see `You can now view muttniks in the browser.` in the output.

Visit http://localhost:3000 to see it

# Interactions

In Firefox and Chrome, you can use [MetaMask](https://metamask.io) alongside the http://localhost:3000 webpage to interact with the contract.

If you don't want to use MetaMask, you can pass up data via URLs and parameters (these use your private key as a URL parameter, so are not recommended in production).

- To adopt a pet (in this case pet ID 3 from private key `8d5366123cb560bb606379f90a0bfd4769eecc0557f1b362dcae9012b548b1e5`)

```
curl --request POST \
  --url 'http://localhost:9000/api/adopt?petId=3&privateKey=c87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3'
```

- To rename a pet (in this case for pet 3 from the above private key and with name "Astro"):

```
curl --request POST \
  --url 'http://localhost:9000/api/assignName?petId=3&privateKey=c87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3&name=Astro'

```

You can visit other URLs to see cached data (note that it may take a minute or so for these caches to be updated). These include:

- Pets adopted by an adopter's address. For example this is for the first account: http://localhost:9000/api/petsByAdopter?adopter=0x627306090abab3a6e1400e9345bc60c78a8bef57

- Cached pet names. This is for the third pet ID: http://localhost:5000/petName/3


# Development

## Testing

You can run the Solidity tests with:

- `docker-compose run --rm truffle truffle test`

For the following tests, be sure to have run:

- `docker-compose up ganache`

and

- `docker-compose run --rm truffle truffle migrate --network development`

as a prerequisite.

You can run the Play! tests with:

- `docker-compose run --rm app sbt testWithMigrate`

You can run the Clojure tests with:

- `docker-compose run --rm jobs lein test`

You can run the React tests with:

- `docker-compose run --rm react npm test`

## Integration tests

To run the integration tests, you'll need to set up the `ganache`, `truffle`, `app`, and `jobs` services as described in the Cheat sheet.

To then run Swift integration tests:

`docker-compose run --rm client`


## Other

When developing in React, you can use Flow to type check:

- `docker-compose run --rm react flow-watch`

We use `web3j` to easily talk to the contracts in Scala. You can generate this code with:

- `docker-compose run --rm web3j /web3j-3.3.1/bin/web3j truffle generate /code/sol/build/contracts/Adoption.json -o /code/app -p contracts`

# Acknowledgements

See [LICENSE](LICENSE).
