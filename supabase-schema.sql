-- ============================================================
-- Westroe JMS — Supabase auth schema
-- Run this once in Supabase: Dashboard > SQL Editor > New query
-- ============================================================

-- 1. Profiles table — one row per user, linked to Supabase's built-in auth.users
create table if not exists public.profiles (
  id           uuid references auth.users(id) on delete cascade primary key,
  name         text not null,
  email        text not null,
  role         text not null default 'admin',   -- admin, executive, accounting, pm, pe, super, field, arch, sub, owner
  company      text,
  sub_id       text,
  owner_id     text,
  project_ids  text[] default '{}',
  phone        text,
  created_at   timestamptz default now()
);

-- 2. Row Level Security — locks the table down by default, then opens specific access
alter table public.profiles enable row level security;

-- Any signed-in user can view all profiles (needed for the Users/Directory screens)
create policy "Authenticated users can view profiles"
  on public.profiles for select
  using (auth.role() = 'authenticated');

-- Users can update their own profile only
create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- 3. Auto-create a profile row whenever someone signs up
-- Reads the "name", "role", and "company" passed in at signup time (see options.data in the app code)
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, name, email, role, company)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', new.email),
    new.email,
    coalesce(new.raw_user_meta_data->>'role', 'admin'),
    new.raw_user_meta_data->>'company'
  );
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- To manually add a crew member, subcontractor, or project owner
-- account (instead of them self-signing-up as a new GC):
--
-- 1. Supabase Dashboard > Authentication > Users > Add User
--    (set their email + a temporary password)
-- 2. Then run, filling in their new user id from that screen:
--
-- update public.profiles
-- set role = 'pm', name = 'Jane Smith'   -- or 'sub', 'owner', 'field', etc.
-- where id = 'paste-their-user-id-here';
-- ============================================================
