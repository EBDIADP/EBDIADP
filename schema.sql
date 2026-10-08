-- =====================================================================
-- EBD IADP - banco de dados (Supabase / PostgreSQL)
-- Estado atual, com as regras de gravação por perfil, aviso de novas contas,
-- perfil adicional Tesoureiro(a), módulo financeiro, perfil Coordenador(a) e
-- revogação de EXECUTE das funções internas (out/2026).
--
-- COMO USAR: Supabase > SQL Editor > New query > cole tudo > Run.
-- Pode ser executado de novo sem problema (não apaga dados).
--
-- ATENÇÃO: o schema.sql original foi perdido. Este arquivo foi
-- reconstruído a partir das funções, triggers e políticas lidas do
-- banco em produção e do código do app. As FUNÇÕES, TRIGGERS e
-- POLÍTICAS são cópia fiel; a definição das TABELAS (tipos e
-- restrições) é inferida. Antes de depender dele em um projeto novo,
-- teste em um projeto Supabase de teste.
-- =====================================================================

-- ---------- 1. Tabelas ----------
-- Dados do app: cada linha guarda um objeto JSON em "dados".
create table if not exists public.turmas   (id text primary key, dados jsonb not null default '{}'::jsonb);
create table if not exists public.aulas    (id text primary key, dados jsonb not null default '{}'::jsonb);
create table if not exists public.avisos   (id text primary key, dados jsonb not null default '{}'::jsonb);
-- chamadas: id no formato 'AAAA-MM-DD|idDaTurma'; dados = {p: presentes, e: extras}
create table if not exists public.chamadas (id text primary key, dados jsonb not null default '{}'::jsonb);

-- Perfis dos usuários (1 linha por conta de login).
create table if not exists public.perfis (
  id        uuid primary key references auth.users(id) on delete cascade,
  nome      text,
  email     text,
  perfil    text not null default 'professor'
            check (perfil in ('admin','coordenador','secretario','lider','professor')),
  ativo     boolean not null default false,
  aluno_id  text,   -- vínculo com o cadastro de aluno (professor, líder, secretário, admin)
  turma_id  text,   -- turma de líder e secretário
  criado_em timestamptz not null default now(),
  aprovado_em timestamptz,                         -- quando a conta foi liberada (aviso de novas contas)
  perfis_extra text[] not null default '{}'        -- perfis adicionais (hoje só 'tesoureiro')
);

-- Bancos antigos: libera o perfil 'coordenador' na restrição (seguro de repetir).
alter table public.perfis drop constraint if exists perfis_perfil_check;
alter table public.perfis add constraint perfis_perfil_check
  check (perfil in ('admin','coordenador','secretario','lider','professor'));
-- Para bancos que já existiam antes dessas duas colunas (create table if not exists não as adiciona):
alter table public.perfis add column if not exists aprovado_em timestamptz;
alter table public.perfis add column if not exists perfis_extra text[] not null default '{}';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'perfis_extra_valores') then
    alter table public.perfis add constraint perfis_extra_valores
      check (perfis_extra <@ array['tesoureiro']::text[]);
  end if;
end $$;

alter table public.turmas   enable row level security;
alter table public.aulas    enable row level security;
alter table public.avisos   enable row level security;
alter table public.chamadas enable row level security;
alter table public.perfis   enable row level security;

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete
  on public.turmas, public.aulas, public.avisos, public.chamadas, public.perfis
  to authenticated;

-- ---------- 2. Funções auxiliares ----------
create or replace function public.sou_ativo() returns boolean
  language sql stable security definer set search_path = public as
$$ select exists (select 1 from public.perfis where id = auth.uid() and ativo) $$;

create or replace function public.sou_admin() returns boolean
  language sql stable security definer set search_path = public as
$$ select exists (select 1 from public.perfis where id = auth.uid() and ativo and perfil = 'admin') $$;

-- admin ou coordenador: gestão do conteúdo (turmas, aulas, avisos, chamadas, financeiro).
-- Usuários e auditoria continuam só do admin (sou_admin).
create or replace function public.sou_gestor() returns boolean
  language sql stable security definer set search_path = public as
