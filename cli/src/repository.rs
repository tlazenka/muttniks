extern crate reqwest;
extern crate serde;

use serde::{Serialize, Deserialize};

use reqwest::Client;
use reqwest::Url;

use std::error;

#[allow(non_snake_case)]
#[derive(Deserialize, Serialize, Debug)]
pub struct Pet {
    pub externalId: i64,
    pub title: Option<String>,
}

#[allow(non_snake_case)]
#[derive(Deserialize, Serialize, Debug)]
pub struct AdoptersLastUpdated {
    pub adoptersLastUpdated: Option<i64>,
}

#[allow(non_snake_case)]
#[derive(Deserialize, Serialize, Debug)]
pub struct PetName {
    pub name: Option<String>,
    pub lastUpdateTime: Option<i64>,
}

type Result<T> = std::result::Result<T, Box<error::Error>>;

pub fn get_pets_by_adopter(client: &Client, base_url: &Url, adopter: &str) -> Result<Vec<Pet>> {
    let url = Url::parse_with_params(base_url.join("api/petsByAdopter")?.as_str(),
                                     &[("adopter", adopter)])?;

    let mut response = client
        .get(url.as_str()).send()?;

    if !(response.status().is_success()) {
        return Err(response.text()?.into());
    }

    let result: Vec<Pet> = response.json()?;
    return Ok(result);
}

pub fn adopt_pet(client: &Client, base_url: &Url, private_key: &str, pet_id: i64) -> Result<()> {
    let url = Url::parse_with_params(base_url.join("api/adopt")?.as_str(),
                                     &[("petId", pet_id.to_string()), ("privateKey", private_key.to_string())])?;

    let mut response = client
        .post(url)
        .send()?;

    if !(response.status().is_success()) {
        return Err(response.text()?.into());
    }

    return Ok(());
}

pub fn assign_name_to_pet(client: &Client, base_url: &Url, private_key: &str, pet_id: i64, name: &str) -> Result<()> {
	let url = Url::parse_with_params(base_url.join("api/assignName")?.as_str(),
                                     &[("petId", pet_id.to_string()), ("name", name.to_string()), ("privateKey", private_key.to_string())])?;

    let mut response = client
        .post(url)
        .send()?;

    if !(response.status().is_success()) {
        return Err(response.text()?.into());
    }

    return Ok(());
}

pub fn get_last_known_adopters_update(client: &Client, base_url: &Url) -> Result<AdoptersLastUpdated> {
    let url = Url::parse(base_url.join("api/lastKnownAdoptersUpdate")?.as_str())?;

    let mut response = client
        .get(url.as_str()).send()?;

    if !(response.status().is_success()) {
        return Err(response.text()?.into());
    }

    let result: AdoptersLastUpdated = response.json()?;
    return Ok(result);
}

pub fn get_pet_name(client: &Client, base_url: &Url, pet_id: i64) -> Result<PetName> {
    let url = Url::parse(base_url.join("petName/")?.join(&pet_id.to_string())?.as_str())?;

    let mut response = client
        .get(url.as_str()).send()?;

    if !(response.status().is_success()) {
        return Err(response.text()?.into());
    }

    let result: PetName = response.json()?;
    return Ok(result);
}
