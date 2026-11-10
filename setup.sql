-- Rode este arquivo inteiro: Supabase > SQL Editor > New query > Run
-- Pode ser rodado mais de uma vez sem dar erro.

-- ============ TABELAS ============
create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price numeric(10,2) default 0,
  category text default 'Outros',
  description text default '',
  image_url text default '',
  sold_out boolean default false,
  created_at timestamptz default now()
);
alter table products add column if not exists old_price numeric(10,2);

create table if not exists settings (
  id int primary key default 1 check (id = 1),
  store_name text default 'Vellora',
  tagline text default 'Brilho que conta a sua história',
  whatsapp text default ''
);
alter table settings add column if not exists installments int default 5;
insert into settings (id) values (1) on conflict do nothing;

create table if not exists categories (name text primary key, video_url text);

-- Sacola de cada cliente (cada pessoa só enxerga a própria)
create table if not exists cart_items (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,
  qty int not null default 1 check (qty > 0),
  primary key (user_id, product_id)
);

-- ============ QUEM É A DONA DA LOJA ============
-- TROQUE pelo e-mail que você usa para entrar no admin.html
create table if not exists admins (email text primary key);
insert into admins (email) values ('kaique@5514.com') on conflict do nothing;
alter table admins enable row level security;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where lower(email) = lower(coalesce(auth.jwt() ->> 'email', '')))
$$;

-- ============ SEGURANÇA ============
alter table products enable row level security;
alter table settings enable row level security;
alter table categories enable row level security;
alter table cart_items enable row level security;

-- produtos: todos leem, só a dona escreve
drop policy if exists "catalogo publico" on products;
create policy "catalogo publico" on products for select using (true);
drop policy if exists "dona insere" on products;
create policy "dona insere" on products for insert to authenticated with check (public.is_admin());
drop policy if exists "dona edita" on products;
create policy "dona edita" on products for update to authenticated using (public.is_admin());
drop policy if exists "dona exclui" on products;
create policy "dona exclui" on products for delete to authenticated using (public.is_admin());

-- dados da loja
drop policy if exists "config publica" on settings;
create policy "config publica" on settings for select using (true);
drop policy if exists "dona insere config" on settings;
create policy "dona insere config" on settings for insert to authenticated with check (public.is_admin());
drop policy if exists "dona edita config" on settings;
create policy "dona edita config" on settings for update to authenticated using (public.is_admin());

-- vídeos das categorias
drop policy if exists "categorias publicas" on categories;
create policy "categorias publicas" on categories for select using (true);
drop policy if exists "dona insere categoria" on categories;
create policy "dona insere categoria" on categories for insert to authenticated with check (public.is_admin());
drop policy if exists "dona edita categoria" on categories;
create policy "dona edita categoria" on categories for update to authenticated using (public.is_admin());
drop policy if exists "dona exclui categoria" on categories;
create policy "dona exclui categoria" on categories for delete to authenticated using (public.is_admin());

-- sacola: cada cliente só mexe na sua
drop policy if exists "sacola propria" on cart_items;
create policy "sacola propria" on cart_items for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============ FOTOS E VÍDEOS ============
insert into storage.buckets (id, name, public) values ('produtos', 'produtos', true) on conflict do nothing;
drop policy if exists "fotos publicas" on storage.objects;
create policy "fotos publicas" on storage.objects for select using (bucket_id = 'produtos');
drop policy if exists "dona envia fotos" on storage.objects;
create policy "dona envia fotos" on storage.objects for insert to authenticated with check (bucket_id = 'produtos' and public.is_admin());
drop policy if exists "dona troca fotos" on storage.objects;
create policy "dona troca fotos" on storage.objects for update to authenticated using (bucket_id = 'produtos' and public.is_admin());
drop policy if exists "dona apaga fotos" on storage.objects;
create policy "dona apaga fotos" on storage.objects for delete to authenticated using (bucket_id = 'produtos' and public.is_admin());

-- ============ PAGAMENTO POR PIX ============
alter table settings add column if not exists pix_key text default '';
alter table settings add column if not exists pix_name text default '';
alter table settings add column if not exists pix_city text default '';

create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  number bigint generated always as identity,
  user_id uuid references auth.users(id) on delete set null,
  user_email text,
  items jsonb not null default '[]',
  total numeric(10,2) not null default 0,
  status text not null default 'aguardando' check (status in ('aguardando','pago','enviado','cancelado')),
  created_at timestamptz default now(),
  paid_at timestamptz
);
alter table orders enable row level security;
drop policy if exists "ver pedidos" on orders;
create policy "ver pedidos" on orders for select to authenticated using (user_id = auth.uid() or public.is_admin());
drop policy if exists "dona atualiza pedidos" on orders;
create policy "dona atualiza pedidos" on orders for update to authenticated using (public.is_admin());
drop policy if exists "dona apaga pedidos" on orders;
create policy "dona apaga pedidos" on orders for delete to authenticated using (public.is_admin());
-- Não existe permissão de "insert": o pedido só nasce pela função abaixo, que calcula o total no servidor.


