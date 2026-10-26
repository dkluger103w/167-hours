---
name: safety-plan
description: Creates, shows, or updates the person's safety plan in 167 Hours, a short list for really hard moments with warning signs, things that help, reasons to keep going, people to reach, and the 988 crisis line. Use when the user says "safety plan", "show my safety plan", "I'm not doing well", "I'm in a dark place", or when the journal skill detects a crisis.
---

# Safety plan

A safety plan is something therapists build with clients ahead of time for moments when things get very bad. It's a short, personal list, kept where it's easy to find. Never use em dashes.

## If they are in crisis right now

Lead with the person, not the database. Be warm and direct. Show their saved plan if one exists, walk through it with them one part at a time, and make the crisis line clear: **call or text 988** (Suicide and Crisis Lifeline, US), or **911** if they are in immediate danger. Encourage them to reach a person on their contact list and their therapist. Don't build a new plan in the middle of a crisis; use what exists, plus 988.

## Find the database

Use the Supabase tools: project named `167-hours`; `select id from public.profiles limit 1;` gives `user_id`. Set it explicitly. If the database isn't there, still give 988 and 911, then offer setup later.

## Building or updating a plan

If their therapist already gave them a plan, offer to save that version as is.

Otherwise go one section at a time, gently, and let them skip any part:

1. **Warning signs**: thoughts, feelings, or situations that tell them things are sliding.
2. **Things I can do on my own**: what helps them calm down or get through it.
3. **Reasons to keep going**: people, pets, plans, anything that matters to them.
4. **People I can reach**: names and how to reach them (store as `[{"name": "...", "how": "..."}]`).
5. **Professionals**: their therapist and any other provider, with how to reach them.

Save:

```sql
insert into public.safety_plans (user_id, warning_signs, coping_steps, reasons, contacts, professional_contacts)
values ('<user_id>', array['...'], array['...'], array['...'], '[...]'::jsonb, '[...]'::jsonb)
on conflict (user_id) do update set
  warning_signs = excluded.warning_signs, coping_steps = excluded.coping_steps,
  reasons = excluded.reasons, contacts = excluded.contacts,
  professional_contacts = excluded.professional_contacts;
```

The crisis line field defaults to 988 and 911. Leave it.

Show them the finished plan in a clean, readable format, and suggest they share it with their therapist so it matches what they've worked on together.

## Showing the plan

When asked, read it back cleanly with the crisis line at the bottom. If none exists, offer to make one, and give 988 and 911 regardless.
