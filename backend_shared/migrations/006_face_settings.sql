ALTER TABLE sessions ADD COLUMN auth_method text NOT NULL DEFAULT 'legacy'
  CHECK (auth_method IN ('legacy','password_otp','face_otp','face_device'));
ALTER TABLE face_templates ADD COLUMN device_key_hash text;
ALTER TABLE users ADD COLUMN phone text NOT NULL DEFAULT '';
ALTER TABLE users ADD COLUMN bio text NOT NULL DEFAULT '';
