{* Smarty *}
<html>
<head>
<meta http-equiv='content' content='text/html;charset=utf-8'/>
<link rel='stylesheet' type='text/css' href='{$web_prefix}/css/main.css'/>
</head>
<body>
<div id='main'>
{include file='header.tpl'}
<div id='content'>
<table border='1' cellspacing='0' cellpadding='3'>
{foreach from=$history item=h}
<tr><td>{$h.set_id}<td>{$h.user_name|default:'Робот'}<td>{$h.timestamp|date_format:"%a %d.%m.%Y, %H:%M"}<td><a href="dict.php?act=edit&id={$h.lemma_id}">{$h.lemma_text}</a><td><a href="dict_diff.php?lemma_id={$h.lemma_id}&set_id={$h.set_id}">Изменения</a></tr>
{/foreach}
</table>
</div>
<div id='rightcol'>
{include file='right.tpl'}
</div>
<div id='fake'></div>
</div>
{include file='footer.tpl'}
</body>
</html>
