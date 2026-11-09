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

create table if not exists public.quizzes (
  id          uuid primary key default gen_random_uuid(),
  article_id  text,
  language    text not null default 'en',
  source      text not null check (source in ('ai', 'bank')),
  created_at  timestamptz not null default now()
);
create unique index if not exists quizzes_article_lang_idx on public.quizzes (article_id, language);

create table if not exists public.quiz_questions (
  quiz_id        uuid not null references public.quizzes (id) on delete cascade,
  position       integer not null,
  question       text not null,
  options        text[] not null check (array_length(options, 1) = 4),
  correct_index  integer not null check (correct_index between 0 and 3),
  explanation    text not null default '',
  primary key (quiz_id, position)
);

create table if not exists public.quiz_answers (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  quiz_id     uuid not null references public.quizzes (id) on delete cascade,
  position    integer not null,
  choice      integer not null check (choice between 0 and 3),
  correct     boolean not null,
  created_at  timestamptz not null default now(),
  primary key (user_id, quiz_id, position)
);

create table if not exists public.quiz_attempts (
  user_id         uuid not null references public.profiles (id) on delete cascade,
  day             date not null,
  quiz_id         uuid not null references public.quizzes (id) on delete cascade,
  score           integer not null,
  total           integer not null,
  points_awarded  integer not null,
  created_at      timestamptz not null default now(),
  primary key (user_id, day)
);

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
alter table public.quizzes              enable row level security;
alter table public.quiz_questions       enable row level security;
alter table public.quiz_answers         enable row level security;
alter table public.quiz_attempts        enable row level security;
alter table public.missions             enable row level security;
alter table public.waste_scans          enable row level security;
alter table public.mission_completions  enable row level security;
alter table public.community_posts      enable row level security;
alter table public.post_ratings         enable row level security;

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

drop policy if exists "own attempts" on public.quiz_attempts;
create policy "own attempts" on public.quiz_attempts for select to authenticated using (user_id = (select auth.uid()));

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
-- quiz_bank, quizzes, quiz_questions, quiz_answers, news_sources: no client policies (answers stay secret).

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

-- Policies from the app's earlier name (EcoStep), if an older version of this script ran.
drop policy if exists "ecostep upload own folder" on storage.objects;
drop policy if exists "ecostep update own avatar" on storage.objects;
drop policy if exists "ecostep read own private" on storage.objects;
drop policy if exists "ecostep delete own files" on storage.objects;

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
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    left(coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
                  nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
                  split_part(new.email, '@', 1),
                  'EcoFun member'), 80),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', new.raw_user_meta_data ->> 'picture')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill profiles for accounts created before this script ran.
insert into public.profiles (id, full_name)
select u.id, left(coalesce(nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''), split_part(u.email, '@', 1), 'EcoFun member'), 80)
from auth.users u
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
returns uuid language plpgsql stable set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Sign in to continue.' using errcode = '28000'; end if;
  return uid;
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
create or replace function public._nvidia_chat(p_model text, p_messages jsonb, p_max_tokens integer default 700, p_temperature numeric default 0.1)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  resp     record;
  v_content  text;
  body     jsonb;
begin
  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT', '45');
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
      'quizzes', (select count(*) from public.quiz_attempts where user_id = uid),
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
    -- the quiz follows the story read today, until the quiz is started
    article_id = case when public.daily_progress.quiz_id is null then excluded.article_id else public.daily_progress.article_id end,
    news_read_at = coalesce(public.daily_progress.news_read_at, now());
  return public.get_home();
end;
$$;

-- ----------------------------------------------------------------------------
-- 9. Quiz — questions written by AI from the article, graded only on the server
-- ----------------------------------------------------------------------------
create or replace function public._quiz_from_bank(p_language text, p_seed text)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare qid uuid; lang text := p_language;
begin
  if (select count(*) from public.quiz_bank where language = lang) < 5 then lang := 'en'; end if;
  insert into public.quizzes (article_id, language, source) values (null, p_language, 'bank') returning id into qid;
  insert into public.quiz_questions (quiz_id, position, question, options, correct_index, explanation)
  select qid, row_number() over () - 1, question, options, correct_index, explanation
  from (select * from public.quiz_bank where language = lang order by md5(p_seed || id::text) limit 5) b;
  return qid;
end;
$$;

