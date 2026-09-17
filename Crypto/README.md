# Crypto — index

Cipher primitives and key material. The transport that uses them is documented in
[../Network/13_connection_lifecycle.md](../Network/13_connection_lifecycle.md).

- [00_tqcipher64.md](00_tqcipher64.md) — TQCipher64 is the project's historical
  name for CAST5 / CAST-128. Identification is backed by native control flow and
  all eight matching S-boxes.
- [01_rc5_credential_field.md](01_rc5_credential_field.md) — the RC5 credential
  field transform applied before `Msg1060`/`Msg1121`. The key is derived from the
  login seed, not from the fixed pre-login default; see
  [../Server/login-credential-envelope.md](../Server/login-credential-envelope.md)
  for the settled two-stage derivation.
- [02_server_dat_rsa_public_key_5517.md](02_server_dat_rsa_public_key_5517.md) —
  independent native audit of the `Server.dat` RSA public key. All 256 bytes match.
