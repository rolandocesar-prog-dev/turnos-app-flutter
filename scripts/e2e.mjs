// Prueba de integración (design.md §10): carga los datos de ejemplo y corre `flutter drive` en
// Chrome. Se ejecuta dentro de `firebase emulators:exec` (npm run test:e2e), con chromedriver
// escuchando en el puerto 4444. FLUTTER elige el comando: `flutter` (CI) o `fvm flutter` (local).
import { spawnSync } from 'node:child_process';

const flutter = process.env.FLUTTER ?? 'flutter';
const steps = [
  'node scripts/seed.mjs',
  `${flutter} drive --driver=test_driver/integration_test.dart ` +
    '--target=integration_test/booking_flow_test.dart -d web-server --browser-name=chrome',
];

for (const command of steps) {
  console.log(`> ${command}`);
  const { status } = spawnSync(command, { stdio: 'inherit', shell: true });
  if (status !== 0) process.exit(status ?? 1);
}
