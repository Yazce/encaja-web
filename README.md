# encaja-web

Versión de Encaja como web real: mismo diseño y misma lógica de
coincidencias que ya teníais, pero con Supabase como base de datos
(en vez de guardar solo en el navegador) y desplegada en Vercel con
una URL fija que puede abrir todo el equipo desde el móvil o el
ordenador.

No hace falta ningún paso de compilación: es un único archivo
`index.html` que habla directamente con Supabase desde el navegador.

## 1. Crear el proyecto en Supabase (gratis)

1. Entra en **https://supabase.com** → **Start your project** → crea
   una cuenta (puedes usar tu cuenta de GitHub para ir más rápido).
2. **New project** → ponle un nombre, p. ej. `encaja` → elige una
   contraseña de base de datos (guárdala, no hace falta usarla a
   mano) → elige la región más cercana (Europa) → **Create new
   project**. Tarda 1-2 minutos en aprovisionarse.
3. En el menú lateral, ve a **SQL Editor** → **New query**.
4. Abre el archivo [`schema.sql`](schema.sql) de esta carpeta, copia
   **todo** su contenido, pégalo en el editor y pulsa **Run**.
   Esto crea las 3 tablas (`compradores`, `pisos`, `contactados`),
   las políticas de acceso y carga los 108 pisos que ya teníais
   detectados.
5. Ve a **Project Settings** (icono de engranaje) → **API**. Copia:
   - **Project URL** (algo como `https://xxxxx.supabase.co`)
   - **anon public** key (una clave larga, empieza distinto a la
     `service_role`, ¡esa NO se usa aquí!)

## 2. Configurar `index.html` con esos datos

Abre [`index.html`](index.html) y busca estas dos líneas cerca del
principio del `<script>`:

```js
const SUPABASE_URL = "TU_SUPABASE_URL_AQUI";
const SUPABASE_ANON_KEY = "TU_SUPABASE_ANON_KEY_AQUI";
```

Sustituye los dos valores por el **Project URL** y la **anon public
key** que copiaste. Guarda el archivo.

> La `anon key` es pública por diseño (Supabase la protege con las
> políticas de acceso del `schema.sql`, no ocultándola) — es normal
> que quede visible en el código de la web, igual que ya era visible
> el enlace compartido de la versión anterior.

## 3. Subir este proyecto a GitHub

```bash
cd "C:\Users\gigag\Desktop\encaja-web"
git init
git add .
git commit -m "Encaja web sobre Supabase"
git branch -M main
git remote add origin https://github.com/<tu-usuario>/encaja-web.git
git push -u origin main
```

## 4. Desplegar en Vercel (gratis)

1. Entra en **https://vercel.com** → **Sign Up** → elige **Continue
   with GitHub** (así Vercel puede leer tus repos directamente).
2. **Add New...** → **Project**.
3. Busca `encaja-web` en la lista de repos e **Import**.
4. Framework Preset: déjalo en **Other** (es HTML plano, no hace
   falta build). No cambies nada más.
5. **Deploy**. En menos de un minuto te da una URL pública fija, tipo
   `https://encaja-web.vercel.app` — esa es la que compartes con tu
   equipo.

Cada vez que hagas `git push` a `main`, Vercel vuelve a desplegar
solo automáticamente.

## Notas

- No hay login: cualquiera con el enlace y con acceso a la anon key
  (visible en el código) puede leer y escribir datos — mismo modelo
  de confianza que la versión anterior ("se comparte con todo el
  equipo que tenga este enlace"). Si más adelante queréis restringir
  el acceso, se puede añadir Supabase Auth y políticas RLS por
  usuario.
- La web se sincroniza sola entre todos los que la tengan abierta
  (usa Supabase Realtime): si alguien añade un piso o un comprador,
  al resto del equipo se les actualiza la lista sin recargar.
- El scraper de `encaja-scraper` escribe directamente en la tabla
  `pisos` de esta misma base de datos — en cuanto detecta un piso
  nuevo o una bajada de precio, aparece aquí solo, sin que nadie
  tenga que importar nada.
