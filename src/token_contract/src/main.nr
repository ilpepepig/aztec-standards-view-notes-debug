pub mod types;
pub mod test;

use aztec::macros::aztec;

#[aztec]
pub contract Token {
    // aztec library
    use aztec::{
        macros::{functions::{private, utility}, storage::storage},
        state_vars::Map,
        protocol_types::{address::AztecAddress, storage::map::derive_storage_slot_in_map},
        messages::logs::note::encode_and_encrypt_note,
    };
    use crate::types::balance_set::BalanceSet;
    
    /// @param private_balances The private balances of the token
    #[storage]
    struct Storage<Context> {
        private_balances: Map<AztecAddress, BalanceSet<Context>, Context>,
    }

    /// @notice Transfer tokens from private balance to another private balance
    /// @dev Spends notes, emits a new note (UintNote) with any remaining change, and sends a note to the recipient
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to transfer
    #[private]
    fn transfer_private_to_private(from: AztecAddress, to: AztecAddress, amount: u128) {
        // Subtracts `amount` from the private balance of `from`
        let change = storage.private_balances.at(from).sub(from, amount);
        // Increases `change` to the private balance of `from`, and emits a private balance note to from
        change.emit(encode_and_encrypt_note(&mut context, from));

        storage.private_balances.at(to).add(to, amount).emit(encode_and_encrypt_note(
            &mut context,
            to,
        ));
    }

    /// @notice Mints tokens
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to mint
    #[private]
    fn mint_to_private(to: AztecAddress, amount: u128) {
        storage.private_balances.at(to).add(to, amount).emit(encode_and_encrypt_note(
            &mut context,
            to,
        ));
    }

    /** ==========================================================
     * ===================== UNCONSTRAINED =======================
     * ======================================================== */

    #[utility]
    unconstrained fn balance_of_private(owner: AztecAddress) -> u128 {
        storage.private_balances.at(owner).balance_of()
    }
}
