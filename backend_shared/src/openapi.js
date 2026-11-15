import { z, id, name, username, email, password, role, status, isoDate, coordinates } from './validation.js';
import { timePolicySchema } from './attendance-time.js';
import { criticalFactSchema } from './critical-facts.js';

const imageBase64 = z.string().min(16).max(2800000);
const language = z.enum(['vi', 'en', 'zh']);
const branch = z.object({ name, address: z.string().min(3).max(500), latitude: coordinates.latitude,
  longitude: coordinates.longitude, radiusMeters: z.number().min(20).max(5000), timePolicy: timePolicySchema.optional() }).strict();
const employee = z.object({ fullName: name, username, email, password, role: role.optional(),
  status: status.optional(), branchId: id.nullable().optional() }).strict();
const shift = z.object({ title: name, branchId: id, employeeId: id, startsAt: isoDate, endsAt: isoDate,
  status: z.literal('scheduled').optional() }).strict();
const correction = z.object({ shiftId: id, requestedCheckIn: isoDate.nullable().optional(),
  requestedCheckOut: isoDate.nullable().optional(), reason: z.string().min(5).max(2000) }).strict();
const item = z.object({ id, text: z.string().min(1).max(1000), translatedText: z.string().max(2000),
  state: z.enum(['open', 'understood', 'clarify']).default('open') }).strict();
const handover = z.object({ shiftId: id, recipientId: id, originalText: z.string().min(1).max(12000),
  translatedText: z.string().max(24000), sourceLanguage: language, targetLanguage: language,
  items: z.array(item).min(1).max(40), criticalFacts: z.array(criticalFactSchema).max(3).optional(),
  status: z.enum(['draft', 'submitted', 'acknowledged']).optional() }).strict();
const requests = {
  Register: z.object({ fullName: name, username, email, password }).strict(),
  Login: z.object({ username, password: z.string().min(1).max(128) }).strict(),
  VerifyOtp: z.object({ challengeId: id, code: z.string().regex(/^\d{6}$/) }).strict(),
  ResendOtp: z.object({ challengeId: id }).strict(),
  Refresh: z.object({ refreshToken: z.string().min(32).max(200) }).strict(),
  FaceLogin: z.object({ username, imageBase64 }).strict(),
  FaceUnlock: z.object({ username, imageBase64, deviceKey: z.string().regex(/^[A-Za-z0-9_-]{43}$/) }).strict(),
  FaceEnroll: z.object({ imageBase64, enableQuickLogin: z.boolean().optional() }).strict(),
  ProfilePatch: z.object({ fullName: name.optional(), phone: z.string().max(20).regex(/^[+()0-9 .-]*$/).optional(),
    bio: z.string().max(300).optional() }).strict(),
  Branch: branch, BranchPatch: branch.partial(), Employee: employee, EmployeePatch: employee.partial(),
  Shift: shift, ShiftPatch: shift.omit({ status: true }).partial(),
  Punch: z.object({ shiftId: id, ...coordinates }).strict(),
  Correction: correction,
  CorrectionPatch: correction.omit({ shiftId: true }).partial().extend({
    status: z.enum(['pending', 'approved', 'rejected']).optional(), resolutionNote: z.string().max(2000).optional(),
  }),
  LocationShare: z.object({ ...coordinates, ttlMinutes: z.number().int().min(1).max(120) }).strict(),
  Handover: handover,
  HandoverPatch: handover.omit({ shiftId: true }).partial().extend({ version: z.number().int().positive(),
    factAnswers: z.array(z.object({ factId: id, value: z.string().min(1).max(80) }).strict()).max(3).optional() }),
  ChatMessage: z.object({ clientMessageId: id, recipientId: id, text: z.string().min(1).max(2000), sourceLanguage: language }).strict(),
  NotificationDevice: z.object({ installationId: z.string().regex(/^[A-Za-z0-9_-]{22}$/),
    firebaseProjectId: z.string().min(6).max(30), platform: z.literal('android') }).strict(),
};
const schemas = Object.fromEntries(Object.entries(requests).map(([key, schema]) => {
  const json = z.toJSONSchema(schema, { io: 'input' });
  delete json.$schema;
  if (key.endsWith('Patch')) json.minProperties = key === 'HandoverPatch' ? 2 : 1;
  return [key, json];
}));
const ref = key => ({ $ref: `#/components/schemas/${key}` });
const jsonResponse = (description, data = {}) => ({ description,
  content: { 'application/json': { schema: { type: 'object', properties: { data }, required: ['data'] } } } });
