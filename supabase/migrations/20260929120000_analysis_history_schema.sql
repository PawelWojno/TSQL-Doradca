create table public.analyses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete restrict,
  query_text text not null,
  status text not null default 'open' check (status in ('open', 'resolved')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.analysis_suggestions (
  id uuid primary key default gen_random_uuid(),
  analysis_id uuid not null references public.analyses (id) on delete cascade,
  rule_code text not null,
  message text not null,
  severity text not null check (severity in ('high', 'medium', 'low')),
  position smallint not null,
  created_at timestamptz not null default now(),
  unique (analysis_id, position)
);

alter table public.analyses enable row level security;
alter table public.analysis_suggestions enable row level security;

-- analyses: SELECT dla całego zespołu, INSERT/UPDATE/DELETE tylko właściciel
create policy analyses_select_team on public.analyses
  for select to authenticated using (true);

create policy analyses_insert_own on public.analyses
  for insert to authenticated with check (owner_id = auth.uid());

create policy analyses_update_own on public.analyses
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy analyses_delete_own on public.analyses
  for delete to authenticated using (owner_id = auth.uid());

-- analysis_suggestions: SELECT dla całego zespołu, INSERT tylko gdy analiza należy do wywołującego, brak UPDATE, DELETE tylko przez CASCADE
create policy analysis_suggestions_select_team on public.analysis_suggestions
  for select to authenticated using (true);

create policy analysis_suggestions_insert_own on public.analysis_suggestions
  for insert to authenticated with check (
    exists (
      select 1 from public.analyses a
      where a.id = analysis_id and a.owner_id = auth.uid()
    )
  );

-- trigger: query_text/owner_id/created_at niezmienne po zapisie; updated_at aktualizowany przy każdym dozwolonym UPDATE
create or replace function public.analyses_guard_update()
returns trigger
language plpgsql
as $$
begin
  if new.query_text is distinct from old.query_text
     or new.owner_id is distinct from old.owner_id
     or new.created_at is distinct from old.created_at then
    raise exception 'analyses.query_text, owner_id and created_at are immutable after insert';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger analyses_guard_update
  before update on public.analyses
  for each row
  execute function public.analyses_guard_update();
