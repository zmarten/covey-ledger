# Covey validation plan

## Goal

Validate whether upland hunters want a field-to-freezer workflow strongly enough to join a waitlist, reply with real pain points, or test a rough build.

## Primary hypothesis

Upland hunters who already use Garmin/onX/paper notes have an unsolved post-hunt tracking problem: bird splits, freezer inventory, gifting/consumption, and practical possession-limit awareness are scattered or not tracked at all.

## First-week success metrics

Strong signal:

- 25+ waitlist signups from relevant hunting audiences
- 10+ qualitative replies describing current tracking pain
- 5+ hunters willing to test a rough workflow
- At least 3 people mention freezer inventory, party splits, or possession/compliance without being prompted

Weak signal:

- Signups come only from friends/non-hunters
- Replies focus only on mapping/scouting instead of post-hunt workflow
- Hunters say existing paper notes/spreadsheets are good enough

## Audience list

Start with manual, high-context outreach rather than broad posting.

1. Personal hunter network and guides
2. Garmin hunting/watch communities
3. Upland hunting forums/groups
4. onX/Garmin waypoint discussions where people mention messy exports or logs
5. State-specific upland groups: Montana, South Dakota, Kansas, North Dakota, Nebraska

## Interview questions

Ask after signup or in direct outreach:

1. How do you currently record what happened during a hunt?
2. Do you track birds after they are split, gifted, frozen, or eaten?
3. Have you ever worried about possession limits because of freezer inventory?
4. What tools do you already use: Garmin watch, Alpha/Astro, onX, paper, spreadsheet, notes app?
5. If Covey only did one thing well, should it be field capture, bird splitting, freezer inventory, exports, or limit context?
6. Would you use a rough test build if it required manual entry first?

## Experiment sequence

### Step 1 — Quiet smoke test

- Merge and deploy the landing page.
- Confirm `https://covey.zachmartens.com/` has no certificate warning.
- Submit one real waitlist test and confirm the Supabase row exists.
- Confirm duplicate email behaves like success.

### Step 2 — Direct outreach

- Send the DM draft to 10–20 known hunters.
- Ask for blunt feedback, not signups only.
- Track exact language used to describe pain points.

### Step 3 — Small community post

- Post in one relevant community with the feedback-first Reddit/forum draft.
- Avoid claiming a complete product.
- Reply to every useful comment with a follow-up question.

### Step 4 — Positioning decision

After 7 days, classify the strongest pull:

- Garmin-first field capture
- Freezer inventory
- Party split ledger
- Possession-limit confidence
- Exportable hunt record

Use that winner to define the first tester workflow.

## Tracking sheet columns

- Date
- Source/channel
- Name/handle
- State(s) hunted
- Tools used today
- Pain point quote
- Interested in testing? yes/no
- Which feature pulled them in?
- Follow-up needed

## Approval-required actions

These should be queued for Zach, not done autonomously under his identity:

- Posting to X/LinkedIn/GitHub as Zach
- Posting in communities where Zach is personally accountable
- Sending DMs from Zach's personal accounts
- Claiming official launch/availability
