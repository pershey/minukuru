alter table admin.review_runs
  add column if not exists external_key text;

create unique index if not exists review_runs_external_key_idx
  on admin.review_runs (external_key)
  where external_key is not null;

create or replace function public.get_content_review_batch(target_batch_label text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with selected_drafts as (
    select d.*
    from admin.question_drafts d
    where d.draft_batch_label = target_batch_label
      and d.external_key is not null
      and d.generated_question_id is not null
      and d.normalized_text_hash is not null
  ),
  latest_reviews as (
    select distinct on (rr.draft_id)
      rr.*
    from admin.review_runs rr
    join selected_drafts d on d.id = rr.draft_id
    order by rr.draft_id, rr.created_at desc
  ),
  fingerprint as (
    select encode(
      extensions.digest(
        convert_to(
          coalesce(
            string_agg(
              concat_ws(E'\t', d.external_key, d.generated_question_id, d.normalized_text_hash),
              E'\n' order by d.external_key
            ),
            ''
          ),
          'UTF8'
        ),
        'sha256'
      ),
      'hex'
    ) as value
    from selected_drafts d
  )
  select jsonb_build_object(
    'schemaVersion', 1,
    'batchLabel', target_batch_label,
    'batchFingerprint', (select value from fingerprint),
    'drafts', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'draftId', d.external_key,
          'taskId', d.task_external_key,
          'batchLabel', d.draft_batch_label,
          'provider', d.provider,
          'model', d.model_name,
          'mode', d.mode,
          'accessTier', d.access_tier,
          'contentFlavor', d.content_flavor,
          'generatedQuestionId', d.generated_question_id,
          'question', d.question_payload,
          'sourceSnapshot', d.source_snapshot,
          'createdAt', d.created_at
        )
        order by d.created_at, d.external_key
      )
      from selected_drafts d
    ), '[]'::jsonb),
    'reviews', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'reviewId', coalesce(rr.external_key, rr.id::text),
          'draftId', d.external_key,
          'generatedQuestionId', d.generated_question_id,
          'reviewStage', rr.review_stage,
          'reviewerKind', rr.reviewer_kind,
          'reviewerModel', rr.reviewer_model,
          'similarityRatio', coalesce(rr.similarity_ratio, 0),
          'topSimilarQuestions', '[]'::jsonb,
          'review', rr.review_payload,
          'createdAt', rr.created_at
        )
        order by rr.created_at, d.external_key
      )
      from latest_reviews rr
      join selected_drafts d on d.id = rr.draft_id
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.get_content_review_batch(text) from public, anon, authenticated;
grant execute on function public.get_content_review_batch(text) to service_role;
