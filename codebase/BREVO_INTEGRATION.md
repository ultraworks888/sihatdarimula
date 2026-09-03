# Brevo Integration Guide — My Healthy Start

This guide explains how to connect your self-hosted backend to the PocketBase notification queue to deliver SMS and WhatsApp messages via Brevo.

---

## Architecture Overview

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  React App   │────▶│  PocketBase  │◀────│ Brevo Worker │
│  (Frontend)  │     │  (Backend)   │     │  (Your Host) │
└──────────────┘     └──────────────┘     └──────────────┘
                           │                      │
                     notification_queue       Brevo API
                     notification_prefs       (SMS/WhatsApp)
```

1. **React App** saves user notification preferences to PocketBase
2. **PocketBase** stores preferences + a `notification_queue` collection
3. **Brevo Worker** (your self-hosted Node.js service) polls the queue and sends messages via Brevo API

---

## PocketBase Collections

### `notification_preferences`
Stores per-user opt-in/out for channels and notification types.

| Field               | Type     | Description                        |
|---------------------|----------|------------------------------------|
| user                | relation | → users                            |
| sms_enabled         | bool     | Opted into SMS                     |
| whatsapp_enabled    | bool     | Opted into WhatsApp                |
| in_app_enabled      | bool     | Opted into in-app notifications    |
| vaccine_reminders   | bool     | Vaccine due/overdue alerts         |
| content_updates     | bool     | New article notifications          |
| growth_reminders    | bool     | Monthly growth log reminders       |
| feeding_reminders   | bool     | Scheduled feeding alerts           |

### `notification_queue`
Messages waiting to be sent. Your Brevo worker reads `status = "pending"`.

| Field            | Type     | Description                                   |
|------------------|----------|-----------------------------------------------|
| user             | relation | → users                                       |
| child            | relation | → children (optional)                         |
| channel          | select   | `sms` \| `whatsapp` \| `in_app`               |
| type             | select   | `vaccine_reminder` \| `content_update` \| etc  |
| status           | select   | `pending` \| `sent` \| `failed` \| `cancelled` |
| phone            | text     | Malaysian number (+60...)                      |
| title            | text     | Notification title                             |
| message          | text     | Body text / template fallback                  |
| template_id      | text     | Brevo template ID (for WhatsApp)               |
| template_params  | json     | Template variable values                       |
| scheduled_at     | date     | When to send (null = ASAP)                     |
| sent_at          | date     | When actually sent                             |
| error_message    | text     | Error details if failed                        |
| external_id      | text     | Brevo message ID for tracking                  |

### `notifications`
In-app notifications shown to the user. Created by the worker or by PocketBase hooks.

| Field   | Type     | Description              |
|---------|----------|--------------------------|
| user    | relation | → users                  |
| child   | relation | → children (optional)    |
| type    | select   | Notification category    |
| title   | text     | Display title            |
| message | text     | Display message          |
| is_read | bool     | Read status              |

---

## Brevo Worker Setup (Node.js)

### 1. Install Dependencies

```bash
mkdir brevo-worker && cd brevo-worker
npm init -y
npm install @getbrevo/brevo pocketbase node-cron
```

### 2. Environment Variables

Create a `.env` file:

```env
POCKETBASE_URL=https://your-pocketbase-url.com
PB_ADMIN_EMAIL=admin@example.com
PB_ADMIN_PASSWORD=your-admin-password
BREVO_API_KEY=xkeysib-your-brevo-api-key
BREVO_WHATSAPP_SENDER=+60XXXXXXXXX
BREVO_SMS_SENDER=HealthyStart
```

### 3. Worker Script (`worker.js`)

```javascript
require('dotenv').config();
const cron = require('node-cron');
const PocketBase = require('pocketbase/cjs');
const SibApiV3Sdk = require('@getbrevo/brevo');

const pb = new PocketBase(process.env.POCKETBASE_URL);

// Brevo SMS client
const smsApi = new SibApiV3Sdk.TransactionalSMSApi();
smsApi.setApiKey(SibApiV3Sdk.TransactionalSMSApiApiKeys.apiKey, process.env.BREVO_API_KEY);

// Brevo WhatsApp client (uses transactional email API with WhatsApp channel)
const waApi = new SibApiV3Sdk.TransactionalWhatsAppApi();
// Note: WhatsApp via Brevo uses their dedicated endpoint

async function authenticate() {
  await pb.admins.authWithPassword(
    process.env.PB_ADMIN_EMAIL,
    process.env.PB_ADMIN_PASSWORD
  );
  console.log('[Auth] Authenticated with PocketBase');
}

