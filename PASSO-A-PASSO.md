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
- O site é publicado no GitHub Pages: `https://ebdiadp.github.io/EBDIADP/`. Esse é o endereço que deve estar em **Site URL** no Supabase.
- O código fica no repositório `github.com/EBDIADP/EBDIADP` (branch `main`).
- A **confirmação de e-mail está desligada** e o **envio de e-mails (SMTP próprio) ainda não funciona**. Por isso o botão **Esqueci a senha** foi **desativado** no app: na tela de login aparece a orientação de falar com o administrador. Veja a seção **Recuperação de senha e envio de e-mails**.

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
3. Em **Authentication › Sign In / Providers**, na seção "Cadastros de usuários" (em português, "Entrar / Fornecedores"), deixe **Permitir que novos usuários se cadastrem** ligado e **desligue** **Confirm email** (Confirmar e-mail). Clique em **Salvar alterações**.
   - **Desligado (recomendado):** a pessoa cria a conta e já entra na fila de aprovação, sem depender de e-mail. Como o administrador aprova cada conta, a confirmação por e-mail faz pouca falta.
   - **Ligado:** cada cadastro envia um e-mail de confirmação. O envio padrão do Supabase permite só **2 e-mails por hora no projeto inteiro** e logo aparece o erro **"email rate limit exceeded"** (o app mostra "Não foi possível criar a conta"). Só ligue depois de ter um SMTP próprio funcionando.
4. Depois de publicar o site (passo 6), volte em **Authentication › URL Configuration** e coloque `https://ebdiadp.github.io/EBDIADP/` em **Site URL**. Isso faz o link de "Esqueci a senha" voltar para o seu site.

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

**O repositório precisa ser público.** No plano gratuito do GitHub, o GitHub Pages só publica repositórios públicos. Ao tornar o repositório privado, o site é desativado e dá erro 404, e voltar para público **não** o reativa sozinho. Isso não expõe os dados da igreja: eles ficam no Supabase, protegidos pelas regras do banco, e a chave que aparece no `index.html` é a chave pública. Nunca coloque uma chave `service_role` ou `secret` no repositório.

**Se o site der erro 404** (por exemplo, depois de alternar entre público e privado):
1. Deixe o repositório **público** (Settings › General › Danger Zone › Change visibility).
2. Em **Settings › Pages**, confira se a fonte é **Deploy from a branch**, branch `main`, pasta `/ (root)`, e clique em **Save**.
3. Faça um **novo commit** no repositório (por exemplo, edite e salve o `PASSO-A-PASSO.md`). Isso dispara a publicação de novo.
4. Na aba **Actions**, espere o fluxo "pages build and deployment" terminar com sucesso (alguns minutos).
5. Abra o endereço mostrado em **Settings › Pages** (trocar a visibilidade pode mudar o endereço) e atualize com **Ctrl + F5**. Se mudou, ajuste o **Site URL** no Supabase e avise quem tem o app instalado.

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

**Aviso de novos cadastros (para o administrador):** quando alguém cria uma conta, o administrador vê no app:
- uma faixa no topo da tela, "N pessoa(s) aguardam aprovação", que leva direto a **Gerenciar › Usuários**;
- um número ao lado de **Gerenciar** e de **Usuários**;
- com o app aberto, uma verificação a cada 1 minuto e um aviso rápido na tela quando chega um novo cadastro.

Conta como "aguardando aprovação" quem está **inativo e ainda sem vínculos** (sem turma e sem aluno). Ao ativar a pessoa e fazer os vínculos, o aviso some. O aviso só aparece com o app aberto; **não há e-mail nem notificação no celular**. E-mail depende de um SMTP funcionando (veja a seção **Recuperação de senha e envio de e-mails**).

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

## Recuperação de senha e envio de e-mails

**Situação atual:** o botão **Esqueci a senha** envia um e-mail, e isso **não funciona** hoje. Por isso ele foi **desativado** no app e a tela de login mostra "Esqueceu a senha? Fale com o administrador da EBD." Quem esquecer a senha precisa do administrador (veja "Enquanto o e-mail não funciona: redefinir a senha manualmente", mais abaixo). O envio padrão do Supabase é limitado a 2 e-mails por hora e não serve para uso real. Foi tentado um SMTP com o **Brevo** usando um Gmail como remetente, e o envio falhou (o cadastro com confirmação ligada deu erro 500). A causa exata não foi confirmada.

### Como fazer o "Esqueci a senha" funcionar (e reativar o botão)

É preciso configurar um SMTP próprio no Supabase (**Authentication › Emails › SMTP Settings**, marcando **Enable Custom SMTP**). Com ele, o limite padrão passa a ser de 30 e-mails por hora (ajustável em **Authentication › Rate Limits**).

**Opção recomendada: Resend (exige um domínio próprio)**

O Resend só envia para outras pessoas depois que você verifica um domínio que é seu (por exemplo `igrejaiadp.com.br`). Um Gmail não serve como domínio.

1. Crie uma conta em **resend.com** e vá em **Domains › Add Domain**. O Resend recomenda usar um subdomínio, como `updates.seudominio.com.br`.
2. Cadastre os registros DNS (SPF e DKIM) que o Resend mostra, no site onde o domínio está registrado. Espere o domínio aparecer como **Verified**.
3. Em **API Keys**, crie uma chave com permissão de envio e guarde-a.
4. No Supabase, em **SMTP Settings**, preencha:

