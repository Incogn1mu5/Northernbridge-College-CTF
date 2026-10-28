<?php
function fetch_authorized_student(SQLite3 $db, string $studentId, string $adminDepartment): ?array
{
    $stmt = $db->prepare('
        SELECT
            s.student_id, s.first_name, s.last_name, s.department,
            m.math, m.cpp, m.python, m.graphics
        FROM students s
        LEFT JOIN marks m ON s.student_id = m.student_id
        WHERE s.student_id = :student_id
          AND s.department = :department
        LIMIT 1
    ');
    $stmt->bindValue(':student_id', $studentId, SQLITE3_TEXT);
    $stmt->bindValue(':department', $adminDepartment, SQLITE3_TEXT);
    $result = $stmt->execute();
    $row = $result ? $result->fetchArray(SQLITE3_ASSOC) : false;
    return $row ?: null;
}
