// database/connection.js
const mysql = require("mysql");

const db = mysql.createConnection({
  host: "localhost",
  user: "root",
  password: "",
  database: "skysense",
});

db.connect((err) => {
  if (err) console.error("❌ MySQL error:", err);
  else console.log("🟢 MySQL connected");
});

// ===================== SENSOR (INSERT) =====================
function insertData(windSpeed, temperature, windDegree, humidity, ldr) {
  const sql = `
    INSERT INTO data_sensor
      (wind_speed, temperature, wind_degree, humidity, ldr, timestamp)
    VALUES
      (?, ?, ?, ?, ?, NOW())
  `;

  db.query(sql, [windSpeed, temperature, windDegree, humidity, ldr], (err, result) => {
    if (err) return console.error("❌ Insert error:", err);
    console.log("✅ Data inserted successfully: ID", result.insertId);
  });
}

// ===================== SENSOR (AVG) =====================
function selectAvgData(res) {
  const sql = `
    SELECT
      DATE(timestamp) AS tanggal,
      AVG(wind_speed) AS avg_wind_speed,
      MAX(wind_speed) AS max_wind_speed,
      MIN(wind_speed) AS min_wind_speed,
      AVG(temperature) AS avg_temperature,
      MAX(temperature) AS max_temperature,
      MIN(temperature) AS min_temperature,
      AVG(humidity) AS avg_humidity,
      MAX(humidity) AS max_humidity,
      MIN(humidity) AS min_humidity,
      AVG(ldr) AS avg_ldr,
      MAX(ldr) AS max_ldr,
      MIN(ldr) AS min_ldr
    FROM data_sensor
    GROUP BY DATE(timestamp)
    ORDER BY DATE(timestamp) DESC;
  `;

  db.query(sql, (err, results) => {
    if (err) {
      console.error("❌ Select error:", err);
      return res.status(500).json({ error: "Database error" });
    }
    res.status(200).json(results);
  });
}

// ===================== SENSOR LOGS (ADMIN) =====================
// filter pakai dateFrom/dateTo (string datetime)
function listSensorLogs({ dateFrom, dateTo, limit = 50, offset = 0 } = {}) {
  return new Promise((resolve, reject) => {
    let sql = `
      SELECT
        id,
        wind_speed AS windSpeed,
        temperature,
        wind_degree AS windDirection,
        humidity,
        ldr AS light,
        timestamp AS createdAt
      FROM data_sensor
    `;

    const params = [];
    const where = [];

    if (dateFrom) {
      where.push("timestamp >= ?");
      params.push(dateFrom);
    }
    if (dateTo) {
      where.push("timestamp <= ?");
      params.push(dateTo);
    }
    if (where.length) sql += " WHERE " + where.join(" AND ");

    sql += " ORDER BY timestamp DESC LIMIT ? OFFSET ?";
    params.push(Number(limit));
    params.push(Number(offset));

    db.query(sql, params, (err, rows) => {
      if (err) return reject(err);
      resolve(rows);
    });
  });
}

function countSensorLogs({ dateFrom, dateTo } = {}) {
  return new Promise((resolve, reject) => {
    let sql = `SELECT COUNT(*) AS total FROM data_sensor`;
    const params = [];
    const where = [];

    if (dateFrom) {
      where.push("timestamp >= ?");
      params.push(dateFrom);
    }
    if (dateTo) {
      where.push("timestamp <= ?");
      params.push(dateTo);
    }
    if (where.length) sql += " WHERE " + where.join(" AND ");

    db.query(sql, params, (err, rows) => {
      if (err) return reject(err);
      resolve(rows?.[0]?.total ?? 0);
    });
  });
}

function deleteSensorLogById(id) {
  return new Promise((resolve, reject) => {
    const sql = `DELETE FROM data_sensor WHERE id = ?`;
    db.query(sql, [id], (err, result) => {
      if (err) return reject(err);
      resolve(result);
    });
  });
}

