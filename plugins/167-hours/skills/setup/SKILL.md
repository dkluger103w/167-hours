---
name: setup
description: Sets up 167 Hours for a new person, from confirming they are in therapy to building their private database and filling in their profile. Use when the user says "set up 167 Hours", "get started", "install", "start setup", "I just added the plugin", or when any other 167 Hours skill finds the database missing.
---

# 167 Hours setup

Walk a brand-new person through setup. Many testers are not technical. Assume they have never heard of a database. Use plain words, keep every message short, and give ONE step at a time, waiting for them to say it's done before the next. Never show SQL, project IDs, or error dumps unless they ask. Never use em dashes.

Do as much as possible yourself with the Supabase tools so the person only has to click, not configure.

## Step 1: Welcome and the one rule

Say briefly what 167 Hours is: a place to talk through the week between therapy sessions, with the important parts saved privately and turned into a short summary for their therapist.

Then confirm two things, conversationally:

- **They are 18 or older.** If not, explain kindly that 167 Hours is for adults right now and stop setup.
- **They are currently seeing a therapist.** This is the one rule: 167 Hours supports therapy and never replaces it. Ask their therapist's name (first name or "Dr. Last name" is fine). If they don't have a therapist, explain the rule warmly, suggest that finding one is a great first step, and stop setup.

Also say once, plainly: 167 Hours is not a crisis service. In an emergency, call or text 988 or call 911.

## Step 2: Make sure Supabase is connected

Check whether Supabase tools are available (for example `list_projects`).

If they are available, say "Supabase is connected" and go straight to Step 3.

If they are not available, the person almost certainly already made a free Supabase account: the 167 Hours setup page (167hours.app/start) has them do that before they ever get here. **Do not tell them to go to supabase.com or sign up again.** Instead, one step at a time:

1. Tell them a Supabase card with a **Connect** button should appear in this chat (or has already). Ask them to click **Connect**. If no card appears, use the connector search to surface Supabase so they get the card.
2. If Supabase asks them to sign in, that's normal: sign in the same way they made their account (email and the password they saved, or Continue with Google).
3. On the "Authorize Claude" page, check the Organization is theirs, then click **Authorize Claude**.
4. Back in the chat, the card says **Connected** with a **Use** button. Click **Use**; that sends "Use Supabase for this" automatically, so there's nothing to type.

When they click Use or say it's connected, call `list_projects` to confirm before moving on. If the tools still aren't available after they click Use, ask them to start a brand-new chat (with Auto on) and send "set up 167 Hours" again; new connections sometimes only show up in new chats. As a last resort: in Claude, Settings, then Connectors, find Supabase, click Connect.

Only if they say they don't have a Supabase account at all, send them to the "Make a free Supabase account" step at 167hours.app/start, and tell them to come back here when it's done.

If they get stuck, ask what they see on screen and help from there.

## Step 3: Create their private database

1. Call `list_organizations`. If there is more than one, ask which to use; usually there is only one.
2. Call `list_projects`. If a project named `167-hours` already exists, use it and skip to step 4.
3. Otherwise create one. Call `get_cost` for a project in that organization and then `confirm_cost`; a free-tier project costs $0. If the cost is not $0, stop and tell the person: their free Supabase slots may be used up, and they should ask whoever invited them to test for help. Create the project with name `167-hours` in the region closest to them (`us-east-1` if unsure). Do not ask them for a database password; generate a long random one and don't display it. Explain it takes a minute or two to finish.
4. Poll `get_project` until the status is active (ACTIVE_HEALTHY). Keep the person posted with one short line, not each poll.

## Step 4: Build the tables

1. Check whether the tables already exist: `select to_regclass('public.entries') is not null as ready;`
2. If not ready, read `references/schema.sql` from this skill and apply it with `apply_migration`, name `initial_schema`. Apply the whole file as one migration.
3. If it fails, try once more. If it fails again, tell the person something went wrong on the database side and to send a screenshot to whoever invited them. Don't paste the error at them.

## Step 5: Create their account row

The chat works as an administrator, so create one owner record for this person. Check first:

```sql
select id from public.profiles limit 1;
```

If no row exists, create the owner (this also creates their profile automatically):

```sql
insert into auth.users (instance_id, id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated',
        'owner@167hours.local', '{"provider":"email","providers":["email"]}', '{}', now(), now())
returning id;
```

That id is their `user_id` for everything from now on. One person per database.

## Step 6: Fill in their profile

Ask, one at a time and conversationally:

