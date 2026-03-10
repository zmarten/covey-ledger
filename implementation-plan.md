## implementation-plan.md

---

## Build Philosophy

* Server owns compliance logic.
* UI surfaces numbers clearly.
* Every step is testable in isolation.
* No hidden math.

---

## Phase 0 — Foundation Setup (Week 1)

### 1. Project Initialization

* Create Vite + React + TypeScript app
* Install shadcn/ui
* Configure Tailwind with:

  * 8pt spacing scale
  * Color tokens (Olive, Burnt, Canvas, etc.)
* Establish base layout shell:

  * Header
  * Main content area
  * Notification region

Checkpoint:

* App loads.
* Design tokens applied.
* Global typography matches spec.

---

### 2. Auth (Single User)

* Implement email/password auth via Lovable Cloud
* Create:

  * Login page
  * Protected route wrapper
* Store user session securely

Checkpoint:

* User can sign up.
* User can log in.
* Session persists on refresh.

---

## Phase 1 — Core Data Model & Compliance Engine (Week 2)

### 3. Database Schema

Create collections/tables:

* Users
* States
* Species
* Regulations
* HarvestEntries
* Distributions
* Consumptions

Do NOT store possession as static value.

Checkpoint:

* CRUD working for each entity.
* Data visible in admin console.

---

### 4. Compliance Engine (Server-Side Only)

Build server function:

`validateHarvestEntry(userId, stateId, speciesId, quantity, date)`

Step 1 — Calculate daily total:

* Sum harvest entries for same date/state/species.

Step 2 — Calculate possession:

Total harvested (state/species)
– Distributed (state/species)
– Consumed (state/species)

Return:

* dailyRemaining
* possessionRemaining
* blocked (true/false)
* explanation string

Checkpoint:

* Unit tests:

  * Below limit → allowed
  * At limit → blocked
  * Multi-day possession math correct
  * Split + consume reduce possession correctly

---

## Phase 2 — Harvest Logging Flow (Week 3)

### 5. Dashboard (Read-Only First)

Build:

* Active state selector
* Today’s totals
* Remaining daily
* Remaining possession
* Freezer summary blocks

Use static data first.
Then wire to backend.

Checkpoint:

* Numbers update on page load.
* Warning color triggers at 80%.

---

### 6. Harvest Entry Form

Fields:

* Species dropdown
* Quantity input
* State dropdown (auto-filled from active state)
* Notes
* Save button

On Save:

1. Call compliance engine.
2. If blocked → show exact explanation.
3. If allowed → persist entry.
4. Return updated remaining counts.

Checkpoint:

* Attempting over-limit entry fails cleanly.
* Exact remaining capacity shown.
* No generic error messages.

---

## Phase 3 — Inventory & Split Logic (Week 4)

### 7. End-of-Day Split Tool

Build flow:

1. Query today’s harvest entries.
2. Enter number of hunters.
3. Adjust retained share.

Logic:

* Only retained quantity updates ledger.
* Distributed quantity stored separately.

Checkpoint:

* After split, possession recalculates correctly.
* Edge case: retained = 0 works.

---

### 8. Freezer Inventory Page

Build grouped table:

| Species | State | Possession | Freezer | Consumed | Net |

Actions:

* “Mark Consumed” modal
* “Gifted” transfer action

Each action triggers server recalculation.

Checkpoint:

* Consuming reduces possession.
* Gifting reduces possession.
* No negative states possible.

---

## Phase 4 — History & Reporting (Week 5)

### 9. Season & Trip History

Views:

* Filter by state
* Filter by date range
* Group by species

Show totals:

* Harvested
* Kept
* Distributed
* Consumed

Checkpoint:

* Seasonal totals match ledger math.
* Cross-check random state manually.

---

## Phase 5 — Compliance Sentinel (Optional, Week 6)

### 10. AI Monitoring Service

Scheduled job:

* Scan possession per state
* Detect >80% threshold
* Detect freezer aging > X days

Output:

* Advisory messages stored in notifications table.

Tone:

* Calm. Precise. No drama.

Checkpoint:

* Advisory triggers correctly.
* No duplicate alerts.

---

## Timeline Overview

| Week | Focus                       |
| ---- | --------------------------- |
| 1    | Setup + Auth                |
| 2    | Schema + Compliance Engine  |
| 3    | Dashboard + Harvest Logging |
| 4    | Split Tool + Inventory      |
| 5    | History + QA                |
| 6    | AI Sentinel (Optional)      |

---

## Team Roles

### You (Product Owner)

* Define regulation rules
* Validate math correctness
* Run weekly ledger audits

### Frontend Dev

* UI components
* Form handling
* State display logic

### Backend Dev

* Compliance engine
* Data integrity
* Audit logging

---

## Rituals

### Weekly: 30-Minute Ledger Audit

* Attempt illegal entry
* Cross-check possession math manually
* Validate one multi-day scenario

### Monthly: 3-User Usability Test

Ask:

* “Can you tell how many birds you can still shoot?”
* “Where would you log today’s birds?”
* “Do you trust these numbers?”

Log top 3 confusions. Fix first.

---

## Optional Integrations

* State wildlife regulation APIs
* Export to PDF compliance report
* CSV export for taxidermy or reporting
* Offline-first sync mode

---

If this looks solid, say **“Proceed”** and I’ll generate:

`design-guidelines.md`

This one will translate your rugged field-ledger vision into a precise visual and emotional system.
