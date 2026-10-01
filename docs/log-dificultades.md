# Log de dificultades y soluciones

Registro cronológico inverso de los problemas encontrados al construir el pipeline y cómo se resolvieron. Cada fila corresponde a un commit o a una intervención en la máquina de desarrollo.

| Cuándo | Problema | Causa | Solución |
| --- | --- | --- | --- |
| 1/10 12:20 | Run de `main` fallaba al aplicar el Ingress: "failed calling webhook validate.nginx.ingress.kubernetes.io: connection refused" | Condición de carrera: el rollout del controlador de ingress-nginx termina unos segundos antes de que su webhook de validación acepte conexiones. Intermitente; dos runs previos con el mismo código habían pasado | Bucle de reintentos (12 × 5 s) alrededor del `kubectl apply` de los manifiestos |
| 1/10 09:00 | Pods de Prometheus/Grafana (Helm) y luego los de la app quedaban en `Pending` en kind | `kube-scheduler` en CrashLoopBackOff: perdía la elección de líder porque el API server no respondía en 5 s. Notebook de 2 núcleos, VM de Docker Desktop de 1,7 GB; kube-prometheus-stack completo la saturaba | Desinstalar el stack Helm en local y escribir `monitoring/lite` (Prometheus + Grafana sin operador, ~250 MB). `local-up.sh` lo usa por defecto; `MONITORING=full` conserva la opción Helm |
| 1/10 08:40 | `helm upgrade --install` fallaba con "another operation is in progress" | Instalación anterior cortada por disco lleno; release en `pending-install` | `helm uninstall` y reinstalar |
| 1/10 08:20 | Docker no respondía, el script local fallaba sin mensaje claro | Disco raíz al 100 % (218 GB) tras descargar imágenes de kind, ingress y Prometheus | Liberar 17 GB borrando cachés regenerables (`~/.cache` de Chrome, Puppeteer, TypeScript, uv) y reiniciar Docker Desktop |
| 1/10 08:04 | Job *Deploy*: smoke test devolvía HTTP 503 con los pods `Running` | `curl` 7 s después del rollout; el Ingress no tenía endpoints listos todavía | Reintentos en el smoke test (30 × 3 s) |
| 1/10 08:00 | Job *Deploy*: pods en `CreateContainerConfigError` | `runAsNonRoot: true` exige UID numérico; la imagen usaba `USER app` por nombre | `adduser -u 10001`, `USER 10001:10001`; `runAsUser`/`runAsGroup: 10001` en el Deployment |
| 1/10 07:53 | Job *Deploy*: rollout agotaba el tiempo | kind no podía descargar la imagen: el paquete en ghcr.io nace privado | `docker pull` con `GITHUB_TOKEN` + `kind load docker-image`; paso de diagnóstico (`describe`, `logs`) si falla |
| 1/10 07:47 | Jobs *Trivy* y *Build* fallaban en 0 s | `aquasecurity/trivy-action@0.28.0` no existe | Fijar `v0.36.0` (último release por API) |
| 1/10 07:44 | Todos los runs fallaban con "workflow file issue" | El contexto `secrets` no está disponible en `if:` de steps | Variable de entorno del job (`HAS_GCP`) evaluada en el `if` |
| 1/10 07:44 | Dependabot abrió un PR a Express 5 | Config por defecto incluye versiones mayores | `ignore` de `semver-major` en `dependabot.yml` |
| 1/10 07:45 | El build no ejecutaba los tests aunque existía la etapa *test* | Docker solo construye las etapas de las que depende el target final | *test* genera un marcador que *runtime* copia, forzando la dependencia |
| 30/9 20:10 | `docker build` fallaba con "gpg: decryption failed" | Credenciales de Docker Hub en `pass`, cifradas con una clave GPG de frase olvidada; Docker Desktop las consulta en cada pull | Borrar el almacén de `pass` (solo tenía esas credenciales). Docker descarga anónimo; la imagen va a ghcr.io con el token de GitHub |
| 30/9 19:55 | `terraform validate` rechazaba `variables.tf` | HCL no permite varios argumentos en un bloque de una línea | Bloques multilínea |
| 30/9 19:55 | El YAML del workflow no parseaba | `${{ }}` dentro de mapas en línea `{ a: b }` | Bloques `with:` en formato de bloque |
| 30/9 19:50 | `node --test test/` no encontraba los tests | En Node 22 el runner espera patrones de archivo, no un directorio | `node --test` sin argumentos |

## Lecciones

- Los fallos aparecen en las junturas entre herramientas, no dentro de cada una: imagen privada que el cluster no puede bajar, UID por nombre que Kubernetes no verifica, Ingress sin endpoints en el primer segundo.
- Un paso de diagnóstico automático en el job de deploy (`if: failure()`) ahorró varias iteraciones ciegas.
- Verificar espacio en disco y memoria de la VM antes de levantar un cluster local con monitoreo completo.
