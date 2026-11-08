## Using it

- Click the download icon in the bar → panel opens.
- Paste a link, press Enter or hit the download button.
- Bar icon shows a live `NN%` while downloading; panel shows the same
  plus the current status line.
- Settings → Plugins → YouTube Downloader (gear icon) lets you set the
  download folder, cap max resolution, or switch to audio-only.

## Known limitations

- **No cancel button.** The documented `noctalia.runStream()` API
  doesn't hand back a process handle, so there's no way to send SIGINT
  from Luau. If Noctalia adds a handle/kill method to `runStream`
  later, this is the first thing to wire up.
- **Completion detection is heuristic.** `runStream()` also has no
  "process exited" callback — only stdout lines — so "done" is
  inferred from yt-dlp's own output (a completed merge step, or "already
  downloaded"). This works for the normal video+audio path, but
  audio-only downloads (no merge step) don't have a reliable completion
  line to key off of yet, so the "done" state may not always flip
  automatically — the file downloads fine either way. Worth revisiting
  if `runStream` gets a completion/exit callback in a future release.
- One download at a time — starting a second while one's running is a
  no-op until the first is detected as finished.
