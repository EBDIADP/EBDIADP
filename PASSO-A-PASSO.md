# EBD IADP online: passo a passo

Este guia serve para **instalar do zero** e para **manter** o sistema. Arquivos do projeto:

| Arquivo | Para que serve | Sobe para o site? |
|---|---|---|
| `index.html` | O app inteiro | Sim |
| `manifest.webmanifest`, `sw.js` | Instalação no celular e tela offline | Sim |
| `icon-192.png`, `icon-512.png`, `icon-maskable-512.png`, `apple-touch-icon.png` | Ícones do app | Sim |
| `schema.sql` | Banco de dados e regras de acesso (Supabase) | Não (só guardar) |
| `PASSO-A-PASSO.md` | Este guia | Não (só guardar) |

Os nomes dos menus dos sites podem mudar um pouco com o tempo.

## Situação atual (produção)

- O banco já está criado no Supabase e as regras de acesso já foram aplicadas.
- O `index.html` já está configurado com a URL e a chave pública desse projeto.
- O site é publicado no GitHub Pages: `https://brncompany.github.io/EBDIADP/`. Confira em **Settings › Pages** do repositório qual repositório e qual branch publicam o site.
- O código fica no repositório `github.com/EBDIADP/EBDIADP` (branch `main`).

Se você só vai **atualizar** o app, vá direto para a seção **Atualizar o app depois**. O restante deste guia descreve a instalação completa, para refazer ou copiar o sistema para outro projeto.

## 1. Criar o banco (Supabase)

1. Acesse **supabase.com**, crie uma conta e clique em **New project**.
2. Dê um nome (ex.: `ebd`), crie uma **senha do banco** (guarde-a) e escolha uma região próxima (ex.: São Paulo).
3. Espere o projeto terminar de criar.

## 2. Criar as tabelas e as regras de acesso

1. No menu lateral, abra **SQL Editor** › **New query**.
2. Abra o arquivo `schema.sql`, copie **todo** o conteúdo, cole no editor e clique em **Run**.
3. Deve aparecer "Success". Se der erro, copie a mensagem e peça ajuda.

O `schema.sql` cria as tabelas, o cadastro automático de usuários, a proteção do último administrador e as regras de acesso por perfil. Ele pode ser executado de novo sem apagar dados.

Aviso: o arquivo original foi perdido e este foi reconstruído a partir do banco em produção. Se for usá-lo em um projeto novo, teste antes em um projeto de teste.

## 3. Ajustar o login

1. Abra **Authentication** e procure as configurações do provedor **Email**.
2. Deixe o login por e-mail e senha **ligado**.
3. Escolha sobre **Confirm email** (confirmação por e-mail):
   - **Desligado:** a pessoa cria a conta e já entra na fila de aprovação. É mais simples.
   - **Ligado:** ela precisa clicar no link do e-mail antes. É mais seguro, mas o e-mail padrão do Supabase tem limite de envios.
4. Depois de publicar o site (passo 6), volte em **Authentication › URL Configuration** e coloque o endereço do site em **Site URL**. Isso faz o link de "Esqueci a senha" voltar para o seu site.

## 4. Copiar as chaves do projeto

1. Abra **Project Settings** › **API** (ou **API Keys**).
2. Copie a **Project URL** (algo como `https://abcd1234.supabase.co`).
3. Copie a chave **pública**, chamada `anon` ou `publishable`.
4. **Nunca use** a chave `service_role` ou `secret`. Ela dá acesso total e não pode ficar no site.

A chave pública pode ficar no `index.html`, porque quem protege os dados são as regras do banco (passo 2).

## 5. Colar as chaves no app

Só é necessário em um projeto novo. O `index.html` de produção já vem preenchido.

1. Abra o `index.html` em um editor de texto.
2. Procure por `SUPABASE_URL` (perto do começo do script).
3. Troque os dois valores:
   ```js
   const SUPABASE_URL='https://abcd1234.supabase.co',SUPABASE_KEY='sua-chave-publica';
   ```
