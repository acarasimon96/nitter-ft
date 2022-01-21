# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat
import karax/[karaxdsl, vdom, vstyles]

import renderutils, search
import ".."/[types, utils, formatters]

proc renderStat(num: int; class: string; text=""): VNode =
  let t = if text.len > 0: text else: class
  buildHtml(li(class=class)):
    span(class="profile-stat-header"): text capitalizeAscii(t)
    span(class="profile-stat-num"):
      text insertSep($num, ',')

proc renderProfileCard*(profile: Profile; prefs: Prefs, path: string): VNode =
  buildHtml(tdiv(class="profile-card")):
    tdiv(class="profile-card-info"):
      let
        url = getPicUrl(profile.getUserPic())
        size =
          if prefs.autoplayGifs and profile.userPic.endsWith("gif"): ""
          else: "_400x400"

      a(class="profile-card-avatar", href=url, target="_blank"):
        genImg(profile.getUserPic(size))

      tdiv(class="profile-card-tabs-name-and-follow"):
        tdiv():
          linkUser(profile, class="profile-card-fullname")
          linkUser(profile, class="profile-card-username")
        let following = isFollowing(profile.username, prefs.following)
        if not following:
          buttonReferer "/follow/" & profile.username, "Follow", path, "profile-card-follow-button"
        else:
          buttonReferer "/unfollow/" & profile.username, "Unfollow", path, "profile-card-follow-button"

    tdiv(class="profile-card-extra"):
      if profile.bio.len > 0:
        tdiv(class="profile-bio"):
          p(dir="auto"):
            verbatim replaceUrls(profile.bio, prefs)

      if profile.location.len > 0:
        tdiv(class="profile-location"):
          span: icon "location"
          let (place, url) = getLocation(profile)
          if url.len > 1:
            a(href=url): text place
          elif "://" in place:
            a(href=place): text place
          else:
            span: text place

      if profile.website.len > 0:
        tdiv(class="profile-website"):
          span:
            let url = replaceUrls(profile.website, prefs)
            icon "link"
            a(href=url): text shortLink(url)

      tdiv(class="profile-joindate"):
        span(title=getJoinDateFull(profile)):
          icon "calendar", getJoinDate(profile)

      tdiv(class="profile-card-extra-links"):
        ul(class="profile-statlist"):
          renderStat(profile.tweets, "posts", text="Tweets")
          renderStat(profile.following, "following")
          renderStat(profile.followers, "followers")
          renderStat(profile.likes, "likes")

proc renderPhotoRail(profile: Profile; photoRail: PhotoRail): VNode =
  let count = insertSep($profile.media, ',')
  buildHtml(tdiv(class="photo-rail-card")):
    tdiv(class="photo-rail-header"):
      a(href=(&"/{profile.username}/media")):
        icon "picture", count & " Photos and videos"

    input(id="photo-rail-grid-toggle", `type`="checkbox")
    label(`for`="photo-rail-grid-toggle", class="photo-rail-header-mobile"):
      icon "picture", count & " Photos and videos"
      icon "down"

    tdiv(class="photo-rail-grid"):
      for i, photo in photoRail:
        if i == 16: break
        a(href=(&"/{profile.username}/status/{photo.tweetId}#m")):
          genImg(photo.url & (if "format" in photo.url: "" else: ":thumb"))

proc renderBanner(banner: string): VNode =
  buildHtml():
    if banner.startsWith('#'):
      a(style={backgroundColor: banner})
    else:
      a(href=getPicUrl(banner), target="_blank"):
        genImg(banner)

proc renderProtected(username: string): VNode =
  buildHtml(tdiv(class="timeline-container")):
    tdiv(class="timeline-header timeline-protected"):
      h2: text "This account's tweets are protected."
      p: text &"Only confirmed followers have access to @{username}'s tweets."

proc renderProfile*(profile: Profile; timeline: var Timeline;
                    photoRail: PhotoRail; prefs: Prefs; path: string): VNode =
  timeline.query.fromUser = @[profile.username]
  buildHtml(tdiv(class="profile-tabs")):
    if not prefs.hideBanner:
      tdiv(class="profile-banner"):
        if profile.banner.len > 0:
          renderBanner(profile.banner)

    let sticky = if prefs.stickyProfile: " sticky" else: ""
    tdiv(class=(&"profile-tab{sticky}")):
      renderProfileCard(profile, prefs, path)
      if photoRail.len > 0:
        renderPhotoRail(profile, photoRail)

    if profile.protected:
      renderProtected(profile.username)
    else:
      renderTweetSearch(timeline, prefs, path)
