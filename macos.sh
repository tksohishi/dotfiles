#!/bin/bash
# macOS defaults that differ from stock settings.
# Run once on a fresh install, or after a major macOS update to re-apply.
# Review before running — preferences may change between macOS versions.

set -e

echo "Applying macOS defaults..."

# ── Dock ─────────────────────────────────────────────────────
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 64
defaults write com.apple.dock show-recents -bool false
# Empty dock (no persistent apps)
defaults write com.apple.dock persistent-apps -array
defaults write com.apple.dock persistent-others -array
# Bottom-right hot corner: Quick Note (14)
defaults write com.apple.dock wvous-br-corner -int 14

# ── Finder ───────────────────────────────────────────────────
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowRecentTags -bool false
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false
# New Finder windows open Home folder
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/"
# Disable iCloud Desktop & Documents sync
defaults write com.apple.finder FXICloudDriveDesktop -bool false
defaults write com.apple.finder FXICloudDriveDocuments -bool false

# ── Global ───────────────────────────────────────────────────
# Fast key repeat
defaults write NSGlobalDomain KeyRepeat -int 2
# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Week starts on Monday
defaults write NSGlobalDomain AppleFirstWeekday -dict gregorian -int 2
# Auto-switch between light and dark mode
defaults write NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically -bool true
# Don't minimize windows on title bar double-click
defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -bool false
# Disable swipe navigation with scroll gesture
defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false
# Faster trackpad tracking speed
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2

# ── Screenshot ───────────────────────────────────────────────
# Disable floating thumbnail after capture
defaults write com.apple.screencapture show-thumbnail -bool false

# ── Window Manager ───────────────────────────────────────────
# Disable "click wallpaper to show desktop"
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
# Hide desktop icons
defaults write com.apple.WindowManager HideDesktop -bool true

# ── Trackpad ─────────────────────────────────────────────────
# Tap to click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

# ── Restart affected apps ────────────────────────────────────
echo "Restarting Dock and Finder to apply changes..."
killall Dock
killall Finder

echo "Done. Some changes (keyboard, trackpad) may require a logout to take effect."
