PRAGMA foreign_keys = ON;

-- ============================================================
-- Northernbridge College CTF — seed data
-- Idempotent: safe to run many times (CREATE IF NOT EXISTS +
-- INSERT OR IGNORE). Existing player data is never destroyed.
-- ============================================================

CREATE TABLE IF NOT EXISTS login_attempts (
    attempt_key  TEXT PRIMARY KEY,
    attempts     INTEGER NOT NULL DEFAULT 0,
    last_attempt INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS admins (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    name TEXT NOT NULL,
    number TEXT NOT NULL,
    salary REAL NOT NULL DEFAULT 0,
    department TEXT NOT NULL
);


CREATE TABLE IF NOT EXISTS students (
    student_id TEXT PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    contact_number TEXT NOT NULL,
    dob TEXT NOT NULL,
    address TEXT NOT NULL,
    department TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,

    CHECK (
        department IN (
            'Information Technology',
            'Computer Science',
            'Civil Engineering',
            'Mechanical Engineering'
        )
    )
);


CREATE TABLE IF NOT EXISTS marks (
    student_id TEXT PRIMARY KEY,

    math INTEGER NOT NULL DEFAULT 0,
    cpp INTEGER NOT NULL DEFAULT 0,
    python INTEGER NOT NULL DEFAULT 0,
    graphics INTEGER NOT NULL DEFAULT 0,

    FOREIGN KEY (student_id)
        REFERENCES students(student_id)
        ON DELETE CASCADE,

    CHECK (math BETWEEN 0 AND 100),
    CHECK (cpp BETWEEN 0 AND 100),
    CHECK (python BETWEEN 0 AND 100),
    CHECK (graphics BETWEEN 0 AND 100)
);


-- Course catalogue (per department). Kept separate from marks so the
-- limited clerk view can report an enrolled-courses count.
CREATE TABLE IF NOT EXISTS courses (
    course_id TEXT PRIMARY KEY,
    course_name TEXT NOT NULL,
    department TEXT NOT NULL,
    instructor TEXT NOT NULL,
    credits INTEGER NOT NULL DEFAULT 4
);


-- Faculty directory (fictional).
CREATE TABLE IF NOT EXISTS faculty (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    department TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone TEXT NOT NULL,
    title TEXT NOT NULL
);

-- =========================================
-- FICTIONAL STUDENTS
-- =========================================

INSERT OR IGNORE INTO students
(student_id, first_name, last_name, contact_number, dob, address, department, email, password)
VALUES

(   'NB-AP26-1001',
    'Aarav',
    'Patel',
    '9045678991',
    '2004-01-12',
    'Ahmedabad',
    'Information Technology',
    'aaravpatel@northernbridge.lab',
    'aarav2004'
),

(   'NB-RP26-1002',
    'Raghav',
    'patel',
    '7865324567',
    '2004-08-20',
    'Rajkot, Gujarat, India.',
    'Information Technology',
    'raghavpatel@northernbridge.lab',
    'raghav2004'
),

(   'NB-AN26-1003',
    'Arjun',
    'Nair',
    '9059993456',
    '2003-09-25',
    'Ahmedabad',
    'Information Technology',
    'arjunnair@northernbridge.lab',
    'arjun2003'
),

(   'NB-YS26-1004',
    'Yash',
    'Sharma',
    '9654321789',
    '2004-08-15',
    'Ahmedabad',
    'Information Technology',
    'yashsharma@northernbridge.lab',
    'yash2004'
),

(   'NB-RA26-1005',
    'riya',
    'agarwal',
    '9876512340',
    '2004-02-29',
    'jharkhand,india',
    'Information Technology',
    'riyaagarwal@northernbridge.lab',
    'riya2004'
),

(   'NB-RP26-2001',
    'Riya',
    'Patel',
    '9258792358',
    '2004-03-21',
    'Vadodara',
    'Computer Science',
    'riyapatel@northernbridge.lab',
    'riya2004'
),

(   'NB-AP26-2002',
    'Ananya',
    'pandey',
    '8967452310',
    '2002-06-03',
    'Mumbai, Maharashtra, India',
    'Computer Science',
    'ananyapandey@northernbridge.lab',
    'ananya2002'
),

(   'NB-RP26-2003',
    'Rakesh',
    'pandya',
    '8967451398',
    '2005-10-03',
    'Pune, Maharashtra, India',
    'Computer Science',
    'rakeshpandya@northernbridge.lab',
    'rakesh2005'
),

(   'NB-RC26-2004',
    'Ritesh',
    'Chaudary',
    '8967452445',
    '2004-11-04',
    'Jaipur, Rajasthan, India',
    'Computer Science',
    'riteshchaudary@northernbridge.lab',
    'ritesh2004'
),

(   'NB-AK26-2005',
    'Ayaan',
    'Khan',
    '8006852310',
    '2005-10-09',
    'West Bengal, India',
    'Computer Science',
    'ayaankhan@northernbridge.lab',
    'ayaan2005'
),

(   'NB-VS26-3001',
    'Vivaan',
    'Shah',
    '9344665130',
    '2003-11-08',
    'Surat',
    'Civil Engineering',
    'vivaanshah@northernbridge.lab',
    'vivaan2003'
),

(   'NB-JO26-3002',
    'jack',
    'Okafor',
    '2345678490',
    '2003-11-12',
    'jamaica',
    'Civil Engineering',
    'jackokafor@northernbridge.lab',
    'jack2003'
),

(   'NB-JG26-3003',
    'jay',
    'Ghosal',
    '2365458490',
    '2006-12-11',
    'Delhi, India',
    'Civil Engineering',
    'jayghosal@northernbridge.lab',
    'jay2006'
),

(   'NB-RJ26-3004',
    'Raj',
    'Jaiswal',
    '9745678490',
    '2006-10-11',
    'Jamnagar, Gujarat, India',
    'Civil Engineering',
    'rajjaiswal@northernbridge.lab',
    'raj2006'
),

(   'NB-YG26-3005',
    'yash',
    'Gohil',
    '9045678490',
    '2005-11-12',
    'Ahmedabad, Gujarat, India',
    'Civil Engineering',
    'yashgohil@northernbridge.lab',
    'yash2005'
),

(   'NB-KS26-4001',
    'Kavya',
    'Singh',
    '9004567890',
    '2004-06-17',
    'Rajkot',
    'Mechanical Engineering',
    'kavyasingh@northernbridge.lab',
    'kavya2004'
),

(   'NB-RT26-4002',
    'raj',
    'tripathi',
    '9674738475',
    '2004-05-03',
    'Uttarakhand,India',
    'Mechanical Engineering',
    'rajtripathi@northernbridge.lab',
    'raj2004'
),

(   'NB-AB26-4003',
    'Anmol',
    'Bhatiya',
    '9675848475',
    '2005-06-06',
    'Uttarakhand,India',
    'Mechanical Engineering',
    'anmolbhatiya@northernbridge.lab',
    'anmol2005'
),

(   'NB-AB26-4004',
    'Anjali',
    'Bhatiya',
    '9674739476',
    '2004-04-01',
    'Jharkhand,India',
    'Mechanical Engineering',
    'anjalibhatiya@northernbridge.lab',
    'anjali2004'
),

(   'NB-CH26-4005',
    'Charul',
    'Hinger',
    '9673439675',
    '2005-06-07',
    'Uttarpradesh,India',
    'Mechanical Engineering',
    'charulhinger@northernbridge.lab',
    'charul2005'
);


-- =========================================
-- FICTIONAL MARKS
-- =========================================

INSERT OR IGNORE INTO marks
(student_id, math, cpp, python, graphics)
VALUES

('NB-AP26-1001', 72, 81, 65, 74),
('NB-RP26-1002', 88, 79, 91, 83),
('NB-AN26-1003', 61, 70, 55, 68),
('NB-YS26-1004', 76, 84, 73, 80),
('NB-RA26-1005', 69, 77, 35, 62),
('NB-RP26-2001', 70, 85, 36, 50),
('NB-AP26-2002', 67, 54, 53, 76),
('NB-RP26-2003', 56, 34, 67, 75),
('NB-RC26-2004', 55, 67, 45, 50),
('NB-AK26-2005', 35, 36, 37, 38),
('NB-VS26-3001', 37, 78, 45, 23),
('NB-JO26-3002', 72, 81, 65, 74),
('NB-JG26-3003', 88, 79, 91, 83),
('NB-RJ26-3004', 35, 36, 37, 38),
('NB-YG26-3005', 56, 34, 67, 75),
('NB-KS26-4001', 67, 54, 53, 76),
('NB-RT26-4002', 69, 77, 35, 62),
('NB-AB26-4003', 76, 84, 73, 80),
('NB-AB26-4004', 67, 54, 53, 76),
('NB-CH26-4005', 35, 36, 37, 38);


-- =========================================
-- FICTIONAL COURSE CATALOGUE
-- =========================================

INSERT OR IGNORE INTO courses
(course_id, course_name, department, instructor, credits)
VALUES

('IT-101', 'Introduction to Information Technology', 'Information Technology', 'Dr. Anil Mehta', 4),
('IT-202', 'Network Fundamentals', 'Information Technology', 'Dr. Anil Mehta', 4),
('IT-310', 'Information Security Essentials', 'Information Technology', 'Ms. Priya Kannan', 4),
('CS-101', 'Programming Fundamentals', 'Computer Science', 'Mr. Rohan Singh', 4),
('CS-203', 'Data Structures and Algorithms', 'Computer Science', 'Mr. Rohan Singh', 4),
('CS-305', 'Database Management Systems', 'Computer Science', 'Dr. Lina Farouk', 4),
('CE-101', 'Engineering Mechanics', 'Civil Engineering', 'Mr. David Okafor', 4),
('CE-204', 'Structural Analysis', 'Civil Engineering', 'Mr. David Okafor', 4),
('ME-101', 'Thermodynamics', 'Mechanical Engineering', 'Mr. Mohd. Khan', 4),
('ME-206', 'Fluid Mechanics', 'Mechanical Engineering', 'Mr. Mohd. Khan', 4);


-- =========================================
-- FICTIONAL FACULTY DIRECTORY
-- =========================================

INSERT OR IGNORE INTO faculty
(name, department, email, phone, title)
VALUES

('Dr. Anil Mehta', 'Information Technology', 'anil.mehta@northernbridge.lab', '9911223344', 'Professor'),
('Ms. Priya Kannan', 'Information Technology', 'priya.kannan@northernbridge.lab', '9922334455', 'Assistant Professor'),
('Mr. Rohan Singh', 'Computer Science', 'rohan.singh@northernbridge.lab', '9933445566', 'Professor'),
('Dr. Lina Farouk', 'Computer Science', 'lina.farouk@northernbridge.lab', '9944556677', 'Associate Professor'),
('Mr. David Okafor', 'Civil Engineering', 'david.okafor@northernbridge.lab', '9955667788', 'Professor'),
('Ms. Fatima Hassan', 'Civil Engineering', 'fatima.hassan@northernbridge.lab', '9966778899', 'Assistant Professor'),
('Mr. Mohd. Khan', 'Mechanical Engineering', 'mohammed.khan@northernbridge.lab', '9977889900', 'Professor'),
('Dr. Emily Wong', 'Mechanical Engineering', 'emily.wong@northernbridge.lab', '9988990011', 'Associate Professor');
