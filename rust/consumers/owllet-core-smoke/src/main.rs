//! Independent native host proof. Every key/nonce here is a PUBLIC TEST FIXTURE.
//! This executable never connects to RPC, reads real wallets, or broadcasts.
use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use owllet_core::{
    session::AccountFamily,
    transactions::{evm_calldata, solana_wire, tron},
    vault::{export_account_key, open_account_vault, seal_account_key},
    EvmTransactionFee, EvmTransactionRequest,
};
use std::process::ExitCode;

fn check(condition: bool, message: &str) -> Result<(), String> {
    if condition {
        Ok(())
    } else {
        Err(message.into())
    }
}

fn self_test() -> Result<(), String> {
    println!("Owllet Core native consumer — PUBLIC FIXTURES, NEVER SEND FUNDS");
    let wrapping_key = [11; 32]; // Public fixtures only; production hosts use protected secure entropy.
    let evm_key = "46".repeat(32);
    let evm_address = owllet_core::derive_evm_address_from_private_key(&evm_key)?;
    let record = seal_account_key(
        AccountFamily::Evm,
        &evm_key,
        &evm_address,
        &wrapping_key,
        &[1; 12],
    )
    .map_err(|e| e.to_string())?;
    let (mut session, account) =
        open_account_vault(AccountFamily::Evm, &record, &evm_address, &wrapping_key)
            .map_err(|e| e.to_string())?;
    let request = EvmTransactionRequest {
        chain_id: 1,
        nonce: 9,
        gas_limit: 21000,
        to: Some("0x3535353535353535353535353535353535353535".into()),
        value_wei: "1000000000000000000".into(),
        data_hex: String::new(),
        fee: EvmTransactionFee::Legacy {
            gas_price_wei: 20_000_000_000,
        },
    };
    let signed = session
        .sign_evm_transaction(&account, &request)
        .map_err(|e| e.to_string())?;
    check(signed.raw_transaction_hex == "0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83","EIP-155 fixture mismatch")?;
    check(
        evm_calldata::encode_erc20_transfer(
            request.to.as_deref().ok_or("Missing fixture destination")?,
            "42",
        )?
        .len()
            == 68,
        "ERC-20 calldata size mismatch",
    )?;
    check(
        export_account_key(AccountFamily::Evm, &record, &evm_address, &wrapping_key)
            .map_err(|e| e.to_string())?
            .as_str()
            == evm_key.as_str(),
        "Explicit export changed key",
    )?;
    session.lock();
    check(
        session.sign_evm_transaction(&account, &request).is_err(),
        "Locked account accepted signing",
    )?;
    check(
        open_account_vault(AccountFamily::Evm, &record, &evm_address, &[12; 32]).is_err(),
        "Wrong wrapping key opened vault",
    )?;
    println!("PASS EVM: official signed bytes, calldata, vault authentication, export, lock");

    let solana_key = "07".repeat(32);
    let payer = owllet_core::derive_solana_address_from_private_key(&[7; 32])?;
    let receiver = owllet_core::derive_solana_address_from_private_key(&[8; 32])?;
    let record = seal_account_key(
        AccountFamily::Solana,
        &solana_key,
        &payer,
        &wrapping_key,
        &[2; 12],
    )
    .map_err(|e| e.to_string())?;
    let (mut session, account) =
        open_account_vault(AccountFamily::Solana, &record, &payer, &wrapping_key)
            .map_err(|e| e.to_string())?;
    let instructions = serde_json::json!([{
        "programId":"11111111111111111111111111111111", "data":"020000000100000000000000",
        "keys":[{"pubkey":payer,"isSigner":true,"isWritable":true},{"pubkey":receiver,"isSigner":false,"isWritable":true}],
    }]);
    let signed = session
        .build_and_sign_solana_transaction(
            &account,
            "11111111111111111111111111111111",
            &instructions.to_string(),
            "[]",
        )
        .map_err(|e| e.to_string())?;
    let wire = BASE64.decode(&signed).map_err(|e| e.to_string())?;
    let message = solana_wire::solana_transaction_message_bytes(&wire)?;
    check(
        session
            .sign_solana_transaction_message(&account, &message)
            .map_err(|e| e.to_string())?
            == signed,
        "Solana raw message wire changed",
    )?;
    check(
        session
            .sign_serialized_solana_transaction(&account, &signed)
            .map_err(|e| e.to_string())?
            == signed,
        "Solana signer-slot roundtrip changed",
    )?;
    session.lock();
    check(
        session.sign_solana_message(&account, b"fixture").is_err(),
        "Locked Solana account accepted signing",
    )?;
    println!("PASS Solana: v0 compilation, exact message/wire, signer slots, vault, lock");

    let tron_address = owllet_core::derive_tron_address_from_private_key(&evm_key)?;
    let record = seal_account_key(
        AccountFamily::Tron,
        &evm_key,
        &tron_address,
        &wrapping_key,
        &[3; 12],
    )
    .map_err(|e| e.to_string())?;
    let (mut session, account) =
        open_account_vault(AccountFamily::Tron, &record, &tron_address, &wrapping_key)
            .map_err(|e| e.to_string())?;
    let personal = session
        .sign_tron_personal_message(&account, "hello")
        .map_err(|e| e.to_string())?;
    check(
        personal.starts_with("0x") && personal.len() == 132,
        "TRON personal signature format changed",
    )?;
    let transaction = session
        .sign_tron_transaction(&account, "616263")
        .map_err(|e| e.to_string())?;
    check(
        transaction == tron::sign_tron_transaction(&evm_key, "616263")?,
        "TRON digest/signature differs",
    )?;
    session.lock();
    check(
        session.sign_tron_transaction(&account, "616263").is_err(),
        "Locked TRON account accepted signing",
    )?;
    println!("PASS TRON: message format, raw transaction digest/signature, vault, lock");
    bitcoin_self_test()?;
    println!(
        "PASS independent Rust host: no Flutter, FRB, backend or platform keystore dependencies"
    );
    Ok(())
}

