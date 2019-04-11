extern crate muttniks_cli;

extern crate reqwest;
extern crate serde;
extern crate rand;
#[macro_use]
extern crate lazy_static;

use std::{thread, time};

use std::env;
use std::time::Duration;
use reqwest::ClientBuilder;
use reqwest::Url;

use rand::{thread_rng, Rng};
use rand::distributions::Alphanumeric;

lazy_static! {
    static ref API_BASE_URL: Url = Url::parse(&env::var("API_BASE_URL").unwrap()).unwrap();
    static ref CACHE_BASE_URL: Url = Url::parse(&env::var("CACHE_BASE_URL").unwrap()).unwrap();

    static ref CLIENT_TIMEOUT_SECONDS: u64 = env::var("TEST_CLIENT_TIMEOUT_SECONDS").unwrap().parse::<u64>().unwrap();
    static ref CACHE_POLL_DURATION_SECONDS: u64 = env::var("TEST_CACHE_POLL_DURATION_SECONDS").unwrap().parse::<u64>().unwrap();

    static ref ACCOUNT: String = env::var("TEST_ACCOUNT").unwrap();
    static ref PRIVATE_KEY: String = env::var("TEST_PRIVATE_KEY").unwrap();

    static ref PET_ID: i64 = env::var("TEST_PET_ID").unwrap().parse::<i64>().unwrap();

    static ref ALLOW_ADOPTION_ERRORS: i64 = env::var("TEST_ALLOW_ADOPTION_ERRORS").unwrap().parse::<i64>().unwrap_or(0);
}

fn random_alphanumeric_string(length: usize) -> String {
    thread_rng()
        .sample_iter(&Alphanumeric)
        .take(length)
        .collect()
}

#[test]
fn test_adoption() -> Result<(), Box<::std::error::Error>> {
    let client = ClientBuilder::new().timeout(Duration::new(*CLIENT_TIMEOUT_SECONDS, 0)).build()?;

    println!("Adopting: {:?} from private key: {:?} account: {:?}", *PET_ID, *PRIVATE_KEY, *ACCOUNT);

    let adopt_pet_result = muttniks_cli::repository::adopt_pet(&client, &API_BASE_URL, &PRIVATE_KEY, *PET_ID);

    match adopt_pet_result {
        Ok(r) => { println!("adopt_pet_result: {:?}", r); }
        Err(e) => {
            if *ALLOW_ADOPTION_ERRORS == 0 {
                eprintln!("Error adopting pet id: {:?} message: {:?}", *PET_ID, e);
                return Err(e)
            }
            else {
                println!("Error adopting pet id: {:?} but ignoring due to TEST_ALLOW_ADOPTION_ERRORS being set to: {:?}", *PET_ID, *ALLOW_ADOPTION_ERRORS);
            }
        }
    }

    let sleep_duration = time::Duration::from_secs(*CACHE_POLL_DURATION_SECONDS);

    {
        let mut x = 0;

        loop {
            let last_known_adopters_update_result = muttniks_cli::repository::get_last_known_adopters_update(&client, &API_BASE_URL)?;

            println!("last_known_adopters_update_result: {:?}", last_known_adopters_update_result);
            let adopters_last_updated = last_known_adopters_update_result.adoptersLastUpdated.unwrap_or(0);
            if (x != 0) && (adopters_last_updated > x) {
                break;
            }
            x = adopters_last_updated;

            println!("Waiting for adopter cache...");

            thread::sleep(sleep_duration);
        }

        let get_pets_by_adopter_result = muttniks_cli::repository::get_pets_by_adopter(&client, &API_BASE_URL, &ACCOUNT)?;

        println!("get_pets_by_adopter_result: {:?}", get_pets_by_adopter_result);
        let pets: Vec<&muttniks_cli::repository::Pet> = get_pets_by_adopter_result.iter().filter(|p| p.externalId == *PET_ID).collect();
        assert_eq!(pets.len(), 1);
    }

    {
        let random_string: String = random_alphanumeric_string(16);

        println!("Assigning name: {:?} to: {:?}", random_string, *PET_ID);

        let assign_name_to_pet_result = muttniks_cli::repository::assign_name_to_pet(&client, &API_BASE_URL, &PRIVATE_KEY, *PET_ID, &random_string)?;

        println!("assign_name_to_pet_result: {:?}", assign_name_to_pet_result);

        let mut x = 0;

        loop {
            let pet_name_result = muttniks_cli::repository::get_pet_name(&client, &CACHE_BASE_URL, *PET_ID)?;

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
