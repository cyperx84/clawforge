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

const frameDuration = 120 * time.Millisecond

// forgeFrames contains the ASCII art frames for the forge startup animation.
// 10 frames of a hammering/sparks effect at ~120ms each = ~1.2s total.
var forgeFrames = [...]string{
	// Frame 0: Forge cold
	`
        _______________
       /               \
      /   C L A W       \
     /    F O R G E      \
    /                     \
   /_______________________\
          |       |
          |       |
          |  ___  |
          | |   | |
   _______|_|___|_|________
  |________________________|
`,
	// Frame 1: Embers glow
	`
        _______________
       /               \
      /   C L A W       \
     /    F O R G E      \
    /         .           \
   /_______________________\
          |       |
          |   *   |
          |  ___  |
          | |   | |
   _______|_|___|_|________
  |_______.....____________|
`,
	// Frame 2: Fire rising
	`
        _______________
       /               \
      /   C L A W       \
     /    F O R G E      \
    /        . .          \
   /_______________________\
          |  * *  |
          |  /|\  |
          |  ___  |
          | |^^^| |
   _______|_|___|_|________
  |______*..^^^..*_________|
`,
	// Frame 3: Hammer up
	`
        _______________
       /               \    _____
      /   C L A W       \  |     |
     /    F O R G E      \ | ))) |
    /       * . *         \|_____|
   /_______________________\  |
          | *** * |           |
          |  /|\  |          /
          |  ___  |         /
          | |^^^| |
   _______|_|___|_|________
  |______*..^^^..*_________|
`,
	// Frame 4: Hammer strike!
	`
        _______________
       /               \
      /   C L A W       \
     /    F O R G E      \  _____
    /     * * . * *       \ |     |
   /________________________| ))) |
          | ***** |         |_____|
          |  /|\  |
          |  ___  |
          | |^^^| |
   _______|_|___|_|________
  |______*..^^^..*_________|
`,
	// Frame 5: SPARKS!
	`
        _______________
       /    *      *    \
      /   C L A W    *   \
     /    F O R G E   *   \  _____
    /   *  * * . * *  *    \ |     |
   /________________________\| ))) |
       *  | ***** |  *      |_____|
      *   |  /|\  |   *
          |  ___  |
          | |^^^| |
   _______|_|___|_|________
  |______*..^^^..*_________|
`,
	// Frame 6: Sparks fade, hammer lifts
	`
        _______________
       /       *        \
      /   C L A W        \
     /    F O R G E       \  _____
    /      * . . *         \ |     |
   /_______________________\ | ))) |
          | * * * |          |_____|
          |  /|\  |            |
          |  ___  |           /
          | |^^^| |
   _______|_|___|_|________
  |______*..^^^..*_________|
`,
	// Frame 7: Second strike!
	`
        _______________
       /               \
      /   C L A W       \
     /    F O R G E      \  _____
    /     * * . * *       \ |     |
   /________________________| ))) |
          | ***** |         |_____|
          |  /|\  |
          |  ___  |
          | |^^^| |
   _______|_|___|_|________
  |______*..^^^..*_________|
`,
	// Frame 8: BIG SPARKS!
	`
     *  _______________  *
    *  /  *   *    *    \  *
      /   C L A W   * *  \
   * /    F O R G E  *    \  _____
    / * *  * * . * *  * *  \ |     |
   /________________________\| ))) |
    *  *  | ***** |  *  *   |_____|
   *   *  |  /|\  |  *   *
      *   |  ___  |   *
          | |^^^| |
   _______|_|___|_|________
  |______*..^^^..*_________|
`,
	// Frame 9: Forge ready — blade forged
	`
        _______________
       /               \
      /   C L A W       \
     /    F O R G E      \
    /       READY          \
   /_______________________\
          |       |
          |  ---  |
          |  ___  |
          | |===| |
   _______|_|___|_|________
  |_______ FORGED _________|
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
