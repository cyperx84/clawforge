package main

import (
	"time"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

// AnimationTickMsg advances the forge startup animation by one frame.
type AnimationTickMsg time.Time

// AnimationDoneMsg signals that the startup animation has completed.
type AnimationDoneMsg struct{}

const frameDuration = 140 * time.Millisecond

// forgeFrames contains the emoji animation frames for the forge startup sequence.
// 10 frames @ 140ms = ~1.4s total.
// Each frame is centered by lipgloss — emoji are kept spaced to avoid double-width
// alignment drift across different terminal emulators.
var forgeFrames = [...]string{

	// Frame 0 — Cold forge: nothing active yet
	`
  ⚒️   C L A W F O R G E   ⚒️


        ⬛  ⬛  ⬛  ⬛  ⬛

        ⬛             ⬛

        ⬛  ⬛  ⬛  ⬛  ⬛


      · · · initializing · · ·
`,

	// Frame 1 — First ember: a single spark at the base
	`
  ⚒️   C L A W F O R G E   ⚒️


        ⬛  ⬛  ⬛  ⬛  ⬛

        ⬛      🟠     ⬛

        ⬛  ⬛  ⬛  ⬛  ⬛


      · · · heating forge · · ·
`,

	// Frame 2 — Embers glow: fire building
	`
  ⚒️   C L A W F O R G E   ⚒️


        ⬛  ⬛  ⬛  ⬛  ⬛

        ⬛   🔥  🟠  🔥  ⬛

        ⬛  ⬛  ⬛  ⬛  ⬛


      · · · fire rising · · ·
`,

	// Frame 3 — Full fire: forge is hot
	`
  ⚒️   C L A W F O R G E   ⚒️


        🟥  🟥  🟥  🟥  🟥

        🟥   🔥  🔥  🔥  🟥

        🟥  🟥  🟥  🟥  🟥


      · · · forge is hot · · ·
`,

	// Frame 4 — Hammer raised: agent ready to strike
	`
  ⚒️   C L A W F O R G E   ⚒️

            🔨

        🟥  🟥  🟥  🟥  🟥

        🟥   🔥  🔥  🔥  🟥

        🟥  🟥  🟥  🟥  🟥


      · · · agents loading · · ·
`,

	// Frame 5 — STRIKE: hammer hits the forge
	`
  ⚒️   C L A W F O R G E   ⚒️


        ⚡  ⚡  💥  ⚡  ⚡

        ⚡   🔥  🔨  🔥  ⚡

        ⚡  ⚡  ✨  ⚡  ⚡


      · · · FORGING AGENTS · · ·
`,

	// Frame 6 — Sparks fly: maximum energy
	`
  ⚒️   C L A W F O R G E   ⚒️

   ✨      ⚡  💥  ⚡      ✨

        ⚡   🔥  🔥  🔥  ⚡

   ✨      ⚡  ✨  ⚡      ✨


      · · · SPARKS FLYING · · ·
`,

	// Frame 7 — Cooling: quench in blue
	`
  ⚒️   C L A W F O R G E   ⚒️


        💧  💧  💧  💧  💧

        💧   🌊  🔵  🌊  💧

        💧  💧  💧  💧  💧


      · · · quenching · · ·
`,

	// Frame 8 — Agents emerge: bots ready
	`
  ⚒️   C L A W F O R G E   ⚒️


        🤖        🤖        🤖


           ready to deploy


      · · · spawning fleet · · ·
`,

	// Frame 9 — READY: full fleet online
	`
  ✅   C L A W F O R G E   ✅


        🤖  🤖  🤖  🤖  🤖

              ONLINE

        ⚒️  fleet forged  ⚒️


`,
}

// animationTick returns a command that sends an AnimationTickMsg after frameDuration.
func animationTick() tea.Cmd {
	return tea.Tick(frameDuration, func(t time.Time) tea.Msg {
		return AnimationTickMsg(t)
	})
}

// renderAnimation renders the current animation frame centered in the terminal.
func renderAnimation(frame int, width, height int) string {
	if frame < 0 || frame >= len(forgeFrames) {
		return ""
	}

	content := animFrameStyle.Render(forgeFrames[frame])

	if width > 0 && height > 0 {
		return lipgloss.Place(width, height, lipgloss.Center, lipgloss.Center, content)
	}
	return content
}
