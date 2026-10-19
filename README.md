# Next.js SSR en AWS

Next.js App Router con OpenNext, Lambda, S3 y CloudFront, sin Amplify. Cada PR obtiene un entorno Terraform aislado con URL HTTPS `*.cloudfront.net`; al cerrarlo se destruye.

## Arquitectura

```text
CloudFront -> Lambda servidor (SSR, Server Components, API, Server Actions, middleware)
		   -> S3 privado /_assets (/_next/static/*)
		   -> Lambda de optimizacion (/_next/image*)

Lambda servidor -> S3 /_cache + DynamoDB (cache ISR y etiquetas)
				-> SQS FIFO -> Lambda de revalidacion -> servidor via HTTPS
Lambda inicializadora -> DynamoDB (metadatos del build)
```

El modulo local [infra/modules/nextjs/main.tf](infra/modules/nextjs/main.tf) empaqueta los cuatro bundles Lambda y sube assets y cache inicial. Las paginas, incluso las prerenderizadas, pasan por el servidor OpenNext; no se reescriben rutas a `index.html`. CloudFront conserva cookies, query strings y cabeceras RSC; permite POST para Server Actions y respeta `Cache-Control` de Next.js. `x-forwarded-host` mantiene el host publico para las comprobaciones de origen.

Se usa un modulo local porque TerraNext 3.2.0 requiere dominio propio y ACM, mientras estas previews no los necesitan. El contrato es el build predeterminado de OpenNext 4.1.11, sin funciones separadas por ruta, Lambda@Edge ni streaming. El middleware se integra en el servidor regional. Cambiar esos modos requiere adaptar Terraform al manifiesto `open-next.output.json`.

## Requisitos

- Node.js 22, npm y Terraform 1.10 o posterior.
- Cuenta AWS, rol GitHub Actions con OIDC y secret `AWS_ROLE_ARN`.
- Bucket de estado remoto existente, versionado y cifrado, configurado en [infra/backend.tf](infra/backend.tf).
- Permisos de despliegue adicionales a los del antiguo sitio estatico.

Los roles de ejecucion de Lambda se crean por separado con acceso limitado a sus logs, prefijos S3, tabla DynamoDB o cola SQS. La cola usa cifrado administrado por SQS, reintentos y DLQ; no se necesita KMS personalizado. Los logs caducan a los siete dias. No se activa un warmer; existen cold starts y costes de Lambda, S3, CloudFront, SQS y DynamoDB incluso para previews.

Las Function URLs de servidor e imagenes son publicas (`NONE`) y tambien se pueden invocar directamente, fuera de CloudFront. S3 permanece privado con OAC y acceso CDN limitado a `/_assets/*`. Esto no convierte la preview en un entorno privado: no publiques secretos ni datos sensibles. Autenticacion de previews o restriccion de origen requeririan proteccion adicional.

## Desarrollo Y Pruebas

```sh
npm ci
npm run dev
```

Rutas de comprobacion: `/ssr/` cambia la fecha en cada peticion, `/api/health/` devuelve JSON sin cache y `/isr/` se regenera bajo demanda con `revalidate = 60`.

```sh
npm run lint
npm run opennext:build
npm run start
```

OpenNext ejecuta `next build` y genera `.open-next/`; no hace falta ejecutar ambos builds. `npm run build` sigue disponible para Next.js. La CLI AWS instalada es `open-next build`: no ofrece comandos `preview` o `deploy`; se prueba con Next.js y se despliega con Terraform.

Con el servidor arrancado, en otra terminal:

```sh
npm run test:smoke -- http://localhost:3000
terraform -chdir=infra init -backend=false
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate
terraform -chdir=infra test
```

Los planes de prueba usan AWS simulado, pero empaquetan el build real con el proveedor archive; no crean recursos. Tambien comprueban una configuracion de limpieza sin directorio de build. El smoke test verifica SSR, API y cabeceras/cache inicial de ISR; no demuestra el ciclo distribuido completo. En AWS, consulta `/isr/`, repite antes de 60 segundos, vuelve despues del TTL y comprueba que una peticion posterior obtiene una fecha nueva tras la revalidacion asincrona. Revisa CloudWatch y la DLQ si la fecha no cambia. Tambien puedes ejecutar el smoke test contra la URL de CloudFront.

## Entornos De Preview

El [workflow](.github/workflows/preview.yml) instala dependencias, valida tipos, construye OpenNext, prueba Terraform, selecciona el workspace `pr-N`, guarda un plan y lo aplica. Terraform carga assets, cache y codigo Lambda. Despues, Actions invalida CloudFront, espera su finalizacion, ejecuta el smoke test y comenta la URL en el PR. Se omiten PRs desde forks; el checkout y el despliegue ejecutan codigo del PR, por lo que solo deben tener acceso colaboradores de confianza.

