-- EBD IADP: módulo financeiro (ofertas e despesas)
-- Rode no Supabase: SQL Editor > New query > cole tudo > Run. Pode rodar de novo sem apagar dados.
-- Só o administrador ativo lê e grava esta tabela. O banco recusa qualquer outro usuário,
-- mesmo que alguém tente acessar sem passar pela tela do app.

create table if not exists public.financeiro (
  id uuid primary key default gen_random_uuid(),
  data date not null,                                   -- data do lançamento
  tipo text not null check (tipo in ('entrada','saida')),
  categoria text not null,
  descricao text not null default '',
  valor_centavos integer not null check (valor_centavos > 0 and valor_centavos <= 1000000000),
  turma_id text,                                        -- opcional (vazio = geral)
  criado_por uuid default auth.uid(),
  criado_por_nome text,
  criado_em timestamptz not null default now()
);

create index if not exists financeiro_data_idx on public.financeiro (data);

-- Quem pode usar o financeiro: administrador ou coordenador ativo.
create or replace function public.pode_financeiro()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.perfis p
    where p.id = auth.uid() and p.ativo is true and p.perfil in ('admin','coordenador')
  );
$$;

alter table public.financeiro enable row level security;

drop policy if exists financeiro_admin on public.financeiro;
create policy financeiro_admin on public.financeiro
  for all to authenticated
  using (public.pode_financeiro())
  with check (public.pode_financeiro());

revoke all on public.financeiro from anon;
