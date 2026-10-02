# --- !Ups

CREATE TABLE pets (
  id BIGINT PRIMARY KEY CHECK (id >= 0),
  adopter TEXT NULL,
  CONSTRAINT adopter_eth_address
    CHECK (adopter IS NULL OR adopter ~ '^0x[0-9a-fA-F]{40}$')
);

# --- !Downs

DROP TABLE pets;
