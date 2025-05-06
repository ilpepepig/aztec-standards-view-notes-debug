use crate::test::utils;
use crate::Token;
use authwit::cheatcodes as authwit_cheatcodes;
use aztec::note::constants::MAX_NOTES_PER_PAGE;
use uint_note::uint_note::{PartialUintNote, UintNote};

// TODO: Can't figure out why this test is failing
#[test]
unconstrained fn transfer_private_multiple_notes_recursively() {
    // Setup with account contracts. Slower since we actually deploy them, but needed for authwits.
    let (env, token_contract_address, owner, recipient) =
        utils::setup(/* with_account_contracts */ true);

    let notes_amount: u128 = 1000;
    let notes_count: u128 = 12;
    let total_amount = notes_amount * notes_count;

    env.impersonate(owner);
    for i in 0..notes_count {
        utils::mint_to_private(env, token_contract_address, owner, notes_amount);
    }

    // Transfer tokens
    // Transfer will require 11 notes with change, which requires 2 recursive calls: 2 + 8 + 1
    env.impersonate(owner);
    // transfer amount is 10999 of the 12000 total
    let transfer_amount = total_amount - notes_amount - (1 as u128);
    let transfer_private_from_call_interface = Token::at(token_contract_address)
        .transfer_private_to_private(owner, recipient, transfer_amount);
    transfer_private_from_call_interface.call(&mut env.private());
    env.advance_block_by(1);

    // Check that the notes still owned by the owner are correct
    env.impersonate(token_contract_address);
    let final_owner_notes: BoundedVec<UintNote, MAX_NOTES_PER_PAGE> =
        utils::get_private_balance_notes(owner, 0);
    assert(final_owner_notes.len() == 2, "Incorrect note count"); // 1000 UintNote x1 and 1 UintNote x1
    assert(final_owner_notes.get(0).get_value() == notes_amount, "Incorrect note amount");
    assert(final_owner_notes.get(1).get_value() == (1 as u128), "Incorrect note change amount");

    // Check that the notes generated to the recipient are correct
    env.impersonate(token_contract_address);
    let recipient_notes: BoundedVec<UintNote, MAX_NOTES_PER_PAGE> =
        utils::get_private_balance_notes(recipient, 0);
    assert(recipient_notes.len() == 1, "Incorrect transferred note count"); // 8999 UintNote x1
    assert(
        recipient_notes.get(0).get_value() == transfer_amount,
        "Incorrect transferred note amount",
    );

    // Check balances
    utils::check_private_balance(
        token_contract_address,
        owner,
        total_amount - transfer_amount,
    );
    utils::check_private_balance(token_contract_address, recipient, transfer_amount);
}
