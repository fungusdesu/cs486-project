import sql from 'mssql';

export function createDatabase(env = process.env) {
  const mode = (env.DB_MODE || 'mock').toLowerCase();
  const rows = { bookings: [], maintenance: [], spaces: Array.from({length: 10}, (_, i) => ({space_id: `S${String(i + 1).padStart(4, '0')}`, space_name: `Mock Space ${i + 1}`})) };
  let pool;
  async function getPool() {
    if (!pool) pool = await sql.connect({server: env.DB_SERVER || 'localhost', database: env.DB_DATABASE || 'School', user: env.DB_USERNAME || undefined, password: env.DB_PASSWORD || undefined, options: {trustServerCertificate: String(env.DB_TRUST_SERVER_CERTIFICATE || 'true') === 'true'}, pool: {max: 10}});
    return pool;
  }
  if (mode === 'mock') return {mode, health: async () => 'mock', createBooking: async (body) => { const result = {...body, state: 'PENDING'}; rows.bookings.push(result); return result; }, reviewBooking: async (id, decision, body) => { const booking = rows.bookings.find((item) => item.booking_request_id === id); if (!booking) { const e = new Error('booking not found'); e.statusCode = 404; throw e; } booking.state = decision; return booking; }, availableSpaces: async () => rows.spaces, createMaintenance: async (body) => { const item = {...body, status: 'PENDING'}; rows.maintenance.push(item); return item; }, updateMaintenanceImpact: async (id, body) => ({maintenance_id: id, ...body}), affectedBookings: async (id) => rows.bookings.filter((b) => b.maintenance_id === id), approvedHours: async () => ({approved_hours: rows.bookings.filter((b) => b.state === 'APPROVED').length}), bookingsByWeekdayAndHour: async () => []};
  const exec = async (procedure, params = {}) => { const request = (await getPool()).request(); for (const [key, value] of Object.entries(params)) request.input(key, value); return (await request.execute(procedure)).recordset || []; };
  return {mode, health: async () => { await getPool(); return 'sqlserver'; }, createBooking: async (b) => (await exec('USP_CreateBookingRequest', b))[0] || {accepted: true}, reviewBooking: async (id, decision, b) => (await exec(decision === 'APPROVED' ? 'USP_ApproveBookingRequest' : 'USP_RejectBookingRequest', {...b, booking_request_id: id}))[0] || {booking_request_id: id, decision}, availableSpaces: async (q) => (await exec('USP_FindAvailableSpaces', q)), createMaintenance: async (b) => (await exec('USP_CreateMaintenance', b))[0] || b, updateMaintenanceImpact: async (id, b) => (await exec('USP_UpdateMaintenanceImpact', {...b, maintenance_id: id}))[0] || b, affectedBookings: async (id) => (await exec('USP_GetAffectedBookings', {maintenance_id: id})), approvedHours: async () => ({approved_hours: 0, note: 'attach approved report procedure'}), bookingsByWeekdayAndHour: async () => []};
}
