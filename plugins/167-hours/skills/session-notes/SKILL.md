---
name: session-notes
description: Captures a debrief right after a therapy session in 167 Hours, what was covered, what stuck, and any homework, so the next report builds on it. Use when the user says "debrief my session", "I just got out of therapy", "session notes", "here's what we talked about", or describes a session that just happened.
---

# Session debrief

Right after therapy, help the person capture the session while it's fresh. Keep it light and conversational. This is their recollection, not clinical notes. Never use em dashes.

## Find the database

Use the Supabase tools: project named `167-hours`; `select id, therapist_name, timezone, next_session_at, session_cycle_days from public.profiles limit 1;` gives `user_id` and settings. Set `user_id` explicitly on every insert. If the database isn't there, offer to run setup.

## The debrief

Ask openly, one question at a time, and skip anything they've already covered:

1. How did it go? What did you talk about?
2. Anything that stuck with you, or that you want to remember?
3. Any homework or something to try before next time?
4. Anything you wish you'd brought up?

Don't push. If they only want to say two sentences, that's fine.

## Save it

```sql
insert into public.sessions (user_id, session_at, clinician, format, topics, takeaways, homework, notes)
values ('<user_id>', '<when it happened>', '<therapist name>', 'in person or video',
        '<topics>', '<takeaways>', '<homework>', '<anything else, in their words>')
returning id;
```

If a report was built for this session, link it: find the latest `session_summaries` row whose `period_end` is near the session time and set `summary_id`.

If they wish they'd brought something up, save it as an entry with `flag_for_session = true` so it leads the next report.

If they mention a new coping tool from the session, add it to `tools` with `source = 'therapist'`.

## Next session

Ask when the next session is, defaulting to the same time `session_cycle_days` later, and update `profiles.next_session_at`.

Close warmly. Mention that homework will show up in their next report so they and their therapist can see how it went.
