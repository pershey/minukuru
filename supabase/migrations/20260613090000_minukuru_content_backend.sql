create schema if not exists admin;

create extension if not exists pg_cron;

create table if not exists admin.runtime_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

insert into admin.runtime_config (key, value)
values (
  'content_publish_schedule',
  jsonb_build_object(
    'cron', '0 9 * * 1',
    'timezone', 'Asia/Tokyo'
  )
)
on conflict (key) do nothing;

create table if not exists admin.question_manifests (
  id uuid primary key default gen_random_uuid(),
  content_version text not null unique,
  storage_bucket text not null default 'minukuru-content',
  storage_path text not null,
  checksum text,
  status text not null check (status in ('draft', 'staged', 'published', 'archived')),
  release_at timestamptz,
  notes text,
  created_by uuid,
  approved_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists question_manifests_status_release_idx
  on admin.question_manifests (status, release_at);

create or replace function admin.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists question_manifests_touch_updated_at on admin.question_manifests;
create trigger question_manifests_touch_updated_at
before update on admin.question_manifests
for each row execute function admin.touch_updated_at();

create or replace function admin.publish_due_manifest()
returns table(content_version text, storage_bucket text, storage_path text)
language plpgsql
security definer
as $$
declare
  next_manifest admin.question_manifests%rowtype;
begin
  select *
  into next_manifest
  from admin.question_manifests
  where status = 'staged'
    and release_at is not null
    and release_at <= now()
  order by release_at asc
  limit 1;

  if next_manifest.id is null then
    return;
  end if;

  update admin.question_manifests
  set status = 'archived'
  where status = 'published';

  update admin.question_manifests
  set status = 'published'
  where id = next_manifest.id;

  return query
  select next_manifest.content_version, next_manifest.storage_bucket, next_manifest.storage_path;
end;
$$;

create or replace function public.get_published_manifest_metadata()
returns table(content_version text, storage_bucket text, storage_path text, updated_at timestamptz)
language sql
security definer
as $$
  select content_version, storage_bucket, storage_path, updated_at
  from admin.question_manifests
  where status = 'published'
  order by updated_at desc
  limit 1;
$$;

create or replace function admin.reschedule_content_publish_job()
returns void
language plpgsql
security definer
as $$
declare
  job_name constant text := 'minukuru_publish_content';
  config jsonb;
  cron_expr text;
begin
  select value into config
  from admin.runtime_config
  where key = 'content_publish_schedule';

  cron_expr := coalesce(config->>'cron', '0 9 * * 1');

  perform cron.unschedule(job_name)
  where exists (
    select 1 from cron.job where jobname = job_name
  );

  perform cron.schedule(
    job_name,
    cron_expr,
    'select admin.publish_due_manifest();'
  );
end;
$$;

select admin.reschedule_content_publish_job();

revoke all on schema admin from public, anon, authenticated;
revoke all on all tables in schema admin from public, anon, authenticated;
revoke all on all functions in schema admin from public, anon, authenticated;
grant execute on function public.get_published_manifest_metadata() to anon, authenticated;
