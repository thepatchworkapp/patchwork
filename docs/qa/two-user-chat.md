# Two-User Chat QA Script

Manual/simulator coverage for Patchwork chat between two signed-in users.

## Prerequisites

- Two test accounts with known credentials:
  - User A: seeker account.
  - User B: tasker account with tasker mode enabled.
- A shared conversation already exists between User A and User B. Prefer a conversation with no accepted proposal for the proposal-status checks.
- Two devices or simulators can run the same build at the same time. If using one Mac, run one account on Simulator and the other on a physical device when possible.
- Both installs point at the same Convex deployment and are signed in before starting.
- Note each account name, device/simulator, app build, backend/deployment, and starting conversation id/name if available.

## Start State

1. On User A, open `Messages`, select the `Seeker` tab, and open the conversation with User B.
2. On User B, open `Messages`, select the `Tasker` tab, and open the same conversation with User A.
3. Confirm both chat headers show the opposite participant and the subtitle is `Direct messages` unless an accepted proposal already exists.
4. Confirm the composer placeholder is `Type a message...` and the `Propose terms` action is visible before any accepted proposal.

## Text Realtime Check

1. From User A, type a unique message such as `qa text A 2026-06-01 14:05` and tap `Send message`.
2. Confirm User A sees the message immediately and any `Sending...` state clears.
3. Without pulling to refresh or reopening, confirm User B sees the same text in the open conversation within a few seconds.
4. Reply from User B with a unique message.
5. Confirm User A receives the reply in the open conversation within a few seconds.
6. Return to the Messages list on each device and confirm the row preview and unread badge behavior match the latest message and current read state.

## Proposal Realtime Check

1. From User A, tap `Propose terms`.
2. Enter a flat or hourly rate, a valid future date/time, and a short unique note.
3. Tap `Send`.
4. Confirm User A sees a proposal card immediately with status `Pending`; if visible, `Sending...` clears.
5. Without refresh, confirm User B receives the proposal card with the same rate, date/time, note, and `Pending` status.
6. Confirm only User B, the receiver, sees the proposal actions: `Decline`, `Counter`, and `Accept`.

## Accept, Decline, And Counter Status Checks

Run these as separate passes when possible so each starts from a fresh pending proposal.

### Accept

1. On the receiver's device, tap `Accept` on a pending proposal.
2. Confirm both users see the same proposal update to `Accepted`.
3. Confirm the chat subtitle changes to `Active conversation`.
4. Confirm the `Job in progress` banner appears and the conversation row shows `Job linked`.
5. Confirm `Propose terms` is no longer shown after the proposal is accepted.

### Decline

1. Start from a fresh pending proposal.
2. On the receiver's device, tap `Decline`.
3. Confirm both users see the proposal status update to `Declined`.
4. Confirm the conversation remains usable for text messages.

### Counter

1. Start from a fresh pending proposal.
2. On the receiver's device, tap `Counter`.
3. Change the rate or note, then tap `Send Counter`.
4. Confirm both users see the original proposal update to `Countered`.
5. Confirm both users also see a new counter proposal card with status `Pending`.
6. Confirm only the new receiver can act on the counter proposal.

## Kill/Reopen Cache Check

1. With both devices on the same conversation, send one text message and one proposal or status update.
2. Force quit the app on User A's device.
3. Relaunch User A and open the same conversation.
4. Confirm previously loaded chat content paints quickly from local cache before any visible refresh.
5. Confirm the final visible thread still contains the latest text, proposal card, and proposal status after the refresh completes.
6. Repeat once for User B if the first pass was clean.

## Fetch-Only-Missing-Messages Check

1. Keep User A in the conversation and force quit User B.
2. From User A, send two unique messages while User B is closed.
3. Relaunch User B and open the same conversation.
4. Confirm older cached messages are still present immediately.
5. Confirm only the missing new messages append in chronological order after refresh; no duplicate messages or proposal cards appear.
6. From User B, send a reply and confirm User A receives it realtime without needing to reopen.

## Evidence To Record

- Build number, backend/deployment, date/time, account names, and device/simulator names.
- Screenshots or screen recordings for:
  - Both users in the same conversation.
  - User B receiving User A's text realtime.
  - Proposal card received realtime with `Pending` status and receiver actions.
  - `Accepted`, `Declined`, and `Countered` states, including the new pending counter proposal.
  - Reopen showing cached thread content followed by the current thread.
  - Missing messages appending without duplicates after reopen.
- Any error banners, delayed realtime updates, duplicate rows, stale statuses, or mismatched proposal details.

## Acceptance Criteria

- Two signed-in users can open the same conversation from the expected Messages role tab.
- Text messages appear locally immediately and on the other user's open conversation without manual refresh.
- Proposal cards appear realtime with matching rate, schedule, notes, status, and receiver-only actions.
- Accept, decline, and counter actions update both users' proposal status and system state consistently.
- Accepted proposals show active-job UI (`Active conversation`, `Job in progress`, and `Job linked`) and hide `Propose terms`.
- Killing and reopening preserves cached content and converges to the latest thread.
- Reopening after offline activity fetches only missing messages/status updates, maintains chronological order, and does not duplicate messages or proposals.

## Review Criteria

- Fail the run for missing realtime delivery, duplicate messages/proposals, stale proposal status, wrong receiver actions, missing active-job UI after accept, or lost cached content on reopen.
- Treat delivery over roughly 10 seconds as a delay to investigate even if it eventually succeeds.
- Record any tester workaround separately from the pass/fail result; do not count a flow as passed if it required pull-to-refresh, app restart, or changing tabs to update.
