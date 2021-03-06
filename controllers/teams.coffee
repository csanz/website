_ = require 'underscore'
colors = require 'colors'
app = require '../config/app'
{ ensureAuth } = require '../lib/route-middleware'
Team = app.db.model 'Team'
Vote = app.db.model 'Vote'

# middleware
loadTeam = (req, res, next) ->
  if id = req.param('id')
    try
      Team.findById id, (err, team) ->
        return next err if err
        return next 404 unless team
        req.team = team
        next()
    catch error
      throw error unless error.message == 'Id cannot be longer than 12 bytes'
      return next 404
  else
    next()

loadPeople = (req, res, next) ->
  req.team.people (err, people) ->
    return next err if err
    req.people = people
    next()

loadVotes = (req, res, next) ->
  if (!app.enabled('voting') || !req.user)
    return next()
  Vote.findOne { type:'upvote', team_id: req.team.id, person_id: req.user.id }, (err, vote) ->
    return next err if err
    req.user.upvote = vote.upvote if vote
    next()

ensureAccess = (req, res, next) ->
  return next 401 unless req.team.includes(req.user, req.session.team) or req.user?.admin
  next()

# index
app.get '/teams', (req, res, next) ->
  Team.find {}, {}, sort: [['updatedAt', -1]], (err, teams) ->
    return next err if err
    res.render2 'teams', teams: teams

# new
app.get '/teams/new', (req, res, next) ->
  Team.canRegister (err, yeah) ->
    return next err if err
    if yeah
      team = new Team
      team.emails = [ req.user.github.email ] if req.loggedIn
      res.render2 'teams/new', team: team
    else
      res.render2 'teams/max'

# create
app.post '/teams', (req, res, next) ->
  team = new Team req.body
  team.save (err) ->
    return next err if err and err.name != 'ValidationError'
    if team.errors
      res.render2 'teams/new', team: team
    else
      req.session.team = team.code
      res.redirect "/teams/#{team.id}"

# show (join)
app.get '/teams/:id', [loadTeam, loadPeople, loadVotes], (req, res) ->
  req.session.invite = req.param('invite') if req.param('invite')
  res.render2 'teams/show'
    team: req.team
    people: req.people
    voting: app.enabled('voting')
    votes: []
    upvoted: !!(req.user && req.user.upvote)

# resend invitation
app.all '/teams/:id/invites/:inviteId', [loadTeam, ensureAccess], (req, res) ->
  req.team.invites.id(req.param('inviteId')).send(true)
  res.redirect "/teams/#{req.team.id}"

# edit
app.get '/teams/:id/edit', [loadTeam, loadPeople, ensureAccess], (req, res) ->
  res.render2 'teams/edit', team: req.team, people: req.people

# update
app.put '/teams/:id', [loadTeam, ensureAccess], (req, res, next) ->
  _.extend req.team, req.body
  req.team.save (err) ->
    return next err if err and err.name != 'ValidationError'
    if req.team.errors
      req.team.people (err, people) ->
        return next err if err
        res.render2 'teams/edit', team: req.team, people: people
    else
      res.redirect "/teams/#{req.team.id}"
  null

# delete
app.delete '/teams/:id', [loadTeam, ensureAccess], (req, res, next) ->
  req.team.remove (err) ->
    return next err if err
    res.redirect '/teams'

# upvote
app.post '/teams/:id/love', [loadTeam, ensureAuth], (req, res) ->
  team_id = req.team.id
  person_id = req.user.id
  console.log( 'team'.cyan, team_id, 'voter'.cyan, person_id, 'love'.red )
  Vote.findOne { type:'upvote', team_id: team_id, person_id: person_id }, (err, vote) ->
    console.log arguments
    return res.send 400 if err
    if not vote
      vote = new Vote
      vote.type = 'upvote'
      vote.person_id = person_id
      vote.team_id = team_id
    vote.love()
    vote.save (err) ->
      return res.send 400 if err
      res.send 'love'

# un-upvote
app.post '/teams/:id/nolove', [loadTeam, ensureAuth], (req, res) ->
  console.log( 'team'.cyan, req.team.id, 'voter'.cyan, req.user.id, 'nolove'.red )
  Vote.findOne { type:'upvote', team_id: req.team.id, person_id: req.user.id }, (err, vote) ->
    return res.send 400 if err
    vote.nolove()
    vote.save (err) ->
      return res.send 400 if err
      res.send 'nolove'