// ✅ export raw (kolom asli DB) supaya CSV rapi
function getSensorLogsForExport({ dateFrom, dateTo } = {}) {
  return new Promise((resolve, reject) => {
    let sql = `
      SELECT
        id,
        wind_speed,
        temperature,
        wind_degree,
        humidity,
        ldr,
        timestamp
      FROM data_sensor
    `;

    const params = [];
    const where = [];

    if (dateFrom) {
      where.push("timestamp >= ?");
      params.push(dateFrom);
    }
    if (dateTo) {
      where.push("timestamp <= ?");
      params.push(dateTo);
    }
    if (where.length) sql += " WHERE " + where.join(" AND ");

    sql += " ORDER BY timestamp DESC";

    db.query(sql, params, (err, rows) => {
      if (err) return reject(err);
      resolve(rows);
    });
  });
}

// ===================== USERS =====================
function findUserByEmail(email) {
  return new Promise((resolve, reject) => {
    db.query("SELECT * FROM users WHERE email = ? LIMIT 1", [email], (err, rows) => {
      if (err) return reject(err);
      resolve(rows[0] || null);
    });
  });
}

function getUserById(id) {
  return new Promise((resolve, reject) => {
    db.query("SELECT * FROM users WHERE id = ? LIMIT 1", [id], (err, rows) => {
      if (err) return reject(err);
      resolve(rows[0] || null);
    });
  });
}

function createUser({ name, email, password_hash, role = "client", status = "pending" }) {
  return new Promise((resolve, reject) => {
    const sql = `
      INSERT INTO users (name, email, password_hash, role, status)
      VALUES (?, ?, ?, ?, ?)
    `;
    db.query(sql, [name, email, password_hash, role, status], (err, result) => {
      if (err) return reject(err);
      resolve({ id: result.insertId });
    });
  });
}

function getPendingUsers() {
  return new Promise((resolve, reject) => {
    const sql = `
      SELECT id, name, email, role, status, created_at
      FROM users
      WHERE role = 'client' AND status = 'pending'
      ORDER BY created_at DESC
    `;
    db.query(sql, (err, rows) => {
      if (err) return reject(err);
      resolve(rows);
    });
  });
}

function approveUser(userId) {
  return new Promise((resolve, reject) => {
    const sql = `
      UPDATE users
      SET status = 'approved'
      WHERE id = ? AND role = 'client'
    `;
    db.query(sql, [userId], (err, result) => {
      if (err) return reject(err);
      resolve(result);
    });
  });
}

function getAllUsers({ status, role } = {}) {
  return new Promise((resolve, reject) => {
    let sql = `
      SELECT id, name, email, role, status, created_at
      FROM users
    `;
    const params = [];
    const where = [];

    if (status) {
      where.push("status = ?");
      params.push(status);
    }
    if (role) {
      where.push("role = ?");
      params.push(role);
    }
    if (where.length) sql += " WHERE " + where.join(" AND ");

    sql += " ORDER BY created_at DESC";

    db.query(sql, params, (err, rows) => {
      if (err) return reject(err);
      resolve(rows);
    });
  });
}

function setUserStatus(userId, status) {
  return new Promise((resolve, reject) => {
    const sql = `
      UPDATE users
      SET status = ?
      WHERE id = ?
    `;
    db.query(sql, [status, userId], (err, result) => {
      if (err) return reject(err);
      resolve(result);
    });
  });
}
// ===== ADMIN: USERS CRUD =====

// create user by admin
function adminCreateUser({ name, email, password_hash, role = "client", status = "approved" }) {
  return new Promise((resolve, reject) => {
    const sql = `
      INSERT INTO users (name, email, password_hash, role, status)
      VALUES (?, ?, ?, ?, ?)
    `;
    db.query(sql, [name, email, password_hash, role, status], (err, result) => {
      if (err) return reject(err);
      resolve({ id: result.insertId });
    });
  });
}

// update user basic fields (name/email/role/status)
function adminUpdateUser(id, { name, email, role, status }) {
  return new Promise((resolve, reject) => {
    const sets = [];
    const params = [];

    if (name !== undefined) { sets.push("name = ?"); params.push(name); }
    if (email !== undefined) { sets.push("email = ?"); params.push(email); }
    if (role !== undefined) { sets.push("role = ?"); params.push(role); }
    if (status !== undefined) { sets.push("status = ?"); params.push(status); }

    if (!sets.length) return resolve({ affectedRows: 0 });

    const sql = `UPDATE users SET ${sets.join(", ")} WHERE id = ?`;
    params.push(id);

    db.query(sql, params, (err, result) => {
      if (err) return reject(err);
      resolve(result);
    });
  });
}

