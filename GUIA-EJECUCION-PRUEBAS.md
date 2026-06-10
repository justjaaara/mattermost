# Guía de Comandos para Ejecución Manual de Pruebas — Toggle Reviewer

> **Shell:** Fish  
> **Nota:** Los comandos de esta guía están escritos para copiar y pegar directamente en una terminal interactiva de Fish. Si necesitas ejecutar un script completo (como `api-toggle-reviewer-tests.sh`), se mantiene en `bash` porque usa `#!/bin/bash`.

---

## 1. Preparación del entorno

### Verificar que el servidor está corriendo
```fish
curl -s http://localhost:8065/api/v4/system/ping | jq .
```
**Respuesta esperada:** `{"status":"OK"}`

### Variables de entorno (en Fish)
```fish
set -x BASE_URL "http://localhost:8065"
set -x ADMIN_TOKEN "sikxyytwx7ns78p7qr4ouypkcw"
set -x USER_ID "41zi8sjrfina8fkjoq8u5ichyh"
set -x TEAM_ID "3nxh448t9igd8fnznhu9eff9cr"
```

---

## 2. Pruebas API

### Script automatizado (bash — recomendado)
```fish
cd /home/felipe/Documents/GitRepos/mattermost
chmod +x api-toggle-reviewer-tests.sh
bash ./api-toggle-reviewer-tests.sh
```

---

## 3. Pruebas de Regresión

### Backend (Go)
```fish
cd /home/felipe/Documents/GitRepos/mattermost/server

# Suite completa de regresión
set -x PATH $PATH /usr/local/go/bin

go test ./channels/app -run 'TestContentFlagging|TestGetReviewersForTeam|TestSaveContentFlaggingConfig|TestAssignFlaggedPostReviewer|TestFlagPost|TestGetContentFlaggingConfigReviewerIDs' -v -timeout 15m

# Tests individuales
go test ./channels/app -run '^TestContentFlaggingEnabledForTeam$' -v
go test ./channels/app -run '^TestGetReviewersForTeam$' -v
go test ./channels/app -run '^TestSaveContentFlaggingConfig$' -v
go test ./channels/app -run '^TestAssignFlaggedPostReviewer$' -v
go test ./channels/app -run '^TestFlagPost$' -v
go test ./channels/app -run '^TestGetContentFlaggingConfigReviewerIDs$' -v

# Con cobertura
go test ./channels/app -run 'TestContentFlagging' -v -coverprofile=coverage_app.out -timeout 15m
go tool cover -func=coverage_app.out | grep content_flagging
```

### Frontend (Jest)
```fish
cd /home/felipe/Documents/GitRepos/mattermost/webapp/channels

# Tests individuales
npx cross-env TZ=Etc/UTC LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 jest content_reviewers.test.tsx --verbose
npx cross-env TZ=Etc/UTC LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 jest team_reviewers_section.test.tsx --verbose

# Suite completa
npx cross-env TZ=Etc/UTC LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 jest content_reviewers.test.tsx team_reviewers_section.test.tsx --verbose

# Con cobertura
npx jest team_reviewers_section.test.tsx --coverage \
  --collectCoverageFrom='src/components/admin_console/content_flagging/content_reviewers/team_reviewers_section/team_reviewers_section.tsx' \
  --collectCoverageFrom='!src/**/*.test.tsx'
```

---

## 4. Pruebas Unitarias

