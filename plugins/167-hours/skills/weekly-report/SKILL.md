---
name: weekly-report
description: Builds the short, structured summary of the person's week for their therapist in 167 Hours, reviewed by the person first and sent only by them. Use when the user says "build my report", "make my summary", "get ready for my session", "what should I bring to therapy", or "send my therapist an update".
---

# Weekly report for the therapist

Build a summary the therapist can read in about five minutes before the session. It reports what the person shared, in their words where possible. It is not a clinical assessment and never diagnoses or interprets. All clinical judgment stays with the therapist. Never use em dashes.

## Find the database

Use the Supabase tools: project named `167-hours`; `select id, display_name, therapist_name, timezone, next_session_at from public.profiles limit 1;`. Set `user_id` explicitly. If the database isn't there, offer to run setup.

## Pick the period

The period runs from the end of the last report (`select max(period_end) from public.session_summaries where user_id = ...`) to now. If there's no earlier report, start from the last session in `sessions`, or the last 7 days. Tell the person the date range in one line.

## Gather (never include private entries)

- `entries` in the period with `private = false`, ordered by `occurred_at`, with linked people and patterns.
- The most recent `sessions` row: its homework and takeaways.
- `tool_uses` in the period with tool names.
- Patterns linked to entries in the period.

## Report structure

Write it in this order and keep it tight. Omit any section with nothing in it.

1. **Header**: "Between-session summary for [therapist name]", the person's first name, the date range, and the date of the upcoming session.
2. **What [name] wants to talk about**: everything with `flag_for_session = true`, first and in their words.
3. **The week at a glance**: three to five plain bullets on what came up most. Descriptive, not interpretive ("Work stress came up on four days", not "shows signs of burnout").
4. **Timeline**: by day, with times, one line per meaningful entry. Trigger, thought, feeling and intensity, what they did, as available.
5. **Urges**: each urge, its strength, whether they acted on it, and what helped.
6. **Mood by time of day**: average intensity for morning (5 to 12), afternoon (12 to 17), evening (17 to 22), night (22 to 5), in their time zone, and counts by entry type.
7. **Sleep**: nights logged and hours.
8. **Patterns**: any linked this week, with status.
9. **Last session's homework**: what it was and anything they said about how it went.
10. **What helped**: tools used and how much they helped.
11. **Footer**: "Prepared by [name] with 167 Hours. This summary reflects what [name] chose to share between sessions. It is not a clinical record." Then the therapist feedback note from `references/feedback.md`.

Use their own words wherever possible. Don't soften or dramatize.

## Review with the person first

Show them the report in chat. Ask:

- Is there anything they want removed or kept private? (If so, mark those entries `private = true` and rebuild.)
- Anything missing they want added?

Only after they approve:

1. Save it:
   ```sql
   insert into public.session_summaries (user_id, period_start, period_end, title, content_md)
   values ('<user_id>', '<start>', '<end>', 'Between-session summary, <dates>', '<markdown>')
   returning id;
   ```
2. Make a clean, printable file for them to send. If you can create files, produce a PDF named like `Between-Session-Summary-Oct-20.pdf` with a simple, calm layout (generous margins, clear headings, no logos needed). If you can't create files, give the final version as clean formatted text they can copy into an email.
3. Offer a short, ready-to-send email they can paste, addressed to their therapist, saying the summary is attached and they're looking forward to the session.

The person always sends it themselves. Never email anyone directly unless they explicitly ask you to and an email tool is connected; even then, show the exact email first and wait for an OK.
