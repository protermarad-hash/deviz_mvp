const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2/options');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

admin.initializeApp();
setGlobalOptions({ region: 'europe-west1', maxInstances: 10 });

const db = admin.firestore();

const COLLECTIONS = {
  notifications: 'notifications',
  emailQueue: 'notification_email_queue',
  users: 'users',
  companyProfiles: 'company_profiles',
  emailServerConfigs: 'email_server_configs',
  emailDeliveryLogs: 'email_delivery_logs',
  pushQueue: 'notification_push_queue',
  deviceTokens: 'notification_device_tokens',
};

const DEFAULT_COMPANY_ID = 'default';
const FORCED_SMTP_ADMIN_EMAIL = 'proterm.arad@gmail.com';
const MAX_INLINE_ATTACHMENT_BYTES = 550 * 1024;

const SMTP_HOST_SECRET = defineSecret('NOTIFICATION_SMTP_HOST');
const SMTP_PORT_SECRET = defineSecret('NOTIFICATION_SMTP_PORT');
const SMTP_USER_SECRET = defineSecret('NOTIFICATION_SMTP_USER');
const SMTP_PASS_SECRET = defineSecret('NOTIFICATION_SMTP_PASS');
const EMAIL_FROM_SECRET = defineSecret('NOTIFICATION_EMAIL_FROM');
const SMTP_SECURE_SECRET = defineSecret('NOTIFICATION_SMTP_SECURE');
const EMAIL_CONFIG_ENCRYPTION_SECRET = defineSecret('EMAIL_CONFIG_ENCRYPTION_KEY');

const EMAIL_RUNTIME_SECRETS = [
  SMTP_HOST_SECRET,
  SMTP_PORT_SECRET,
  SMTP_USER_SECRET,
  SMTP_PASS_SECRET,
  EMAIL_FROM_SECRET,
  SMTP_SECURE_SECRET,
  EMAIL_CONFIG_ENCRYPTION_SECRET,
];

exports.saveEmailServerConfig = onCall(
  { region: 'europe-west1', secrets: EMAIL_RUNTIME_SECRETS },
  async (request) => {
    const actor = await resolveActorContext(request, { requireAdmin: true });
    const data = request.data || {};
    const configId = (data.configId || '').toString().trim();
    if (!configId) {
      throw new HttpsError('invalid-argument', 'configId este obligatoriu.');
    }

    await migrateLegacyEmailConfigsIfNeeded(actor.companyId);

    const companyConfigs = companyEmailConfigsCollection(actor.companyId);
    const configRef = companyConfigs.doc(configId);
    const existingSnapshot = await configRef.get();
    const existing = existingSnapshot.exists ? existingSnapshot.data() || {} : {};
    const activeSnapshot = await companyConfigs
      .where('is_active', '==', true)
      .limit(1)
      .get();
    const hasAnyActiveConfig = !activeSnapshot.empty;
    const shouldAutoActivateFirst = !existingSnapshot.exists && !hasAnyActiveConfig;
    const now = admin.firestore.FieldValue.serverTimestamp();
    const encryptedPassword = resolveEncryptedPassword({
      incomingPassword: (data.password || '').toString(),
      existingEncryptedPassword: (existing.password_encrypted || '').toString(),
    });

    const payload = {
      id: configId,
      provider: (data.provider || 'custom_smtp').toString().trim(),
      host: (data.host || '').toString().trim(),
      port: Number(data.port || 0),
      secure: normalizeBoolean(data.secure),
      username: (data.username || '').toString().trim(),
      password_encrypted: encryptedPassword,
      from_email: (data.fromEmail || '').toString().trim(),
      from_name: (data.fromName || '').toString().trim(),
      reply_to_email: (data.replyToEmail || '').toString().trim(),
      enabled: shouldAutoActivateFirst ? true : normalizeBoolean(data.enabled, true),
      is_active: shouldAutoActivateFirst
        ? true
        : normalizeBoolean(existing.is_active, false),
      company_id: actor.companyId,
      created_by: existing.created_by || actor.uid,
      created_by_email: existing.created_by_email || actor.email,
      updated_by: actor.uid,
      updated_by_email: actor.email,
      last_test_at: existing.last_test_at || null,
      last_test_status: (existing.last_test_status || '').toString().trim(),
      last_test_error: (existing.last_test_error || '').toString().trim(),
      created_at: existing.created_at || now,
      updated_at: now,
    };

    validateEmailConfig({
      host: payload.host,
      port: payload.port,
      secure: payload.secure,
      username: payload.username,
      password: encryptedPassword ? '__stored__' : '',
      fromEmail: payload.from_email,
    });
    await configRef.set(payload, { merge: true });

    if (payload.is_active) {
      await ensureSingleActiveCompanyConfig({
        companyId: actor.companyId,
        activeConfigId: configId,
      });
    }

    return {
      ok: true,
      configId,
      isActive: payload.is_active,
      enabled: payload.enabled,
      autoActivated: shouldAutoActivateFirst,
    };
  },
);

