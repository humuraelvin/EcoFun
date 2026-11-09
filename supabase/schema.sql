-- ============================================================================
--  EcoFun — complete Supabase schema
--  Paste this whole file into Supabase → SQL Editor → New query → Run.
--  It is safe to run again: every statement is idempotent.
--  After it succeeds, run supabase/secrets.local.sql (stores the NVIDIA key).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Extensions
-- ----------------------------------------------------------------------------
create extension if not exists http with schema extensions;      -- outbound HTTPS (AI + RSS)
create extension if not exists pg_cron;                            -- hourly news refresh
create extension if not exists pg_net with schema extensions;      -- async calls to the email sender

-- AI calls can take up to ~40 s; PostgREST's default limit for signed-in users is 8 s.
alter role authenticated set statement_timeout = '60s';
notify pgrst, 'reload config';

-- ----------------------------------------------------------------------------
-- 1. Helpers
-- ----------------------------------------------------------------------------
-- EcoFun days follow Rwanda time (Africa/Kigali, UTC+2) for every user.
create or replace function public.eco_today()
returns date language sql stable set search_path = '' as $$
  select (now() at time zone 'Africa/Kigali')::date;
$$;

-- ----------------------------------------------------------------------------
-- 2. Tables
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null default 'EcoFun member' check (char_length(full_name) between 1 and 80),
  avatar_url  text check (avatar_url is null or char_length(avatar_url) <= 500),
  points      integer not null default 0,
  is_admin    boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists profiles_points_idx on public.profiles (points desc);

create table if not exists public.point_events (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  amount      integer not null,
  reason      text not null,          -- quiz | mission | scan | rating_received | admin_grant
  note        text,
  granted_by  uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now()
);
create index if not exists point_events_user_idx on public.point_events (user_id, created_at desc);

create table if not exists public.news_sources (
  id        serial primary key,
  name      text not null,
  url       text not null unique,
  language  text not null check (language in ('en', 'rw')),
  mode      text not null default 'filter' check (mode in ('all', 'filter')),
  active    boolean not null default true
);

create table if not exists public.news_articles (
  id            text primary key,            -- md5(url)
  url           text not null unique,
  title         text not null,
  summary       text not null default '',
  body          text not null default '',
  image_url     text,
  source        text not null,
  language      text not null check (language in ('en', 'rw')),
  published_at  timestamptz not null,
  fetched_at    timestamptz not null default now()
);
create index if not exists news_articles_published_idx on public.news_articles (published_at desc);
create index if not exists news_articles_lang_idx on public.news_articles (language, published_at desc);

create table if not exists public.news_reads (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  article_id  text not null,
  read_at     timestamptz not null default now(),
  primary key (user_id, article_id)
);

create table if not exists public.daily_progress (
  user_id               uuid not null references public.profiles (id) on delete cascade,
  day                   date not null,
  article_id            text,
  news_read_at          timestamptz,
  quiz_id               uuid,
  quiz_completed_at     timestamptz,
  quiz_score            integer,
  quiz_total            integer,
  mission_completed_at  timestamptz,
  primary key (user_id, day)
);

create table if not exists public.quiz_bank (
  id             serial primary key,
  language       text not null default 'en' check (language in ('en', 'rw')),
  question       text not null unique,
  options        text[] not null check (array_length(options, 1) = 4),
  correct_index  integer not null check (correct_index between 0 and 3),
  explanation    text not null default ''
);

-- The question pool: AI writes environment questions in English, Google Translate adds Kinyarwanda.
create table if not exists public.quiz_pool (
  id              bigint generated always as identity primary key,
  topic           text not null,
  difficulty      text not null default 'medium' check (difficulty in ('easy', 'medium', 'hard')),
  question_en     text not null,
  choices_en      text[] not null check (array_length(choices_en, 1) = 4),
  explanation_en  text not null default '',
  question_rw     text,
  choices_rw      text[] check (choices_rw is null or array_length(choices_rw, 1) = 4),
  explanation_rw  text,
  answer          integer not null check (answer between 0 and 3),
  source          text not null default 'ai-practical',
  fingerprint     text not null unique,
  created_at      timestamptz not null default now()
);
create index if not exists quiz_pool_rw_idx on public.quiz_pool (id) where question_rw is not null;

create table if not exists public.quiz_sessions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles (id) on delete cascade,
  language        text not null default 'en' check (language in ('en', 'rw')),
  created_at      timestamptz not null default now(),
  finished_at     timestamptz,
  score           integer,
  total           integer,
  scored          boolean not null default false,
  points_awarded  integer not null default 0
);
create index if not exists quiz_sessions_user_idx on public.quiz_sessions (user_id, created_at desc);

create table if not exists public.quiz_session_items (
  session_id   uuid not null references public.quiz_sessions (id) on delete cascade,
  position     integer not null,
  pool_id      bigint not null references public.quiz_pool (id) on delete cascade,
  choice       integer check (choice between 0 and 3),
  correct      boolean,
  answered_at  timestamptz,
  primary key (session_id, position)
);
create index if not exists quiz_session_items_pool_idx on public.quiz_session_items (pool_id);

create table if not exists public.missions (
  id              serial primary key,
  icon            text not null default '🌱',
  title_en        text not null unique,
  title_rw        text not null,
  description_en  text not null,
  description_rw  text not null,
  points          integer not null default 20 check (points between 1 and 100),
  needs_scan      boolean not null default false,
  active          boolean not null default true
);

create table if not exists public.waste_scans (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles (id) on delete cascade,
  image_path      text,
  category        text not null check (category in ('biodegradable', 'non_biodegradable', 'uncertain')),
  item            text not null,
  material        text not null default '',
  confidence      real not null default 0,
  reason          text not null default '',
  decompose_time  text not null default '',
  disposal        text not null default '',
  tip             text not null default '',
  recyclable      boolean not null default false,
  model           text not null default '',
  created_at      timestamptz not null default now()
);
create index if not exists waste_scans_user_idx on public.waste_scans (user_id, created_at desc);

create table if not exists public.mission_completions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles (id) on delete cascade,
  day             date not null,
  mission_id      integer not null references public.missions (id),
  story           text not null check (char_length(story) between 3 and 1000),
  image_path      text not null,
  scan_id         uuid references public.waste_scans (id) on delete set null,
  points_awarded  integer not null default 0,
  created_at      timestamptz not null default now(),
  unique (user_id, day)
);
create index if not exists mission_completions_user_idx on public.mission_completions (user_id, day desc);

create table if not exists public.community_posts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  image_path    text not null,
  caption       text not null default '' check (char_length(caption) <= 300),
  rating_count  integer not null default 0,
  rating_total  integer not null default 0,
  created_at    timestamptz not null default now()
);
create index if not exists community_posts_created_idx on public.community_posts (created_at desc);

