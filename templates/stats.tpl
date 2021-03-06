{* Smarty *}
{extends file='common.tpl'}
{block name=content}
<script type="text/javascript">
$(document).ready(function(){
{literal}
    $("#show_more_users").click(function(event){
        $("#users_table tr:hidden").each(function(i, el) {
            $(el).show();
            if (i == 19)
                return false;
        });
        if ($("#users_table tr:hidden").length == 0)
            $(this).hide();
        event.preventDefault();
    });
    $("#show_user").click(function(event) {
        $("a[name='user{/literal}{if $is_logged}{$smarty.session.user_id}{/if}{literal}']").closest('tr').show().addClass('bgyellow');
    });
    $("a[name='" + location.hash.substring(1) +"']").closest('tr').addClass('bgyellow');
{/literal}
});
</script>
<h1>Статистика</h1>
<ul class="nav nav-tabs">
    <li class="active"><a href="?page=stats&weekly">Активность за неделю</a></li>
    <li><a href="?page=genre_stats">Состав корпуса</a></li>
    <li><a href="?page=tag_stats">По тегам</a></li>
    <li><a href="?page=charts">Графики</a></li>
</ul>
{if isset($smarty.get.weekly)}<p>См. также <a href="?page=stats">активность за всё время</a>.</p>{/if}
<a name="users"></a>
<h3>Участники по количеству размеченных примеров (всего размечено {$ma_count})</h3>
<table class="table table-condensed" id="users_table">
<tr>
    <th rowspan='2'>#</th>
    <th rowspan='2'>Участник</th>
    {if !isset($smarty.get.weekly)}<th rowspan='2'>Рейтинг</th>{/if}
    <th rowspan='2'>Ответов</th>
    <th colspan='2'>В завершённых пулах</th>
    {if !isset($smarty.get.weekly)}<th colspan='2'>В проверенных пулах</th>{/if}
    <th rowspan='2'>Последняя<br/>активность</th></tr>
<tr><th>Размечено<th>% расхождений{if !isset($smarty.get.weekly)}<th>Размечено<th>% ошибок{/if}</tr>
{foreach item=s from=$user_stats.annotators}
    <tr {if $s@iteration>20 && (!isset($smarty.session.user_id) || $smarty.session.user_id != $s.user_id)}style="display:none;"{/if}>
        <td><a name="user{$s.user_id}"></a>{$s@iteration}
        <td><a href="/user.php?id={$s.user_id}">{$s.fin.user_name}</a>
        {if !isset($smarty.get.weekly)}<td>{$s.rating}</td>{/if}
        <td>{$s.total}
        <td>{$s.fin.value|default:'0'}
        <td>{if isset($s.fin.divergence)}{$s.fin.divergence|string_format:"%.1f%%"}{else}&mdash;{/if}
        {if !isset($smarty.get.weekly)}<td>{$s.fin.moderated|default:'0'}
        <td>{$s.fin.error_rate|string_format:"%.1f%%"}{/if}
        <td>
            {if $s.fin.last_active > $user_stats.timestamp_today}сегодня в {$s.fin.last_active|date_format:"%H:%M"}
            {elseif $s.fin.last_active > $user_stats.timestamp_yesterday}вчера в {$s.fin.last_active|date_format:"%H:%M"}
            {elseif $s.fin.last_active == 0}давно
            {else}{$s.fin.last_active|date_format:"%d.%m.%y"}{/if}
    </tr>
{/foreach}
</table>
<a href="#" class="pseudo" id="show_more_users">Показать ещё 20 участников</a>
{if $is_logged}или <a href="#user{$smarty.session.user_id}" class="pseudo" id="show_user">найти меня</a>{/if}
<h3>Команды по количеству размеченных примеров</h3>
<table class="table">
    <tr><th>#</th><th>Название</th><th>Количество участников<br/>активных/всего</th><th>Размечено примеров</th>{if !isset($smarty.get.weekly)}<th>Проверено</th><th>% ошибок</th>{/if}</tr>
    {foreach $user_stats.teams as $i=>$team name=x}
        <tr>
            <td>{$team@iteration}</td>
            <td><a href="?page=stats&amp;team={$i}">{$team.name}</a></td>
            <td>{$team.active_users}/{$team.num_users}</td>
            <td>{$team.total}</td>
            {if !isset($smarty.get.weekly)}<td>{$team.moderated}</td>
            <td>{$team.error_rate|string_format:"%.1f%%"}</td>{/if}
        </tr>
    {/foreach}
</table>
<h3>Участники по количеству добавленных предложений</h3>
<ol>
{foreach item=s from=$user_stats.added_sentences}
    <li>{$s.user_name} ({$s.value})</li>
{/foreach}
</ol>
{/block}
