-- Encaja · esquema inicial de Supabase
-- Pega TODO este archivo en Supabase → SQL Editor → New query → Run.
-- Crea las tablas, el login por compañero (Supabase Auth), las
-- políticas de acceso y carga los 108 pisos actuales como datos
-- iniciales.
--
-- Después de correr esto, cada compañero necesita una cuenta creada a
-- mano desde el panel de Supabase (Authentication → Users → Add user)
-- — ver el README para el paso a paso. Sin login, nadie puede entrar
-- a la web.

create table if not exists public.compradores (
  id text primary key,
  nombre text not null,
  telefono text not null,
  zona text,
  tipo text,
  presupuesto numeric,
  caract text,
  agente text not null,
  owner_id uuid references auth.users(id) default auth.uid(),
  fecha timestamptz not null default now()
);

create table if not exists public.pisos (
  id text primary key,
  referencia text,
  zona text not null,
  tipo text,
  precio numeric,
  precio_anterior numeric,
  bajada_pct text,
  caract text,
  agente text,
  origen text,
  url text,
  reservado boolean not null default false,
  fecha timestamptz not null default now()
);

create table if not exists public.contactados (
  match_key text primary key,
  fecha timestamptz not null default now()
);

-- Perfil de cada usuario: su nombre para mostrar y si es admin.
create table if not exists public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text,
  is_admin boolean not null default false,
  creado timestamptz not null default now()
);

alter table public.perfiles enable row level security;

drop policy if exists "perfiles_select_propio" on public.perfiles;
create policy "perfiles_select_propio" on public.perfiles
  for select using (auth.uid() = id);

drop policy if exists "perfiles_update_propio" on public.perfiles;
create policy "perfiles_update_propio" on public.perfiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- Crea el perfil automáticamente en cuanto se crea un usuario nuevo
-- (por ejemplo, al añadirlo a mano desde Authentication → Users).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.perfiles (id, nombre)
  values (new.id, coalesce(new.raw_user_meta_data->>'nombre', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ¿El usuario que hace la consulta es admin? (para las políticas de abajo)
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select is_admin from public.perfiles where id = auth.uid()), false);
$$;

-- RLS: hace falta sesión iniciada para usar la web. Los pisos son un
-- catálogo compartido por todo el equipo (sin dueño individual). Los
-- compradores sí quedan ligados a quien los creó: un agente normal
-- solo ve los suyos; un admin los ve todos.

alter table public.compradores enable row level security;
alter table public.pisos enable row level security;
alter table public.contactados enable row level security;

drop policy if exists "compradores_all" on public.compradores;
drop policy if exists "compradores_select" on public.compradores;
drop policy if exists "compradores_insert" on public.compradores;
drop policy if exists "compradores_update" on public.compradores;
drop policy if exists "compradores_delete" on public.compradores;

create policy "compradores_select" on public.compradores
  for select using (owner_id = auth.uid() or public.is_admin());

create policy "compradores_insert" on public.compradores
  for insert with check (owner_id = auth.uid());

create policy "compradores_update" on public.compradores
  for update using (owner_id = auth.uid() or public.is_admin())
  with check (owner_id = auth.uid() or public.is_admin());

create policy "compradores_delete" on public.compradores
  for delete using (owner_id = auth.uid() or public.is_admin());

-- El scraper de encaja-scraper escribe en "pisos" con la
-- service_role key, que siempre salta la RLS — estas políticas solo
-- afectan a la web (que usa la anon key + sesión de usuario).
drop policy if exists "pisos_all" on public.pisos;
create policy "pisos_all" on public.pisos
  for all using (auth.uid() is not null) with check (auth.uid() is not null);

drop policy if exists "contactados_all" on public.contactados;
create policy "contactados_all" on public.contactados
  for all using (auth.uid() is not null) with check (auth.uid() is not null);

-- Datos iniciales: los 108 pisos ya detectados por el scraper.
insert into public.pisos
  (id, referencia, zona, tipo, precio, precio_anterior, bajada_pct, caract, agente, origen, url, reservado, fecha)
