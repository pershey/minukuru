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
