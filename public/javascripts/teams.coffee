$('#page.teams-show .invites a').live 'click', (e) ->
  e.preventDefault()
  $t = $(this).hide()
  $n = $t.next().show().html 'sending&hellip;'
  $.post @href, ->
    $n.text('done').delay(500).fadeOut 'slow', -> $t.show()

$('#page.teams-show .heart').live 'click', (e) ->
  e.preventDefault()
  $this = $(this)
  team = $this.attr('data-team')
  if $this.hasClass('loved')
    $.post '/teams/'+team+'/nolove', ->
      $this.removeClass('loved')
  else
    $.post '/teams/'+team+'/love', ->
      $this.addClass('loved')

$('#page.teams-edit').each ->
  $('a.scary').click ->
    $this = $(this)
    pos = $this.position()
    form = $('form.delete')
    form
      .fadeIn('fast')
      .css
        left: pos.left + ($this.width() - form.outerWidth())/2
        top: pos.top + ($this.height() - form.outerHeight())/2
    false
  $('form.delete a').click ->
    $(this).closest('form').fadeOut('fast')
    false
