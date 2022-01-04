# SPDX-License-Identifier: AGPL-3.0-only
import strutils, uri

import jester

import router_utils
import ".."/[types, redis_cache, api]
import ../views/[general, timeline, list]
export getListTimeline, getGraphList

template respList*(list, timeline, title, vnode: typed) =
  if list.id.len == 0 or list.name.len == 0:
    resp Http404, showError("List " & @"id" & " not found", cfg)

  let
    html = renderList(vnode, timeline.query, list)
    rss = "/i/lists/$1/rss" % [@"id"]

  resp renderMain(html, request, cfg, prefs, titleText=title, rss=rss, banner=list.banner)

proc createListRouter*(cfg: Config) =
  router list:
    get "/@name/lists/@slug/?":
      cond '.' notin @"name"
      cond @"name" != "i"
      cond @"slug" != "memberships"
      let
        slug = decodeUrl(@"slug")
        list = await getCachedList(@"name", slug)
      if list.id.len == 0:
        resp Http404, showError("List \"" & @"slug" & "\" not found", cfg)
      redirect("/i/lists/" & list.id)

    get "/i/lists/@id/?":
      cond '.' notin @"id"
      let
        prefs = cookiePrefs()
        list = await getCachedList(id=(@"id"))
        title = "@" & list.username & "/" & list.name
        timeline = await getListTimeline(list.id, getCursor())
        vnode = renderTimelineTweets(timeline, prefs, request.path)
      respList(list, timeline, title, vnode)

    get "/i/lists/@id/members":
      cond '.' notin @"id"
      let
        prefs = cookiePrefs()
        list = await getCachedList(id=(@"id"))
        title = "@" & list.username & "/" & list.name
        members = await getListMembers(list, getCursor())
      respList(list, members, title, renderTimelineUsers(members, prefs, request.path))
