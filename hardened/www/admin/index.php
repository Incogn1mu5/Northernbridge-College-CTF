<?php
require_once __DIR__ . '/../includes/init.php';
require_once __DIR__ . '/../db.php';

$error = '';

require_once __DIR__ . '/../includes/login-throttle.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';
    $clientKey = $_SERVER['REMOTE_ADDR'] . '|' . strtolower($username);

    if (login_is_locked_out($db, $clientKey)) {
        $error = 'Too many attempts. Please try again later.';
    } else {
        $stmt = $db->prepare("
            SELECT id, username, name, password_hash
            FROM admins WHERE username = :username LIMIT 1
        ");
        $stmt->bindValue(':username', $username, SQLITE3_TEXT);
        $admin = $stmt->execute()->fetchArray(SQLITE3_ASSOC);

        if ($admin && password_verify($password, $admin['password_hash'])) {
            login_clear_attempts($db, $clientKey);
            session_regenerate_id(true);
            $_SESSION['admin_logged_in'] = true;
            $_SESSION['admin_id'] = $admin['id'];
            header('Location: dashboard.php');
            exit;
        } else {
                login_record_failure($db, $clientKey);
                error_log('[Northernbridge-hardened] failed admin login for '
                    . $username . ' from ' . $_SERVER['REMOTE_ADDR']);
                $error = 'Invalid administrator username or password.';
            }
    }
}

?>

