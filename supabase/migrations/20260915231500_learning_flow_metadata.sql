alter table admin.question_drafts
  add column if not exists audience text not null default 'general'
    check (audience in ('child', 'adult', 'general')),
  add column if not exists learning_stage text not null default 'challenge'
    check (learning_stage in ('example', 'practice', 'action', 'challenge')),
  add column if not exists learning_focus text not null default 'evidence'
    check (learning_focus in ('pause', 'evidence', 'verify', 'consult')),
  add column if not exists response_type text not null default 'selectSegments'
    check (response_type in ('selectSegments', 'singleChoice')),
  add column if not exists content_revision integer not null default 1
    check (content_revision > 0);

update admin.question_drafts
set audience = case question_payload->>'audience'
      when 'child' then 'child'
      when 'adult' then 'adult'
      when 'general' then 'general'
      else audience
    end,
    learning_stage = case question_payload->>'learningStage'
      when 'example' then 'example'
      when 'practice' then 'practice'
      when 'action' then 'action'
      when 'challenge' then 'challenge'
      else learning_stage
    end,
    learning_focus = case question_payload->>'learningFocus'
      when 'pause' then 'pause'
      when 'evidence' then 'evidence'
      when 'verify' then 'verify'
      when 'consult' then 'consult'
      else learning_focus
    end,
    response_type = case question_payload->>'responseType'
      when 'selectSegments' then 'selectSegments'
      when 'singleChoice' then 'singleChoice'
      else response_type
    end,
    content_revision = case
      when coalesce(question_payload->>'contentRevision', '') ~ '^[1-9][0-9]*$'
        then (question_payload->>'contentRevision')::integer
      else content_revision
    end;

create or replace function admin.sync_question_draft_learning_metadata()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.audience := coalesce(nullif(new.question_payload->>'audience', ''), new.audience, 'general');
  new.learning_stage := coalesce(nullif(new.question_payload->>'learningStage', ''), new.learning_stage, 'challenge');
  new.learning_focus := coalesce(nullif(new.question_payload->>'learningFocus', ''), new.learning_focus, 'evidence');
  new.response_type := coalesce(nullif(new.question_payload->>'responseType', ''), new.response_type, 'selectSegments');

  if coalesce(new.question_payload->>'contentRevision', '') <> '' then
    new.content_revision := (new.question_payload->>'contentRevision')::integer;
  end if;

  return new;
end;
$$;

drop trigger if exists question_drafts_sync_learning_metadata on admin.question_drafts;
create trigger question_drafts_sync_learning_metadata
before insert or update of question_payload on admin.question_drafts
for each row execute function admin.sync_question_draft_learning_metadata();

create or replace view admin.ready_publish_candidates as
select
  d.id as draft_id,
  d.draft_batch_label,
  d.mode,
  d.access_tier,
  d.content_flavor,
  d.generated_question_id,
  d.lifecycle_status,
  d.question_payload,
  coalesce(lr.realism_score, d.realism_score) as realism_score,
  coalesce(lr.safety_score, d.safety_score) as safety_score,
  coalesce(lr.learning_score, d.learning_score) as learning_score,
  coalesce(lr.uniqueness_score, d.uniqueness_score) as uniqueness_score,
  coalesce((lr.review_payload->>'compositeScore')::numeric, d.composite_score) as composite_score,
  lr.action as latest_action,
  lr.passed as latest_passed,
  lr.similarity_ratio,
  lr.created_at as reviewed_at,
  d.audience,
  d.learning_stage,
  d.learning_focus,
  d.response_type,
  d.content_revision
from admin.question_drafts d
left join admin.latest_review_runs lr
  on lr.draft_id = d.id
where d.lifecycle_status in ('ai_reviewed', 'human_reviewed', 'approved', 'published');

revoke all on function admin.sync_question_draft_learning_metadata() from public, anon, authenticated;
