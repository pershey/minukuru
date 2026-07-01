create table if not exists admin.source_examples (
  id uuid primary key default gen_random_uuid(),
  external_key text unique,
  source_kind text not null check (source_kind in ('manual', 'internal_capture', 'public_report', 'future_submission')),
  source_channel text not null check (source_channel in ('ad', 'profile', 'news', 'forum', 'messaging', 'other')),
  title text not null,
  raw_excerpt text not null,
  redacted_excerpt text not null,
  reference_notes text,
  mode_candidates text[] not null default '{}',
  signal_tags text[] not null default '{}',
  safety_status text not null default 'pending' check (safety_status in ('pending', 'approved', 'rejected')),
  ingestion_status text not null default 'raw' check (ingestion_status in ('raw', 'normalized', 'retired')),
  realism_score int check (realism_score between 0 and 100),
  sensitivity_flags jsonb not null default '[]'::jsonb,
  extracted_signals jsonb not null default '{}'::jsonb,
  allow_real_world_flavor boolean not null default false,
  source_hash text,
  collected_at timestamptz,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists source_examples_source_hash_idx
  on admin.source_examples (source_hash)
  where source_hash is not null;

create index if not exists source_examples_channel_status_idx
  on admin.source_examples (source_channel, safety_status, allow_real_world_flavor);

create table if not exists admin.pattern_blueprints (
  id uuid primary key default gen_random_uuid(),
  external_key text unique,
  slug text not null unique,
  name text not null,
  mode text not null check (mode in ('explanationSnipe', 'newsPoison', 'scamAdChecker', 'profileHunter', 'conspiracyTrap')),
  access_tier text not null default 'premium' check (access_tier in ('free', 'premium')),
  content_flavor text not null default 'standard' check (content_flavor in ('standard', 'realWorld')),
  source_channels text[] not null default '{}',
  hook_types text[] not null default '{}',
  red_flag_tags text[] not null default '{}',
  target_difficulty text not null default 'normal' check (target_difficulty in ('easy', 'normal', 'hard')),
  audience_tone text not null default 'general' check (audience_tone in ('childFriendly', 'general', 'seniorFriendly')),
  generator_notes text,
  realism_constraints jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists pattern_blueprints_mode_idx
  on admin.pattern_blueprints (mode, access_tier, content_flavor, active);

create table if not exists admin.question_drafts (
  id uuid primary key default gen_random_uuid(),
  external_key text unique,
  task_external_key text,
  draft_batch_label text not null,
  source_example_id uuid references admin.source_examples(id) on delete set null,
  blueprint_id uuid references admin.pattern_blueprints(id) on delete set null,
  provider text,
  model_name text,
  mode text not null check (mode in ('explanationSnipe', 'newsPoison', 'scamAdChecker', 'profileHunter', 'conspiracyTrap')),
  access_tier text not null default 'premium' check (access_tier in ('free', 'premium')),
  content_flavor text not null default 'standard' check (content_flavor in ('standard', 'realWorld')),
  lifecycle_status text not null default 'generated' check (lifecycle_status in ('generated', 'ai_reviewed', 'human_reviewed', 'approved', 'rejected', 'published')),
  generated_question_id text,
  normalized_text_hash text,
  source_snapshot jsonb not null default '{}'::jsonb,
  generation_context jsonb not null default '{}'::jsonb,
  question_payload jsonb not null,
  realism_score int check (realism_score between 0 and 100),
  safety_score int check (safety_score between 0 and 100),
  learning_score int check (learning_score between 0 and 100),
  uniqueness_score int check (uniqueness_score between 0 and 100),
  composite_score numeric(5,2),
  duplicate_of uuid references admin.question_drafts(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists question_drafts_generated_question_id_idx
  on admin.question_drafts (generated_question_id)
  where generated_question_id is not null;

create index if not exists question_drafts_batch_status_idx
  on admin.question_drafts (draft_batch_label, lifecycle_status, access_tier, content_flavor);

create index if not exists question_drafts_source_blueprint_idx
  on admin.question_drafts (source_example_id, blueprint_id);

create table if not exists admin.review_runs (
  id uuid primary key default gen_random_uuid(),
  draft_id uuid not null references admin.question_drafts(id) on delete cascade,
  review_stage text not null check (review_stage in ('generation_self_check', 'ai_review', 'human_review')),
  reviewer_kind text not null check (reviewer_kind in ('openai', 'gemini', 'manual', 'rulebased', 'script')),
  reviewer_model text,
  passed boolean not null,
  action text not null check (action in ('accept', 'revise', 'reject', 'needs_human')),
  realism_score int check (realism_score between 0 and 100),
  safety_score int check (safety_score between 0 and 100),
  learning_score int check (learning_score between 0 and 100),
  uniqueness_score int check (uniqueness_score between 0 and 100),
  segment_clarity_score int check (segment_clarity_score between 0 and 100),
  similarity_ratio numeric(5,4),
  review_payload jsonb not null,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists review_runs_draft_created_idx
  on admin.review_runs (draft_id, created_at desc);

alter table admin.source_examples enable row level security;
alter table admin.pattern_blueprints enable row level security;
alter table admin.question_drafts enable row level security;
alter table admin.review_runs enable row level security;

drop trigger if exists source_examples_touch_updated_at on admin.source_examples;
create trigger source_examples_touch_updated_at
before update on admin.source_examples
for each row execute function admin.touch_updated_at();

drop trigger if exists pattern_blueprints_touch_updated_at on admin.pattern_blueprints;
create trigger pattern_blueprints_touch_updated_at
before update on admin.pattern_blueprints
for each row execute function admin.touch_updated_at();

drop trigger if exists question_drafts_touch_updated_at on admin.question_drafts;
create trigger question_drafts_touch_updated_at
before update on admin.question_drafts
for each row execute function admin.touch_updated_at();

insert into admin.runtime_config (key, value)
values (
  'content_factory_thresholds',
  jsonb_build_object(
    'minCompositeScore', 78,
    'minSafetyScore', 86,
    'minRealismScore', 72,
    'minLearningScore', 70,
    'maxSimilarityRatio', 0.86
  )
)
on conflict (key) do nothing;

insert into admin.pattern_blueprints (
  slug,
  name,
  mode,
  access_tier,
  content_flavor,
  source_channels,
  hook_types,
  red_flag_tags,
  target_difficulty,
  audience_tone,
  generator_notes,
  realism_constraints
)
values
  (
    'scam-limited-authority',
    '限定感と監修風の権威づけ',
    'scamAdChecker',
    'premium',
    'standard',
    array['ad'],
    array['limited_offer', 'authority_claim'],
    array['urgency', 'fakeAuthority', 'tooGoodToBeTrue'],
    'normal',
    'general',
    '広告見出し、特典、安心感の順で自然につなげる。露骨な犯罪誘導は入れない。',
    jsonb_build_object('maxCorrectSegments', 3, 'tone', 'ad-like')
  ),
  (
    'profile-soft-credential',
    'ぼかした肩書きと個別誘導',
    'profileHunter',
    'premium',
    'standard',
    array['profile', 'messaging'],
    array['vague_credential', 'private_invite'],
    array['fakeAuthority', 'secretInfo', 'hardToVerify'],
    'normal',
    'general',
    'SNS自己紹介として短く自然に。実績は盛りすぎず、閉じた誘導を混ぜる。',
    jsonb_build_object('maxCorrectSegments', 2, 'tone', 'social-profile')
  ),
  (
    'news-local-jump',
    '地域ニュース風の数字飛躍',
    'newsPoison',
    'premium',
    'standard',
    array['news'],
    array['local_news', 'cause_jump'],
    array['suspiciousNumber', 'tooStrongClaim', 'noSource'],
    'normal',
    'seniorFriendly',
    '地方ニュースや広報記事の落ち着いた語り口で、一部だけ飛躍させる。',
    jsonb_build_object('maxCorrectSegments', 2, 'tone', 'local-news')
  ),
  (
    'explanation-fact-slip',
    '図鑑風の自然な事実ずらし',
    'explanationSnipe',
    'premium',
    'standard',
    array['other'],
    array['encyclopedia_style'],
    array['tooStrongClaim', 'hardToVerify'],
    'easy',
    'childFriendly',
    '学習読み物らしい落ち着いた文体で、1点だけ事実を少しずらす。',
    jsonb_build_object('maxCorrectSegments', 1, 'tone', 'educational')
  ),
  (
    'conspiracy-secret-circle',
    '閉じた仲間意識と秘密の情報源',
    'conspiracyTrap',
    'premium',
    'standard',
    array['forum', 'messaging'],
    array['secret_source', 'enemy_framing'],
    array['secretInfo', 'enemyFraming', 'forcedConnection'],
    'hard',
    'general',
    '実在テーマは避け、特別感と敵味方構図を少しずつ積む。',
    jsonb_build_object('maxCorrectSegments', 3, 'tone', 'rumor-thread')
  ),
  (
    'realworld-ad-soft-fomo',
    '現実モードのやわらかい FOMO 訴求',
    'scamAdChecker',
    'premium',
    'realWorld',
    array['ad', 'messaging'],
    array['fomo', 'limited_offer', 'social_proof'],
    array['urgency', 'tooGoodToBeTrue', 'hardToVerify'],
    'hard',
    'general',
    '実際の広告らしい自然さを優先。実在サービス名や金額断言は避ける。',
    jsonb_build_object('maxCorrectSegments', 3, 'tone', 'realworld-ad')
  ),
  (
    'realworld-profile-mentor',
    '現実モードのメンター風プロフィール',
    'profileHunter',
    'premium',
    'realWorld',
    array['profile', 'messaging'],
    array['mentor', 'exclusive_access'],
    array['fakeAuthority', 'secretInfo', 'hardToVerify'],
    'hard',
    'general',
    '現実の自己紹介文に近い長さで、強すぎない肩書きと閉じた導線を混ぜる。',
    jsonb_build_object('maxCorrectSegments', 3, 'tone', 'realworld-profile')
  )
on conflict (slug) do nothing;

create or replace view admin.latest_review_runs as
select distinct on (draft_id)
  id,
  draft_id,
  review_stage,
  reviewer_kind,
  reviewer_model,
  passed,
  action,
  realism_score,
  safety_score,
  learning_score,
  uniqueness_score,
  segment_clarity_score,
  similarity_ratio,
  review_payload,
  notes,
  created_at
from admin.review_runs
order by draft_id, created_at desc;

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
  lr.created_at as reviewed_at
from admin.question_drafts d
left join admin.latest_review_runs lr
  on lr.draft_id = d.id
where d.lifecycle_status in ('ai_reviewed', 'human_reviewed', 'approved', 'published');

create or replace function admin.mark_draft_reviewed(
  target_draft_id uuid,
  target_status text,
  target_realism_score int,
  target_safety_score int,
  target_learning_score int,
  target_uniqueness_score int,
  target_composite_score numeric
)
returns void
language sql
security definer
as $$
  update admin.question_drafts
  set lifecycle_status = target_status,
      realism_score = target_realism_score,
      safety_score = target_safety_score,
      learning_score = target_learning_score,
      uniqueness_score = target_uniqueness_score,
      composite_score = target_composite_score
  where id = target_draft_id;
$$;

revoke all on all tables in schema admin from public, anon, authenticated;
revoke all on all functions in schema admin from public, anon, authenticated;
