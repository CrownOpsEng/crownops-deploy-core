from __future__ import annotations

import base64
import hashlib
import json
import os
from urllib.parse import quote, unquote
from typing import Any

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC


SETUP_URI_BASE = "obsidian://setuplivesync?settings="
SETUP_URI_ITERATIONS = 100_000
DEFAULT_LIVESYNC_SETTINGS: dict[str, Any] = {
    "syncOnStart": True,
    "gcDelay": 0,
    "periodicReplication": True,
    "syncOnFileOpen": True,
    "encrypt": True,
    "usePathObfuscation": True,
    "batchSave": True,
    "batch_size": 50,
    "batches_limit": 50,
    "useHistory": True,
    "disableRequestURI": True,
    "customChunkSize": 50,
    "syncAfterMerge": False,
    "concurrencyOfReadChunksOnline": 100,
    "minimumIntervalOfReadChunksOnline": 100,
    "handleFilenameCaseSensitive": False,
    "doNotUseFixedRevisionForChunks": False,
    "settingVersion": 10,
    "notifyThresholdOfRemoteStorageSize": 800,
}


def _derive_encryption_key(passphrase: str, salt: bytes) -> bytes:
    passphrase_digest = hashlib.sha256(passphrase.encode("utf-8")).digest()
    key_derivation = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=SETUP_URI_ITERATIONS,
    )
    return key_derivation.derive(passphrase_digest)


def build_livesync_settings(
    couchdb_uri: str,
    couchdb_user: str,
    couchdb_password: str,
    couchdb_dbname: str,
    vault_passphrase: str,
) -> dict[str, Any]:
    settings = dict(DEFAULT_LIVESYNC_SETTINGS)
    settings.update(
        {
            "couchDB_URI": couchdb_uri,
            "couchDB_USER": couchdb_user,
            "couchDB_PASSWORD": couchdb_password,
            "couchDB_DBNAME": couchdb_dbname,
            "passphrase": vault_passphrase,
        }
    )
    return settings


def encrypt_settings_payload(
    settings: dict[str, Any],
    setup_uri_passphrase: str,
    *,
    iv: bytes | None = None,
    salt: bytes | None = None,
) -> str:
    plaintext = json.dumps(settings, separators=(",", ":")).encode("utf-8")
    iv = iv or os.urandom(16)
    salt = salt or os.urandom(16)
    key = _derive_encryption_key(setup_uri_passphrase, salt)
    ciphertext = AESGCM(key).encrypt(iv, plaintext, None)
    encoded_ciphertext = base64.b64encode(ciphertext).decode("ascii")
    return f"%{iv.hex()}{salt.hex()}{encoded_ciphertext}"


def build_setup_uri(settings: dict[str, Any], setup_uri_passphrase: str) -> str:
    encrypted_settings = encrypt_settings_payload(settings, setup_uri_passphrase)
    return f"{SETUP_URI_BASE}{quote(encrypted_settings, safe='')}"


def decrypt_setup_uri(setup_uri: str, setup_uri_passphrase: str) -> dict[str, Any]:
    if not setup_uri.startswith(SETUP_URI_BASE):
        raise ValueError(f"setup URI must start with {SETUP_URI_BASE!r}")

    encrypted_settings = unquote(setup_uri[len(SETUP_URI_BASE):])
    if not encrypted_settings.startswith("%") or len(encrypted_settings) < 66:
        raise ValueError("setup URI payload is malformed")

    iv = bytes.fromhex(encrypted_settings[1:33])
    salt = bytes.fromhex(encrypted_settings[33:65])
    ciphertext = base64.b64decode(encrypted_settings[65:])
    key = _derive_encryption_key(setup_uri_passphrase, salt)
    plaintext = AESGCM(key).decrypt(iv, ciphertext, None)
    return json.loads(plaintext.decode("utf-8"))