values
  ('ip-2537-nuevo-169950-0b96c9', '2537', 'Juan XXIII', 'Flat', 169950, NULL, NULL, '3 hab · 2 baños · 87 m2 · ref. 2537 · https://www.inmoparadise.com/ficha/flat/alicante/juan-xxiii/10473/29856254/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/juan-xxiii/10473/29856254/en/', false, '2026-08-24T09:48:19.866741+00:00'),
  ('ip-2559-nuevo-119950-a949a2', '2559', 'Ciudad Elegida', 'Flat', 119950, NULL, NULL, '3 hab · 1 baños · 80 m2 · ref. 2559 · https://www.inmoparadise.com/ficha/flat/alicante/ciudad-elegida/10473/30022170/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/ciudad-elegida/10473/30022170/en/', false, '2026-08-24T09:48:19.866770+00:00'),
  ('ip-2524-nuevo-209950-614d34', '2524', 'La Florida', 'Flat', 209950, NULL, NULL, '2 hab · 2 baños · 72 m2 · ref. 2524 · https://www.inmoparadise.com/ficha/flat/alicante/la-florida/10473/29769509/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/la-florida/10473/29769509/en/', false, '2026-08-24T09:48:19.866781+00:00'),
  ('ip-2290-nuevo-155000-00cbe8', '2290', 'La Florida', 'Flat', 155000, NULL, NULL, '3 hab · 1 baños · 89 m2 · ref. 2290 · https://www.inmoparadise.com/ficha/flat/alicante/la-florida/10473/27820669/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/la-florida/10473/27820669/en/', false, '2026-08-24T09:48:19.866790+00:00'),
  ('ip-2255-nuevo-166000-849b21', '2255', 'Ciudad Elegida', 'Flat', 166000, NULL, NULL, '3 hab · 2 baños · 140 m2 · ref. 2255 · https://www.inmoparadise.com/ficha/flat/alicante/ciudad-elegida/10473/27474319/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/ciudad-elegida/10473/27474319/en/', false, '2026-08-24T09:48:19.866798+00:00'),
  ('ip-2557-nuevo-185000-4624b7', '2557', 'San Gabriel', 'Terraced house', 185000, NULL, NULL, '3 hab · 1 baños · 80 m2 · ref. 2557 · https://www.inmoparadise.com/ficha/terraced-house/alicante/san-gabriel/10473/29987890/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/terraced-house/alicante/san-gabriel/10473/29987890/en/', false, '2026-08-24T09:48:19.866806+00:00'),
  ('ip-2558-nuevo-260000-cb4b34', '2558', 'Benalua', 'Flat', 260000, NULL, NULL, '3 hab · 1 baños · 79 m2 · ref. 2558 · https://www.inmoparadise.com/ficha/flat/alicante/benalua/10473/30021750/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/benalua/10473/30021750/en/', false, '2026-08-24T09:48:19.866813+00:00'),
  ('ip-2515-nuevo-280000-d8de6f', '2515', 'Garbinet-Parque de las Avenidas', 'Flat', 280000, NULL, NULL, '3 hab · 3 baños · 121 m2 · ref. 2515 · https://www.inmoparadise.com/ficha/flat/alicante/garbinet-parque-de-las-avenidas/10473/29718682/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/garbinet-parque-de-las-avenidas/10473/29718682/en/', true, '2026-08-24T09:48:19.866820+00:00'),
  ('ip-2552-nuevo-169950-5e6d31', '2552', 'Campoamor', 'Flat', 169950, NULL, NULL, '3 hab · 1 baños · 91 m2 · ref. 2552 · https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29937917/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29937917/en/', false, '2026-08-24T09:48:19.866827+00:00'),
  ('ip-2542-nuevo-215000-f4721e', '2542', 'San Blas', 'Flat', 215000, NULL, NULL, '3 hab · 2 baños · 97 m2 · ref. 2542 · https://www.inmoparadise.com/ficha/flat/alicante/san-blas/10473/29890130/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/san-blas/10473/29890130/en/', false, '2026-08-24T09:48:19.866838+00:00'),
  ('ip-2315-nuevo-264000-09a9c7', '2315', 'Carolinas Altas', 'Duplex Penthouse', 264000, NULL, NULL, '3 hab · 2 baños · 132 m2 · ref. 2315 · https://www.inmoparadise.com/ficha/duplex-penthouse/alicante/carolinas-altas/10473/27927047/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/duplex-penthouse/alicante/carolinas-altas/10473/27927047/en/', false, '2026-08-24T09:48:19.866846+00:00'),
  ('ip-2556-nuevo-189000-0f209b', '2556', 'Carolinas Altas', 'Flat', 189000, NULL, NULL, '3 hab · 2 baños · 114 m2 · ref. 2556 · https://www.inmoparadise.com/ficha/flat/alicante/carolinas-altas/10473/29975344/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/carolinas-altas/10473/29975344/en/', false, '2026-08-24T09:48:19.866856+00:00'),
  ('ip-2371-nuevo-236000-c69030', '2371', 'Campoamor', 'Flat', 236000, NULL, NULL, '3 hab · 2 baños · 115 m2 · ref. 2371 · https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/28596412/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/28596412/en/', false, '2026-08-24T09:48:19.866863+00:00'),
  ('ip-2555-nuevo-149000-abce21', '2555', '400 viviendas', 'Flat', 149000, NULL, NULL, '3 hab · 1 baños · 97 m2 · ref. 2555 · https://www.inmoparadise.com/ficha/flat/alicante/400-viviendas/10473/29952646/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/400-viviendas/10473/29952646/en/', false, '2026-08-24T09:48:19.866871+00:00'),
  ('ip-2549-nuevo-154950-1860fe', '2549', 'Ciudad de Asís', 'Flat', 154950, NULL, NULL, '3 hab · 1 baños · 60 m2 · ref. 2549 · https://www.inmoparadise.com/ficha/flat/alicante/ciudad-de-asis/10473/29935833/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/ciudad-de-asis/10473/29935833/en/', false, '2026-08-24T09:48:19.866878+00:00'),
  ('ip-2554-nuevo-229950-8a5d77', '2554', 'La florida portazgo', 'Flat', 229950, NULL, NULL, '2 hab · 1 baños · 75 m2 · ref. 2554 · https://www.inmoparadise.com/ficha/flat/alicante/la-florida-portazgo/10473/29941067/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/la-florida-portazgo/10473/29941067/en/', false, '2026-08-24T09:48:19.866884+00:00'),
  ('ip-2553-nuevo-287900-703855', '2553', 'Benalua', 'Flat', 287900, NULL, NULL, '4 hab · 1 baños · 96 m2 · ref. 2553 · https://www.inmoparadise.com/ficha/flat/alicante/benalua/10473/29939526/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/benalua/10473/29939526/en/', false, '2026-08-24T09:48:19.866891+00:00'),
  ('ip-2480-nuevo-172000-bc7487', '2480', 'Centro', 'Duplex', 172000, NULL, NULL, '4 hab · 1 baños · 93 m2 · ref. 2480 · https://www.inmoparadise.com/ficha/duplex/torrevieja/centro/10473/29377021/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/duplex/torrevieja/centro/10473/29377021/en/', false, '2026-08-24T09:48:19.866898+00:00'),
  ('ip-2471-nuevo-359950-e65ca3', '2471', 'Villamontes-Boqueres', 'Single family house', 359950, NULL, NULL, '5 hab · 3 baños · 2762 m2 · ref. 2471 · https://www.inmoparadise.com/ficha/single-family-house/san-vicente-del-raspeig/villamontes-boqueres/10473/29348436/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/single-family-house/san-vicente-del-raspeig/villamontes-boqueres/10473/29348436/en/', false, '2026-08-24T09:48:19.866904+00:00'),
  ('ip-2509-nuevo-196000-8fe50f', '2509', 'Campoamor', 'Flat', 196000, NULL, NULL, '3 hab · 1 baños · 85 m2 · ref. 2509 · https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29643484/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29643484/en/', false, '2026-08-24T09:48:19.866939+00:00'),
  ('ip-2551-nuevo-99950-83bae7', '2551', 'Juan XXIII', 'Flat', 99950, NULL, NULL, '3 hab · 1 baños · 82 m2 · ref. 2551 · https://www.inmoparadise.com/ficha/flat/alicante/juan-xxiii/10473/29935958/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/juan-xxiii/10473/29935958/en/', false, '2026-08-24T09:48:19.866949+00:00'),
  ('ip-2511-nuevo-185000-f0a3ec', '2511', 'Carolinas bajas', 'Flat', 185000, NULL, NULL, '4 hab · 1 baños · 100 m2 · ref. 2511 · https://www.inmoparadise.com/ficha/flat/alicante/carolinas-bajas/10473/29646574/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/carolinas-bajas/10473/29646574/en/', false, '2026-08-24T09:48:19.866956+00:00'),
  ('ip-2540-nuevo-117000-25730e', '2540', 'Virgen del Remedio-Parque lo Morant', 'Duplex', 117000, NULL, NULL, '3 hab · 1 baños · 77 m2 · ref. 2540 · https://www.inmoparadise.com/ficha/duplex/alicante/virgen-del-remedio-parque-lo-morant/10473/29874689/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/duplex/alicante/virgen-del-remedio-parque-lo-morant/10473/29874689/en/', false, '2026-08-24T09:48:19.866964+00:00'),
  ('ip-2541-nuevo-112000-57b960', '2541', 'Virgen del Remedio-Parque lo Morant', 'Duplex', 112000, NULL, NULL, '3 hab · 1 baños · 78 m2 · ref. 2541 · https://www.inmoparadise.com/ficha/duplex/alicante/virgen-del-remedio-parque-lo-morant/10473/29882158/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/duplex/alicante/virgen-del-remedio-parque-lo-morant/10473/29882158/en/', false, '2026-08-24T09:48:19.866970+00:00'),
  ('ip-2545-nuevo-345000-f0df64', '2545', 'Centro', 'Flat', 345000, NULL, NULL, '4 hab · 2 baños · 108 m2 · ref. 2545 · https://www.inmoparadise.com/ficha/flat/alicante/centro/10473/29908833/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/centro/10473/29908833/en/', false, '2026-08-24T09:48:19.866977+00:00'),
  ('ip-2522-nuevo-126000-099218', '2522', 'Altozano', 'Flat', 126000, NULL, NULL, '3 hab · 1 baños · 69 m2 · ref. 2522 · https://www.inmoparadise.com/ficha/flat/alicante/altozano/10473/29763946/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/altozano/10473/29763946/en/', false, '2026-08-24T09:48:19.866984+00:00'),
  ('ip-2544-nuevo-399000-463c76', '2544', 'Raval Roig-Virgen del Socorro', 'Penthouse', 399000, NULL, NULL, '2 hab · 2 baños · 119 m2 · ref. 2544 · https://www.inmoparadise.com/ficha/penthouse/alicante/raval-roig-virgen-del-socorro/10473/29908729/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/penthouse/alicante/raval-roig-virgen-del-socorro/10473/29908729/en/', false, '2026-08-24T09:48:19.866992+00:00'),
  ('ip-2536-nuevo-189950-1a2b98', '2536', 'Santo Domingo', 'Flat', 189950, NULL, NULL, '3 hab · 1 baños · 90 m2 · ref. 2536 · https://www.inmoparadise.com/ficha/flat/alicante/santo-domingo/10473/29855557/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/santo-domingo/10473/29855557/en/', false, '2026-08-24T09:48:19.866999+00:00'),
  ('ip-2473-nuevo-325000-6e3064', '2473', 'Los Ángeles', 'Terraced house', 325000, NULL, NULL, '4 hab · 3 baños · 281 m2 · ref. 2473 · https://www.inmoparadise.com/ficha/terraced-house/alicante/los-angeles/10473/29354492/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/terraced-house/alicante/los-angeles/10473/29354492/en/', false, '2026-08-24T09:48:19.867006+00:00'),
  ('ip-2497-nuevo-259950-472bea', '2497', 'El Moralet', 'Flat', 259950, NULL, NULL, '5 hab · 3 baños · 250 m2 · ref. 2497 · https://www.inmoparadise.com/ficha/flat/alicante/el-moralet/10473/29467312/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/el-moralet/10473/29467312/en/', false, '2026-08-24T09:48:19.867016+00:00'),
  ('ip-2532-nuevo-179000-ae04a9', '2532', 'Campoamor', 'Ground floor apartment', 179000, NULL, NULL, '4 hab · 1 baños · 82 m2 · ref. 2532 · https://www.inmoparadise.com/ficha/ground-floor-apartment/alicante/campoamor/10473/29827572/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/ground-floor-apartment/alicante/campoamor/10473/29827572/en/', false, '2026-08-24T09:48:19.867023+00:00'),
  ('ip-2548-nuevo-255000-2d7c8e', '2548', 'Los Ángeles-Tómbola-San Nicolás', 'Flat', 255000, NULL, NULL, '3 hab · 2 baños · 102 m2 · ref. 2548 · https://www.inmoparadise.com/ficha/flat/alicante/los-angeles-tombola-san-nicolas/10473/29926164/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/los-angeles-tombola-san-nicolas/10473/29926164/en/', false, '2026-08-24T09:48:19.867030+00:00'),
  ('ip-2550-nuevo-99950-cf4e31', '2550', 'Colonia Santa Isabel', 'Flat', 99950, NULL, NULL, '2 hab · 1 baños · 62 m2 · ref. 2550 · https://www.inmoparadise.com/ficha/flat/san-vicente-del-raspeig/colonia-santa-isabel/10473/29935896/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/san-vicente-del-raspeig/colonia-santa-isabel/10473/29935896/en/', false, '2026-08-24T09:48:19.867037+00:00'),
  ('ip-2456-nuevo-207000-00185f', '2456', 'Campoamor', 'Flat', 207000, NULL, NULL, '3 hab · 2 baños · 111 m2 · ref. 2456 · https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29224856/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29224856/en/', true, '2026-08-24T09:48:19.867045+00:00'),
  ('ip-2546-nuevo-296000-ceac1d', '2546', 'Carolinas bajas', 'Terraced house', 296000, NULL, NULL, '4 hab · 130 m2 · ref. 2546 · https://www.inmoparadise.com/ficha/terraced-house/alicante/carolinas-bajas/10473/29916342/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/terraced-house/alicante/carolinas-bajas/10473/29916342/en/', false, '2026-08-24T09:48:19.867051+00:00'),
  ('ip-2470-nuevo-165000-49357f', '2470', 'San Blas', 'Mezzanine', 165000, NULL, NULL, '3 hab · 2 baños · 90 m2 · ref. 2470 · https://www.inmoparadise.com/ficha/mezzanine/alicante/san-blas/10473/29342541/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/mezzanine/alicante/san-blas/10473/29342541/en/', false, '2026-08-24T09:48:19.867058+00:00'),
  ('ip-2538-nuevo-390000-3930fc', '2538', 'Paus', 'Flat', 390000, NULL, NULL, '3 hab · 2 baños · 119 m2 · ref. 2538 · https://www.inmoparadise.com/ficha/flat/alicante/paus/10473/29863886/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/paus/10473/29863886/en/', false, '2026-08-24T09:48:19.867069+00:00'),
  ('ip-2490-nuevo-228000-efe500', '2490', 'Campoamor', 'Mezzanine', 228000, NULL, NULL, '4 hab · 2 baños · 132 m2 · ref. 2490 · https://www.inmoparadise.com/ficha/mezzanine/alicante/campoamor/10473/29433326/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/mezzanine/alicante/campoamor/10473/29433326/en/', true, '2026-08-24T09:48:19.867080+00:00'),
  ('ip-2543-nuevo-318000-909f0b', '2543', '- Sant Vicent del Raspeig - Sol y Luz', 'Duplex Penthouse', 318000, NULL, NULL, '3 hab · 2 baños · 94 m2 · ref. 2543 · https://www.inmoparadise.com/ficha/duplex-penthouse/san-vicente-del-raspeig/sant-vicent-del-raspeig-sol-y-luz/10473/29902275/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/duplex-penthouse/san-vicente-del-raspeig/sant-vicent-del-raspeig-sol-y-luz/10473/29902275/en/', false, '2026-08-24T09:48:19.867089+00:00'),
  ('ip-2350-nuevo-225000-e58750', '2350', 'Benalua', 'Flat', 225000, NULL, NULL, '3 hab · 1 baños · 104 m2 · ref. 2350 · https://www.inmoparadise.com/ficha/flat/alicante/benalua/10473/28390570/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/benalua/10473/28390570/en/', false, '2026-08-24T09:48:19.867098+00:00'),
  ('ip-2447-nuevo-85000-a8612c', '2447', 'Babel', 'Business Premise', 85000, NULL, NULL, '1 baños · 33 m2 · ref. 2447 · https://www.inmoparadise.com/ficha/business-premise/alicante/babel/10473/29184724/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/business-premise/alicante/babel/10473/29184724/en/', true, '2026-08-24T09:48:19.867105+00:00'),
  ('ip-2518-nuevo-199950-5adb06', '2518', 'Pla del bon repos', 'Flat', 199950, NULL, NULL, '3 hab · 1 baños · 74 m2 · ref. 2518 · https://www.inmoparadise.com/ficha/flat/alicante/pla-del-bon-repos/10473/29728275/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/pla-del-bon-repos/10473/29728275/en/', true, '2026-08-24T09:48:19.867112+00:00'),
  ('ip-2427-nuevo-247000-71bf60', '2427', 'Santo Domingo', 'Flat', 247000, NULL, NULL, '5 hab · 2 baños · 130 m2 · ref. 2427 · https://www.inmoparadise.com/ficha/flat/alicante/santo-domingo/10473/29005783/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/santo-domingo/10473/29005783/en/', false, '2026-08-24T09:48:19.867119+00:00'),
  ('ip-2403-nuevo-359950-a27b93', '2403', 'Vicente Savall', 'House', 359950, NULL, NULL, '5 hab · 2 baños · 167 m2 · ref. 2403 · https://www.inmoparadise.com/ficha/house/san-vicente-del-raspeig/vicente-savall/10473/28843320/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/house/san-vicente-del-raspeig/vicente-savall/10473/28843320/en/', false, '2026-08-24T09:48:19.867126+00:00'),
  ('ip-2502-nuevo-259950-49f662', '2502', 'Altozano', 'Flat', 259950, NULL, NULL, '3 hab · 2 baños · 118 m2 · ref. 2502 · https://www.inmoparadise.com/ficha/flat/alicante/altozano/10473/29566023/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/altozano/10473/29566023/en/', false, '2026-08-24T09:48:19.867133+00:00'),
  ('ip-2513-nuevo-199950-c206f2', '2513', 'Centro', 'Flat', 199950, NULL, NULL, '1 hab · 1 baños · 65 m2 · ref. 2513 · https://www.inmoparadise.com/ficha/flat/alicante/centro/10473/29712462/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/centro/10473/29712462/en/', false, '2026-08-24T09:48:19.867139+00:00'),
  ('ip-2466-nuevo-179000-f6093e', '2466', 'Campoamor', 'Flat', 179000, NULL, NULL, '2 hab · 1 baños · 89 m2 · ref. 2466 · https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29323563/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29323563/en/', false, '2026-08-24T09:48:19.867146+00:00'),
  ('ip-2443-nuevo-184900-4f2441', '2443', 'Santo Domingo', 'Flat', 184900, NULL, NULL, '3 hab · 1 baños · 80 m2 · ref. 2443 · https://www.inmoparadise.com/ficha/flat/alicante/santo-domingo/10473/29157608/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/santo-domingo/10473/29157608/en/', false, '2026-08-24T09:48:19.867152+00:00'),
  ('ip-2246-nuevo-279950-232429', '2246', 'La Albufereta', 'Flat', 279950, NULL, NULL, '3 hab · 1 baños · 79 m2 · ref. 2246 · https://www.inmoparadise.com/ficha/flat/alicante/la-albufereta/10473/27315171/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/la-albufereta/10473/27315171/en/', false, '2026-08-24T09:48:19.867160+00:00'),
  ('ip-1199-nuevo-134000-e8fe8b', '1199', 'Altozano', 'Flat', 134000, NULL, NULL, '2 hab · 1 baños · 56 m2 · ref. 1199 · https://www.inmoparadise.com/ficha/flat/alicante/altozano/10473/18929513/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/altozano/10473/18929513/en/', false, '2026-08-24T09:48:19.867169+00:00'),
  ('ip-2506-nuevo-187500-845ce5', '2506', 'Santo Domingo', 'Flat', 187500, NULL, NULL, '4 hab · 1 baños · 107 m2 · ref. 2506 · https://www.inmoparadise.com/ficha/flat/alicante/santo-domingo/10473/29627633/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/santo-domingo/10473/29627633/en/', false, '2026-08-24T09:48:19.867176+00:00'),
  ('ip-2452-nuevo-133000-560290', '2452', 'Carolinas bajas', 'Penthouse', 133000, NULL, NULL, '2 hab · 1 baños · 65 m2 · ref. 2452 · https://www.inmoparadise.com/ficha/penthouse/alicante/carolinas-bajas/10473/29197646/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/penthouse/alicante/carolinas-bajas/10473/29197646/en/', false, '2026-08-24T09:48:19.867183+00:00'),
  ('ip-1555-nuevo-185000-b2e943', '1555', 'Carolinas bajas', 'Flat', 185000, NULL, NULL, '4 hab · 2 baños · 90 m2 · ref. 1555 · https://www.inmoparadise.com/ficha/flat/alicante/carolinas-bajas/10473/21912903/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/carolinas-bajas/10473/21912903/en/', false, '2026-08-24T09:48:19.867189+00:00'),
  ('ip-2451-nuevo-133000-4dc31a', '2451', 'Carolinas bajas', 'Penthouse', 133000, NULL, NULL, '2 hab · 1 baños · 65 m2 · ref. 2451 · https://www.inmoparadise.com/ficha/penthouse/alicante/carolinas-bajas/10473/29197546/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/penthouse/alicante/carolinas-bajas/10473/29197546/en/', false, '2026-08-24T09:48:19.867196+00:00'),
  ('ip-2378-nuevo-179950-72ce31', '2378', 'Nou Alacant', 'Flat', 179950, NULL, NULL, '4 hab · 1 baños · 85 m2 · ref. 2378 · https://www.inmoparadise.com/ficha/flat/alicante/nou-alacant/10473/28629239/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/nou-alacant/10473/28629239/en/', false, '2026-08-24T09:48:19.867203+00:00'),
  ('ip-2531-nuevo-229950-672771', '2531', 'Campoamor', 'Flat', 229950, NULL, NULL, '5 hab · 2 baños · 122 m2 · ref. 2531 · https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29805975/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29805975/en/', false, '2026-08-24T09:48:19.867210+00:00'),
  ('ip-2370-nuevo-149995-f380d4', '2370', 'Campoamor', 'Mezzanine', 149995, NULL, NULL, '3 hab · 1 baños · 92 m2 · ref. 2370 · https://www.inmoparadise.com/ficha/mezzanine/alicante/campoamor/10473/28595035/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/mezzanine/alicante/campoamor/10473/28595035/en/', false, '2026-08-24T09:48:19.867217+00:00'),
  ('ip-2386-nuevo-230000-9d01b2', '2386', 'Mercado', 'Flat', 230000, NULL, NULL, '3 hab · 1 baños · 123 m2 · ref. 2386 · https://www.inmoparadise.com/ficha/flat/alicante/mercado/10473/28756871/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/mercado/10473/28756871/en/', false, '2026-08-24T09:48:19.867223+00:00'),
  ('ip-2519-nuevo-170000-8cc108', '2519', 'Ciudad de Asís', 'Flat', 170000, NULL, NULL, '3 hab · 1 baños · 80 m2 · ref. 2519 · https://www.inmoparadise.com/ficha/flat/alicante/ciudad-de-asis/10473/29734201/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/ciudad-de-asis/10473/29734201/en/', false, '2026-08-24T09:48:19.867230+00:00'),
  ('ip-2533-nuevo-149950-335876', '2533', 'La Florida', 'Flat', 149950, NULL, NULL, '3 hab · 1 baños · 73 m2 · ref. 2533 · https://www.inmoparadise.com/ficha/flat/alicante/la-florida/10473/29843866/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/la-florida/10473/29843866/en/', false, '2026-08-24T09:48:19.867239+00:00'),
  ('ip-2534-nuevo-239950-a71fcf', '2534', 'Campoamor', 'Flat', 239950, NULL, NULL, '3 hab · 2 baños · 139 m2 · ref. 2534 · https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29845291/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29845291/en/', false, '2026-08-24T09:48:19.867246+00:00'),
  ('ip-2467-nuevo-142000-9c985f', '2467', 'Los Ángeles', 'Flat', 142000, NULL, NULL, '3 hab · 1 baños · 70 m2 · ref. 2467 · https://www.inmoparadise.com/ficha/flat/alicante/los-angeles/10473/29325241/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/los-angeles/10473/29325241/en/', false, '2026-08-24T09:48:19.867255+00:00'),
  ('ip-2474-nuevo-119950-784ccb', '2474', 'Virgen del Remedio-Parque lo Morant', 'Flat', 119950, NULL, NULL, '4 hab · 1 baños · 80 m2 · ref. 2474 · https://www.inmoparadise.com/ficha/flat/alicante/virgen-del-remedio-parque-lo-morant/10473/29354603/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/virgen-del-remedio-parque-lo-morant/10473/29354603/en/', false, '2026-08-24T09:48:19.867264+00:00'),
  ('ip-2476-nuevo-135000-7194f0', '2476', 'Carolinas Altas', 'Flat', 135000, NULL, NULL, '2 hab · 1 baños · 69 m2 · ref. 2476 · https://www.inmoparadise.com/ficha/flat/alicante/carolinas-altas/10473/29366933/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/carolinas-altas/10473/29366933/en/', false, '2026-08-24T09:48:19.867271+00:00'),
  ('ip-1180-nuevo-209950-f23dd4', '1180', 'Santa ana', 'Country House', 209950, NULL, NULL, '3 hab · 1 baños · 120 m2 · ref. 1180 · https://www.inmoparadise.com/ficha/country-house/el-rebolledo/santa-ana/10473/18696105/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/country-house/el-rebolledo/santa-ana/10473/18696105/en/', false, '2026-08-24T09:48:19.867279+00:00'),
  ('ip-2512-nuevo-110000-cb9e87', '2512', 'Carolinas Altas', 'Ground floor apartment', 110000, NULL, NULL, '3 hab · 1 baños · 101 m2 · ref. 2512 · https://www.inmoparadise.com/ficha/ground-floor-apartment/alicante/carolinas-altas/10473/29700241/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/ground-floor-apartment/alicante/carolinas-altas/10473/29700241/en/', false, '2026-08-24T09:48:19.867287+00:00'),
  ('ip-2516-nuevo-115000-7ba5dd', '2516', 'Virgen del Remedio-Parque lo Morant', 'Flat', 115000, NULL, NULL, '3 hab · 1 baños · 71 m2 · ref. 2516 · https://www.inmoparadise.com/ficha/flat/alicante/virgen-del-remedio-parque-lo-morant/10473/29725093/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/virgen-del-remedio-parque-lo-morant/10473/29725093/en/', false, '2026-08-24T09:48:19.867294+00:00'),
  ('ip-2517-nuevo-138000-a5e283', '2517', 'Juan XXIII', 'Flat', 138000, NULL, NULL, '4 hab · 2 baños · 95 m2 · ref. 2517 · https://www.inmoparadise.com/ficha/flat/alicante/juan-xxiii/10473/29725345/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/juan-xxiii/10473/29725345/en/', false, '2026-08-24T09:48:19.867301+00:00'),
  ('ip-2520-nuevo-166000-3d6466', '2520', 'Virgen del Remedio-Parque lo Morant', 'Flat', 166000, NULL, NULL, '3 hab · 2 baños · 98 m2 · ref. 2520 · https://www.inmoparadise.com/ficha/flat/alicante/virgen-del-remedio-parque-lo-morant/10473/29739194/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/virgen-del-remedio-parque-lo-morant/10473/29739194/en/', false, '2026-08-24T09:48:19.867307+00:00'),
  ('ip-2525-nuevo-385000-c92f9b', '2525', 'Centro', 'Flat', 385000, NULL, NULL, '4 hab · 2 baños · 138 m2 · ref. 2525 · https://www.inmoparadise.com/ficha/flat/alicante/centro/10473/29771287/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/centro/10473/29771287/en/', false, '2026-08-24T09:48:19.867316+00:00'),
  ('ip-2481-nuevo-305000-8fffdd', '2481', 'Centro', 'Flat', 305000, NULL, NULL, '3 hab · 2 baños · 88 m2 · ref. 2481 · https://www.inmoparadise.com/ficha/flat/alicante/centro/10473/29377627/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/centro/10473/29377627/en/', false, '2026-08-24T09:48:19.867323+00:00'),
  ('ip-2420-nuevo-319950-045a92', '2420', 'Vistahermosa', 'Flat', 319950, NULL, NULL, '4 hab · 1 baños · 161 m2 · ref. 2420 · https://www.inmoparadise.com/ficha/flat/alicante/vistahermosa/10473/28917842/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/vistahermosa/10473/28917842/en/', false, '2026-08-24T09:48:19.867330+00:00'),
  ('ip-2431-nuevo-194950-0bdec7', '2431', 'Campoamor', 'Flat', 194950, NULL, NULL, '4 hab · 1 baños · 95 m2 · ref. 2431 · https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29017648/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29017648/en/', false, '2026-08-24T09:48:19.867337+00:00'),
  ('ip-2455-nuevo-207500-0f295d', '2455', 'Campoamor', 'Flat', 207500, NULL, NULL, '3 hab · 2 baños · 123 m2 · ref. 2455 · https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29220888/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/campoamor/10473/29220888/en/', false, '2026-08-24T09:48:19.867344+00:00'),
  ('ip-2336-nuevo-227000-d80147', '2336', 'Carolinas Altas', 'Flat', 227000, NULL, NULL, '3 hab · 2 baños · 128 m2 · ref. 2336 · https://www.inmoparadise.com/ficha/flat/alicante/carolinas-altas/10473/28235269/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/carolinas-altas/10473/28235269/en/', false, '2026-08-24T09:48:19.867351+00:00'),
  ('ip-2173-nuevo-180000-606e65', '2173', 'Carolinas bajas', 'Flat', 180000, NULL, NULL, '4 hab · 1 baños · 91 m2 · ref. 2173 · https://www.inmoparadise.com/ficha/flat/alicante/carolinas-bajas/10473/26667761/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/carolinas-bajas/10473/26667761/en/', false, '2026-08-24T09:48:19.867359+00:00'),
  ('ip-2316-nuevo-188000-86a78d', '2316', 'Benalua', 'Flat', 188000, NULL, NULL, '3 hab · 1 baños · 78 m2 · ref. 2316 · https://www.inmoparadise.com/ficha/flat/alicante/benalua/10473/27940772/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/benalua/10473/27940772/en/', true, '2026-08-24T09:48:19.867366+00:00'),
  ('ip-2510-nuevo-185000-11ce1a', '2510', 'Carolinas Altas', 'Flat', 185000, NULL, NULL, '3 hab · 1 baños · 83 m2 · ref. 2510 · https://www.inmoparadise.com/ficha/flat/alicante/carolinas-altas/10473/29646517/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/carolinas-altas/10473/29646517/en/', false, '2026-08-24T09:48:19.867373+00:00'),
  ('ip-2477-nuevo-285000-f891d5', '2477', 'Tómbola - Rabasa', 'Flat', 285000, NULL, NULL, '4 hab · 2 baños · 129 m2 · ref. 2477 · https://www.inmoparadise.com/ficha/flat/alicante/tombola-rabasa/10473/29368174/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/tombola-rabasa/10473/29368174/en/', false, '2026-08-24T09:48:19.867380+00:00'),
  ('ip-2507-nuevo-259950-5321c8', '2507', 'Santo Domingo', 'Flat', 259950, NULL, NULL, '4 hab · 2 baños · 146 m2 · ref. 2507 · https://www.inmoparadise.com/ficha/flat/alicante/santo-domingo/10473/29638178/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/santo-domingo/10473/29638178/en/', false, '2026-08-24T09:48:19.867388+00:00'),
  ('ip-2313-nuevo-169950-38bd3d', '2313', 'La Florida', 'Flat', 169950, NULL, NULL, '3 hab · 2 baños · 103 m2 · ref. 2313 · https://www.inmoparadise.com/ficha/flat/alicante/la-florida/10473/27911129/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/la-florida/10473/27911129/en/', false, '2026-08-24T09:48:19.867395+00:00'),
  ('ip-2409-nuevo-123000-7ac020', '2409', 'Ciudad Elegida', 'Flat', 123000, NULL, NULL, '2 hab · 1 baños · 78 m2 · ref. 2409 · https://www.inmoparadise.com/ficha/flat/alicante/ciudad-elegida/10473/28864030/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/ciudad-elegida/10473/28864030/en/', false, '2026-08-24T09:48:19.867402+00:00'),
  ('ip-2416-nuevo-259950-39bc1e', '2416', 'Babel', 'Flat', 259950, NULL, NULL, '4 hab · 2 baños · 134 m2 · ref. 2416 · https://www.inmoparadise.com/ficha/flat/alicante/babel/10473/28900977/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/babel/10473/28900977/en/', true, '2026-08-24T09:48:19.867408+00:00'),
  ('ip-2294-nuevo-189950-29fc73', '2294', 'Babel', 'Flat', 189950, NULL, NULL, '3 hab · 2 baños · 91 m2 · ref. 2294 · https://www.inmoparadise.com/ficha/flat/alicante/babel/10473/27841965/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/babel/10473/27841965/en/', false, '2026-08-24T09:48:19.867415+00:00'),
  ('ip-2482-nuevo-239950-ce11f0', '2482', 'Altozano', 'Flat', 239950, NULL, NULL, '5 hab · 2 baños · 125 m2 · ref. 2482 · https://www.inmoparadise.com/ficha/flat/alicante/altozano/10473/29393007/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/altozano/10473/29393007/en/', false, '2026-08-24T09:48:19.867421+00:00'),
  ('ip-2369-nuevo-129950-32036c', '2369', 'Carolinas bajas', 'Flat', 129950, NULL, NULL, '3 hab · 1 baños · 74 m2 · ref. 2369 · https://www.inmoparadise.com/ficha/flat/alicante/carolinas-bajas/10473/28594096/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/carolinas-bajas/10473/28594096/en/', true, '2026-08-24T09:48:19.867427+00:00'),
  ('ip-2360-nuevo-235000-158bda', '2360', 'Vistahermosa', 'Flat', 235000, NULL, NULL, '2 hab · 2 baños · 80 m2 · ref. 2360 · https://www.inmoparadise.com/ficha/flat/alicante/vistahermosa/10473/28479454/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/vistahermosa/10473/28479454/en/', false, '2026-08-24T09:48:19.867434+00:00'),
  ('ip-2498-nuevo-195000-7da64f', '2498', 'Plà del Bon Repòs-La Goteta', 'Flat', 195000, NULL, NULL, '4 hab · 1 baños · 115 m2 · ref. 2498 · https://www.inmoparadise.com/ficha/flat/alicante/pla-del-bon-repos-la-goteta/10473/29522116/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/pla-del-bon-repos-la-goteta/10473/29522116/en/', false, '2026-08-24T09:48:19.867440+00:00'),
  ('ip-2499-nuevo-205000-2f0aaf', '2499', 'Carolinas bajas', 'Flat', 205000, NULL, NULL, '2 hab · 1 baños · 77 m2 · ref. 2499 · https://www.inmoparadise.com/ficha/flat/alicante/carolinas-bajas/10473/29524539/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/carolinas-bajas/10473/29524539/en/', false, '2026-08-24T09:48:19.867449+00:00'),
  ('ip-2501-nuevo-140000-62f173', '2501', 'Carolinas bajas', 'Business Premise', 140000, NULL, NULL, '1 baños · 72 m2 · ref. 2501 · https://www.inmoparadise.com/ficha/business-premise/alicante/carolinas-bajas/10473/29555161/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/business-premise/alicante/carolinas-bajas/10473/29555161/en/', false, '2026-08-24T09:48:19.867458+00:00'),
  ('ip-2281-nuevo-129950-de7e16', '2281', 'Virgen del Remedio-Parque lo Morant', 'Flat', 129950, NULL, NULL, '3 hab · 1 baños · 90 m2 · ref. 2281 · https://www.inmoparadise.com/ficha/flat/alicante/virgen-del-remedio-parque-lo-morant/10473/27645731/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/virgen-del-remedio-parque-lo-morant/10473/27645731/en/', false, '2026-08-24T09:48:19.867464+00:00'),
  ('ip-2404-nuevo-8500-9461e9', '2404', 'Campoamor', 'Garage', 8500, NULL, NULL, '8 m2 · ref. 2404 · https://www.inmoparadise.com/ficha/garage/alicante/campoamor/10473/28846080/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/garage/alicante/campoamor/10473/28846080/en/', false, '2026-08-24T09:48:19.867471+00:00'),
  ('ip-2486-nuevo-145000-1bf8df', '2486', 'Ciudad Elegida', 'Flat', 145000, NULL, NULL, '3 hab · 1 baños · 75 m2 · ref. 2486 · https://www.inmoparadise.com/ficha/flat/alicante/ciudad-elegida/10473/29410316/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/ciudad-elegida/10473/29410316/en/', false, '2026-08-24T09:48:19.867477+00:00'),
  ('ip-2487-nuevo-235000-45578a', '2487', 'Carolinas bajas', 'Flat', 235000, NULL, NULL, '3 hab · 1 baños · 109 m2 · ref. 2487 · https://www.inmoparadise.com/ficha/flat/alicante/carolinas-bajas/10473/29410432/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/carolinas-bajas/10473/29410432/en/', false, '2026-08-24T09:48:19.867484+00:00'),
  ('ip-2472-nuevo-319900-da5ff3', '2472', 'Sur', 'Flat', 319900, NULL, NULL, '4 hab · 2 baños · 188 m2 · ref. 2472 · https://www.inmoparadise.com/ficha/flat/san-vicente-del-raspeig/sur/10473/29354345/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/san-vicente-del-raspeig/sur/10473/29354345/en/', false, '2026-08-24T09:48:19.867490+00:00'),
  ('ip-2080-nuevo-269950-02bc8a', '2080', 'Altozano', 'Penthouse', 269950, NULL, NULL, '4 hab · 2 baños · 143 m2 · ref. 2080 · https://www.inmoparadise.com/ficha/penthouse/alicante/altozano/10473/25997581/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/penthouse/alicante/altozano/10473/25997581/en/', false, '2026-08-24T09:48:19.867496+00:00'),
  ('ip-2326-nuevo-149950-b1e0b6', '2326', 'Campoamor', 'Business Premise', 149950, NULL, NULL, '222 m2 · ref. 2326 · https://www.inmoparadise.com/ficha/business-premise/alicante/campoamor/10473/28136162/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/business-premise/alicante/campoamor/10473/28136162/en/', false, '2026-08-24T09:48:19.867504+00:00'),
  ('ip-2401-nuevo-199950-318842', '2401', 'Campoamor', 'Business Premise', 199950, NULL, NULL, '3 hab · 2 baños · 300 m2 · ref. 2401 · https://www.inmoparadise.com/ficha/business-premise/alicante/campoamor/10473/28837918/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/business-premise/alicante/campoamor/10473/28837918/en/', false, '2026-08-24T09:48:19.867514+00:00'),
  ('ip-2331-nuevo-205000-b7508b', '2331', 'San nicolas de bari - Benisaudet', 'Flat', 205000, NULL, NULL, '4 hab · 2 baños · 105 m2 · ref. 2331 · https://www.inmoparadise.com/ficha/flat/alicante/san-nicolas-de-bari-benisaudet/10473/28165819/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/san-nicolas-de-bari-benisaudet/10473/28165819/en/', false, '2026-08-24T09:48:19.867521+00:00'),
  ('ip-2457-nuevo-109950-6740d9', '2457', 'Campoamor', 'Garage', 109950, NULL, NULL, '471 m2 · ref. 2457 · https://www.inmoparadise.com/ficha/garage/alicante/campoamor/10473/29237771/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/garage/alicante/campoamor/10473/29237771/en/', false, '2026-08-24T09:48:19.867529+00:00'),
  ('ip-1727-nuevo-370000-6b0fc1', '1727', 'Playa de San Juan', 'Flat', 370000, NULL, NULL, '3 hab · 2 baños · 117 m2 · ref. 1727 · https://www.inmoparadise.com/ficha/flat/alicante/playa-de-san-juan/10473/23006399/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/playa-de-san-juan/10473/23006399/en/', false, '2026-08-24T09:48:19.867536+00:00'),
  ('ip-2396-nuevo-189950-2df2c5', '2396', 'La Albufereta', 'Flat', 189950, NULL, NULL, '1 hab · 1 baños · 40 m2 · ref. 2396 · https://www.inmoparadise.com/ficha/flat/alicante/la-albufereta/10473/28828305/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/la-albufereta/10473/28828305/en/', false, '2026-08-24T09:48:19.867542+00:00'),
  ('ip-2465-nuevo-289000-3f6511', '2465', 'Campoamor', 'Penthouse', 289000, NULL, NULL, '3 hab · 2 baños · 117 m2 · ref. 2465 · https://www.inmoparadise.com/ficha/penthouse/alicante/campoamor/10473/29299169/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/penthouse/alicante/campoamor/10473/29299169/en/', false, '2026-08-24T09:48:19.867548+00:00'),
  ('ip-2304-nuevo-310000-be4069', '2304', 'Babel', 'Penthouse', 310000, NULL, NULL, '3 hab · 2 baños · 118 m2 · ref. 2304 · https://www.inmoparadise.com/ficha/penthouse/alicante/babel/10473/27875733/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/penthouse/alicante/babel/10473/27875733/en/', true, '2026-08-24T09:48:19.867555+00:00'),
  ('ip-2424-nuevo-169950-eca1b1', '2424', 'Centro Tradicional', 'Penthouse', 169950, NULL, NULL, '1 hab · 1 baños · 46 m2 · ref. 2424 · https://www.inmoparadise.com/ficha/penthouse/alicante/centro-tradicional/10473/28979865/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/penthouse/alicante/centro-tradicional/10473/28979865/en/', true, '2026-08-24T09:48:19.867561+00:00'),
  ('ip-2394-nuevo-950000-30221d', '2394', 'Santo Domingo', 'Terraced house', 950000, NULL, NULL, '5 hab · 4 baños · 326 m2 · ref. 2394 · https://www.inmoparadise.com/ficha/terraced-house/alicante/santo-domingo/10473/28811141/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/terraced-house/alicante/santo-domingo/10473/28811141/en/', false, '2026-08-24T09:48:19.867569+00:00'),
  ('ip-2344-nuevo-360000-1a5f47', '2344', 'Tómbola - Rabasa', 'House Type Duplex', 360000, NULL, NULL, '4 hab · 2 baños · 228 m2 · ref. 2344 · https://www.inmoparadise.com/ficha/house-type-duplex/alicante/tombola-rabasa/10473/28345561/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/house-type-duplex/alicante/tombola-rabasa/10473/28345561/en/', false, '2026-08-24T09:48:19.867576+00:00'),
  ('ip-2252-nuevo-305000-86a5af', '2252', 'Centro', 'Flat', 305000, NULL, NULL, '4 hab · 2 baños · 77 m2 · ref. 2252 · https://www.inmoparadise.com/ficha/flat/alicante/centro/10473/27412466/en/', 'Inmoparadise (auto)', 'nuevo', 'https://www.inmoparadise.com/ficha/flat/alicante/centro/10473/27412466/en/', false, '2026-08-24T09:48:19.867582+00:00')
