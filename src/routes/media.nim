# SPDX-License-Identifier: AGPL-3.0-only
import uri, strutils, httpclient, os, hashes, base64, re
import asynchttpserver, asyncstreams, asyncfile, asyncnet

import jester

import router_utils
import ".."/[types, formatters, agents, utils]

export asynchttpserver, asyncstreams, asyncfile, asyncnet
export httpclient, os, strutils, asyncstreams, base64, re

const
  m3u8Mime* = "application/vnd.apple.mpegurl"
  maxAge* = "max-age=604800"

let mediaAgent* = getAgent()

proc safeFetch*(url, agent: string): Future[string] {.async.} =
  let client = newAsyncHttpClient(userAgent=agent)
  try: result = await client.getContent(url)
  except: discard
  finally: client.close()

template respond*(req: asynchttpserver.Request; headers) =
  var msg = "HTTP/1.1 200 OK\c\L"
  for k, v in headers:
    msg.add(k & ": " & v & "\c\L")

  msg.add "\c\L"
  yield req.client.send(msg)

proc proxyMedia*(req: jester.Request; url: string): Future[HttpCode] {.async.} =
  result = Http200
  let
    request = req.getNativeReq()
    client = newAsyncHttpClient(userAgent=mediaAgent)

  try:
    let res = await client.get(url)
    if res.status != "200 OK":
      return Http404

    let hashed = $hash(url)
    if request.headers.getOrDefault("If-None-Match") == hashed:
      return Http304

    let contentLength =
      if res.headers.hasKey("content-length"):
        res.headers["content-length", 0]
      else:
        ""

    let headers = newHttpHeaders({
      "Content-Type": res.headers["content-type", 0],
      "Content-Length": contentLength,
      "Cache-Control": maxAge,
      "ETag": hashed
    })

    respond(request, headers)

    var (hasValue, data) = (true, "")
    while hasValue:
      (hasValue, data) = await res.bodyStream.read()
      if hasValue:
        await request.client.send(data)
    data.setLen 0
  except HttpRequestError, ProtocolError, OSError:
    result = Http404
  finally:
    client.close()

template check*(code): untyped =
  if code != Http200:
    resp code
  else:
    enableRawMode()
    break route

proc decoded*(req: jester.Request; index: int): string =
  let
    based = req.matches[0].len > 1
    encoded = req.matches[index]
  if based: decode(encoded)
  else: decodeUrl(encoded)

proc createMediaRouter*(cfg: Config) =
  router media:
    get "/pic/?":
      resp Http404

    get re"^\/pic\/(enc)?\/?(.+)":
      var url = decoded(request, 1)
      if "twimg.com" notin url:
        url.insert(twimg)
      if not url.startsWith(https):
        url.insert(https)

      let uri = parseUri(url)
      cond isTwitterUrl(uri) == true

      let code = await proxyMedia(request, url)
      check code

    get re"^\/video\/(enc)?\/?(.+)\/(.+)$":
      let url = decoded(request, 2)
      cond "http" in url

      if getHmac(url) != request.matches[1]:
        resp showError("Failed to verify signature", cfg)

      if ".mp4" in url or ".ts" in url or ".m4s" in url:
        let code = await proxyMedia(request, url)
        check code

      var content: string
      if ".vmap" in url:
        let m3u8 = getM3u8Url(await safeFetch(url, mediaAgent))
        if m3u8.len > 0:
          content = await safeFetch(url, mediaAgent)
        else:
          resp Http404

      if ".m3u8" in url:
        let vid = await safeFetch(url, mediaAgent)
        content = proxifyVideo(vid, cookiePref(proxyVideos))

      resp content, m3u8Mime
