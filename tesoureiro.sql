-- EBD IADP: perfil adicional "Tesoureiro(a)"
-- Rode DEPOIS do financeiro.sql. No Supabase: SQL Editor > New query > cole tudo > Run.
-- Pode rodar de novo sem apagar dados.
--
-- Como funciona: o perfil principal do usuário (administrador, secretário, líder ou professor)
-- continua como está. Esta coluna guarda perfis ADICIONAIS, hoje só 'tesoureiro'.
-- Assim a mesma pessoa pode, por exemplo, ser Secretário(a) e Tesoureiro(a) ao mesmo tempo.

alter table public.perfis
  add column if not exists perfis_extra text[] not null default '{}';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'perfis_extra_valores') then
    alter table public.perfis
      add constraint perfis_extra_valores
      check (perfis_extra <@ array['tesoureiro']::text[]);
  end if;
end $$;

-- Só o administrador pode mudar o perfil adicional (ninguém consegue se promover sozinho).
create or replace function public.protege_perfis_extra()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.perfis_extra is distinct from old.perfis_extra
     and auth.uid() is not null
     and not exists (
       select 1 from public.perfis p
       where p.id = auth.uid() and p.perfil = 'admin' and p.ativo is true
     ) then
    raise exception 'Só o administrador pode alterar o perfil adicional';
  end if;
  return new;
end;
$$;

drop trigger if exists protege_perfis_extra on public.perfis;
create trigger protege_perfis_extra
  before update on public.perfis
  for each row execute function public.protege_perfis_extra();

-- Quem pode usar o financeiro: administrador ativo OU usuário ativo com o perfil adicional tesoureiro.
create or replace function public.pode_financeiro()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.perfis p
    where p.id = auth.uid()
      and p.ativo is true
      and (p.perfil = 'admin' or 'tesoureiro' = any (p.perfis_extra))
  );
$$;