create table if not exists public.post_ratings (
  post_id     uuid not null references public.community_posts (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  value       integer not null check (value between 1 and 5),
  created_at  timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.post_comments (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.community_posts (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  body        text not null check (char_length(body) between 1 and 500),
  created_at  timestamptz not null default now()
);
create index if not exists post_comments_post_idx on public.post_comments (post_id, created_at);

create table if not exists public.announcements (
  id          uuid primary key default gen_random_uuid(),
  title_en    text not null,
  body_en     text not null,
  title_rw    text not null,
  body_rw     text not null,
  emailed     boolean not null default false,
  recipients  integer not null default 0,
  created_by  uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now()
);

-- In-app notifications (live through Supabase Realtime).
--   members: rating, comment, announcement, points_granted, points_removed, post_removed, welcome
--   admins:  new_user, user_left, new_post
create table if not exists public.notifications (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  kind        text not null,
  actor_id    uuid references public.profiles (id) on delete set null,
  post_id     uuid references public.community_posts (id) on delete cascade,
  data        jsonb not null default '{}',
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);
create index if not exists notifications_unread_idx on public.notifications (user_id) where read_at is null;

-- Columns added after the first release.
alter table public.profiles add column if not exists suspended_at timestamptz;
alter table public.profiles add column if not exists suspended_reason text;
alter table public.community_posts add column if not exists comment_count integer not null default 0;
alter table public.waste_scans add column if not exists disposed_at timestamptz;
alter table public.waste_scans add column if not exists disposal_image_path text;
alter table public.waste_scans add column if not exists disposal_feedback text;
alter table public.waste_scans add column if not exists disposal_points integer not null default 0;

-- The first release generated quizzes from news articles; those tables are replaced by the pool above.
drop function if exists public._quiz_from_ai(public.news_articles, text);
drop function if exists public._quiz_from_bank(text, text);
drop function if exists public._quiz_payload(uuid, uuid);
drop table if exists public.quiz_answers, public.quiz_attempts, public.quiz_questions, public.quizzes cascade;

-- ----------------------------------------------------------------------------
-- 3. Row level security
--    Clients may read what they need and edit only their own name/avatar.
--    Every points-related write goes through the SECURITY DEFINER functions below.
-- ----------------------------------------------------------------------------
alter table public.profiles             enable row level security;
alter table public.point_events         enable row level security;
alter table public.news_sources         enable row level security;
alter table public.news_articles        enable row level security;
alter table public.news_reads           enable row level security;
alter table public.daily_progress       enable row level security;
alter table public.quiz_bank            enable row level security;
alter table public.quiz_pool            enable row level security;
alter table public.quiz_sessions        enable row level security;
alter table public.quiz_session_items   enable row level security;
alter table public.missions             enable row level security;
alter table public.waste_scans          enable row level security;
alter table public.mission_completions  enable row level security;
alter table public.community_posts      enable row level security;
alter table public.post_ratings         enable row level security;
alter table public.post_comments        enable row level security;
alter table public.announcements        enable row level security;
alter table public.notifications        enable row level security;

drop policy if exists "profiles readable" on public.profiles;
create policy "profiles readable" on public.profiles for select to authenticated using (true);
drop policy if exists "profiles self update" on public.profiles;
create policy "profiles self update" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
revoke update on public.profiles from authenticated, anon;
grant update (full_name, avatar_url) on public.profiles to authenticated;

drop policy if exists "own point events" on public.point_events;
create policy "own point events" on public.point_events for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "news readable" on public.news_articles;
create policy "news readable" on public.news_articles for select to anon, authenticated using (true);

drop policy if exists "own news reads" on public.news_reads;
create policy "own news reads" on public.news_reads for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "own progress" on public.daily_progress;
create policy "own progress" on public.daily_progress for select to authenticated using (user_id = (select auth.uid()));


drop policy if exists "missions readable" on public.missions;
create policy "missions readable" on public.missions for select to authenticated using (true);

drop policy if exists "own scans" on public.waste_scans;
create policy "own scans" on public.waste_scans for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "delete own scans" on public.waste_scans;
create policy "delete own scans" on public.waste_scans for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists "own completions" on public.mission_completions;
create policy "own completions" on public.mission_completions for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "posts readable" on public.community_posts;
create policy "posts readable" on public.community_posts for select to authenticated using (true);
drop policy if exists "delete own posts" on public.community_posts;
create policy "delete own posts" on public.community_posts for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists "own ratings" on public.post_ratings;
create policy "own ratings" on public.post_ratings for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "comments readable" on public.post_comments;
create policy "comments readable" on public.post_comments for select to authenticated using (true);

drop policy if exists "announcements readable" on public.announcements;
create policy "announcements readable" on public.announcements for select to authenticated using (true);

drop policy if exists "own notifications" on public.notifications;
create policy "own notifications" on public.notifications for select to authenticated using (user_id = (select auth.uid()));
-- quiz_bank, quiz_pool, quiz_sessions, quiz_session_items, news_sources: no client policies (answers stay secret).

-- ----------------------------------------------------------------------------
-- 4. Storage buckets + policies (files live under <bucket>/<user id>/...)
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('missions',  'missions',  false, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('scans',     'scans',     false, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('community', 'community', true,  5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('avatars',   'avatars',   true,  2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Used by storage policies and the app; true only for admins.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select is_admin and suspended_at is null from public.profiles where id = auth.uid()), false);
$$;

-- Policies from the app's earlier name (EcoStep), if an older version of this script ran.
drop policy if exists "ecostep upload own folder" on storage.objects;
drop policy if exists "ecostep update own avatar" on storage.objects;
drop policy if exists "ecostep read own private" on storage.objects;
drop policy if exists "ecostep delete own files" on storage.objects;

drop policy if exists "ecofun admin read all" on storage.objects;
create policy "ecofun admin read all" on storage.objects for select to authenticated
  using (bucket_id in ('missions', 'scans', 'community', 'avatars') and public.is_admin());
drop policy if exists "ecofun admin delete all" on storage.objects;
create policy "ecofun admin delete all" on storage.objects for delete to authenticated
  using (bucket_id in ('missions', 'scans', 'community', 'avatars') and public.is_admin());

drop policy if exists "ecofun upload own folder" on storage.objects;
create policy "ecofun upload own folder" on storage.objects for insert to authenticated
  with check (bucket_id in ('missions', 'scans', 'community', 'avatars')
              and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "ecofun update own avatar" on storage.objects;
create policy "ecofun update own avatar" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "ecofun read own private" on storage.objects;
create policy "ecofun read own private" on storage.objects for select to authenticated
  using (bucket_id in ('missions', 'scans', 'avatars', 'community')
         and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "ecofun delete own files" on storage.objects;
create policy "ecofun delete own files" on storage.objects for delete to authenticated
  using (bucket_id in ('missions', 'scans', 'community', 'avatars')
         and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ----------------------------------------------------------------------------
-- 5. New-user profile trigger
-- ----------------------------------------------------------------------------
-- A member exists in EcoFun only after verifying their email with the code.
-- (Supabase keeps the unverified sign-up in auth.users until then; it is purged after an hour.)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_name text;
begin
  if new.email_confirmed_at is null then return new; end if;
  if tg_op = 'UPDATE' and old.email_confirmed_at is not null then return new; end if;
  v_name := public._display_name(coalesce(new.raw_user_meta_data, '{}'), new.email);
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id, v_name, coalesce(new.raw_user_meta_data ->> 'avatar_url', new.raw_user_meta_data ->> 'picture'))
  on conflict (id) do nothing;
  if found then
    perform public._notify(new.id, 'welcome', null, null, '{}');
    perform public._notify_admins('new_user', new.id, null, jsonb_build_object('name', v_name, 'email', new.email));
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert or update of email_confirmed_at on auth.users
  for each row execute function public.handle_new_user();

-- Remove unfinished sign-ups (profiles of unverified accounts, and the accounts themselves after 1 hour).
delete from public.profiles p using auth.users u where u.id = p.id and u.email_confirmed_at is null;

create or replace function public._purge_unverified()
returns integer language plpgsql volatile security definer set search_path = '' as $$
declare n integer;
begin
  delete from auth.users where email_confirmed_at is null and created_at < now() - interval '1 hour';
  get diagnostics n = row_count;
  return n;
end;
$$;

-- Backfill profiles for verified accounts created before this script ran.
insert into public.profiles (id, full_name)
select u.id, left(coalesce(nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''), split_part(u.email, '@', 1), 'EcoFun member'), 80)
from auth.users u
where u.email_confirmed_at is not null
on conflict (id) do nothing;
-- Default names from the app's earlier name.
update public.profiles set full_name = 'EcoFun member' where full_name = 'EcoStep member';

create or replace function public.touch_profile()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  new.full_name := left(trim(new.full_name), 80);
  if new.full_name = '' then new.full_name := 'EcoFun member'; end if;
  return new;
end;
$$;
drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_profile();

-- ----------------------------------------------------------------------------
-- 6. Internal helpers (not callable by app users)
-- ----------------------------------------------------------------------------
create or replace function public._require_user()
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := auth.uid(); v_suspended timestamptz;
begin
  if uid is null then raise exception 'Sign in to continue.' using errcode = '28000'; end if;
  select suspended_at into v_suspended from public.profiles where id = uid;
  if v_suspended is not null then
    raise exception 'Your account has been suspended.' using errcode = '42501';
  end if;
  return uid;
end;
$$;

create or replace function public._require_admin()
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public._require_user();
begin
  if not coalesce((select is_admin from public.profiles where id = uid), false) then
    raise exception 'Admin access is required.' using errcode = '42501';
  end if;
  return uid;
end;
$$;

-- In-app notification (never to yourself). Never raises.
create or replace function public._notify(p_user uuid, p_kind text, p_actor uuid default null,
                                          p_post uuid default null, p_data jsonb default '{}')
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  if p_user is null or p_user = p_actor then return; end if;
  insert into public.notifications (user_id, kind, actor_id, post_id, data)
  values (p_user, p_kind, p_actor, p_post, coalesce(p_data, '{}'));
exception when others then
  raise warning 'EcoFun notification (%) failed: %', p_kind, sqlerrm;
end;
$$;

create or replace function public._notify_admins(p_kind text, p_actor uuid default null,
                                                 p_post uuid default null, p_data jsonb default '{}')
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  insert into public.notifications (user_id, kind, actor_id, post_id, data)
  select id, p_kind, p_actor, p_post, coalesce(p_data, '{}') from public.profiles
  where is_admin and id is distinct from p_actor;
exception when others then
  raise warning 'EcoFun admin notification (%) failed: %', p_kind, sqlerrm;
end;
$$;

-- Google Translate (en <-> rw). Translates a list of short texts in one request; returns null on failure.
create or replace function public._translate(p_texts text[], p_from text, p_to text)
returns text[] language plpgsql volatile security definer set search_path = '' as $$
declare
  resp    record;
  joined  text;
  out     text := '';
  seg     jsonb;
  parts   text[];
begin
  if p_texts is null or array_length(p_texts, 1) is null then return p_texts; end if;
  joined := array_to_string(array(select regexp_replace(coalesce(t, ''), '\s*[\r\n]+\s*', ' ', 'g') from unnest(p_texts) t), E'\n');
  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT', '20');
  select status, content as c into resp from extensions.http((
    'POST',
    'https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&sl=' || p_from || '&tl=' || p_to,
    array[extensions.http_header('User-Agent', 'Mozilla/5.0 (Linux; Android 14) EcoFun/1.0')],
    'application/x-www-form-urlencoded',
    'q=' || extensions.urlencode(joined)
  )::extensions.http_request);
  if resp.status <> 200 then return null; end if;
  for seg in select * from jsonb_array_elements((resp.c::jsonb) -> 0) loop
    out := out || coalesce(seg ->> 0, '');
  end loop;
  parts := regexp_split_to_array(out, E'\s*\n\s*');
  if array_length(parts, 1) <> array_length(p_texts, 1) then return null; end if;
  return array(select btrim(x) from unnest(parts) x);
exception when others then
  raise warning 'EcoFun translate failed: %', sqlerrm;
  return null;
end;
$$;

create or replace function public._award_points(p_user uuid, p_amount integer, p_reason text, p_note text default null, p_by uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_amount = 0 then return; end if;
  update public.profiles set points = greatest(0, points + p_amount) where id = p_user;
  insert into public.point_events (user_id, amount, reason, note, granted_by) values (p_user, p_amount, p_reason, p_note, p_by);
end;
$$;

create or replace function public._nvidia_key()
returns text language plpgsql stable security definer set search_path = '' as $$
declare k text;
begin
  select decrypted_secret into k from vault.decrypted_secrets where name = 'nvidia_api_key' limit 1;
  if k is null or k = '' then
    raise exception 'AI is not configured yet. Run supabase/secrets.local.sql.' using errcode = 'P0001';
  end if;
  return k;
end;
$$;

-- Calls NVIDIA's OpenAI-compatible chat endpoint and returns the parsed JSON object the model wrote.
drop function if exists public._nvidia_chat(text, jsonb, integer, numeric);
create or replace function public._nvidia_chat(p_model text, p_messages jsonb, p_max_tokens integer default 700,
                                               p_temperature numeric default 0.1, p_timeout integer default 45)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  resp     record;
  v_content  text;
  body     jsonb;
begin
  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT', p_timeout::text);
  perform extensions.http_set_curlopt('CURLOPT_CONNECTTIMEOUT', '10');
  select status, content as c into resp
  from extensions.http((
    'POST',
    'https://integrate.api.nvidia.com/v1/chat/completions',
    array[extensions.http_header('Authorization', 'Bearer ' || public._nvidia_key()),
          extensions.http_header('Accept', 'application/json')],
    'application/json',
    jsonb_build_object(
      'model', p_model,
      'messages', p_messages,
      'temperature', p_temperature,
      'max_tokens', p_max_tokens,
      'response_format', jsonb_build_object('type', 'json_object'),
      'chat_template_kwargs', jsonb_build_object('enable_thinking', false)
    )::text
  )::extensions.http_request);

  if resp.status <> 200 then
    raise exception 'AI service returned status %', resp.status using errcode = 'P0002';
  end if;

  v_content := (resp.c::jsonb) -> 'choices' -> 0 -> 'message' ->> 'content';
  if v_content is null then raise exception 'AI returned an empty answer' using errcode = 'P0002'; end if;
  -- Strip optional ```json fences, then keep the outermost JSON object.
  v_content := regexp_replace(v_content, '^\s*```(json)?', '');
  v_content := regexp_replace(v_content, '```\s*$', '');
  v_content := substring(v_content from position('{' in v_content));
  v_content := left(v_content, length(v_content) - position('}' in reverse(v_content)) + 1);
  body := v_content::jsonb;
  return body;
end;
$$;

-- XML text node → plain text (undo the escaping Postgres applies to text() nodes).
create or replace function public._xml_unescape(t text)
returns text language sql immutable set search_path = '' as $$
  select replace(replace(replace(replace(replace(coalesce(t, ''),
    '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&');
$$;

-- Decode HTML entities (numeric + the common named ones).
create or replace function public._html_entities(t text)
returns text language plpgsql immutable set search_path = '' as $$
declare r text := coalesce(t, ''); m text[]; code integer; guard integer := 0;
begin
  loop
    m := regexp_match(r, '&#([0-9]{1,7});');
    exit when m is null or guard > 400;
    guard := guard + 1;
    code := m[1]::integer;
    r := replace(r, '&#' || m[1] || ';',
      case when code between 1 and 1114111 and code not between 55296 and 57343 then chr(code) else '' end);
  end loop;
  loop
    m := regexp_match(r, '&#[xX]([0-9a-fA-F]{1,6});');
    exit when m is null or guard > 800;
    guard := guard + 1;
    code := ('x' || lpad(m[1], 8, '0'))::bit(32)::integer;
    r := regexp_replace(r, '&#[xX]' || m[1] || ';',
      case when code between 1 and 1114111 and code not between 55296 and 57343 then chr(code) else '' end, 'g');
  end loop;
  r := replace(r, '&nbsp;', ' ');
  r := replace(r, '&rsquo;', '’'); r := replace(r, '&lsquo;', '‘');
  r := replace(r, '&rdquo;', '”'); r := replace(r, '&ldquo;', '“');
  r := replace(r, '&ndash;', '–'); r := replace(r, '&mdash;', '—');
  r := replace(r, '&hellip;', '…'); r := replace(r, '&raquo;', '»'); r := replace(r, '&laquo;', '«');
  r := replace(r, '&quot;', '"'); r := replace(r, '&#039;', ''''); r := replace(r, '&apos;', '''');
  r := replace(r, '&lt;', '<'); r := replace(r, '&gt;', '>');
  r := replace(r, '&amp;', '&');
  return r;
end;
$$;

-- HTML article → readable plain text, paragraphs separated by a blank line.
create or replace function public._html_to_text(h text)
returns text language plpgsql immutable set search_path = '' as $$
declare r text := coalesce(h, '');
begin
  r := regexp_replace(r, '<(script|style)[^>]*?>.*?</(script|style)>', ' ', 'gi');
  r := regexp_replace(r, '<figcaption[^>]*?>.*?</figcaption>', ' ', 'gi');
  r := regexp_replace(r, '<br\s*/?>', E'\n', 'gi');
  r := regexp_replace(r, '</(p|div|h[1-6]|li|blockquote|tr)>', E'\n\n', 'gi');
  r := regexp_replace(r, '<[^>]+>', ' ', 'g');
  r := public._html_entities(r);
  r := regexp_replace(r, '[ \t\r\f' || chr(160) || ']+', ' ', 'g');
  r := regexp_replace(r, ' *\n *', E'\n', 'g');
  r := regexp_replace(r, '\n{2,}', E'\n\n', 'g');
  r := regexp_replace(r, '\n?The post .{0,250} appeared first on .{0,120}$', '', 'i');
  r := regexp_replace(r, '\n?(Read More|Continue reading)\s*(»|›|…)?\s*$', '', 'i');
  return btrim(r, E' \n');
end;
$$;

-- ----------------------------------------------------------------------------
-- 7. News ingestion (runs on the server; the app just reads news_articles)
-- ----------------------------------------------------------------------------
insert into public.news_sources (name, url, language, mode) values
  ('Taarifa',          'https://taarifa.rw/category/environment/feed/',      'en', 'all'),
  ('Green Africa',     'https://www.greenafrica.rw/feed/',                   'en', 'filter'),
  ('KT Press',         'https://www.ktpress.rw/feed/',                       'en', 'filter'),
  ('Rebero',           'https://rebero.rw/category/ibidukikije/feed/',       'rw', 'all'),
  ('Umuseke',          'https://umuseke.rw/feed/',                           'rw', 'filter'),
  ('Izuba Radio & TV', 'https://izubaradiotv.rw/rss/latest-posts',           'rw', 'filter')
on conflict (url) do update set name = excluded.name, language = excluded.language, mode = excluded.mode;

create or replace function public._looks_environmental(p_text text, p_language text)
returns boolean language sql immutable set search_path = '' as $$
  select case when p_language = 'rw' then
    lower(p_text) ~ '(ibidukikije|ikirere|imihindagurikire|imyanda|amashyamba|ishyamba|isuri|imvura|karuboni|ibinyabuzima|inyamaswa|inkangu|ibiza|ibishanga|igishanga|pariki|plasitiki|pulasitiki|amazi meza|ingufu z|izuba ritanga|gutera ibiti|ibiti|ubutaka|umwanda|isuku|kubungabunga|kurengera|rema\M)'
  else
    lower(p_text) ~ '\m(climate|environment|environmental|conservation|biodiversity|forest|forests|deforestation|afforestation|reforestation|trees?|wildlife|gorillas?|national park|wetlands?|waste|plastics?|recycl\w*|pollution|emissions?|carbon|renewable|solar|green energy|clean energy|flood\w*|landslides?|erosion|drought|rema|sustainab\w*|ecosystems?|compost\w*|sanitation|e-waste|air quality|water resources|weather|rainfall|nature)\M'
  end;
$$;

create or replace function public.refresh_news()
returns integer language plpgsql volatile security definer set search_path = '' as $$
declare
  src        record;
  resp       record;
  doc        xml;
  it         xml;
  raw        text;
  v_title    text;
  v_link     text;
  v_desc     text;
  v_body     text;
  v_cats     text;
  v_date     timestamptz;
  v_img      text;
  v_summary  text;
  saved      integer := 0;
begin
  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT', '25');
  for src in select * from public.news_sources where active loop
    begin
      select status, content as c into resp from extensions.http((
        'GET', src.url,
        array[extensions.http_header('User-Agent', 'Mozilla/5.0 (Linux; Android 14) EcoFun/1.0 news reader'),
              extensions.http_header('Accept', 'application/rss+xml, application/xml, text/xml')],
        null, null)::extensions.http_request);
      if resp.status <> 200 or resp.c is null then
        raise warning 'EcoFun news: % returned %', src.url, resp.status;
        continue;
      end if;

      raw := resp.c;
      raw := regexp_replace(raw, '^\s*<\?xml[^>]*\?>', '');                    -- drop XML declaration
      raw := regexp_replace(raw, '<!DOCTYPE[^>]*>', '', 'i');
      raw := regexp_replace(raw, '[\x01-\x08\x0B\x0C\x0E-\x1F]', '', 'g');     -- illegal control chars
      raw := replace(raw, '&nbsp;', '&#160;');
      raw := regexp_replace(raw, '&(?!(amp|lt|gt|quot|apos|#[0-9]+|#[xX][0-9a-fA-F]+);)[a-zA-Z][a-zA-Z0-9]*;', '', 'g');
      doc := xmlparse(document raw);

      for it in select unnest(xpath('/rss/channel/item', doc)) loop
        begin
          v_title := btrim(public._html_entities(public._xml_unescape(array_to_string(xpath('/item/title/text()', it)::text[], ''))));
          v_link  := btrim(public._xml_unescape(array_to_string(xpath('/item/link/text()', it)::text[], '')));
          v_desc  := public._xml_unescape(array_to_string(xpath('/item/description/text()', it)::text[], ''));
          v_body  := public._xml_unescape(array_to_string(xpath('/item/*[local-name()="encoded"]/text()', it)::text[], ''));
          v_cats  := public._xml_unescape(array_to_string(xpath('/item/category/text()', it)::text[], ' '));
          begin
            v_date := btrim(array_to_string(xpath('/item/pubDate/text()', it)::text[], ''))::timestamptz;
          exception when others then v_date := now();
          end;
          if v_date > now() + interval '1 day' then v_date := now(); end if;

          v_img := (xpath('/item/*[local-name()="content"]/@url', it))[1]::text;
          if v_img is null then v_img := (xpath('/item/enclosure/@url', it))[1]::text; end if;
          if v_img is null then v_img := (xpath('/item/*[local-name()="thumbnail"]/@url', it))[1]::text; end if;
          if v_img is null then v_img := substring(v_body from '<img[^>]+src="(https?://[^"]+)"'); end if;
          if v_img is null then v_img := substring(v_desc from '<img[^>]+src="(https?://[^"]+)"'); end if;
          v_img := public._xml_unescape(v_img);

          if v_title = '' or v_link !~ '^https?://' then continue; end if;

          v_summary := public._html_to_text(v_desc);
          v_body := public._html_to_text(v_body);
          if v_body = '' then v_body := v_summary; end if;
          if v_summary = '' or length(v_summary) > 400 then
            v_summary := left(regexp_replace(v_body, '\s+', ' ', 'g'), 260);
          end if;

          if src.mode = 'filter'
             and not public._looks_environmental(v_title || ' ' || v_cats || ' ' || left(v_body, 600), src.language) then
            continue;
          end if;

          insert into public.news_articles (id, url, title, summary, body, image_url, source, language, published_at, fetched_at)
          values (md5(v_link), v_link, left(v_title, 300), left(v_summary, 400), left(v_body, 20000), v_img, src.name, src.language, v_date, now())
          on conflict (id) do update set
            title = excluded.title, summary = excluded.summary, body = excluded.body,
            image_url = coalesce(excluded.image_url, public.news_articles.image_url), fetched_at = now();
          saved := saved + 1;
        exception when others then
          raise warning 'EcoFun news item skipped (%): %', src.name, sqlerrm;
        end;
      end loop;
    exception when others then
      raise warning 'EcoFun news source failed (%): %', src.url, sqlerrm;
    end;
  end loop;

  delete from public.news_articles where published_at < now() - interval '120 days';
  return saved;
end;
$$;

-- ----------------------------------------------------------------------------
-- 8. Daily flow: home summary, streak, news read
-- ----------------------------------------------------------------------------
create or replace function public._streak(p_user uuid)
returns integer language plpgsql stable security definer set search_path = '' as $$
declare d date := public.eco_today(); n integer := 0;
begin
  if not exists (select 1 from public.mission_completions where user_id = p_user and day = d) then
    d := d - 1;   -- today is still open; the streak survives until midnight
  end if;
  while exists (select 1 from public.mission_completions where user_id = p_user and day = d) loop
    n := n + 1;
    d := d - 1;
  end loop;
  return n;
end;
$$;

create or replace function public._mission_for_day(p_day date)
returns integer language sql stable security definer set search_path = '' as $$
  select id from public.missions where active
  order by id
  offset (select (p_day - date '2024-01-01') % greatest(count(*), 1) from public.missions where active)
  limit 1;
$$;

create or replace function public.get_home()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  uid    uuid := public._require_user();
  today  date := public.eco_today();
  p      public.daily_progress;
  prof   public.profiles;
  m      public.missions;
  week   jsonb;
begin
  select * into prof from public.profiles where id = uid;
  select * into p from public.daily_progress where user_id = uid and day = today;
  select * into m from public.missions where id = public._mission_for_day(today);

  select coalesce(jsonb_agg(jsonb_build_object(
           'day', g::date,
           'done', exists (select 1 from public.mission_completions c where c.user_id = uid and c.day = g::date))
         order by g), '[]'::jsonb)
    into week
  from generate_series(today - 6, today, interval '1 day') g;

  return jsonb_build_object(
    'today', today,
    'profile', jsonb_build_object('id', prof.id, 'full_name', prof.full_name, 'avatar_url', prof.avatar_url,
                                  'points', prof.points, 'is_admin', prof.is_admin),
    'unread_notifications', (select count(*) from public.notifications where user_id = uid and read_at is null),
    'streak', public._streak(uid),
    'week', week,
    'progress', jsonb_build_object(
      'article_id', p.article_id,
      'news_read', p.news_read_at is not null,
      'quiz_done', p.quiz_completed_at is not null,
      'quiz_score', p.quiz_score,
      'quiz_total', p.quiz_total,
      'mission_done', p.mission_completed_at is not null),
    'mission', case when m.id is null then null else jsonb_build_object(
      'id', m.id, 'icon', m.icon, 'title_en', m.title_en, 'title_rw', m.title_rw,
      'description_en', m.description_en, 'description_rw', m.description_rw,
      'points', m.points, 'needs_scan', m.needs_scan) end,
    'stats', jsonb_build_object(
      'missions', (select count(*) from public.mission_completions where user_id = uid),
      'scans', (select count(*) from public.waste_scans where user_id = uid),
      'quizzes', (select count(*) from public.quiz_sessions where user_id = uid and finished_at is not null),
      'articles', (select count(*) from public.news_reads where user_id = uid))
  );
end;
$$;

create or replace function public.mark_news_read(p_article_id text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_user(); today date := public.eco_today();
begin
  if not exists (select 1 from public.news_articles where id = p_article_id) then
    raise exception 'This story is no longer available.' using errcode = 'P0001';
  end if;
  insert into public.news_reads (user_id, article_id) values (uid, p_article_id)
  on conflict (user_id, article_id) do update set read_at = now();

  insert into public.daily_progress (user_id, day, article_id, news_read_at)
  values (uid, today, p_article_id, now())
  on conflict (user_id, day) do update set
    article_id = coalesce(public.daily_progress.article_id, excluded.article_id),
    news_read_at = coalesce(public.daily_progress.news_read_at, now());
  return public.get_home();
end;
$$;

-- ----------------------------------------------------------------------------
-- 9. Quizzes — open any time, 10 environment questions, graded only on the server
--    The pool grows by itself: every few minutes AI writes 10 new English questions on a
--    random topic and Google Translate adds the Kinyarwanda version.
-- ----------------------------------------------------------------------------
-- Practical, everyday topics: what ordinary people in Rwanda do at home, at the market, at work and outside.
create or replace function public._quiz_topics()
returns text[] language sql immutable set search_path = '' as $$
  select array[
    'sorting household waste into biodegradable and non-biodegradable',
    'what can go into a compost heap and what cannot',
    'what to do with plastic bottles and plastic packaging',
    'what to do with old batteries, phones, chargers and bulbs',
    'what to do with broken glass and glass bottles',
    'what to do with metal tins and cans',
    'what to do with old clothes and shoes',
    'what to do with leftover food and food peelings',
    'what to do with used cooking oil',
    'what to do with expired medicines',
    'why we should never burn rubbish, and what to do instead',
    'why we should never throw rubbish in rivers, drains or the street',
    'keeping drains and gutters clean before the rainy season',
    'saving water at home: taps, washing, bathing',
    'collecting and using rainwater at home',
    'keeping drinking water clean and safe',
    'saving electricity at home: lights, phone chargers, appliances',
    'cooking with less charcoal and firewood, and using improved stoves',
    'shopping with reusable bags and avoiding single-use plastic',
    'choosing products with less packaging at the market',
    'reusing and repairing things instead of throwing them away',
    'planting and caring for trees around the home and school',
    'protecting soil on hillsides from erosion',
    'kitchen gardens and growing your own vegetables',
    'using fertilisers and pesticides safely on the farm',
    'keeping animals and their waste from polluting water',
    'protecting rivers, lakes and wetlands near you',
    'protecting wild animals and not buying wildlife products',
    'keeping your neighbourhood clean and taking part in Umuganda',
    'good toilet and sanitation habits that protect the environment',
    'removing standing water where mosquitoes breed',
    'walking, cycling and sharing rides instead of driving alone',
    'turning off engines instead of leaving motorbikes or cars running',
    'keeping public places, buses and parks clean',
    'saving paper at school and at work',
    'eco-friendly habits for students at school',
    'eco-friendly habits at the workplace and in small shops',
    'staying safe and helping others during floods and heavy rain',
    'everyday choices that reduce air pollution and smoke',
    'teaching children simple ways to care for the environment',
    'recognising which everyday items are biodegradable',
    'recognising which everyday items are recyclable',
    'what each colour of waste bin is for and how to use bins properly',
    'caring for the environment during celebrations, weddings and events',
    'simple habits that keep Rwanda clean and green'
  ];
$$;

create or replace function public._quiz_fingerprint(p_question text)
returns text language sql immutable set search_path = '' as $$
  select md5(regexp_replace(lower(coalesce(p_question, '')), '[^a-z0-9]', '', 'g'));
$$;

-- Writes one batch (up to 10 questions) into the pool. Returns how many new questions were saved.
create or replace function public._quiz_pool_fill()
returns integer language plpgsql volatile security definer set search_path = '' as $$
declare
  topics   text[] := public._quiz_topics();
  topic    text := topics[1 + floor(random() * array_length(topics, 1))::integer];
  angle    text := (array['real situations at home', 'real situations at the market and in shops',
                          'real situations on the farm and in the garden', 'real situations at school',
                          'real situations on the road and in town', 'real situations at work',
                          'real situations with children and family'])[1 + floor(random() * 7)::integer];
  diff     text := (array['easy', 'easy', 'easy', 'medium'])[1 + floor(random() * 4)::integer];
  result   jsonb;
  q        jsonb;
  qs       jsonb[] := '{}';
  texts    text[] := '{}';
  rw       text[];
  n        integer := 0;
  saved    integer := 0;
  choices  text[];
  rw_choices text[];
  msgs     jsonb;
  perm     integer[];
  new_answer integer;
  k        integer;
begin
  msgs := jsonb_build_array(
      jsonb_build_object('role', 'system', 'content',
        'You write quiz questions for EcoFun, an app that teaches ordinary people in Rwanda (market sellers, farmers, ' ||
        'moto drivers, parents, students) how to take care of the environment in daily life. ' ||
        'Every question must be PRACTICAL and SIMPLE: what to do, where something goes, which habit is better, what an item is. ' ||
        'Think of real situations at home, at the market, on the farm, at school, on the road. ' ||
        'Good examples: "Where should you put banana peels?", "What should you do with an old phone battery?", ' ||
        '"Which habit saves water when washing dishes?", "Is a plastic bag biodegradable?". ' ||
        'NEVER ask about numbers, statistics, percentages, years, dates, measurements, records, scientific terms, chemical ' ||
        'names, laws, agreements, conferences, organisations or famous people. Never ask trick questions. ' ||
        'Use plain words a 12-year-old understands and correct grammar. Questions under 18 words; each option under 7 words. ' ||
        'Exactly one option is clearly correct. The three wrong options must be REALISTIC things people really do wrong ' ||
        '(for example "Burn it", "Throw it in the drain", "Leave the tap running"), never silly or impossible answers. ' ||
        'Write options as short actions or short answers, not "Yes, because..." sentences. ' ||
        'The explanation is shown after answering, also to people who chose wrong: in 2 short sentences say why the ' ||
        'right answer is right and give one practical tip. Reply with JSON only.'),
      jsonb_build_object('role', 'user', 'content',
        'Write 10 ' || diff || ' questions about "' || topic || '", using ' || angle || '. Mix these forms across the 10: ' ||
        '"What should you do with ...?", "Where should ... go?", "Which is the best way to ...?", "Which habit ...?", ' ||
        '"What is wrong with ...?", "What can you make from ...?" and at most 2 of "Is ... biodegradable?". ' ||
        'Each question about a different item or situation. Seed: ' ||
        floor(random() * 1000000)::text || '. Return {"questions":[{"question":"...","options":["...","...","...","..."],' ||
        '"correct_index":0,"explanation":"Why it is right. Practical tip."}]}'));
  -- Nemotron Super writes clear, practical questions in ~10 s; Ultra is the slower backup.
  begin
    result := public._nvidia_chat('nvidia/nemotron-3.5-super-vl-120b-a12b', msgs, 5000, 0.7, 90);
  exception when others then
    result := public._nvidia_chat('nvidia/nemotron-3-ultra-550b-a55b', msgs, 5000, 0.7, 120);
  end;

  for q in select * from jsonb_array_elements(coalesce(result -> 'questions', '[]'::jsonb)) loop
    exit when n >= 10;
    if jsonb_typeof(q -> 'options') = 'array' and jsonb_array_length(q -> 'options') = 4
       and (q ->> 'correct_index') ~ '^[0-3]$'
       and char_length(coalesce(q ->> 'question', '')) between 10 and 200
       -- practical only: no numbers, years, statistics or jargon
       and (q ->> 'question') || ' ' || (q -> 'options')::text !~ '[0-9%]'
       and (q ->> 'question') !~* '(estimat|percent|statistic|according to|approximately|primary source|guideline|average|record|which year|founded|agreement|convention|protocol|summit|organi[sz]ation|eutrophic|species is|flagship|ppm|emission factor)'
       and (select count(*) from jsonb_array_elements_text(q -> 'options') x where btrim(x) ~* '^(yes|no)\M') <= 2
       -- four distinct, non-empty options that don't start mid-sentence
       and (select count(distinct lower(btrim(x))) from jsonb_array_elements_text(q -> 'options') x) = 4
       and not exists (select 1 from jsonb_array_elements_text(q -> 'options') x
                       where char_length(btrim(x)) < 1 or x ~ '^\s')
       and not exists (select 1 from public.quiz_pool where fingerprint = public._quiz_fingerprint(q ->> 'question')) then
      qs := qs || q;
      texts := texts || array[btrim(q ->> 'question')] || array(select left(btrim(x), 120) from jsonb_array_elements_text(q -> 'options') x)
                     || array[left(coalesce(q ->> 'explanation', ''), 400)];
      n := n + 1;
    end if;
  end loop;
  if n = 0 then return 0; end if;

  rw := public._translate(texts, 'en', 'rw');   -- 6 texts per question, in order

  for k in 1 .. n loop
    q := qs[k];
    -- shuffle the four options (and their translations) so the correct one lands anywhere
    perm := array(select g from generate_series(1, 4) g order by random());
    choices := array(select left(btrim(x), 120) from jsonb_array_elements_text(q -> 'options') x);
    choices := array[choices[perm[1]], choices[perm[2]], choices[perm[3]], choices[perm[4]]];
    new_answer := array_position(perm, (q ->> 'correct_index')::integer + 1) - 1;
    if rw is not null then
      rw_choices := rw[(k - 1) * 6 + 2 : (k - 1) * 6 + 5];
      rw_choices := array[rw_choices[perm[1]], rw_choices[perm[2]], rw_choices[perm[3]], rw_choices[perm[4]]];
    else
      rw_choices := null;
    end if;
    insert into public.quiz_pool (topic, difficulty, question_en, choices_en, explanation_en,
                                  question_rw, choices_rw, explanation_rw, answer, source, fingerprint)
    values (topic, diff, q ->> 'question', choices, left(coalesce(q ->> 'explanation', ''), 400),
            case when rw is not null then rw[(k - 1) * 6 + 1] end,
            rw_choices,
            case when rw is not null then rw[(k - 1) * 6 + 6] end,
            new_answer, 'ai-practical', public._quiz_fingerprint(q ->> 'question'))
    on conflict (fingerprint) do nothing;
    if found then saved := saved + 1; end if;
  end loop;
  return saved;
end;
$$;

-- Cron: one batch every few minutes; also re-translates questions whose translation failed.
create or replace function public._quiz_pool_tick()
returns void language plpgsql volatile security definer set search_path = '' as $$
declare r record; rw text[];
begin
  if (select count(*) from public.quiz_pool) < 200000 then
    begin
      perform public._quiz_pool_fill();
    exception when others then
      raise warning 'EcoFun quiz pool fill failed: %', sqlerrm;
    end;
  end if;
  for r in select * from public.quiz_pool where question_rw is null order by id limit 10 loop
    rw := public._translate(array[r.question_en] || r.choices_en || array[r.explanation_en], 'en', 'rw');
    exit when rw is null;
    update public.quiz_pool set question_rw = rw[1], choices_rw = rw[2:5], explanation_rw = rw[6] where id = r.id;
  end loop;
end;
$$;


create or replace function public._quiz_payload(p_session uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'quiz_id', s.id,
    'language', s.language,
    'questions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'position', i.position,
        'question', case when s.language = 'rw' and p.question_rw is not null then p.question_rw else p.question_en end,
        'options', to_jsonb(case when s.language = 'rw' and p.choices_rw is not null then p.choices_rw else p.choices_en end),
        'topic', p.topic,
        'answer', case when i.choice is null then null else jsonb_build_object(
          'choice', i.choice, 'correct', i.correct, 'correct_index', p.answer,
          'explanation', case when s.language = 'rw' and p.explanation_rw is not null then p.explanation_rw else p.explanation_en end) end)
        order by i.position)
      from public.quiz_session_items i join public.quiz_pool p on p.id = i.pool_id
      where i.session_id = s.id), '[]'::jsonb))
  from public.quiz_sessions s where s.id = p_session;
$$;

-- Starts (or resumes) a 10-question quiz.
create or replace function public.get_quiz(p_language text default 'en')
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid     uuid := public._require_user();
  lang    text := case when p_language = 'rw' then 'rw' else 'en' end;
  sid     uuid;
  picked  bigint[];
  tries   integer := 0;
  scored_today integer;
begin
  select count(*) into scored_today from public.quiz_sessions
  where user_id = uid and scored and (finished_at at time zone 'Africa/Kigali')::date = public.eco_today();

  -- Unfinished quizzes whose questions were removed from the pool can never be finished: drop them.
  delete from public.quiz_sessions s
  where s.user_id = uid and s.finished_at is null
    and (select count(*) from public.quiz_session_items i where i.session_id = s.id) < 4;

  select id into sid from public.quiz_sessions
  where user_id = uid and finished_at is null and language = lang and created_at > now() - interval '3 hours'
  order by created_at desc limit 1;

  if sid is null then
    loop
      -- questions this member has never seen first, then anything else
      select array_agg(id) into picked from (
        select p.id from public.quiz_pool p
        where (lang = 'en' or p.question_rw is not null)
          and not exists (select 1 from public.quiz_session_items i join public.quiz_sessions s on s.id = i.session_id
                          where s.user_id = uid and i.pool_id = p.id)
        order by random() limit 10) t;
      if coalesce(array_length(picked, 1), 0) < 10 then
        picked := coalesce(picked, '{}') || array(
          select p.id from public.quiz_pool p
          where (lang = 'en' or p.question_rw is not null) and p.id <> all (coalesce(picked, '{}'))
          order by random() limit 10 - coalesce(array_length(picked, 1), 0));
      end if;
      exit when coalesce(array_length(picked, 1), 0) >= 10 or tries >= 1;
      tries := tries + 1;
      begin
        perform public._quiz_pool_fill();   -- first quizzes ever: write questions now
      exception when others then
        raise warning 'EcoFun quiz pool fill failed: %', sqlerrm;
      end;
    end loop;
    if coalesce(array_length(picked, 1), 0) < 4 then
      raise exception 'New quiz questions are being prepared. Please try again in a minute.' using errcode = 'P0001';
    end if;

    insert into public.quiz_sessions (user_id, language) values (uid, lang) returning id into sid;
    insert into public.quiz_session_items (session_id, position, pool_id)
    select sid, ord - 1, pid from unnest(picked) with ordinality as u(pid, ord);
  end if;

  return jsonb_build_object('completed', false, 'scored_today', scored_today, 'scored_limit', 3,
                            'points_per_correct', 2, 'counts_for_points', scored_today < 3)
         || public._quiz_payload(sid);
end;
$$;

create or replace function public.answer_quiz(p_quiz_id uuid, p_position integer, p_choice integer)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid  uuid := public._require_user();
  s    public.quiz_sessions;
  it   public.quiz_session_items;
  p    public.quiz_pool;
begin
  select * into s from public.quiz_sessions where id = p_quiz_id and user_id = uid;
  if s.id is null or s.finished_at is not null then
    raise exception 'This quiz is no longer available. Start a new one.' using errcode = 'P0001';
  end if;
  if p_choice is null or p_choice not between 0 and 3 then raise exception 'Choose one of the four answers.' using errcode = 'P0001'; end if;
  select * into it from public.quiz_session_items where session_id = s.id and position = p_position;
  if it.session_id is null then raise exception 'Question not found.' using errcode = 'P0001'; end if;
  select * into p from public.quiz_pool where id = it.pool_id;
  if it.choice is null then
    update public.quiz_session_items set choice = p_choice, correct = (p_choice = p.answer), answered_at = now()
    where session_id = s.id and position = p_position returning * into it;
  end if;
  return jsonb_build_object('choice', it.choice, 'correct', it.correct, 'correct_index', p.answer,
    'explanation', case when s.language = 'rw' and p.explanation_rw is not null then p.explanation_rw else p.explanation_en end);
end;
$$;

create or replace function public.finish_quiz(p_quiz_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid      uuid := public._require_user();
  today    date := public.eco_today();
  s        public.quiz_sessions;
  v_total  integer;
  v_answered integer;
  v_score  integer;
  scored_today integer;
  pts      integer := 0;
begin
  select * into s from public.quiz_sessions where id = p_quiz_id and user_id = uid for update;
  if s.id is null then raise exception 'This quiz is no longer available.' using errcode = 'P0001'; end if;
  if s.finished_at is not null then
    return jsonb_build_object('already_completed', true, 'score', s.score, 'total', s.total, 'points_awarded', 0);
  end if;
  select count(*), count(choice), count(*) filter (where correct) into v_total, v_answered, v_score
  from public.quiz_session_items where session_id = s.id;
  if v_answered < v_total then raise exception 'Answer every question first.' using errcode = 'P0001'; end if;

  select count(*) into scored_today from public.quiz_sessions
  where user_id = uid and scored and (finished_at at time zone 'Africa/Kigali')::date = today;
  if scored_today < 3 then pts := v_score * 2; end if;

  update public.quiz_sessions set finished_at = now(), score = v_score, total = v_total,
         scored = scored_today < 3, points_awarded = pts
  where id = s.id;
  insert into public.daily_progress (user_id, day, quiz_completed_at, quiz_score, quiz_total)
  values (uid, today, now(), v_score, v_total)
  on conflict (user_id, day) do update set
    quiz_completed_at = coalesce(public.daily_progress.quiz_completed_at, now()),
    quiz_score = greatest(coalesce(public.daily_progress.quiz_score, 0), excluded.quiz_score),
    quiz_total = excluded.quiz_total;
  perform public._award_points(uid, pts, 'quiz', v_score || '/' || v_total);

  return jsonb_build_object('already_completed', false, 'score', v_score, 'total', v_total, 'points_awarded', pts,
                            'scored_left', greatest(0, 2 - scored_today));
end;
$$;

-- ----------------------------------------------------------------------------
-- 10. AI waste identification
-- ----------------------------------------------------------------------------
create or replace function public.classify_waste(p_image_base64 text, p_mime text default 'image/jpeg',
                                                 p_image_path text default null, p_language text default 'en')
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid      uuid := public._require_user();
  lang     text := case when p_language = 'rw' then 'Kinyarwanda' else 'English' end;
  result   jsonb;
  model    text := 'nvidia/nemotron-3.5-super-vl-120b-a12b';
  cat      text;
  scan     public.waste_scans;
  today_scans integer;
  msgs     jsonb;
begin
  if p_mime not in ('image/jpeg', 'image/png', 'image/webp') then
    raise exception 'Use a JPEG, PNG or WebP photo.' using errcode = 'P0001';
  end if;
  if p_image_base64 is null or length(p_image_base64) < 200 or length(p_image_base64) > 1500000 then
    raise exception 'The photo is too large. Try again.' using errcode = 'P0001';
  end if;
  if p_image_path is not null and split_part(p_image_path, '/', 1) <> uid::text then
    raise exception 'Invalid photo path.' using errcode = 'P0001';
  end if;
  select count(*) into today_scans from public.waste_scans
  where user_id = uid and created_at > now() - interval '1 day';
  if today_scans >= 60 then
    raise exception 'You reached today''s scan limit. Come back tomorrow!' using errcode = 'P0001';
  end if;

  msgs := jsonb_build_array(jsonb_build_object('role', 'user', 'content', jsonb_build_array(
    jsonb_build_object('type', 'text', 'text',
      'You are EcoFun''s waste-sorting expert for households in Rwanda. Identify the single main waste item in the photo. ' ||
      'Biodegradable: food scraps, fruit and vegetable peels, leaves, grass, untreated wood, plain paper and cardboard, natural cloth. ' ||
      'Non-biodegradable: plastics (bottles, bags, packaging), glass, metal, cans, batteries, electronics, rubber, styrofoam, synthetic fabric. ' ||
      'If no waste item is clearly visible, or the material cannot be judged, use "uncertain". ' ||
      'Write every text value in ' || lang || '. Return ONLY a JSON object with keys: ' ||
      '"category" ("biodegradable", "non_biodegradable" or "uncertain"), "item" (2-4 words), "material" (short), ' ||
      '"confidence" (number 0-1), "reason" (one sentence on how you can tell), "decompose_time" (e.g. "2-5 weeks" or "450+ years"), ' ||
      '"disposal" (one practical sentence for a household in Rwanda; never suggest burning), ' ||
      '"tip" (one short encouraging eco tip), "recyclable" (true or false).'),
    jsonb_build_object('type', 'image_url', 'image_url', jsonb_build_object('url', 'data:' || p_mime || ';base64,' || p_image_base64))
  )));

  begin
    result := public._nvidia_chat(model, msgs, 500, 0.1);
  exception when others then
    if sqlerrm like 'AI is not configured%' then raise; end if;
    model := 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning';    -- fallback model
    begin
      result := public._nvidia_chat(model, msgs, 500, 0.1);
    exception when others then
      raise exception 'The AI could not analyse this photo right now. Please try again.' using errcode = 'P0002';
    end;
  end;

  cat := lower(coalesce(result ->> 'category', 'uncertain'));
  cat := case when cat in ('biodegradable', 'non_biodegradable') then cat
              when cat like 'non%' then 'non_biodegradable'
              else 'uncertain' end;

  insert into public.waste_scans (user_id, image_path, category, item, material, confidence, reason,
                                  decompose_time, disposal, tip, recyclable, model)
  values (uid, p_image_path, cat,
          left(coalesce(nullif(result ->> 'item', ''), 'Unknown item'), 80),
          left(coalesce(result ->> 'material', ''), 80),
          least(1, greatest(0, coalesce(case when (result ->> 'confidence') ~ '^[0-9.]+$' then (result ->> 'confidence')::real end, 0))),
          left(coalesce(result ->> 'reason', ''), 300),
          left(coalesce(result ->> 'decompose_time', ''), 60),
          left(coalesce(result ->> 'disposal', ''), 300),
          left(coalesce(result ->> 'tip', ''), 300),
          coalesce(lower(result ->> 'recyclable') in ('true', 'yes'), false),
          model)
  returning * into scan;

  -- Scanning itself earns nothing; points come when the item is disposed of properly (confirm_disposal).
  return to_jsonb(scan) || jsonb_build_object('points_awarded', 0);
end;
$$;

-- Points for disposing of a scanned item properly: the member photographs it going into the
-- right bin / compost / collection point, and AI checks the photo.
create or replace function public.confirm_disposal(p_scan_id uuid, p_image_base64 text, p_mime text default 'image/jpeg',
                                                   p_image_path text default null, p_language text default 'en')
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid      uuid := public._require_user();
  lang     text := case when p_language = 'rw' then 'Kinyarwanda' else 'English' end;
  scan     public.waste_scans;
  result   jsonb;
  msgs     jsonb;
  ok       boolean;
  conf     real;
  feedback text;
  today_disposals integer;
  pts      integer := 0;
begin
  select * into scan from public.waste_scans where id = p_scan_id and user_id = uid for update;
  if scan.id is null then raise exception 'This scan is no longer available.' using errcode = 'P0001'; end if;
  if scan.disposed_at is not null then
    return jsonb_build_object('disposed', true, 'already', true, 'points_awarded', 0, 'feedback', scan.disposal_feedback);
  end if;
  if scan.category = 'uncertain' then
    raise exception 'Scan a clear waste item first.' using errcode = 'P0001';
  end if;
  if p_mime not in ('image/jpeg', 'image/png', 'image/webp')
     or p_image_base64 is null or length(p_image_base64) < 200 or length(p_image_base64) > 1500000 then
    raise exception 'The photo is too large. Try again.' using errcode = 'P0001';
  end if;
  if p_image_path is not null and split_part(p_image_path, '/', 1) <> uid::text then
    raise exception 'Invalid photo path.' using errcode = 'P0001';
  end if;

  msgs := jsonb_build_array(jsonb_build_object('role', 'user', 'content', jsonb_build_array(
    jsonb_build_object('type', 'text', 'text',
      'You check proof photos for EcoFun, a recycling app in Rwanda. Earlier the member scanned: "' || scan.item ||
      '" (' || replace(scan.category, '_', '-') || '). Recommended disposal: ' || scan.disposal || ' ' ||
      'Does THIS photo show that kind of item being disposed of properly — for example put into a waste bin, a sorting or ' ||
      'recycling bin, a compost heap or pit, a collection sack, or handed to a collection point? Accept reasonable real photos; ' ||
      'reject photos with no item, no bin/compost/collection context, screenshots, or littering and burning. ' ||
      'Write "feedback" in ' || lang || ' as one short friendly sentence. Return ONLY JSON: ' ||
      '{"disposed": true or false, "confidence": number 0-1, "feedback": "..."}'),
    jsonb_build_object('type', 'image_url', 'image_url', jsonb_build_object('url', 'data:' || p_mime || ';base64,' || p_image_base64))
  )));
  begin
    result := public._nvidia_chat('nvidia/nemotron-3.5-super-vl-120b-a12b', msgs, 250, 0.1);
  exception when others then
    begin
      result := public._nvidia_chat('nvidia/nemotron-3-nano-omni-30b-a3b-reasoning', msgs, 250, 0.1);
    exception when others then
      raise exception 'The AI could not check this photo right now. Please try again.' using errcode = 'P0002';
    end;
  end;

  ok := coalesce(lower(result ->> 'disposed') in ('true', 'yes'), false);
  conf := coalesce(case when (result ->> 'confidence') ~ '^[0-9.]+$' then (result ->> 'confidence')::real end, 0);
  feedback := left(coalesce(nullif(result ->> 'feedback', ''), ''), 300);
  if not ok or conf < 0.5 then
    return jsonb_build_object('disposed', false, 'points_awarded', 0, 'feedback', feedback);
  end if;

  -- 3 points for each of the first 10 proper disposals per day
  select count(*) into today_disposals from public.waste_scans
  where user_id = uid and disposal_points > 0 and (disposed_at at time zone 'Africa/Kigali')::date = public.eco_today();
  if today_disposals < 10 then pts := 3; end if;

  update public.waste_scans set disposed_at = now(), disposal_image_path = p_image_path,
         disposal_feedback = feedback, disposal_points = pts
  where id = scan.id;
  perform public._award_points(uid, pts, 'disposal', scan.item);
  return jsonb_build_object('disposed', true, 'points_awarded', pts, 'feedback', feedback);
end;
$$;

-- ----------------------------------------------------------------------------
-- 11. Climate missions
-- ----------------------------------------------------------------------------
create or replace function public.complete_mission(p_story text, p_image_path text, p_scan_id uuid default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid    uuid := public._require_user();
  today  date := public.eco_today();
  p      public.daily_progress;
  m      public.missions;
  story  text := btrim(coalesce(p_story, ''));
begin
  select * into p from public.daily_progress where user_id = uid and day = today;
  if p.mission_completed_at is not null then
    raise exception 'You already completed today''s mission.' using errcode = 'P0001';
  end if;
  if char_length(story) < 3 or char_length(story) > 1000 then
    raise exception 'Write a short story (up to 1,000 characters).' using errcode = 'P0001';
  end if;
  if p_image_path is null or split_part(p_image_path, '/', 1) <> uid::text then
    raise exception 'Add a photo of your action.' using errcode = 'P0001';
  end if;
  if p_scan_id is not null and not exists (select 1 from public.waste_scans where id = p_scan_id and user_id = uid) then
    p_scan_id := null;
  end if;

  select * into m from public.missions where id = public._mission_for_day(today);
  insert into public.mission_completions (user_id, day, mission_id, story, image_path, scan_id, points_awarded)
  values (uid, today, m.id, story, p_image_path, p_scan_id, m.points);
  insert into public.daily_progress (user_id, day, mission_completed_at) values (uid, today, now())
  on conflict (user_id, day) do update set mission_completed_at = now();
  perform public._award_points(uid, m.points, 'mission', m.title_en);

  return jsonb_build_object('points_awarded', m.points, 'streak', public._streak(uid));
end;
$$;

-- ----------------------------------------------------------------------------
-- 12. Community: posts, ratings, comments, leaderboard
--     Points come from other members' ratings (1-5 stars = 1-5 points), never from posting.
-- ----------------------------------------------------------------------------
create or replace function public._post_json(p_post public.community_posts, p_viewer uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', p_post.id, 'user_id', p_post.user_id, 'image_path', p_post.image_path, 'caption', p_post.caption,
    'rating_count', p_post.rating_count, 'rating_total', p_post.rating_total, 'comment_count', p_post.comment_count,
    'created_at', p_post.created_at,
    'author_name', pr.full_name, 'author_avatar', pr.avatar_url,
    'my_rating', (select r.value from public.post_ratings r where r.post_id = p_post.id and r.user_id = p_viewer))
  from public.profiles pr where pr.id = p_post.user_id;
$$;

create or replace function public.create_post(p_image_path text, p_caption text default '')
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_user(); pid uuid; v_caption text := left(btrim(coalesce(p_caption, '')), 300);
begin
  if p_image_path is null or split_part(p_image_path, '/', 1) <> uid::text then
    raise exception 'Upload a photo first.' using errcode = 'P0001';
  end if;
  if (select count(*) from public.community_posts where user_id = uid and created_at > now() - interval '1 day') >= 10 then
    raise exception 'You can share up to 10 photos a day.' using errcode = 'P0001';
  end if;
  insert into public.community_posts (user_id, image_path, caption)
  values (uid, p_image_path, v_caption) returning id into pid;
  perform public._notify_admins('new_post', uid, pid, jsonb_build_object('caption', left(v_caption, 120)));
  return pid;
end;
$$;

create or replace function public.get_feed(p_limit integer default 20, p_before timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public._require_user();
begin
  return coalesce((
    select jsonb_agg(public._post_json(c, uid) order by c.created_at desc)
    from (select c.* from public.community_posts c
          join public.profiles pr on pr.id = c.user_id and pr.suspended_at is null
          where p_before is null or c.created_at < p_before
          order by c.created_at desc
          limit least(greatest(p_limit, 1), 50)) c), '[]'::jsonb);
end;
$$;

create or replace function public.get_post(p_post_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public._require_user(); post public.community_posts;
begin
  select * into post from public.community_posts where id = p_post_id;
  if post.id is null then raise exception 'This post is no longer available.' using errcode = 'P0001'; end if;
  return public._post_json(post, uid);
end;
$$;

create or replace function public.rate_post(p_post_id uuid, p_value integer)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_user(); post public.community_posts; inserted integer;
begin
  if p_value not between 1 and 5 then raise exception 'Choose 1 to 5 stars.' using errcode = 'P0001'; end if;
  select * into post from public.community_posts where id = p_post_id for update;
  if post.id is null then raise exception 'This post is no longer available.' using errcode = 'P0001'; end if;
  if post.user_id = uid then raise exception 'You cannot rate your own post.' using errcode = 'P0001'; end if;

  insert into public.post_ratings (post_id, user_id, value) values (p_post_id, uid, p_value) on conflict do nothing;
  get diagnostics inserted = row_count;
  if inserted = 0 then
    return jsonb_build_object('already_rated', true, 'rating_count', post.rating_count, 'rating_total', post.rating_total);
  end if;
  update public.community_posts set rating_count = rating_count + 1, rating_total = rating_total + p_value
  where id = p_post_id returning * into post;
  perform public._award_points(post.user_id, p_value, 'rating_received', p_value || ' stars');
  perform public._notify(post.user_id, 'rating', uid, post.id, jsonb_build_object('stars', p_value));
  return jsonb_build_object('already_rated', false, 'rating_count', post.rating_count, 'rating_total', post.rating_total);
end;
$$;

create or replace function public.get_comments(p_post_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public._require_user();
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'post_id', c.post_id, 'user_id', c.user_id, 'body', c.body, 'created_at', c.created_at,
      'author_name', pr.full_name, 'author_avatar', pr.avatar_url) order by c.created_at)
    from (select * from public.post_comments where post_id = p_post_id order by created_at desc limit 200) c
    join public.profiles pr on pr.id = c.user_id), '[]'::jsonb);
end;
$$;

create or replace function public.add_comment(p_post_id uuid, p_body text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_user(); post public.community_posts; v_body text := btrim(coalesce(p_body, '')); cid uuid;
begin
  if char_length(v_body) < 1 or char_length(v_body) > 500 then
    raise exception 'Write a comment (up to 500 characters).' using errcode = 'P0001';
  end if;
  select * into post from public.community_posts where id = p_post_id for update;
  if post.id is null then raise exception 'This post is no longer available.' using errcode = 'P0001'; end if;
  if (select count(*) from public.post_comments where user_id = uid and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'You are commenting very fast. Take a short break.' using errcode = 'P0001';
  end if;
  insert into public.post_comments (post_id, user_id, body) values (p_post_id, uid, v_body) returning id into cid;
  update public.community_posts set comment_count = comment_count + 1 where id = p_post_id;
  perform public._notify(post.user_id, 'comment', uid, post.id, jsonb_build_object('snippet', left(v_body, 120)));
  return jsonb_build_object('id', cid);
end;
$$;

-- Authors delete their own comments; admins can delete any.
create or replace function public.delete_comment(p_comment_id uuid)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_user(); c public.post_comments;
begin
  select * into c from public.post_comments where id = p_comment_id;
  if c.id is null then return; end if;
  if c.user_id <> uid and not public.is_admin() then
    raise exception 'You can only delete your own comments.' using errcode = '42501';
  end if;
  delete from public.post_comments where id = c.id;
  update public.community_posts set comment_count = greatest(0, comment_count - 1) where id = c.post_id;
end;
$$;

-- Verified, active members only (admins are not ranked).
create or replace function public.get_leaderboard(p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public._require_user();
begin
  return jsonb_build_object(
    'leaders', coalesce((
      select jsonb_agg(jsonb_build_object('id', id, 'full_name', full_name, 'avatar_url', avatar_url, 'points', points, 'rank', rnk) order by rnk)
      from (select id, full_name, avatar_url, points, rank() over (order by points desc) as rnk, created_at
            from public.profiles where not is_admin and suspended_at is null
            order by points desc, created_at limit least(greatest(p_limit, 1), 200)) t), '[]'::jsonb),
    'my_rank', (select rnk from (select id, rank() over (order by points desc) as rnk from public.profiles
                                 where not is_admin and suspended_at is null) r where r.id = uid),
    'members', (select count(*) from public.profiles where not is_admin and suspended_at is null));
end;
$$;

create or replace function public.delete_my_account()
returns void language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_user(); v_name text; v_email text;
begin
  select p.full_name, u.email into v_name, v_email from public.profiles p join auth.users u on u.id = p.id where p.id = uid;
  perform public._notify_admins('user_left', null, null, jsonb_build_object('name', v_name, 'email', v_email));
  delete from auth.users where id = uid;
end;
$$;

-- ----------------------------------------------------------------------------
-- 12a. Notifications
-- ----------------------------------------------------------------------------
create or replace function public.get_notifications(p_limit integer default 40, p_before timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public._require_user();
begin
  return jsonb_build_object(
    'unread', (select count(*) from public.notifications where user_id = uid and read_at is null),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', n.id, 'kind', n.kind, 'data', n.data, 'read', n.read_at is not null, 'created_at', n.created_at,
        'post_id', n.post_id, 'post_image', cp.image_path,
        'actor_id', n.actor_id, 'actor_name', a.full_name, 'actor_avatar', a.avatar_url) order by n.created_at desc)
      from (select * from public.notifications where user_id = uid and (p_before is null or created_at < p_before)
            order by created_at desc limit least(greatest(p_limit, 1), 100)) n
      left join public.profiles a on a.id = n.actor_id
      left join public.community_posts cp on cp.id = n.post_id), '[]'::jsonb));
end;
$$;

-- Marks the given notifications (or all, when p_ids is null) as read. Returns the new unread count.
create or replace function public.mark_notifications_read(p_ids bigint[] default null)
returns integer language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_user();
begin
  update public.notifications set read_at = now()
  where user_id = uid and read_at is null and (p_ids is null or id = any (p_ids));
  return (select count(*) from public.notifications where user_id = uid and read_at is null);
end;
$$;

create or replace function public.clear_notifications()
returns void language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_user();
begin
  delete from public.notifications where user_id = uid;
end;
$$;

-- Live updates for the notification bell.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications') then
    execute 'alter publication supabase_realtime add table public.notifications';
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 12b. Admin portal (every function checks that the caller is an admin)
-- ----------------------------------------------------------------------------
create or replace function public.admin_dashboard()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public._require_admin(); today date := public.eco_today();
begin
  return jsonb_build_object(
    'members', (select count(*) from public.profiles where not is_admin),
    'new_today', (select count(*) from public.profiles where not is_admin and (created_at at time zone 'Africa/Kigali')::date = today),
    'new_week', (select count(*) from public.profiles where not is_admin and created_at > now() - interval '7 days'),
    'active_today', (select count(distinct user_id) from (
        select user_id from public.daily_progress where day = today
        union all select user_id from public.waste_scans where created_at > now() - interval '1 day'
        union all select user_id from public.quiz_sessions where created_at > now() - interval '1 day'
        union all select user_id from public.community_posts where created_at > now() - interval '1 day') a),
    'suspended', (select count(*) from public.profiles where suspended_at is not null),
    'unverified', (select count(*) from auth.users where email_confirmed_at is null),
    'posts', (select count(*) from public.community_posts),
    'posts_today', (select count(*) from public.community_posts where created_at > now() - interval '1 day'),
    'comments', (select count(*) from public.post_comments),
    'ratings', (select count(*) from public.post_ratings),
    'quizzes', (select count(*) from public.quiz_sessions where finished_at is not null),
    'quizzes_today', (select count(*) from public.quiz_sessions where finished_at > now() - interval '1 day'),
    'quiz_questions', (select count(*) from public.quiz_pool),
    'scans', (select count(*) from public.waste_scans),
    'disposals', (select count(*) from public.waste_scans where disposed_at is not null),
    'missions', (select count(*) from public.mission_completions),
    'stories_read', (select count(*) from public.news_reads),
    'articles', (select count(*) from public.news_articles),
    'points_total', (select coalesce(sum(points), 0) from public.profiles where not is_admin),
    'signups', (select jsonb_agg(jsonb_build_object('day', g::date, 'count',
                  (select count(*) from public.profiles p where not p.is_admin and (p.created_at at time zone 'Africa/Kigali')::date = g::date))
                  order by g) from generate_series(today - 13, today, interval '1 day') g),
    'top', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'full_name', full_name, 'avatar_url', avatar_url, 'points', points))
             from (select * from public.profiles where not is_admin and suspended_at is null order by points desc limit 5) t), '[]'::jsonb),
    'recent', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'full_name', p.full_name, 'avatar_url', p.avatar_url,
                                                   'email', u.email, 'created_at', p.created_at) order by p.created_at desc)
             from (select * from public.profiles where not is_admin order by created_at desc limit 5) p
             join auth.users u on u.id = p.id), '[]'::jsonb));
end;
$$;

create or replace function public.admin_users(p_search text default '', p_filter text default 'all',
                                              p_limit integer default 30, p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public._require_admin(); q text := '%' || lower(btrim(coalesce(p_search, ''))) || '%';
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id, 'full_name', p.full_name, 'avatar_url', p.avatar_url, 'email', u.email, 'points', p.points,
      'is_admin', p.is_admin, 'suspended', p.suspended_at is not null, 'created_at', p.created_at,
      'last_seen', u.last_sign_in_at) order by p.created_at desc)
    from (select p.* from public.profiles p join auth.users u on u.id = p.id
          where (lower(p.full_name) like q or lower(u.email) like q)
            and case p_filter when 'suspended' then p.suspended_at is not null
                              when 'admins' then p.is_admin
                              when 'active' then p.suspended_at is null and not p.is_admin
                              else true end
          order by p.created_at desc
          limit least(greatest(p_limit, 1), 100) offset greatest(p_offset, 0)) p
    join auth.users u on u.id = p.id), '[]'::jsonb);
