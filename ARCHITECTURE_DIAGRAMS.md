# GFGPay - Architecture Diagrams

## 1. High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GFGPAY ECOSYSTEM                                │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
    │  Mobile App │      │   Web App   │      │  Third-Party│
    │   (React    │      │   (React)   │      │    APIs     │
    │   Native)   │      │             │      │             │
    └──────┬──────┘      └──────┬──────┘      └──────┬──────┘
           │                    │                    │
           └────────────────────┼────────────────────┘
                                │
                        ┌───────▼───────┐
                        │  HTTPS/TLS    │
                        │  Load Balancer│
                        └───────┬───────┘
                                │
          ┌─────────────────────┼─────────────────────┐
          │                     │                     │
    ┌─────▼─────┐        ┌─────▼─────┐        ┌─────▼─────┐
    │  Server 1 │        │  Server 2 │        │  Server 3 │
    │  (Node.js)│        │  (Node.js)│        │  (Node.js)│
    └─────┬─────┘        └─────┬─────┘        └─────┬─────┘
          │                    │                    │
          └────────────────────┼────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │   MongoDB Cluster   │
                    │  ┌───────────────┐  │
                    │  │    Primary    │  │
                    │  └───────┬───────┘  │
                    │          │          │
                    │  ┌───────┴───────┐  │
                    │  │   Secondary   │  │
                    │  │   Replicas    │  │
                    │  └───────────────┘  │
                    └─────────────────────┘
```

---

## 2. Request Processing Pipeline

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         REQUEST PROCESSING PIPELINE                           │
└──────────────────────────────────────────────────────────────────────────────┘

  Incoming Request
        │
        ▼
┌───────────────────┐
│      Helmet       │ ──▶ Security headers (XSS, MIME sniffing, etc.)
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│       CORS        │ ──▶ Cross-origin access control
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│      Morgan       │ ──▶ HTTP request logging
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│   Body Parser     │ ──▶ JSON/URL-encoded parsing
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│  Mongo Sanitize   │ ──▶ NoSQL injection prevention
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│   Rate Limiter    │ ──▶ Request throttling
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│      Router       │ ──▶ Route matching
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│   Authenticate    │ ──▶ JWT verification
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│    Idempotency    │ ──▶ Duplicate check (for payments)
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│    Validation     │ ──▶ Joi schema validation
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│   PIN Verify      │ ──▶ Transaction PIN check (for transfers)
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│    Controller     │ ──▶ Request handling
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│     Service       │ ──▶ Business logic
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│      Model        │ ──▶ Database operations
└─────────┬─────────┘
          │
          ▼
     Response
```

---

