from __future__ import annotations

import json
import os
import time
from dataclasses import dataclass
from typing import Any, Callable, TypeVar, cast
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from web3 import Web3
from web3.contract import Contract
from web3.types import TxReceipt

T = TypeVar("T")

API_BASE = os.environ.get("API_BASE", "http://app:9000")
RPC_URL = os.environ.get("RPC_URL", "http://anvil:8545")
CONTRACT_ADDRESS = os.environ.get(
    "ADOPTION_ADDRESS", "0x5FbDB2315678afecb367f032d93F642f64180aa3"
)
OWNER = Web3.to_checksum_address("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
ADOPTER = Web3.to_checksum_address("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")
RECIPIENT = Web3.to_checksum_address("0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC")

ABI: list[dict[str, Any]] = [
    {"type": "function", "name": "createAdoptee", "stateMutability": "nonpayable",
     "inputs": [{"name": "petId", "type": "uint256"}], "outputs": []},
    {"type": "function", "name": "adopt", "stateMutability": "nonpayable",
     "inputs": [{"name": "petId", "type": "uint256"}], "outputs": []},
    {"type": "function", "name": "transfer", "stateMutability": "nonpayable",
     "inputs": [{"name": "petId", "type": "uint256"}, {"name": "to", "type": "address"}], "outputs": []},
    {"type": "function", "name": "assignName", "stateMutability": "nonpayable",
     "inputs": [{"name": "petId", "type": "uint256"}, {"name": "name", "type": "bytes32"}], "outputs": []},
    {"type": "function", "name": "adopterOf", "stateMutability": "view",
     "inputs": [{"name": "petId", "type": "uint256"}], "outputs": [{"name": "", "type": "address"}]},
]


@dataclass(frozen=True)
class HttpResponse:
    status: int
    body: str

    def json(self) -> dict[str, Any]:
        value = json.loads(self.body)
        if not isinstance(value, dict):
            raise AssertionError(f"expected JSON object, got {type(value).__name__}")
        return cast(dict[str, Any], value)


def http_at(base: str, method: str, path: str, payload: dict[str, Any] | None = None) -> HttpResponse:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = Request(
        f"{base}{path}",
        data=data,
        method=method,
        headers={"Content-Type": "application/json"} if data is not None else {},
    )
    try:
        with urlopen(request, timeout=10) as response:
            return HttpResponse(response.status, response.read().decode("utf-8"))
    except HTTPError as error:
        return HttpResponse(error.code, error.read().decode("utf-8"))


def http(method: str, path: str, payload: dict[str, Any] | None = None) -> HttpResponse:
    return http_at(API_BASE, method, path, payload)


def eventually(description: str, read: Callable[[], T], accept: Callable[[T], bool], timeout: float = 30.0) -> T:
    deadline = time.monotonic() + timeout
    last: T | None = None
    while time.monotonic() < deadline:
        last = read()
        if accept(last):
            return last
        time.sleep(0.5)
    raise AssertionError(f"timed out waiting for {description}; last value={last!r}")


def wait_receipt(w3: Web3, tx_hash: Any) -> TxReceipt:
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=20)
    assert receipt["status"] == 1
    return receipt


def sync(pet_id: int) -> dict[str, Any]:
    response = http("GET", f"/pets/{pet_id}")
    if response.status != 200:
        return {"httpStatus": response.status, "body": response.body}
    return response.json()


def test_complete_adoption_like_name_transfer_flow() -> None:
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    assert w3.is_connected()
    assert w3.eth.chain_id == 31337

    contract: Contract = w3.eth.contract(
        address=Web3.to_checksum_address(CONTRACT_ADDRESS), abi=ABI
    )
    pet_id = int(time.time_ns() % 8_000_000_000) + 1_000_000

    wait_receipt(w3, contract.functions.createAdoptee(pet_id).transact({"from": OWNER}))
    created = eventually(
        "PetCreated sync",
        lambda: sync(pet_id),
        lambda pet: pet.get("status") == "unadopted",
    )
    assert created["trustedLikes"] == 0

    created_at = int(time.time())
    first_like = http(
        "POST",
        f"/pets/{pet_id}/likes",
        {"session": f"integration-{pet_id}", "sessionCreatedAtEpochSecond": created_at},
    )
    assert first_like.status == 201, first_like.body
    assert first_like.json()["decision"] == "accepted"
    assert first_like.json()["trustedLikes"] == 1

    repeated_like = http(
        "POST",
        f"/pets/{pet_id}/likes",
        {"session": f"integration-{pet_id}", "sessionCreatedAtEpochSecond": created_at},
    )
    assert repeated_like.status == 201, repeated_like.body
    assert repeated_like.json()["decision"] == "suspicious"
    assert "repeated-session" in repeated_like.json()["reasons"]
    assert repeated_like.json()["rawLikes"] == 2
    assert repeated_like.json()["trustedLikes"] == 1

    wait_receipt(w3, contract.functions.adopt(pet_id).transact({"from": ADOPTER}))
    adopted = eventually(
        "Adopted sync",
        lambda: sync(pet_id),
        lambda pet: str(pet.get("adopter", "")).lower() == ADOPTER.lower(),
    )
    assert adopted["status"] == "adopted"
    assert cast(str, contract.functions.adopterOf(pet_id).call()).lower() == ADOPTER.lower()

    name = "Luna"
    encoded_name = name.encode("utf-8").ljust(32, b"\0")
    wait_receipt(w3, contract.functions.assignName(pet_id, encoded_name).transact({"from": ADOPTER}))
    named = eventually(
        "NameAssigned sync",
        lambda: sync(pet_id),
        lambda pet: pet.get("name") == name,
    )
    assert named["name"] == name

    wait_receipt(w3, contract.functions.transfer(pet_id, RECIPIENT).transact({"from": ADOPTER}))
    transferred = eventually(
        "Transferred sync",
        lambda: sync(pet_id),
        lambda pet: str(pet.get("adopter", "")).lower() == RECIPIENT.lower(),
    )
    assert transferred["trustedLikes"] == 1
    assert transferred["rawLikes"] == 2
    assert cast(str, contract.functions.adopterOf(pet_id).call()).lower() == RECIPIENT.lower()


def test_contract_revert_does_not_create_sync() -> None:
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    contract: Contract = w3.eth.contract(
        address=Web3.to_checksum_address(CONTRACT_ADDRESS), abi=ABI
    )
    pet_id = int(time.time_ns() % 8_000_000_000) + 9_000_000_000
    wait_receipt(w3, contract.functions.createAdoptee(pet_id).transact({"from": OWNER}))
    eventually("PetCreated sync", lambda: sync(pet_id), lambda pet: pet.get("status") == "unadopted")

    try:
        contract.functions.transfer(pet_id, RECIPIENT).transact({"from": RECIPIENT})
    except Exception:
        pass
    else:
        raise AssertionError("unauthorized transfer unexpectedly succeeded")

    current = sync(pet_id)
    assert current["status"] == "unadopted"
    assert current.get("adopter") in (None, "")
