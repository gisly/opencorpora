<?php
require_once('../lib/header_ajax.php');
require_once('../lib/lib_dict.php');

try {
    switch ($_POST['act']) {
        case 'forget':
            forget_pending_token($_POST['token_id'], $_POST['rev_id']);
            break;
        case 'update':
            update_pending_token($_POST['token_id'], $_POST['rev_id'], 0, (bool)$_POST['smart']);
            break;
        default:
            $result['error'] = 1;
    }
}
catch (Exception $e) {
    $result['error'] = 1;
}

log_timing(true);
die(json_encode($result));
?>