## 3. Money Transfer Transaction Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    MONEY TRANSFER - TRANSACTION FLOW                          │
└──────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────┐
                    │         TRANSFER REQUEST         │
                    │   Sender → ₹500 → Receiver       │
                    └───────────────┬─────────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │     1. VALIDATION PHASE        │
                    │  ┌─────────────────────────┐  │
                    │  │ • Check idempotency key │  │
                    │  │ • Verify JWT token      │  │
                    │  │ • Verify transaction PIN│  │
                    │  │ • Validate input data   │  │
                    │  └─────────────────────────┘  │
                    └───────────────┬───────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │     2. PRE-TRANSFER CHECKS     │
                    │  ┌─────────────────────────┐  │
                    │  │ • Sender wallet active? │  │
                    │  │ • Sufficient balance?   │  │
                    │  │ • Daily limit ok?       │  │
                    │  │ • Receiver exists?      │  │
                    │  │ • Receiver wallet ok?   │  │
                    │  └─────────────────────────┘  │
                    └───────────────┬───────────────┘
                                    │
          ┌─────────────────────────▼─────────────────────────┐
          │              3. DATABASE TRANSACTION               │
          │  ┌─────────────────────────────────────────────┐  │
          │  │         START TRANSACTION (Session)         │  │
          │  └─────────────────────────────────────────────┘  │
          │                         │                         │
          │         ┌───────────────┴───────────────┐         │
          │         ▼                               ▼         │
          │  ┌─────────────────┐           ┌─────────────────┐│
          │  │  DEBIT SENDER   │           │ CREDIT RECEIVER ││
          │  │                 │           │                 ││
          │  │ balance: 1000   │           │ balance: 500    ││
          │  │ version: 5      │           │ version: 3      ││
          │  │       ↓         │           │       ↓         ││
          │  │ balance: 500    │           │ balance: 1000   ││
          │  │ version: 6      │           │ version: 4      ││
          │  └─────────────────┘           └─────────────────┘│
          │                         │                         │
          │  ┌─────────────────────────────────────────────┐  │
          │  │           CREATE TRANSACTION RECORD          │  │
          │  │  • referenceId: GFG123ABC                    │  │
          │  │  • status: completed                         │  │
          │  │  • balanceAfterSender: 500                   │  │
          │  │  • balanceAfterReceiver: 1000                │  │
          │  └─────────────────────────────────────────────┘  │
          │                         │                         │
          │  ┌─────────────────────────────────────────────┐  │
          │  │              COMMIT TRANSACTION              │  │
          │  └─────────────────────────────────────────────┘  │
          └─────────────────────────┬─────────────────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │        4. RESPONSE             │
                    │  ┌─────────────────────────┐  │
                    │  │ • Transaction ID        │  │
                    │  │ • Reference ID          │  │
                    │  │ • Amount transferred    │  │
                    │  │ • New balance           │  │
                    │  │ • Timestamp             │  │
                    │  └─────────────────────────┘  │
                    └───────────────────────────────┘
```

---

## 4. Optimistic Locking Mechanism

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        OPTIMISTIC LOCKING FLOW                                │
└──────────────────────────────────────────────────────────────────────────────┘

 Without Locking (PROBLEM):
 ═══════════════════════════

   Request A                    Database                    Request B
       │                           │                           │
       │     Read balance=1000     │     Read balance=1000     │
       │◄──────────────────────────│──────────────────────────►│
       │                           │                           │
       │    Debit 800 (thinks      │    Debit 800 (thinks      │
       │    balance is 1000)       │    balance is 1000)       │
       │──────────────────────────►│◄──────────────────────────│
       │                           │                           │
       │                    Final Balance = -600 😱             │
       │                           │                           │


 With Optimistic Locking (SOLUTION):
 ════════════════════════════════════

   Request A                    Database                    Request B
       │                           │                           │
       │  Read: balance=1000       │  Read: balance=1000       │
       │        version=1          │        version=1          │
       │◄──────────────────────────│──────────────────────────►│
       │                           │                           │
       │  Update WHERE version=1   │                           │
       │  SET balance=200, v=2     │                           │
       │──────────────────────────►│                           │
       │                           │                           │
       │       SUCCESS ✅           │                           │
       │◄──────────────────────────│                           │
       │                           │                           │
       │                           │  Update WHERE version=1   │
       │                           │  (but version is now 2!)  │
       │                           │◄──────────────────────────│
       │                           │                           │
       │                           │       FAIL ❌              │
       │                           │──────────────────────────►│
       │                           │                           │
       │                           │  Request B must RETRY     │
       │                           │  with fresh data          │
       │                           │                           │
```

---

## 5. Idempotency Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           IDEMPOTENCY MECHANISM                               │
└──────────────────────────────────────────────────────────────────────────────┘

 First Request:
 ══════════════

   Client                         Server                      Database
      │                              │                            │
      │  POST /transfer              │                            │
      │  Idempotency-Key: ABC123     │                            │
      │─────────────────────────────►│                            │
      │                              │                            │
      │                              │  Check: Key ABC123 exists? │
      │                              │───────────────────────────►│
      │                              │◄───────────────────────────│
      │                              │  No, doesn't exist         │
      │                              │                            │
      │                              │  Process transfer...       │
      │                              │───────────────────────────►│
      │                              │◄───────────────────────────│
      │                              │                            │
      │  Response: Success           │  Store key with result     │
      │  TransactionId: TXN456       │───────────────────────────►│
      │◄─────────────────────────────│                            │
      │                              │                            │


 Duplicate Request (Network Retry):
 ═══════════════════════════════════

   Client                         Server                      Database
      │                              │                            │
      │  POST /transfer              │                            │
      │  Idempotency-Key: ABC123     │  (Same key!)               │
      │─────────────────────────────►│                            │
      │                              │                            │
      │                              │  Check: Key ABC123 exists? │
      │                              │───────────────────────────►│
      │                              │◄───────────────────────────│
      │                              │  YES! Found previous result│
      │                              │                            │
      │  Response: Success           │  Return cached result      │
      │  TransactionId: TXN456       │  (Same as before!)         │
      │  idempotent: true            │                            │
      │◄─────────────────────────────│                            │
      │                              │                            │
      │  Money NOT deducted twice! ✅ │                            │
      │                              │                            │
