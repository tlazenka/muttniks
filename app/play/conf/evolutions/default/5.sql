# --- !Ups

CREATE TABLE chain_sync_identity (
    chain_id BIGINT NOT NULL,
    contract_address TEXT NOT NULL,
    genesis_hash TEXT NOT NULL,
    observed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (chain_id, contract_address)
);

# --- !Downs

DROP TABLE chain_sync_identity;
