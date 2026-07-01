create extension if not exists pgcrypto;

create type public.project_kind as enum ('image', 'video');
create type public.visibility as enum ('private', 'public');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (username ~ '^[a-z0-9_]{3,30}$'),
  display_name text not null default '',
  bio text not null default '' check (char_length(bio) <= 160),
  avatar_path text,
  storage_used bigint not null default 0 check (storage_used >= 0),
  created_at timestamptz not null default now()
);

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  kind public.project_kind not null,
  schema_version integer not null default 1,
  current_revision integer not null default 1,
  manifest jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.project_versions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  revision integer not null,
  device_id text not null,
  manifest jsonb not null,
  created_at timestamptz not null default now(),
  unique(project_id, revision, device_id)
);

create table public.media_assets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  project_id uuid references public.projects(id) on delete cascade,
  storage_path text unique not null,
  checksum text not null,
  byte_size bigint not null check (byte_size > 0),
  mime_type text not null,
  distributable boolean not null default true,
  created_at timestamptz not null default now(),
  unique(owner_id, checksum)
);

create table public.share_links (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  token_hash text unique not null,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  media_asset_id uuid not null references public.media_assets(id) on delete restrict,
  thumbnail_asset_id uuid references public.media_assets(id) on delete set null,
  caption text not null default '' check (char_length(caption) <= 2200),
  visibility public.visibility not null default 'public',
  duration_ms integer check (duration_ms is null or duration_ms between 0 and 60000),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.follows (
  follower_id uuid references public.profiles(id) on delete cascade,
  following_id uuid references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.reactions (
  post_id uuid references public.posts(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table public.saved_posts (
  post_id uuid references public.posts(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table public.blocks (
  blocker_id uuid references public.profiles(id) on delete cascade,
  blocked_id uuid references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  type text not null,
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('post', 'comment', 'user')),
  target_id uuid not null,
  reason text not null check (char_length(reason) between 3 and 500),
  status text not null default 'open' check (status in ('open', 'reviewing', 'closed')),
  created_at timestamptz not null default now()
);

create index posts_feed_idx on public.posts (created_at desc) where deleted_at is null;
create index comments_post_idx on public.comments (post_id, created_at);
create index notifications_recipient_idx on public.notifications (recipient_id, created_at desc);
create index projects_owner_idx on public.projects (owner_id, updated_at desc);

alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.project_versions enable row level security;
alter table public.media_assets enable row level security;
alter table public.share_links enable row level security;
alter table public.posts enable row level security;
alter table public.follows enable row level security;
alter table public.comments enable row level security;
alter table public.reactions enable row level security;
alter table public.saved_posts enable row level security;
alter table public.blocks enable row level security;
alter table public.notifications enable row level security;
alter table public.reports enable row level security;

create policy "profiles are readable" on public.profiles for select using (true);
create policy "users manage own profile" on public.profiles for all
  using (auth.uid() = id) with check (auth.uid() = id);
create policy "owners manage projects" on public.projects for all
  using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "owners manage versions" on public.project_versions for all
  using (exists(select 1 from public.projects p where p.id = project_id and p.owner_id = auth.uid()))
  with check (exists(select 1 from public.projects p where p.id = project_id and p.owner_id = auth.uid()));
create policy "owners manage assets" on public.media_assets for all
  using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "owners manage share links" on public.share_links for all
  using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "public posts are readable" on public.posts for select
  using (deleted_at is null and (visibility = 'public' or author_id = auth.uid()));
create policy "authors manage posts" on public.posts for all
  using (auth.uid() = author_id) with check (auth.uid() = author_id);
create policy "follows are readable" on public.follows for select using (true);
create policy "users manage own follows" on public.follows for all
  using (auth.uid() = follower_id) with check (auth.uid() = follower_id);
create policy "comments on visible posts readable" on public.comments for select
  using (
    deleted_at is null and exists(
      select 1 from public.posts p
      where p.id = post_id
        and p.deleted_at is null
        and (p.visibility = 'public' or p.author_id = auth.uid())
    )
  );
create policy "authors manage comments" on public.comments for all
  using (auth.uid() = author_id) with check (auth.uid() = author_id);
create policy "reactions are readable" on public.reactions for select using (true);
create policy "users manage reactions" on public.reactions for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users manage saved posts" on public.saved_posts for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users manage blocks" on public.blocks for all
  using (auth.uid() = blocker_id) with check (auth.uid() = blocker_id);
create policy "users read own notifications" on public.notifications for select
  using (auth.uid() = recipient_id);
create policy "users update own notifications" on public.notifications for update
  using (auth.uid() = recipient_id);
create policy "users create and read own reports" on public.reports for all
  using (auth.uid() = reporter_id) with check (auth.uid() = reporter_id);
