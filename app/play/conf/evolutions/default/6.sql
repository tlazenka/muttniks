# --- !Ups

CREATE TABLE pet_likes (
    like_id UUID PRIMARY KEY,
    pet_id BIGINT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    anonymous_session TEXT NOT NULL,
    network_bucket TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    session_created_at TIMESTAMPTZ NOT NULL,
    classification TEXT NOT NULL DEFAULT 'pending'
        CHECK (classification IN ('pending', 'accepted', 'suspicious')),
    like_reasons TEXT[] NOT NULL DEFAULT '{}'
);

CREATE INDEX pet_likes_recent_idx ON pet_likes (occurred_at DESC);
CREATE INDEX pet_likes_pet_idx ON pet_likes (pet_id, occurred_at DESC);

# --- !Downs

DROP TABLE pet_likes;
