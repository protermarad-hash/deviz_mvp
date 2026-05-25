create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  contact_person text,
  phone text,
  email text,
  created_at timestamptz not null default now()
);

create table if not exists public.materials (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  unit text not null,
  sell_price numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.offers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
  number text not null,
  offer_date date not null default current_date,
  currency text not null default 'RON',
  eur_rate numeric(12,4) not null default 5,
  labor_total numeric(12,2) not null default 0,
  overhead_total numeric(12,2) not null default 0,
  profit_percent numeric(8,2) not null default 15,
  vat_percent numeric(8,2) not null default 21,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.offer_lines (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null references public.offers(id) on delete cascade,
  material_id uuid references public.materials(id) on delete set null,
  material_name text not null,
  unit text not null,
  quantity numeric(12,2) not null default 0,
  unit_price numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.clients enable row level security;
alter table public.materials enable row level security;
alter table public.offers enable row level security;
alter table public.offer_lines enable row level security;

create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

create policy "clients_owner_all" on public.clients for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "materials_owner_all" on public.materials for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "offers_owner_all" on public.offers for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "offer_lines_owner_all"
on public.offer_lines
for all
using (
  exists (
    select 1 from public.offers o
    where o.id = offer_lines.offer_id and o.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.offers o
    where o.id = offer_lines.offer_id and o.user_id = auth.uid()
  )
);
