use crate::Token;
use aztec::{
    note::{constants::MAX_NOTES_PER_PAGE, note_getter::view_notes, note_getter_options::NoteStatus},
    oracle::{execution::get_contract_address, random::random},
    prelude::{AztecAddress, NoteViewerOptions},
    protocol_types::storage::map::derive_storage_slot_in_map,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};
use std::test::OracleMock;
use uint_note::uint_note::UintNote;

pub unconstrained fn setup(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {
    // Setup env, generate keys
    let mut env = TestEnvironment::new();
    let (owner, recipient) = if with_account_contracts {
        let owner = env.create_account_contract(1);
        let recipient = env.create_account_contract(2);
        (owner, recipient)
    } else {
        let owner = env.create_account(1);
        let recipient = env.create_account(2);
        (owner, recipient)
    };

    let token_contract_address = deploy_token(&mut env, owner);

    (&mut env, token_contract_address, owner, recipient)
}

pub unconstrained fn deploy_token(env: &mut TestEnvironment, owner: AztecAddress) -> AztecAddress {
    // Start the test in the account contract address
    env.impersonate(owner);

    // Deploy token contract
    let initializer_call_interface = Token::interface().constructor();
    let token_contract = env.deploy("./@token_contract", "Token").with_public_void_initializer(
        initializer_call_interface,
    );
    env.advance_block_by(1);

    token_contract.to_address()
}

pub unconstrained fn mint_to_private(
    env: &mut TestEnvironment,
    token_contract_address: AztecAddress,
    recipient: AztecAddress,
    amount: u128,
) {
    let note_randomness = random();
    let _ = OracleMock::mock("getRandomField").returns(note_randomness);

    let from = recipient; // we are setting from to recipient because of TODO(#9887)
    Token::at(token_contract_address).mint_to_private(from, recipient, amount).call(
        &mut env.private(),
    );

    env.advance_block_by(1);
}

pub unconstrained fn transfer_in_private(
    env: &mut TestEnvironment,
    from: AztecAddress,
    token_contract_address: AztecAddress,
    recipient: AztecAddress,
    amount: u128,
) {
    let note_randomness = random();
    let _ = OracleMock::mock("getRandomField").returns(note_randomness);

    env.impersonate(from);
    Token::at(token_contract_address).transfer_private_to_private(from, recipient, amount).call(
        &mut env.private(),
    );

    env.advance_block_by(1);
}

pub unconstrained fn check_private_balance(
    token_contract_address: AztecAddress,
    address: AztecAddress,
    address_amount: u128,
) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(token_contract_address);
    // Direct call to unconstrained
    let balance_of_private = Token::balance_of_private(address);
    assert(balance_of_private == address_amount, "Private balance is not correct");
    cheatcodes::set_contract_address(current_contract_address);
}

pub unconstrained fn get_private_balance_notes(
    account: AztecAddress,
    offset: u32,
) -> BoundedVec<UintNote, MAX_NOTES_PER_PAGE> {
    let mut options = NoteViewerOptions::new();
    options.set_offset(offset);
    options.set_status(NoteStatus.ACTIVE);
    let private_balances_slot = Token::storage_layout().private_balances.slot;
    let private_balance_slot = derive_storage_slot_in_map(private_balances_slot, account);
    let notes: BoundedVec<UintNote, MAX_NOTES_PER_PAGE> =
        view_notes(private_balance_slot, options);
    notes
}
