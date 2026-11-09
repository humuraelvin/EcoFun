-- Template for supabase/secrets.local.sql (that file is git-ignored).
-- Copy this file to secrets.local.sql, paste your NVIDIA API key (https://build.nvidia.com),
-- then run it in Supabase → SQL Editor after schema.sql.
do $$
declare existing uuid;
begin
  select id into existing from vault.secrets where name = 'nvidia_api_key';
  if existing is null then
    perform vault.create_secret('nvapi-YOUR-KEY-HERE', 'nvidia_api_key', 'NVIDIA API key for EcoFun AI');
  else
    perform vault.update_secret(existing, 'nvapi-YOUR-KEY-HERE', 'nvidia_api_key', 'NVIDIA API key for EcoFun AI');
  end if;
end $$;

-- Email sender (ecofun-mailer Edge Function). MAILER_SECRET must match the function's MAILER_SECRET secret.
do $$
declare existing uuid;
begin
  select id into existing from vault.secrets where name = 'mailer_url';
  if existing is null then
    perform vault.create_secret('https://YOUR-PROJECT.supabase.co/functions/v1/ecofun-mailer', 'mailer_url', 'EcoFun email sender URL');
  else
    perform vault.update_secret(existing, 'https://YOUR-PROJECT.supabase.co/functions/v1/ecofun-mailer', 'mailer_url', 'EcoFun email sender URL');
  end if;
  select id into existing from vault.secrets where name = 'mailer_secret';
  if existing is null then
    perform vault.create_secret('MAILER-SECRET-HERE', 'mailer_secret', 'Shared secret between Postgres and ecofun-mailer');
  else
    perform vault.update_secret(existing, 'MAILER-SECRET-HERE', 'mailer_secret', 'Shared secret between Postgres and ecofun-mailer');
  end if;
end $$;