const uuid = { type: 'string', format: 'uuid' };
schemas.OtpChallenge = { type: 'object', required: ['challengeId', 'maskedEmail', 'expiresAt', 'retryAfterSeconds'], properties: {
  challengeId: uuid, maskedEmail: { type: 'string' }, expiresAt: { type: 'string', format: 'date-time' },
  retryAfterSeconds: { type: 'integer', minimum: 0 }, purpose: { type: 'string' },
} };
schemas.Session = { type: 'object', required: ['accessToken', 'refreshToken', 'user'], properties: {
  accessToken: { type: 'string' }, refreshToken: { type: 'string' }, user: { type: 'object' },
} };
const paths = {};
function add(method, path, tag, summary, options = {}) {
  const { body, public: isPublic = false, result = {}, code = 200, description, parameters = [] } = options;
  const params = [...parameters];
  if (path.includes('{id}')) params.unshift({ name: 'id', in: 'path', required: true, schema: uuid });
  const operation = {
    tags: [tag], summary, operationId: `${method}_${path.replace(/[^a-zA-Z0-9]+/g, '_')}`,
    ...(description ? { description } : {}), ...(isPublic ? { security: [] } : {}),
    ...(params.length ? { parameters: params } : {}),
    ...(body ? { requestBody: { required: true, content: { 'application/json': { schema: ref(body) } } } } : {}),
    responses: { [code]: jsonResponse('Thành công', result),
      ...Object.fromEntries([400, 401, 403, 404, 409, 413, 422, 429, 503].map(code => [code, { $ref: '#/components/responses/Error' }])) },
  };
  (paths[path] ??= {})[method] = operation;
  return operation;
}
const query = (name, schema, required = false) => ({ name, in: 'query', required, schema });
add('get', '/health', 'Hệ thống', 'Kiểm tra API và PostgreSQL', { public: true });
for (const [path, body, summary, result, code] of [
  ['register', 'Register', 'Đăng ký và gửi OTP email', ref('OtpChallenge'), 202],
  ['login', 'Login', 'Đăng nhập mật khẩu, nhận challenge OTP', ref('OtpChallenge'), 200],
  ['verify-otp', 'VerifyOtp', 'Xác nhận OTP, nhận JWT', ref('Session'), 200],
  ['resend-otp', 'ResendOtp', 'Gửi lại OTP sau cooldown 60 giây', ref('OtpChallenge'), 200],
  ['refresh', 'Refresh', 'Đổi refresh token dùng một lần', ref('Session'), 200],
  ['logout', 'Refresh', 'Thu hồi phiên đăng nhập', {}, 200],
]) add('post', `/auth/${path}`, 'Xác thực', summary, { public: true, body, result, code });
add('post', '/auth/face-login', 'Khuôn mặt', 'Đăng nhập mặt và OTP', { public: true, body: 'FaceLogin',
  result: { anyOf: [ref('OtpChallenge'), ref('Session')] },
  description: 'Backend này trả challenge OTP. Một số bản API chung trả phiên trực tiếp; Flutter 1.3.2 hỗ trợ cả hai. Yêu cầu tài khoản active, email xác thực và mẫu đã đăng ký.' });
add('post', '/auth/face-unlock', 'Khuôn mặt', 'Đăng nhập mặt và khóa thiết bị, không OTP', { public: true, body: 'FaceUnlock', result: ref('Session'),
  description: 'Cần mẫu mặt và deviceKey tạo sau đăng nhập mật khẩu + OTP. Nhận diện ảnh 2D chưa kiểm tra người thật.' });
