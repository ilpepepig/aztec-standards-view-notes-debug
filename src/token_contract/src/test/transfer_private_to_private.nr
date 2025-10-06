use crate::test::utils;
use crate::Token;
use aztec::note::constants::MAX_NOTES_PER_PAGE;
use uint_note::uint_note::UintNote;

#[test]
unconstrained fn test_view_notes_success() {
    let (env, token_contract_address, owner, recipient) = utils::setup(true);

    let amount: u128 = 1000;

    // Mint 2 notes to owner
    utils::mint_to_private(env, token_contract_address, owner, amount);
    utils::mint_to_private(env, token_contract_address, owner, amount);

    // Transfer exactly 1 note from owner to recipient
    utils::transfer_in_private(env, owner, token_contract_address, recipient, amount);

    // The owner should own 1 note worth 1000
    let owner_notes: BoundedVec<UintNote, MAX_NOTES_PER_PAGE> =
        utils::get_private_balance_notes(env, token_contract_address, owner, 0);
    assert(owner_notes.len() == 1, "Incorrect note count");
    assert(owner_notes.get(0).get_value() == amount, "Incorrect amount");

    // The recipient should own 1 note worth 1000
    let recipient_notes: BoundedVec<UintNote, MAX_NOTES_PER_PAGE> =
        utils::get_private_balance_notes(env, token_contract_address, recipient, 0);
    assert(recipient_notes.len() == 1, "Incorrect transferred note count");
    assert(recipient_notes.get(0).get_value() == amount, "Incorrect transferred amount");
}

#[test(should_fail_with = "Incorrect note count")]
unconstrained fn test_view_notes_fail() {
    let (env, token_contract_address, owner, recipient) = utils::setup(true);

    let amount: u128 = 1000;

    // Mint 2 notes to owner
    utils::mint_to_private(env, token_contract_address, owner, amount);
    utils::mint_to_private(env, token_contract_address, owner, amount);

    // Transfer exactly 1 note from owner to recipient
    utils::transfer_in_private(env, owner, token_contract_address, recipient, amount);

    // The owner should own 1 note worth 1000, but still owns 2 notes according to view_notes
    let owner_notes: BoundedVec<UintNote, MAX_NOTES_PER_PAGE> =
        utils::get_private_balance_notes(env, token_contract_address, owner, 0);
    assert(owner_notes.len() == 2, "Incorrect note count");
    assert(owner_notes.get(0).get_value() == amount, "Incorrect amount");
    assert(owner_notes.get(1).get_value() == amount, "Incorrect amount");

    // The recipient should own 1 note worth 1000, but owns none according to view_notes
    let recipient_notes: BoundedVec<UintNote, MAX_NOTES_PER_PAGE> =
        utils::get_private_balance_notes(env, token_contract_address, recipient, 0);
    assert(recipient_notes.len() == 0, "Incorrect transferred note count");

    // However, the private transfer did happen and they actually own what they are supposed to own
    utils::check_private_balance(env, token_contract_address, owner, 1000);
    utils::check_private_balance(env, token_contract_address, recipient, 1000);
}