create or replace function public._quiz_from_ai(p_article public.news_articles, p_language text)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare
  qid     uuid;
  result  jsonb;
  q       jsonb;
  pos     integer := 0;
  lang_name text := case when p_language = 'rw' then 'Kinyarwanda (simple, clear, natural Kinyarwanda used in Rwanda)' else 'English' end;
begin
  result := public._nvidia_chat(
    'nvidia/nemotron-3.5-lightning-30b-a3b',
    jsonb_build_array(
      jsonb_build_object('role', 'system', 'content',
        'You write short, fair multiple-choice quizzes for EcoFun, a climate-education app for people in Rwanda. ' ||
        'Every question must be answerable from the article text. Exactly one option is correct; the other three are plausible but clearly wrong. ' ||
        'Vary the position of the correct option. Never ask about the author, the website or publication dates. Reply with JSON only.'),
      jsonb_build_object('role', 'user', 'content',
        'Write 5 questions in ' || lang_name || ' about this article. ' ||
        'Return {"questions":[{"question":"...","options":["...","...","...","..."],"correct_index":0,"explanation":"one short sentence"}]}' ||
        E'\n\nTitle: ' || p_article.title || E'\n\nArticle:\n' || left(p_article.body, 6000))),
    1800, 0.3);

  if jsonb_typeof(result -> 'questions') <> 'array' or jsonb_array_length(result -> 'questions') < 3 then
    raise exception 'AI quiz had too few questions';
  end if;

  insert into public.quizzes (article_id, language, source) values (p_article.id, p_language, 'ai')
  on conflict (article_id, language) do nothing returning id into qid;
  if qid is null then   -- someone else generated it a moment ago
    select id into qid from public.quizzes where article_id = p_article.id and language = p_language;
    return qid;
  end if;

  for q in select * from jsonb_array_elements(result -> 'questions') loop
    exit when pos >= 5;
    if jsonb_typeof(q -> 'options') = 'array' and jsonb_array_length(q -> 'options') = 4
       and (q ->> 'correct_index') ~ '^[0-3]$' and length(coalesce(q ->> 'question', '')) between 5 and 400 then
      insert into public.quiz_questions (quiz_id, position, question, options, correct_index, explanation)
      values (qid, pos, q ->> 'question',
              array(select left(x, 200) from jsonb_array_elements_text(q -> 'options') x),
              (q ->> 'correct_index')::integer, left(coalesce(q ->> 'explanation', ''), 400));
      pos := pos + 1;
    end if;
  end loop;

  if pos < 3 then raise exception 'AI quiz questions were malformed'; end if;
  return qid;
end;
$$;

create or replace function public._quiz_payload(p_quiz uuid, p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'quiz_id', p_quiz,
    'source', (select source from public.quizzes where id = p_quiz),
    'questions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'position', q.position, 'question', q.question, 'options', to_jsonb(q.options),
        'answer', case when a.user_id is null then null else jsonb_build_object(
          'choice', a.choice, 'correct', a.correct, 'correct_index', q.correct_index, 'explanation', q.explanation) end)
        order by q.position)
      from public.quiz_questions q
      left join public.quiz_answers a on a.quiz_id = q.quiz_id and a.position = q.position and a.user_id = p_user
      where q.quiz_id = p_quiz), '[]'::jsonb));
$$;

create or replace function public.get_quiz(p_language text default 'en')
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid    uuid := public._require_user();
  today  date := public.eco_today();
  lang   text := case when p_language = 'rw' then 'rw' else 'en' end;
  p      public.daily_progress;
  art    public.news_articles;
  qid    uuid;
begin
  select * into p from public.daily_progress where user_id = uid and day = today;
  if p.news_read_at is null then
    raise exception 'Read today''s story first.' using errcode = 'P0001';
  end if;
  if p.quiz_completed_at is not null then
    return jsonb_build_object('completed', true, 'score', p.quiz_score, 'total', p.quiz_total);
  end if;

  qid := p.quiz_id;
  if qid is null then
    select * into art from public.news_articles where id = p.article_id;
    if art.id is not null then
      select id into qid from public.quizzes where article_id = art.id and language = lang;
      if qid is null and length(art.body) >= 200 then
        begin
          qid := public._quiz_from_ai(art, lang);
        exception when others then
          raise warning 'EcoFun AI quiz failed: %', sqlerrm;
          qid := null;
        end;
      end if;
    end if;
    if qid is null then qid := public._quiz_from_bank(lang, uid::text || today::text); end if;
    update public.daily_progress set quiz_id = qid where user_id = uid and day = today;
  end if;

  return jsonb_build_object('completed', false) || public._quiz_payload(qid, uid);
