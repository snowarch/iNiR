"use client"

import { useState, useEffect, useRef } from "react"
import { CopyButton } from "./copy-button"

const commands = [
  "git clone https://github.com/snowarch/inir.git",
  "cd inir",
  "./setup install",
]

const simulatedOutput = [
  { text: "Cloning into 'inir'...", type: "info" },
  { text: "remote: Enumerating objects: 2847", type: "info" },
  { text: "remote: Counting objects: 100% (447/447)", type: "info" },
  { text: "Receiving objects: 100% (2847/2847), 15.2MiB", type: "info" },
  { text: "", type: "empty" },
  { text: "==> Installing dependencies...", type: "success" },
  { text: "==> Setting up iNiR...", type: "success" },
  { text: "==> Done! Restart Niri to activate.", type: "done" },
]

export function AnimatedTerminal() {
  const [completedLines, setCompletedLines] = useState<string[]>([])
  const [activeLine, setActiveLine] = useState(0)
  const [charIndex, setCharIndex] = useState(0)
  const [done, setDone] = useState(false)
  const [showOutput, setShowOutput] = useState(false)
  const [started, setStarted] = useState(false)
  const ref = useRef<HTMLDivElement>(null)
  const fullText = commands.join("\n")

  useEffect(() => {
    if (!ref.current) return
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !started) {
          setStarted(true)
        }
      },
      { threshold: 0.3 }
    )
    observer.observe(ref.current)
    return () => observer.disconnect()
  }, [started])

  // Reset animation after completion for loop
  useEffect(() => {
    if (done && showOutput) {
      const resetTimer = setTimeout(() => {
        setCompletedLines([])
        setActiveLine(0)
        setCharIndex(0)
        setDone(false)
        setShowOutput(false)
      }, 5000)
      return () => clearTimeout(resetTimer)
    }
  }, [done, showOutput])

  useEffect(() => {
    if (!started || done) return
    if (activeLine >= commands.length) {
      setDone(true)
      setTimeout(() => setShowOutput(true), 300)
      return
    }

    const cmd = commands[activeLine]
    if (charIndex > cmd.length) {
      const timer = setTimeout(() => {
        setCompletedLines((prev) => [...prev, cmd])
        setActiveLine((prev) => prev + 1)
        setCharIndex(0)
      }, 300)
      return () => clearTimeout(timer)
    }

    const timer = setTimeout(
      () => setCharIndex((prev) => prev + 1),
      18 + Math.random() * 35
    )
    return () => clearTimeout(timer)
  }, [started, activeLine, charIndex, done])

  return (
    <div ref={ref} className="group relative overflow-hidden">
      {/* TUI titlebar */}
      <div className="flex items-center justify-between border-b-2 border-border px-4 py-2 bg-surface">
        <div className="flex items-center gap-3">
          <div className="flex gap-1.5">
            <span className="w-2.5 h-2.5 bg-error block" title="close" />
            <span className="w-2.5 h-2.5 bg-warning block" title="minimize" />
            <span className="w-2.5 h-2.5 bg-success block" title="maximize" />
          </div>
          <span className="font-mono text-[10px] text-text-dim uppercase tracking-widest ml-1">~/terminal</span>
        </div>
        <div className="flex items-center gap-2 font-mono text-[9px] text-text-dim">
          <span className="border border-border px-1.5 py-0.5">[bash]</span>
          <CopyButton text={fullText} />
        </div>
      </div>

      {/* Terminal content */}
      <div className="bg-[#080808] px-5 py-4 font-mono text-[12px] leading-[1.75] min-h-[160px] relative">
        <div className="absolute inset-x-0 top-0 h-4 bg-gradient-to-b from-main/3 to-transparent pointer-events-none" />

        {showOutput && (
          <div className="mb-3 space-y-0.5">
            {simulatedOutput.map((line, i) => (
              <div
                key={i}
                className={`${
                  line.type === "done"
                    ? "text-main font-bold"
                    : line.type === "success"
                    ? "text-success"
                    : line.type === "info"
                    ? "text-text-dim"
                    : "h-2"
                } opacity-0 animate-[fadeIn_0.18s_ease-out_forwards]`}
                style={{ animationDelay: `${i * 70}ms` }}
              >
                {line.type !== "empty" && (
                  <>
                    <span className="text-foreground/20 mr-2 select-none">›</span>
                    {line.text}
                  </>
                )}
              </div>
            ))}
            <div className="h-1" />
          </div>
        )}

        {completedLines.map((line, i) => (
          <div key={i} className="flex items-start gap-0">
            <span className="text-main select-none mr-3 font-bold w-3 flex-shrink-0">$</span>
            <span className="text-foreground/85">{line}</span>
          </div>
        ))}

        {!done && started && activeLine < commands.length && (
          <div className="flex items-start gap-0">
            <span className="text-main select-none mr-3 font-bold w-3 flex-shrink-0">$</span>
            <span className="text-foreground/85">
              {commands[activeLine].slice(0, charIndex)}
            </span>
            <span className="inline-block w-[8px] h-[14px] bg-main align-middle animate-[blink_1s_step-end_infinite] ml-px" />
          </div>
        )}

        {!started && (
          <div className="flex items-start gap-0">
            <span className="text-main select-none mr-3 font-bold w-3 flex-shrink-0">$</span>
            <span className="inline-block w-[8px] h-[14px] bg-main align-middle animate-[blink_1s_step-end_infinite]" />
          </div>
        )}

        {done && !showOutput && (
          <div className="flex items-start gap-0">
            <span className="text-main select-none mr-3 font-bold w-3 flex-shrink-0">$</span>
            <span className="inline-block w-[8px] h-[14px] bg-main align-middle animate-[blink_1s_step-end_infinite]" />
          </div>
        )}
      </div>

      {/* TUI status bar */}
      <div className="flex items-center justify-between border-t-2 border-border px-4 py-1.5 bg-surface font-mono text-[9px]">
        <span className="flex items-center gap-2">
          {done ? (
            <>
              <span className="text-success font-bold">[✓]</span>
              <span className="text-text-dim uppercase tracking-widest">completed</span>
            </>
          ) : (
            <>
              <span className="text-main font-bold animate-pulse">[…]</span>
              <span className="text-text-dim uppercase tracking-widest">running</span>
            </>
          )}
        </span>
        <span className="text-text-dim/50">zsh · 80×24</span>
      </div>
    </div>
  )
}
