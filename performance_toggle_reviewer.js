import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 10 },   // Ramp-up
    { duration: '2m', target: 10 },    // Carga leve
    { duration: '30s', target: 50 },      // Ramp-up medio
    { duration: '2m', target: 50 },     // Carga media
    { duration: '30s', target: 0 },      // Ramp-down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],     // 95% de requests < 500ms
    http_req_failed: ['rate<0.01'],     // Tasa de error < 1%
  },
};

const BASE_URL = 'http://localhost:8065';
const TOKEN = __ENV.ADMIN_TOKEN || 'sikxyytwx7ns78p7qr4ouypkcw';
const TEAM_ID = __ENV.TEAM_ID || '3nxh448t9igd8fnznhu9eff9cr';

export default function () {
  // Escenario 1: Consultar estado de toggle por equipo (más frecuente)
  const resStatus = http.get(
    `${BASE_URL}/api/v4/content_flagging/team/${TEAM_ID}/status`,
    { headers: { Authorization: `Bearer ${TOKEN}` } }
  );
  check(resStatus, {
    'status endpoint: status is 200': (r) => r.status === 200,
    'status endpoint: response time < 500ms': (r) => r.timings.duration < 500,
  });

  // Escenario 2: Consultar configuración (admin)
  const resConfig = http.get(
    `${BASE_URL}/api/v4/content_flagging/config`,
    { headers: { Authorization: `Bearer ${TOKEN}` } }
  );
  check(resConfig, {
    'config endpoint: status is 200': (r) => r.status === 200,
    'config endpoint: response time < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(1);
}