```

---

## 6. Transaction State Machine

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        TRANSACTION STATE MACHINE                              │
└──────────────────────────────────────────────────────────────────────────────┘

                              ┌───────────┐
                              │  PENDING  │
                              │           │
                              │ (Created, │
                              │ not yet   │
                              │ processed)│
                              └─────┬─────┘
                                    │
                          Start Processing
                                    │
                                    ▼
                            ┌───────────────┐
                            │  PROCESSING   │
                            │               │
                            │ (Debit/Credit │
                            │  in progress) │
                            └───────┬───────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
               Success          Failure        Timeout
                    │               │               │
                    ▼               ▼               ▼
            ┌───────────┐   ┌───────────┐   ┌───────────┐
            │ COMPLETED │   │  FAILED   │   │  FAILED   │
            │           │   │           │   │           │
            │ (Success! │   │(Rollback  │   │ (Auto     │
            │  Final)   │   │ happened) │   │  retry)   │
            └─────┬─────┘   └───────────┘   └───────────┘
                  │
            Admin Refund
                  │
                  ▼
            ┌───────────┐
            │ REVERSED  │
            │           │
            │ (Refunded │
            │  to user) │
            └───────────┘


 State Descriptions:
 ════════════════════

 PENDING     → Transaction created, waiting to start
 PROCESSING  → Money movement in progress
 COMPLETED   → Successfully finished (final state)
 FAILED      → Error occurred, money returned to sender
 REVERSED    → Admin-initiated refund after completion
 CANCELLED   → User cancelled before processing
```

---

## 7. Data Model Relationships

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          DATA MODEL RELATIONSHIPS                             │
└──────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────┐
    │                          USER                                │
    │  ┌────────────────────────────────────────────────────────┐ │
    │  │ _id: ObjectId                                          │ │
    │  │ firstName: String                                      │ │
    │  │ lastName: String                                       │ │
    │  │ email: String (unique)                                 │ │
    │  │ phoneNumber: String (unique)                           │ │
    │  │ password: String (hashed)                              │ │
    │  │ pin: String (hashed)                                   │ │
    │  │ upiId: String (unique, auto-generated)                 │ │
    │  │ kycStatus: enum                                        │ │
    │  └────────────────────────────────────────────────────────┘ │
    └─────────────────────────────┬───────────────────────────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
                    ▼             │             ▼
    ┌───────────────────────┐    │    ┌───────────────────────┐
    │        WALLET         │    │    │     BANK_ACCOUNT      │
    │  ┌─────────────────┐  │    │    │  ┌─────────────────┐  │
    │  │ _id: ObjectId   │  │    │    │  │ _id: ObjectId   │  │
    │  │ user: ref(User) │◄─┼────┼───►│  │ user: ref(User) │  │
    │  │ balance: Number │  │    │    │  │ bankName: String│  │
    │  │ currency: String│  │    │    │  │ accountNumber   │  │
    │  │ version: Number │  │    │    │  │ ifscCode: String│  │
    │  │ dailySpent      │  │    │    │  │ isPrimary: Bool │  │
    │  │ totalReceived   │  │    │    │  └─────────────────┘  │
    │  │ totalSent       │  │    │    └───────────────────────┘
    │  │ isLocked: Bool  │  │    │
    │  └─────────────────┘  │    │
    └───────────┬───────────┘    │
                │                │
                │                │
                ▼                ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                      TRANSACTION                             │
    │  ┌────────────────────────────────────────────────────────┐ │
    │  │ _id: ObjectId                                          │ │
    │  │ referenceId: String (unique, GFG + timestamp + random) │ │
    │  │ type: enum (transfer, deposit, withdrawal, refund)     │ │
    │  │ sender: ref(User)                                      │ │
    │  │ senderWallet: ref(Wallet)                              │ │
    │  │ receiver: ref(User)                                    │ │
    │  │ receiverWallet: ref(Wallet)                            │ │
    │  │ amount: Number                                         │ │
    │  │ status: enum (pending, processing, completed, failed)  │ │
    │  │ idempotencyKey: String (unique, sparse)                │ │
    │  │ balanceAfterSender: Number                             │ │
    │  │ balanceAfterReceiver: Number                           │ │
    │  │ metadata: {                                            │ │
    │  │   senderUpiId, receiverUpiId, failureReason, etc.     │ │
    │  │ }                                                      │ │
    │  │ completedAt: Date                                      │ │
    │  │ failedAt: Date                                         │ │
    │  └────────────────────────────────────────────────────────┘ │
    └─────────────────────────────────────────────────────────────┘
