-- =====================================================================
-- Inscrições de alunos pelo formulário público (inscricao.html)
-- Pode ser executado de novo sem apagar dados.
-- O formulário só consegue INSERIR (como anon). Quem lê, aprova ou recusa
-- são admin, coordenador e líder/secretário da turma (pode_gravar_turma).
-- Requer o schema.sql já executado (usa pode_gravar_turma e a tabela turmas).
-- =====================================================================
create table if not exists public.inscricoes (
  id          uuid primary key default gen_random_uuid(),
  criado_em   timestamptz not null default now(),
  status      text not null default 'pendente' check (status in ('pendente','aprovada','recusada')),
  turma_id    text not null,
  nome        text not null check (char_length(btrim(nome)) between 3 and 120),
  nasc        date not null check (nasc between date '1900-01-01' and current_date),
  titulo      text not null default '' check (titulo in ('','Pr.','Pra.','Miss.','Pb.','Coop.','Dc.','Membro')),
  professor   boolean not null default false,
  batizado    text not null default '' check (batizado in ('','sim','nao')),
  resp        text not null default '' check (char_length(resp) <= 120),
  contato     text not null default '' check (char_length(contato) <= 40),
  decidido_em  timestamptz,
  decidido_por uuid,
  aluno_id     text
);

-- Evita o mesmo aluno pendente duas vezes na mesma turma
create unique index if not exists inscricoes_pendente_unica
  on public.inscricoes (lower(btrim(nome)), nasc, turma_id) where status = 'pendente';
create index if not exists inscricoes_status_idx on public.inscricoes (status, criado_em);

alter table public.inscricoes enable row level security;

-- Validação no servidor (espelha as regras do app) + limite de envios
create or replace function public.inscricoes_valida() returns trigger
  language plpgsql security definer set search_path = public as
$$
declare td jsonb; sem_prof boolean; exige_resp boolean; sem_bat boolean;
begin
  select dados into td from public.turmas where id = new.turma_id;
  if td is null then raise exception 'turma_invalida' using errcode = '22023'; end if;
  new.nome    := regexp_replace(btrim(new.nome), '\s+', ' ', 'g');
  new.resp    := regexp_replace(btrim(new.resp), '\s+', ' ', 'g');
  new.contato := btrim(new.contato);
  sem_prof    := coalesce((td->>'semProf')::boolean, false);
  exige_resp  := coalesce((td->>'exigeResp')::boolean, false);
  sem_bat     := lower(btrim(coalesce(td->>'nome',''))) = 'desbravadores';
  if sem_prof then new.titulo := ''; new.professor := false;
  elsif new.titulo = '' then raise exception 'titulo_obrigatorio' using errcode = '22023'; end if;
  if sem_bat then new.batizado := '';
  elsif new.batizado = '' then raise exception 'batizado_obrigatorio' using errcode = '22023'; end if;
  if exige_resp and new.resp = '' then raise exception 'responsavel_obrigatorio' using errcode = '22023'; end if;
  if (select count(*) from public.inscricoes where criado_em > now() - interval '10 minutes') >= 30 then
    raise exception 'limite_de_envios' using errcode = '54000';
  end if;
  return new;
end $$;
revoke execute on function public.inscricoes_valida() from public, anon, authenticated;

drop trigger if exists inscricoes_valida on public.inscricoes;
create trigger inscricoes_valida before insert on public.inscricoes
  for each row execute function public.inscricoes_valida();

-- Políticas
drop policy if exists inscricoes_enviar  on public.inscricoes;
drop policy if exists inscricoes_ver     on public.inscricoes;
drop policy if exists inscricoes_decidir on public.inscricoes;
drop policy if exists inscricoes_excluir on public.inscricoes;
create policy inscricoes_enviar on public.inscricoes for insert to anon
  with check (status = 'pendente' and decidido_em is null and decidido_por is null and aluno_id is null);
create policy inscricoes_ver on public.inscricoes for select to authenticated
  using (public.pode_gravar_turma(turma_id));
create policy inscricoes_decidir on public.inscricoes for update to authenticated
  using (public.pode_gravar_turma(turma_id)) with check (public.pode_gravar_turma(turma_id));
create policy inscricoes_excluir on public.inscricoes for delete to authenticated
  using (public.pode_gravar_turma(turma_id));

revoke all on public.inscricoes from anon, authenticated;
grant insert on public.inscricoes to anon;
grant select, update, delete on public.inscricoes to authenticated;

-- Lista pública (só id e nome + regras) das turmas, para o formulário
create or replace function public.turmas_inscricao()
returns table (id text, nome text, sem_prof boolean, exige_resp boolean, sem_bat boolean)
  language sql stable security definer set search_path = public as
$$
  select t.id,
         t.dados->>'nome',
         coalesce((t.dados->>'semProf')::boolean, false),
         coalesce((t.dados->>'exigeResp')::boolean, false),
         lower(btrim(coalesce(t.dados->>'nome',''))) = 'desbravadores'
  from public.turmas t
  order by t.dados->>'nome'
$$;
revoke execute on function public.turmas_inscricao() from public;
grant execute on function public.turmas_inscricao() to anon, authenticated;
