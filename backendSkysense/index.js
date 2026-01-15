// index.js
try {
  require("dotenv").config();
} catch (_) {}

const express = require("express");
const axios = require("axios");
const WebSocket = require("ws");
const cors = require("cors");
const mqtt = require("mqtt");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");

const {
  insertData,
  selectAvgData,

  // users
  findUserByEmail,
  createUser,
  getPendingUsers,
  approveUser,
  getUserById,
  getAllUsers,
  setUserStatus,

  // logs (admin)
  listSensorLogs,
  countSensorLogs,
  deleteSensorLogById,
  getSensorLogsForExport,

  // admin users CRUD
  adminCreateUser,
  adminUpdateUser,
  adminUpdateUserPassword,
  adminDeleteUser,

  // chat
  getAnyAdminUser,
  getOrCreateThread,
  listThreadsForAdmin,
  listMessages,
  insertMessage,
} = require("./database/connection");

const app = express();
app.use(cors());
app.use(express.json());

// ================== PORT / HOST ==================
const HTTP_PORT = Number(process.env.HTTP_PORT || 3000);
const WS_PORT = Number(process.env.WS_PORT || 3001);
const CHAT_WS_PORT = Number(process.env.CHAT_WS_PORT || 3002); // ✅ CHAT WS
const HTTP_HOST = process.env.HTTP_HOST || "0.0.0.0";

// ================== JWT SECRET ==================
const JWT_SECRET = process.env.JWT_SECRET || "skysense_secret_change_me";

// ================== AUTH MIDDLEWARE ==================
function auth(req, res, next) {
  const h = req.headers.authorization || "";
  const token = h.startsWith("Bearer ") ? h.slice(7) : null;
  if (!token) return res.status(401).json({ error: "Token required" });

  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch (e) {
    return res.status(401).json({ error: "Invalid token" });
  }
}

function adminOnly(req, res, next) {
  if (req.user?.role !== "admin") return res.status(403).json({ error: "Admin only" });
  next();
}

// ================== ECOWITT CONFIG ==================
const ECOWITT_URL = "https://api.ecowitt.net/api/v3/device/real_time";
const PARAMS = {
  application_key: process.env.ECOWITT_APP_KEY || "9C06F529D042D05D81C2DED02284341C",
  api_key: process.env.ECOWITT_API_KEY || "03ddf1de-7434-4444-a495-01de8529cb5c",
  mac: process.env.ECOWITT_MAC || "48:E7:29:5F:05:68",
  call_back: "all",
};

// ================== MQTT ==================
const MQTT_BROKER = process.env.MQTT_BROKER || "mqtt://broker.hivemq.com:1883";
const MQTT_TOPIC = process.env.MQTT_TOPIC || "ecowitt/weather";

const mqttClient = mqtt.connect(MQTT_BROKER, {
  reconnectPeriod: 3000,
  connectTimeout: 10_000,
  keepalive: 60,
});

mqttClient.on("connect", () => console.log("🟢 MQTT connected:", MQTT_BROKER));
mqttClient.on("reconnect", () => console.log("🟡 MQTT reconnecting..."));
mqttClient.on("close", () => console.log("🟠 MQTT closed"));
mqttClient.on("error", (err) => console.error("🔴 MQTT error:", err.message));

// ================== WEBSOCKET SENSOR REALTIME ==================
const wss = new WebSocket.Server({ port: WS_PORT });
wss.on("connection", (ws) => {
  console.log("📡 Realtime WS client connected (sensor)");
  ws.on("close", () => console.log("❌ Realtime WS client disconnected (sensor)"));
});

// ================== WEBSOCKET CHAT ==================
const chatWss = new WebSocket.Server({ port: CHAT_WS_PORT });

// map userId -> Set(ws)
const chatClients = new Map();

function addClient(userId, ws) {
  if (!chatClients.has(userId)) chatClients.set(userId, new Set());
  chatClients.get(userId).add(ws);
}

function removeClient(userId, ws) {
  const set = chatClients.get(userId);
  if (!set) return;
  set.delete(ws);
  if (set.size === 0) chatClients.delete(userId);
}

function sendToUser(userId, payload) {
  const set = chatClients.get(userId);
  if (!set) return;
  const msg = JSON.stringify(payload);
  for (const ws of set) {
    if (ws.readyState === WebSocket.OPEN) ws.send(msg);
  }
}

