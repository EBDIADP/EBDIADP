-- =====================================================================
-- EBD IADP - histórico de alterações (auditoria)
-- Supabase > SQL Editor > New query > cole tudo > Run. Pode rodar de novo.
-- Registra quem, quando e o que mudou em turmas, aulas, avisos, chamadas e perfis.
-- Só o administrador lê. Ninguém (nem admin pelo app) altera ou apaga registros.
-- =====================================================================
create table if not exists public.historico (
  id        bigint generated always as identity primary key,
  quando    timestamptz not null default now(),
  quem      uuid,
  quem_nome text,
  tabela    text not null,
  op        text not null check (op in ('INSERT','UPDATE','DELETE')),
  registro  text not null,
  antes     jsonb,
  depois    jsonb
);
create index if not exists historico_quando on public.historico (quando desc);
create index if not exists historico_tabela on public.historico (tabela, quando desc);

alter table public.historico enable row level security;
revoke all on public.historico from anon, authenticated;
grant select on public.historico to authenticated;
drop policy if exists historico_ver on public.historico;
create policy historico_ver on public.historico for select to authenticated using (public.sou_admin());

create or replace function public.registra_historico() returns trigger
  language plpgsql security definer set search_path = public as
$$
declare a jsonb; d jsonb; nome text;
begin
  a := case when tg_op <> 'INSERT' then to_jsonb(old) end;
  d := case when tg_op <> 'DELETE' then to_jsonb(new) end;
  if tg_op = 'UPDATE' and a = d then return null; end if;   -- nada mudou
  select p.nome into nome from public.perfis p where p.id = auth.uid();
  insert into public.historico (quem, quem_nome, tabela, op, registro, antes, depois)
  values (auth.uid(), coalesce(nome, 'Sistema'), tg_table_name, tg_op,
          coalesce(d->>'id', a->>'id'),
          coalesce(a->'dados', a), coalesce(d->'dados', d));
  return null;
end $$;

do $$ declare t text; begin
  foreach t in array array['turmas','aulas','avisos','chamadas','perfis'] loop
    execute format('drop trigger if exists auditoria on public.%I', t);
    execute format('create trigger auditoria after insert or update or delete on public.%I
                    for each row execute function public.registra_historico()', t);
  end loop;
end $$;

-- Função de trigger: não precisa ficar chamável pela API.
revoke execute on function public.registra_historico() from public, anon, authenticated;

-- Opcional (LGPD): apagar registros com mais de 12 meses. Rode de vez em quando, como administrador no SQL Editor.
-- delete from public.historico where quando < now() - interval '12 months';