add('get', '/me', 'Hồ sơ', 'Xem tài khoản và vai trò hiện tại');
add('patch', '/me', 'Hồ sơ', 'Sửa tên, điện thoại, giới thiệu', { body: 'ProfilePatch' });
for (const [path, schema, tag, writeRole] of [
  ['employees', 'Employee', 'Nhân viên', 'Chỉ admin'],
  ['branches', 'Branch', 'Chi nhánh', 'Chỉ admin'],
  ['shifts', 'Shift', 'Ca làm', 'Admin hoặc manager trong chi nhánh'],
]) {
  add('get', `/${path}`, tag, 'Danh sách trong phạm vi quyền');
  add('get', `/${path}/{id}`, tag, 'Xem chi tiết trong phạm vi quyền');
  add('post', `/${path}`, tag, 'Tạo mới', { body: schema, code: 201, description: writeRole });
  add('patch', `/${path}/{id}`, tag, 'Cập nhật', { body: `${schema}Patch`, description: `${writeRole}. Ca đã có lịch sử không được đổi kế hoạch.` });
  add('delete', `/${path}/{id}`, tag, 'Xóa khi không có ràng buộc lịch sử', { description: writeRole });
}
add('get', '/attendance', 'Chấm công', 'Danh sách công theo quyền');
for (const action of ['check-in', 'check-out']) add('post', `/attendance/${action}`, 'Chấm công', action === 'check-in' ? 'Vào ca bằng GPS' : 'Ra ca bằng GPS',
  { body: 'Punch', code: action === 'check-in' ? 201 : 200,
    description: 'Phải là người được phân ca, đúng cửa sổ giờ, trong bán kính chi nhánh; khoảng cách + sai số GPS không vượt bán kính. Giờ do server ghi nhận.' });
add('get', '/corrections', 'Điều chỉnh công', 'Danh sách đơn theo quyền');
add('get', '/corrections/{id}', 'Điều chỉnh công', 'Chi tiết đơn');
add('post', '/corrections', 'Điều chỉnh công', 'Gửi đơn của mình', { body: 'Correction', code: 201,
  description: 'Cần ít nhất requestedCheckIn hoặc requestedCheckOut.' });
add('patch', '/corrections/{id}', 'Điều chỉnh công', 'Sửa hoặc duyệt/từ chối đơn', { body: 'CorrectionPatch',
  description: 'Người gửi sửa khi pending; không tự duyệt. Người duyệt chỉ gửi status và resolutionNote.' });
add('delete', '/corrections/{id}', 'Điều chỉnh công', 'Rút đơn pending của mình');
add('post', '/location-shares', 'Vị trí', 'Chia sẻ một vị trí có thời hạn', { body: 'LocationShare', code: 201 });
add('get', '/location-shares', 'Vị trí', 'Vị trí hiện được phép xem');
add('delete', '/location-shares/{id}', 'Vị trí', 'Dừng chia sẻ');
add('get', '/face/status', 'Khuôn mặt', 'Trạng thái mẫu mặt');
add('post', '/face/enroll', 'Khuôn mặt', 'Đăng ký hoặc thay mẫu mặt', { body: 'FaceEnroll', code: 201,
  description: 'enableQuickLogin=true bật khóa thiết bị sau mật khẩu + OTP. Ảnh 2D có thể bị giả mạo; chưa có liveness.' });
add('delete', '/face/enroll', 'Khuôn mặt', 'Xóa mẫu, thu hồi khóa và phiên mặt');
add('get', '/dashboard', 'Báo cáo', 'Dashboard theo vai trò');
add('get', '/reports/monthly', 'Báo cáo', 'Báo cáo tháng theo phạm vi quyền', { parameters: [
  query('month', { type: 'string', pattern: '^(19|20|21)\\d{2}-(0[1-9]|1[0-2])$', example: '2026-11' }, true),
  query('employeeId', uuid), query('branchId', uuid),
] });
add('get', '/handover-recipients', 'Bàn giao', 'Người nhận hợp lệ cùng chi nhánh');
add('get', '/handovers', 'Bàn giao', 'Danh sách bàn giao theo quyền');
add('get', '/handovers/{id}', 'Bàn giao', 'Chi tiết bàn giao');
add('get', '/handovers/{id}/revisions', 'Bàn giao', 'Lịch sử phiên bản bất biến');
add('post', '/handovers', 'Bàn giao', 'Tạo bàn giao ca của mình', { body: 'Handover', code: 201,
  description: 'Bản submitted cần 1–3 criticalFacts có trong bản gốc và bản dịch. Server không tự dịch văn bản.' });
