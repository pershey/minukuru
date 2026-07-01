do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'admin'
      and table_name = 'question_manifests'
      and column_name = 'distribution_channel'
  ) then
    alter table admin.question_manifests
      add column distribution_channel text not null default 'full';
  end if;
end;
$$;

update admin.question_manifests
set distribution_channel = 'full'
where distribution_channel is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'question_manifests_distribution_channel_check'
      and conrelid = 'admin.question_manifests'::regclass
  ) then
    alter table admin.question_manifests
      add constraint question_manifests_distribution_channel_check
      check (distribution_channel in ('full', 'free', 'premium'));
  end if;
end;
$$;

create index if not exists question_manifests_channel_status_release_idx
  on admin.question_manifests (distribution_channel, status, release_at);

drop function if exists public.get_published_manifest_metadata(text);
drop function if exists public.get_published_manifest_metadata();
drop function if exists admin.publish_due_manifest();

create or replace function admin.publish_due_manifest()
returns table(distribution_channel text, content_version text, storage_bucket text, storage_path text)
language plpgsql
security definer
as $$
declare
  channel_key text;
  next_manifest admin.question_manifests%rowtype;
begin
  for channel_key in
    select distinct qm.distribution_channel
    from admin.question_manifests qm
    where qm.status = 'staged'
      and qm.release_at is not null
      and qm.release_at <= now()
    order by qm.distribution_channel
  loop
    select *
    into next_manifest
    from admin.question_manifests qm_pending
    where qm_pending.distribution_channel = channel_key
      and qm_pending.status = 'staged'
      and qm_pending.release_at is not null
      and qm_pending.release_at <= now()
    order by qm_pending.release_at asc, qm_pending.created_at asc
    limit 1;

    continue when next_manifest.id is null;

    update admin.question_manifests as qm_published
    set status = 'archived'
    where qm_published.status = 'published'
      and qm_published.distribution_channel = channel_key
      and qm_published.id <> next_manifest.id;

    update admin.question_manifests
    set status = 'published'
    where id = next_manifest.id;

    distribution_channel := next_manifest.distribution_channel;
    content_version := next_manifest.content_version;
    storage_bucket := next_manifest.storage_bucket;
    storage_path := next_manifest.storage_path;
    return next;
  end loop;
end;
$$;

create or replace function public.get_published_manifest_metadata(target_channel text)
returns table(distribution_channel text, content_version text, storage_bucket text, storage_path text, updated_at timestamptz)
language sql
security definer
as $$
  select distribution_channel, content_version, storage_bucket, storage_path, updated_at
  from admin.question_manifests
  where status = 'published'
    and distribution_channel = coalesce(nullif(target_channel, ''), 'full')
  order by updated_at desc
  limit 1;
$$;

create or replace function public.get_published_manifest_metadata()
returns table(distribution_channel text, content_version text, storage_bucket text, storage_path text, updated_at timestamptz)
language sql
security definer
as $$
  select *
  from public.get_published_manifest_metadata('full');
$$;

grant execute on function public.get_published_manifest_metadata() to anon, authenticated;
grant execute on function public.get_published_manifest_metadata(text) to anon, authenticated;
