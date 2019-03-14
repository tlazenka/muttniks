# Cheat sheet

Run each of these commands in separate Terminal windows.

First, we need to start our blockchain and deploy our smart contract:

- `docker-compose up ganache`
- `docker-compose run --rm truffle truffle migrate --network development`

Next, let's start up our main server

- `docker-compose up app`

Visit http://localhost:9000 to see the server-side rendered page

In addition, you can browse the "single-page application", which uses caching. The caching bit is started with:

- `docker-compose up jobs`

And then the single-page application with:

- `docker-compose up react`

Visit http://localhost:3000 to see this version

# Interactions

## Plain browser

You can navigate to http://localhost:9000 to interact with the contract as Account #1. Or, run:

```
docker-compose stop app
docker-compose -f docker-compose.yml -f docker-compose.firefox.yml up app
```

And then:

```
docker-compose up firefox
```

Then, open http://localhost:5800 in a web browser to access it, or go to vnc://localhost:5900

The password is `password`

Go to http://app:9000 to interact with the contract.

## MetaMask

You can install the MetaMask extension in your browser, but we also include a Firefox image with it. To use, run:

`docker-compose up firefox`

Then, open http://localhost:5800 in a web browser to access it, or go to vnc://localhost:5900

The password is `password`

In the Firefox address bar that appears, go to:

`about:debugging`

Click "Load Temporary Add-on..."

Navigate to "Other Locations -> Computer -> var -> tmp -> metamask", select `manifest.json`, and click Open.

Click "Continue", then "Import with seed phrase". Type into the Wallet Seed box the seed words from ganache. These are by default:

`candy maple cake sugar pudding cream honey rich smooth crumble sweet treat`

Enter a New Password, then click Import. Accept a few terms and notices, then in the main window change from "Main Ethereum Network" to "Custom RPC"

Type in http://ganache:7545 as "New RPC URL", and click Save

Open a new tab and navigate to http://app:9000 in a new address bar


## API

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

You can visit other URLs to see the data. These include:

- Pets adopted by an adopter's address. For example this is for the first account: http://localhost:9000/api/petsByAdopter?adopter=0x627306090abab3a6e1400e9345bc60c78a8bef57

- Cached pet names. This is for the second pet ID: http://localhost:5000/petName/2

# Development

You can run the Solidity tests with:

- `docker-compose run --rm truffle truffle test`

You can run the Play! tests with:

- `docker-compose run --rm app sbt testWithMigrate`

You can run the Clojure tests with:

- `docker-compose run --rm jobs lein test`

You can run the React tests with:

- `docker-compose run --rm react npm test`

When developing in React, you can use Flow to type check:

- `docker-compose run --rm react flow-watch`

We use `web3j` to easily talk to the contracts in Scala. You can generate this code with:

- `docker-compose run --rm web3j /web3j-3.3.1/bin/web3j truffle generate /code/sol/build/contracts/Adoption.json -o /code/app -p contracts`