-- ============ FRETE E ENTREGA ============
alter table settings add column if not exists free_ship_from numeric(10,2) default 0;
alter table settings add column if not exists pickup_text text default '';
alter table orders add column if not exists ship_method text default 'entrega';
alter table orders add column if not exists ship_price numeric(10,2) default 0;
alter table orders add column if not exists ship_cep text;
alter table orders add column if not exists ship_uf text;
alter table orders add column if not exists ship_days text;
alter table orders add column if not exists customer_name text;
alter table orders add column if not exists customer_phone text;
alter table orders add column if not exists address jsonb;
alter table orders add column if not exists tracking text;
alter table orders add column if not exists shipped_at timestamptz;

-- Valor do frete por estado (REVISE estes valores no painel, aba Loja > Frete)
create table if not exists shipping_rates (uf text primary key, price numeric(10,2) not null default 0, days text default '');
alter table shipping_rates enable row level security;
drop policy if exists "frete publico" on shipping_rates;
create policy "frete publico" on shipping_rates for select using (true);
drop policy if exists "dona insere frete" on shipping_rates;
create policy "dona insere frete" on shipping_rates for insert to authenticated with check (public.is_admin());
drop policy if exists "dona edita frete" on shipping_rates;
create policy "dona edita frete" on shipping_rates for update to authenticated using (public.is_admin());
drop policy if exists "dona exclui frete" on shipping_rates;
create policy "dona exclui frete" on shipping_rates for delete to authenticated using (public.is_admin());
insert into shipping_rates (uf, price, days) values
 ('SP',15,'2 a 5 dias úteis'),
 ('RJ',20,'3 a 6 dias úteis'),('MG',20,'3 a 6 dias úteis'),('ES',20,'3 a 6 dias úteis'),
 ('PR',22,'4 a 7 dias úteis'),('SC',22,'4 a 7 dias úteis'),('RS',22,'4 a 7 dias úteis'),
 ('DF',25,'4 a 8 dias úteis'),('GO',25,'4 a 8 dias úteis'),('MT',25,'4 a 8 dias úteis'),('MS',25,'4 a 8 dias úteis'),
 ('BA',28,'5 a 9 dias úteis'),('SE',28,'5 a 9 dias úteis'),('AL',28,'5 a 9 dias úteis'),('PE',28,'5 a 9 dias úteis'),('PB',28,'5 a 9 dias úteis'),
 ('RN',28,'5 a 9 dias úteis'),('CE',28,'5 a 9 dias úteis'),('PI',28,'5 a 9 dias úteis'),('MA',28,'5 a 9 dias úteis'),
 ('AM',32,'7 a 12 dias úteis'),('PA',32,'7 a 12 dias úteis'),('AC',32,'7 a 12 dias úteis'),('RO',32,'7 a 12 dias úteis'),
 ('RR',32,'7 a 12 dias úteis'),('AP',32,'7 a 12 dias úteis'),('TO',32,'7 a 12 dias úteis')
on conflict do nothing;

-- Descobre o estado pelo CEP (faixas oficiais dos Correios)
create or replace function public.uf_from_cep(p_cep text) returns text language sql immutable as $$
  select case when length(d) <> 8 then null else case
    when n between 1000000 and 19999999 then 'SP'
    when n between 20000000 and 28999999 then 'RJ'
    when n between 29000000 and 29999999 then 'ES'
    when n between 30000000 and 39999999 then 'MG'
    when n between 40000000 and 48999999 then 'BA'
    when n between 49000000 and 49999999 then 'SE'
    when n between 50000000 and 56999999 then 'PE'
    when n between 57000000 and 57999999 then 'AL'
    when n between 58000000 and 58999999 then 'PB'
    when n between 59000000 and 59999999 then 'RN'
    when n between 60000000 and 63999999 then 'CE'
    when n between 64000000 and 64999999 then 'PI'
    when n between 65000000 and 65999999 then 'MA'
    when n between 66000000 and 68899999 then 'PA'
    when n between 68900000 and 68999999 then 'AP'
    when n between 69000000 and 69299999 or n between 69400000 and 69899999 then 'AM'
    when n between 69300000 and 69399999 then 'RR'
    when n between 69900000 and 69999999 then 'AC'
    when n between 70000000 and 72799999 or n between 73000000 and 73699999 then 'DF'
    when n between 72800000 and 72999999 or n between 73700000 and 76799999 then 'GO'
    when n between 76800000 and 76999999 then 'RO'
    when n between 77000000 and 77999999 then 'TO'
    when n between 78000000 and 78899999 then 'MT'
    when n between 79000000 and 79999999 then 'MS'
    when n between 80000000 and 87999999 then 'PR'
    when n between 88000000 and 89999999 then 'SC'
    when n between 90000000 and 99999999 then 'RS'
  end end
  from (select regexp_replace(coalesce(p_cep, ''), '\D', '', 'g') as d) a,
       lateral (select case when length(a.d) = 8 then a.d::bigint end as n) b
