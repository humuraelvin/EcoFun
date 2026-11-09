# EcoStep

EcoStep is a Flutter app that turns climate awareness into a small daily habit for people in Rwanda:

1. **Read** today's environment story — real news from Rwandan newsrooms, in English or Kinyarwanda.
2. **Quiz** — five questions that EcoStep's AI writes *from the story you just read*, graded on the server.
3. **Act** — a daily climate mission proven with a photo and a short story; waste missions are checked by AI.

Plus an **AI waste scanner** (in-app camera → biodegradable or not, how to dispose of it in Rwanda),
a **community** feed with star ratings and a leaderboard, streaks, points and a personal journey.

---

## Architecture

| Layer | Technology |
|---|---|
| App | Flutter (Android + iOS), GetX for state/navigation, easy_localization (English + Kinyarwanda) |
| Auth | Supabase Auth — email/password with emailed codes, optional Google |
| Data | Supabase Postgres with Row Level Security; all points logic in `SECURITY DEFINER` SQL functions |
| Files | Supabase Storage buckets: `missions` and `scans` (private), `community` and `avatars` (public) |
| News | `refresh_news()` runs hourly in Postgres (pg_cron) and ingests RSS from Taarifa, Green Africa, KT Press, Rebero, Umuseke and Izuba Radio & TV |
| AI | NVIDIA API, called from Postgres (`http` extension); the key lives in Supabase Vault, never in the app |
| | Vision: `nvidia/nemotron-3.5-super-vl-120b-a12b` (fallback `nemotron-3-nano-omni-30b`) · Quiz: `nvidia/nemotron-3.5-lightning-30b-a3b` |

```
lib/
  app/        app shell, routes, SessionController (today's progress), NewsController
  core/       theme (colours, type), reusable widgets, utils (formatting, image compression, photo picker)
  data/       Supabase client, models, repositories, storage service, auth
  features/   auth · shell · home · news · quiz · mission · scan · history · community · profile
supabase/
  schema.sql          the complete database (run in the SQL editor)
  secrets.example.sql template for the git-ignored secrets.local.sql (NVIDIA key → Vault)
```

Every rule that matters is enforced in the database: one quiz score and one mission per user per day
(Kigali time), answers never leave the server, users can only edit their own name/photo, ratings are once
per post and never on your own post, and only admins can grant points.

---

## Set up Supabase (once)

1. **SQL Editor → New query** → paste all of [`supabase/schema.sql`](supabase/schema.sql) → **Run**.
   The last line fills the news feed immediately and prints how many articles were saved.
2. Copy `supabase/secrets.example.sql` to `supabase/secrets.local.sql`, put your NVIDIA key in it, and run it
   the same way. (It stores the key encrypted in Vault.)
3. **Authentication → Sign In / Providers → Email**: keep Email enabled.
   - Easiest for testing: turn **Confirm email** off — new accounts can sign in immediately.
   - If you keep confirmation on, the app accepts the emailed code: in **Authentication → Emails**, add
     `{{ .Token }}` to the *Confirm signup* template.
4. For password reset by code, edit **Authentication → Emails → Reset Password** and include `{{ .Token }}`,
   e.g. `<p>Your EcoStep code is <b>{{ .Token }}</b></p>`.
5. Optional — make someone an admin:
   ```sql
   update public.profiles set is_admin = true
   where id = (select id from auth.users where email = 'admin@example.com');
   ```
6. Optional — Google sign-in: create OAuth clients in Google Cloud (Web + Android with your SHA-1), enable
   Google in Supabase with the Web client ID, and put that ID in `GOOGLE_WEB_CLIENT_ID`.

## Run the app

```bash
cp assets/config/.env.example assets/config/.env   # then fill in your Supabase URL + publishable key
flutter pub get
flutter run --release        # release mode is the smooth, low-memory build
```

The app is tuned for low-end phones (2 GB RAM, 32-bit ARM): native system fonts (no bundled font files),
images decoded at display size, a capped image cache, lazily built tabs, compressed uploads (~100 KB) and
offline caches for the home screen and news.
