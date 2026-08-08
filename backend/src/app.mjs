import express from 'express';
import { databaseHealth } from './database.mjs';
import { executeJsonProcedure } from './procedure-adapter.mjs';

const app = express();
app.use(express.json({ limit: '1mb' }));

const asyncRoute = (handler) => (request, response, next) =>
  Promise.resolve(handler(request, response, next)).catch(next);

const requireObjectBody = (request, _response, next) => {
  if (!request.body || Array.isArray(request.body) || typeof request.body !== 'object') {
    const error = new Error('Request body must be a JSON object.');
    error.statusCode = 400;
    error.name = 'ValidationError';
    throw error;
  }
  next();
};

const procedureRoute = (environmentKey, source) => asyncRoute(async (request, response) => {
  const payload = source(request);
  const rows = await executeJsonProcedure(environmentKey, payload);
  response.json({ data: rows });
});

app.get('/api/health', asyncRoute(async (_request, response) => {
  response.json({ status: 'ok', database: await databaseHealth() });
}));

app.post('/api/bookings', requireObjectBody, procedureRoute('PROC_SUBMIT_BOOKING', (request) => request.body));
app.post('/api/bookings/:id/approve', procedureRoute(
  'PROC_APPROVE_BOOKING',
  (request) => ({ ...request.body, booking_request_id: request.params.id }),
));
app.post('/api/bookings/:id/reject', procedureRoute(
  'PROC_REJECT_BOOKING',
  (request) => ({ ...request.body, booking_request_id: request.params.id }),
));
app.get('/api/spaces/available', procedureRoute(
  'PROC_FIND_AVAILABLE_SPACES',
  (request) => request.query,
));
app.post('/api/maintenance', requireObjectBody, procedureRoute('PROC_CREATE_MAINTENANCE', (request) => request.body));
app.patch('/api/maintenance/:id/impact', procedureRoute(
  'PROC_UPDATE_MAINTENANCE_IMPACT',
  (request) => ({ ...request.body, maintenance_id: request.params.id }),
));
app.get('/api/maintenance/:id/affected-bookings', procedureRoute(
  'PROC_AFFECTED_BOOKINGS',
  (request) => ({ ...request.query, maintenance_id: request.params.id }),
));
app.get('/api/reports/approved-hours', procedureRoute(
  'PROC_REPORT_APPROVED_HOURS',
  (request) => request.query,
));
app.get('/api/reports/bookings-by-time', procedureRoute(
  'PROC_REPORT_BOOKINGS_BY_TIME',
  (request) => request.query,
));
app.get('/api/rooms/find', procedureRoute('PROC_FIND_AVAILABLE_SPACES', (request) => request.query));
app.get('/api/maintenance/escalations', procedureRoute('PROC_MAINTENANCE_ESCALATIONS', (request) => request.query));

app.use((_request, response) => response.status(404).json({ error: 'Not found' }));
app.use((error, _request, response, _next) => {
  const status = Number(error.statusCode) || 500;
  response.status(status).json({
    error: error.name || 'Error',
    message: error.message || 'Unexpected server error',
  });
});

export default app;
