{* Smarty *}
{extends file='common.tpl'}
{block name=content}
<h1>Свежие комментарии</h1>
<ul class="pager">
    {if $comments.total > ($skip + 20)}<li class="next"><a href='?skip={$skip + 20}'>раньше &rarr;</a></li>{else}<li class="next disabled"><a href="#">раньше &rarr;</a></li>{/if}
    {if $skip > 0}<li class="previous"><a href='?skip={$skip - 20}'>&larr; позже</a></li>{else}<li class="previous disabled"><a href="#">&larr; позже</a></li>{/if}
</ul>
<table class="table"> 
{foreach item=comment from=$comments.c}
    <tr>
        <td><a href="/sentence.php?id={$comment.sent_id}">Предложение {$comment.sent_id}</a></td>
        <td>{$comment.user_name|htmlspecialchars}</td>
        <td>{$comment.ts|date_format:"%a %d.%m.%Y, %H:%M"}</td>
        <td><a href="/sentence.php?id={$comment.sent_id}#comm_{$comment.id}">{$comment.text|htmlspecialchars}</a></td>
    </tr>
{/foreach}
</table>
<ul class="pager">
    {if $comments.total > ($skip + 20)}<li class="next"><a href='?skip={$skip + 20}'>раньше &rarr;</a></li>{else}<li class="next disabled"><a href="#">раньше &rarr;</a></li>{/if}
    {if $skip > 0}<li class="previous"><a href='?skip={$skip - 20}'>&larr; позже</a></li>{else}<li class="previous disabled"><a href="#">&larr; позже</a></li>{/if}
</ul>
{/block}