```

---

## 8. Security Layers

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           SECURITY LAYERS                                     │
└──────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────────────────┐
    │ LAYER 1: NETWORK SECURITY                                                │
    │ ┌─────────────────────────────────────────────────────────────────────┐ │
    │ │  • HTTPS/TLS encryption                                             │ │
    │ │  • Helmet security headers                                          │ │
    │ │  • CORS restrictions                                                │ │
    │ └─────────────────────────────────────────────────────────────────────┘ │
    └─────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
    ┌─────────────────────────────────────────────────────────────────────────┐
    │ LAYER 2: RATE LIMITING                                                   │
    │ ┌─────────────────────────────────────────────────────────────────────┐ │
    │ │  • General: 100 req/15min                                           │ │
    │ │  • Auth: 10 req/15min                                               │ │
    │ │  • Payment: 10 req/min                                              │ │
    │ │  • Transfer: 5 req/min                                              │ │
    │ └─────────────────────────────────────────────────────────────────────┘ │
    └─────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
    ┌─────────────────────────────────────────────────────────────────────────┐
    │ LAYER 3: AUTHENTICATION                                                  │
    │ ┌─────────────────────────────────────────────────────────────────────┐ │
    │ │  • JWT Access Token (30 min expiry)                                 │ │
    │ │  • JWT Refresh Token (30 day expiry)                                │ │
    │ │  • Token stored server-side for revocation                          │ │
    │ └─────────────────────────────────────────────────────────────────────┘ │
    └─────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
    ┌─────────────────────────────────────────────────────────────────────────┐
    │ LAYER 4: AUTHORIZATION (for financial operations)                        │
    │ ┌─────────────────────────────────────────────────────────────────────┐ │
    │ │  • Transaction PIN verification                                     │ │
    │ │  • Wallet status check (active, not locked)                         │ │
    │ │  • KYC status for high-value transactions                           │ │
    │ └─────────────────────────────────────────────────────────────────────┘ │
    └─────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
    ┌─────────────────────────────────────────────────────────────────────────┐
    │ LAYER 5: INPUT VALIDATION                                                │
    │ ┌─────────────────────────────────────────────────────────────────────┐ │
    │ │  • Joi schema validation                                            │ │
    │ │  • MongoDB sanitization (NoSQL injection)                           │ │
    │ │  • Amount limits (min: ₹1, max: ₹100,000)                           │ │
    │ │  • Daily transfer limit (₹200,000)                                  │ │
    │ └─────────────────────────────────────────────────────────────────────┘ │
    └─────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
    ┌─────────────────────────────────────────────────────────────────────────┐
    │ LAYER 6: DATA PROTECTION                                                 │
    │ ┌─────────────────────────────────────────────────────────────────────┐ │
    │ │  • Passwords hashed with bcrypt (10 rounds)                         │ │
    │ │  • PINs hashed with bcrypt                                          │ │
    │ │  • Sensitive fields excluded from JSON responses                    │ │
    │ │  • Bank account numbers masked in responses                         │ │
    │ └─────────────────────────────────────────────────────────────────────┘ │
    └─────────────────────────────────────────────────────────────────────────┘
```

