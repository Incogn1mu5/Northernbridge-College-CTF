<?php
// ---------------------------------------------------------
// Northernbridge College — Academics
// ---------------------------------------------------------

require_once __DIR__ . '/includes/init.php';
require_once __DIR__ . '/db.php';

/*
|--------------------------------------------------------------------------
| Fetch courses from database
|--------------------------------------------------------------------------
*/
$coursesResult = $db->query("
    SELECT
        course_id,
        course_name,
        department,
        instructor,
        credits
    FROM courses
    ORDER BY
        CASE department
            WHEN 'Information Technology' THEN 1
            WHEN 'Computer Science' THEN 2
            WHEN 'Civil Engineering' THEN 3
            WHEN 'Mechanical Engineering' THEN 4
            ELSE 5
        END,
        course_id
");

$coursesByDepartment = [];

if ($coursesResult) {
    while ($course = $coursesResult->fetchArray(SQLITE3_ASSOC)) {
        $coursesByDepartment[$course['department']][] = $course;
    }
}

$totalCourses = 0;
foreach ($coursesByDepartment as $departmentCourses) {
    $totalCourses += count($departmentCourses);
}

/*
|--------------------------------------------------------------------------
| Fetch faculty data from database
|--------------------------------------------------------------------------
*/
$facultyResult = $db->query("
    SELECT
        name,
        department,
        email,
        phone,
        title
    FROM faculty
    ORDER BY name
");

$facultyByName = [];

if ($facultyResult) {
    while ($faculty = $facultyResult->fetchArray(SQLITE3_ASSOC)) {
        $facultyByName[$faculty['name']] = $faculty;
    }
}

$departments = [
    'Information Technology',
    'Computer Science',
    'Civil Engineering',
    'Mechanical Engineering',
];

$highlights = [
    [
        "title" => "4 Departments, Dynamic Courses",
        "desc" => "Explore current course offerings directly from the college course catalogue.",
    ],
    [
        "title" => "11:1 Student–Faculty Ratio",
        "desc" => "Small seminar sizes and close mentorship on every course track.",
    ],
    [
        "title" => "Hands-On Curriculum",
        "desc" => "Lab work, studio critique, and applied projects in every major.",
    ],
    [
        "title" => "Senior Capstones",
        "desc" => "Every graduate completes an independent capstone project or thesis.",
    ],
];

$year = date("Y");
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Academics — Northernbridge College</title>
<style>
    :root {
        --ink:        #1c2a24;
        --parchment:  #f6f3ec;
        --hedge:      #2f4a3d;
        --hedge-dark: #203329;
        --brass:      #a97c33;
        --line:       #d9d2c2;
        --muted:      #5b6b62;
        font-size: 16px;
    }

    * { box-sizing: border-box; }

    body {
        margin: 0;
        background: var(--parchment);
        color: var(--ink);
        font-family: "Iowan Old Style", "Palatino Linotype", Georgia, serif;
        line-height: 1.55;
    }

    h1, h2, h3, .brand-word {
        font-family: "Iowan Old Style", Georgia, serif;
        font-weight: 600;
        letter-spacing: 0.01em;
    }

    .sans {
        font-family: "Segoe UI", Helvetica, Arial, sans-serif;
    }

    a { color: inherit; }

    /* ---------- Page hero ---------- */
    .page-hero {
        background: linear-gradient(180deg, var(--hedge) 0%, var(--hedge-dark) 100%);
        color: var(--parchment);
        padding: 3rem 1.5rem 2.6rem;
    }

    .page-hero-inner {
        max-width: 1100px;
        margin: 0 auto;
    }

    .page-hero h1 {
        font-size: 2.3rem;
        margin: 0 0 0.8rem;
        line-height: 1.2;
    }

    .hero-motto {
        font-family: "Segoe UI", Helvetica, Arial, sans-serif;
        font-size: 0.78rem;
        letter-spacing: 0.12em;
        color: var(--brass);
        margin-bottom: 0.6rem;
    }

    .page-hero p.lede {
        font-size: 1.05rem;
        color: #dfe6e1;
        max-width: 60ch;
        margin: 0;
    }

    /* ---------- Sections ---------- */
    .section {
        max-width: 1100px;
        margin: 0 auto;
        padding: 3rem 1.5rem 3.5rem;
    }

    .section-head {
        display: flex;
        align-items: baseline;
        justify-content: space-between;
        border-bottom: 1px solid var(--line);
        padding-bottom: 0.7rem;
        margin-bottom: 1.6rem;
    }

    .section-head h2 {
        font-size: 1.5rem;
        margin: 0;
        color: var(--hedge-dark);
    }

    .section-head a {
        font-family: "Segoe UI", Helvetica, Arial, sans-serif;
        font-size: 0.88rem;
        text-decoration: none;
        color: var(--hedge);
        border-bottom: 1px solid var(--hedge);
    }

    /* ---------- Highlights ---------- */
    .card-grid {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 1.25rem;
    }

    .card {
        border: 1px solid var(--line);
        background: #fffdf8;
        padding: 1.2rem;
        border-radius: 3px;
        border-top: 3px solid var(--hedge);
    }

    .card h3 {
        font-size: 1.05rem;
        margin: 0 0 0.5rem;
        color: var(--hedge-dark);
    }

    .card p {
        font-family: "Segoe UI", Helvetica, Arial, sans-serif;
        font-size: 0.87rem;
        color: var(--muted);
        margin: 0;
    }

    /* ---------- Courses ---------- */
    .department-section {
        margin-bottom: 2.8rem;
    }

    .department-section:last-child {
        margin-bottom: 0;
    }

    .department-title {
        display: flex;
        align-items: baseline;
        justify-content: space-between;
        gap: 1rem;
        margin-bottom: 1rem;
        padding-bottom: 0.55rem;
        border-bottom: 1px solid var(--line);
    }

    .department-title h3 {
        margin: 0;
        font-size: 1.35rem;
        color: var(--hedge-dark);
    }

    .department-code {
        font-family: "Segoe UI", Helvetica, Arial, sans-serif;
        font-size: 0.76rem;
        font-weight: 700;
        letter-spacing: 0.08em;
        color: var(--brass);
        text-transform: uppercase;
    }

    .course-grid {
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        gap: 1.25rem;
    }

    .course-card {
        border: 1px solid var(--line);
        border-top: 3px solid var(--hedge);
        background: #fffdf8;
        padding: 1.35rem;
        border-radius: 3px;
    }

    .course-code {
        font-family: "Segoe UI", Helvetica, Arial, sans-serif;
        font-size: 0.78rem;
        font-weight: 700;
        letter-spacing: 0.08em;
        color: var(--brass);
        margin-bottom: 0.35rem;
    }

    .course-card h4 {
        margin: 0 0 1rem;
        font-size: 1.12rem;
        color: var(--hedge-dark);
    }

    .course-details {
        display: grid;
        gap: 0.55rem;
        font-family: "Segoe UI", Helvetica, Arial, sans-serif;
        font-size: 0.86rem;
    }

    .course-detail {
        display: flex;
        justify-content: space-between;
        gap: 1rem;
        padding-top: 0.45rem;
        border-top: 1px solid #eee9df;
    }

    .course-detail .label {
        color: var(--muted);
        font-weight: 600;
    }

    .course-detail .value {
        color: var(--ink);
        text-align: right;
    }

    .instructor-link {
        color: var(--hedge);
        background: none;
        border: 0;
        padding: 0;
        margin: 0;
        font: inherit;
        font-weight: 600;
        text-decoration: underline;
        text-decoration-color: var(--brass);
        text-underline-offset: 3px;
        cursor: pointer;
    }

    .instructor-link:hover {
        color: var(--brass);
    }

    /* ---------- Faculty modal ---------- */
    .faculty-modal {
        position: fixed;
        inset: 0;
        z-index: 1000;
        display: none;
        align-items: center;
        justify-content: center;
        padding: 1.5rem;
        background: rgba(28, 42, 36, 0.68);
    }

    .faculty-modal.is-open {
        display: flex;
    }

    .faculty-tile {
        width: min(520px, 100%);
        background: #fffdf8;
        border: 1px solid var(--line);
        border-top: 4px solid var(--brass);
        border-radius: 5px;
        padding: 2rem;
        box-shadow: 0 18px 50px rgba(0, 0, 0, 0.22);
        position: relative;
    }

    .faculty-eyebrow {
        font-family: "Segoe UI", Helvetica, Arial, sans-serif;
        font-size: 0.75rem;
        font-weight: 700;
        letter-spacing: 0.12em;
        color: var(--brass);
        text-transform: uppercase;
        margin-bottom: 0.45rem;
    }

    .faculty-tile h3 {
        margin: 0 0 0.25rem;
        font-size: 1.7rem;
        color: var(--hedge-dark);
    }

    .faculty-title {
        color: var(--muted);
        font-family: "Segoe UI", Helvetica, Arial, sans-serif;
        font-size: 0.9rem;
        margin-bottom: 1.4rem;
    }

    .faculty-details {
        display: grid;
        gap: 0.75rem;
    }

    .faculty-detail {
        display: grid;
        grid-template-columns: 120px 1fr;
        gap: 1rem;
        padding-top: 0.65rem;
        border-top: 1px solid #eee9df;
        font-family: "Segoe UI", Helvetica, Arial, sans-serif;
        font-size: 0.9rem;
    }

    .faculty-detail .label {
        color: var(--muted);
        font-weight: 600;
    }

    .faculty-detail .value {
        color: var(--ink);
        word-break: break-word;
    }

    .faculty-close {
        position: absolute;
        top: 0.9rem;
        right: 0.9rem;
        border: 1px solid var(--line);
        background: var(--parchment);
        color: var(--hedge-dark);
        width: 34px;
        height: 34px;
        border-radius: 50%;
        cursor: pointer;
        font-size: 1.1rem;
        line-height: 1;
    }

    .faculty-close:hover {
        background: var(--hedge);
        color: white;
    }

    /* ---------- Academic calendar strip ---------- */
    .note-strip {
        background: var(--parchment);
        border-bottom: 1px solid var(--line);
        border-top: 1px solid var(--line);
    }

    .note-strip-inner {
        max-width: 1100px;
        margin: 0 auto;
        padding: 0.85rem 1.5rem;
        display: flex;
        align-items: center;
        gap: 0.8rem;
        font-family: "Segoe UI", Helvetica, Arial, sans-serif;
        font-size: 0.93rem;
    }

    .note-tag {
        flex-shrink: 0;
        color: var(--hedge);
        font-weight: 700;
        border-right: 1px solid var(--line);
        padding-right: 0.8rem;
    }

    .note-strip-inner p { margin: 0; color: #3c4841; }

    /* ---------- Responsive ---------- */
    @media (max-width: 860px) {
        .card-grid { grid-template-columns: repeat(2, 1fr); }
        .course-grid { grid-template-columns: 1fr; }
    }

    @media (max-width: 560px) {
        .card-grid { grid-template-columns: 1fr; }
        .page-hero h1 { font-size: 1.9rem; }
        .note-strip-inner { flex-direction: column; align-items: flex-start; }
        .note-tag { border-right: none; padding-right: 0; }
    }

    @media (prefers-reduced-motion: reduce) {
        * { transition: none !important; }
    }

    :focus-visible {
        outline: 2px solid var(--brass);
        outline-offset: 2px;
    }
</style>
</head>
<body>

<?php require_once __DIR__ . '/includes/header.php'; ?>

<section class="page-hero">
    <div class="page-hero-inner">
        <div class="hero-motto sans">ACADEMICS</div>
        <h1>Courses &amp; Departments</h1>
        <p class="lede">Explore the college course catalogue by department, with course details maintained directly in the academic database.</p>
    </div>
</section>

<section class="section">
    <div class="section-head">
        <h2>Why Study Here</h2>
        <a href="admissions.php">Apply now</a>
    </div>
    <div class="card-grid">
        <?php foreach ($highlights as $h): ?>
        <div class="card">
            <h3><?php echo htmlspecialchars($h['title']); ?></h3>
            <p><?php echo htmlspecialchars($h['desc']); ?></p>
        </div>
        <?php endforeach; ?>
    </div>
</section>

<div class="note-strip">
    <div class="note-strip-inner">
        <span class="note-tag">Fall <?php echo $year; ?></span>
        <p>Registration opens August 20. New students enroll through the student portal after completing admission.</p>
    </div>
</div>

<section class="section">
    <div class="section-head">
        <h2>Courses</h2>
        <span class="sans"><?php echo $totalCourses; ?> courses</span>
    </div>

    <?php
    $departmentCodes = [
        'Information Technology' => 'IT',
        'Computer Science' => 'CS',
        'Civil Engineering' => 'CE',
        'Mechanical Engineering' => 'ME',
    ];
    ?>

    <script>
        const facultyDirectory = <?php
            echo json_encode(
                $facultyByName,
                JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT
            );
        ?>;
    </script>

    <?php foreach ($departments as $department): ?>
        <div class="department-section">
            <div class="department-title">
                <h3><?php echo htmlspecialchars($department); ?></h3>
                <span class="department-code">
                    <?php echo htmlspecialchars($departmentCodes[$department]); ?>
                </span>
            </div>

            <div class="course-grid">
                <?php if (!empty($coursesByDepartment[$department])): ?>
                    <?php foreach ($coursesByDepartment[$department] as $course): ?>
                        <article class="course-card">
                            <div class="course-code">
                                Course Code:
                                <?php echo htmlspecialchars($course['course_id']); ?>
                            </div>

                            <h4>
                                <?php echo htmlspecialchars($course['course_name']); ?>
                            </h4>

                            <div class="course-details">
                                <div class="course-detail">
                                    <span class="label">Department</span>
                                    <span class="value">
                                        <?php echo htmlspecialchars($course['department']); ?>
                                    </span>
                                </div>

                                <div class="course-detail">
                                    <span class="label">Instructor</span>
                                    <span class="value">
                                        <?php if (isset($facultyByName[$course['instructor']])): ?>
                                            <button
                                                type="button"
                                                class="instructor-link"
                                                data-instructor="<?php echo htmlspecialchars($course['instructor'], ENT_QUOTES, 'UTF-8'); ?>"
                                            >
                                                <?php echo htmlspecialchars($course['instructor']); ?>
                                            </button>
                                        <?php else: ?>
                                            <?php echo htmlspecialchars($course['instructor']); ?>
                                        <?php endif; ?>
                                    </span>
                                </div>

                                <div class="course-detail">
                                    <span class="label">Credits</span>
                                    <span class="value">
                                        <?php echo htmlspecialchars($course['credits']); ?>
                                    </span>
                                </div>
                            </div>
                        </article>
                    <?php endforeach; ?>
                <?php else: ?>
                    <p class="sans">No courses are currently listed for this department.</p>
                <?php endif; ?>
            </div>
        </div>
    <?php endforeach; ?>
</section>

<!-- Faculty profile modal -->
<div class="faculty-modal" id="facultyModal" aria-hidden="true">
    <div class="faculty-tile" role="dialog" aria-modal="true" aria-labelledby="facultyName">
        <button
            type="button"
            class="faculty-close"
            id="facultyClose"
            aria-label="Close faculty profile"
        >
            ×
        </button>

        <div class="faculty-eyebrow">Faculty Profile</div>

        <h3 id="facultyName"></h3>
        <p class="faculty-title" id="facultyTitle"></p>

        <div class="faculty-details">
            <div class="faculty-detail">
                <span class="label">Department</span>
                <span class="value" id="facultyDepartment"></span>
            </div>

            <div class="faculty-detail">
                <span class="label">Email</span>
                <span class="value" id="facultyEmail"></span>
            </div>

            <div class="faculty-detail">
                <span class="label">Phone</span>
                <span class="value" id="facultyPhone"></span>
            </div>
        </div>
    </div>
</div>

<script>
(function () {
    const modal = document.getElementById('facultyModal');
    const closeButton = document.getElementById('facultyClose');

    const facultyName = document.getElementById('facultyName');
    const facultyTitle = document.getElementById('facultyTitle');
    const facultyDepartment = document.getElementById('facultyDepartment');
    const facultyEmail = document.getElementById('facultyEmail');
    const facultyPhone = document.getElementById('facultyPhone');

    function openFacultyProfile(name) {
        const faculty = facultyDirectory[name];

        if (!faculty) {
            return;
        }

        facultyName.textContent = faculty.name;
        facultyTitle.textContent = faculty.title;
        facultyDepartment.textContent = faculty.department;
        facultyEmail.textContent = faculty.email;
        facultyPhone.textContent = faculty.phone;

        modal.classList.add('is-open');
        modal.setAttribute('aria-hidden', 'false');
    }

    function closeFacultyProfile() {
        modal.classList.remove('is-open');
        modal.setAttribute('aria-hidden', 'true');
    }

    document.querySelectorAll('.instructor-link').forEach(function (button) {
        button.addEventListener('click', function () {
            openFacultyProfile(this.dataset.instructor);
        });
    });

    closeButton.addEventListener('click', closeFacultyProfile);

    modal.addEventListener('click', function (event) {
        if (event.target === modal) {
            closeFacultyProfile();
        }
    });

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && modal.classList.contains('is-open')) {
            closeFacultyProfile();
        }
    });
})();
</script>

<?php require_once __DIR__ . '/includes/footer.php'; ?>