on conflict (id) do nothing;

-- ============================================================
-- Rol de comprador (comprador / vendedor / ambos) y notas internas
-- ============================================================
alter table public.compradores add column if not exists rol text not null default 'comprador';
alter table public.compradores add column if not exists notas text;
alter table public.compradores drop constraint if exists compradores_rol_check;
alter table public.compradores add constraint compradores_rol_check check (rol in ('comprador', 'vendedor', 'ambos'));

-- ============================================================
-- Alquiler (independiente de Compradores/Pisos/Coincidencias)
-- ============================================================
-- Quien busca alquilar (alquiler_clientes) y los pisos en alquiler
-- que se añaden a mano (alquiler_pisos — todavía no hay ninguna
-- fuente automática, el scraper solo vigila venta). Mismas reglas de
-- acceso que Compradores/Pisos: los clientes de alquiler solo los ve
-- quien los creó (o un admin); los pisos en alquiler los ve y edita
-- todo el equipo por igual.

create table if not exists public.alquiler_clientes (
  id text primary key,
  nombre text not null,
  telefono text not null,
  zona text,
  tipo text,
  presupuesto numeric,
  caract text,
  agente text not null,
  owner_id uuid references auth.users(id) default auth.uid(),
  fecha timestamptz not null default now()
);

create table if not exists public.alquiler_pisos (
  id text primary key,
  zona text not null,
  tipo text,
  precio numeric,
  caract text,
  agente text,
  url text,
  fecha timestamptz not null default now()
);

