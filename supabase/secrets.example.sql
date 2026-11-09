-- Template for supabase/secrets.local.sql (that file is git-ignored).
-- Copy this file to secrets.local.sql, paste your NVIDIA API key (https://build.nvidia.com),
-- then run it in Supabase → SQL Editor after schema.sql.
do $$
declare existing uuid;
begin
  select id into existing from vault.secrets where name = 'nvidia_api_key';
  if existing is null then
    perform vault.create_secret('nvapi-YOUR-KEY-HERE', 'nvidia_api_key', 'NVIDIA API key for EcoStep AI');
  else
    perform vault.update_secret(existing, 'nvapi-YOUR-KEY-HERE', 'nvidia_api_key', 'NVIDIA API key for EcoStep AI');
  end if;
end $$;
