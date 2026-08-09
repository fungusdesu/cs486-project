import express from 'express';

const iso = (value) => new Date(value).toISOString();
const required = (body, names) => names.filter((name) => body?.[name] === undefined || body[name] === null || body[name] === '');

export function createApp({db}) {
  const app = express();
  app.use(express.json({limit: '32kb'}));
  app.get('/api/health', async (_req, res, next) => {
    try { res.json({ok: true, service: 'g06-backend', mode: db.mode, database: await db.health()}); } catch (error) { next(error); }
  });
  app.post('/api/bookings', async (req, res, next) => {
    try {
      const missing = required(req.body, ['booking_request_id', 'user_id', 'space_id', 'requested_start_time', 'requested_end_time']);
      if (missing.length) return res.status(400).json({error: 'missing_fields', fields: missing});
      if (new Date(req.body.requested_end_time) <= new Date(req.body.requested_start_time)) return res.status(400).json({error: 'invalid_time_range'});
      res.status(201).json(await db.createBooking(req.body));
    } catch (error) { next(error); }
  });
  for (const [path, decision] of [['approve', 'APPROVED'], ['reject', 'REJECTED']]) {
    app.post(`/api/bookings/:id/${path}`, async (req, res, next) => {
      try { res.json(await db.reviewBooking(req.params.id, decision, req.body ?? {})); } catch (error) { next(error); }
    });
  }
  app.get('/api/spaces/available', async (req, res, next) => {
    try {
      const missing = required(req.query, ['start', 'end']);
      if (missing.length) return res.status(400).json({error: 'missing_query', fields: missing});
      if (new Date(req.query.end) <= new Date(req.query.start)) return res.status(400).json({error: 'invalid_time_range'});
      res.json({spaces: await db.availableSpaces(req.query)});
    } catch (error) { next(error); }
  });
  app.post('/api/maintenance', async (req, res, next) => {
    try {
      const missing = required(req.body, ['maintenance_id', 'space_id', 'reporter_id']);
      if (missing.length) return res.status(400).json({error: 'missing_fields', fields: missing});
      res.status(201).json(await db.createMaintenance(req.body));
    } catch (error) { next(error); }
  });
  app.patch('/api/maintenance/:id/impact', async (req, res, next) => {
    try {
      if (!['ADVISORY', 'OUT_OF_SERVICE'].includes(req.body?.impact_level_code)) return res.status(400).json({error: 'invalid_impact_level'});
      res.json(await db.updateMaintenanceImpact(req.params.id, req.body));
    } catch (error) { next(error); }
  });
  app.get('/api/maintenance/:id/affected-bookings', async (req, res, next) => {
    try { res.json({bookings: await db.affectedBookings(req.params.id)}); } catch (error) { next(error); }
  });
  app.get('/api/reports/approved-hours', async (_req, res, next) => { try { res.json(await db.approvedHours()); } catch (error) { next(error); } });
  app.get('/api/reports/bookings-by-weekday-and-hour', async (_req, res, next) => { try { res.json({rows: await db.bookingsByWeekdayAndHour()}); } catch (error) { next(error); } });
  app.get('/api/reports/room-finder', async (req, res, next) => { try { res.json({spaces: await db.availableSpaces(req.query)}); } catch (error) { next(error); } });
  app.use((_req, res) => res.status(404).json({error: 'not_found'}));
  app.use((error, _req, res, _next) => { console.error(error); res.status(error.statusCode || 500).json({error: 'server_error', message: error.message}); });
  return app;
}