create table if not exists public.alquiler_contactados (
  match_key text primary key,
  fecha timestamptz not null default now()
);

alter table public.alquiler_clientes enable row level security;
alter table public.alquiler_pisos enable row level security;
alter table public.alquiler_contactados enable row level security;

drop policy if exists "alquiler_clientes_select" on public.alquiler_clientes;
drop policy if exists "alquiler_clientes_insert" on public.alquiler_clientes;
drop policy if exists "alquiler_clientes_update" on public.alquiler_clientes;
drop policy if exists "alquiler_clientes_delete" on public.alquiler_clientes;

create policy "alquiler_clientes_select" on public.alquiler_clientes
  for select using (owner_id = auth.uid() or public.is_admin());

create policy "alquiler_clientes_insert" on public.alquiler_clientes
  for insert with check (owner_id = auth.uid());

create policy "alquiler_clientes_update" on public.alquiler_clientes
  for update using (owner_id = auth.uid() or public.is_admin())
  with check (owner_id = auth.uid() or public.is_admin());

create policy "alquiler_clientes_delete" on public.alquiler_clientes
  for delete using (owner_id = auth.uid() or public.is_admin());

-- El catálogo de pisos en alquiler lo ve y edita todo el equipo,
-- igual que el de venta (por ahora se añaden siempre a mano).
drop policy if exists "alquiler_pisos_all" on public.alquiler_pisos;
create policy "alquiler_pisos_all" on public.alquiler_pisos
  for all using (auth.uid() is not null) with check (auth.uid() is not null);