- What they'd like to be called.
- Their time zone (offer a guess from what they've said; store an IANA name like `America/Chicago`).
- When their next therapy session is, and whether it's usually weekly. Store `next_session_at` as a timestamp in their time zone and `session_cycle_days` (7 for weekly, 14 for every other week).
- When they'd like their therapist's summary ready. Suggest the evening before the session (around 7 PM) as the default, since it gives them time to review it and gives their therapist time to read it. Store their answer in plain words in `report_timing` (for example "evening before, 7 PM" or "morning of, 9 AM"). Be honest about how this works: you can't send messages or notifications on your own, so say something like "Around then, just open your 167 Hours chat and say 'build my report.' If you're already chatting with me near that time, I'll bring it up." Suggest they set a phone reminder or calendar alert for that time. They always review it and send it themselves.

- Their therapist's email address, so the summary can be addressed to them. Optional: if they'd rather not share it, skip it.
- Last, and optional: whether they'd like to give you a name. Say something like "Some people like to give their 167 Hours companion a name. Totally optional; if not, I'm just 167 Hours." Store it in `companion_name` (null if they skip). Don't suggest names unless they ask.

Save with an `update public.profiles set display_name = ..., therapist_name = ..., therapist_email = ..., timezone = ..., next_session_at = ..., session_cycle_days = ..., report_timing = ..., companion_name = ... where id = '<user_id>';`

Before saving, make sure these columns exist (databases set up with an earlier version won't have them): `alter table public.profiles add column if not exists report_timing text, add column if not exists therapist_email text, add column if not exists companion_name text;`

## Step 6b: Email drafts (optional)

Ask which email they use (Gmail, Outlook, or something else). Explain: if they connect it, 167 Hours will put each summary into a ready-to-send **draft** addressed to their therapist. Nothing is ever sent automatically; they open the draft, look it over, and press send themselves.

- If they use Gmail or Outlook and want this, check whether that connector is available. If not, search the connector directory for it so a card appears in the chat.
- Read the card before giving instructions, and describe the button that is actually there:
  - If it says **Connected** with a **Use** button, it's already linked to a Google or Microsoft account. Ask them to click **Use**. Then check which email address it's connected to (for example, look up their own profile or address with the email tool) and say it back: "Your drafts will be saved in the inbox for name@example.com. Is that the email you want to use?" If it's the wrong account, tell them how to switch: in Claude, Settings, then Connectors, find Gmail (or Outlook), disconnect it, then connect again and pick the right account.
  - If it shows a **Connect** button, ask them to click **Connect**, sign in to the email account they want to use, and approve access. Then click **Use** when it appears. After that, confirm the address the same way.
- If they use something else, or would rather not connect email, that's fine: the report will give them text to copy and paste instead.

## Step 7: Safety plan (offer, don't push)

Say: therapists often help clients make a short safety plan for really hard moments. Ask whether they'd like to set one up now, later, or skip it. If now, follow the safety-plan skill. If they already have one from their therapist, offer to save it.

## Step 8: Show them how to use it

Finish with a short, friendly explanation:

- **This chat is now your journal.** Ask them to rename this chat "167 Hours" (or "167 Hours: [companion name]" if they chose one) and pin it, then come back to this same chat every time, on the phone or computer. Explain how: tap or click the chat's title (or the "..." menu) to rename it and pin it, so it stays at the top of the chat list. One chat, used over and over, means the journal is always on. Long chats are fine; Claude condenses older parts automatically.
- If they ever start a different chat by accident and want it saved, they can just say "save this to 167 Hours".
- Just talk. Type or use voice, any time, about anything. The important parts get saved quietly in the background.
- Say "keep that private" about anything they don't want in their therapist's summary.
- After a session, say "debrief my session" to capture what they covered.
- Before a session, say "build my report" to make their therapist's summary. They always see it before it goes anywhere, and they send it themselves.
- Their entries are stored in their own Supabase account, not in a shared database. The people building 167 Hours can't see them.

- **Use it on your phone.** It's their choice, but most people use the Claude phone app, and it's the easiest way to stay connected day to day. Get the free **Claude** app from the App Store or Google Play, sign in with this same Claude account, and the pinned 167 Hours chat is right there. Tapping the microphone to talk works great.
- Say "help" any time to see these instructions again.

Then close with one short line that hands it to them, without a question, for example: "That's it. Whenever something's on your mind, just come back to this chat and talk to me the way you normally would." Don't ask how their week has been or prompt them to start; they come to you when they want to.
