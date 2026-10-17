-- Aplicar una vez desde SQL Editor de Supabase como propietario del proyecto.
-- Dos tablas de persistencia. Acceso solo desde el servidor de confianza.
begin;
create table if not exists public.hefesto_reservas_states (
  workshop_id text primary key,
  state jsonb not null check (jsonb_typeof(state) = 'object'),
  revision bigint not null default 0 check (revision >= 0),
  updated_at timestamptz not null default now()
);
create table if not exists public.hefesto_reservas_sessions (
  workshop_id text not null references public.hefesto_reservas_states(workshop_id) on delete cascade,
  token_hash text not null,
  expires bigint not null,
  primary key (workshop_id, token_hash)
);
create index if not exists hefesto_reservas_sessions_expires_idx on public.hefesto_reservas_sessions(expires);
alter table public.hefesto_reservas_states enable row level security;
alter table public.hefesto_reservas_sessions enable row level security;
revoke all on public.hefesto_reservas_states from public, anon, authenticated;
revoke all on public.hefesto_reservas_sessions from public, anon, authenticated;
grant select, insert, update, delete on public.hefesto_reservas_states to service_role;
grant select, insert, update, delete on public.hefesto_reservas_sessions to service_role;
-- No se crean políticas públicas: el navegador habla con la API de Hefesto.
notify pgrst, 'reload schema';
commit;
