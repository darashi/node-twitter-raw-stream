# Twitter Raw Stream

## Usage

    TwitterRawStream = require('twitter-raw-stream')

    stream = TwitterRawStream('username', 'password')
    stream.on 'data', (raw, message) ->
      console.log(raw)
      console.log(message)