$$ select exists (select 1 from public.perfis where id = auth.uid() and ativo and perfil in ('admin','coordenador')) $$;

create or replace function public.meu_perfil() returns text
  language sql stable security definer set search_path = public as
$$ select perfil::text from public.perfis where id = auth.uid() and ativo $$;

-- true se for admin ou coordenador, ou líder/secretário vinculado à turma informada
create or replace function public.pode_gravar_turma(tid text) returns boolean
  language sql stable security definer set search_path = public as
$$ select coalesce((
     select perfil in ('admin','coordenador')
         or (perfil in ('lider','secretario') and coalesce(tid,'') <> '' and turma_id::text = tid)
     from public.perfis where id = auth.uid() and ativo), false) $$;

-- true se o usuário logado é professor(a) ativo(a) e é o(a) responsável pela chamada da chave
-- 'AAAA-MM-DD|idDaTurma'. O responsável é o professor da aula agendada (aulas.dados->>'prof');
-- se a aula não existir mais, vale o professor guardado na própria chamada (dados->'e'->>'prof').
-- O nome é montado como no app: título (exceto 'Membro') + espaço + nome do aluno vinculado.
create or replace function public.professor_da_chamada(chave text, d jsonb) returns boolean
  language sql stable security definer set search_path = public as
$$ select coalesce((
     select (case when exists (select 1 from public.aulas a
                                where a.dados->>'turma' = split_part(chave,'|',2)
                                  and a.dados->>'data'  = split_part(chave,'|',1))
                  then (select a.dados->>'prof' from public.aulas a
                         where a.dados->>'turma' = split_part(chave,'|',2)
                           and a.dados->>'data'  = split_part(chave,'|',1) limit 1)
                  else d->'e'->>'prof' end) = x.nome
     from (
       select (case when coalesce(al->>'titulo','') not in ('','Membro') then (al->>'titulo') || ' ' else '' end)
              || (al->>'nome') as nome
       from public.perfis p
       cross join public.turmas t
       cross join lateral jsonb_array_elements(
         case when jsonb_typeof(t.dados->'alunos') = 'array' then t.dados->'alunos' else '[]'::jsonb end) al
       where p.id = auth.uid() and p.ativo and p.perfil = 'professor'
         and p.aluno_id is not null and al->>'id' = p.aluno_id
       limit 1) x
   ), false) $$;

-- ---------- 3. Cadastro automático e proteção do administrador ----------
-- A primeira conta criada vira administradora e já entra ativa.
-- As demais entram como professor inativo, aguardando aprovação.
create or replace function public.novo_usuario() returns trigger
  language plpgsql security definer set search_path to 'public' as
$function$
declare primeiro boolean;
begin
  select not exists (select 1 from public.perfis) into primeiro;
  insert into public.perfis (id, nome, email, perfil, ativo)
  values (new.id, coalesce(new.raw_user_meta_data->>'nome',''), coalesce(new.email,''),
          case when primeiro then 'admin' else 'professor' end, primeiro);
  return new;
end $function$;

-- Nunca deixa o sistema sem ao menos um administrador ativo.
create or replace function public.protege_ultimo_admin() returns trigger
  language plpgsql security definer set search_path to 'public' as
$function$
begin
  if old.perfil = 'admin' and old.ativo
     and (tg_op = 'DELETE' or new.perfil <> 'admin' or not new.ativo)
     and not exists (select 1 from public.perfis where perfil = 'admin' and ativo and id <> old.id) then
    raise exception 'Precisa existir ao menos um administrador ativo';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $function$;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario after insert on auth.users
  for each row execute function public.novo_usuario();

drop trigger if exists protege_admin on public.perfis;
create trigger protege_admin before delete or update on public.perfis
  for each row execute function public.protege_ultimo_admin();

-- Marca a data de aprovação quando a conta fica ativa (diferencia conta nova de conta desativada).
create or replace function public.perfis_marca_aprovado() returns trigger
  language plpgsql as
$$
begin
  if new.ativo is true and new.aprovado_em is null then
    new.aprovado_em := now();
  end if;
  return new;
