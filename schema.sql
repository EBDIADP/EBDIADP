-- =====================================================================
-- EBD IADP - banco de dados (Supabase / PostgreSQL)
-- Estado atual, com as regras de gravação por perfil (out/2026).
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
            check (perfil in ('admin','secretario','lider','professor')),
  ativo     boolean not null default false,
  aluno_id  text,   -- vínculo com o cadastro de aluno (professor, líder, secretário, admin)
  turma_id  text,   -- turma de líder e secretário
  criado_em timestamptz not null default now()
);

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

create or replace function public.meu_perfil() returns text
  language sql stable security definer set search_path = public as
$$ select perfil::text from public.perfis where id = auth.uid() and ativo $$;

-- true se for admin, ou líder/secretário vinculado à turma informada
create or replace function public.pode_gravar_turma(tid text) returns boolean
  language sql stable security definer set search_path = public as
$$ select coalesce((
     select perfil = 'admin'
         or (perfil in ('lider','secretario') and coalesce(tid,'') <> '' and turma_id::text = tid)
     from public.perfis where id = auth.uid() and ativo), false) $$;

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

-- turmas: criar e excluir só admin; alterar (alunos) admin ou líder/secretário da turma.
create policy turmas_inserir on public.turmas for insert with check (public.sou_admin());
create policy turmas_excluir on public.turmas for delete using (public.sou_admin());
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

-- chamadas: professor insere e altera; excluir só admin ou líder/secretário da turma.
create policy chamadas_inserir on public.chamadas for insert with check (
  public.meu_perfil() = 'professor' or public.pode_gravar_turma(split_part(id::text,'|',2)));
create policy chamadas_alterar on public.chamadas for update
  using (public.meu_perfil() = 'professor' or public.pode_gravar_turma(split_part(id::text,'|',2)))
  with check (public.meu_perfil() = 'professor' or public.pode_gravar_turma(split_part(id::text,'|',2)));
create policy chamadas_excluir on public.chamadas for delete
  using (public.pode_gravar_turma(split_part(id::text,'|',2)));

-- perfis: cada um vê o próprio; só o admin vê todos, altera e exclui (menos a si mesmo).
-- Não há política de INSERT: perfis só são criados pelo trigger ao_criar_usuario.
create policy perfis_ver     on public.perfis for select using (id = auth.uid() or public.sou_admin());
create policy perfis_alterar on public.perfis for update using (public.sou_admin()) with check (public.sou_admin());
create policy perfis_excluir on public.perfis for delete using (public.sou_admin() and id <> auth.uid());

-- ---------- 5. Conferência (opcional) ----------
-- select tablename, policyname, cmd, qual, with_check from pg_policies where schemaname = 'public' order by 1, 2;
