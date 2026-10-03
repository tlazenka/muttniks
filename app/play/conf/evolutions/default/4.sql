# --- !Ups

ALTER TABLE processed_chain_events ADD COLUMN event_type TEXT;
ALTER TABLE processed_chain_events ADD COLUMN pet_id BIGINT;
ALTER TABLE processed_chain_events ADD COLUMN adopter TEXT;
ALTER TABLE processed_chain_events ADD COLUMN recipient TEXT;
ALTER TABLE processed_chain_events ADD COLUMN assigned_name TEXT;

CREATE TABLE chain_sync_blocks (
    chain_id BIGINT NOT NULL,
    contract_address TEXT NOT NULL,
    block_number BIGINT NOT NULL,
    block_hash TEXT NOT NULL,
    PRIMARY KEY (chain_id, contract_address, block_number)
);

CREATE INDEX processed_chain_events_block_idx
    ON processed_chain_events (chain_id, block_number, log_index);

# --- !Downs

DROP INDEX processed_chain_events_block_idx;
DROP TABLE chain_sync_blocks;
ALTER TABLE processed_chain_events DROP COLUMN assigned_name;
ALTER TABLE processed_chain_events DROP COLUMN recipient;
ALTER TABLE processed_chain_events DROP COLUMN adopter;
ALTER TABLE processed_chain_events DROP COLUMN pet_id;
ALTER TABLE processed_chain_events DROP COLUMN event_type;
