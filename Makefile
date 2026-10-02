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