drop policy if exists "alquiler_contactados_all" on public.alquiler_contactados;
create policy "alquiler_contactados_all" on public.alquiler_contactados
  for all using (auth.uid() is not null) with check (auth.uid() is not null);

-- Mueve a Jose Luis (busca alquiler, no compra) de Compradores a Alquiler.
insert into public.alquiler_clientes (id, nombre, telefono, zona, tipo, presupuesto, caract, agente, owner_id, fecha)
select gen_random_uuid()::text, nombre, telefono, zona, tipo, presupuesto,
       'Con urbanización', agente, owner_id, fecha
from public.compradores
where nombre = 'Jose Luis' and telefono = '601182032'
on conflict (id) do nothing;

delete from public.compradores where nombre = 'Jose Luis' and telefono = '601182032';

-- Beatriz compra y también vende su casa en Río Park.
update public.compradores set rol = 'ambos' where nombre = 'Beatriz' and telefono = '603655249';

-- ============================================================
-- Suscripciones push (avisos reales aunque el móvil esté bloqueado)
-- ============================================================
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) default auth.uid(),
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);

alter table public.push_subscriptions enable row level security;

drop policy if exists "push_subscriptions_select" on public.push_subscriptions;
drop policy if exists "push_subscriptions_insert" on public.push_subscriptions;
drop policy if exists "push_subscriptions_update" on public.push_subscriptions;
drop policy if exists "push_subscriptions_delete" on public.push_subscriptions;

-- Cada persona ve y gestiona solo sus propias suscripciones (el envío
-- real lo hace el scraper con la service role key, que salta RLS).
create policy "push_subscriptions_select" on public.push_subscriptions
  for select using (owner_id = auth.uid() or public.is_admin());

create policy "push_subscriptions_insert" on public.push_subscriptions
  for insert with check (owner_id = auth.uid());

create policy "push_subscriptions_update" on public.push_subscriptions
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "push_subscriptions_delete" on public.push_subscriptions
  for delete using (owner_id = auth.uid());