---

## 9. Error Handling Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          ERROR HANDLING FLOW                                  │
└──────────────────────────────────────────────────────────────────────────────┘

    Error Occurs
         │
         ▼
    ┌────────────────────────────────────────────────────────────┐
    │                   ERROR CONVERTER                           │
    │  ┌──────────────────────────────────────────────────────┐  │
    │  │  Convert all errors to ApiError format:              │  │
    │  │                                                      │  │
    │  │  Mongoose ValidationError → 400 Bad Request          │  │
    │  │  Mongoose CastError → 400 Bad Request                │  │
    │  │  Duplicate Key (11000) → 409 Conflict                │  │
    │  │  JWT Error → 401 Unauthorized                        │  │
    │  │  Unknown → 500 Internal Server Error                 │  │
    │  └──────────────────────────────────────────────────────┘  │
    └────────────────────────────────┬───────────────────────────┘
                                     │
                                     ▼
    ┌────────────────────────────────────────────────────────────┐
    │                    ERROR HANDLER                            │
    │  ┌──────────────────────────────────────────────────────┐  │
    │  │  1. Log error (Winston)                              │  │
    │  │     - Error message                                  │  │
    │  │     - Stack trace                                    │  │
    │  │     - Request URL, method, IP                        │  │
    │  │     - User ID (if authenticated)                     │  │
    │  │                                                      │  │
    │  │  2. Format response                                  │  │
    │  │     Development: Include stack trace                 │  │
    │  │     Production: Hide internal details                │  │
    │  │                                                      │  │
    │  │  3. Send response                                    │  │
    │  │     {                                                │  │
    │  │       success: false,                                │  │
    │  │       message: "User-friendly error message",        │  │
    │  │       errors: [...] // validation errors             │  │
    │  │     }                                                │  │
    │  └──────────────────────────────────────────────────────┘  │
    └────────────────────────────────────────────────────────────┘
```

---

## 10. Daily Limit Management

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        DAILY LIMIT MANAGEMENT                                 │
└──────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────┐
    │                     WALLET SCHEMA                            │
    │  dailySpent: Number        (Amount spent today)             │
    │  dailySpentDate: Date      (When dailySpent was last reset) │
    │  dailyLimit: ₹200,000      (Maximum per day)                │
    └─────────────────────────────────────────────────────────────┘

    Transfer Request: ₹50,000
           │
           ▼
    ┌──────────────────────────────────────────────┐
    │  Is dailySpentDate = Today?                  │
    └──────────────────┬───────────────────────────┘
                       │
           ┌───────────┴───────────┐
           │                       │
          YES                     NO
           │                       │
           ▼                       ▼
    ┌─────────────────┐    ┌─────────────────────┐
    │ Use current     │    │ Reset dailySpent = 0 │
    │ dailySpent      │    │ dailySpentDate = now │
    │ value           │    └──────────┬──────────┘
    └────────┬────────┘               │
             │                        │
             └───────────┬────────────┘
                         │
                         ▼
    ┌──────────────────────────────────────────────┐
    │  dailySpent + transferAmount <= dailyLimit?  │
    └──────────────────┬───────────────────────────┘
                       │
           ┌───────────┴───────────┐
           │                       │
          YES                     NO
           │                       │
           ▼                       ▼
    ┌─────────────────┐    ┌─────────────────────┐
    │ ALLOW TRANSFER  │    │ REJECT: Daily limit │
    │                 │    │ exceeded            │
    │ Update:         │    │                     │
    │ dailySpent +=   │    │ Show remaining      │
    │ transferAmount  │    │ limit to user       │
    └─────────────────┘    └─────────────────────┘
```

This comprehensive documentation covers all the unique concepts in GFGPay!