exports.listEmailServerConfigs = onCall(
  { region: 'europe-west1', secrets: EMAIL_RUNTIME_SECRETS },
  async (request) => {
    const actor = await resolveActorContext(request, { requireAdmin: false });
    await migrateLegacyEmailConfigsIfNeeded(actor.companyId);
    const snapshot = await companyEmailConfigsCollection(actor.companyId)
      .orderBy('updated_at', 'desc')
      .get();
    const configs = snapshot.docs.map((doc) =>
      sanitizeConfigForClient({
        ...(doc.data() || {}),
        id: (doc.data() || {}).id || doc.id,
      }),
    );

    if (!actor.isAdmin) {
      const active = configs.find((item) => item.is_active === true && item.enabled !== false);
      return {
        ok: true,
        items: [],
        summary: {
          hasActiveEmailServer: !!active,
          fromEmail: active ? (active.from_email || '') : '',
          fromName: active ? (active.from_name || '') : '',
        },
      };
    }

    return {
      ok: true,
      items: configs,
    };
  },
);

exports.listEmailDeliveryLogs = onCall(
  { region: 'europe-west1', secrets: EMAIL_RUNTIME_SECRETS },
  async (request) => {
    const actor = await resolveActorContext(request, { requireAdmin: false });
    const limit = Math.max(
      1,
      Math.min(100, Number((request.data || {}).limit || 50) || 50),
    );
    let snapshot;
    try {
      snapshot = await db
        .collection(COLLECTIONS.emailDeliveryLogs)
        .where('company_id', '==', actor.companyId)
        .orderBy('created_at', 'desc')
        .limit(limit)
        .get();
    } catch (_) {
      snapshot = await db
        .collection(COLLECTIONS.emailDeliveryLogs)
        .orderBy('created_at', 'desc')
        .limit(Math.max(limit * 2, 50))
        .get();
    }
    const items = snapshot.docs.map((doc) => ({
      ...(doc.data() || {}),
      id: (doc.data() || {}).id || doc.id,
    }))
      .filter((item) => {
        const company = (item.company_id || '').toString().trim();
        return !company || company === actor.companyId;
      })
      .slice(0, limit);
    return {
      ok: true,
      items,
    };
  },
);

