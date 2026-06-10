Pre-requisitos (hacer una sola vez)
cd /home/felipe/Documents/GitRepos/mattermost/server
# Generar código y dependencias
make modules-tidy
make setup-go-work
go generate -buildvcs=false ./channels/store
cd ./public && go generate -buildvcs=false ./plugin
Ejecutar tests específicos del toggle reviewer
cd /home/felipe/Documents/GitRepos/mattermost/server
# 1. Test del toggle (habilitado/deshabilitado por equipo)
go test ./channels/app -run '^TestContentFlaggingEnabledForTeam$' -v -timeout 10m

# 2. Test de resolución de reviewers (getReviewersForTeam)
go test ./channels/app -run '^TestGetReviewersForTeam$' -v -timeout 10m

# 3. Test de guardado de configuración
go test ./channels/app -run '^TestSaveContentFlaggingConfig$' -v -timeout 10m

# 4. Test de asignación de reviewer
go test ./channels/app -run '^TestAssignFlaggedPostReviewer$' -v -timeout 10m

# 5. Test de flagging de posts
go test ./channels/app -run '^TestFlagPost$' -v -timeout 10m

# 6. Test de validación del modelo (ReviewSettingsRequest.IsValid)
go test ./public/model -run '^TestReviewerSettings_IsValid$' -v -timeout 10m

# 7. Test de configuración de reviewer IDs
go test ./channels/app -run '^TestGetContentFlaggingConfigReviewerIDs$' -v -timeout 10m

Con cobertura
# App tests con coverage
go test ./channels/app -run '^TestContentFlaggingEnabledForTeam$' -v -coverprofile=coverage_app.out -timeout 10m

# Model tests con coverage
go test ./public/model -run '^TestReviewerSettings_IsValid$' -v -coverprofile=coverage_model.out -timeout 10m

# Ver cobertura por función
go tool cover -func=coverage_app.out | grep content_flagging

frontend

UNA VEZ 
cd /home/felipe/Documents/GitRepos/mattermost/webapp
npm install --ignore-scripts

cd /home/felipe/Documents/GitRepos/mattermost/webapp/channels
# Test del componente principal (radio buttons common vs team)
npx cross-env TZ=Etc/UTC LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 jest content_reviewers.test.tsx --verbose

# Test de la sección de equipos (toggle, paginación, disable all)
npx cross-env TZ=Etc/UTC LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 jest team_reviewers_section.test.tsx --verbose


# Test con cobertura (solo del archivo objetivo)
npx jest team_reviewers_section.test.tsx --coverage \
  --collectCoverageFrom='src/components/admin_console/content_flagging/content_reviewers/team_reviewers_section/team_reviewers_section.tsx' \
  --collectCoverageFrom='!src/**/*.test.tsx'


  3. Tests API (curl)
Requiere: Mattermost server corriendo en localhost:8065 y un token de autenticación.
# Variables de entorno
export BASE_URL="http://localhost:8065"
export ADMIN_TOKEN="TU_TOKEN_ADMIN"
export USER_TOKEN="TU_TOKEN_USUARIO"
export TEAM_ID="TU_TEAM_ID"
# API-01: Guardar configuración válida (modo común)
curl -X PUT "$BASE_URL/api/v4/content_flagging/config" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "EnableContentFlagging": true,
    "ReviewerSettings": {
      "CommonReviewers": true,
      "SystemAdminsAsReviewers": false,
      "TeamAdminsAsReviewers": false,
      "CommonReviewerIds": ["user_id_1"]
    }
  }'
# API-02: Configuración inválida (common sin IDs ni admins)
curl -X PUT "$BASE_URL/api/v4/content_flagging/config" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "ReviewerSettings": {
      "CommonReviewers": true,
      "SystemAdminsAsReviewers": false,
      "TeamAdminsAsReviewers": false,
      "CommonReviewerIds": []
    }
  }'
# Resultado esperado: HTTP 400
# API-04: Obtener configuración
curl -X GET "$BASE_URL/api/v4/content_flagging/config" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
# API-05: Consultar estado por equipo
curl -X GET "$BASE_URL/api/v4/content_flagging/team/$TEAM_ID/status" \
  -H "Authorization: Bearer $USER_TOKEN"
# API-06: Sin autenticación (debe dar 401)
curl -X PUT "$BASE_URL/api/v4/content_flagging/config" \
  -H "Content-Type: application/json" \
  -d '{"ReviewerSettings": {"CommonReviewers": true}}'