end;
$$;

create or replace function public.answer_quiz(p_quiz_id uuid, p_position integer, p_choice integer)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid  uuid := public._require_user();
  q    public.quiz_questions;
  a    public.quiz_answers;
begin
  if not exists (select 1 from public.daily_progress where user_id = uid and day = public.eco_today() and quiz_id = p_quiz_id) then
    raise exception 'This quiz is not available today.' using errcode = 'P0001';
  end if;
  if p_choice not between 0 and 3 then raise exception 'Choose one of the four answers.' using errcode = 'P0001'; end if;
  select * into q from public.quiz_questions where quiz_id = p_quiz_id and position = p_position;
  if q.quiz_id is null then raise exception 'Question not found.' using errcode = 'P0001'; end if;

  insert into public.quiz_answers (user_id, quiz_id, position, choice, correct)
  values (uid, p_quiz_id, p_position, p_choice, p_choice = q.correct_index)
  on conflict do nothing;
  select * into a from public.quiz_answers where user_id = uid and quiz_id = p_quiz_id and position = p_position;

  return jsonb_build_object('choice', a.choice, 'correct', a.correct, 'correct_index', q.correct_index, 'explanation', q.explanation);
end;
$$;

create or replace function public.finish_quiz(p_quiz_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid     uuid := public._require_user();
  today   date := public.eco_today();
  total   integer;
  answered integer;
  score   integer;
  pts     integer;
  existing public.quiz_attempts;
begin
  select * into existing from public.quiz_attempts where user_id = uid and day = today;
  if existing.user_id is not null then
    return jsonb_build_object('already_completed', true, 'score', existing.score, 'total', existing.total, 'points_awarded', 0);
  end if;
  if not exists (select 1 from public.daily_progress where user_id = uid and day = today and quiz_id = p_quiz_id) then
    raise exception 'This quiz is not available today.' using errcode = 'P0001';
  end if;

  select count(*) into total from public.quiz_questions where quiz_id = p_quiz_id;
  select count(*), count(*) filter (where correct) into answered, score
  from public.quiz_answers where user_id = uid and quiz_id = p_quiz_id;
  if answered < total then raise exception 'Answer every question first.' using errcode = 'P0001'; end if;

  pts := score * 5;
  insert into public.quiz_attempts (user_id, day, quiz_id, score, total, points_awarded)
  values (uid, today, p_quiz_id, score, total, pts);
  update public.daily_progress set quiz_completed_at = now(), quiz_score = score, quiz_total = total
  where user_id = uid and day = today;
  perform public._award_points(uid, pts, 'quiz', score || '/' || total);

  return jsonb_build_object('already_completed', false, 'score', score, 'total', total, 'points_awarded', pts);
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

  -- 2 points for each of the first 5 successful scans per day
  if cat <> 'uncertain' and today_scans < 5 then
    perform public._award_points(uid, 2, 'scan', scan.item);
  end if;

  return to_jsonb(scan) || jsonb_build_object('points_awarded', case when cat <> 'uncertain' and today_scans < 5 then 2 else 0 end);
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
  if p.quiz_completed_at is null then
    raise exception 'Finish today''s quiz first.' using errcode = 'P0001';
  end if;
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
  update public.daily_progress set mission_completed_at = now() where user_id = uid and day = today;
  perform public._award_points(uid, m.points, 'mission', m.title_en);

  return jsonb_build_object('points_awarded', m.points, 'streak', public._streak(uid));
end;
$$;

-- ----------------------------------------------------------------------------
-- 12. Community: posts, ratings, leaderboard, admin
-- ----------------------------------------------------------------------------
create or replace function public.create_post(p_image_path text, p_caption text default '')
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_user(); pid uuid;
begin
  if p_image_path is null or split_part(p_image_path, '/', 1) <> uid::text then
    raise exception 'Upload a photo first.' using errcode = 'P0001';
  end if;
  if (select count(*) from public.community_posts where user_id = uid and created_at > now() - interval '1 day') >= 10 then
    raise exception 'You can share up to 10 photos a day.' using errcode = 'P0001';
  end if;
  insert into public.community_posts (user_id, image_path, caption)
  values (uid, p_image_path, left(btrim(coalesce(p_caption, '')), 300)) returning id into pid;
  return pid;
end;
$$;

create or replace function public.get_feed(p_limit integer default 20, p_before timestamptz default null)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x order by (x ->> 'created_at') desc), '[]'::jsonb) from (
    select jsonb_build_object(
      'id', c.id, 'user_id', c.user_id, 'image_path', c.image_path, 'caption', c.caption,
      'rating_count', c.rating_count, 'rating_total', c.rating_total, 'created_at', c.created_at,
      'author_name', pr.full_name, 'author_avatar', pr.avatar_url,
      'my_rating', (select r.value from public.post_ratings r where r.post_id = c.id and r.user_id = auth.uid())) x
    from public.community_posts c
    join public.profiles pr on pr.id = c.user_id
    where auth.uid() is not null and (p_before is null or c.created_at < p_before)
    order by c.created_at desc
    limit least(greatest(p_limit, 1), 50)) t;
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
  perform public._award_points(post.user_id, 1, 'rating_received', p_value || ' stars');
  return jsonb_build_object('already_rated', false, 'rating_count', post.rating_count, 'rating_total', post.rating_total);
