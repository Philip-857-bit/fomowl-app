//! Integer-only transaction DTOs; planning and verification are SDK operations.
use super::bitcoin_account::{BitcoinAccountDto, BitcoinKeychainDto, BitcoinNetworkDto};
use owllet_core::transactions::{bitcoin as core, bitcoin_signing};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BitcoinUtxoDto {
    pub txid: String,
    pub vout: u32,
    pub value_sat: u64,
    pub script_pubkey_hex: String,
    pub keychain: BitcoinKeychainDto,
    pub address_index: u32,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BitcoinRecipientDto {
    pub address: String,
    pub amount_sat: u64,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BitcoinTransactionPlanDto {
    pub account: BitcoinAccountDto,
    pub unsigned_tx_hex: String,
    pub selected_utxos: Vec<BitcoinUtxoDto>,
    pub recipients: Vec<BitcoinRecipientDto>,
    pub change_index: u32,
    pub rbf: bool,
    pub fee_rate_sat_vb: u64,
    pub recipient_total_sat: u64,
    pub change_sat: u64,
    pub fee_sat: u64,
    pub estimated_vbytes: u64,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SignedBitcoinTransactionDto {
    pub raw_transaction_hex: String,
    pub txid: String,
    pub wtxid: String,
    pub fee_sat: u64,
    pub vbytes: u64,
}
impl BitcoinUtxoDto {
    fn core(self) -> core::BitcoinUtxo {
        core::BitcoinUtxo {
            txid: self.txid,
            vout: self.vout,
            value_sat: self.value_sat,
            script_pubkey_hex: self.script_pubkey_hex,
            keychain: self.keychain.core(),
            address_index: self.address_index,
        }
    }
    fn from_core(value: core::BitcoinUtxo) -> Self {
        Self {
            txid: value.txid,
            vout: value.vout,
            value_sat: value.value_sat,
            script_pubkey_hex: value.script_pubkey_hex,
            keychain: match value.keychain {
                owllet_core::BitcoinKeychain::External => BitcoinKeychainDto::External,
                owllet_core::BitcoinKeychain::Internal => BitcoinKeychainDto::Internal,
            },
            address_index: value.address_index,
        }
    }
}
impl BitcoinRecipientDto {
    fn core(self) -> core::BitcoinRecipient {
        core::BitcoinRecipient {
            address: self.address,
            amount_sat: self.amount_sat,
        }
    }
    fn from_core(value: core::BitcoinRecipient) -> Self {
        Self {
            address: value.address,
            amount_sat: value.amount_sat,
        }
    }
}
impl BitcoinTransactionPlanDto {
    pub(crate) fn core(self) -> core::BitcoinTransactionPlan {
        core::BitcoinTransactionPlan {
            account: self.account.core(),
            unsigned_tx_hex: self.unsigned_tx_hex,
            selected_utxos: self
                .selected_utxos
                .into_iter()
                .map(BitcoinUtxoDto::core)
                .collect(),
            recipients: self
                .recipients
                .into_iter()
                .map(BitcoinRecipientDto::core)
                .collect(),
            change_index: self.change_index,
            rbf: self.rbf,
            fee_rate_sat_vb: self.fee_rate_sat_vb,
            recipient_total_sat: self.recipient_total_sat,
            change_sat: self.change_sat,
            fee_sat: self.fee_sat,
            estimated_vbytes: self.estimated_vbytes,
        }
    }
    fn from_core(value: core::BitcoinTransactionPlan) -> Result<Self, String> {
        Ok(Self {
            account: BitcoinAccountDto::from_core(value.account)?,
            unsigned_tx_hex: value.unsigned_tx_hex,
            selected_utxos: value
                .selected_utxos
                .into_iter()
                .map(BitcoinUtxoDto::from_core)
                .collect(),
            recipients: value
                .recipients
                .into_iter()
                .map(BitcoinRecipientDto::from_core)
                .collect(),
            change_index: value.change_index,
            rbf: value.rbf,
            fee_rate_sat_vb: value.fee_rate_sat_vb,
            recipient_total_sat: value.recipient_total_sat,
            change_sat: value.change_sat,
            fee_sat: value.fee_sat,
            estimated_vbytes: value.estimated_vbytes,
        })
    }
}
impl SignedBitcoinTransactionDto {
    pub(crate) fn from_core(value: bitcoin_signing::SignedBitcoinTransaction) -> Self {
        Self {
            raw_transaction_hex: value.raw_transaction_hex,
            txid: value.txid,
            wtxid: value.wtxid,
            fee_sat: value.fee_sat,
            vbytes: value.vbytes,
        }
    }
}
pub fn plan_bitcoin_transfer(
    network: BitcoinNetworkDto,
    account: BitcoinAccountDto,
    candidate_utxos: Vec<BitcoinUtxoDto>,
    recipients: Vec<BitcoinRecipientDto>,
    fee_rate_sat_vb: u64,
    change_index: u32,
    rbf: bool,
) -> Result<BitcoinTransactionPlanDto, String> {
    if candidate_utxos.len() > core::BITCOIN_MAX_ITEMS || recipients.len() > core::BITCOIN_MAX_ITEMS
    {
        return Err("Too many Bitcoin transaction items".into());
    }
    let utxos: Vec<_> = candidate_utxos
        .into_iter()
        .map(BitcoinUtxoDto::core)
        .collect();
    let recipients: Vec<_> = recipients
        .into_iter()
        .map(BitcoinRecipientDto::core)
        .collect();
    BitcoinTransactionPlanDto::from_core(core::plan_bitcoin_transaction(
        network.core(),
        &account.core(),
        &utxos,
        &recipients,
        fee_rate_sat_vb,
        change_index,
        rbf,
    )?)
}
pub fn validate_bitcoin_transfer_plan(plan: BitcoinTransactionPlanDto) -> Result<(), String> {
    core::validate_bitcoin_transaction_plan(&plan.core())
}
/// Public host observations only; replacement construction stays in Owllet Core.
pub fn plan_bitcoin_transfer_replacement(
    original_plan: BitcoinTransactionPlanDto,
    original_signed_tx_hex: String,
    original_txid: String,
    original_unconfirmed: bool,
    has_descendants: bool,
    incremental_relay_fee_sat_vb: u64,
    fee_rate_sat_vb: u64,
) -> Result<BitcoinTransactionPlanDto, String> {
    BitcoinTransactionPlanDto::from_core(
        owllet_core::transactions::bitcoin_rbf::plan_bitcoin_rbf_replacement(
            &original_plan.core(),
            &original_signed_tx_hex,
            &owllet_core::transactions::bitcoin_rbf::BitcoinRbfContext {
                original_txid,
                original_unconfirmed,
                has_descendants,
                incremental_relay_fee_sat_vb,
            },
            fee_rate_sat_vb,
        )?,
    )
}
pub fn create_bitcoin_transfer_psbt(plan: BitcoinTransactionPlanDto) -> Result<String, String> {
    owllet_core::transactions::bitcoin_psbt::create_bitcoin_psbt(&plan.core())
}
pub fn verify_bitcoin_transfer(
    plan: BitcoinTransactionPlanDto,
    raw_transaction_hex: String,
) -> Result<SignedBitcoinTransactionDto, String> {
    bitcoin_signing::verify_signed_bitcoin_transaction(&plan.core(), &raw_transaction_hex)
        .map(SignedBitcoinTransactionDto::from_core)
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BitcoinPsbtOutputDto {
    pub amount_sat: u64,
    pub script_pubkey_hex: String,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BitcoinPsbtInspectionDto {
    pub input_count: u32,
    pub outputs: Vec<BitcoinPsbtOutputDto>,
    pub fee_sat: Option<u64>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BitcoinPsbtFinalizationDto {
    pub psbt_base64: String,
    pub complete: bool,
    pub raw_transaction_hex: Option<String>,
}
pub fn inspect_bitcoin_transfer_psbt(
    psbt_base64: String,
) -> Result<BitcoinPsbtInspectionDto, String> {
    let result = owllet_core::transactions::bitcoin_psbt::inspect_bitcoin_psbt(&psbt_base64)?;
    Ok(BitcoinPsbtInspectionDto {
        input_count: u32::try_from(result.input_count).map_err(|_| "Oversized Bitcoin PSBT")?,
        outputs: result
            .outputs
            .into_iter()
            .map(|output| BitcoinPsbtOutputDto {
                amount_sat: output.amount_sat,
                script_pubkey_hex: output.script_pubkey_hex,
            })
            .collect(),
        fee_sat: result.fee_sat,
    })
}
pub fn finalize_bitcoin_transfer_psbt(
    psbt_base64: String,
) -> Result<BitcoinPsbtFinalizationDto, String> {
    let result = owllet_core::transactions::bitcoin_psbt::finalize_bitcoin_psbt(&psbt_base64)?;
    Ok(BitcoinPsbtFinalizationDto {
        psbt_base64: result.psbt_base64,
        complete: result.complete,
        raw_transaction_hex: result.raw_transaction_hex,
    })
}

#[cfg(test)]
mod tests {
    use super::super::bitcoin_account::{
        derive_bitcoin_account_address, derive_bitcoin_account_metadata,
        derive_bitcoin_owned_script, BitcoinPurposeDto,
    };
    use super::*;
    const MNEMONIC: &str = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
    fn inputs(
        purpose: BitcoinPurposeDto,
    ) -> (BitcoinAccountDto, BitcoinUtxoDto, BitcoinRecipientDto) {
        let seed = owllet_core::mnemonic_to_seed(MNEMONIC).unwrap();
        let account =
            derive_bitcoin_account_metadata(seed, BitcoinNetworkDto::Mainnet, 0, purpose).unwrap();
        let utxo = BitcoinUtxoDto {
            txid: "11".repeat(32),
            vout: 0,
            value_sat: 100_000,
            script_pubkey_hex: derive_bitcoin_owned_script(
                account.clone(),
                account.network,
                BitcoinKeychainDto::External,
                0,
            )
            .unwrap(),
            keychain: BitcoinKeychainDto::External,
            address_index: 0,
        };
        let recipient = BitcoinRecipientDto {
            address: derive_bitcoin_account_address(
                account.clone(),
                account.network,
                BitcoinKeychainDto::External,
                1,
            )
            .unwrap(),
            amount_sat: 50_000,
        };
        (account, utxo, recipient)
    }
    #[test]
    fn rbf_adapter_preserves_both_purposes_and_requires_pending_observations() {
        for purpose in [BitcoinPurposeDto::Bip84, BitcoinPurposeDto::Bip86] {
            let (account, utxo, recipient) = inputs(purpose);
            let plan = plan_bitcoin_transfer(
                account.network,
                account.clone(),
                vec![utxo],
                vec![recipient],
                2,
                0,
                true,
            )
            .unwrap();
            let seed = owllet_core::mnemonic_to_seed(MNEMONIC).unwrap();
            let core_account = account.core();
            let secret = zeroize::Zeroizing::new(
                owllet_core::derive_bitcoin_account_xprv_from_seed(
                    &seed,
                    core_account.network,
                    0,
                    core_account.purpose,
                )
                .unwrap(),
            );
            let signed =
                bitcoin_signing::sign_bitcoin_transaction(&plan.clone().core(), &secret).unwrap();
            let replacement = plan_bitcoin_transfer_replacement(
                plan.clone(),
                signed.raw_transaction_hex.clone(),
                signed.txid.clone(),
                true,
                false,
                1,
                4,
            )
            .unwrap();
            assert_eq!(replacement.recipients, plan.recipients);
            assert_eq!(replacement.selected_utxos, plan.selected_utxos);
            assert_eq!(replacement.account, plan.account);
            assert!(replacement.fee_sat > plan.fee_sat);
            validate_bitcoin_transfer_plan(replacement.clone()).unwrap();
            let newer =
                bitcoin_signing::sign_bitcoin_transaction(&replacement.clone().core(), &secret)
                    .unwrap();
            assert_eq!(
                verify_bitcoin_transfer(replacement, newer.raw_transaction_hex)
                    .unwrap()
                    .txid,
                newer.txid
            );
            for (pending, descendants, relay, rate) in [
                (false, false, 1, 4),
                (true, true, 1, 4),
                (true, false, 0, 4),
                (true, false, 1, 2),
                (true, false, u64::MAX, 4),
            ] {
                assert!(plan_bitcoin_transfer_replacement(
                    plan.clone(),
                    signed.raw_transaction_hex.clone(),
                    signed.txid.clone(),
                    pending,
                    descendants,
                    relay,
                    rate
                )
                .is_err());
            }
            assert!(plan_bitcoin_transfer_replacement(
                plan,
                "invalid".into(),
                signed.txid,
                true,
                false,
                1,
                4
            )
            .is_err());
        }
    }

    #[test]
    fn both_purposes_plan_exact_integer_amounts_and_reject_tampering() {
        for purpose in [BitcoinPurposeDto::Bip84, BitcoinPurposeDto::Bip86] {
            let (account, utxo, recipient) = inputs(purpose);
            let plan = plan_bitcoin_transfer(
                account.network,
                account.clone(),
                vec![utxo.clone()],
                vec![recipient.clone()],
                2,
                0,
                true,
            )
            .unwrap();
            assert_eq!(plan.recipient_total_sat, 50_000);
            assert_eq!(
                plan.fee_sat + plan.change_sat + plan.recipient_total_sat,
                100_000
            );
            assert!(plan.change_sat > 0);
            validate_bitcoin_transfer_plan(plan.clone()).unwrap();
            let psbt = create_bitcoin_transfer_psbt(plan.clone()).unwrap();
            let inspection = inspect_bitcoin_transfer_psbt(psbt.clone()).unwrap();
            assert_eq!(inspection.input_count, 1);
            assert_eq!(inspection.fee_sat, Some(plan.fee_sat));
            assert!(!finalize_bitcoin_transfer_psbt(psbt).unwrap().complete);
            assert!(inspect_bitcoin_transfer_psbt("invalid".into()).is_err());
            let mut edited = plan.clone();
            edited.fee_sat += 1;
            assert!(validate_bitcoin_transfer_plan(edited).is_err());
            let mut forged = utxo.clone();
            forged.script_pubkey_hex = "00".into();
            assert!(plan_bitcoin_transfer(
                account.network,
                account.clone(),
                vec![forged],
                vec![recipient.clone()],
                2,
                0,
                true
            )
            .is_err());
            assert!(plan_bitcoin_transfer(
                account.network,
                account.clone(),
                vec![utxo.clone(), utxo.clone()],
                vec![recipient.clone()],
                2,
                0,
                true
            )
            .is_err());
            assert!(plan_bitcoin_transfer(
                BitcoinNetworkDto::Testnet4,
                account.clone(),
                vec![utxo.clone()],
                vec![recipient.clone()],
                2,
                0,
                true
            )
            .is_err());
            assert!(plan_bitcoin_transfer(
                account.network,
                account,
                vec![utxo],
                vec![recipient],
                u64::MAX,
                0,
                true
            )
            .is_err());
            assert!(verify_bitcoin_transfer(plan, "invalid".into()).is_err());
        }
    }
}