end;
$$;

create or replace function public.admin_user_detail(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public._require_admin(); p public.profiles; u record;
begin
  select * into p from public.profiles where id = p_user;
  if p.id is null then raise exception 'This member no longer exists.' using errcode = 'P0001'; end if;
  select email, last_sign_in_at, email_confirmed_at into u from auth.users where id = p_user;
  return jsonb_build_object(
    'profile', jsonb_build_object('id', p.id, 'full_name', p.full_name, 'avatar_url', p.avatar_url, 'points', p.points,
                                  'is_admin', p.is_admin, 'suspended', p.suspended_at is not null,
                                  'suspended_reason', p.suspended_reason, 'suspended_at', p.suspended_at,
                                  'created_at', p.created_at, 'email', u.email, 'last_seen', u.last_sign_in_at,
                                  'verified_at', u.email_confirmed_at),
    'stats', jsonb_build_object(
      'streak', public._streak(p_user),
      'missions', (select count(*) from public.mission_completions where user_id = p_user),
      'quizzes', (select count(*) from public.quiz_sessions where user_id = p_user and finished_at is not null),
      'correct_answers', (select count(*) from public.quiz_session_items i join public.quiz_sessions s on s.id = i.session_id
                          where s.user_id = p_user and i.correct),
      'scans', (select count(*) from public.waste_scans where user_id = p_user),
      'disposals', (select count(*) from public.waste_scans where user_id = p_user and disposed_at is not null),
      'stories_read', (select count(*) from public.news_reads where user_id = p_user),
      'posts', (select count(*) from public.community_posts where user_id = p_user),
      'comments', (select count(*) from public.post_comments where user_id = p_user),
      'ratings_given', (select count(*) from public.post_ratings where user_id = p_user),
      'ratings_received', (select coalesce(sum(rating_count), 0) from public.community_posts where user_id = p_user)),
    'points', coalesce((select jsonb_agg(jsonb_build_object('amount', amount, 'reason', reason, 'note', note, 'created_at', created_at)
                         order by created_at desc)
                       from (select * from public.point_events where user_id = p_user order by created_at desc limit 25) e), '[]'::jsonb),
    'posts', coalesce((select jsonb_agg(public._post_json(c, uid) order by c.created_at desc)
                      from (select * from public.community_posts where user_id = p_user order by created_at desc limit 12) c), '[]'::jsonb));
end;
$$;

create or replace function public.admin_set_suspended(p_user uuid, p_suspended boolean, p_reason text default '')
returns void language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_admin(); target public.profiles;
begin
  select * into target from public.profiles where id = p_user;
  if target.id is null then raise exception 'This member no longer exists.' using errcode = 'P0001'; end if;
  if target.id = uid or target.is_admin then raise exception 'Admins cannot be suspended.' using errcode = 'P0001'; end if;
  update public.profiles set suspended_at = case when p_suspended then now() end,
         suspended_reason = case when p_suspended then left(btrim(coalesce(p_reason, '')), 300) end
  where id = p_user;
  -- also blocks sign-in and token refresh
  update auth.users set banned_until = case when p_suspended then 'infinity'::timestamptz end where id = p_user;
end;
$$;

create or replace function public.admin_delete_user(p_user uuid)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_admin(); target public.profiles;
begin
  select * into target from public.profiles where id = p_user;
  if target.id is null then return; end if;
  if target.id = uid or target.is_admin then raise exception 'Admins cannot be deleted here.' using errcode = 'P0001'; end if;
  delete from auth.users where id = p_user;
end;
$$;

create or replace function public.admin_adjust_points(p_user uuid, p_points integer, p_reason text)
returns integer language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_admin(); v_reason text := left(btrim(coalesce(p_reason, '')), 200); v_points integer;
begin
  if p_points is null or p_points = 0 or p_points not between -1000 and 1000 then
    raise exception 'Points must be between -1000 and 1000.' using errcode = 'P0001';
  end if;
  if char_length(v_reason) < 3 then raise exception 'Add a short reason.' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.profiles where id = p_user) then
    raise exception 'This member no longer exists.' using errcode = 'P0001';
  end if;
  perform public._award_points(p_user, p_points, case when p_points > 0 then 'admin_grant' else 'admin_deduct' end, v_reason, uid);
  perform public._notify(p_user, case when p_points > 0 then 'points_granted' else 'points_removed' end, null, null,
                         jsonb_build_object('points', abs(p_points), 'reason', v_reason));
  select points into v_points from public.profiles where id = p_user;
  return v_points;
