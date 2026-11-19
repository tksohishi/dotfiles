// The last part of a session transcript, cut to whole lines. A long session's transcript grows to hundreds of MB, and
// reading and parsing all of it on every prompt cost a hook seconds of CPU and hundreds of MB; the hooks only need the
// last few turns.
export async function transcriptTail(path: string, bytes = 4 << 20): Promise<string> {
  const file = Bun.file(path)
  if (file.size <= bytes) return file.text()
  const text = await file.slice(file.size - bytes).text()
  return text.slice(text.indexOf('\n') + 1)
}
