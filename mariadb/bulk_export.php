<?php
declare(strict_types=1);

error_reporting(E_ALL);
ini_set('display_errors', '1');
set_time_limit(0);

$host = '127.0.0.1';
$port = 3306;
$user = 'root';
$password = '';
$exportDir = __DIR__ . DIRECTORY_SEPARATOR . 'exported';

// Ensure export directory exists
if (!is_dir($exportDir)) {
    if (!mkdir($exportDir, 0755, true) && !is_dir($exportDir)) {
        fwrite(STDERR, "Failed to create export directory: {$exportDir}\n");
        exit(1);
    }
}

// Connect to MariaDB
try {
    $dsn = sprintf('mysql:host=%s;port=%d;charset=utf8mb4', $host, $port);
    $pdo = new PDO($dsn, $user, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_COLUMN,
    ]);
} catch (PDOException $e) {
    fwrite(STDERR, 'Connection failed: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}

// Detect event scheduler status to decide whether to dump events
$eventSchedulerOn = false;
try {
    $stmtVar = $pdo->query("SHOW VARIABLES LIKE 'event_scheduler'");
    $row = $stmtVar->fetch(PDO::FETCH_ASSOC);
    if ($row && isset($row['Value'])) {
        $eventSchedulerOn = strtolower((string)$row['Value']) === 'on';
    }
} catch (Throwable $e) {
    // If unknown, default to false to avoid mysqldump failure
}

// Detect if INFORMATION_SCHEMA.LIBRARIES exists to decide on dumping routines with this client
$supportsLibraries = false;
try {
    $stmtLib = $pdo->query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='information_schema' AND table_name='LIBRARIES'");
    $supportsLibraries = ((int)$stmtLib->fetch(PDO::FETCH_COLUMN) > 0);
} catch (Throwable $e) {
    // Be conservative; if unknown, assume false to avoid client/server mismatch
    $supportsLibraries = false;
}

// Exclude system databases and common defaults
$systemDbs = [
    'information_schema',
    'mysql',
    'performance_schema',
    'sys',
    'test',
];

$placeholders = implode(',', array_fill(0, count($systemDbs), '?'));
$sql = "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA
         WHERE SCHEMA_NAME NOT IN ($placeholders)
         ORDER BY SCHEMA_NAME";

$stmt = $pdo->prepare($sql);
$stmt->execute($systemDbs);
$databases = $stmt->fetchAll();

if (!$databases) {
    echo "No user databases found.\n";
    exit(0);
}

// Locate mysqldump
$mysqldump = trim((string)@shell_exec('command -v mysqldump'));
if ($mysqldump === '') {
    // Fallback to default name; if not in PATH, the command will fail and we report it below
    $mysqldump = 'mysqldump';
}

$timestamp = date('Ymd_His');
if (!$eventSchedulerOn) {
    echo "Note: event_scheduler is OFF; skipping --events in dumps.\n";
}
if (!$supportsLibraries) {
    echo "Note: information_schema.LIBRARIES not found; skipping --routines to avoid client/server mismatch.\n";
}

foreach ($databases as $db) {
    $safeName = preg_replace('/[^A-Za-z0-9_.-]/', '_', (string)$db);
    $filePath = $exportDir . DIRECTORY_SEPARATOR . "{$timestamp}_{$safeName}.sql";

    // Build mysqldump command with standard, safe export flags
    $cmdParts = [
        escapeshellcmd($mysqldump),
        '--host=' . escapeshellarg($host),
        '--port=' . (int)$port,
        '--user=' . escapeshellarg($user),
        '--single-transaction',            // Consistent snapshot without locking
        '--quick',
        '--triggers',
        '--hex-blob',
        '--set-gtid-purged=OFF',
        '--add-drop-table',
        '--default-character-set=utf8mb4',
        '--skip-lock-tables',              // Avoid explicit locks when using single-transaction
        '--databases', escapeshellarg((string)$db), // Include CREATE DATABASE / USE statements
        '--result-file=' . escapeshellarg($filePath),
    ];

    if ($supportsLibraries) {
        $cmdParts[] = '--routines';
    }
    if ($eventSchedulerOn) {
        $cmdParts[] = '--events';
    }

    $cmd = implode(' ', $cmdParts);

    echo "Exporting database '{$db}' to '{$filePath}' ...\n";

    $output = [];
    $exitCode = 0;
    exec($cmd . ' 2>&1', $output, $exitCode);

    if ($exitCode !== 0) {
        if (file_exists($filePath) && filesize($filePath) === 0) {
            @unlink($filePath);
        }
        fwrite(STDERR, "Failed to export '{$db}'. Exit code: {$exitCode}\n");
        if (!empty($output)) {
            fwrite(STDERR, implode(PHP_EOL, $output) . PHP_EOL);
        }
        continue; // Proceed with the next database
    }

    echo "Done: {$filePath}\n";
}

echo "All exports completed. Files are in: {$exportDir}\n";
