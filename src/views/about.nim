# SPDX-License-Identifier: AGPL-3.0-only
import strformat
import karax/[karaxdsl, vdom], markdown

const
  date = staticExec("git show -s --format=\"%cd\" --date=format:\"%Y.%m.%d\"")
  hash = staticExec("git log -1 --format=\"%h\"")
  link = "https://github.com/acarasimon96/nitter-ft/commit/" & hash
  version = &"{date}-{hash}"

let
  about = markdown(readFile("public/md/about.md"))
  feature = markdown(readFile("public/md/feature.md"))

proc renderAbout*(): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    verbatim about
    h2: text "Instance info"
    p:
      text "Version "
      a(href=link): text version

proc renderFeature*(): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    verbatim feature
