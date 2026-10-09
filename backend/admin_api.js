// Admin API for the payment-confirmation page (backend/admin_web/index.html,
// served at /admin). Every route needs the X-Admin-Key header to match
// ADMIN_API_KEY; without that env var the admin API is switched off.
const crypto = require('node:crypto');
const express = require('express');

function sameKey(given, expected) {
  const a = Buffer.from(String(given || ''));
  const b = Buffer.from(String(expected));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

/**
 * @param {object} options
 * @param {string} [options.adminKey]  ADMIN_API_KEY
 * @param {() => object} options.service  returns { list, confirm, reject }
 *   bound to Firestore (lazy, so the server starts without credentials).
 */
function createAdminRouter({ adminKey, service }) {
  const router = express.Router();
  router.use(express.json());

  router.use((req, res, next) => {
    if (!adminKey) {
      return res.status(503).json({ message: 'Admin API disabled: set ADMIN_API_KEY' });
    }
    if (!sameKey(req.get('x-admin-key'), adminKey)) {
      return res.status(401).json({ message: 'Invalid admin key' });
    }
    return next();
  });

  const handle = (fn) => async (req, res) => {
    try {
      res.json(await fn(req));
    } catch (error) {
      const notFound = /not found/i.test(error.message);
      const conflict = /not pending|cancelled/i.test(error.message);
      const invalid = /invalid/i.test(error.message);
      res
        .status(notFound ? 404 : conflict ? 409 : invalid ? 400 : 500)
        .json({ message: error.message });
    }
  };

  router.get('/bookings', handle(async (req) => {
    const state = ['pending', 'paid', 'cancelled'].includes(req.query.state)
      ? req.query.state
      : 'pending';
    return { state, bookings: await service().list(state) };
  }));

  router.post('/bookings/:id/confirm', handle(async (req) => ({
    confirmed: await service().confirm(req.params.id, 'admin-web'),
  })));

  router.post('/bookings/:id/reject', handle(async (req) => service().reject(req.params.id)));

  router.get('/config/payment', handle(async () => service().getPaymentConfig()));

  router.put('/config/payment', handle(async (req) => service().setPaymentConfig(req.body || {})));

  return router;
}

module.exports = { createAdminRouter };
