<?php
/*
|--------------------------------------------------------------------------
| Shared site header / navigation
|--------------------------------------------------------------------------
| Inlined after <body> on every public-facing page. Provides a consistent
| college brand bar and primary navigation. Never references internal paths.
|--------------------------------------------------------------------------
*/

$nc_admin_current = basename($_SERVER['SCRIPT_NAME'] ?? 'index.php'); 
function nc_admin_nav_class(string $target, string $current): string { 
    return $current === $target ? ' active' : ''; 
    } 
?>
<style> 
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

<header class="nc-admin-header">

<a class="nc-admin-brand" href="dashboard.php" title="Northernbridge College Administration">
    <span class="nc-admin-crest">NC</span>

    <span class="nc-admin-wordmark">
        NORTHERNBRIDGE 
        <small>COLLEGE</small>
    </span>
</a>

<nav class="nc-admin-nav" aria-label="Administration">

    <a 
        class="<?= nc_admin_nav_class('dashboard.php', $nc_admin_current) ?>" 
        href="dashboard.php"> Dashboard </a>

    <a class="nc-admin-logout" href="logout.php"> Logout </a>

</nav>
</header>