4. Salve o arquivo.

## 6. Publicar o site

Os arquivos da primeira tabela marcados como "Sim" precisam subir juntos, na mesma pasta (sem eles o app não instala no celular).

**GitHub Pages (usado hoje):**
1. Envie os arquivos para o repositório (botão **Add file › Upload files**, depois **Commit changes**).
2. Em **Settings › Pages**, escolha a branch `main` e a pasta raiz.
3. Aguarde de 1 a 2 minutos. O endereço aparece na mesma tela.

**Alternativas** (o arquivo é o mesmo): Netlify (arrastar a pasta em `app.netlify.com/drop`), Cloudflare Pages ou Vercel.

Depois de publicar, volte ao passo 3.4 e coloque o endereço em **Site URL**.

## 7. Criar o administrador (faça isto primeiro)

1. Abra o site, toque em **Criar conta** e use o e-mail de quem será o administrador.
2. **A primeira conta criada vira administradora automaticamente.** Por isso, faça este passo antes de divulgar o endereço.
3. Entre. As cinco turmas serão criadas sozinhas na primeira entrada do administrador: Desbravadores, Chamados por Deus, Bereanos, Escolhidas e Carvalhos da Justiça.

## 8. Liberar os demais usuários

1. Cada pessoa abre o site, toca em **Criar conta** e cadastra nome, e-mail e senha.
2. Ela verá "Aguardando aprovação".
3. O administrador abre **Gerenciar › Usuários**, toca em **⋯ › Editar**, escolhe o **Perfil**, faz os **vínculos** (veja abaixo), marca **Ativo** e salva.
4. A pessoa sai, entra de novo e já usa o app.

### Perfis e vínculos

| Perfil | O que vê e faz no app | Vínculo necessário |
|---|---|---|
| **Administrador(a)** | Tudo, incluindo Usuários e backup | Aluno (opcional) |
| **Secretário(a)** | Acompanha uma turma: chamada, agenda, histórico, faltas; agenda aulas, cadastra alunos e publica avisos nela | **Turma** (obrigatório) |
| **Líder** | Igual ao secretário(a) | **Turma** e **aluno** (ambos obrigatórios) |
| **Professor(a)** | Vê e faz a chamada apenas das aulas em que é o(a) professor(a); só leitura nas demais telas | **Aluno** (obrigatório) |

**Importante:** líder e secretário(a) **sem turma vinculada não conseguem salvar nada**. O banco só aceita gravações de líder e secretário(a) na turma vinculada a eles.

Para remover alguém por completo, desative-a no app. Para apagar o login dela, exclua também em **Authentication › Users** no Supabase.

## Como as permissões funcionam

O banco (Supabase) recusa gravações fora destas regras, mesmo que alguém tente burlar a tela do app:

| Ação | Quem pode |
|---|---|
| Ler turmas, alunos, aulas, avisos e chamadas | Qualquer usuário **ativo** |
| Ler qualquer dado sem estar logado, ou com conta inativa | Ninguém |
| Criar ou excluir turmas | Só o administrador |
| Alterar alunos de uma turma | Administrador; líder e secretário(a) apenas da própria turma |
| Criar, alterar e excluir aulas e avisos | Administrador; líder e secretário(a) apenas da própria turma |
| Salvar chamadas | Administrador; líder e secretário(a) da própria turma; professor |
| Excluir chamadas | Administrador; líder e secretário(a) da própria turma |
| Ver a lista de usuários, mudar perfil, ativar, excluir | Só o administrador |
| Nunca ficar sem administrador ativo | Sempre |
| Backup (exportar e importar) | Só o administrador (tela do app) |

**Limites que ainda existem:**