### Backend (Go)
```fish
cd /home/felipe/Documents/GitRepos/mattermost/server

# Preparar entorno
make modules-tidy
make setup-go-work
go generate -buildvcs=false ./channels/store
cd ./public; go generate -buildvcs=false ./plugin; cd ..

# Test del toggle
go test ./channels/app -run '^TestContentFlaggingEnabledForTeam$' -v

# Test de resolución de reviewers
go test ./channels/app -run '^TestGetReviewersForTeam$' -v

# Test de validación del modelo
go test ./public/model -run '^TestReviewerSettings_IsValid$' -v

# Test de guardado
go test ./channels/app -run '^TestSaveContentFlaggingConfig$' -v

# Test de asignación
go test ./channels/app -run '^TestAssignFlaggedPostReviewer$' -v

# Test de flagging
go test ./channels/app -run '^TestFlagPost$' -v

# Test de config reviewer IDs
go test ./channels/app -run '^TestGetContentFlaggingConfigReviewerIDs$' -v

# Con memoria limitada (para CI)
set -x GOMAXPROCS 1
set -x GOGC 50
set -x GOMEMLIMIT 2GiB
go test ./channels/app -run '^TestContentFlaggingEnabledForTeam$' -v -p 1 -vet=off
```

### Frontend (Jest)
```fish
cd /home/felipe/Documents/GitRepos/mattermost/webapp
npm install --ignore-scripts

cd /home/felipe/Documents/GitRepos/mattermost/webapp/channels

# Test componente principal (radio buttons)
npx cross-env TZ=Etc/UTC LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 jest content_reviewers.test.tsx --verbose

# Test sección de equipos (toggle, paginación)
npx cross-env TZ=Etc/UTC LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 jest team_reviewers_section.test.tsx --verbose

# Cobertura por archivo
npx jest content_reviewers.test.tsx --coverage \
  --collectCoverageFrom='src/components/admin_console/content_flagging/content_reviewers/content_reviewers.tsx'
```

---

## 5. Pruebas de Seguridad

> **Nota:** Las pruebas de seguridad requieren **tokens reales** de usuarios reales en el servidor. El script incluido obtiene automáticamente el token de usuario regular.

### Script automatizado (bash — recomendado)
```fish
cd /home/felipe/Documents/GitRepos/mattermost
chmod +x security-toggle-reviewer-tests.sh
bash ./security-toggle-reviewer-tests.sh
```


---

## 6. Pruebas de Rendimiento

### Instalar k6
```fish
# Ubuntu/Debian
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D786D10F933941025036
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```

### Ejecutar script de carga
```fish
set -x ADMIN_TOKEN "sikxyytwx7ns78p7qr4ouypkcw"
set -x TEAM_ID "3nxh448t9igd8fnznhu9eff9cr"

# Ejecutar desde el directorio donde esté el script
k6 run /home/felipe/Documents/GitRepos/mattermost/performance_toggle_reviewer.js \
  --out json=/tmp/performance_results.json
```

### Script de ejemplo (guardar como `performance_toggle_reviewer.js`)
```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 10 },
    { duration: '2m', target: 10 },
    { duration: '30s', target: 50 },
    { duration: '2m', target: 50 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = 'http://localhost:8065';
const TOKEN = __ENV.ADMIN_TOKEN || 'test-token';
const TEAM_ID = __ENV.TEAM_ID || 'team1';

export default function () {
  const res = http.get(
    `${BASE_URL}/api/v4/content_flagging/team/${TEAM_ID}/status`,
    { headers: { Authorization: `Bearer ${TOKEN}` } }
  );
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  sleep(1);
}
```

---

## 7. Pruebas de Caja Negra (Manual)

### CB-01: Seleccionar "Same reviewers for all teams" = True
```fish
# Abrir navegador en:
# http://localhost:8065/admin_console/security/content_flagging
#
# Verificar que aparece selector de usuarios común
# y no aparece grilla de equipos
```

### CB-02: Seleccionar "Same reviewers for all teams" = False
```fish
# Verificar que aparece grilla de equipos con toggles
# y no aparece selector común
```

