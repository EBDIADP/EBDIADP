-- Chamada pública por link temporário e de uso único.
-- Execute no SQL Editor do Supabase. O token cru nunca é salvo no banco.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.chamada_links (
  token_hash text primary key,
  turma_id text not null,
  dia date not null,
  criado_por uuid not null references auth.users(id) on delete cascade,
  criado_em timestamptz not null default now(),
  expira_em timestamptz not null,
  usado_em timestamptz,
  revogado_em timestamptz
);
alter table public.chamada_links enable row level security;
revoke all on public.chamada_links from public, anon, authenticated;

create or replace function public.criar_link_chamada(p_turma_id text, p_data date)
returns text language plpgsql security definer set search_path = '' as $$
declare v_token text; v_id uuid := auth.uid(); v_key text := p_data::text || '|' || p_turma_id;
begin
  if v_id is null or not exists (select 1 from public.perfis p where p.id=v_id and p.ativo) then
    raise exception 'Acesso negado';
  end if;
  if not public.pode_gravar_turma(p_turma_id)
     and not public.professor_da_chamada(v_key, coalesce((select c.dados from public.chamadas c where c.id=v_key), '{}'::jsonb)) then
    raise exception 'Você não pode compartilhar esta chamada';
  end if;
  if not exists (select 1 from public.aulas a where a.dados->>'turma'=p_turma_id and a.dados->>'data'=p_data::text) then
    raise exception 'A aula não existe';
  end if;
  update public.chamada_links set revogado_em=now()
    where turma_id=p_turma_id and dia=p_data and revogado_em is null and usado_em is null;
  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.chamada_links(token_hash,turma_id,dia,criado_por,expira_em)
    values (encode(extensions.digest(v_token,'sha256'),'hex'),p_turma_id,p_data,v_id,now()+interval '30 days');
  return v_token;
end $$;

