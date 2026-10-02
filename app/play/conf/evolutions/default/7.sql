# --- !Ups

ALTER TABLE pets ADD COLUMN image_url TEXT;

# --- !Downs

ALTER TABLE pets DROP COLUMN image_url;
