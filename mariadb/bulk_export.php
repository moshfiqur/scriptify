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
        '--routines',
        '--triggers',
        '--events',
        '--hex-blob',
        '--set-gtid-purged=OFF',
        '--add-drop-table',
        '--default-character-set=utf8mb4',
        '--skip-lock-tables',              // Avoid explicit locks when using single-transaction
        '--databases', escapeshellarg((string)$db), // Include CREATE DATABASE / USE statements
        '--result-file=' . escapeshellarg($filePath),
    ];

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