end;
$$;

-- Kept for older app versions.
create or replace function public.admin_grant_points(p_email text, p_points integer, p_reason text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_admin(); target uuid; target_name text;
begin
  select id into target from auth.users where lower(email) = lower(btrim(p_email));
  if target is null then raise exception 'No member uses that email.' using errcode = 'P0001'; end if;
  perform public.admin_adjust_points(target, p_points, p_reason);
  select full_name into target_name from public.profiles where id = target;
  return jsonb_build_object('ok', true, 'member', target_name);
end;
$$;

create or replace function public.admin_posts(p_limit integer default 20, p_before timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public._require_admin();
begin
  return coalesce((
    select jsonb_agg(public._post_json(c, uid) || jsonb_build_object('author_email', u.email,
                     'author_suspended', pr.suspended_at is not null) order by c.created_at desc)
    from (select * from public.community_posts where p_before is null or created_at < p_before
          order by created_at desc limit least(greatest(p_limit, 1), 50)) c
    join public.profiles pr on pr.id = c.user_id
    join auth.users u on u.id = c.user_id), '[]'::jsonb);
end;
$$;

create or replace function public.admin_delete_post(p_post_id uuid, p_reason text default '')
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_admin(); post public.community_posts;
begin
  select * into post from public.community_posts where id = p_post_id;
  if post.id is null then return jsonb_build_object('deleted', false); end if;
  delete from public.community_posts where id = post.id;
  perform public._notify(post.user_id, 'post_removed', null, null,
                         jsonb_build_object('caption', left(post.caption, 120), 'reason', left(btrim(coalesce(p_reason, '')), 200)));
  return jsonb_build_object('deleted', true, 'image_path', post.image_path, 'user_id', post.user_id);
end;
$$;

create or replace function public.admin_translate(p_text text, p_from text, p_to text)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_admin(); r text[];
begin
  if p_from not in ('en', 'rw') or p_to not in ('en', 'rw') or p_from = p_to then
    raise exception 'Choose English or Kinyarwanda.' using errcode = 'P0001';
  end if;
  if char_length(btrim(coalesce(p_text, ''))) = 0 then return ''; end if;
  -- keep paragraphs: translate line by line
  r := public._translate(regexp_split_to_array(left(p_text, 4000), E'\n'), p_from, p_to);
  if r is null then raise exception 'Translation is not available right now. Try again.' using errcode = 'P0002'; end if;
  return array_to_string(r, E'\n');
end;
$$;

create or replace function public.admin_post_announcement(p_title_en text, p_body_en text, p_title_rw text, p_body_rw text,
                                                          p_send_email boolean default false)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid  uuid := public._require_admin();
  t_en text := left(btrim(coalesce(p_title_en, '')), 120);
  b_en text := left(btrim(coalesce(p_body_en, '')), 2000);
  t_rw text := left(btrim(coalesce(p_title_rw, '')), 120);
  b_rw text := left(btrim(coalesce(p_body_rw, '')), 2000);
  tr   text[];
  aid  uuid;
  n    integer;
  r    record;
begin
  if (t_en = '' or b_en = '') and (t_rw = '' or b_rw = '') then
    raise exception 'Write a title and a message.' using errcode = 'P0001';
  end if;
  -- fill a missing language automatically
  if t_rw = '' or b_rw = '' then
    tr := public._translate(array[t_en, b_en], 'en', 'rw');
    t_rw := coalesce(nullif(t_rw, ''), tr[1], t_en); b_rw := coalesce(nullif(b_rw, ''), tr[2], b_en);
  elsif t_en = '' or b_en = '' then
    tr := public._translate(array[t_rw, b_rw], 'rw', 'en');
    t_en := coalesce(nullif(t_en, ''), tr[1], t_rw); b_en := coalesce(nullif(b_en, ''), tr[2], b_rw);
  end if;

  insert into public.announcements (title_en, body_en, title_rw, body_rw, emailed, created_by)
  values (t_en, b_en, t_rw, b_rw, coalesce(p_send_email, false), uid) returning id into aid;

  insert into public.notifications (user_id, kind, actor_id, data)
  select p.id, 'announcement', uid, jsonb_build_object('announcement_id', aid, 'title_en', t_en, 'body_en', b_en, 'title_rw', t_rw, 'body_rw', b_rw)
  from public.profiles p where p.suspended_at is null and p.id <> uid;
  get diagnostics n = row_count;
  update public.announcements set recipients = n where id = aid;

  if coalesce(p_send_email, false) then
    for r in select u.id, u.email, coalesce(u.raw_user_meta_data, '{}') as meta
             from auth.users u join public.profiles p on p.id = u.id
             where p.suspended_at is null and not p.is_admin and u.email is not null
               and coalesce(u.raw_user_meta_data ->> 'email_updates', 'true') <> 'false' loop
      perform public._queue_email(r.id, r.email, 'announcement',
        jsonb_build_object('name', public._display_name(r.meta, r.email), 'lang', public._user_lang(r.meta),
                           'title', case when public._user_lang(r.meta) = 'rw' then t_rw else t_en end,
                           'body', case when public._user_lang(r.meta) = 'rw' then b_rw else b_en end),
        'announcement:' || aid || ':' || r.id);
    end loop;
  end if;
  return jsonb_build_object('id', aid, 'recipients', n, 'title_en', t_en, 'title_rw', t_rw, 'body_en', b_en, 'body_rw', b_rw);
end;
$$;

create or replace function public.admin_announcements(p_limit integer default 30)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public._require_admin();
begin
  return coalesce((select jsonb_agg(to_jsonb(a) order by a.created_at desc)
                   from (select * from public.announcements order by created_at desc limit least(greatest(p_limit, 1), 100)) a), '[]'::jsonb);
end;
$$;

create or replace function public.admin_delete_announcement(p_id uuid)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_admin();
begin
  delete from public.notifications where kind = 'announcement' and data ->> 'announcement_id' = p_id::text;
  delete from public.announcements where id = p_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- 12d. App updates: the latest Android release (the app shows "Update available")
-- ----------------------------------------------------------------------------
create table if not exists public.app_releases (
  platform          text primary key check (platform in ('android', 'ios')),
  version_code      integer not null,
  version_name      text not null,
  download_url      text not null,
  min_version_code  integer not null default 0,   -- older builds must update (forced)
  notes_en          text not null default '',
  notes_rw          text not null default '',
  released_at       timestamptz not null default now()
);
alter table public.app_releases enable row level security;
drop policy if exists "releases readable" on public.app_releases;
create policy "releases readable" on public.app_releases for select to anon, authenticated using (true);
grant select on public.app_releases to anon, authenticated;

-- ----------------------------------------------------------------------------
-- 12c. Emails: welcome, password changed, streak milestones, announcements, goodbye
--   Events are written to email_outbox; pg_net pings the ecofun-mailer Edge Function, which
--   sends them through Gmail SMTP. A cron job retries anything that failed.
--   (Sign-up / reset codes are sent by Supabase Auth itself, through the same Gmail account.)
-- ----------------------------------------------------------------------------
create table if not exists public.email_outbox (
  id          bigint generated always as identity primary key,
  user_id     uuid references auth.users (id) on delete set null,
  to_email    text not null,
  kind        text not null,
  data        jsonb not null default '{}',
  dedupe_key  text unique,
  status      text not null default 'pending' check (status in ('pending', 'sending', 'sent', 'failed')),
  attempts    integer not null default 0,
  last_error  text,
  created_at  timestamptz not null default now(),
  claimed_at  timestamptz,
  sent_at     timestamptz
);
alter table public.email_outbox drop constraint if exists email_outbox_kind_check;
alter table public.email_outbox add constraint email_outbox_kind_check
  check (kind in ('welcome', 'password_changed', 'streak', 'goodbye', 'announcement'));
create index if not exists email_outbox_open_idx on public.email_outbox (id) where status <> 'sent';
alter table public.email_outbox enable row level security;   -- no policies: app users can't see it
revoke all on public.email_outbox from anon, authenticated;

create or replace function public._user_lang(p_meta jsonb)
returns text language sql immutable set search_path = '' as $$
  select case when p_meta ->> 'lang' = 'rw' then 'rw' else 'en' end;
$$;

create or replace function public._display_name(p_meta jsonb, p_email text)
returns text language sql immutable set search_path = '' as $$
  select left(coalesce(nullif(trim(p_meta ->> 'full_name'), ''), nullif(trim(p_meta ->> 'name'), ''),
                       split_part(p_email, '@', 1), 'EcoFun member'), 80);
$$;

-- Wakes the Edge Function (async; the request leaves only after the transaction commits).
create or replace function public._kick_mailer()
returns void language plpgsql volatile security definer set search_path = '' as $$
declare v_url text; v_secret text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'mailer_url' limit 1;
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'mailer_secret' limit 1;
  if coalesce(v_url, '') = '' or coalesce(v_secret, '') = '' then return; end if;
  perform net.http_post(
    url := v_url,
    body := '{}'::jsonb,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-mailer-secret', v_secret),
    timeout_milliseconds := 30000);
exception when others then
  raise warning 'EcoFun mailer ping failed: %', sqlerrm;
end;
$$;

-- Never raises: an email problem must not block sign-up, password changes or missions.
create or replace function public._queue_email(p_user uuid, p_to text, p_kind text, p_data jsonb, p_dedupe text default null)
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  if p_to is null or position('@' in p_to) = 0 then return; end if;
  if lower(p_to) like '%@ecofun.com' then return; end if;   -- built-in staff accounts have no real inbox
  insert into public.email_outbox (user_id, to_email, kind, data, dedupe_key)
  values (p_user, lower(p_to), p_kind, coalesce(p_data, '{}'), p_dedupe)
  on conflict (dedupe_key) do nothing;
  if found then perform public._kick_mailer(); end if;
exception when others then
  raise warning 'EcoFun email (%) not queued: %', p_kind, sqlerrm;
end;
$$;

create or replace function public._on_auth_user_mail()
returns trigger language plpgsql security definer set search_path = '' as $$
declare meta jsonb;
begin
  if tg_op = 'DELETE' then
    if old.email is not null and old.email_confirmed_at is not null then
      meta := coalesce(old.raw_user_meta_data, '{}');
      perform public._queue_email(null, old.email, 'goodbye',
        jsonb_build_object('name', public._display_name(meta, old.email), 'lang', public._user_lang(meta)),
        'goodbye:' || old.id);
    end if;
    return old;
  end if;

  meta := coalesce(new.raw_user_meta_data, '{}');
  if new.email_confirmed_at is not null and (tg_op = 'INSERT' or old.email_confirmed_at is null) then
    perform public._queue_email(new.id, new.email, 'welcome',
      jsonb_build_object('name', public._display_name(meta, new.email), 'lang', public._user_lang(meta)),
      'welcome:' || new.id);
  end if;
  if tg_op = 'UPDATE' and new.email_confirmed_at is not null
     and coalesce(old.encrypted_password, '') <> ''
     and new.encrypted_password is distinct from old.encrypted_password then
    perform public._queue_email(new.id, new.email, 'password_changed',
      jsonb_build_object('name', public._display_name(meta, new.email), 'lang', public._user_lang(meta),
                         'email', new.email, 'at', now()),
      'password:' || new.id || ':' || floor(extract(epoch from now()) / 60)::bigint);
  end if;
  return new;
exception when others then
  raise warning 'EcoFun auth email trigger: %', sqlerrm;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists on_auth_user_mail on auth.users;
create trigger on_auth_user_mail
  after insert or update of email_confirmed_at, encrypted_password or delete on auth.users
  for each row execute function public._on_auth_user_mail();

-- Streak milestones after a mission (members can switch these off in Profile → Email updates).
create or replace function public._on_mission_mail()
returns trigger language plpgsql security definer set search_path = '' as $$
declare s integer; u record; pts integer;
begin
  s := public._streak(new.user_id);
  if s in (3, 7, 14, 30, 50, 100, 200, 365) then
    select email, coalesce(raw_user_meta_data, '{}') as meta into u from auth.users where id = new.user_id;
    if u.email is not null and coalesce(u.meta ->> 'email_updates', 'true') <> 'false' then
      select points into pts from public.profiles where id = new.user_id;
      perform public._queue_email(new.user_id, u.email, 'streak',
        jsonb_build_object('name', public._display_name(u.meta, u.email), 'lang', public._user_lang(u.meta),
                           'streak', s, 'points', coalesce(pts, 0)),
        'streak:' || new.user_id || ':' || s || ':' || public.eco_today());
    end if;
  end if;
  return new;
exception when others then
  raise warning 'EcoFun streak email: %', sqlerrm;
  return new;
end;
$$;

drop trigger if exists mission_completions_mail on public.mission_completions;
create trigger mission_completions_mail after insert on public.mission_completions
  for each row execute function public._on_mission_mail();

-- Used only by the ecofun-mailer Edge Function, which proves itself with the shared secret.
create or replace function public._mailer_secret_ok(p_secret text)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare v text;
begin
  select decrypted_secret into v from vault.decrypted_secrets where name = 'mailer_secret' limit 1;
  return coalesce(v, '') <> '' and p_secret is not null and p_secret = v;
end;
$$;

create or replace function public.mailer_claim(p_secret text, p_limit integer default 20)
returns setof public.email_outbox language plpgsql volatile security definer set search_path = '' as $$
begin
  if not public._mailer_secret_ok(p_secret) then
    raise exception 'Not allowed.' using errcode = '42501';
  end if;
  return query
  with claimed as (
  update public.email_outbox o
     set status = 'sending', attempts = o.attempts + 1, claimed_at = now()
   where o.id in (
     select e.id from public.email_outbox e
      where e.status = 'pending'
         or (e.status in ('sending', 'failed') and e.attempts < 5 and e.claimed_at < now() - interval '10 minutes')
      order by e.id
      limit least(greatest(coalesce(p_limit, 20), 1), 50)
      for update skip locked)
  returning o.*)
  select * from claimed;
end;
$$;

create or replace function public.mailer_done(p_secret text, p_id bigint, p_error text default null)
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  if not public._mailer_secret_ok(p_secret) then
    raise exception 'Not allowed.' using errcode = '42501';
  end if;
  update public.email_outbox
     set status = case when p_error is null then 'sent' else 'failed' end,
         sent_at = case when p_error is null then now() end,
         last_error = left(p_error, 500)
   where id = p_id;
end;
$$;

-- Every 10 minutes: retry anything unsent, and forget sent emails after 30 days.
create or replace function public._mailer_cron()
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  delete from public.email_outbox where status = 'sent' and sent_at < now() - interval '30 days';
  if exists (select 1 from public.email_outbox
              where status = 'pending'
                 or (status in ('sending', 'failed') and attempts < 5 and claimed_at < now() - interval '10 minutes')) then
    perform public._kick_mailer();
  end if;
end;
$$;

-- ----------------------------------------------------------------------------
-- 13. Function privileges: only the public API is callable by signed-in users
-- ----------------------------------------------------------------------------
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname like '\_%' loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
  end loop;
end $$;
revoke all on function public.refresh_news() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;

grant execute on function public.eco_today() to anon, authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.get_home() to authenticated;
grant execute on function public.mark_news_read(text) to authenticated;
grant execute on function public.get_quiz(text) to authenticated;
grant execute on function public.answer_quiz(uuid, integer, integer) to authenticated;
grant execute on function public.finish_quiz(uuid) to authenticated;
grant execute on function public.classify_waste(text, text, text, text) to authenticated;
grant execute on function public.confirm_disposal(uuid, text, text, text, text) to authenticated;
grant execute on function public.complete_mission(text, text, uuid) to authenticated;
grant execute on function public.create_post(text, text) to authenticated;
grant execute on function public.get_feed(integer, timestamptz) to authenticated;
grant execute on function public.get_post(uuid) to authenticated;
grant execute on function public.rate_post(uuid, integer) to authenticated;
grant execute on function public.get_comments(uuid) to authenticated;
grant execute on function public.add_comment(uuid, text) to authenticated;
grant execute on function public.delete_comment(uuid) to authenticated;
grant execute on function public.get_leaderboard(integer) to authenticated;
grant execute on function public.get_notifications(integer, timestamptz) to authenticated;
grant execute on function public.mark_notifications_read(bigint[]) to authenticated;
grant execute on function public.clear_notifications() to authenticated;
grant execute on function public.delete_my_account() to authenticated;
grant execute on function public.admin_dashboard() to authenticated;
grant execute on function public.admin_users(text, text, integer, integer) to authenticated;
grant execute on function public.admin_user_detail(uuid) to authenticated;
grant execute on function public.admin_set_suspended(uuid, boolean, text) to authenticated;
grant execute on function public.admin_delete_user(uuid) to authenticated;
grant execute on function public.admin_adjust_points(uuid, integer, text) to authenticated;
grant execute on function public.admin_grant_points(text, integer, text) to authenticated;
grant execute on function public.admin_posts(integer, timestamptz) to authenticated;
grant execute on function public.admin_delete_post(uuid, text) to authenticated;
grant execute on function public.admin_translate(text, text, text) to authenticated;
grant execute on function public.admin_post_announcement(text, text, text, text, boolean) to authenticated;
grant execute on function public.admin_announcements(integer) to authenticated;
grant execute on function public.admin_delete_announcement(uuid) to authenticated;
-- The mailer functions check the shared secret themselves.
grant execute on function public.mailer_claim(text, integer) to anon, authenticated, service_role;
grant execute on function public.mailer_done(text, bigint, text) to anon, authenticated, service_role;
revoke execute on function public.get_home(), public.mark_news_read(text), public.get_quiz(text),
  public.answer_quiz(uuid, integer, integer), public.finish_quiz(uuid), public.classify_waste(text, text, text, text),
  public.complete_mission(text, text, uuid), public.create_post(text, text), public.get_feed(integer, timestamptz),
  public.rate_post(uuid, integer), public.admin_grant_points(text, integer, text), public.delete_my_account()
  from public, anon;

-- ----------------------------------------------------------------------------
-- 14. Seed content: missions and the fallback quiz bank
-- ----------------------------------------------------------------------------
insert into public.missions (icon, title_en, title_rw, description_en, description_rw, points, needs_scan) values
  ('🗑️', 'Sort your household waste', 'Vangura imyanda yo mu rugo',
   'Separate today''s waste into biodegradable and non-biodegradable. Snap a photo of one item — EcoFun''s AI will check its type.',
   'Tandukanya imyanda y''uyu munsi: ibora n''itabora. Fata ifoto y''ikintu kimwe — AI ya EcoFun irakubwira ubwoko bwacyo.', 25, true),
  ('🛍️', 'Say no to a plastic bag', 'Anga isashe ya pulasitiki',
   'Carry a reusable bag or basket when you shop today. Rwanda banned single-use plastic bags in 2008 — keep it that way.',
   'Jyana igikapu cyangwa agaseke uyu munsi uhaha. U Rwanda rwaciye amasashe mu 2008 — dukomeze kubyubahiriza.', 20, false),
  ('🍌', 'Start a compost pile', 'Tangira ikimoteri cy''ifumbire',
   'Collect fruit peels, vegetable scraps and leaves in one corner or bucket to turn them into compost. Photograph your pile.',
   'Kusanya ibishishwa by''imbuto, imboga n''amababi ahantu hamwe kugira ngo bibe ifumbire. Fata ifoto yabyo.', 25, true),
  ('🚰', 'Save water today', 'Zigama amazi uyu munsi',
   'Close the tap while brushing or washing dishes, and reuse rinse water for plants. Show us how you saved water.',
   'Funga robine wiyoza amenyo cyangwa woza ibikoresho, kandi wongere ukoreshe amazi wuhira ibimera. Twereke uko wazigamye amazi.', 20, false),
  ('🌳', 'Care for a tree', 'Ita ku giti',
   'Plant a seedling or water a young tree near your home or school. Trees protect Rwanda''s hills from erosion.',
   'Tera ingemwe cyangwa wuhire igiti gikiri gito hafi y''urugo cyangwa ishuri. Ibiti birinda imisozi y''u Rwanda isuri.', 30, false),
  ('🧴', 'Give a bottle a second life', 'Ha icupa ubuzima bushya',
   'Reuse a plastic bottle or jar — as a plant pot, water container or storage. Snap it so the AI can identify the material.',
   'Ongera ukoreshe icupa cyangwa ikibindi — nk''inkono y''ururabo cyangwa ububiko. Gifotore AI imenye icyo gikozwemo.', 20, true),
  ('💡', 'Switch it off', 'Zimya ibidakoreshwa',
   'Turn off lights, chargers and devices you are not using today. Photograph a switch you turned off.',
   'Zimya amatara, chargeurs n''ibikoresho udakoresha uyu munsi. Fotora umuriro wazimije.', 15, false),
  ('🧹', 'Clean up your street', 'Sukura aho utuye',
   'Pick up litter around your home, like during Umuganda. Sort what you collect and scan one item.',
   'Tora imyanda iri hafi y''urugo nk''uko bigenda mu Muganda. Vangura ibyo watoraguye maze usuzume kimwe.', 30, true),
  ('🚶', 'Walk or share a ride', 'Genda n''amaguru cyangwa musangire imodoka',
   'Walk, cycle or take the bus for one trip instead of a private car or moto. Share a photo of your green trip.',
   'Genda n''amaguru, igare cyangwa bisi aho gukoresha imodoka yawe cyangwa moto. Sangiza ifoto y''urugendo rwawe.', 20, false),
  ('🥕', 'Eat local, waste less', 'Rya ibyo iwacu, ntutaye ibiryo',
   'Cook with local produce and finish your leftovers today. Peels go to compost, not the street.',
   'Teka ukoresheje ibihingwa by''iwacu kandi urye ibisigaye. Ibishishwa bijye mu ifumbire, si mu muhanda.', 20, true)
on conflict (title_en) do update set icon = excluded.icon, title_rw = excluded.title_rw,
  description_en = excluded.description_en, description_rw = excluded.description_rw,
  points = excluded.points, needs_scan = excluded.needs_scan;

insert into public.quiz_bank (language, question, options, correct_index, explanation) values
  ('en', 'Which of these is biodegradable?', array['Banana peel', 'Plastic bottle', 'Glass jar', 'Aluminium can'], 0, 'Banana peels are organic and break down in a few weeks.'),
  ('en', 'In which year did Rwanda ban single-use plastic bags?', array['1994', '2008', '2015', '2020'], 1, 'Rwanda banned non-biodegradable plastic bags in 2008.'),
  ('en', 'What is the safest way to deal with plastic waste at home?', array['Burn it', 'Bury it in the garden', 'Separate it for collection or recycling', 'Throw it in a river'], 2, 'Burning plastic releases toxic smoke; separating it lets it be recycled.'),
  ('en', 'Why do trees help Rwanda''s hills?', array['They make soil slippery', 'Their roots hold soil and reduce erosion', 'They stop all rain', 'They raise temperatures'], 1, 'Roots bind the soil, which reduces erosion and landslides.'),
  ('en', 'Which gas is the main driver of human-caused climate change?', array['Oxygen', 'Nitrogen', 'Carbon dioxide', 'Helium'], 2, 'Burning fuels releases CO₂, which traps heat in the atmosphere.'),
  ('en', 'How long can a plastic bottle take to break down?', array['About a week', 'About a year', 'Around 10 years', 'Hundreds of years'], 3, 'Plastic bottles can persist for 450 years or more.'),
  ('en', 'What can kitchen scraps like peels become?', array['Compost that feeds soil', 'Fuel for cars', 'Plastic', 'Glass'], 0, 'Composting turns food scraps into natural fertilizer.'),
  ('en', 'What is Umuganda?', array['A national park', 'Monthly community work day', 'A type of tree', 'A recycling machine'], 1, 'On the last Saturday of each month Rwandans work together, often cleaning and planting.'),
  ('en', 'Which energy source is renewable?', array['Diesel', 'Coal', 'Solar power', 'Petrol'], 2, 'Sunlight is replenished every day, so solar power is renewable.'),
  ('en', 'Which item should never go in a compost pile?', array['Leaves', 'Vegetable peels', 'Batteries', 'Eggshells'], 2, 'Batteries contain toxic metals and need special collection.'),
  ('en', 'What makes flooding worse in cities?', array['Parks and trees', 'Paved surfaces and blocked drains', 'Wetlands', 'Gardens'], 1, 'Water cannot soak into paved ground, and blocked drains overflow.'),
  ('en', 'Why are wetlands like Nyandungu in Kigali important?', array['They store floodwater and shelter wildlife', 'They produce plastic', 'They cause droughts', 'They are only for parking'], 0, 'Wetlands absorb floodwater, filter water and support biodiversity.'),
  ('en', 'Which habit saves the most water?', array['Leaving the tap running', 'Closing the tap while brushing teeth', 'Washing a car daily', 'Long showers'], 1, 'Closing the tap can save several litres every time you brush.'),
  ('en', 'What does "recycling" mean?', array['Throwing waste away', 'Turning used materials into new products', 'Burning waste', 'Burying waste'], 1, 'Recycling processes used materials so they can be made into something new.'),
  ('en', 'Which of these is non-biodegradable?', array['Paper bag', 'Leaves', 'Styrofoam cup', 'Orange peel'], 2, 'Styrofoam is a plastic foam that does not break down naturally.'),
  ('rw', 'Ni ikihe muri ibi kibora?', array['Igishishwa cy''umuneke', 'Icupa rya pulasitiki', 'Ikirahure', 'Agacupa k''icyuma'], 0, 'Igishishwa cy''umuneke ni ikinyabuzima kibora mu byumweru bike.'),
  ('rw', 'U Rwanda rwaciye amasashe ya pulasitiki mu wuhe mwaka?', array['1994', '2008', '2015', '2020'], 1, 'U Rwanda rwaciye amasashe atabora mu 2008.'),
  ('rw', 'Ni ubuhe buryo bwiza bwo gucunga imyanda ya pulasitiki mu rugo?', array['Kuyitwika', 'Kuyitaba mu murima', 'Kuyitandukanya ikajyanwa gutunganywa', 'Kuyijugunya mu mugezi'], 2, 'Gutwika pulasitiki bitera umwotsi w''uburozi; kuyitandukanya bituma itunganywa.'),
  ('rw', 'Kuki ibiti bifasha imisozi y''u Rwanda?', array['Bituma ubutaka bunyerera', 'Imizi yabyo ifata ubutaka ikagabanya isuri', 'Bihagarika imvura yose', 'Byongera ubushyuhe'], 1, 'Imizi ifata ubutaka, bikagabanya isuri n''inkangu.'),
  ('rw', 'Ibishishwa byo mu gikoni bishobora kuvamo iki?', array['Ifumbire', 'Lisansi', 'Pulasitiki', 'Ikirahure'], 0, 'Ibishishwa bivamo ifumbire y''umwimerere.'),
  ('rw', 'Umuganda ni iki?', array['Pariki y''igihugu', 'Umunsi w''ibikorwa rusange buri kwezi', 'Ubwoko bw''igiti', 'Imashini itunganya imyanda'], 1, 'Ku wa Gatandatu wa nyuma wa buri kwezi abanyarwanda bakorera hamwe, akenshi basukura cyangwa batera ibiti.'),
  ('rw', 'Ni iyihe ngufu zisubira?', array['Mazutu', 'Amakara', 'Ingufu z''izuba', 'Lisansi'], 2, 'Izuba rirasa buri munsi, bityo ingufu zaryo zirisubira.'),
  ('rw', 'Ni ikihe kintu kitagomba kujya mu ifumbire?', array['Amababi', 'Ibishishwa by''imboga', 'Amabuye ya radiyo (batiri)', 'Ibishishwa by''amagi'], 2, 'Batiri zirimo ibyuma by''uburozi zikeneye gukusanywa ukwazo.'),
  ('rw', 'Ni iyihe ngeso izigama amazi menshi?', array['Gusiga robine ifunguye', 'Gufunga robine wiyoza amenyo', 'Koza imodoka buri munsi', 'Kwiyuhagira igihe kirekire'], 1, 'Gufunga robine bizigama litiro nyinshi buri gihe wiyoza amenyo.'),
  ('rw', 'Ni ikihe muri ibi kitabora?', array['Isashe y''impapuro', 'Amababi', 'Igikombe cya sitiropore', 'Igishishwa cy''icunga'], 2, 'Sitiropore ni pulasitiki itabora.')
on conflict (question) do nothing;

-- Seed the pool with the hand-written starter questions (English + Kinyarwanda pairs).
insert into public.quiz_pool (topic, difficulty, question_en, choices_en, explanation_en, question_rw, choices_rw, explanation_rw, answer, source, fingerprint)
select 'starter', 'easy', e.question, e.options, e.explanation, r.question, r.options, r.explanation, e.correct_index, 'bank',
       public._quiz_fingerprint(e.question)
from (select *, row_number() over (order by id) as n from public.quiz_bank where language = 'en') e
join (select *, row_number() over (order by id) as n from public.quiz_bank where language = 'rw') r on r.n = e.n
where e.correct_index = r.correct_index
on conflict (fingerprint) do nothing;

-- ----------------------------------------------------------------------------
-- 15. Scheduled jobs: news (hourly), email retries, quiz questions, unverified sign-up cleanup
-- ----------------------------------------------------------------------------
do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname in ('ecostep-refresh-news', 'ecofun-refresh-news');
  perform cron.schedule('ecofun-refresh-news', '7 * * * *', 'select public.refresh_news();');
  perform cron.unschedule(jobid) from cron.job where jobname = 'ecofun-mailer';
  perform cron.schedule('ecofun-mailer', '*/10 * * * *', 'select public._mailer_cron();');
  perform cron.unschedule(jobid) from cron.job where jobname = 'ecofun-quiz-pool';
  perform cron.schedule('ecofun-quiz-pool', '*/4 * * * *', 'select public._quiz_pool_tick();');
  perform cron.unschedule(jobid) from cron.job where jobname = 'ecofun-purge-unverified';
  perform cron.schedule('ecofun-purge-unverified', '*/15 * * * *', 'select public._purge_unverified();');
end $$;

-- ----------------------------------------------------------------------------
-- 16. One-time data fixes (safe to repeat)
-- ----------------------------------------------------------------------------
-- Scanning no longer earns points: remove old scan points and recount every balance from its history.
delete from public.point_events where reason = 'scan';
update public.profiles p set points = greatest(0, coalesce((select sum(amount) from public.point_events e where e.user_id = p.id), 0))
where p.points is distinct from greatest(0, coalesce((select sum(amount) from public.point_events e where e.user_id = p.id), 0));
-- Quizzes are practical now: remove the first generation of exam-style questions (and any with numbers or years).
delete from public.quiz_pool
where source = 'ai'
   or question_en ~ '[0-9]' or array_to_string(choices_en, ' ') ~ '[0-9]';
delete from public.quiz_sessions s
where s.finished_at is null and (select count(*) from public.quiz_session_items i where i.session_id = s.id) < 4;
-- The built-in admin account (created with the Auth admin API) is always an admin.
update public.profiles set is_admin = true, full_name = 'EcoFun Admin'
where id in (select id from auth.users where lower(email) = 'admin@ecofun.com') and not is_admin;
select public._purge_unverified() as unverified_removed;

-- Fill the news feed right now.
select public.refresh_news() as articles_saved;
