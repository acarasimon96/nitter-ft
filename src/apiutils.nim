# SPDX-License-Identifier: AGPL-3.0-only
import httpclient, asyncdispatch, options, sequtils, strutils, uri
import jsony, packedjson, zippy
import types, tokens, consts, parserutils, http_pool
from experimental/types/common import Errors, ErrorObj

const
  rlRemaining = "x-rate-limit-remaining"
  rlReset = "x-rate-limit-reset"

var pool: HttpPool

proc genParams*(pars: openArray[(string, string)] = @[]; cursor="";
                count="20"; ext=true): seq[(string, string)] =
  result = timelineParams
  for p in pars:
    result &= p
  if ext:
    result &= ("ext", "mediaStats")
  if count.len > 0:
    result &= ("count", count)
  if cursor.len > 0:
    # The raw cursor often has plus signs, which sometimes get turned into spaces,
    # so we need to them back into a plus
    if " " in cursor:
      result &= ("cursor", cursor.replace(" ", "+"))
    else:
      result &= ("cursor", cursor)

proc genHeaders*(token: Token = nil): HttpHeaders =
  result = newHttpHeaders({
    "connection": "keep-alive",
    "authorization": auth,
    "content-type": "application/json",
    "x-guest-token": if token == nil: "" else: token.tok,
    "x-twitter-active-user": "yes",
    "authority": "api.twitter.com",
    "accept-encoding": "gzip",
    "accept-language": "en-US,en;q=0.9",
    "accept": "*/*",
    "DNT": "1"
  })

template updateToken() =
  if api != Api.search and resp.headers.hasKey(rlRemaining):
    let
      remaining = parseInt(resp.headers[rlRemaining])
      reset = parseInt(resp.headers[rlReset])
    token.setRateLimit(api, remaining, reset)

template fetchImpl(result, fetchBody) {.dirty.} =
  once:
    pool = HttpPool()

  var token = await getToken(api)
  if token.tok.len == 0:
    raise rateLimitError()

  try:
    var resp: AsyncResponse
    result = pool.use(genHeaders(token)):
      resp = await c.get($url)
      await resp.body

    if result.len > 0:
      if resp.headers.getOrDefault("content-encoding") == "gzip":
        result = uncompress(result, dfGzip)
      else:
        echo "non-gzip body, url: ", url, ", body: ", result

    fetchBody

    release(token, used=true)

    if resp.status == $Http400:
      raise newException(InternalError, $url)
  except InternalError as e:
    raise e
  except Exception as e:
    echo "error: ", e.name, ", msg: ", e.msg, ", token: ", token[], ", url: ", url
    if "length" notin e.msg and "descriptor" notin e.msg:
      release(token, invalid=true)
    raise rateLimitError()

proc fetch*(url: Uri; api: Api): Future[JsonNode] {.async.} =
  var body: string
  fetchImpl body:
    if body.startsWith('{') or body.startsWith('['):
      result = parseJson(body)
    else:
      echo resp.status, ": ", body
      result = newJNull()

    updateToken()

    let error = result.getError
    if error in {invalidToken, forbidden, badToken}:
      echo "fetch error: ", result.getError
      release(token, invalid=true)
      raise rateLimitError()

proc fetchRaw*(url: Uri; api: Api): Future[string] {.async.} =
  fetchImpl result:
    if not (result.startsWith('{') or result.startsWith('[')):
      echo resp.status, ": ", result
      result.setLen(0)

    updateToken()

    if result.startsWith("{\"errors"):
      let errors = result.fromJson(Errors).errors
      if errors.anyIt(it.code in {invalidToken, forbidden, badToken}):
        echo "fetch error: ", errors
        release(token, invalid=true)
        raise rateLimitError()
