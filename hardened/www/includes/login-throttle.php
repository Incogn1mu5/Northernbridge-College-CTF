<?php
const LOGIN_MAX_ATTEMPTS     = 5;
const LOGIN_LOCKOUT_SECONDS  = 300;

function login_is_locked_out(SQLite3 $db, string $key): bool
{
    $stmt = $db->prepare('SELECT attempts, last_attempt FROM login_attempts WHERE attempt_key = :key');
    $stmt->bindValue(':key', $key, SQLITE3_TEXT);
    $row = $stmt->execute()->fetchArray(SQLITE3_ASSOC);

    if (!$row) {
        return false;
    }

    $withinWindow = (time() - (int)$row['last_attempt']) < LOGIN_LOCKOUT_SECONDS;
    return $withinWindow && (int)$row['attempts'] >= LOGIN_MAX_ATTEMPTS;
}

function login_record_failure(SQLite3 $db, string $key): void
{
    $stmt = $db->prepare('
        INSERT INTO login_attempts (attempt_key, attempts, last_attempt)
        VALUES (:key, 1, :now)
        ON CONFLICT(attempt_key) DO UPDATE SET
            attempts = attempts + 1,
            last_attempt = :now
    ');
    $stmt->bindValue(':key', $key, SQLITE3_TEXT);
    $stmt->bindValue(':now', time(), SQLITE3_INTEGER);
    $stmt->execute();
}

function login_clear_attempts(SQLite3 $db, string $key): void
{
    $stmt = $db->prepare('DELETE FROM login_attempts WHERE attempt_key = :key');
    $stmt->bindValue(':key', $key, SQLITE3_TEXT);
    $stmt->execute();
}