El cierre no requiere Node.js ni un build. Antes de destruir Terraform, el workflow pagina y elimina todas las versiones y delete markers del bucket del preview. Esto permite limpiar buckets versionados que quedaron de la arquitectura estática anterior, cuyo `force_destroy` era `false`.

```sh
terraform -chdir=infra init
terraform -chdir=infra workspace select pr-123
bash scripts/empty-versioned-preview-bucket.sh "$(terraform -chdir=infra output -raw s3_bucket_name)" 123
terraform -chdir=infra destroy -var='pr_number=123' -var='deploy_artifacts=false'
terraform -chdir=infra workspace select default
terraform -chdir=infra workspace delete pr-123
```

`deploy_artifacts=false` es exclusivamente para destruir: no lo uses en un apply normal porque eliminaria objetos gestionados. Los buckets de preview usan `force_destroy` para borrar tambien cache creada en runtime. Produccion no permite vaciar el bucket automaticamente.

Para un despliegue manual, construye OpenNext, inicializa el backend y selecciona el workspace antes de planificar:

```sh
terraform -chdir=infra init -reconfigure
terraform -chdir=infra workspace select pr-123 || terraform -chdir=infra workspace new pr-123
terraform -chdir=infra plan -var='pr_number=123' -out=tfplan
terraform -chdir=infra apply tfplan
terraform -chdir=infra output -raw preview_url
```

Sin `pr_number` los nombres son de produccion. Los workspaces no son limites de seguridad: no mezcles un workspace de preview con variables de produccion. El backend de estado existente no cambia.

## Migracion Desde El Sitio Estatico

Este cambio reemplaza los recursos anteriores: no migra la distribucion existente y la URL sera distinta. Antes de actualizar una preview existente, revisa el plan. El bucket antiguo tenia versionado y no `force_destroy`; debes vaciar **solo ese bucket de preview**, incluidas versiones y delete markers, antes de que Terraform pueda borrarlo. No vacies el bucket de estado remoto. Alternativamente, destruye las previews con la configuracion anterior despues de vaciar sus buckets y vuelve a crearlas con esta configuracion. Coordina los PRs ya abiertos, que pueden seguir usando el workflow antiguo. Para produccion prepara una migracion independiente y evita aplicar un reemplazo sin revisar.

## Permisos Del Rol De GitHub Actions

`AWS_ROLE_ARN` sigue siendo el ARN del rol OIDC de despliegue, no el de una Lambda. Restringe su trust policy al repositorio y a los eventos previstos (`repo:OWNER/REPO:pull_request` para previews, con audiencia `sts.amazonaws.com`); no uses `pull_request_target` para ejecutar builds no confiables.

El rol necesita lectura/gestion/borrado de los recursos de preview en estos servicios:

- S3: bucket y objetos de la app (incluidos codigo y cache), configuracion de cifrado, public access block y policies. La limpieza de previews requiere `s3:ListBucketVersions` y `s3:DeleteObjectVersion`, ademas de `s3:ListBucket`, `s3:DeleteObject` y permisos de configuracion del bucket.
- Lambda: funciones, codigo, configuracion, Function URLs, permisos, invocacion del inicializador y event source mappings.
- DynamoDB: tabla e indices de cache; SQS: colas, atributos, etiquetas y borrado.
- CloudFront: distribucion, OAC, funcion de host, cache policies e invalidaciones; lectura de policies administradas.
- CloudWatch Logs: grupos, retencion, etiquetas y borrado.
- IAM: crear/leer/eliminar roles, gestionar sus inline policies y etiquetas, y `iam:PassRole` limitado a `deploy-aws-pr-*-*` con `iam:PassedToService = lambda.amazonaws.com`.
- Backend: `s3:ListBucket`, `s3:GetObject`, `s3:PutObject` y permisos de borrado del lock `.tflock` en los prefijos de estado/workspaces.

Limita ARNs y condiciones al prefijo `deploy-aws-pr-*`, cuenta y region cuando el servicio lo permita. Algunas operaciones de creacion/listado requieren `Resource: "*"`; no sustituyas esta revision por permisos administrativos globales. `PowerUserAccess` por si solo no permite gestionar los roles IAM. No hacen falta permisos de Amplify, ACM ni Route 53. El repositorio no modifica automaticamente el rol de despliegue ni su trust policy.