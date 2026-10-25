<?php
function require_admin_session(SQLite3 $db): array
{
    if (empty($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
        header('Location: index.php');
        exit;
    }

    $stmt = $db->prepare('
        SELECT id, username, name, number, salary, department
        FROM admins
        WHERE id = :id
        LIMIT 1
    ');
    $stmt->bindValue(':id', $_SESSION['admin_id'] ?? null, SQLITE3_INTEGER);
    $result = $stmt->execute();
    $admin = $result ? $result->fetchArray(SQLITE3_ASSOC) : false;

    if (!$admin) {
        session_unset();
        session_destroy();
        header('Location: index.php');
        exit;
    }

    return $admin;
}