end $$;

drop trigger if exists perfis_marca_aprovado on public.perfis;
create trigger perfis_marca_aprovado before insert or update on public.perfis
  for each row execute function public.perfis_marca_aprovado();

-- Só o administrador pode mudar o perfil adicional (ninguém se promove sozinho).
create or replace function public.protege_perfis_extra() returns trigger
  language plpgsql security definer set search_path = public as
$$
begin
  if new.perfis_extra is distinct from old.perfis_extra
     and auth.uid() is not null
     and not exists (select 1 from public.perfis p
                     where p.id = auth.uid() and p.perfil = 'admin' and p.ativo is true) then
    raise exception 'Só o administrador pode alterar o perfil adicional';
  end if;
  return new;
end $$;

drop trigger if exists protege_perfis_extra on public.perfis;
create trigger protege_perfis_extra before update on public.perfis
  for each row execute function public.protege_perfis_extra();

-- ---------- 4. Políticas de acesso (RLS) ----------
-- Remove políticas antigas para poder reexecutar o arquivo.
do $$ declare t text; p text; begin
  foreach t in array array['turmas','aulas','avisos','chamadas'] loop
    foreach p in array array['ativos_ler','ativos_inserir','ativos_alterar','ativos_excluir',
                             t||'_inserir', t||'_alterar', t||'_excluir'] loop
      execute format('drop policy if exists %I on public.%I', p, t);
    end loop;
  end loop;
  drop policy if exists perfis_ver     on public.perfis;
  drop policy if exists perfis_alterar on public.perfis;
  drop policy if exists perfis_excluir on public.perfis;
end $$;

-- Leitura: qualquer usuário ATIVO lê as quatro tabelas.
-- (Limite conhecido: a leitura ainda não é separada por turma.)
do $$ declare t text; begin
  foreach t in array array['turmas','aulas','avisos','chamadas'] loop
    execute format('create policy ativos_ler on public.%I for select using (public.sou_ativo())', t);
  end loop;
end $$;

-- turmas: excluir admin ou coordenador; alterar (alunos) admin, coordenador ou líder/secretário da turma.
-- O INSERT também usa pode_gravar_turma porque o app grava com UPSERT (INSERT ... ON CONFLICT
-- DO UPDATE), e o Postgres confere a regra de INSERT antes de detectar a turma existente.
-- Com sou_admin() aqui, líder e secretário(a) não conseguiam salvar alunos novos.
-- Turma nova só nasce com id que nenhum perfil tem em turma_id, então só admin e coordenador criam turma.
create policy turmas_inserir on public.turmas for insert with check (public.pode_gravar_turma(id::text));
create policy turmas_excluir on public.turmas for delete using (public.sou_gestor());
create policy turmas_alterar on public.turmas for update
  using (public.pode_gravar_turma(id::text)) with check (public.pode_gravar_turma(id::text));

-- aulas e avisos: admin ou líder/secretário da turma da aula/aviso.
create policy aulas_inserir on public.aulas for insert with check (public.pode_gravar_turma(dados->>'turma'));
create policy aulas_alterar on public.aulas for update
  using (public.pode_gravar_turma(dados->>'turma')) with check (public.pode_gravar_turma(dados->>'turma'));
create policy aulas_excluir on public.aulas for delete using (public.pode_gravar_turma(dados->>'turma'));

create policy avisos_inserir on public.avisos for insert with check (public.pode_gravar_turma(dados->>'turma'));
create policy avisos_alterar on public.avisos for update
  using (public.pode_gravar_turma(dados->>'turma')) with check (public.pode_gravar_turma(dados->>'turma'));
create policy avisos_excluir on public.avisos for delete using (public.pode_gravar_turma(dados->>'turma'));

-- chamadas: o professor insere e altera só as chamadas das aulas em que é o(a) responsável;
-- admin e líder/secretário da turma gravam as da turma. Excluir: só admin ou líder/secretário da turma.
create policy chamadas_inserir on public.chamadas for insert with check (
  public.professor_da_chamada(id::text, dados) or public.pode_gravar_turma(split_part(id::text,'|',2)));