async function processQueue() {
  try {
    const now = new Date().toISOString();
    const pending = await pb.collection('notification_queue').getFullList({
      filter: `status = "pending" && (scheduled_at = "" || scheduled_at <= "${now}")`,
      sort: 'created',
      expand: 'user',
    });

    console.log(`[Queue] Found ${pending.length} pending notifications`);

    for (const notif of pending) {
      try {
        if (notif.channel === 'sms') {
          await sendSMS(notif);
        } else if (notif.channel === 'whatsapp') {
          await sendWhatsApp(notif);
        } else if (notif.channel === 'in_app') {
          await createInAppNotification(notif);
        }

        await pb.collection('notification_queue').update(notif.id, {
          status: 'sent',
          sent_at: new Date().toISOString(),
        });
      } catch (err) {
        console.error(`[Error] Failed to send ${notif.id}:`, err.message);
        await pb.collection('notification_queue').update(notif.id, {
          status: 'failed',
          error_message: err.message?.substring(0, 1000) || 'Unknown error',
        });
      }
    }
  } catch (err) {
    console.error('[Queue] Error processing queue:', err.message);
  }
}

async function sendSMS(notif) {
  const sms = new SibApiV3Sdk.SendTransacSms();
  sms.sender = process.env.BREVO_SMS_SENDER;
  sms.recipient = notif.phone;
  sms.content = notif.message;
  sms.type = 'transactional';

  const result = await smsApi.sendTransacSms(sms);
  console.log(`[SMS] Sent to ${notif.phone}: ${result.messageId}`);

  await pb.collection('notification_queue').update(notif.id, {
    external_id: result.messageId,
  });
}