exports.setActiveEmailServerConfig = onCall(
  { region: 'europe-west1', secrets: EMAIL_RUNTIME_SECRETS },
  async (request) => {
    const actor = await resolveActorContext(request, { requireAdmin: true });
    const configId = ((request.data || {}).configId || '').toString().trim();
    if (!configId) {
      throw new HttpsError('invalid-argument', 'configId este obligatoriu.');
    }
    await migrateLegacyEmailConfigsIfNeeded(actor.companyId);
    const snapshot = await companyEmailConfigsCollection(actor.companyId).get();
    const batch = db.batch();
    let found = false;
    snapshot.docs.forEach((doc) => {
      const isTarget = doc.id === configId;
      if (isTarget) found = true;
      batch.set(
        doc.ref,
        {
          is_active: isTarget,
          company_id: actor.companyId,
          updated_by: actor.uid,
          updated_by_email: actor.email,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
    if (!found) {
      throw new HttpsError('not-found', 'Configuratia SMTP nu a fost gasita.');
    }
    await batch.commit();
    return { ok: true, activeConfigId: configId };
  },
);

exports.testEmailServerConfig = onCall(
  { region: 'europe-west1', secrets: EMAIL_RUNTIME_SECRETS },
  async (request) => {
    const actor = await resolveActorContext(request, { requireAdmin: false });
    let resolved = null;
    try {
      resolved = await resolveEmailConfigFromRequest(request.data || {}, actor.companyId);
      const transporter = createTransporterFromConfig(resolved.config);
      await transporter.verify();
      if (resolved.configId) {
        await markConfigTestResult({
          companyId: actor.companyId,
          configId: resolved.configId,
          status: 'success',
          error: '',
        });
      }
      return {
        ok: true,
        message: 'Conexiunea SMTP este validă.',
        configId: resolved.configId,
      };
    } catch (error) {
      const errorPayload = buildSmtpCallableError({
        error,
        action: 'test_connection',
        configId: resolved?.configId || '',
        config: resolved?.config,
      });
      logger.error('SMTP test connection failed', {
        action: 'test_connection',
        configId: resolved?.configId || '',
        smtp: buildSafeSmtpContext(resolved?.config),
        error: serializeErrorForLogs(error),
      });
      if (resolved.configId) {
        await markConfigTestResult({
          companyId: actor.companyId,
          configId: resolved.configId,
          status: 'failed',
          error: errorPayload.message,
        });
      }
      throw new HttpsError(errorPayload.code, errorPayload.message, errorPayload.details);
    }
  },
);

exports.sendEmailServerTestEmail = onCall(
  { region: 'europe-west1', secrets: EMAIL_RUNTIME_SECRETS },
  async (request) => {
    const actor = await resolveActorContext(request, { requireAdmin: false });
    const data = request.data || {};
    let resolved = null;
    const logId = `email-test-${Date.now()}`;
    try {
      const toEmail = (data.toEmail || '').toString().trim();
      if (!toEmail) {
        throw new HttpsError('invalid-argument', 'Lipseste adresa destinatar pentru emailul de test.');
      }
      resolved = await resolveEmailConfigFromRequest(data, actor.companyId);
      const { config, configId } = resolved;
      const transporter = createTransporterFromConfig(config);
      const info = await transporter.sendMail({
        from: formatFromHeader(config.fromName, config.fromEmail),
        to: toEmail,
        replyTo: config.replyToEmail || undefined,
        subject: 'Test configurare SMTP',
        text: 'Acesta este un email de test trimis din configurarea SMTP activa din Modaris.',
        html: '<p>Acesta este un email de test trimis din configurarea SMTP activa din Modaris.</p>',
      });
      if (configId) {
        await markConfigTestResult({
          companyId: actor.companyId,
          configId,
          status: 'success',
          error: '',
        });
      }
      await db.collection(COLLECTIONS.emailDeliveryLogs).doc(logId).set(
        {
          id: logId,
          source_module: 'email_settings',
          source_entity_id: configId || 'draft',
          to: toEmail,
          subject: 'Test configurare SMTP',
          status: 'sent',
          attempt_count: 1,
          error_message: '',
          provider_message_id: info.messageId || '',
          company_id: actor.companyId,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          sent_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return {
        ok: true,
        message: 'Emailul de test a fost trimis.',
        providerMessageId: info.messageId || '',
      };
    } catch (error) {
      const toEmail = (data.toEmail || '').toString().trim();
      const configId = resolved?.configId || '';
      const errorPayload = buildSmtpCallableError({
        error,
        action: 'send_test_email',
        configId,
        config: resolved?.config,
      });
      logger.error('SMTP send test email failed', {
        action: 'send_test_email',
        configId,
        toEmail,
        smtp: buildSafeSmtpContext(resolved?.config),
        error: serializeErrorForLogs(error),
      });
      if (configId) {
        await markConfigTestResult({
          companyId: actor.companyId,
          configId,
          status: 'failed',
          error: errorPayload.message,
        });
      }
      await db.collection(COLLECTIONS.emailDeliveryLogs).doc(logId).set(
        {
          id: logId,
          source_module: 'email_settings',
          source_entity_id: configId || 'draft',
          to: toEmail,
          subject: 'Test configurare SMTP',
          status: 'failed',
          attempt_count: 1,
          error_message: errorPayload.message,
          provider_message_id: '',
          company_id: actor.companyId,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          sent_at: null,
        },
        { merge: true },
      );
      throw new HttpsError(errorPayload.code, errorPayload.message, errorPayload.details);
    }
  },
);

exports.processNotificationEmailQueue = onDocumentWritten(
  {
    document: `${COLLECTIONS.emailQueue}/{queueId}`,
    secrets: EMAIL_RUNTIME_SECRETS,
  },
  async (event) => {
    const after = event.data?.after;
    if (!after) return;
    const queue = after.data() || {};
    const previous = event.data?.before?.data() || null;
    if (!shouldProcessQueue(queue, previous)) return;

    const queueRef = after.ref;
    const queueId = (queue.id || after.id || '').toString().trim() || after.id;
    const recipientEmail = (queue.recipient_email || '').toString().trim();
    const queueSubject = (queue.subject || '').toString().trim();
    const deliveryLogRef = db
      .collection(COLLECTIONS.emailDeliveryLogs)
      .doc(queueId);
    const notificationRef = db
      .collection(COLLECTIONS.notifications)
      .doc((queue.notification_id || '').toString().trim());

    logger.info('Processing notification email queue item', {
      queueId,
      sourceModule: (queue.source_module || '').toString().trim(),
      sourceEntityId: (queue.source_entity_id || '').toString().trim(),
      recipientEmail,
      subject: queueSubject,
      status: (queue.status || '').toString().trim(),
      attachmentCount: Array.isArray(queue.attachments) ? queue.attachments.length : 0,
      inlineAssetCount: Array.isArray(queue.inline_assets) ? queue.inline_assets.length : 0,
    });

    const companyId = resolveCompanyIdFromQueue(queue);

    await deliveryLogRef.set(
      {
        id: deliveryLogRef.id,
        source_module: (queue.source_module || '').toString().trim(),
        source_entity_id: (queue.source_entity_id || '').toString().trim(),
        to: (queue.recipient_email || '').toString().trim(),
        subject: (queue.subject || '').toString().trim(),
        status: 'queued',
        attempt_count: Number(queue.attempt_count || 0),
        error_message: '',
        provider_message_id: '',
        company_id: companyId,
        created_at: queue.created_at || admin.firestore.FieldValue.serverTimestamp(),
        sent_at: null,
      },
      { merge: true },
    );

    await queueRef.set(
      {
        status: 'sending',
        attempt_count: Number(queue.attempt_count || 0) + 1,
        last_attempt_at: admin.firestore.FieldValue.serverTimestamp(),
        error_message: '',
      },
      { merge: true },
    );
    await deliveryLogRef.set(
      {
        status: 'sending',
        attempt_count: Number(queue.attempt_count || 0) + 1,
        error_message: '',
      },
      { merge: true },
    );
    await notificationRef.set(
      {
        email_status: 'sending',
        email_error_message: '',
        last_delivery_attempt_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    try {
      validateQueueEmailPayload(queue);
      const runtimeConfig = await resolveActiveEmailRuntimeConfig(companyId);
      const transporter = createTransporterFromConfig(runtimeConfig);
      const attachments = await resolveQueueAttachments(queue);
      // inline assets: [{ cid, filename, base64, contentType }]
      if (Array.isArray(queue.inline_assets)) {
        queue.inline_assets.forEach((asset) => {
          try {
            if (!asset || !asset.cid || !asset.base64) return;
            attachments.push({
              filename: asset.filename ? asset.filename.toString() : asset.cid.toString(),
              content: Buffer.from(asset.base64.toString(), 'base64'),
              cid: asset.cid.toString(),
              contentType: asset.contentType ? asset.contentType.toString() : undefined,
            });
          } catch (e) {}
        });
      }

      logger.info('Queue item attachments resolved', {
        queueId,
        resolvedAttachmentCount: attachments.length,
      });
      const info = await transporter.sendMail({
        from: formatFromHeader(runtimeConfig.fromName, runtimeConfig.fromEmail),
        to: recipientEmail,
        replyTo: runtimeConfig.replyToEmail || undefined,
        subject: queueSubject,
        text: (queue.body_text || queue.body || '').toString(),
        html: (queue.body_html || '').toString() || undefined,
        attachments: attachments.length ? attachments : undefined,
      });
      await queueRef.set(
        {
          status: 'sent',
          processed_at: admin.firestore.FieldValue.serverTimestamp(),
          provider_message_id: info.messageId || '',
          error_message: '',
        },
        { merge: true },
      );
      await deliveryLogRef.set(
        {
          status: 'sent',
          attempt_count: Number(queue.attempt_count || 0) + 1,
          provider_message_id: info.messageId || '',
          error_message: '',
          company_id: companyId,
          sent_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      await notificationRef.set(
        {
          sent_email: true,
          email_status: 'sent',
          email_error_message: '',
          last_delivery_attempt_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } catch (error) {
      logger.error('Email queue failed', {
        queueId,
        recipientEmail,
        subject: queueSubject,
        error: serializeErrorForLogs(error),
      });
      await queueRef.set(
        {
          status: 'failed',
          processed_at: admin.firestore.FieldValue.serverTimestamp(),
          error_message: normalizeError(error),
        },
        { merge: true },
      );
      await deliveryLogRef.set(
        {
          status: 'failed',
          attempt_count: Number(queue.attempt_count || 0) + 1,
          error_message: normalizeError(error),
          company_id: companyId,
        },
        { merge: true },
      );
      await notificationRef.set(
        {
          sent_email: false,
          email_status: 'failed',
          email_error_message: normalizeError(error),
          last_delivery_attempt_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  },
);

exports.processNotificationPushQueue = onDocumentWritten(
  `${COLLECTIONS.pushQueue}/{queueId}`,
  async (event) => {
    const after = event.data?.after;
    if (!after) return;
    const queue = after.data() || {};
    const previous = event.data?.before?.data() || null;
    if (!shouldProcessQueue(queue, previous)) return;

    const queueRef = after.ref;
    const notificationRef = db
      .collection(COLLECTIONS.notifications)
      .doc((queue.notification_id || '').toString().trim());

    await queueRef.set(
      {
        status: 'sending',
        attempt_count: Number(queue.attempt_count || 0) + 1,
        last_attempt_at: admin.firestore.FieldValue.serverTimestamp(),
        error_message: '',
      },
      { merge: true },
    );
    await notificationRef.set(
      {
        push_status: 'sending',
        push_error_message: '',
        last_delivery_attempt_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    try {
      const recipientUserId = (queue.recipient_user_id || '').toString().trim();
      const tokensSnapshot = await db
        .collection(COLLECTIONS.deviceTokens)
        .where('user_id', '==', recipientUserId)
        .where('is_active', '==', true)
        .get();
      const tokens = tokensSnapshot.docs
        .map((doc) => ((doc.data() || {}).token || '').toString().trim())
        .filter(Boolean);

      if (!tokens.length) {
        throw new Error('Nu exista device token activ pentru utilizator.');
      }

      const data = stringifyValues({
        ...(queue.metadata || {}),
        source_module: (queue.source_module || '').toString().trim(),
        source_entity_id: (queue.source_entity_id || '').toString().trim(),
        title: (queue.title || '').toString().trim(),
        body: (queue.body || '').toString().trim(),
        notification_id: (queue.notification_id || '').toString().trim(),
      });
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: (queue.title || '').toString().trim(),
          body: (queue.body || '').toString().trim(),
        },
        data,
        android: {
          priority: 'high',
          notification: {
            channelId: 'modaris_realtime_notifications',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      });

      const failedTokens = [];
      response.responses.forEach((item, index) => {
        if (!item.success) {
          failedTokens.push(tokens[index]);
        }
      });
      if (failedTokens.length === tokens.length) {
        throw new Error(
          response.responses[0]?.error?.message || 'Push-ul a esuat pe toate device-urile.',
        );
      }

      await queueRef.set(
        {
          status: 'sent',
          processed_at: admin.firestore.FieldValue.serverTimestamp(),
          error_message:
            failedTokens.length > 0
              ? `Unele device-uri au esuat: ${failedTokens.length}`
              : '',
        },
        { merge: true },
      );
      await notificationRef.set(
        {
          sent_push: true,
          push_status: 'sent',
          push_error_message:
            failedTokens.length > 0
              ? `Unele device-uri au esuat: ${failedTokens.length}`
              : '',
          last_delivery_attempt_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } catch (error) {
      logger.error('Push queue failed', error);
      await queueRef.set(
        {
          status: 'failed',
          processed_at: admin.firestore.FieldValue.serverTimestamp(),
          error_message: normalizeError(error),
        },
        { merge: true },
      );
      await notificationRef.set(
        {
          sent_push: false,
          push_status: 'failed',
          push_error_message: normalizeError(error),
          last_delivery_attempt_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  },
);

function shouldProcessQueue(current, previous) {
  const status = (current.status || '').toString().trim().toLowerCase();
  if (status !== 'queued') return false;
  const previousStatus = ((previous || {}).status || '').toString().trim().toLowerCase();
  return previousStatus !== 'sending';
}

function validateQueueEmailPayload(queue) {
  if (!(queue.recipient_email || '').toString().trim()) {
    throw new Error('Lipseste destinatarul emailului in notification_email_queue.');
  }
  if (!(queue.subject || '').toString().trim()) {
    throw new Error('Lipseste subiectul emailului in notification_email_queue.');
  }
  const bodyText = (queue.body_text || queue.body || '').toString().trim();
  const bodyHtml = (queue.body_html || '').toString().trim();
  if (!bodyText && !bodyHtml) {
    throw new Error('Lipseste continutul emailului (body_text/body_html) in notification_email_queue.');
  }
}

async function resolveQueueAttachments(queue) {
  const attachments = [];
  if (!Array.isArray(queue.attachments)) {
    return attachments;
  }
  for (const att of queue.attachments) {
    if (!att || !att.filename) continue;
    const fileName = att.filename.toString();
    const base64 = (att.base64 || '').toString();
    const storagePath = (att.storage_path || att.storagePath || '').toString().trim();
    const storageBucket = (att.storage_bucket || att.storageBucket || '').toString().trim();
    const contentType = (att.content_type || att.contentType || '').toString().trim();
    const declaredSize = Number(att.size_bytes || att.sizeBytes || 0) || 0;

    if (base64) {
      const buffer = Buffer.from(base64, 'base64');
      if (declaredSize > MAX_INLINE_ATTACHMENT_BYTES || buffer.length > MAX_INLINE_ATTACHMENT_BYTES) {
        throw new Error(
          `Attachment inline prea mare pentru Firestore queue (${fileName}). Incarca documentul in Storage si trimite storage_path.`,
        );
      }
      attachments.push({
        filename: fileName,
        content: buffer,
        contentType: contentType || undefined,
      });
      continue;
    }

    if (storagePath) {
      const bucket = storageBucket
        ? admin.storage().bucket(storageBucket)
        : admin.storage().bucket();
      let downloaded;
      try {
        [downloaded] = await bucket.file(storagePath).download();
      } catch (error) {
        throw new Error(
          `Nu am putut descarca attachment-ul din Storage (${fileName}): ${normalizeError(error)}`,
        );
      }
      attachments.push({
        filename: fileName,
        content: downloaded,
        contentType: contentType || undefined,
      });
      continue;
    }

    throw new Error(
      `Attachment invalid in notification_email_queue (${fileName}). Lipseste base64 sau storage_path.`,
    );
  }
  return attachments;
}

function createTransporterFromConfig(config) {
  validateEmailConfig(config);
  return nodemailer.createTransport({
    host: config.host,
    port: Number(config.port || 0),
    secure: normalizeBoolean(config.secure),
    auth:
      config.username && config.password
        ? { user: config.username, pass: config.password }
        : undefined,
  });
}

async function resolveActiveEmailRuntimeConfig(companyId = DEFAULT_COMPANY_ID) {
  await migrateLegacyEmailConfigsIfNeeded(companyId);
  const snapshot = await companyEmailConfigsCollection(companyId)
    .where('is_active', '==', true)
    .where('enabled', '==', true)
    .limit(1)
    .get();
  if (!snapshot.empty) {
    return configDocToRuntimeConfig(snapshot.docs[0].data() || {});
  }
  return createEnvRuntimeConfig();
}

function createEnvRuntimeConfig() {
  const host =
    firstSecretOrEnv(SMTP_HOST_SECRET, 'NOTIFICATION_SMTP_HOST', 'SMTP_HOST');
  const port = Number(
    firstSecretOrEnv(
      SMTP_PORT_SECRET,
      'NOTIFICATION_SMTP_PORT',
      'SMTP_PORT',
    ) || '587',
  );
  const user =
    firstSecretOrEnv(SMTP_USER_SECRET, 'NOTIFICATION_SMTP_USER', 'SMTP_USER');
  const pass =
    firstSecretOrEnv(SMTP_PASS_SECRET, 'NOTIFICATION_SMTP_PASS', 'SMTP_PASS');
  const from =
    firstSecretOrEnv(
      EMAIL_FROM_SECRET,
      'NOTIFICATION_EMAIL_FROM',
      'EMAIL_FROM',
      'MAIL_FROM',
    ) || user;
  if (!host || !port || !from) {
    throw new Error(
      'Config email lipsa: NOTIFICATION_SMTP_HOST, NOTIFICATION_SMTP_PORT si NOTIFICATION_EMAIL_FROM (sau aliasurile legacy) trebuie configurate in Firebase Secrets sau env.',
    );
  }
  return {
    provider: 'env_fallback',
    host,
    port,
    secure:
      firstSecretOrEnv(
        SMTP_SECURE_SECRET,
        'NOTIFICATION_SMTP_SECURE',
        'SMTP_SECURE',
        'false',
      ) === 'true',
    username: user,
    password: pass,
    fromEmail: from,
    fromName: '',
    replyToEmail: '',
  };
}

async function resolveEmailConfigFromRequest(data, companyId = DEFAULT_COMPANY_ID) {
  await migrateLegacyEmailConfigsIfNeeded(companyId);
  const companyConfigs = companyEmailConfigsCollection(companyId);
  const configId = (data.configId || '').toString().trim();
  if (configId) {
    const snapshot = await companyConfigs.doc(configId).get();
    if (!snapshot.exists) {
      throw new HttpsError('not-found', 'Configuratia SMTP nu a fost gasita.');
    }
    const base = snapshot.data() || {};
    const merged = {
      ...base,
      provider: (data.provider || base.provider || 'custom_smtp').toString().trim(),
      host: (data.host || base.host || '').toString().trim(),
      port: Number(data.port || base.port || 0),
      secure: data.secure === undefined ? base.secure : data.secure,
      username: (data.username || base.username || '').toString().trim(),
      from_email: (data.fromEmail || base.from_email || '').toString().trim(),
      from_name: (data.fromName || base.from_name || '').toString().trim(),
      reply_to_email: (data.replyToEmail || base.reply_to_email || '').toString().trim(),
      password:
        (data.password || '').toString().trim() ||
        decryptPassword((base.password_encrypted || '').toString()),
    };
    const config = configPayloadToRuntimeConfig(merged);
    return { configId, config };
  }

  if (!hasInlineSmtpInput(data)) {
    const snapshot = await db
      .collection(COLLECTIONS.companyProfiles)
      .doc(companyId)
      .collection(COLLECTIONS.emailServerConfigs)
      .where('is_active', '==', true)
      .where('enabled', '==', true)
      .limit(1)
      .get();
    if (snapshot.empty) {
      throw new HttpsError('failed-precondition', 'Nu exista configuratie SMTP activa.');
    }
    const config = configDocToRuntimeConfig(snapshot.docs[0].data() || {});
    return { configId: snapshot.docs[0].id, config };
  }

  const config = configPayloadToRuntimeConfig({
    provider: data.provider,
    host: data.host,
    port: data.port,
    secure: data.secure,
    username: data.username,
    password: data.password,
    from_email: data.fromEmail,
    from_name: data.fromName,
    reply_to_email: data.replyToEmail,
  });
  return { configId: '', config };
}

function configDocToRuntimeConfig(raw) {
  return configPayloadToRuntimeConfig({
    ...raw,
    password: decryptPassword((raw.password_encrypted || '').toString()),
  });
}

function configPayloadToRuntimeConfig(raw) {
  const config = {
    provider: (raw.provider || 'custom_smtp').toString().trim(),
    host: (raw.host || '').toString().trim(),
    port: parseSmtpPort(raw.port),
    secure: parseSecureBoolean(raw.secure),
    username: (raw.username || '').toString().trim(),
    password: (raw.password || '').toString(),
    fromEmail: (raw.from_email || raw.fromEmail || '').toString().trim(),
    fromName: (raw.from_name || raw.fromName || '').toString().trim(),
    replyToEmail: (raw.reply_to_email || raw.replyToEmail || '').toString().trim(),
  };
  validateEmailConfig(config);
  return config;
}

function formatFromHeader(fromName, fromEmail) {
  const name = (fromName || '').toString().trim();
  const email = (fromEmail || '').toString().trim();
  if (!name) return email;
  return `${name} <${email}>`;
}

function validateEmailConfig(config) {
  if (!(config.host || '').toString().trim()) {
    throw new HttpsError('invalid-argument', 'Lipseste host SMTP.');
  }
  if (!Number.isInteger(Number(config.port || 0)) || Number(config.port || 0) <= 0) {
    throw new HttpsError('invalid-argument', 'Port SMTP invalid.');
  }
  if (typeof config.secure !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Setarea secure trebuie sa fie boolean.');
  }
  if (!(config.username || '').toString().trim()) {
    throw new HttpsError('invalid-argument', 'Lipseste username SMTP.');
  }
  if (!(config.password || '').toString().trim()) {
    throw new HttpsError('invalid-argument', 'Lipseste parola SMTP in configuratia activa.');
  }
  if (!(config.fromEmail || '').toString().trim()) {
    throw new HttpsError('invalid-argument', 'Lipseste fromEmail in configuratia SMTP.');
  }
}

function parseSmtpPort(rawPort) {
  const portValue = Number(rawPort);
  if (!Number.isInteger(portValue) || portValue <= 0 || portValue > 65535) {
    throw new HttpsError('invalid-argument', 'Port SMTP invalid.');
  }
  return portValue;
}

function parseSecureBoolean(rawSecure) {
  if (typeof rawSecure === 'boolean') {
    return rawSecure;
  }
  if (rawSecure === undefined || rawSecure === null || `${rawSecure}`.trim() === '') {
    return false;
  }
  const value = `${rawSecure}`.trim().toLowerCase();
  if (['true', '1', 'yes', 'da'].includes(value)) return true;
  if (['false', '0', 'no', 'nu'].includes(value)) return false;
  throw new HttpsError('invalid-argument', 'Setarea secure trebuie sa fie boolean.');
}

function hasInlineSmtpInput(data) {
  const fields = [
    'host',
    'port',
    'username',
    'password',
    'fromEmail',
    'from_email',
    'replyToEmail',
    'reply_to_email',
    'provider',
    'secure',
  ];
  return fields.some((field) => data[field] !== undefined && data[field] !== null && `${data[field]}`.trim() !== '');
}

function buildSmtpCallableError({ error, action, configId, config }) {
  if (error instanceof HttpsError) {
    const details = {
      ...(typeof error.details === 'object' && error.details !== null ? error.details : {}),
      details:
        (error && error.message ? error.message : 'Eroare SMTP.').toString(),
      action,
      smtp: buildSafeSmtpContext(config),
      configId: configId || '',
    };
    return {
      code: error.code || 'internal',
      message: error.message || 'Eroare SMTP.',
      details,
    };
  }

  const defaultMessage = normalizeError(error);
  const smtpErrorCode = (error && (error.code || error.responseCode || error.command))
    ? String(error.code || error.responseCode || error.command)
    : 'SMTP_UNKNOWN';
  const responseCode = Number(error && error.responseCode ? error.responseCode : 0);
  const isAuthError = smtpErrorCode === 'EAUTH' || responseCode === 535 || /535|auth/i.test(defaultMessage);
  const message = isAuthError
    ? 'SMTP authentication failed. Verifica parola de aplicatie Gmail.'
    : defaultMessage;
  return {
    code: isAuthError ? 'permission-denied' : 'internal',
    message,
    details: {
      details: defaultMessage,
      action,
      smtpErrorCode,
      responseCode,
      technicalMessage: defaultMessage,
      smtp: buildSafeSmtpContext(config),
      configId: configId || '',
    },
  };
}

function buildSafeSmtpContext(config) {
  if (!config) {
    return {
      hasPassword: false,
    };
  }
  return {
    smtpHost: (config.host || '').toString().trim(),
    smtpPort: Number(config.port || 0),
    secure: typeof config.secure === 'boolean' ? config.secure : false,
    fromEmail: (config.fromEmail || '').toString().trim(),
    username: (config.username || '').toString().trim(),
    hasPassword: !!(config.password || '').toString().trim(),
  };
}

function serializeErrorForLogs(error) {
  if (!error) return { message: 'Unknown error' };
  return {
    name: error.name || '',
    code: error.code || '',
    message: normalizeError(error),
    stack: (error.stack || '').toString().slice(0, 3000),
    command: error.command || '',
    responseCode: error.responseCode || '',
    response: (error.response || '').toString().slice(0, 1000),
    errno: error.errno || '',
    syscall: error.syscall || '',
    address: error.address || '',
    port: error.port || '',
  };
}

function normalizeBoolean(value, fallback = false) {
  if (typeof value === 'boolean') return value;
  const text = (value || '').toString().trim().toLowerCase();
  if (!text) return fallback;
  return ['true', '1', 'yes', 'da'].includes(text);
}

function resolveEncryptedPassword({ incomingPassword, existingEncryptedPassword }) {
  const raw = (incomingPassword || '').toString();
  if (raw.trim()) {
    return encryptPassword(raw);
  }
  return (existingEncryptedPassword || '').toString().trim();
}

function encryptPassword(value) {
  if (!value) return '';
  const secret = firstSecretOrEnv(
    EMAIL_CONFIG_ENCRYPTION_SECRET,
    'EMAIL_CONFIG_ENCRYPTION_KEY',
  );
  if (!secret) {
    throw new Error('EMAIL_CONFIG_ENCRYPTION_KEY nu este configurata.');
  }
  const key = crypto.createHash('sha256').update(secret).digest();
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);
  const encrypted = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
  return `${iv.toString('base64')}:${encrypted.toString('base64')}`;
}

function decryptPassword(value) {
  if (!value) return '';
  const secret = firstSecretOrEnv(
    EMAIL_CONFIG_ENCRYPTION_SECRET,
    'EMAIL_CONFIG_ENCRYPTION_KEY',
  );
  if (!secret) {
    throw new Error('EMAIL_CONFIG_ENCRYPTION_KEY nu este configurata.');
  }
  const parts = value.split(':');
  if (parts.length !== 2) return '';
  const key = crypto.createHash('sha256').update(secret).digest();
  const iv = Buffer.from(parts[0], 'base64');
  const encrypted = Buffer.from(parts[1], 'base64');
  const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
  return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8');
}

async function markConfigTestResult({ companyId = DEFAULT_COMPANY_ID, configId, status, error }) {
  if (!configId) return;
  await companyEmailConfigsCollection(companyId).doc(configId).set(
    {
      last_test_at: admin.firestore.FieldValue.serverTimestamp(),
      last_test_status: status,
      last_test_error: (error || '').toString().trim(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

function normalizeError(error) {
  return (error && error.message ? error.message : String(error || 'Eroare necunoscuta')).slice(0, 500);
}

function companyEmailConfigsCollection(companyId) {
  const id = (companyId || DEFAULT_COMPANY_ID).toString().trim() || DEFAULT_COMPANY_ID;
  return db
    .collection(COLLECTIONS.companyProfiles)
    .doc(id)
    .collection(COLLECTIONS.emailServerConfigs);
}

function resolveCompanyIdFromQueue(queue) {
  const queueCompany = (queue.company_id || '').toString().trim();
  if (queueCompany) return queueCompany;
  const metadataCompany = ((queue.metadata || {}).company_id || '').toString().trim();
  if (metadataCompany) return metadataCompany;
  return DEFAULT_COMPANY_ID;
}

async function resolveActorContext(request, { requireAdmin = false } = {}) {
  const auth = request.auth || null;
  if (!auth || !auth.uid) {
    // Backward-compatible fallback for legacy app flows where Firebase Auth
    // token is not attached to callable requests.
    return {
      uid: 'legacy-unauthenticated',
      email: '',
      role: 'admin',
      isAdmin: true,
      companyId: DEFAULT_COMPANY_ID,
    };
  }
  const uid = (auth.uid || '').toString().trim();
  const token = auth.token || {};
  const email = (token.email || '').toString().trim().toLowerCase();

  const userProfile = await loadAuthUserProfile({ uid, email });
  const role = (userProfile.role || token.role || '').toString().trim().toLowerCase();
  const companyId = resolveCompanyId({ token, userProfile });
  const isForcedAdmin = email === FORCED_SMTP_ADMIN_EMAIL;
  const isAdmin = isForcedAdmin || ['admin'].includes(role);

  if (requireAdmin && !isAdmin) {
    throw new HttpsError('permission-denied', 'Doar administratorul poate modifica serverul SMTP.');
  }

  return {
    uid,
    email,
    role,
    isAdmin,
    companyId,
  };
}

async function loadAuthUserProfile({ uid, email }) {
  const usersRef = db.collection(COLLECTIONS.users);
  const byUid = await usersRef.where('firebase_uid', '==', uid).limit(1).get();
  if (!byUid.empty) {
    return byUid.docs[0].data() || {};
  }

  const docById = await usersRef.doc(uid).get();
  if (docById.exists) {
    return docById.data() || {};
  }

  if (email) {
    const byEmail = await usersRef.where('email', '==', email).limit(1).get();
    if (!byEmail.empty) {
      return byEmail.docs[0].data() || {};
    }
  }

  return {};
}

function resolveCompanyId({ token, userProfile }) {
  const candidates = [
    token.company_id,
    token.companyId,
    token.tenant_id,
    token.tenantId,
    token.organization_id,
    token.organizationId,
    token.firm_id,
    token.firmId,
    userProfile.company_id,
    userProfile.companyId,
    userProfile.tenant_id,
    userProfile.tenantId,
    userProfile.organization_id,
    userProfile.organizationId,
    userProfile.firm_id,
    userProfile.firmId,
  ];
  for (const item of candidates) {
    const value = (item || '').toString().trim();
    if (value) return value;
  }
  return DEFAULT_COMPANY_ID;
}

function sanitizeConfigForClient(raw) {
  const config = { ...(raw || {}) };
  const encrypted = (config.password_encrypted || '').toString().trim();
  delete config.password;
  config.password_encrypted = encrypted ? '__masked__' : '';
  config.has_password = encrypted.length > 0;
  return config;
}

async function ensureSingleActiveCompanyConfig({ companyId, activeConfigId }) {
  const snapshot = await companyEmailConfigsCollection(companyId).get();
  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    const shouldBeActive = doc.id === activeConfigId;
    batch.set(
      doc.ref,
      {
        is_active: shouldBeActive,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
  await batch.commit();
}

async function migrateLegacyEmailConfigsIfNeeded(companyId) {
  const scoped = companyEmailConfigsCollection(companyId);
  const existing = await scoped.limit(1).get();
  if (!existing.empty) {
    return;
  }

  const legacy = await db.collection(COLLECTIONS.emailServerConfigs).get();
  if (legacy.empty) {
    return;
  }

  const docs = legacy.docs.map((doc) => ({ id: doc.id, ...(doc.data() || {}) }));
  docs.sort((a, b) => {
    const aActive = a.is_active === true ? 1 : 0;
    const bActive = b.is_active === true ? 1 : 0;
    if (aActive !== bActive) return bActive - aActive;
    const aUpdated = (a.updated_at && a.updated_at.toMillis) ? a.updated_at.toMillis() : 0;
    const bUpdated = (b.updated_at && b.updated_at.toMillis) ? b.updated_at.toMillis() : 0;
    return bUpdated - aUpdated;
  });

  const preferredIndex = docs.findIndex((item) => {
    const emailParts = [
      (item.username || '').toString().trim().toLowerCase(),
      (item.from_email || '').toString().trim().toLowerCase(),
      (item.fromEmail || '').toString().trim().toLowerCase(),
      (item.created_by_email || '').toString().trim().toLowerCase(),
    ];
    return emailParts.includes(FORCED_SMTP_ADMIN_EMAIL);
  });
  const activeIndex = preferredIndex >= 0
    ? preferredIndex
    : Math.max(0, docs.findIndex((item) => item.is_active === true));

  const batch = db.batch();
  docs.forEach((item, index) => {
    const target = scoped.doc((item.id || '').toString().trim() || `migrated-${index + 1}`);
    batch.set(
      target,
      {
        ...item,
        id: (item.id || '').toString().trim() || `migrated-${index + 1}`,
        company_id: companyId,
        is_active: index === activeIndex,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
  await batch.commit();
}

function firstEnv(...keys) {
  for (const key of keys) {
    const value = (process.env[key] || '').toString().trim();
    if (value) return value;
  }
  return '';
}

function firstSecretOrEnv(secret, ...keys) {
  try {
    const secretValue = secret.value();
    if ((secretValue || '').toString().trim()) {
      return secretValue.toString().trim();
    }
  } catch (error) {}
  return firstEnv(...keys);
}

function stringifyValues(raw) {
  const result = {};
  Object.entries(raw || {}).forEach(([key, value]) => {
    if (value === null || value === undefined) return;
    result[key] = String(value);
  });
  return result;
}
