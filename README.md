# Vellora Semijoias · catálogo com área da loja

Arquivos:
- `index.html` → catálogo que os clientes veem
- `admin.html` → login + cadastro das peças (só você acessa)
- `style.css`, `config.js`, `setup.sql`

## Passo a passo

1. **Crie um projeto grátis** em https://supabase.com (Start your project → New project).
2. No menu **SQL Editor → New query**, cole o conteúdo de `setup.sql` e clique em **Run**.
3. Crie o **seu usuário**: **Authentication → Users → Add user → Create new user**. Informe seu e-mail e uma senha forte e marque a opção de confirmar o e-mail automaticamente.
4. **Bloqueie novos cadastros** (importante): **Authentication → Sign In / Providers → Email** (ou *Settings*, dependendo da versão do painel) e desative **“Allow new users to sign up”**. Assim, só você consegue entrar.
5. Pegue as chaves em **Project Settings → API**: copie a **Project URL** e a chave **anon public** e cole em `config.js`.
   Nunca use a chave `service_role` no site.
6. **Suba os arquivos no GitHub** (repositório novo → Add file → Upload files).
7. No repositório: **Settings → Pages → Branch: main / (root) → Save**. Em 1 ou 2 minutos o site fica em `https://SEU-USUARIO.github.io/NOME-DO-REPOSITORIO/`.
8. Entre em `.../admin.html`, faça login e cadastre as peças. Elas aparecem no catálogo na hora, sem republicar nada.

## Observações
- O link do admin não aparece em lugar nenhum do catálogo. Guarde o endereço.
- A segurança vem das regras do `setup.sql`: qualquer pessoa **lê** o catálogo, mas só quem está logado **cria, edita ou apaga**.
- No plano gratuito, o Supabase pausa projetos sem uso por cerca de uma semana. É só reativar no painel.
- Os nomes dos menus do Supabase podem mudar com o tempo.
