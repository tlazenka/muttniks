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
	
