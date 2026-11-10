// Compila la web para el proyecto real (design.md §6, «Hosting»). Corre como `predeploy` de
// Hosting, así nunca se publica una versión que apunte a los emuladores. FLUTTER elige el
// comando: `flutter` (por defecto) o `fvm flutter` (en local).
import { spawnSync } from 'node:child_process';

const flutter = process.env.FLUTTER ?? 'flutter';
const command = `${flutter} build web --release --dart-define=FIREBASE_ENV=production`;

console.log(`> ${command}`);
const { status } = spawnSync(command, { stdio: 'inherit', shell: true });
process.exit(status ?? 1);