- **A leitura não é separada por turma.** A tela esconde as outras turmas de líder, secretário(a) e professor, mas o banco entrega todos os dados a qualquer usuário ativo. Isso inclui nascimento de crianças e telefone de responsáveis.
- **O professor pode salvar a chamada de qualquer turma**, não só das aulas em que é o responsável. Só a tela impede isso.

Por isso, libere acesso só a quem precisa e desative quem sair da equipe.

## Mensagens de erro ao salvar

- **"Sem permissão para essa alteração. Os dados foram recarregados do servidor."** O banco recusou a gravação pelas regras acima. A alteração foi descartada e a tela voltou ao que está salvo. Se acontecer com alguém que deveria poder, confira o perfil e os vínculos dessa pessoa (principalmente a **turma** de líder e secretário(a)).
- **"Atenção: não foi possível salvar no servidor. Verifique a conexão e tente de novo."** Problema de internet ou do Supabase. Aguarde e tente de novo. Não feche o app antes de a mensagem sumir e a gravação ser concluída.

Depois de uma gravação importante, vale recarregar a página e conferir.

## Cuidados

- **Dados de menores e LGPD:** o app guarda nascimento de crianças e telefone de responsáveis. Libere acesso só a quem precisa, desative quem sair da equipe e avise os responsáveis sobre o uso dos dados.
- **Cópia de segurança:** exporte o backup (Gerenciar › Turmas, como administrador) de tempos em tempos e guarde o arquivo. Confira também as regras de backup do seu plano no Supabase.
- **Projeto pausado:** projetos gratuitos podem ser pausados depois de um período sem uso. Confira as regras atuais do plano. Se pausar, basta reativar no painel.
- **Atualização dos dados:** o app busca os dados ao entrar e quando você volta para a aba. Se duas pessoas editarem o mesmo registro ao mesmo tempo, vale a última gravação.
- **E-mails de redefinição de senha:** o envio padrão do Supabase tem limite. Se muita gente precisar, configure um servidor de e-mail próprio nas configurações de Authentication.
- **Chaves:** a chave pública pode ficar no código. Se alguma vez a chave `service_role` ou `secret` for colada no `index.html` ou publicada, gere uma nova no Supabase imediatamente.

## Atualizar o app depois

1. Substitua o arquivo alterado (normalmente `index.html`) no repositório e faça o **Commit**.
2. Aguarde de 1 a 2 minutos a publicação do GitHub Pages.
3. Nos celulares, feche e abra o app uma ou duas vezes para carregar a versão nova.

Os dados ficam no banco e não são afetados.

**Se mudar as regras do banco**, rode o SQL no Supabase e **atualize também o `schema.sql`** guardado, para ele continuar sendo a cópia fiel do que está em produção. Para conferir as regras em vigor:

```sql
select tablename, policyname, cmd, qual, with_check
from pg_policies where schemaname = 'public' order by 1, 2;
```

## 9. Instalar como app no celular

O site precisa estar em um endereço `https://` (GitHub Pages, Netlify, Cloudflare Pages e Vercel já são).

**Android (Chrome):**
1. Abra o endereço do site.
2. Toque nos três pontinhos › **Instalar app** (ou **Adicionar à tela inicial**).
3. O ícone da EBD aparece na tela inicial e abre em tela cheia.

**iPhone (Safari):**
1. Abra o endereço no **Safari** (não funciona pelo Chrome do iPhone).
2. Toque em **Compartilhar** › **Adicionar à Tela de Início**.

**Observações:**
- O app precisa de internet para mostrar e salvar dados, que ficam no Supabase. Sem internet, só a tela inicial abre.
- Ele busca sempre a versão mais nova do site. Depois de atualizar os arquivos na hospedagem, feche e abra o app uma ou duas vezes.
- Esse app não aparece na Play Store nem na App Store. Cada pessoa instala pelo navegador, e você pode mandar o endereço pelo WhatsApp.
- Para trocar o ícone, substitua os arquivos `.png` mantendo os mesmos nomes e tamanhos (192, 512, 512 e 180 pixels).
