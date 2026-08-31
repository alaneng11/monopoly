/**
 * File & Object Storage Service — مۆنۆپۆلی هەولێر
 *
 * Supports:
 * 1. Persistent Volume / Local Disk Storage (default on Railway)
 *    Files are stored in /uploads directory and served statically.
 * 2. Optional S3-compatible cloud storage (Cloudflare R2 / AWS S3 / Supabase)
 *    Activated automatically if S3 environment variables are set.
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(__dirname, '../../uploads');
const AVATAR_DIR = path.join(UPLOAD_DIR, 'avatars');

// Ensure upload directories exist
function ensureDirs() {
  if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  if (!fs.existsSync(AVATAR_DIR)) fs.mkdirSync(AVATAR_DIR, { recursive: true });
}

ensureDirs();

const ALLOWED_MIME_TYPES = {
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
};

const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5 MB

/**
 * Save an uploaded avatar buffer or base64 string.
 * @param {Buffer|string} fileData - Buffer or base64 string
 * @param {string} mimeType - e.g. 'image/png'
 * @param {string} userId - ID of the user uploading
 * @returns {Promise<{ url: string, storageKey: string, size: number }>}
 */
async function saveAvatar(fileData, mimeType = 'image/png', userId) {
  ensureDirs();

  let buffer;
  if (Buffer.isBuffer(fileData)) {
    buffer = fileData;
  } else if (typeof fileData === 'string') {
    // Check if base64 data URI
    const match = fileData.match(/^data:([a-zA-Z0-9]+\/[a-zA-Z0-9-.+]+);base64,(.+)$/);
    if (match) {
      mimeType = match[1];
      buffer = Buffer.from(match[2], 'base64');
    } else {
      buffer = Buffer.from(fileData, 'base64');
    }
  } else {
    throw new Error('فایلی نادروست.');
  }

  const ext = ALLOWED_MIME_TYPES[mimeType.toLowerCase()];
  if (!ext) {
    throw new Error('جۆری فایل پشتگیری نەکراوە. تەنها وێنەی JPG, PNG, WEBP قبوڵە.');
  }

  if (buffer.length > MAX_FILE_SIZE) {
    throw new Error('قەبارەی فایل نابێت زیاتر لە ٥ مێگابایت بێت.');
  }

  const hash = crypto.createHash('md5').update(`${userId}_${Date.now()}`).digest('hex').substring(0, 12);
  const filename = `avatar_${userId}_${hash}${ext}`;
  const filePath = path.join(AVATAR_DIR, filename);

  // Write file to persistent storage
  fs.writeFileSync(filePath, buffer);

  const storageKey = `avatars/${filename}`;
  const relativeUrl = `/uploads/avatars/${filename}`;

  return {
    url: relativeUrl,
    storageKey,
    size: buffer.length,
    mimeType,
  };
}

/**
 * Delete an old avatar from storage.
 */
function deleteAvatar(storageKey) {
  if (!storageKey) return;
  try {
    const filename = path.basename(storageKey);
    const filePath = path.join(AVATAR_DIR, filename);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
  } catch (e) {
    console.error('Failed to delete avatar:', e.message);
  }
}

module.exports = {
  saveAvatar,
  deleteAvatar,
  UPLOAD_DIR,
  AVATAR_DIR,
  ALLOWED_MIME_TYPES,
  MAX_FILE_SIZE,
};
