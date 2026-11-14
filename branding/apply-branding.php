<?php
// Apply supported Moodle settings after installation/upgrades, once per design revision.
define('CLI_SCRIPT', true);
require '/var/www/html/config.php';

$directory = '/usr/local/share/carbono-campus';
$html = file_get_contents($directory . '/welcome.html');
$css = file_get_contents($directory . '/campus.css');
$js = file_get_contents($directory . '/login.js');
if ($html === false || $css === false || $js === false) {
    throw new RuntimeException('Carbono Forestal branding files are missing.');
}
$version = hash('sha256', $html . $css . $js . $CFG->wwwroot . 'campus-v1');
if (get_config('local_carbonocampus', 'brandingrevision') === $version) {
    echo "railway: campus branding unchanged\n";
    exit(0);
}
$assetbase = rtrim($CFG->wwwroot, '/') . '/carbono-campus';
set_config('auth_instructions', str_replace('{{assetbase}}', htmlspecialchars($assetbase, ENT_QUOTES, 'UTF-8'), $html));

// Keep administrator additions; replace only the block owned by this branding.
$start = '<!-- carbono-campus:start -->';
$end = '<!-- carbono-campus:end -->';
$head = (string)($CFG->additionalhtmlhead ?? '');
$head = preg_replace('/<!-- carbono-campus:start -->.*?<!-- carbono-campus:end -->/s', '', $head);
$icon = htmlspecialchars($assetbase . '/icon.png', ENT_QUOTES, 'UTF-8');
set_config('additionalhtmlhead', trim($head) . "\n" . $start
    . "\n" . '<link rel="icon" type="image/png" href="' . $icon . '">'
    . "\n" . '<meta name="theme-color" content="#123d2c">'
    . "\n<style>\n" . $css . "\n</style>\n<script>\n" . $js . "\n</script>\n" . $end);

$DB->update_record('course', (object)[
    'id' => SITEID,
    'fullname' => 'Carbono Forestal · Campus Virtual',
    'shortname' => 'Carbono Forestal',
]);
set_config('brandingrevision', $version, 'local_carbonocampus');
purge_all_caches();
echo "railway: Carbono Forestal campus branding applied\n";
