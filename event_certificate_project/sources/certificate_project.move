module certificate_project::certificate_project {
    use sui::object;
    use sui::object::UID;
    use sui::tx_context::TxContext;
    use sui::transfer;
    use sui::event;
    use std::string::String;

    /// On-chain certificate object (v4).
    ///
    /// Privacy: only non-PII fields are surfaced as named struct fields.
    /// Rich credential JSON-LD is referenced from minimal `metadata` bytes
    /// (UTF-8 JSON with credentialDocumentUrl). Anything truly private should
    /// not be put on chain.
    /// Soulbound certificate object (v4). **No `store` ability** — not tradable.
    public struct Certificate has key {
        id: UID,
        /// Event title (explorer-friendly).
        title: String,
        /// Credential type label (explorer-friendly).
        certificate_type: String,
        /// Hashed issuer label (hex), to avoid doxxing in explorers.
        issuer: String,
        /// Hashed participant label (hex).
        participant: String,
        /// Validation page URL for this credential.
        web_page: String,
        issued_date: u64,
        expiry_date: u64,
        /// Minimal JSON-LD bytes (UTF-8) including credentialDocumentUrl + documentHash.
        metadata: vector<u8>,
    }

    /// Event emitted whenever a certificate is minted.
    public struct CertificateMinted has copy, drop {
        object_id: object::ID,
        recipient: address,
    }

    /// Configuration shared object controlling who may mint.
    public struct MintConfig has key, store {
        id: UID,
        /// Address allowed to call `mint_certificate` (configured at `init_mint_config`).
        mint_authority: address,
        /// Emergency pause switch controlled by the AdminCap holder.
        paused: bool,
    }

    /// Capability object that can manage `MintConfig`.
    public struct AdminCap has key, store {
        id: UID,
    }

    /// Errors
    const ENOT_MINT_AUTHORITY: u64 = 2;
    const EMINTING_PAUSED: u64 = 3;

    /// One-time initializer for v2+.
    ///
    /// Security model:
    /// - Only the `mint_authority` address may initialize config (so random users can’t
    ///   front-run init and set it wrong).
    /// - Returns an `AdminCap` which should be transferred to cold storage / Ledger.
    public fun init_mint_config(
        mint_authority: address,
        ctx: &mut TxContext
    ) {
        assert!(sui::tx_context::sender(ctx) == mint_authority, ENOT_MINT_AUTHORITY);

        let cfg = MintConfig {
            id: object::new(ctx),
            mint_authority,
            paused: false,
        };
        let cap = AdminCap { id: object::new(ctx) };

        transfer::share_object(cfg);
        transfer::public_transfer(cap, mint_authority);
    }

    /// Admin: pause or unpause minting.
    public fun set_paused(_cap: &AdminCap, cfg: &mut MintConfig, paused: bool) {
        cfg.paused = paused;
    }

    /// Admin: rotate mint authority (in case your event key changes).
    public fun set_mint_authority(_cap: &AdminCap, cfg: &mut MintConfig, new_authority: address) {
        cfg.mint_authority = new_authority;
    }

    /// Owner burn: delete a certificate object on-chain.
    ///
    /// Caller must own the object to pass it by value.
    public fun burn_certificate(cert: Certificate) {
        let Certificate {
            id,
            title: _,
            certificate_type: _,
            issuer: _,
            participant: _,
            web_page: _,
            issued_date: _,
            expiry_date: _,
            metadata: _,
        } = cert;
        object::delete(id);
    }

    /// Mint a certificate object and transfer it to `recipient`.
    ///
    /// Explorer-friendly fields:
    /// - `title`: event title
    /// - `certificate_type`: credential label
    /// - `issuer_hash`: SHA-256 hex of issuer label (caller computed)
    /// - `participant_hash`: SHA-256 hex of participant label (caller computed)
    /// - `web_page`: validation page URL
    /// - `issued_date` / `expiry_date`: unix seconds
    /// - `metadata`: minimal JSON-LD bytes (UTF-8)
    public entry fun mint_certificate(
        cfg: &MintConfig,
        recipient: address,
        title: String,
        certificate_type: String,
        issuer_hash: String,
        participant_hash: String,
        web_page: String,
        issued_date: u64,
        expiry_date: u64,
        credential_document: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(!cfg.paused, EMINTING_PAUSED);
        assert!(sui::tx_context::sender(ctx) == cfg.mint_authority, ENOT_MINT_AUTHORITY);

        let cert = Certificate {
            id: object::new(ctx),
            title,
            certificate_type,
            issuer: issuer_hash,
            participant: participant_hash,
            web_page,
            issued_date,
            expiry_date,
            metadata: credential_document,
        };

        let obj_id = object::uid_to_inner(&cert.id);
        event::emit(CertificateMinted { object_id: obj_id, recipient });
        transfer::transfer(cert, recipient);
    }
}
