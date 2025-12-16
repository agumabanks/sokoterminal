# Soko Seller Terminal Improvement Plan

## Overview
This document outlines a comprehensive improvement strategy for the **Soko Seller Terminal** (`@app/soko_seller_terminal`), based on a thorough analysis of the Laravel Backend capabilities and the current Flutter application structure.

The goal is to bridge the feature gap between the robust Backend API and the Terminal App, ensuring a premium, "DHL-grade" experience for sellers.

## 1. Current State Analysis  

### Backend Capabilities (Laravel API V2)
The backend exposes a rich set of features via `routes/api_seller.php`, including:
- **Core Commerce**: Orders (List, Details, Status Updates), Products (CRUD, Attributes, Colors).
- **Specialized Commerce**: **Auctions**, **Wholesale Products**, **Digital Products**.
- **Financials**: Withdraw Requests, Payment History, Commission Logs, Refunds.
- **Marketing**: **Coupons** Management, Flash Deals.
- **Engagement**: **Conversations** (Chat with customers), Product Queries, Reviews.
- **POS**: Dedicated POS endpoints (Customers, Cart, Shipping, Configuration).
- **Settings**: Shop Profile, Verification, Package Management.

### Frontend Status (Flutter App)
The application is built with **Flutter**, using **Riverpod** for state management and **GoRouter** for navigation. The structure is feature-based (`lib/src/features`), which is excellent.
**Existing Features:**
- Authentication
- Dashboard
- Items (Products)
- Orders
- Checkout (POS-like)
- Payments
- Customers
- Reports

## 2. Gap Analysis & Missing Features

The following features exist in the Backend but appear to be **missing or under-implemented** in the Terminal App:

### 🚨 Critical Gaps (High Priority)
1.  **Auctions & Bidding**: 
    -   *Backend*: `SellerAuctionProductController`.
    -   *App*: No dedicated generic `auctions` feature found. Sellers cannot manage auction products or view bids.
2.  **Conversations (Chat)**:
    -   *Backend*: `ConversationController` (Messaging with customers).
    -   *App*: No `chat` or `conversations` feature found. This is vital for customer engagement.
3.  **Wholesale & Digital Products**:
    -   *Backend*: `WholesaleProductController`, `DigitalProductController`.
    -   *App*: `items` feature seems generic. Needs specialized flows for creating/managing wholesale visibility and digital file uploads.
4.  **Coupons & Marketing**:
    -   *Backend*: `CouponController`.
    -   *App*: No interface for sellers to create or manage coupons/discounts.

### ⚠️ Functional Enhancements (Medium Priority)
5.  **Refund Management**:
    -   *Backend*: `RefundController` (Approve/Reject).
    -   *App*: Likely handled in `orders` but deserves a dedicated "Refund Requests" view for clarity.
6.  **Shop Verification & Packages**:
    -   *Backend*: `ShopController@getVerifyForm`, `SellerPackageController`.
    -   *App*: Need to ensure sellers can upgrade their subscription/packages and verify their shop identity directly from the app.

## 3. Improvement Suggestions

### A. dedicated POS Mode
While `checkout` exists, a true **POS Terminal Mode** should be emphasized:
-   **UI**: Landscape-optimized layout.
-   **Features**: 
    -   "Hold Order" / "Park Sale" functionality.
    -   Fast Barcode Scanning (using `mobile_scanner`).
    -   Offline syncing queue (ensure `drift` database is fully utilized for robust offline transactions).
    -   Thermal Receipt Printing (using `blue_thermal_printer`).
    -   Cash Drawer integration.

### B. "Auctions" Module Implementation
Create a new feature module `lib/src/features/auctions`:
-   **List View**: Active auctions, bid counts, time remaining.
-   **Detail View**: Real-time bid updates, ability to cancel bids or end auction early.
-   **Create Flow**: Specialized form for Start Price, Reserve Price, End Date.

### C. "Communications" Hub 
Create `lib/src/features/chat`:
-   Unified inbox for **Customer Chats**, **Product Queries**, and **System Notifications**.
-   Push Notification integration (using `firebase_messaging`) to deep-link to specific chats.

### D. UI/UX Refinement ("Steve Jobs Standard")
-   **Glassmorphism**: Use `BackdropFilter` with subtle opacity for modals and overlays.
-   **Animations**: Implement `Hero` transitions for product images between list and detail views. Use `AnimatedSwitcher` for state changes.
-   **Typography**: Ensure high readability with a premium font family (e.g., Inter or SF Pro).
-   **Haptic Feedback**: Add subtle vibrations for successful scans or confirmed actions. 

## 4. Technical Roadmap  

1.  **Phase 1: Foundation & POS Hardening**
    -   Audit `drift` database schema to ensure it supports offline creation of Orders and Products.
    -   Implement strict Type-Safe API Clients for all `api_seller.php` endpoints.

2.  **Phase 2: Missing Modules**
    -   Implement **Coupons** (Simple CRUD).
    -   Implement **Chat** (WebSocket/Polling based).
    -   Implement **Auctions** (Complex UI).

3.  **Phase 3: Polish**
    -   Conduct "Pixel Perfect" review.
    -   Optimize image caching and list rendering performance.

## 5. Directory Structure Recommendation
Refactor `lib/src/features` to include:
```
lib/src/features/
  ├── auctions/         # [NEW]
  ├── chat/             # [NEW]
  ├── coupons/          # [NEW]
  ├── pos/              # Refactor 'checkout' into a full POS suite
  ├── wholesale/        # [NEW]
  └── ...
```

---
**Prepared by Antigravity**