$$;

-- Orçamento de frete (usado pela sacola, antes do login)
create or replace function public.quote_shipping(p_cep text, p_subtotal numeric default 0) returns json
language plpgsql stable security definer set search_path = public as $$
declare u text; r shipping_rates; fs numeric;
begin
  u := uf_from_cep(p_cep);
  if u is null then return json_build_object('error', 'cep'); end if;
  select * into r from shipping_rates where uf = u;
  if not found then return json_build_object('error', 'region', 'uf', u); end if;
  select coalesce(free_ship_from, 0) into fs from settings where id = 1;
  return json_build_object('uf', u, 'price', case when fs > 0 and p_subtotal >= fs then 0 else r.price end,
                           'days', r.days, 'free', (fs > 0 and p_subtotal >= fs));
end $$;
grant execute on function public.quote_shipping(text, numeric) to anon, authenticated;

-- Cria o pedido: total e frete são calculados AQUI, no servidor
drop function if exists public.create_order();
create or replace function public.create_order(p_method text, p_cep text, p_info jsonb) returns orders
language plpgsql security definer set search_path = public as $$
declare o orders; sub numeric; its jsonb; shp numeric := 0; u text; r shipping_rates; fs numeric; pk text;
        cepd text; m text := 'entrega'; dd text;
begin
  if auth.uid() is null then raise exception 'login'; end if;
  if length(coalesce(p_info::text, '')) > 3000 then raise exception 'dados'; end if;
  select coalesce(sum(p.price * c.qty), 0),
         coalesce(jsonb_agg(jsonb_build_object('product_id', p.id, 'name', p.name, 'price', p.price, 'qty', c.qty)), '[]'::jsonb)
    into sub, its
    from cart_items c join products p on p.id = c.product_id
   where c.user_id = auth.uid() and p.sold_out = false;
  if sub <= 0 then raise exception 'sacola vazia'; end if;
  select coalesce(free_ship_from, 0), coalesce(pickup_text, '') into fs, pk from settings where id = 1;
  cepd := regexp_replace(coalesce(p_cep, ''), '\D', '', 'g');
  if p_method = 'retirada' and pk <> '' then
    m := 'retirada';
  else
    u := uf_from_cep(cepd);
    if u is null then raise exception 'cep'; end if;
    select * into r from shipping_rates where uf = u;
    if not found then raise exception 'regiao'; end if;
    shp := case when fs > 0 and sub >= fs then 0 else r.price end;
    dd := r.days;
  end if;
  insert into orders (user_id, user_email, items, total, ship_method, ship_price, ship_cep, ship_uf, ship_days,
                      customer_name, customer_phone, address)
    values (auth.uid(), auth.jwt() ->> 'email', its, sub + shp, m, shp, cepd, u, dd,
            left(coalesce(p_info ->> 'name', ''), 120), left(coalesce(p_info ->> 'phone', ''), 30), p_info)
    returning * into o;
  delete from cart_items where user_id = auth.uid();
  return o;
end $$;
revoke all on function public.create_order(text, text, jsonb) from public;
grant execute on function public.create_order(text, text, jsonb) to authenticated;

-- ============ ELOGIOS DAS CLIENTES ============
create table if not exists reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  author text not null check (char_length(author) between 2 and 40),
  stars int not null check (stars between 1 and 5),
  body text not null check (char_length(body) between 5 and 400),
  verified boolean not null default false,
  created_at timestamptz default now(),
  unique (user_id)   -- cada cliente tem 1 elogio (ela pode editar ou apagar o dela)
);
alter table reviews enable row level security;

drop policy if exists "elogios publicos" on reviews;
create policy "elogios publicos" on reviews for select using (true);
drop policy if exists "cliente envia elogio" on reviews;
create policy "cliente envia elogio" on reviews for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "cliente edita elogio" on reviews;
create policy "cliente edita elogio" on reviews for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "cliente ou dona apaga elogio" on reviews;
create policy "cliente ou dona apaga elogio" on reviews for delete to authenticated using (user_id = auth.uid() or public.is_admin());

-- "Compra verificada" é decidido pelo servidor (a cliente não consegue marcar sozinha)
create or replace function public.reviews_set_verified() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' then new.user_id := old.user_id; end if;
  new.verified := exists (select 1 from orders o where o.user_id = new.user_id and o.status in ('pago', 'enviado'));
  return new;
end $$;
drop trigger if exists reviews_verified on reviews;
create trigger reviews_verified before insert or update on reviews
  for each row execute function public.reviews_set_verified();
