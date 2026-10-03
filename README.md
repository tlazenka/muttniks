# Puzzola/Muttniks/StateBlaster

## Puzzola

First, install [Docker](https://www.docker.com/get-started). Then, build the project with:

`docker compose build -v`

Next, start up the containers with...

Oh! I'm terribly sorry, these instructions run the _other_ [project hosted here](). Unless you need a spare sbt image hanging around, you can reclaim the 1-2 GB we've accidentally downloaded by running:

`docker compose down --volumes --rmi all --remove-orphans`

_Then_, the choice is (sort of) yours:

## (macOS >= 26) && (Xcode >= 27)

`cd Demos && mint run xcodegen && open Earthquakes.xcodeproj`

_or_

## Linux || macOS

`docker compose run --rm earthquakes "$.properties.mag >= 5"`

## Muttniks

[`Muttniks`](https://hackernoon.com/muttniks-an-open-source-dapp-to-show-you-how-we-built-astro-ledger-8a063b788d0b) has been upgraded, from Scala/Play! 2 to 3, and from single-page application to server-side rendered (yes, that is an upgrade, although interestingly Muttniks [initially also had SSR support via Twirl](https://github.com/tlazenka/muttniks/tree/v0.1/app/views)). An upgrade from another perspective came from removing Clojure in favor of a Scala monolith.

Launch the WIP through:

```
docker compose up app -d && \
  until code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:9000/health); [ "$code" = "200" ]; do echo "Waiting for Play\!... status: $code"; sleep 3; done && \
  open -a Safari http://localhost:9000
```

This waits until an OK response from the Play health endpoint and then opens home through Safari. Please note you'll need a browser with wallet support beyond this.

[Blast to the past](https://hackernoon.com/muttniks-an-open-source-dapp-to-show-you-how-we-built-astro-ledger-8a063b788d0b)

## StateBlaster

I'm simply going to post the `swift`/`gradle` commands here, because there's a good chance we're just going to try to get Generative AI to traipse through the code to try to summarize what's going on here, and then merge in what it outputs. In the meantime:

## Swift/macOS/iOS

`swift test`

`swift format . --recursive --in-place`

`open ./DemoApps/OnboardingStick/OnboardingStick.xcodeproj/`
`open ./DemoApps/OnboardingSwiftUI/OnboardingSwiftUI.xcodeproj/`
`open ./DemoApps/OnboardingStoryboard/OnboardingStoryboard.xcodeproj/`

## Kotlin/Ktor/Android

`rm -rf ~/.m2/repository/com/stateblaster/`

`ls -al ~/.m2/repository/com/stateblaster`

```
./gradlew \
  :witness-annotations:publishToMavenLocal \
  :witness-runtime:publishToMavenLocal \
  :witness-processor:publishToMavenLocal
```
  
`ls -al ~/.m2/repository/com/stateblaster`
  
```
cd examples/ktor-server && \
  gradle clean run --no-daemon \
      --refresh-dependencies
```
  
```
cd examples/android  && \
  gradle clean assembleDebug \
    --refresh-dependencies \
    --no-daemon
```