async function sendWhatsApp(notif) {
  // Use Brevo's WhatsApp API with pre-approved templates
  const payload = {
    senderNumber: process.env.BREVO_WHATSAPP_SENDER,
    recipientNumber: notif.phone,
    templateId: parseInt(notif.template_id),
    params: notif.template_params || {},
  };

  const response = await fetch('https://api.brevo.com/v3/whatsapp/sendMessage', {
    method: 'POST',
    headers: {
      'api-key': process.env.BREVO_API_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`WhatsApp API error: ${err}`);
  }

  const result = await response.json();
  console.log(`[WhatsApp] Sent to ${notif.phone}: ${result.messageId}`);

  await pb.collection('notification_queue').update(notif.id, {
    external_id: result.messageId || '',
  });
}

async function createInAppNotification(notif) {
  await pb.collection('notifications').create({
    user: notif.user,
    child: notif.child || '',
    type: notif.type,
    title: notif.title,
    message: notif.message,
    is_read: false,
  });
  console.log(`[InApp] Created notification for user ${notif.user}`);
}

// === Reminder Generator ===
// Runs daily, checks children's ages and creates queue entries

async function generateVaccineReminders() {
  console.log('[Reminders] Generating vaccine reminders...');

  const children = await pb.collection('children').getFullList({
    filter: 'is_born = true',
    expand: 'user',
  });

  const vaccines = [
    { name: 'BCG', ageMonths: 0 },
    { name: 'Hepatitis B - Dose 1', ageMonths: 0 },
    { name: 'DTaP - Dose 1', ageMonths: 2 },
    { name: 'IPV - Dose 1', ageMonths: 2 },
    { name: 'Hib - Dose 1', ageMonths: 2 },
    { name: 'PCV - Dose 1', ageMonths: 2 },
    { name: 'Rotavirus - Dose 1', ageMonths: 2 },
    { name: 'DTaP - Dose 2', ageMonths: 4 },
    { name: 'IPV - Dose 2', ageMonths: 4 },
    { name: 'Hib - Dose 2', ageMonths: 4 },
    { name: 'Rotavirus - Dose 2', ageMonths: 4 },
    { name: 'DTaP - Dose 3', ageMonths: 6 },
    { name: 'IPV - Dose 3', ageMonths: 6 },
    { name: 'Hib - Dose 3', ageMonths: 6 },
    { name: 'PCV - Dose 2', ageMonths: 6 },
    { name: 'Hepatitis B - Dose 2', ageMonths: 6 },
    { name: 'Measles - Dose 1', ageMonths: 9 },
    { name: 'PCV - Dose 3', ageMonths: 9 },
    { name: 'MMR - Dose 1', ageMonths: 12 },
    { name: 'Varicella - Dose 1', ageMonths: 12 },
    { name: 'Hepatitis A - Dose 1', ageMonths: 12 },
    { name: 'DTaP Booster', ageMonths: 18 },
    { name: 'IPV Booster', ageMonths: 18 },
    { name: 'Hepatitis A - Dose 2', ageMonths: 24 },
    { name: 'MMR - Dose 2', ageMonths: 24 },
    { name: 'Varicella - Dose 2', ageMonths: 36 },
  ];

  for (const child of children) {
    const userId = child.user;
    const dob = new Date(child.date_of_birth);
    const now = new Date();
    const ageMonths = (now.getFullYear() - dob.getFullYear()) * 12 + (now.getMonth() - dob.getMonth());

    // Get user preferences
    let prefs;
    try {
      prefs = await pb.collection('notification_preferences').getFirstListItem(
        `user = "${userId}"`
      );
    } catch {
      continue; // No preferences set — skip
    }

    if (!prefs.vaccine_reminders) continue;

    // Get completed immunisations
    const completed = await pb.collection('immunisations').getFullList({
      filter: `child = "${child.id}" && is_completed = true`,
    });
    const completedNames = new Set(completed.map(r => r.vaccine_name));

    // Get user phone
    const user = await pb.collection('users').getOne(userId);
    const phone = user.phone;

    for (const vaccine of vaccines) {
      if (completedNames.has(vaccine.name)) continue;

      // Send reminder 2 weeks before due date, on due date, and if overdue
      const isDueSoon = ageMonths === vaccine.ageMonths - 1 || ageMonths === vaccine.ageMonths;
      const isOverdue = ageMonths > vaccine.ageMonths;

      if (!isDueSoon && !isOverdue) continue;

      // Check if already queued today
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      try {
        await pb.collection('notification_queue').getFirstListItem(
          `user = "${userId}" && type = "vaccine_reminder" && channel != "in_app" && title = "${vaccine.name}" && created >= "${todayStart.toISOString()}"`
        );
        continue; // Already queued today
      } catch {
        // Not queued yet — proceed
      }

      const status = isOverdue ? 'OVERDUE' : 'DUE';
      const message = `[${status}] ${vaccine.name} for ${child.name}. Please schedule a visit to your paediatrician.`;

      // Queue for each enabled channel
      const channelsToSend = [];
      if (prefs.sms_enabled && phone) channelsToSend.push('sms');
      if (prefs.whatsapp_enabled && phone) channelsToSend.push('whatsapp');
      if (prefs.in_app_enabled) channelsToSend.push('in_app');

      for (const channel of channelsToSend) {
        await pb.collection('notification_queue').create({
          user: userId,
          child: child.id,
          channel,
          type: 'vaccine_reminder',
          status: 'pending',
          phone: phone || '',
          title: vaccine.name,
          message,
          template_id: channel === 'whatsapp' ? 'vaccine_reminder_v1' : '',
          template_params: channel === 'whatsapp' ? JSON.stringify({
            child_name: child.name,
            vaccine_name: vaccine.name,
            status: status,
          }) : null,
        });
      }
    }
  }

  console.log('[Reminders] Done generating vaccine reminders');
}

// === MAIN ===
(async () => {
  await authenticate();

  // Process queue every 2 minutes
  cron.schedule('*/2 * * * *', processQueue);

  // Generate vaccine reminders daily at 8am
  cron.schedule('0 8 * * *', generateVaccineReminders);

  // Initial run
  await processQueue();

  console.log('[Worker] Brevo notification worker started');
})();
```

### 4. WhatsApp Template Setup (Brevo Dashboard)

Create these pre-approved templates in your Brevo account:

#### Template: `vaccine_reminder_v1`
```
Hello! This is a reminder from My Healthy Start.

Your child {{child_name}} has a {{status}} vaccine: {{vaccine_name}}.

Please schedule a visit to your paediatrician soon.

Reply STOP to unsubscribe.
```

#### Template: `content_update_v1`
```
New article on My Healthy Start!

{{article_title}}

Open the app to read more: {{app_url}}
```

### 5. Run the Worker

```bash
# Development
node worker.js

# Production (use PM2 or systemd)
pm2 start worker.js --name brevo-worker
```

---

## Deployment Checklist

1. [ ] Create Brevo account and get API key
2. [ ] Register WhatsApp Business number with Meta (via Brevo)
3. [ ] Create and get approval for WhatsApp templates
4. [ ] Set up PocketBase superuser for the worker
5. [ ] Deploy worker to your SiteGround server
6. [ ] Configure environment variables
7. [ ] Test with a pending notification queue entry
8. [ ] Set up PM2 or systemd for process management
9. [ ] Monitor Brevo dashboard for delivery reports

---

## Security Notes

- The Brevo API key is stored ONLY on your backend server, never in client code
- The PocketBase `notification_queue` is superuser-only (all rules are `null`)
- User preferences are user-scoped (only the owner can read/write)
- Phone numbers are validated as Malaysian format (+60) on the frontend
