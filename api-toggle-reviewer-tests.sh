#!/bin/bash
set -e

# =============================================================================
# Script de Pruebas API para Toggle Reviewer
# =============================================================================
# Ejecuta las pruebas API documentadas en la sección 15 del informe
#
# Requisitos:
#   - Servidor Mattermost corriendo en localhost:8065
#   - Usuario admin creado
#   - Equipo creado
#
# Uso:
#   export ADMIN_TOKEN="tu-token"
#   export TEAM_ID="tu-team-id"
#   ./api-toggle-reviewer-tests.sh
# =============================================================================

BASE_URL="${BASE_URL:-http://localhost:8065}"
ADMIN_TOKEN="${ADMIN_TOKEN:-sikxyytwx7ns78p7qr4ouypkcw}"
TEAM_ID="${TEAM_ID:-3nxh448t9igd8fnznhu9eff9cr}"
USER_ID="${USER_ID:-41zi8sjrfina8fkjoq8u5ichyh}"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Contadores
PASSED=0
FAILED=0

# Función helper para hacer requests
make_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local expected_status="$4"
    local description="$5"
    local token="${6:-$ADMIN_TOKEN}"
    
    local url="$BASE_URL$endpoint"
    local response
    local http_code
    local curl_cmd
    
    if [ "$method" = "GET" ] && [ -z "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "$expected_status" ]; then
        echo -e "${GREEN}[PASS]${NC} $description (HTTP $http_code)"
        ((PASSED++)) || true
    else
        echo -e "${RED}[FAIL]${NC} $description (Expected: HTTP $expected_status, Got: HTTP $http_code)"
        echo "  Response: $body"
        ((FAILED++)) || true
    fi
}

echo "========================================="
echo "Pruebas API - Toggle Reviewer"
echo "Base URL: $BASE_URL"
echo "========================================="
echo ""

# =============================================================================
# API-01: Guardar configuración válida (modo común)
# =============================================================================
echo "--- API-01: Guardar config válida (modo común) ---"
make_request "PUT" "/api/v4/content_flagging/config" \
    '{
        "EnableContentFlagging": true,
        "ReviewerSettings": {
            "CommonReviewers": true,
            "SystemAdminsAsReviewers": false,
            "TeamAdminsAsReviewers": false,
            "CommonReviewerIds": ["'"$USER_ID"'"]
        }
    }' \
    "200" \
    "Guardar configuración válida (modo común)"

# =============================================================================
# API-02: Configuración inválida (common sin IDs ni admins)
# =============================================================================
echo ""
echo "--- API-02: Guardar config inválida (common sin IDs) ---"
make_request "PUT" "/api/v4/content_flagging/config" \
    '{
        "ReviewerSettings": {
            "CommonReviewers": true,
            "SystemAdminsAsReviewers": false,
            "TeamAdminsAsReviewers": false,
            "CommonReviewerIds": []
        }
    }' \
    "400" \
    "Configuración inválida (common sin IDs ni admins)"

# =============================================================================
# API-03: Guardar configuración válida (modo por equipo)
# =============================================================================
echo ""
echo "--- API-03: Guardar config válida (modo por equipo) ---"
make_request "PUT" "/api/v4/content_flagging/config" \
    '{
        "EnableContentFlagging": true,
        "ReviewerSettings": {
            "CommonReviewers": false,
            "SystemAdminsAsReviewers": false,
            "TeamAdminsAsReviewers": false,
            "TeamReviewersSetting": {
                "'"$TEAM_ID"'": {
                    "Enabled": true,
                    "ReviewerIds": ["'"$USER_ID"'"]
                }
            }
        }
    }' \
    "200" \
    "Guardar configuración válida (modo por equipo)"

# =============================================================================
# API-04: Obtener configuración
# =============================================================================
echo ""
echo "--- API-04: Obtener configuración ---"
make_request "GET" "/api/v4/content_flagging/config" \
    "" \
    "200" \
    "Obtener configuración actual"

# =============================================================================
# API-05: Consultar estado por equipo
# =============================================================================
echo ""
echo "--- API-05: Consultar estado por equipo ---"
make_request "GET" "/api/v4/content_flagging/team/$TEAM_ID/status" \
    "" \
    "200" \
    "Consultar estado de toggle por equipo"

# =============================================================================
# API-06: Sin autenticación
# =============================================================================
echo ""
echo "--- API-06: Sin autenticación ---"
response=$(curl -s -w "\n%{http_code}" -X PUT "$BASE_URL/api/v4/content_flagging/config" \
    -H "Content-Type: application/json" \
    -d '{"ReviewerSettings": {"CommonReviewers": true}}')
http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "401" ]; then
    echo -e "${GREEN}[PASS]${NC} Sin autenticación (HTTP 401)"
    ((PASSED++)) || true
else
    echo -e "${RED}[FAIL]${NC} Sin autenticación (Expected: HTTP 401, Got: HTTP $http_code)"
    ((FAILED++)) || true
fi

# =============================================================================
# API-07: Usuario sin permiso manage_system
# =============================================================================
echo ""
echo "--- API-07: Usuario sin permiso ---"
# Crear un usuario regular usando admin token
regular_user_response=$(curl -s -X POST "$BASE_URL/api/v4/users" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "email": "regular_api@example.com",
        "username": "regularapiuser",
        "password": "Regular123!",
        "first_name": "Regular",
        "last_name": "User"
    }')

# Login con usuario regular
regular_token=$(curl -s -D - -X POST "$BASE_URL/api/v4/users/login" \
    -H "Content-Type: application/json" \
    -d '{
        "login_id": "regular_api@example.com",
        "password": "Regular123!"
    }' | grep -i 'Token' | awk '{print $2}' | tr -d '\r')

if [ -z "$regular_token" ]; then
    echo -e "${YELLOW}[WARN]${NC} No se pudo obtener token de usuario regular. Probando con cadena vacía..."
    regular_token="invalid_token"
fi

response=$(curl -s -w "\n%{http_code}" -X PUT "$BASE_URL/api/v4/content_flagging/config" \
    -H "Authorization: Bearer $regular_token" \
    -H "Content-Type: application/json" \
    -d '{"ReviewerSettings": {"CommonReviewers": true}}')
http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "403" ]; then
    echo -e "${GREEN}[PASS]${NC} Usuario sin permiso manage_system (HTTP 403)"
    ((PASSED++)) || true
else
    echo -e "${RED}[FAIL]${NC} Usuario sin permiso (Expected: HTTP 403, Got: HTTP $http_code)"
    ((FAILED++)) || true
fi

# =============================================================================
# Resumen
# =============================================================================
echo ""
echo "========================================="
echo "Resumen de Pruebas API"
echo "========================================="
echo -e "${GREEN}Pasadas: $PASSED${NC}"
echo -e "${RED}Fallidas: $FAILED${NC}"
echo -e "${YELLOW}Total: $((PASSED + FAILED))${NC}"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}TODAS LAS PRUEBAS PASARON ✓${NC}"
    exit 0
else
    echo -e "${RED}ALGUNAS PRUEBAS FALLARON ✗${NC}"
    exit 1
fi
