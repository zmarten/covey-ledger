## app-flow-pages-and-roles.md

---

## Site Map (Top-Level Pages)

1. **Dashboard** – “Today in the Field”
2. **Harvest Entry Log**
3. **State Regulations**
4. **End-of-Day Split Tool**
5. **Freezer Inventory**
6. **Season & Trip History**
7. **Compliance Sentinel / Notifications** (optional)

---

## Purpose of Each Page

* **Dashboard** – Immediate overview: daily harvest, remaining limits, freezer totals.
* **Harvest Entry Log** – Record new harvests; triggers compliance checks.
* **State Regulations** – View and edit per-state daily/possession limits.
* **End-of-Day Split Tool** – Allocate harvested birds among hunters; update possession/freezer.
* **Freezer Inventory** – Track physical storage vs legal possession; adjust consumed or gifted birds.
* **Season & Trip History** – Review historical harvests by state/species/date; seasonal summaries.
* **Compliance Sentinel** – Alerts on approaching limits or freezer aging trends.

---

## User Roles & Access Levels

| Role                          | Access                                                                                                   |
| ----------------------------- | -------------------------------------------------------------------------------------------------------- |
| **Primary User**              | Full CRUD on harvest entries, freezer inventory, split tool, and regulations. Can see compliance alerts. |
| **Admin / Future Multi-User** | Manage users, view other hunters’ entries (read-only), configure shared trips.                           |

> MVP: single-user only, so all pages default to Primary User access.

---

## Primary User Journeys (3-Step Max Each)

### 1. Logging Harvest

1. Open **Harvest Entry Log**
2. Enter species, quantity, state, optional notes
3. Save → compliance engine confirms / blocks entry

### 2. Splitting End-of-Day Harvest

1. Open **End-of-Day Split Tool**
2. Enter number of hunters + select retained birds
3. Save → updates possession and freezer

### 3. Checking Daily Compliance

1. Open **Dashboard**
2. Review daily limits & possession totals per state
3. Take action (log, adjust freezer, split) as needed

### 4. Adjusting Freezer Inventory

1. Open **Freezer Inventory**
2. Mark consumed or gifted birds
3. Save → updates possession and totals

### 5. Reviewing Season / Trip History

1. Open **Season & Trip History**
2. Filter by state/species/date
3. Review totals and trends

### 6. Responding to Compliance Sentinel (Optional)

1. Open **Notifications / Sentinel**
2. View advisory (limit approaching, freezer aging)
3. Adjust actions (harvest, consume, gift) accordingly

---

All workflows adhere to **three-mindless-clicks rule**, making field use simple and reliable.

This completes the four foundational planning documents for **Covey Ledger**.

Next step: implement phase-by-phase using `implementation-plan.md` as the task guide.
