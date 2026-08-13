---
name: examine-video
description: Examine a video file (screen recording, demo, capture) by splitting it into frames and visually reviewing them against the user's question. Use whenever asked to check, review, verify, or describe the contents of a video file.
---
# Examine a video

Turn a video into frames, review them thoroughly, and answer exactly what was asked. This skill exists because a review once reported stale leftover frames from an earlier extraction as part of a new recording; the extraction script makes that failure mode impossible, so use it rather than ad-hoc ffmpeg.

## 1. Extract frames

```
video-frames <video> [interval-seconds]
```

The script (in `~/.dotfiles/bin/`, on PATH) probes duration, recreates `tmp/frames-<basename>/` fresh (trashing any previous run), extracts one frame per interval plus the true final frame, and asserts the body frame count against `ceil(duration / N)` ±1. It prints one `OK:` line with the counts; include that line in the final report. If it exits non-zero, stop and diagnose — never review a directory whose contents you can't account for.

Frame layout: `f001.png..fNNN.png` on a grid starting at t=0 (so f001 is the first frame; `fNNN` ≈ (NNN−1)×N seconds), plus `last.png` — extracted separately because the interval grid can stop short of the actual end, and recordings often hold the proof shot in their final moments.

Pick the interval so the body yields roughly 15-30 frames: the default N=3 suits a ~1 min video; go larger for long ones. For dense moments the user cares about (a dialog flashing by), re-extract just that range at full sampling:

```
ffmpeg -v error -ss <start> -to <end> -i <video> -vf 'fps=1,scale=1280:-1' tmp/frames-<basename>/dense-%03d.png
```

(Dense frames land in the same directory; they're additions from this run, not contamination.)

## 2. Examine thoroughly

- Delegate the bulk read to one subagent: give it the full ordered frame list (f001…fNNN, then last.png), the user's actual question, and ask for a frame-by-frame one-line map plus answers. Frames must be read in order — endpoint frames are where recordings start early or run long.
- Subagent visual claims are leads, not facts. Before reporting any decisive or alarming finding to the user (personal data on screen, an error state, a missing step), read that specific frame in the main context with your own eyes. If the harness discourages main-context image reads, use whatever exception path it documents for decisive verification.
- If two reads of the same frame disagree, trust neither; re-extract and look again.

## 3. Report what was asked

Answer the user's question first, citing frame numbers and timestamps. Include the script's `OK:` count line. Separate observed fact ("f06 shows the consent screen listing the Tasks permission") from judgment ("this likely satisfies the reviewer"). Offer clickable `file://` paths to decisive frames. Leave the frame directory in place until the user is done with it.
