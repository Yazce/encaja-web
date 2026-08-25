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
   Esto crea las tablas (`compradores`, `pisos`, `contactados`,
   `perfiles`), el login por compañero (Supabase Auth) con sus
   políticas de acceso, y carga los 108 pisos que ya teníais
   detectados.
5. Ve a **Project Settings** (icono de engranaje) → **API**. Copia:
   - **Project URL** (algo como `https://xxxxx.supabase.co`)
   - **anon public** key (una clave larga, empieza distinto a la
     `service_role`, ¡esa NO se usa aquí!)
6. Ve a **Authentication** → **Sign In / Providers** (o **Settings**,
   según la versión del panel) y desactiva **"Allow new users to
   sign up"** (o el interruptor equivalente de registro público).
   Así nadie puede crearse una cuenta por su cuenta — las cuentas
   solo las crea un admin a mano (ver el paso 5 más abajo).

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

## 5. Crear una cuenta por compañero

La web pide login (usuario + contraseña) y no tiene registro público:
las cuentas las crea un admin a mano desde el panel de Supabase.

En la pantalla de login, la persona solo ve y escribe un **nombre de
usuario** corto (p. ej. `yaz`), nunca un email. Por dentro, Supabase
Auth sigue funcionando con emails como siempre — la web traduce sola
`yaz` a `yaz@inmoparadise.local` antes de iniciar sesión, y hace lo
contrario al mostrar quién está conectado. Por eso, al crear la
cuenta en Supabase, el email que le pongas debe seguir ese mismo
patrón: `usuario@inmoparadise.local` (dominio inventado, no hace
falta que exista de verdad — Supabase no manda ningún correo ahí
porque la cuenta se crea con Auto Confirm).

1. En Supabase, ve a **Authentication** → **Users** → **Add user** →
   **Create new user**.
2. En **Email**, pon `usuario@inmoparadise.local` usando como
   "usuario" el nombre corto que quieras que teclee esa persona para
   entrar (todo en minúsculas, sin espacios, p. ej. `maria` para
   `maria@inmoparadise.local`). Rellena una **contraseña** provisional
   (que el compañero puede cambiar luego desde el propio Supabase si
   hace falta, o mándasela tú por un canal seguro). Marca **Auto
   Confirm User** — obligatorio aquí, porque ese email no es real y
   nunca podría confirmarse solo.
3. (Opcional pero recomendado) En **User Metadata**, añade:
   ```json
   {"nombre": "Nombre y Apellido"}
   ```
   Así aparecerá con su nombre completo en vez de su usuario dentro
   de la web ("Añadido por ..."). Si lo dejas en blanco, se usa el
   usuario (la parte antes de `@inmoparadise.local`).
4. Pulsa **Create user**. Ya puede iniciar sesión en la web
   escribiendo solo `usuario` (sin el `@inmoparadise.local`) y esa
   contraseña.
5. Para que alguien sea **admin** (ve los compradores de todo el
   equipo, no solo los suyos): ve a **SQL Editor** y ejecuta,
   sustituyendo el usuario:
   ```sql
   update public.perfiles
   set is_admin = true
   where id = (select id from auth.users where email = 'usuario@inmoparadise.local');
   ```
   Por defecto, cualquier cuenta nueva se crea como agente normal
   (`is_admin = false`).
6. Si ya teníais compradores cargados desde antes de activar el
   login, quedan sin dueño hasta que los liguéis a un compañero (si
   no, solo los ve un admin). Para cada uno, ejecuta en el SQL
   Editor, sustituyendo el usuario y el nombre exacto que aparece en
   "Añadido por ...":
   ```sql
   update public.compradores
   set owner_id = (select id from auth.users where email = 'usuario@inmoparadise.local')
   where agente = 'NombreExacto';
   ```

> Nota: las cuentas creadas antes de este cambio (con un email real,
> tipo `nombre@gmail.com`) siguen funcionando igual — para esas, la
> persona debe escribir su email completo en el campo "Usuario" (la
> web solo añade `@inmoparadise.local` si lo que se escribe no
> contiene ya una `@`). Si prefieres unificar, puedes cambiarle el
> email desde **Authentication** → **Users** → esa cuenta → **Edit
> user** por uno con el patrón `usuario@inmoparadise.local`.

## Notas

- Hace falta login (Supabase Auth por dentro, pero en pantalla se
  pide solo "Usuario" + contraseña — sin mostrar ningún email) para
  entrar a la web; no hay registro público, las cuentas las crea un
  admin a mano (ver el paso 5 de arriba). Cada comprador queda ligado
  a quien lo creó: un agente normal solo ve sus propios compradores y
  sus propias coincidencias; un admin los ve todos. El catálogo de
  pisos lo ve y edita todo el mundo por igual, como antes.
- La web se sincroniza sola entre todos los que la tengan abierta
  (usa Supabase Realtime): si alguien añade un piso o un comprador,
  al resto del equipo se les actualiza la lista sin recargar.
- El scraper de `encaja-scraper` escribe directamente en la tabla
  `pisos` de esta misma base de datos — en cuanto detecta un piso
  nuevo o una bajada de precio, aparece aquí solo, sin que nadie
  tenga que importar nada.
