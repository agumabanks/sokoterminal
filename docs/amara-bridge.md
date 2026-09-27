# Amara integration contract v1

Terminal source: `/var/www/soko/app/soko_seller_terminal`.
Amara source: `/var/www/cards.sanaa.ug/Sanaa-Agent`.
Soko backend source: `/var/www/soko/apps/backend-laravel`.
Amara's authenticated Soko projection: `/var/www/cards.sanaa.ug/app/Services/SokoReadRepository.php`.

Terminal owns `seller_terminal.db` in its Android application documents directory. Drift and Terminal's sync queue remain the only local write path. A filename is not a cross-app storage permission. Server projections may lag unsynced POS changes.

`content://com.soko24.soko_seller_terminal.amara/context` provides public protocol metadata: protocol version, package, database name, access model and media-exchange model. It contains no business rows, credentials, filesystem paths or database handles. It accepts only named projections, rejects SQL selection/sort arguments, and rejects insert/update/delete. Other paths are unsupported. This interface is discovery, not authorization to access shop data.

Amara queries discovery for its dashboard and operating context. Older Terminal releases return an update-needed state while the existing server integration continues working.

Business reads continue through `/api/agent/soko/{resource}?device_id=...` with Amara's registered bearer token. The server chooses the registered business scope; resource routes include listings, services, orders, messages and commerce. Never copy Terminal tokens or direct database credentials into Amara prompts. Current server facts, not discovery metadata, ground prices, stock, payment instructions and customer promises.

Prepared photos/videos can be exported to an owner-selected Android document tree and imported through Terminal. The tree is not Terminal's private data folder. Automatic media ingestion, unsynced inventory reads, listing writes and order creation are not implemented by protocol v1. Those require a separate authenticated, seller-scoped command contract with idempotency, business validation and receipts.

Build the release through Flutter after tests have finished: `flutter build apk --release --no-tree-shake-icons`. The existing ad editor uses dynamic icons. Do not run Flutter tests concurrently with Android release packaging: tests regenerate the development plugin registrant.

## Protocol v2: verified shop identity (September 13, 2026)

`/identity` is caller-restricted to co.sanaa.agent and exposes only a 180-second RSA-signed assertion from the full-seller authenticated `/api/v2/seller/amara/identity` endpoint. It contains seller/shop IDs, name, audience, issued/expiry timestamps; it contains no seller access token. Login transitions and failed refresh clear the assertion; generation checks discard late responses after logout. Offline POS remains available while Amara fails closed without fresh identity.

Amara verifies the assertion locally; Cards validates it independently and queries shop/seller IDs rather than registered business names. Cards records the latest observation separately. This is a narrow authenticated read-only projection, not a shop memory migration or permission to publish to any TikTok account. Signing private key is on the Soko server under storage/app/amara-identity; only its public key is deployed to Cards and Amara. Key rotation requires coordinating verifiers.
