-- =====================================================================
-- PennyPal - database and table definitions
-- Dialect: SQLite 3 (the same schema is created on the device by
-- lib/data/database.dart; this script can be run with the sqlite3 CLI:
--     sqlite3 pennypal.db < pennypal_schema.sql
-- IDs are TEXT (UUID v4) so records created offline on different
-- devices never collide when they are synced to the cloud.
-- Dates are stored as ISO-8601 text (YYYY-MM-DD or full timestamps).
-- =====================================================================

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS Users (
  UserId        TEXT PRIMARY KEY,
  FullName      TEXT NOT NULL,
  Email         TEXT NOT NULL UNIQUE COLLATE NOCASE,
  MobileNumber  TEXT NOT NULL,
  PasswordHash  TEXT NOT NULL,              -- "salt$sha256(iterated)"
  Role          TEXT NOT NULL DEFAULT 'student' CHECK (Role IN ('student','admin')),
  IsActive      INTEGER NOT NULL DEFAULT 1,
  CreatedAt     TEXT NOT NULL,
  LastLogin     TEXT
);

CREATE TABLE IF NOT EXISTS UserProfiles (
  ProfileId              TEXT PRIMARY KEY,
  UserId                 TEXT NOT NULL UNIQUE REFERENCES Users(UserId) ON DELETE CASCADE,
  StudentStatus          TEXT,               -- e.g. High school, Undergraduate
  CurrencyPreference     TEXT NOT NULL DEFAULT 'USD',
  NotificationPreference INTEGER NOT NULL DEFAULT 1,
  ProfileImage           TEXT
);

CREATE TABLE IF NOT EXISTS Categories (
  CategoryId    TEXT PRIMARY KEY,
  CategoryName  TEXT NOT NULL,
  CategoryType  TEXT NOT NULL DEFAULT 'expense' CHECK (CategoryType IN ('expense','income')),
  Icon          TEXT,
  IsDefault     INTEGER NOT NULL DEFAULT 0,
  CreatedBy     TEXT REFERENCES Users(UserId) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS Transactions (
  TransactionId   TEXT PRIMARY KEY,
  UserId          TEXT NOT NULL REFERENCES Users(UserId) ON DELETE CASCADE,
  Type            TEXT NOT NULL CHECK (Type IN ('income','expense')),
  Amount          REAL NOT NULL CHECK (Amount > 0),
  CategoryId      TEXT REFERENCES Categories(CategoryId),  -- expenses only
  Source          TEXT,                                    -- income only
  Description     TEXT,
  Date            TEXT NOT NULL,
  PaymentMode     TEXT,
  ReceiptImageUrl TEXT,
  CreatedAt       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tx_user_date ON Transactions(UserId, Date);

CREATE TABLE IF NOT EXISTS Budgets (
  BudgetId        TEXT PRIMARY KEY,
  UserId          TEXT NOT NULL REFERENCES Users(UserId) ON DELETE CASCADE,
  Month           TEXT NOT NULL,             -- YYYY-MM
  CategoryId      TEXT REFERENCES Categories(CategoryId), -- NULL = overall monthly budget
  LimitAmount     REAL NOT NULL CHECK (LimitAmount > 0),
  AlertThreshold  INTEGER NOT NULL DEFAULT 80 CHECK (AlertThreshold BETWEEN 1 AND 100),
  CreatedAt       TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_budget_unique
  ON Budgets(UserId, Month, IFNULL(CategoryId, ''));

CREATE TABLE IF NOT EXISTS SavingsGoals (
  GoalId              TEXT PRIMARY KEY,
  UserId              TEXT NOT NULL REFERENCES Users(UserId) ON DELETE CASCADE,
  GoalName            TEXT NOT NULL,
  TargetAmount        REAL NOT NULL CHECK (TargetAmount > 0),
  CurrentAmount       REAL NOT NULL DEFAULT 0,
  TargetDate          TEXT NOT NULL,
  MonthlyContribution REAL NOT NULL DEFAULT 0,
  Status              TEXT NOT NULL DEFAULT 'active' CHECK (Status IN ('active','completed')),
  Milestones          TEXT NOT NULL DEFAULT '', -- comma separated % reached, e.g. "25,50"
  CreatedAt           TEXT NOT NULL,
  CompletedAt         TEXT
);

CREATE TABLE IF NOT EXISTS Reports (
  ReportId     TEXT PRIMARY KEY,
  UserId       TEXT NOT NULL REFERENCES Users(UserId) ON DELETE CASCADE,
  ReportType   TEXT NOT NULL,                -- monthly | custom
  DateRange    TEXT NOT NULL,                -- "YYYY-MM-DD..YYYY-MM-DD"
  GeneratedOn  TEXT NOT NULL,
  FileUrl      TEXT
);

CREATE TABLE IF NOT EXISTS LearningContent (
  ContentId        TEXT PRIMARY KEY,
  Title            TEXT NOT NULL,
  Topic            TEXT NOT NULL,
  Body             TEXT NOT NULL,
  DifficultyLevel  TEXT NOT NULL DEFAULT 'Beginner',
  ImageUrl         TEXT,
  IsActive         INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS Notifications (
  NotificationId  TEXT PRIMARY KEY,
  UserId          TEXT NOT NULL REFERENCES Users(UserId) ON DELETE CASCADE,
  Title           TEXT NOT NULL,
  Message         TEXT NOT NULL,
  Type            TEXT NOT NULL,             -- budget | goal | system
  ReadStatus      INTEGER NOT NULL DEFAULT 0,
  CreatedAt       TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS SupportQueries (
  QueryId        TEXT PRIMARY KEY,
  UserId         TEXT NOT NULL REFERENCES Users(UserId) ON DELETE CASCADE,
  Subject        TEXT NOT NULL,
  Message        TEXT NOT NULL,
  Status         TEXT NOT NULL DEFAULT 'open' CHECK (Status IN ('open','in_progress','resolved')),
  AdminResponse  TEXT,
  SubmittedOn    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS Feedback (
  FeedbackId   TEXT PRIMARY KEY,
  UserId       TEXT REFERENCES Users(UserId) ON DELETE SET NULL,
  Name         TEXT NOT NULL,
  Email        TEXT NOT NULL,
  Rating       INTEGER NOT NULL CHECK (Rating BETWEEN 1 AND 5),
  Comments     TEXT NOT NULL,
  SubmittedOn  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS AppSettings (
  SettingKey    TEXT PRIMARY KEY,
  SettingValue  TEXT NOT NULL
);

-- Offline sync queue: every local write is recorded here and pushed to
-- the cloud (Firestore) when connectivity is available.
CREATE TABLE IF NOT EXISTS SyncQueue (
  QueueId     INTEGER PRIMARY KEY AUTOINCREMENT,
  EntityName  TEXT NOT NULL,
  RecordId    TEXT NOT NULL,
  Operation   TEXT NOT NULL CHECK (Operation IN ('upsert','delete')),
  UserId      TEXT,
  CreatedAt   TEXT NOT NULL,
  Attempts    INTEGER NOT NULL DEFAULT 0
);
