.PHONY: test-app test-likes test-contracts test-integration test-tacky

test-app:
	docker compose --profile test run --rm app sbt test

test-likes:
	docker compose --profile test run --rm likes-test

test-contracts:
	docker compose --profile test run --rm contracts-test

test-integration:
	docker compose --profile test run --rm integration-tests

test-tacky:
	docker compose run --rm likes-test

.PHONY: test
test:
	swift test
	
.PHONY: format
format:
	swift format --in-place --recursive . 
	
.PHONY: test-docker
test-docker:
	docker-compose run --rm tests
	
.PHONY: format-docker
format-docker:
	docker-compose run --rm format

.PHONY: format-swift
format-swift:
	swift format . --recursive --in-place 

.PHONY: format-kotlin
format-kotlin:
	ktfmt --enable-editorconfig . 
	
.PHONY: test-swift
test-swift:
	swift test

.PHONY: test-swift-docker
test-swift-docker:
	docker-compose run --rm test-swift

.PHONY: format-swift-docker
format-swift-docker:
	docker-compose run --rm format-swift

.PHONY: build-kotlin
build-kotlin:
	./gradlew :witness-annotations:publishToMavenLocal :witness-runtime:publishToMavenLocal :witness-processor:publishToMavenLocal

.PHONY: run-ktor
run-ktor:
	cd examples/ktor-server && gradle clean run --no-daemon --refresh-dependencies

.PHONY: build-android
build-android:
	cd examples/android  && gradle clean assembleDebug --refresh-dependencies --no-daemon

.PHONY: build-kotlin-docker
build-kotlin-docker:
	docker-compose run --rm build-kotlin
        