add('patch', '/handovers/{id}', 'Bàn giao', 'Sửa hoặc xác nhận bàn giao theo phiên bản', { body: 'HandoverPatch',
  description: 'version là phiên bản hiện tại. Người nhận xác nhận acknowledged phải đánh dấu understood mọi mục và nhập factAnswers. Người gửi sửa sẽ yêu cầu xác nhận lại.' });
add('delete', '/handovers/{id}', 'Bàn giao', 'Xóa bản nháp của mình');
add('get', '/chat/contacts', 'Chat realtime', 'Danh bạ người nhận hợp lệ');
const peerId = query('peerId', uuid, true);
const cursor = { type: 'string', pattern: '^\\d{1,19}$', description: 'Cursor bigint dạng chuỗi, tối đa 9223372036854775807.' };
add('get', '/chat/messages', 'Chat realtime', 'Lịch sử hoặc đồng bộ bù', { parameters: [peerId,
  query('afterId', cursor), query('beforeId', cursor), query('limit', { type: 'integer', minimum: 1, maximum: 100, default: 50 })],
  description: 'Không gửi đồng thời afterId và beforeId. SSE chỉ báo cursor; tải nội dung qua route này.' });
const send = add('post', '/chat/messages', 'Chat realtime', 'Gửi tin nhắn, chống trùng UUID', { body: 'ChatMessage', code: 201,
  description: 'Gửi lại cùng clientMessageId và nội dung trả tin cũ (200). ML Kit dịch trên Flutter; backend giữ bản gốc, không có endpoint giả lập dịch.' });
send.responses['200'] = jsonResponse('UUID đã gửi, trả tin nhắn hiện có');
const stream = add('get', '/chat/stream', 'Chat realtime', 'SSE thông báo tin mới', { parameters: [peerId],
  description: 'Header Bearer bắt buộc; tối đa 5 stream/người, 200 stream/process. Sự kiện ready/messages/session_expired/access_revoked/unavailable. Swagger giữ kết nối mở cho đến khi hủy.' });
stream.responses['200'] = { description: 'Luồng Server-Sent Events', content: { 'text/event-stream': { schema: { type: 'string' } } } };
add('get', '/notifications/status', 'Thông báo', 'Trạng thái cấu hình FCM');
add('post', '/notification-devices', 'Thông báo', 'Liên kết Firebase installation với phiên', { body: 'NotificationDevice', code: 201,
  description: 'Tùy chọn; cần cấu hình Firebase backend và Android cùng project. Thiếu cấu hình trả 503 PUSH_DISABLED.' });
add('delete', '/notification-devices/{id}', 'Thông báo', 'Xóa liên kết thuộc phiên hiện tại');

export const openapi = {
  openapi: '3.1.0', info: { title: 'NguyenHoangVu — Attendance API', version: '1.3.3',
    description: 'Nguyễn Hoàng Vũ — 2380602586. Backend Node.js/Express + PostgreSQL cho Flutter mobile.\n\nBắt đầu bằng GET /health (không cần đăng nhập). POST /auth/login gửi OTP email; POST /auth/verify-otp trả data.accessToken. Nhấn Authorize và chỉ dán accessToken; Swagger tự thêm Bearer. Tài khoản phải active để dùng chức năng nghiệp vụ.\n\nTài liệu mô tả source backend này. API chung có thể chưa deploy migration 005–006/chat/hồ sơ/khóa mặt thiết bị. Phiên dịch realtime chưa nghiệm thu trên app public; dịch ML Kit thuộc Flutter. Không có mật khẩu, OTP hoặc tài khoản mặc định trong tài liệu.' },
  servers: [{ url: '/v1', description: 'API cùng host với Swagger' }],
  security: [{ bearerAuth: [] }], paths,
  components: { schemas, securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' } },
    responses: { Error: { description: 'Lỗi xác thực, quyền, dữ liệu, cooldown hoặc dịch vụ.', content: { 'application/json': { schema: {
      type: 'object', required: ['error'], properties: { error: { type: 'object', required: ['code', 'message'],
        properties: { code: { type: 'string' }, message: { type: 'string' }, details: {} } } },
    } } } } } },
};
