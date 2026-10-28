---
name: weekly-report
description: Builds the short, structured summary of the person's week for their therapist in 167 Hours, reviewed by the person first and sent only by them. Use when the user says "build my report", "make my summary", "get ready for my session", "what should I bring to therapy", or "send my therapist an update".
---

# Weekly report for the therapist

Build a summary the therapist can read in about five minutes before the session. It reports what the person shared, in their words where possible. It is not a clinical assessment and never diagnoses or interprets. All clinical judgment stays with the therapist. Never use em dashes.

## Find the database

Use the Supabase tools: project named `167-hours`; `select * from public.profiles limit 1;` (includes `report_timing`, when they like the report ready). Set `user_id` explicitly. If the database isn't there, offer to run setup.

## Pick the period

The period runs from the end of the last report (`select max(period_end) from public.session_summaries where user_id = ...`) to now. If there's no earlier report, start from the last session in `sessions`, or the last 7 days. Tell the person the date range in one line.

## Gather (never include private entries)

- `entries` in the period with `private = false`, ordered by `occurred_at`, with linked people and patterns.
- The most recent `sessions` row: its homework and takeaways.
- `tool_uses` in the period with tool names.
- Patterns linked to entries in the period.

## Report structure: always use the template

The report has one fixed format, the same one used for real clients so far. Read `references/report-template.html` from this skill and fill it in. Do not invent a different layout, change the section order, rename headings, or restyle it. Its comments explain what goes in each part.

Sections, in order:

1. **Header and details**: therapist, client name, next session, period, number of entries and whether any were kept private, and the AI disclaimer.
2. **A note before you read**: three to five sentences on the shape of the week, and that the starting points are ranked suggestions.
3. **The week in brief**: one paragraph in time order. Descriptive, not interpretive.
4. **Suggested starting points**: up to three, ranked by how often and how strongly each came up, each with a short "why it may matter". Then "Also present, if there's room" for the rest.
5. **What [name] wants to bring up**: everything with `flag_for_session = true`, in their words.
6. **Patterns this week**: from `patterns` linked to entries in the period.
7. **Timeline**: by day, with times.
8. **Urges**: when, the urge, and whether they acted on it. Add one plain line about drinking or using, only as they described it.
9. **Sleep and physical**.
10. **Anger and safety**: only when there was rage, thoughts of harming someone, self-harm, not wanting to be here, or danger. Report exactly what was said and whether anything was acted on.
11. **Strengths and what helped**: concrete moments they handled well, and tools that helped.
12. **A note on how [name] used AI this week**: neutral, two or three sentences.
13. **[Name]'s questions for you**: in first person, as they'd ask them.
14. **Footer**, then the therapist feedback note from `references/feedback.md`.

Leave out any section with nothing in it, except the note, the week in brief, the starting points, and the footer. Use their own words in quotes wherever possible. Don't soften or dramatize. Never include entries marked private.

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
2. Make the PDF from the filled template. Save the filled HTML, then convert it to a PDF named like `Between-Session-Summary-Oct-27.pdf` (the session date), using whatever is available (for example a headless browser's print to PDF, or a Python HTML-to-PDF library), keeping the template's styling. Give them the PDF to download. If a PDF truly can't be made, give them the HTML file, which opens in any browser and can be printed to PDF. Also save the filled HTML in `session_summaries.report_html` and the file name in `pdf_filename`.
3. Write a short, warm email to their therapist (use `therapist_email` and `therapist_name` from `profiles`): a line saying here's this week's summary ahead of the session, then the summary itself in the body.
4. **If Gmail or Outlook is connected**, save it as a **draft** addressed to the therapist, with the subject "Between-session summary, <dates>". For the email body, read `references/email-template.html` and fill it in exactly, passing it as the HTML body (and a short plain-text version as the plain body). It's a shorter, inbox-friendly version of the report with the styles built in; do not write your own formatting or use Markdown in the email. Do not try to attach the PDF; the file is too large to pass through the email tool. Then tell them, in this order, in plain words:
   - Their draft is ready, and exactly where to find it. **Gmail:** on the phone, open the Gmail app, tap the menu (three lines, top left), then **Drafts**; on a computer, click **Drafts** in the list on the left. **Outlook:** on the phone, open the Outlook app, tap the menu or your picture (top left), then **Drafts**; on a computer, click **Drafts** in the folder list on the left. Look for the subject "Between-session summary".
   - Download the PDF here and drag it into the draft if they want it attached.
   - Look it over, check the "To" line is their therapist, and hit send when ready. If the therapist's email is missing, ask for it before creating the draft.
5. **If no email is connected, or they use something Claude can't connect to (Yahoo, Apple Mail, iCloud, AOL and others)**, show the email text so they can copy and paste it into a new email, and attach the PDF themselves.

Never send an email. Only create drafts. The person always reviews and sends it themselves.