chatWss.on("connection", (ws, req) => {
  // token via query: ws://IP:3002?token=xxxxx
  try {
    const url = new URL(req.url, "http://localhost");
    const token = url.searchParams.get("token");
    if (!token) {
      ws.close(1008, "Token required");
      return;
    }

    const user = jwt.verify(token, JWT_SECRET);
    ws.user = user;
    addClient(user.id, ws);

    ws.send(JSON.stringify({ type: "hello", userId: user.id, role: user.role }));

    ws.on("message", async (raw) => {
      try {
        const data = JSON.parse(String(raw || "{}"));

        if (data.type === "send_message") {
          const threadId = Number(data.threadId);
          const text = String(data.message || "").trim();
          const receiverId = Number(data.receiverId);

          if (!threadId || !text || !receiverId) {
            ws.send(JSON.stringify({ type: "error", message: "Invalid payload" }));
            return;
          }

          const saved = await insertMessage({
            threadId,
            senderId: user.id,
            senderRole: user.role,
            message: text,
          });

          const payload = {
            type: "new_message",
            threadId,
            message: {
              id: saved.id,
              thread_id: threadId,
              sender_id: user.id,
              sender_role: user.role,
              message: text,
              created_at: new Date().toISOString(),
            },
          };

          // kirim ke pengirim dan penerima realtime
          sendToUser(user.id, payload);
          sendToUser(receiverId, payload);
        }
      } catch (err) {
        ws.send(JSON.stringify({ type: "error", message: "Bad JSON" }));
      }
    });

    ws.on("close", () => removeClient(user.id, ws));
  } catch (e) {
    ws.close(1008, "Invalid token");
  }
});

