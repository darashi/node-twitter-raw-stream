{EventEmitter} = require('events')
https = require('https')

class TwitterRawStream extends EventEmitter
  constructor: (@username, @password) ->
    @numReceived = 0
    @numRetry = 0
    @stallThresholdInSecs = 5
    @lastReceived = new Date()
    @lastChecked = null
    @res = null
    @connected = false

    @on 'data', (raw, message) =>
      @numReceived += 1
      @lastReceived = new Date()
      @numRetry = 0
      if message.created_at
        t = Date.parse(message.created_at)
        if !@mostRecent || @mostRecent < t
          @mostRecent = t

  start: ->
    @lastChecked = new Date()
    setInterval(@monitor, 2*1000)
    @connect()
    @on 'end', =>
      wait = 1000 * Math.pow(2, @numRetry)
      @emit 'reconnect', @numRetry, wait
      @numRetry += 1
      setTimeout =>
        @connect()
      , wait

  connect: ->
    options =
      host: 'stream.twitter.com'
      path: '/1/statuses/sample.json'
      auth: @username + ':' + @password

    req = https.request options, (res) =>
      @res = res
      res.setEncoding('utf8')
      buffer = ''

      if res.statusCode == 200
        @emit 'connect'
        @connected = true
      else
        @emit 'http-error', res

      res.on 'end', =>
        @res = null
        @connected = false
        @emit 'end'

      res.on 'data', (chunk) =>
        buffer += chunk
        while((index = buffer.indexOf('\r\n')) > -1)
          raw = buffer.slice(0, index)
          buffer = buffer.slice(index + 2)
          try
            message = JSON.parse(raw)
            @emit 'data', raw, message
          catch e
            @emit 'error', e
    req.end()

  monitor: =>
    now = new Date()
    delta = (now - @lastChecked) / 1000
    tps = @numReceived / delta
    delay = (now - @mostRecent) / 1000
    last = (now - @lastReceived) / 1000
    status =
      tps: tps
      delay: delay
      last: last
      numReceived: @numReceived
      from: @lastChecked
      to: now

    if @connected
      @emit 'status', status

    if @connected && last > @stallThresholdInSecs
      @emit 'stalled'
      @res.socket.end()

    @numReceived = 0
    @lastChecked = new Date()

module.exports = TwitterRawStream
