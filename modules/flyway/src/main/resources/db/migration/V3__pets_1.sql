CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

INSERT INTO "pets" VALUES
    (1, uuid_generate_v4(), CURRENT_TIMESTAMP),
    (2, uuid_generate_v4(), CURRENT_TIMESTAMP),
    (3, uuid_generate_v4(), CURRENT_TIMESTAMP),
    (4, uuid_generate_v4(), CURRENT_TIMESTAMP),
    (5, uuid_generate_v4(), CURRENT_TIMESTAMP),
    (6, uuid_generate_v4(), CURRENT_TIMESTAMP)
;

INSERT INTO "pet_display" VALUES
    (1, 'Laika', 'https://upload.wikimedia.org/wikipedia/en/7/71/Laika_%28Soviet_dog%29.jpg', CURRENT_TIMESTAMP),
    (2, 'Belka', 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/18/Belka_Dog.jpg/1024px-Belka_Dog.jpg', CURRENT_TIMESTAMP),
    (3, 'Strelka', 'https://upload.wikimedia.org/wikipedia/commons/b/bd/Strelka_Dog.jpg', CURRENT_TIMESTAMP),
    (4, 'Kozyavka', 'https://www.collectorsweekly.com/articles/wp-content/uploads/2015/01/unnamed-101.jpg', CURRENT_TIMESTAMP),
    (5, 'Chernushka', 'https://www.collectorsweekly.com/articles/wp-content/uploads/2015/01/unnamed-141.jpg', CURRENT_TIMESTAMP),
    (6, 'Veterok and Ugoljok', 'https://upload.wikimedia.org/wikipedia/commons/e/e2/Rymdhundarna_Veterok_och_Ugoljok_%2816493301588%29.jpg', CURRENT_TIMESTAMP)
;