create policy chamadas_alterar on public.chamadas for update
  using (public.professor_da_chamada(id::text, dados) or public.pode_gravar_turma(split_part(id::text,'|',2)))
  with check (public.professor_da_chamada(id::text, dados) or public.pode_gravar_turma(split_part(id::text,'|',2)));
create policy chamadas_excluir on public.chamadas for delete
  using (public.pode_gravar_turma(split_part(id::text,'|',2)));

-- perfis: cada um vê o próprio; só o admin vê todos, altera e exclui (menos a si mesmo).
-- Não há política de INSERT: perfis só são criados pelo trigger ao_criar_usuario.
create policy perfis_ver     on public.perfis for select using (id = auth.uid() or public.sou_admin());
create policy perfis_alterar on public.perfis for update using (public.sou_admin()) with check (public.sou_admin());
create policy perfis_excluir on public.perfis for delete using (public.sou_admin() and id <> auth.uid());

-- ---------- 5. Financeiro (ofertas e despesas) ----------
-- Acesso: administrador ou coordenador ativo, ou usuário ativo com o perfil adicional 'tesoureiro'.
create table if not exists public.financeiro (
  id uuid primary key default gen_random_uuid(),
  data date not null,
  tipo text not null check (tipo in ('entrada','saida')),
  categoria text not null,
  descricao text not null default '',
  valor_centavos integer not null check (valor_centavos > 0 and valor_centavos <= 1000000000),
  turma_id text,
  criado_por uuid default auth.uid(),
  criado_por_nome text,
  criado_em timestamptz not null default now()
);
create index if not exists financeiro_data_idx on public.financeiro (data);

create or replace function public.pode_financeiro() returns boolean
  language sql stable security definer set search_path = public as
$$ select exists (select 1 from public.perfis p
                  where p.id = auth.uid() and p.ativo is true
                    and (p.perfil in ('admin','coordenador') or 'tesoureiro' = any (p.perfis_extra))) $$;

alter table public.financeiro enable row level security;
revoke all on public.financeiro from anon;
grant select, insert, update, delete on public.financeiro to authenticated;
drop policy if exists financeiro_admin on public.financeiro;
create policy financeiro_admin on public.financeiro for all to authenticated
  using (public.pode_financeiro()) with check (public.pode_financeiro());

-- O histórico de alterações (auditoria) fica no arquivo auditoria.sql.

-- ---------- 6. Permissão de execução das funções ----------
-- Funções SECURITY DEFINER do schema public ficam expostas em /rest/v1/rpc/... (API).
-- Funções de trigger: ninguém precisa chamá-las pela API (o EXECUTE só é checado ao criar o trigger).
revoke execute on function public.novo_usuario()         from public, anon, authenticated;
revoke execute on function public.protege_ultimo_admin() from public, anon, authenticated;
revoke execute on function public.protege_perfis_extra() from public, anon, authenticated;
-- (registra_historico() é tratada no fim do auditoria.sql)
-- Funções auxiliares das políticas: só usuários logados (as políticas rodam como authenticated).
revoke execute on function public.sou_admin()                       from public, anon;
revoke execute on function public.sou_ativo()                       from public, anon;
revoke execute on function public.sou_gestor()                      from public, anon;
revoke execute on function public.meu_perfil()                      from public, anon;
revoke execute on function public.pode_financeiro()                 from public, anon;
revoke execute on function public.pode_gravar_turma(text)           from public, anon;
revoke execute on function public.professor_da_chamada(text, jsonb) from public, anon;
grant execute on function public.sou_admin()                       to authenticated;
grant execute on function public.sou_ativo()                       to authenticated;
grant execute on function public.sou_gestor()                      to authenticated;
grant execute on function public.meu_perfil()                      to authenticated;
grant execute on function public.pode_financeiro()                 to authenticated;
grant execute on function public.pode_gravar_turma(text)           to authenticated;
grant execute on function public.professor_da_chamada(text, jsonb) to authenticated;

-- ---------- 7. Conferência (opcional) ----------
-- select tablename, policyname, cmd, qual, with_check from pg_policies where schemaname = 'public' order by 1, 2;
