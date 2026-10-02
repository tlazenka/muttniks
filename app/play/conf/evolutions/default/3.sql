# --- !Ups

ALTER TABLE pets ADD COLUMN name TEXT;

CREATE TABLE processed_chain_events (
    chain_id BIGINT NOT NULL,
    transaction_hash TEXT NOT NULL,
    log_index INTEGER NOT NULL,
    block_number BIGINT NOT NULL,
    block_hash TEXT,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (chain_id, transaction_hash, log_index)
);

CREATE TABLE chain_sync_checkpoint (
    chain_id BIGINT NOT NULL,
    contract_address TEXT NOT NULL,
    last_finalized_block BIGINT NOT NULL,
    block_hash TEXT,
    PRIMARY KEY (chain_id, contract_address)
);

# --- !Downs

DROP TABLE chain_sync_checkpoint;
DROP TABLE processed_chain_events;
ALTER TABLE pets DROP COLUMN name;
