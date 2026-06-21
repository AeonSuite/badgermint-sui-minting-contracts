module certificate_nft_project::certificate_nft_project {
    use sui::object;
    use sui::object::UID;
    use sui::tx_context::TxContext;
    use sui::transfer;
    use sui::event;
    use sui::display;
    use sui::package;
    use std::string::String;

    /// Soulbound certificate with permanent image on Irys (Arweave-backed).
    ///
    /// `image_url` points at Irys gateway content (set in Display for SuiScan).
    /// **No `store` ability** — not tradable.
    public struct CertificateNft has key {
        id: UID,
        title: String,
        certificate_type: String,
        issuer: String,
        participant: String,
        web_page: String,
        issued_date: u64,
        expiry_date: u64,
        /// Permanent image URL (e.g. https://gateway.irys.xyz/{id}).
        image_url: String,
        /// Minimal JSON-LD bytes (UTF-8) including credentialDocumentUrl + documentHash.
        metadata: vector<u8>,
    }

    public struct CertificateNftMinted has copy, drop {
        object_id: object::ID,
        recipient: address,
    }

    public struct MintConfig has key, store {
        id: UID,
        mint_authority: address,
        paused: bool,
    }

    public struct AdminCap has key, store {
        id: UID,
    }

    /// One-time witness — consumed at publish to create `package::Publisher` (Display setup).
    public struct CERTIFICATE_NFT_PROJECT has drop {}

    const ENOT_MINT_AUTHORITY: u64 = 2;
    const EMINTING_PAUSED: u64 = 3;
    const EIMAGE_URL_EMPTY: u64 = 4;
    const EPUBLISHER_MISMATCH: u64 = 5;
    const EIMAGE_URL_TOO_LONG: u64 = 6;

    /// Max length for image_url string (explorer + gateway URLs).
    const MAX_IMAGE_URL_LEN: u64 = 512;

    fun init(otw: CERTIFICATE_NFT_PROJECT, ctx: &mut TxContext) {
        package::claim_and_keep(otw, ctx);
    }

    public fun init_mint_config(mint_authority: address, ctx: &mut TxContext) {
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

    public fun set_paused(_cap: &AdminCap, cfg: &mut MintConfig, paused: bool) {
        cfg.paused = paused;
    }

    public fun set_mint_authority(_cap: &AdminCap, cfg: &mut MintConfig, new_authority: address) {
        cfg.mint_authority = new_authority;
    }

    /// One-time: shared Display for SuiScan (image from on-chain `image_url` field).
    public entry fun setup_certificate_nft_display(
        publisher: &package::Publisher,
        ctx: &mut TxContext,
    ) {
        assert!(package::from_module<CertificateNft>(publisher), EPUBLISHER_MISMATCH);

        let keys = vector[
            std::string::utf8(b"name"),
            std::string::utf8(b"image"),
            std::string::utf8(b"thumbnail_url"),
            std::string::utf8(b"description"),
            std::string::utf8(b"link"),
        ];
        let values = vector[
            std::string::utf8(b"{title}"),
            std::string::utf8(b"{image_url}"),
            std::string::utf8(b"{image_url}"),
            std::string::utf8(b"{certificate_type}"),
            std::string::utf8(b"{web_page}"),
        ];

        let mut disp = display::new_with_fields<CertificateNft>(publisher, keys, values, ctx);
        display::update_version(&mut disp);
        transfer::public_share_object(disp);
    }

    /// Owner burn (must own the object).
    public fun burn_certificate_nft(cert: CertificateNft) {
        let CertificateNft {
            id,
            title: _,
            certificate_type: _,
            issuer: _,
            participant: _,
            web_page: _,
            issued_date: _,
            expiry_date: _,
            image_url: _,
            metadata: _,
        } = cert;
        object::delete(id);
    }

    /// Mint one soulbound certificate; image is stored on Irys, URL on chain.
    public entry fun mint_certificate_nft(
        cfg: &MintConfig,
        recipient: address,
        title: String,
        certificate_type: String,
        issuer_hash: String,
        participant_hash: String,
        web_page: String,
        issued_date: u64,
        expiry_date: u64,
        image_url: String,
        credential_document: vector<u8>,
        ctx: &mut TxContext,
    ) {
        assert!(!cfg.paused, EMINTING_PAUSED);
        assert!(sui::tx_context::sender(ctx) == cfg.mint_authority, ENOT_MINT_AUTHORITY);
        assert!(image_url.length() > 0, EIMAGE_URL_EMPTY);
        assert!((image_url.length() as u64) <= MAX_IMAGE_URL_LEN, EIMAGE_URL_TOO_LONG);

        let cert = CertificateNft {
            id: object::new(ctx),
            title,
            certificate_type,
            issuer: issuer_hash,
            participant: participant_hash,
            web_page,
            issued_date,
            expiry_date,
            image_url,
            metadata: credential_document,
        };

        let obj_id = object::uid_to_inner(&cert.id);
        event::emit(CertificateNftMinted { object_id: obj_id, recipient });
        transfer::transfer(cert, recipient);
    }
}