end;
$$;

create or replace function public.admin_grant_points(p_email text, p_points integer, p_reason text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_user(); target uuid; target_name text;
begin
  if not coalesce((select is_admin from public.profiles where id = uid), false) then
    raise exception 'Admin access is required.' using errcode = '42501';
  end if;
  if p_points is null or p_points not between 1 and 500 then
    raise exception 'Points must be between 1 and 500.' using errcode = 'P0001';
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 3 then
    raise exception 'Add a short reason.' using errcode = 'P0001';
  end if;
  select id into target from auth.users where lower(email) = lower(btrim(p_email));
  if target is null then raise exception 'No member uses that email.' using errcode = 'P0001'; end if;
  perform public._award_points(target, p_points, 'admin_grant', left(btrim(p_reason), 200), uid);
  select full_name into target_name from public.profiles where id = target;
  return jsonb_build_object('ok', true, 'member', target_name);
end;
$$;

create or replace function public.delete_my_account()
returns void language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := public._require_user();
begin
  delete from auth.users where id = uid;
end;
$$;

-- ----------------------------------------------------------------------------
-- 12b. Emails: welcome, password changed, streak milestones, goodbye
--   Events are written to email_outbox; pg_net pings the ecofun-mailer Edge Function, which
--   sends them through Gmail SMTP. A cron job retries anything that failed.
--   (Sign-up / reset codes are sent by Supabase Auth itself, through the same Gmail account.)
-- ----------------------------------------------------------------------------
create table if not exists public.email_outbox (
  id          bigint generated always as identity primary key,
  user_id     uuid references auth.users (id) on delete set null,
  to_email    text not null,
  kind        text not null check (kind in ('welcome', 'password_changed', 'streak', 'goodbye')),
  data        jsonb not null default '{}',
  dedupe_key  text unique,
  status      text not null default 'pending' check (status in ('pending', 'sending', 'sent', 'failed')),
  attempts    integer not null default 0,
  last_error  text,
  created_at  timestamptz not null default now(),
  claimed_at  timestamptz,
  sent_at     timestamptz
);
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
grant execute on function public.get_home() to authenticated;
grant execute on function public.mark_news_read(text) to authenticated;
grant execute on function public.get_quiz(text) to authenticated;
grant execute on function public.answer_quiz(uuid, integer, integer) to authenticated;
grant execute on function public.finish_quiz(uuid) to authenticated;
grant execute on function public.classify_waste(text, text, text, text) to authenticated;
grant execute on function public.complete_mission(text, text, uuid) to authenticated;
grant execute on function public.create_post(text, text) to authenticated;
grant execute on function public.get_feed(integer, timestamptz) to authenticated;
grant execute on function public.rate_post(uuid, integer) to authenticated;
grant execute on function public.admin_grant_points(text, integer, text) to authenticated;
grant execute on function public.delete_my_account() to authenticated;
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

-- ----------------------------------------------------------------------------
-- 15. Schedule the news refresh (hourly) and email retries, then fill the feed right now
-- ----------------------------------------------------------------------------
do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname in ('ecostep-refresh-news', 'ecofun-refresh-news');
  perform cron.schedule('ecofun-refresh-news', '7 * * * *', 'select public.refresh_news();');
  perform cron.unschedule(jobid) from cron.job where jobname = 'ecofun-mailer';
  perform cron.schedule('ecofun-mailer', '*/10 * * * *', 'select public._mailer_cron();');
end $$;

select public.refresh_news() as articles_saved;
