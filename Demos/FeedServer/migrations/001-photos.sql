CREATE TABLE IF NOT EXISTS city_photos (
  id text PRIMARY KEY,
  city text NOT NULL,
  country text NOT NULL,
  place text NOT NULL,
  captured_at timestamptz NOT NULL,
  photographer text NOT NULL,
  title text NOT NULL,
  image_url text NOT NULL
);
INSERT INTO city_photos VALUES
('photo-sf-1','San Francisco','US','San Francisco','2026-10-05T12:00:00Z','Keith','San Francisco','https://bloximages.chicago2.vip.townnews.com/sfweekly.com/content/tncms/assets/v3/editorial/d/92/d923f998-5f89-58ac-8ccf-8954f64548b1/63b83e6c99eec.image.jpg'),
('photo-la-1','Los Angeles','US','Los Angeles','2026-10-04T12:00:00Z','Other Keith','Los Angeles','https://cdn.sanity.io/images/ianh83xv/production/b64841f878ee9a1fd27bb5b9fb0fec890362153d-1500x987.jpg?auto=format&w=720&fit=max'),
('photo-nyc-1','New York','US','New York','2026-10-03T12:00:00Z','Keith 3','New York','https://media.architecturaldigest.com/photos/5d5ae8340682ef0009f632e9/16:9/w_2240,c_limit/GettyImages-536213182.jpg')
ON CONFLICT (id) DO UPDATE SET city=EXCLUDED.city,country=EXCLUDED.country,place=EXCLUDED.place,captured_at=EXCLUDED.captured_at,photographer=EXCLUDED.photographer,title=EXCLUDED.title,image_url=EXCLUDED.image_url;