### CB-03 a CB-05: Toggle de equipo
```fish
# Usar UI del navegador:
# 1. Click en toggle de un equipo
# 2. Verificar que cambia color
# 3. Verificar estado con:
curl -s "$BASE_URL/api/v4/content_flagging/team/$TEAM_ID/status" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### CB-06: Configuración inválida (modo común sin revisores)
```fish
# Guardar config con CommonReviewers=true pero sin IDs
curl -s -X PUT "$BASE_URL/api/v4/content_flagging/config" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"ReviewerSettings": {"CommonReviewers": true, "CommonReviewerIds": [], "SystemAdminsAsReviewers": false, "TeamAdminsAsReviewers": false}}'
```
**Esperado:** HTTP 400

---

## 8. Comandos útiles (Fish)

### Ver logs del servidor
```fish
# En tiempo real
tail -f /tmp/mattermost-server.log

# Buscar errores
grep -i "error\|fail\|panic" /tmp/mattermost-server.log
```

### Reiniciar servidor
```fish
# Matar proceso actual
pkill -f "mattermost"

# Reiniciar
nohup bash -c 'cd /home/felipe/Documents/GitRepos/mattermost/server && export MM_SQLSETTINGS_DRIVERNAME=postgres && export MM_SQLSETTINGS_DATASOURCE="postgres://mmuser:mostest@localhost:5432/mattermost_test?sslmode=disable&connect_timeout=10" && export MM_NO_DOCKER=true && export MM_FEATUREFLAGS_CONTENTFLAGGING=true && make run-server > /tmp/mattermost-server.log 2>&1' > /tmp/nohup.out 2>&1 &
```

### Verificar procesos
```fish
ps aux | grep mattermost | grep -v grep
```

### Verificar puertos
```fish
sudo netstat -tlnp | grep 8065
# o
sudo ss -tlnp | grep 8065
```

### Verificar Docker
```fish
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Verificar Docker Compose
```fish
docker compose ls
docker compose ps
```

---

## 9. Estructura de archivos de prueba

```
/home/felipe/Documents/GitRepos/mattermost/
├── api-toggle-reviewer-tests.sh          # Script automatizado API (bash)
├── security-toggle-reviewer-tests.sh     # Script automatizado seguridad (bash)
├── docker-compose.mattermost.yml         # Docker Compose para servidor
├── performance_toggle_reviewer.js        # Script k6 (rendimiento)
├── GUIA-EJECUCION-PRUEBAS.md            # Esta guía (Fish)
├── Final Validación - Toggle Reviewer.md # Documento completo
├── server/
│   ├── channels/app/content_flagging_test.go
│   ├── public/model/content_flagging_settings_test.go
│   └── ...
└── webapp/channels/
    ├── src/components/admin_console/content_flagging/content_reviewers/content_reviewers.test.tsx
    └── src/components/admin_console/content_flagging/content_reviewers/team_reviewers_section/team_reviewers_section.test.tsx
```

---

## 10. Notas importantes

- **Shell:** Los comandos de esta guía están en **Fish shell**. Si usas `bash`, reemplaza `set -x` por `export`, `$VAR` por `${VAR}` donde sea necesario, y `; and` por `&&`.
- **Token de admin:** El token actual es `sikxyytwx7ns78p7qr4ouypkcw`. Puede cambiar si se reinicia el servidor.
- **Feature Flag:** La funcionalidad Toggle Reviewer requiere `FeatureFlagContentFlagging=true` (ya está activo).
- **Base de datos:** PostgreSQL está corriendo en `localhost:5432` con `mmuser/mostest`.
- **Puertos:** Servidor `8065`, Jenkins `8080`, SonarQube `9012`, PostgreSQL `5432`.
- **Scripts:** Los scripts automatizados (`api-toggle-reviewer-tests.sh`, `security-toggle-reviewer-tests.sh`) están en `bash` y se ejecutan con `bash ./script.sh` (no dependen del shell interactivo del usuario).
- **Tokens de seguridad:** Las pruebas de seguridad requieren tokens **reales**. El script `security-toggle-reviewer-tests.sh` obtiene automáticamente el token de usuario regular haciendo login. Si prefieres hacerlo manualmente, sigue los pasos en la sección 5.
