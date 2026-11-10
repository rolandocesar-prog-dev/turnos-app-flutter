import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import type { FidMessage, Messaging } from 'firebase-admin/messaging';

import { isStaleTokenError, type Notice } from './notices.js';

/** Envío de avisos a dispositivos (design.md §13 «Envío»). Devuelve los ids que ya no sirven. */
export interface PushSender {
  send(fids: readonly string[], notice: Notice): Promise<{ stale: string[] }>;
}

/** Producción: FCM con el SDK de administración, un mensaje por id de instalación. */
export class FcmSender implements PushSender {
  constructor(private readonly messaging: Messaging) {}

  async send(fids: readonly string[], notice: Notice): Promise<{ stale: string[] }> {
    if (fids.length === 0) return { stale: [] };
    const messages: FidMessage[] = fids.map((fid) => ({
      fid,
      notification: notice,
      // Al tocar el aviso en la web se abre «Mis reservas».
      webpush: { fcmOptions: { link: '/#/mis-reservas' } },
    }));
    const result = await this.messaging.sendEach(messages);
    const stale = result.responses.flatMap((response, index) =>
      !response.success && isStaleTokenError(response.error?.code) ? [fids[index] ?? ''] : [],
    );
    return { stale };
  }
}

/** Prefijo de los ids que el buzón del emulador trata como vencidos, para probar la limpieza. */
export const STALE_FID_PREFIX = 'vencido-';

/**
 * Emulador: no hay FCM, así que cada aviso se guarda en `devOutbox`, que las pruebas leen y las
 * reglas mantienen cerrada.
 */
export class OutboxSender implements PushSender {
  constructor(private readonly db: Firestore) {}

  async send(fids: readonly string[], notice: Notice): Promise<{ stale: string[] }> {
    if (fids.length === 0) return { stale: [] };
    await this.db.collection('devOutbox').add({
      fids,
      ...notice,
      createdAt: FieldValue.serverTimestamp(),
    });
    return { stale: fids.filter((fid) => fid.startsWith(STALE_FID_PREFIX)) };
  }
}

/** Avisa a todos los dispositivos de [uid] y quita del perfil los ids vencidos. */
export async function notifyUser(
  db: Firestore,
  sender: PushSender,
  uid: string,
  notice: Notice,
): Promise<number> {
  const profile = db.collection('users').doc(uid);
  const tokens: unknown = (await profile.get()).get('fcmTokens');
  const fids = Array.isArray(tokens)
    ? tokens.filter((t): t is string => typeof t === 'string')
    : [];
  if (fids.length === 0) return 0;

  const { stale } = await sender.send(fids, notice);
  if (stale.length > 0) {
    await profile.update({ fcmTokens: FieldValue.arrayRemove(...stale) });
  }
  return fids.length - stale.length;
}
