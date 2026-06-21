# Badgermint Sui Minting Contracts

Soulbound **event training certificates** on Sui for [Badgermint](https://badgermint.app).

This repository contains **Move source only**. Package IDs, mint configuration object IDs, and operator wallet addresses are managed in the private application deployment repo — not published here.

## Packages

| Directory | Module | Purpose |
|-----------|--------|---------|
| `event_certificate_project/` | `certificate_project` | Default **soulbound batch** mint (`mint_certificate`) — hashed issuer/participant, minimal JSON-LD bytes in `metadata` |
| `event_certificate_nft_project/` | `certificate_nft_project` | **On-chain image** soulbound mint (`mint_certificate_nft`) — permanent `image_url` for SuiScan Display |

Both certificate structs use `has key` only (no `store`) — non-transferable soulbound credentials.

## Build & test

Requires [Sui CLI](https://docs.sui.io/guides/developer/getting-started/sui-install) with Move 2024 edition.

```bash
cd event_certificate_project
sui move build
sui move test
```

Repeat for `event_certificate_nft_project/`.

## Publish

After `sui client publish`, record package and `MintConfig` object IDs in your **private** deployment configuration. Do not commit operator keys or production addresses to this public repository.

## Application stack

Backend, mint service, and frontend are not in this repo.