create or replace function public.obter_chamada_publica(p_token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare l public.chamada_links%rowtype; t jsonb; c jsonb; g jsonb; v_key text;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then return jsonb_build_object('ok',false,'error','Link inválido'); end if;
  select * into l from public.chamada_links where token_hash=encode(extensions.digest(p_token,'sha256'),'hex');
  if not found or l.revogado_em is not null or l.expira_em<=now() then return jsonb_build_object('ok',false,'error','Este link expirou ou foi substituído. Peça um novo link.'); end if;
  select dados into t from public.turmas where id=l.turma_id;
  if t is null then return jsonb_build_object('ok',false,'error','Turma não encontrada'); end if;
  v_key := l.dia::text || '|' || l.turma_id;
  if l.usado_em is not null then
    return jsonb_build_object('ok',true,'turma',coalesce(t->>'nome','Turma'),'data',l.dia,'usado',true,'alunos','[]'::jsonb,'presentes','[]'::jsonb);
  end if;
  select dados into g from public.aulas where dados->>'turma'=l.turma_id and dados->>'data'=l.dia::text limit 1;
  select dados into c from public.chamadas where id=v_key;
  return jsonb_build_object('ok',true,'turma',coalesce(t->>'nome','Turma'),'data',l.dia,
    'tema',coalesce(c->'e'->>'tema',g->>'tema',''),'prof',coalesce(c->'e'->>'prof',g->>'prof',''),
    'topicos',coalesce(c->'e'->>'topicos',g->>'topicos',''),'extras',(coalesce(c->'e','{}'::jsonb)-'just'),
    'usado',l.usado_em is not null,
    'alunos',coalesce((select jsonb_agg(jsonb_build_object('id',a->>'id','nome',
      (case when coalesce(a->>'titulo','') not in ('','Membro') then (a->>'titulo')||' ' else '' end)||(a->>'nome')) order by a->>'nome')
      from jsonb_array_elements(case when jsonb_typeof(t->'alunos')='array' then t->'alunos' else '[]'::jsonb end) a
      where coalesce((a->>'ativo')::boolean,true) and coalesce((a->>'arq')::boolean,false)=false),'[]'::jsonb),
    'presentes',coalesce(c->'p','[]'::jsonb));
end $$;

drop function if exists public.salvar_chamada_publica(text,text[]);
create or replace function public.salvar_chamada_publica(p_token text,p_presentes text[],p_extras jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare l public.chamada_links%rowtype; v_key text; v_old jsonb; v_aula jsonb; v_ids text[]; v_roster text[]; v_bib integer; v_vis integer; v_oferta numeric; v_clima text;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then return jsonb_build_object('ok',false,'error','Link inválido'); end if;
  select * into l from public.chamada_links where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') for update;
  if not found or l.revogado_em is not null or l.expira_em<=now() then return jsonb_build_object('ok',false,'error','Este link expirou ou foi substituído. Peça um novo link.'); end if;
  if l.usado_em is not null then return jsonb_build_object('ok',false,'error','Esta chamada já foi enviada.'); end if;
  select coalesce(array_agg(a->>'id'),'{}'::text[]) into v_roster from public.turmas t
    cross join lateral jsonb_array_elements(case when jsonb_typeof(t.dados->'alunos')='array' then t.dados->'alunos' else '[]'::jsonb end) a
    where t.id=l.turma_id and coalesce((a->>'ativo')::boolean,true) and coalesce((a->>'arq')::boolean,false)=false;
  v_ids := coalesce(p_presentes,'{}'::text[]);
  if cardinality(v_ids)<>(select count(distinct x) from unnest(v_ids) x) or exists(select 1 from unnest(v_ids) x where not x=any(v_roster)) then
    return jsonb_build_object('ok',false,'error','A lista de presenças contém dados inválidos.');
  end if;
  v_bib := coalesce(nullif(p_extras->>'biblias','')::integer,0);
  v_vis := coalesce(nullif(p_extras->>'visitantes','')::integer,0);
  v_oferta := coalesce(nullif(p_extras->>'oferta','')::numeric,0);
  v_clima := coalesce(p_extras->>'clima','');
  if v_bib<0 or v_vis<0 or v_oferta<0 or v_clima not in ('','ensolarado','nublado','chuvoso') then
    return jsonb_build_object('ok',false,'error','Confira Bíblias, visitantes, contribuições e clima.');
  end if;
  v_key := l.dia::text || '|' || l.turma_id;
  select dados into v_aula from public.aulas where dados->>'turma'=l.turma_id and dados->>'data'=l.dia::text limit 1;
  select dados into v_old from public.chamadas where id=v_key;
  insert into public.chamadas(id,dados) values(v_key,jsonb_build_object('p',to_jsonb(v_ids),'e',coalesce(v_old->'e','{}'::jsonb) ||
    jsonb_build_object('biblias',v_bib,'oferta',v_oferta,'visitantes',v_vis,'clima',v_clima,'tema',coalesce(v_aula->>'tema',''),'prof',coalesce(v_aula->>'prof',''),'topicos',coalesce(v_aula->>'topicos',''))))
    on conflict(id) do update set dados=public.chamadas.dados || jsonb_build_object('p',to_jsonb(v_ids),
      'e',coalesce(public.chamadas.dados->'e','{}'::jsonb) || jsonb_build_object('biblias',v_bib,'oferta',v_oferta,'visitantes',v_vis,'clima',v_clima,'tema',coalesce(v_aula->>'tema',''),'prof',coalesce(v_aula->>'prof',''),'topicos',coalesce(v_aula->>'topicos','')));
  update public.chamada_links set usado_em=now() where token_hash=l.token_hash;
  return jsonb_build_object('ok',true);
end $$;

revoke execute on function public.criar_link_chamada(text,date) from public, anon;
revoke execute on function public.obter_chamada_publica(text) from public;
revoke execute on function public.salvar_chamada_publica(text,text[],jsonb) from public;
grant execute on function public.criar_link_chamada(text,date) to authenticated;
grant execute on function public.obter_chamada_publica(text) to anon, authenticated;
grant execute on function public.salvar_chamada_publica(text,text[],jsonb) to anon, authenticated;
