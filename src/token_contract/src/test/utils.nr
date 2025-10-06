use crate::Token;
use aztec::{
    note::{constants::MAX_NOTES_PER_PAGE, note_getter::view_notes, note_getter_options::NoteStatus, note_viewer_options::NoteViewerOptions},
    oracle::{execution::get_contract_address, random::random},
    protocol_types::{address::AztecAddress, storage::map::derive_storage_slot_in_map},
    test::helpers::test_environment::TestEnvironment,
    state_vars::private_set::PrivateSet,
};
use std::test::OracleMock;
use uint_note::uint_note::UintNote;

pub unconstrained fn setup(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {
    // Setup env, generate keys
    let mut env = TestEnvironment::new();
    let (owner, recipient) = if with_account_contracts {
        let owner = env.create_contract_account();
        let recipient = env.create_contract_account();
        (owner, recipient)
    } else {
        let owner = env.create_light_account();
        let recipient = env.create_light_account();
        (owner, recipient)
    };

    let token_contract_address = deploy_token(&mut env, owner);

    (&mut env, token_contract_address, owner, recipient)
}

pub unconstrained fn deploy_token(env: &mut TestEnvironment, owner: AztecAddress) -> AztecAddress {
    // Deploy token contract
    let token_contract_address = env.deploy("./@token_contract/Token").without_initializer();

    token_contract_address
}

pub unconstrained fn mint_to_private(
    env: &mut TestEnvironment,
    token_contract_address: AztecAddress,
    recipient: AztecAddress,
    amount: u128,
) {
    let note_randomness = random();
    let _ = OracleMock::mock("getRandomField").returns(note_randomness);

    env.call_private(recipient, Token::at(token_contract_address).mint_to_private(recipient, amount));
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

    env.call_private(
        from,
        Token::at(token_contract_address).transfer_private_to_private(from, recipient, amount),
    );
}

pub unconstrained fn check_private_balance(
    env: &mut TestEnvironment,
    token_contract_address: AztecAddress,
    address: AztecAddress,
    address_amount: u128,
) {
    let balance_of_private = env.simulate_utility(Token::at(token_contract_address).balance_of_private(address));
    assert(balance_of_private == address_amount, "Private balance is not correct");
}

pub unconstrained fn get_private_balance_notes(
    env: &mut TestEnvironment,
    token_contract_address: AztecAddress,
    account: AztecAddress,
    offset: u32,
) -> BoundedVec<UintNote, MAX_NOTES_PER_PAGE> {
    let notes = env.utility_context_at(token_contract_address, |context| {
        let mut options = NoteViewerOptions::new();
        let private_balances_slot = Token::storage_layout().private_balances.slot;
        let private_balance_slot = derive_storage_slot_in_map(private_balances_slot, account);
        let set = PrivateSet::new(context, private_balance_slot);
        let notes: BoundedVec<UintNote, MAX_NOTES_PER_PAGE> =
            set.view_notes(options.set_offset(offset));
        notes
    });

    notes
}