| Campo | Valor |
|---|---|
| Sender email | um endereço do domínio verificado, ex.: `nao-responder@updates.seudominio.com.br` |
| Sender name | `EBD IADP` |
| Host | `smtp.resend.com` |
| Port | `465` |
| Username | `resend` |
| Password | a chave de API criada no passo 3 |

**Alternativa: Brevo (já tentada)**

O Brevo permite verificar um e-mail como remetente (**Senders**) e usa `smtp-relay.brevo.com`, porta `587`, com o **SMTP login** (parecido com `xxxx@smtp-brevo.com`) como usuário e uma **SMTP key** como senha (não é a chave de API). Porém ele exige autenticação do domínio do remetente por causa das regras do Gmail, Yahoo e Microsoft. Com um remetente `@gmail.com`, o envio pode falhar ou os e-mails podem cair no spam. Se quiser tentar de novo, confira antes se a senha é a SMTP key (começa com `xsmtpsib-`) e se o remetente aparece como verificado.

**Para descobrir por que o envio falha:** no Supabase, abra **Logs › Auth** e procure a linha do momento do teste. Mensagens como "535 Authentication failed" indicam senha errada, e "sender is invalid" indica remetente recusado. No Brevo, **Transactional › Logs** mostra se a mensagem chegou lá.

**Como testar:** toque em **Esqueci a senha** no app com um e-mail real e confira a caixa de entrada e o spam (teste também com um provedor diferente). O link leva de volta ao app, que abre a tela de **Nova senha**. Para isso, o **Site URL** precisa estar correto (passo 3.4).

**Como reativar o botão:** quando o SMTP estiver funcionando e testado, no `index.html` procure o trecho abaixo (tela de login):

```
<div class="acts"><button class="tg" id="irCriar">Criar conta</button></div><p style="margin:12px 0 0;font-size:.85rem;opacity:.7">Esqueceu a senha? Fale com o administrador da EBD.</p>
```

e troque por:

```
<div class="acts"><button class="tg" id="irCriar">Criar conta</button><button class="tg" id="esqueci">Esqueci a senha</button></div>
```

O restante do código do botão continua no arquivo, então só essa troca é necessária. Depois faça o commit e teste.

**Cuidados:** a chave do Resend ou a SMTP key do Brevo é um segredo. Ela fica só no Supabase, nunca no `index.html` nem no GitHub. Se vazar, apague a chave no serviço e gere outra.

### Enquanto o e-mail não funciona: redefinir a senha manualmente

Atenção: o botão **Send password recovery** do painel do Supabase também envia e-mail, então não funciona sem SMTP.

**Opção A: o administrador define uma senha temporária pelo SQL.** No Supabase, abra **SQL Editor**, troque o e-mail e a senha e clique em **Run**:

```sql
update auth.users
set encrypted_password = extensions.crypt('SenhaTemporaria123', extensions.gen_salt('bf'))
where email = 'pessoa@exemplo.com';
```

Teste primeiro com uma conta de teste. Entregue a senha temporária à pessoa por um canal seguro. Pelo que consta no código, o app só mostra a tela de nova senha pelo link do e-mail, então a pessoa continuará usando essa senha. Use uma senha diferente para cada pessoa.

**Opção B: excluir e recadastrar.** Exclua a conta em **Authentication › Users** e peça para a pessoa criar a conta de novo. Depois o administrador a aprova e refaz o perfil e os vínculos em **Gerenciar › Usuários**.

## Mensagens de erro ao salvar

- **"Sem permissão para essa alteração. Os dados foram recarregados do servidor."** O banco recusou a gravação pelas regras acima. A alteração foi descartada e a tela voltou ao que está salvo. Se acontecer com alguém que deveria poder, confira o perfil e os vínculos dessa pessoa (principalmente a **turma** de líder e secretário(a)).
- **"Atenção: não foi possível salvar no servidor. Verifique a conexão e tente de novo."** Problema de internet ou do Supabase. Aguarde e tente de novo. Não feche o app antes de a mensagem sumir e a gravação ser concluída.

Depois de uma gravação importante, vale recarregar a página e conferir.

**Mensagens no cadastro e no login:**

- **"Não foi possível criar a conta: email rate limit exceeded"**: o limite de e-mails do Supabase foi atingido. Desligue o **Confirm email** (passo 3) e espere até 1 hora.
- **"Não foi possível enviar o e-mail"**: só aparece se o botão **Esqueci a senha** for reativado e o envio de e-mail não estiver funcionando. Veja a seção **Recuperação de senha e envio de e-mails**.

## Cuidados

- **Dados de menores e LGPD:** o app guarda nascimento de crianças e telefone de responsáveis. Libere acesso só a quem precisa, desative quem sair da equipe e avise os responsáveis sobre o uso dos dados.
- **Cópia de segurança:** exporte o backup (Gerenciar › Turmas, como administrador) de tempos em tempos e guarde o arquivo. Confira também as regras de backup do seu plano no Supabase.
- **Projeto pausado:** projetos gratuitos podem ser pausados depois de um período sem uso. Confira as regras atuais do plano. Se pausar, basta reativar no painel.
- **Atualização dos dados:** o app busca os dados ao entrar e quando você volta para a aba. Se duas pessoas editarem o mesmo registro ao mesmo tempo, vale a última gravação.
- **E-mails de redefinição de senha:** não funcionam com o envio padrão do Supabase (2 por hora). É preciso configurar um SMTP próprio. Veja a seção **Recuperação de senha e envio de e-mails**.
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