# API-07: Usuario sin permiso (debe dar 403)
curl -X PUT "$BASE_URL/api/v4/content_flagging/config" \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"ReviewerSettings": {"CommonReviewers": true}}'
4. Tests de Rendimiento (k6)
Instalar k6
# Ubuntu/Debian
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D786D10F933941025036
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
Crear archivo de test
cat > /tmp/performance_toggle_reviewer.js << 'EOF'
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
    http_req_failed: ['rate<<0.01'],
  },
};
const BASE_URL = 'http://localhost:8065';
const TOKEN = __ENV.ADMIN_TOKEN || 'test-token';
const TEAM_ID = __ENV.TEAM_ID || 'team1';
export default function () {
  const resStatus = http.get(
    `${BASE_URL}/api/v4/content_flagging/team/${TEAM_ID}/status`,
    { headers: { Authorization: `Bearer ${TOKEN}` } }
  );
  check(resStatus, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  const resConfig = http.get(
    `${BASE_URL}/api/v4/content_flagging/config`,
    { headers: { Authorization: `Bearer ${TOKEN}` } }
  );
  check(resConfig, {
    'config status is 200': (r) => r.status === 200,
    'config response time < 500ms': (r) => r.timings.duration < 500,
  });
  sleep(1);
}
EOF
Ejecutar
export ADMIN_TOKEN="TU_TOKEN"
export TEAM_ID="TU_TEAM_ID"
k6 run /tmp/performance_toggle_reviewer.js \
  --out json=/tmp/performance_results.json
5. Tests de Seguridad
SEC-01: Control de acceso (no admin)
curl -X PUT "http://localhost:8065/api/v4/content_flagging/config" \
  -H "Authorization: Bearer $REGULAR_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"EnableContentFlagging": true}'
# Esperado: HTTP 403
SEC-02: Usuario no reviewer
curl -X GET "http://localhost:8065/api/v4/content_flagging/team/$TEAM_ID/reviewers/search?term=" \
  -H "Authorization: Bearer $NON_REVIEWER_TOKEN"
# Esperado: HTTP 403
SEC-03: Payload malformado/XSS
curl -X PUT "http://localhost:8065/api/v4/content_flagging/config" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"ReviewerSettings": {"CommonReviewers": true, "CommonReviewerIds": ["<<script>alert(1)</script>"]}}'
# Esperado: HTTP 400
SEC-04: IDOR (team_id ajeno)
curl -X GET "http://localhost:8065/api/v4/content_flagging/team/team_ajeno/status" \
  -H "Authorization: Bearer $USER_TOKEN"
# Esperado: HTTP 403 si no pertenece al equipo
SEC-05: Feature flag desactivado
# 1. Desactivar ContentFlagging en config
# 2. Intentar acceder al endpoint
curl -X GET "http://localhost:8065/api/v4/content_flagging/config" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
# Esperado: HTTP 404 (endpoints no registrados)
6. Tests de Regresión
Manual (local)
cd /home/felipe/Documents/GitRepos/mattermost/server
# Suite completo de regresión backend
go test ./channels/app -run 'TestContentFlagging|TestGetReviewersForTeam|TestSaveContentFlaggingConfig|TestAssignFlaggedPostReviewer|TestFlagPost|TestGetContentFlaggingConfigReviewerIDs' -v -timeout 15m
cd /home/felipe/Documents/GitRepos/mattermost/webapp/channels
# Suite completo frontend
npx cross-env TZ=Etc/UTC LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 jest content_reviewers.test.tsx team_reviewers_section.test.tsx --verbose
En Jenkins (pipeline automatizado)
El pipeline actual ya ejecuta los tests de regresión en cada build. Solo necesitas hacer Build en Jenkins:
1. Ir a http://localhost:8080/job/mattermostt/
2. Click en "Build Now"
3. Ver console output en tiempo real
7. Ejecutar todo en un solo script
Puedes crear un script run-all-tests.sh:
#!/bin/bash
set -e
echo "=== 1. BUILD ==="
cd /home/felipe/Documents/GitRepos/mattermost/server
make modules-tidy
make setup-go-work
go generate -buildvcs=false ./channels/store
cd ./public && go generate -buildvcs=false ./plugin
echo "=== 2. BACKEND TESTS ==="
cd /home/felipe/Documents/GitRepos/mattermost/server
go test ./channels/app -run 'TestContentFlaggingEnabledForTeam|TestGetReviewersForTeam|TestSaveContentFlaggingConfig' -v -timeout 10m
go test ./public/model -run 'TestReviewerSettings_IsValid' -v
echo "=== 3. FRONTEND TESTS ==="
cd /home/felipe/Documents/GitRepos/mattermost/webapp/channels
npx jest team_reviewers_section.test.tsx --verbose
echo "=== 4. COVERAGE ==="
cd /home/felipe/Documents/GitRepos/mattermost/server
go test ./channels/app -run 'TestContentFlagging' -coverprofile=coverage.out -timeout 10m
go tool cover -func=coverage.out | grep content_flagging
echo "=== TODOS LOS TESTS PASARON ==="
