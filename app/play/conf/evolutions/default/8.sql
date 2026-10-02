# --- !Ups

DROP TRIGGER IF EXISTS pets_changed ON pets;
DROP FUNCTION IF EXISTS notify_pet_changed();

# --- !Downs

CREATE OR REPLACE FUNCTION notify_pet_changed()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM pg_notify('muttniks_pet_changed', NEW.id::text);;
  RETURN NEW;;
END
$$;

CREATE TRIGGER pets_changed
AFTER INSERT OR UPDATE ON pets
FOR EACH ROW
EXECUTE FUNCTION notify_pet_changed();
