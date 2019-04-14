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

Visit http://localhost:9000 to see the server-side rendered page

In addition, you can browse the "single-page application", which uses caching. The caching bit is started with:

- `docker-compose up jobs`

When that is ready, you'll see `*** Start update cache` in the output.

To then view the single-page application, run:

- `docker-compose up react`

When that is ready, you'll see `You can now view muttniks in the browser.` in the output.

Visit http://localhost:3000 to see this version

# Interactions

In most browsers, you can navigate to http://localhost:9000 to interact with the contract as Account #1.

We also provide a Firefox Docker image with [MetaMask](https://metamask.io) available. To access it, in a Terminal window run:

```
docker-compose stop app; docker-compose -f docker-compose.yml -f docker-compose.firefox.yml up app
```

And then, in a new window:

`docker-compose up firefox`

It's started once you see:

`The VNC desktop is:`

Next, open http://localhost:5800 in a web browser to access it, or go to vnc://localhost:5900

The password is `password`

In the Firefox address bar that appears, go to:

`about:debugging`

Click "Load Temporary Add-on..."

Navigate to "Other Locations -> Computer -> var -> tmp -> metamask", select `manifest.json`, and click Open.

In the MetaMask tab that pops up, click "Continue", then "Import with seed phrase". Type into the Wallet Seed box the seed words from ganache. These are by default:

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

To run the integration tests, you'll need to set up the `ganache`, `truffle`, `app`, and `jobs` services as described in the Cheat sheet. Then, to run the Rust version, run:

`docker-compose run --rm cli`

To run the Swift version:

`docker-compose run --rm tool`

To run the Kotlin version:

`docker-compose run --rm mpp`

## Other

When developing in React, you can use Flow to type check:

- `docker-compose run --rm react flow-watch`

We use `web3j` to easily talk to the contracts in Scala. You can generate this code with:

- `docker-compose run --rm web3j /web3j-3.3.1/bin/web3j truffle generate /code/sol/build/contracts/Adoption.json -o /code/app -p contracts`