// update password
function adminUpdateUserPassword(id, password_hash) {
  return new Promise((resolve, reject) => {
    const sql = `UPDATE users SET password_hash = ? WHERE id = ?`;
    db.query(sql, [password_hash, id], (err, result) => {
      if (err) return reject(err);
      resolve(result);
    });
  });
}

// delete user
function adminDeleteUser(id) {
  return new Promise((resolve, reject) => {
    const sql = `DELETE FROM users WHERE id = ?`;
    db.query(sql, [id], (err, result) => {
      if (err) return reject(err);
      resolve(result);
    });
  });
}
// ===================== CHAT =====================

// cari admin pertama (paling gampang) — kalau kamu punya table admin banyak,
// ini bisa kamu ganti logic-nya (misal pilih admin tertentu)
function getAnyAdminUser() {
  return new Promise((resolve, reject) => {
    db.query("SELECT id, name, email FROM users WHERE role='admin' LIMIT 1", (err, rows) => {
      if (err) return reject(err);
      resolve(rows?.[0] || null);
    });
  });
}

// buat / ambil thread untuk pasangan client-admin
function getOrCreateThread(clientId, adminId) {
  return new Promise((resolve, reject) => {
    const findSql = `SELECT * FROM chat_threads WHERE client_id=? AND admin_id=? LIMIT 1`;
    db.query(findSql, [clientId, adminId], (err, rows) => {
      if (err) return reject(err);
      if (rows?.[0]) return resolve(rows[0]);

      const insSql = `INSERT INTO chat_threads (client_id, admin_id) VALUES (?, ?)`;
      db.query(insSql, [clientId, adminId], (err2, result) => {
        if (err2) return reject(err2);
        resolve({ id: result.insertId, client_id: clientId, admin_id: adminId });
      });
    });
  });
}

// list thread untuk admin (lihat daftar client yang chat)
function listThreadsForAdmin(adminId) {
  return new Promise((resolve, reject) => {
    const sql = `
      SELECT
        t.id,
        t.client_id,
        u.name AS client_name,
        u.email AS client_email,
        t.updated_at,
        (
          SELECT m.message
          FROM chat_messages m
          WHERE m.thread_id = t.id
          ORDER BY m.created_at DESC
          LIMIT 1
        ) AS last_message
      FROM chat_threads t
      JOIN users u ON u.id = t.client_id
      WHERE t.admin_id = ?
      ORDER BY t.updated_at DESC
    `;
    db.query(sql, [adminId], (err, rows) => {
      if (err) return reject(err);
      resolve(rows || []);
    });
  });
}

// ambil messages per thread
function listMessages(threadId, limit = 50, beforeId = null) {
  return new Promise((resolve, reject) => {
    let sql = `
      SELECT id, thread_id, sender_id, sender_role, message, created_at
      FROM chat_messages
      WHERE thread_id = ?
    `;
    const params = [threadId];

    if (beforeId) {
      sql += ` AND id < ?`;
      params.push(beforeId);
    }

    sql += ` ORDER BY id DESC LIMIT ?`;
    params.push(Number(limit));

    db.query(sql, params, (err, rows) => {
      if (err) return reject(err);
      // balikkan urutan naik biar enak di UI chat
      resolve((rows || []).reverse());
    });
  });
}

// insert message
function insertMessage({ threadId, senderId, senderRole, message }) {
  return new Promise((resolve, reject) => {
    const sql = `
      INSERT INTO chat_messages (thread_id, sender_id, sender_role, message)
      VALUES (?, ?, ?, ?)
    `;
    db.query(sql, [threadId, senderId, senderRole, message], (err, result) => {
      if (err) return reject(err);

      // update updated_at thread
      db.query(`UPDATE chat_threads SET updated_at = NOW() WHERE id = ?`, [threadId], () => {});

      resolve({
        id: result.insertId,
        thread_id: threadId,
        sender_id: senderId,
        sender_role: senderRole,
        message,
      });
    });
  });
}



module.exports = {
  db,

  // sensor
  insertData,
  selectAvgData,

  // logs admin
  listSensorLogs,
  countSensorLogs,
  deleteSensorLogById,
  getSensorLogsForExport,

  // users
  findUserByEmail,
  getUserById,
  createUser,
  getPendingUsers,
  approveUser,
  getAllUsers,
  setUserStatus,

  // ✅ admin users CRUD
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

};
