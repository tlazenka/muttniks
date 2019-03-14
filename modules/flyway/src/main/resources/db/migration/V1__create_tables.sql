create table "pets" (
  "external_id" bigint NOT NULL,
  "internal_id" UUID UNIQUE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NULL,
  PRIMARY KEY(external_id)
);

create table "pet_display" (
  "pet_external_id" bigint NOT NULL,
  "title" text,
  "image_source" VARCHAR(1024) NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NULL,
  FOREIGN KEY (pet_external_id) REFERENCES pets (external_id) ON DELETE CASCADE,
  PRIMARY KEY(pet_external_id)
);

create table "pet_adopter" (
  "pet_external_id" bigint NOT NULL,
  "adopter" VARCHAR(64) NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NULL,
  FOREIGN KEY (pet_external_id) REFERENCES pets (external_id) ON DELETE CASCADE,
  PRIMARY KEY(pet_external_id)
);