fn main() -> ExitCode {
    if std::env::args().nth(1).as_deref() != Some("--self-test") {
        println!("Usage: owllet-core-smoke --self-test\nRuns public offline fixtures only. Never send funds to fixture accounts.");
        return ExitCode::SUCCESS;
    }
    match self_test() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("FAIL: {error}");
            ExitCode::FAILURE
        }
    }
}

fn bitcoin_self_test() -> Result<(), String> {
    use owllet_core::{
        bitcoin_vault::*,
        transactions::{bitcoin::*, bitcoin_psbt::*, bitcoin_signing::*},
        *,
    };
    let seed=mnemonic_to_seed("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")?;
    for purpose in [BitcoinAccountPurpose::Bip84, BitcoinAccountPurpose::Bip86] {
        let account = derive_bitcoin_account(&seed, BitcoinNetwork::Mainnet, 0, purpose)?;
        let secret = derive_bitcoin_account_xprv_from_seed(&seed, account.network, 0, purpose)?;
        let receive = derive_bitcoin_address_from_account(
            &account,
            account.network,
            BitcoinKeychain::External,
            0,
        )?;
        let change = derive_bitcoin_address_from_account(
            &account,
            account.network,
            BitcoinKeychain::Internal,
            0,
        )?;
        check(receive != change, "Bitcoin receive/change scope differs")?;
        check(
            receive
                == if purpose == BitcoinAccountPurpose::Bip84 {
                    "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
                } else {
                    "bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr"
                },
            "Bitcoin official address mismatch",
        )?;
        let utxo = BitcoinUtxo {
            txid: "11".repeat(32),
            vout: 0,
            value_sat: 100_000,
            script_pubkey_hex: derive_bitcoin_script_pubkey_from_account(
                &account,
                account.network,
                BitcoinKeychain::External,
                0,
            )?,
            keychain: BitcoinKeychain::External,
            address_index: 0,
        };
        let recipient = BitcoinRecipient {
            address: derive_bitcoin_address_from_account(
                &account,
                account.network,
                BitcoinKeychain::External,
                1,
            )?,
            amount_sat: 50_000,
        };
        let plan =
            plan_bitcoin_transaction(account.network, &account, &[utxo], &[recipient], 2, 0, true)?;
        let signed = sign_bitcoin_transaction(&plan, &secret)?;
        check(
            signed == verify_signed_bitcoin_transaction(&plan, &signed.raw_transaction_hex)?,
            "Bitcoin signature verification mismatch",
        )?;
        let psbt = create_bitcoin_psbt(&plan)?;
        let final_psbt = finalize_bitcoin_psbt(&sign_bitcoin_psbt(&account, &secret, &psbt)?)?;
        check(
            final_psbt.complete
                && final_psbt.raw_transaction_hex.as_deref() == Some(&signed.raw_transaction_hex),
            "Bitcoin PSBT/direct signing mismatch",
        )?;
        let record = seal_bitcoin_account_vault(
            &account,
            &secret,
            &[42; 32],
            &[purpose.number() as u8; 12],
        )?;
        let (mut session, handle) = open_bitcoin_account_vault(&account, &record, &[42; 32])?;
        check(
            session.sign_transaction(&handle, &plan)? == signed,
            "Bitcoin custody signature mismatch",
        )?;
        check(
            finalize_bitcoin_psbt(&session.sign_psbt(&handle, &psbt)?)?.complete,
            "Bitcoin custody PSBT incomplete",
        )?;
        session.lock();
        check(
            session.sign_transaction(&handle, &plan).is_err(),
            "Bitcoin locked session signed",
        )?;
        println!(
            "PASS Bitcoin {:?}: XPUB receive/change, plan, verified signing, PSBT, vault and lock",
            purpose
        );
    }
    Ok(())
}
