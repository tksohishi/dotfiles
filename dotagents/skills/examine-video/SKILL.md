---
name: examine-video
description: Examine a video file (screen recording, demo, capture) by splitting it into frames and visually reviewing them against the user's question. Use whenever asked to check, review, verify, or describe the contents of a video file.
---
# Examine a video

Turn a video into frames, review them thoroughly, and answer exactly what was asked. Every step that looks like ceremony is load-bearing: this skill exists because a review once reported stale leftover frames from an earlier extraction as part of a new recording.

## 1. Working directory — always fresh

Derive the directory from the video filename inside the project-local `tmp/`: `tmp/frames-<basename>/` (never the OS temp dir).

- If it already exists, `trash` it first, then `mkdir -p`. Never extract into a directory that may hold files from a previous run — `mkdir -p` onto an existing dir is the contamination path.
- After extraction, the directory must contain only files from this run. If anything predates the extraction command, start over.

## 2. Probe before splitting

```
ffprobe -v error -show_entries format=duration -show_entries stream=width,height -of default=noprint_wrappers=1 <video>
```

Record the duration. Every later count check derives from it.

## 3. Split frames — first and last must be covered

Interval sampling alone misses the endpoints: `fps=1/N` timestamps frames mid-interval, so the true first and final frames (where recordings start early, run long, or hold the proof shot) fall outside the grid. Extract three things:

```
ffmpeg -v error -i <video> -vf 'fps=1/<N>,scale=1280:-1' <dir>/f%03d.png   # body
ffmpeg -v error -i <video> -vf 'select=eq(n\,0),scale=1280:-1' -frames:v 1 <dir>/first.png
ffmpeg -v error -sseof -1 -i <video> -update 1 -vf scale=1280:-1 <dir>/last.png
```

Pick `N` so the body yields roughly 15-30 frames (N=3 for a ~1 min video; larger for long ones). For dense moments the user cares about (a dialog flashing by), re-extract just that time range at `fps=1`.

## 4. Count assertion — non-negotiable

Before any frame is read, verify: body frame count == `ceil(duration / N)` (±1 for rounding), plus `first.png` and `last.png`. On mismatch, stop and diagnose — do not review a directory whose contents you can't account for. State the check's result ("54.0s / 3s → 18 frames, got 18 + first/last") in the final report.

## 5. Examine thoroughly

- Delegate the bulk read to one subagent: give it the full ordered frame list (first.png, f001…fNNN, last.png), the user's actual question, and ask for a frame-by-frame one-line map plus answers. Frames must be read in order — endpoint frames are where recordings start early or run long.
- Subagent visual claims are leads, not facts. Before reporting any decisive or alarming finding to the user (personal data on screen, an error state, a missing step), read that specific frame in the main context with your own eyes. If the harness discourages main-context image reads, use whatever exception path it documents for decisive verification.
- If two reads of the same frame disagree, trust neither; re-extract and look again.

## 6. Report what was asked

Answer the user's question first, citing frame numbers and timestamps (`fNNN` ≈ (NNN-1)×N seconds). Include the count-assertion line. Separate observed fact ("f06 shows the consent screen listing the Tasks permission") from judgment ("this likely satisfies the reviewer"). Offer clickable `file://` paths to decisive frames. Leave the frame directory in place until the user is done with it.
