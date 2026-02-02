-- MariaDB schema for AXP MVP Survey
-- Compatible with MariaDB 10.11+ (Strato managed)
-- Character set: UTF8MB4 for full Unicode support

-- Sessions table (replaces submission for consistency with new naming)
-- Stores one row per survey session
CREATE TABLE IF NOT EXISTS submission (
  submission_id VARCHAR(36) PRIMARY KEY,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  finished_at DATETIME NULL,
  instrument_id VARCHAR(255) NOT NULL,
  instrument_version VARCHAR(100) NOT NULL,
  language VARCHAR(10) NOT NULL DEFAULT 'en',
  consent_version VARCHAR(50) NOT NULL,
  definition_hash VARCHAR(64) NOT NULL,
  user_agent TEXT NULL,
  ip_hash VARCHAR(64) NULL,
  INDEX idx_submission_created (created_at),
  INDEX idx_submission_instrument (instrument_id, instrument_version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Numeric responses (sliders, ratings, etc.)
CREATE TABLE IF NOT EXISTS response_numeric (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  submission_id VARCHAR(36) NOT NULL,
  item_id VARCHAR(255) NOT NULL,
  value DECIMAL(20,6) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_response_numeric_submission (submission_id),
  INDEX idx_response_numeric_item (item_id),
  INDEX idx_response_numeric_created (created_at),
  CONSTRAINT fk_response_numeric_submission 
    FOREIGN KEY (submission_id) REFERENCES submission(submission_id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Text responses (free text, potentially sensitive)
-- These are stored raw and EXCLUDED from public exports
CREATE TABLE IF NOT EXISTS response_text (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  submission_id VARCHAR(36) NOT NULL,
  field_id VARCHAR(255) NOT NULL,
  text TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_response_text_submission (submission_id),
  INDEX idx_response_text_field (field_id),
  INDEX idx_response_text_created (created_at),
  CONSTRAINT fk_response_text_submission 
    FOREIGN KEY (submission_id) REFERENCES submission(submission_id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Computed scores per submission
CREATE TABLE IF NOT EXISTS score (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  submission_id VARCHAR(36) NOT NULL,
  scale_id VARCHAR(100) NOT NULL,
  score_value DECIMAL(20,6) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_score_submission (submission_id),
  INDEX idx_score_scale (scale_id),
  CONSTRAINT fk_score_submission 
    FOREIGN KEY (submission_id) REFERENCES submission(submission_id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Aggregate norms (computed periodically from all submissions)
CREATE TABLE IF NOT EXISTS aggregate_norms (
  instrument_version VARCHAR(100) NOT NULL,
  scale_id VARCHAR(100) NOT NULL,
  n INT NOT NULL DEFAULT 0,
  mean DECIMAL(20,6) NULL,
  sd DECIMAL(20,6) NULL,
  p05 DECIMAL(20,6) NULL,
  p50 DECIMAL(20,6) NULL,
  p95 DECIMAL(20,6) NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (instrument_version, scale_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Experience tracer data (raw points stored as JSON)
-- This is a new table for experience tracer responses
CREATE TABLE IF NOT EXISTS response_tracer (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  submission_id VARCHAR(36) NOT NULL,
  item_id VARCHAR(255) NOT NULL,
  raw_points JSON NULL,
  resampled_vector JSON NULL,
  duration_seconds INT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_response_tracer_submission (submission_id),
  INDEX idx_response_tracer_item (item_id),
  CONSTRAINT fk_response_tracer_submission 
    FOREIGN KEY (submission_id) REFERENCES submission(submission_id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