// ============================================================
// ====================== AUTH REGISTER =======================
// ============================================================
app.post("/auth/register", async (req, res) => {
  try {
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ error: "name, email, password wajib diisi" });
    }

    const existing = await findUserByEmail(email);
    if (existing) return res.status(409).json({ error: "Email sudah terdaftar" });

    const password_hash = await bcrypt.hash(password, 10);

    const created = await createUser({
      name,
      email,
      password_hash,
      role: "client",
      status: "pending",
    });

    return res.status(201).json({
      message: "Register berhasil. Tunggu approval admin.",
      user: { id: created.id, name, email, role: "client", status: "pending" },
    });
  } catch (e) {
    console.error("REGISTER ERROR:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

// ============================================================
// ======================== AUTH LOGIN ========================
// ============================================================
app.post("/auth/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: "email & password wajib diisi" });

    const user = await findUserByEmail(email);
    if (!user) return res.status(401).json({ error: "Email/password salah" });

    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) return res.status(401).json({ error: "Email/password salah" });

    // blok client yang belum approved
    if (user.role === "client" && user.status !== "approved") {
      return res.status(403).json({ error: "Akun belum di-approve admin" });
    }

    const token = jwt.sign({ id: user.id, role: user.role, status: user.status }, JWT_SECRET, {
      expiresIn: "7d",
    });

    return res.json({
      token,
      user: { id: user.id, name: user.name, email: user.email, role: user.role, status: user.status },
    });
  } catch (e) {
    console.error("LOGIN ERROR:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

// ============================================================
// =========================== /ME ============================
// ============================================================
app.get("/me", auth, async (req, res) => {
  try {
    const user = await getUserById(req.user.id);
    if (!user) return res.status(404).json({ error: "User not found" });

    return res.json({
      user: { id: user.id, name: user.name, email: user.email, role: user.role, status: user.status },
    });
  } catch (e) {
    console.error("ME ERROR:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

// ============================================================
// ===================== ADMIN USERS ==========================
// ============================================================
app.get("/admin/pending-users", auth, adminOnly, async (req, res) => {
  try {
    const users = await getPendingUsers();
    return res.json(users);
  } catch (e) {
    console.error("PENDING USERS ERROR:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

// list users
// GET /admin/users?status=approved&role=client
app.get("/admin/users", auth, adminOnly, async (req, res) => {
  try {
    const status = req.query.status ? String(req.query.status) : undefined;
    const role = req.query.role ? String(req.query.role) : undefined;

    const users = await getAllUsers({ status, role });
    return res.json(users);
  } catch (e) {
    console.error("GET USERS ERROR:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

// set user status
app.patch("/admin/users/:id/status", auth, adminOnly, async (req, res) => {
  try {
    const id = Number(req.params.id);
    const status = req.body?.status ? String(req.body.status) : "";
    if (!status) return res.status(400).json({ error: "status is required" });

    const result = await setUserStatus(id, status);
    if (result.affectedRows === 0) return res.status(404).json({ error: "User not found" });

    return res.json({ message: "Status updated", id, status });
  } catch (e) {
    console.error("SET STATUS ERROR:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

// ✅ CREATE USER (admin)
app.post("/admin/users", auth, adminOnly, async (req, res) => {
  try {
    const { name, email, password, role, status } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ error: "name, email, password wajib diisi" });
    }

    const exists = await findUserByEmail(email);
    if (exists) return res.status(409).json({ error: "Email sudah terdaftar" });

    const password_hash = await bcrypt.hash(password, 10);

    const created = await adminCreateUser({
      name,
      email,
      password_hash,
      role: role || "client",
      status: status || "approved",
    });

    return res.status(201).json({
      message: "User dibuat",
      user: { id: created.id, name, email, role: role || "client", status: status || "approved" },
    });
  } catch (e) {
    console.error("ADMIN CREATE USER ERROR:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

// ✅ UPDATE USER (admin)
app.patch("/admin/users/:id", auth, adminOnly, async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!id) return res.status(400).json({ error: "Invalid id" });

    const { name, email, role, status, password } = req.body || {};

    if (req.user.id === id && role && role !== "admin") {
      return res.status(400).json({ error: "Tidak boleh menurunkan role admin sendiri" });
    }

    if (email) {
      const exists = await findUserByEmail(email);
      if (exists && exists.id !== id) return res.status(409).json({ error: "Email sudah dipakai user lain" });
    }

    const result = await adminUpdateUser(id, { name, email, role, status });

    if (password && String(password).trim().length >= 4) {
      const password_hash = await bcrypt.hash(String(password), 10);
      await adminUpdateUserPassword(id, password_hash);
    }

    if ((result?.affectedRows ?? 0) === 0 && !password) {
      return res.status(400).json({ error: "Tidak ada field yang diupdate" });
    }

    return res.json({ message: "User diupdate", id });
  } catch (e) {
    console.error("ADMIN UPDATE USER ERROR:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

// ✅ DELETE USER (admin)
app.delete("/admin/users/:id", auth, adminOnly, async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!id) return res.status(400).json({ error: "Invalid id" });

    if (req.user.id === id) {
      return res.status(400).json({ error: "Tidak boleh menghapus akun sendiri" });
    }

    const result = await adminDeleteUser(id);
    if (result.affectedRows === 0) return res.status(404).json({ error: "User not found" });

    return res.json({ message: "User dihapus", id });
  } catch (e) {
    console.error("ADMIN DELETE USER ERROR:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

// ============================================================
// =================== ADMIN SENSOR LOGS =======================
// ============================================================

// SHOW logs (admin) + pagination info
app.get("/admin/sensor-logs", auth, adminOnly, async (req, res) => {
  try {
    const dateFrom = req.query.dateFrom ? String(req.query.dateFrom) : undefined;
    const dateTo = req.query.dateTo ? String(req.query.dateTo) : undefined;
    const limit = req.query.limit ? Number(req.query.limit) : 50;
    const offset = req.query.offset ? Number(req.query.offset) : 0;

    const [rows, total] = await Promise.all([
      listSensorLogs({ dateFrom, dateTo, limit, offset }),
      countSensorLogs({ dateFrom, dateTo }),
    ]);

    return res.json({ total, limit, offset, rows });
  } catch (e) {
    console.error("ADMIN SENSOR LOGS ERROR:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

// DELETE log tertentu
app.delete("/admin/sensor-logs/:id", auth, adminOnly, async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!id) return res.status(400).json({ error: "Invalid id" });

    const result = await deleteSensorLogById(id);
    if (result.affectedRows === 0) return res.status(404).json({ error: "Log not found" });

    return res.json({ message: "Log deleted", id });
  } catch (e) {
    console.error("DELETE SENSOR LOG ERROR:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

// EXPORT CSV
app.get("/admin/sensor-logs/export.csv", auth, adminOnly, async (req, res) => {
  try {
    const dateFrom = req.query.dateFrom ? String(req.query.dateFrom) : undefined;
    const dateTo = req.query.dateTo ? String(req.query.dateTo) : undefined;

    const rows = await getSensorLogsForExport({ dateFrom, dateTo });

    const escapeCsv = (v) => {
      if (v === null || v === undefined) return "";
      const s = String(v);
      if (/[",\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
      return s;
    };

    const header = ["id", "wind_speed", "temperature", "wind_degree", "humidity", "ldr", "timestamp"];
    const lines = [header.join(",")];

    for (const r of rows) {
      lines.push(
        [
          escapeCsv(r.id),
          escapeCsv(r.wind_speed),
          escapeCsv(r.temperature),
          escapeCsv(r.wind_degree),
          escapeCsv(r.humidity),
          escapeCsv(r.ldr),
          escapeCsv(r.timestamp),
        ].join(",")
      );
    }

    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader("Content-Disposition", `attachment; filename="sensor_logs.csv"`);
    return res.status(200).send(lines.join("\n"));
  } catch (e) {
    console.error("EXPORT CSV ERROR:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

// ============================================================
// =========================== CHAT ===========================
// ============================================================

// Client: get thread (auto create) dengan admin
app.get("/chat/thread", auth, async (req, res) => {
  try {
    const me = req.user;
    if (me.role !== "client") return res.status(403).json({ error: "Client only" });

    const admin = await getAnyAdminUser();
    if (!admin) return res.status(500).json({ error: "Tidak ada admin di database" });

    const thread = await getOrCreateThread(me.id, admin.id);
    return res.json({ threadId: thread.id, admin });
  } catch (e) {
    console.error("CHAT THREAD ERROR:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

// Admin: list threads
app.get("/admin/chat/threads", auth, adminOnly, async (req, res) => {
  try {
    const rows = await listThreadsForAdmin(req.user.id);
    return res.json(rows);
  } catch (e) {
    console.error("ADMIN CHAT THREADS ERROR:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

// Get messages by thread
app.get("/chat/threads/:id/messages", auth, async (req, res) => {
  try {
    const threadId = Number(req.params.id);
    const limit = req.query.limit ? Number(req.query.limit) : 50;
    const beforeId = req.query.beforeId ? Number(req.query.beforeId) : null;

    const rows = await listMessages(threadId, limit, beforeId);
    return res.json(rows);
  } catch (e) {
    console.error("CHAT MESSAGES ERROR:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

// ============================================================
// ================== SENSOR: INSERT & AVG =====================
// ============================================================
app.post("/insert", (req, res) => {
  const { windSpeed, temperature, windDegree, humidity, ldr } = req.body;

  const isNil = (v) => v === undefined || v === null;
  if ([windSpeed, temperature, windDegree, humidity, ldr].some(isNil)) {
    return res.status(400).json({ error: "All fields are required!" });
  }

  insertData(windSpeed, temperature, windDegree, humidity, ldr);
  return res.status(200).json({ message: "Data inserted successfully!" });
});

app.get("/avgdata", (req, res) => {
  selectAvgData(res);
});

// ============================================================
// ================== GLOBAL PAYLOAD ==================
// ============================================================
let lastPayload = null;

// ================== FETCH ECOWITT (REALTIME) ==================
async function fetchEcowitt() {
  try {
    const r = await axios.get(ECOWITT_URL, { params: PARAMS, timeout: 10_000 });
    const data = r.data?.data;
    if (!data) return;

    const payload = {
      temperature:
        data.outdoor?.temperature?.value != null
          ? ((parseFloat(data.outdoor.temperature.value) - 32) * 5) / 9
          : 0,
      humidity: data.outdoor?.humidity?.value != null ? parseFloat(data.outdoor.humidity.value) : 0,
      windSpeed: data.wind?.wind_speed?.value != null ? parseFloat(data.wind.wind_speed.value) : 0,
      windDirection: data.wind?.wind_direction?.value != null ? parseFloat(data.wind.wind_direction.value) : 0,
      rainRate:
        data.rainfall?.rain_rate?.value != null ? parseFloat(data.rainfall.rain_rate.value) * 25.4 : 0,
      light: data?.solar_and_uvi?.solar?.value != null ? parseFloat(data.solar_and_uvi.solar.value) : 0,
      timestamp: Date.now(),
    };

    lastPayload = payload;

    // WS broadcast sensor
    wss.clients.forEach((c) => {
      if (c.readyState === WebSocket.OPEN) c.send(JSON.stringify(payload));
    });

    // MQTT publish
    if (mqttClient.connected) mqttClient.publish(MQTT_TOPIC, JSON.stringify(payload));

    console.log("📡 Realtime sent:", payload);
  } catch (err) {
    console.error("❌ Ecowitt error:", err.message);
  }
}

// insert DB per jam (pakai data terakhir)
setInterval(() => {
  if (!lastPayload) return;

  insertData(
    lastPayload.windSpeed ?? 0,
    lastPayload.temperature ?? 0,
    lastPayload.windDirection ?? 0,
    lastPayload.humidity ?? 0,
    lastPayload.light ?? 0
  );

  console.log("💾 Data inserted to DB (1 hour interval)");
}, 60 * 60 * 1000);

// polling realtime
setInterval(fetchEcowitt, 5000);

app.get("/", (req, res) => res.send("🚀 SkySense Server Running"));

app.listen(HTTP_PORT, HTTP_HOST, () => {
  console.log(`🌐 HTTP      : http://${HTTP_HOST}:${HTTP_PORT}`);
  console.log(`📡 WS Sensor : ws://${HTTP_HOST}:${WS_PORT}`);
  console.log(`💬 WS Chat   : ws://${HTTP_HOST}:${CHAT_WS_PORT}`);
  console.log(`📨 MQTT      : ${MQTT_TOPIC}`);
});
