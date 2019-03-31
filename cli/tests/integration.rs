extern crate muttniks_cli;

extern crate reqwest;
extern crate serde;
extern crate rand;

use std::{thread, time};

use std::env;
use std::time::Duration;
use reqwest::ClientBuilder;
use reqwest::Url;

use rand::{thread_rng, Rng};
use rand::distributions::Alphanumeric;

#[test]
fn test_adoption() -> Result<(), Box<::std::error::Error>> {
    let api_base_url = Url::parse(&env::var("API_BASE_URL")?)?;
    let cache_base_url = Url::parse(&env::var("CACHE_BASE_URL")?)?;

    let timeout = Duration::new(30, 0);
    let client = ClientBuilder::new().timeout(timeout).build()?;

    let account = &env::var("TEST_ACCOUNT")?;
    let private_key = &env::var("TEST_PRIVATE_KEY")?;

    let pet_id = *&env::var("TEST_PET_ID")?.parse::<i64>().unwrap();

    let allow_adoption_errors = *&env::var("TEST_ALLOW_ADOPTION_ERRORS")?.parse::<i64>().unwrap_or(0);

    println!("Adopting: {:?} from private key: {:?} account: {:?}", pet_id, private_key, account);

    let adopt_pet_result = muttniks_cli::repository::adopt_pet(&client, &api_base_url, private_key, pet_id);

    match adopt_pet_result {
        Ok(r) => { println!("adopt_pet_result: {:?}", r); }
        Err(e) => {
            if allow_adoption_errors == 0 {
                eprintln!("Error: {}", e);
                return Err(e)
            }
            else {
                println!("Error adopting pet id: {:?} but ignoring due to TEST_ALLOW_ADOPTION_ERRORS being set to: {:?}", pet_id, allow_adoption_errors);
            }
        }
    }

    let sleep_duration = time::Duration::from_secs(60);

    {
        let mut x = 0;

        loop {
            let last_known_adopters_update_result = muttniks_cli::repository::get_last_known_adopters_update(&client, &api_base_url)?;

            println!("last_known_adopters_update_result: {:?}", last_known_adopters_update_result);
            let adopters_last_updated = last_known_adopters_update_result.adoptersLastUpdated.unwrap_or(0);
            if (x != 0) && (adopters_last_updated > x) {
                break;
            }
            x = adopters_last_updated;

            println!("Waiting for adopter cache...");

            thread::sleep(sleep_duration);
        }

        let get_pets_by_adopter_result = muttniks_cli::repository::get_pets_by_adopter(&client, &api_base_url, account)?;

        println!("get_pets_by_adopter_result: {:?}", get_pets_by_adopter_result);
        let pets: Vec<&muttniks_cli::repository::Pet> = get_pets_by_adopter_result.iter().filter(|p| p.externalId == pet_id).collect();
        assert_eq!(pets.len(), 1);
    }

    {
        let random_string: String = thread_rng()
            .sample_iter(&Alphanumeric)
            .take(16)
            .collect();

        println!("Assigning name: {:?} to: {:?}", random_string, pet_id);

        let assign_name_to_pet_result = muttniks_cli::repository::assign_name_to_pet(&client, &api_base_url, private_key, pet_id, &random_string)?;

        println!("assign_name_to_pet_result: {:?}", assign_name_to_pet_result);

        let mut x = 0;

        loop {
            let pet_name_result = muttniks_cli::repository::get_pet_name(&client, &cache_base_url, pet_id)?;

            println!("pet_name_result: {:?}", pet_name_result);
            let pet_name_updated = pet_name_result.lastUpdateTime.unwrap_or(0);
            if (x != 0) && (pet_name_updated > x) {
                assert_eq!(pet_name_result.name.unwrap(), random_string);
                break;
            }
            x = pet_name_updated;
            println!("Waiting for name cache...");

            thread::sleep(sleep_duration);
        }
    }


    Ok(())
}