<!DOCTYPE html>
<html lang="en">
<head>

    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <title>Admin Portal | Northernbridge College</title>

    <style>
        :root {
            --ink: #1c2a24;
            --parchment: #f6f3ec;
            --hedge: #2f4a3d;
            --hedge-dark: #203329;
            --brass: #a97c33;
            --line: #d9d2c2;
            --muted: #5b6b62;
            --white: #ffffff;
            --red: #b42318;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            min-height: 100vh;
            background: var(--parchment);
            color: var(--ink);
            font-family: Arial, sans-serif;
            display: flex;
            flex-direction: column;
        }

        header {
            background: var(--hedge-dark);
            color: white;
            border-bottom: 4px solid var(--brass);
        }

        nav {
            background: var(--hedge-dark);
            color: white;
            padding: 5px 6%;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .logo {
            font-family: Georgia, serif;
            font-size: 23px;
            font-weight: bold;
        }

        .admin-label {
            font-size: 13px;
            color: #d8dfda;
            letter-spacing: 1px;
        }

        .login-wrapper {
            width: min(900px, 92%);
            margin: auto;
            display: grid;
            grid-template-columns: 1fr 1.2fr;
            background: white;
            border: 1px solid var(--line);
            border-radius: 14px;
            overflow: hidden;
            box-shadow: 0 12px 35px rgba(32, 51, 41, 0.08);
        }

        .portal-panel {
            background: var(--hedge);
            color: white;
            padding: 50px 40px;
        }

        .portal-panel .small {
            color: #d7e0da;
            font-size: 13px;
            text-transform: uppercase;
            letter-spacing: 1.5px;
            margin-bottom: 15px;
        }

        .portal-panel h1 {
            font-family: Georgia, serif;
            font-size: 34px;
            line-height: 1.15;
            margin-bottom: 18px;
        }

        .portal-panel p {
            color: #dce5df;
            line-height: 1.7;
            font-size: 15px;
        }

        .form-panel {
            padding: 50px 45px;
        }

        .form-panel h2 {
            font-family: Georgia, serif;
            font-size: 30px;
            margin-bottom: 8px;
        }

        .subtitle {
            color: var(--muted);
            font-size: 14px;
            margin-bottom: 30px;
        }

        .error {
            background: #fdecec;
            color: var(--red);
            border: 1px solid #f2c5c5;
            padding: 12px 14px;
            border-radius: 7px;
            margin-bottom: 20px;
            font-size: 14px;
        }

        .field {
            margin-bottom: 20px;
        }

        label {
            display: block;
            font-size: 14px;
            font-weight: bold;
            margin-bottom: 8px;
        }

        input {
            width: 100%;
            padding: 13px 14px;
            border: 1px solid var(--line);
            border-radius: 7px;
            background: #fff;
            color: var(--ink);
            font-size: 15px;
            outline: none;
        }

        input:focus {
            border-color: var(--brass);
            box-shadow: 0 0 0 3px rgba(169, 124, 51, 0.12);
        }

        button {
            width: 100%;
            border: none;
            border-radius: 7px;
            padding: 14px;
            background: var(--hedge-dark);
            color: white;
            font-size: 15px;
            font-weight: bold;
            cursor: pointer;
        }

        button:hover {
            background: var(--hedge);
        }

        .notice {
            margin-top: 22px;
            padding-top: 18px;
            border-top: 1px solid var(--line);
            color: var(--muted);
            font-size: 12px;
            line-height: 1.6;
        }

        footer {
            text-align: center;
            padding: 25px;
            color: var(--muted);
            font-size: 12px;
        }

        @media (max-width: 700px) {

            .login-wrapper {
                grid-template-columns: 1fr;
                margin: 35px auto;
            }

            .portal-panel,
            .form-panel {
                padding: 35px 28px;
            }

            .portal-panel h1 {
                font-size: 29px;
            }
        }
            
            .nc-admin-header { 
        display: flex; 
        align-items: center; 
        justify-content: space-between; 
        gap: 1rem; padding: 0.9rem 1.5rem; 
        background: #203329; 
        color: #f6f3ec; 
        font-family: Georgia, 'Times New Roman', serif; 
        box-shadow: 0 2px 10px rgba(0, 0, 0, 0.18); 
        position: relative; z-index: 50; 
    } 
    
    .nc-admin-brand { 
        display: flex; 
        align-items: center; 
        gap: 0.7rem; text-decoration: none; 
        color: inherit; 
    } 
    
    .nc-admin-crest { 
        display: inline-flex; 
        align-items: center; 
        justify-content: center; 
        width: 2.2rem; height: 2.2rem; 
        border: 2px solid #a97c33; 
        border-radius: 50%; 
        color: #a97c33; 
        font-weight: 700; 
        font-size: 0.72rem; 
        letter-spacing: 0.06em; 
        background: rgba(169, 124, 51, 0.08); 
    } 
    
    .nc-admin-wordmark { 
        font-weight: 700; 
        font-size: 1.05rem; 
        letter-spacing: 0.08em; 
        line-height: 1.05; 
        display: flex; 
        flex-direction: column; 
        gap: 0.15rem; 
    } 
    
    .nc-admin-wordmark small { 
        font-size: 0.58rem; 
        letter-spacing: 0.24em; 
        color: #a97c33; 
        font-weight: 400; 
    } 
    
    .nc-admin-nav { 
        display: flex; 
        align-items: center; 
        gap: 0.35rem; 
        font-family: 'Segoe UI', Helvetica, Arial, sans-serif; 
        font-size: 0.86rem; 
    } 
    
    .nc-admin-nav a { 
        color: #f6f3ec; 
        text-decoration: none; 
        padding: 0.4rem 0.8rem; 
        border-radius: 4px; 
        transition: background 0.15s ease, color 0.15s ease; 
    } 
    
    .nc-admin-nav a:hover { 
        background: rgba(255, 255, 255, 0.12); 
    } 
    
    .nc-admin-nav a.active { 
        color: #a97c33; 
    } 
    
    .nc-admin-nav a.nc-admin-logout { 
        background: #a97c33; 
        color: #1c2a24; 
        font-weight: 600; 
    } 
    
    .nc-admin-nav a.nc-admin-logout:hover { 
        background: #b98f47; 
        color: #1c2a24; 
    } 
    
    @media (max-width: 640px) { 
        .nc-admin-header 
        { 
            flex-direction: column; 
            align-items: flex-start; } 
            .nc-admin-nav { 
                width: 100%; 
            }
        }
    </style>

</head>

<body>
<header class="nc-admin-header">

<a class="nc-admin-brand" href="index.php" title="Northernbridge College Administration">
    <span class="nc-admin-crest">NC</span>

    <span class="nc-admin-wordmark">
        NORTHERNBRIDGE 
        <small>COLLEGE</small>
    </span>
</a>

<nav class="nc-admin-nav" aria-label="Administration">

</nav>
</header>

<main class="login-wrapper">

    <section class="portal-panel">

        <div class="small">
            Restricted Area
        </div>

        <h1>
            Administrator Portal
        </h1>

        <p>
            Access the Northernbridge College administration
            system to manage student academic records and
            administrative information.
        </p>


    </section>


    <section class="form-panel">

        <h2>Admin Login</h2>

        <p class="subtitle">
            Sign in with your administrator credentials.
        </p>

        <?php if ($error): ?>

            <div class="error">
                <?= htmlspecialchars($error) ?>
            </div>

        <?php endif; ?>

        <form method="POST">

            <div class="field">

                <label for="username">
                    Username
                </label>

                <input
                    type="text"
                    id="username"
                    name="username"
                    placeholder="Enter administrator username"
                    required
                    autocomplete="username"
                >

            </div>


            <div class="field">

                <label for="password">
                    Password
                </label>

                <input
                    type="password"
                    id="password"
                    name="password"
                    placeholder="Enter administrator password"
                    required
                    autocomplete="current-password"
                >

            </div>


            <button type="submit">
                Sign In
            </button>

        </form>

        <div class="notice">
            This portal is restricted to authorized
            Northernbridge College administrators.
        </div>

    </section>

</main>


<?php require_once __DIR__ . '/../includes/adm-footer.php'; ?>
