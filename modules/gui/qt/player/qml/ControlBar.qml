/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

// Player layout based on Juxtopposed's VLC concept (CC BY 4.0).
// Playback actions and track controls use VideoLAN's native Qt/QML components.
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls as Controls
import VLC.Playlist
import VLC.Dialogs
import VLC.Util

T.Pane {
    id: root
    enum TimeTextPosition { Hide, AboveSlider, LeftRightSlider }
    property int textPosition: ControlBar.TimeTextPosition.LeftRightSlider
    property int identifier: -1
    property real sliderHeight: VLCStyle.dp(8, VLCStyle.scale)
    property real bookmarksHeight: VLCStyle.controlBarBookmarksHeight
    property bool showRemainingTime: true
    property var menu: null
    readonly property real sliderY: mapFromItem(positionSlider, 0, 0).y
    readonly property bool compact: width < VLCStyle.dp(760, VLCStyle.scale)
    readonly property ColorContext colorContext: ColorContext {
        palette: VLCStyle.darkPalette
        colorSet: ColorContext.Window
    }
    signal requestLockUnlockAutoHide(bool lock)
    signal forceUnlock()
    implicitHeight: VLCStyle.dp(52, VLCStyle.scale) + topPadding + bottomPadding
    implicitWidth: VLCStyle.dp(640, VLCStyle.scale)
    padding: VLCStyle.dp(8, VLCStyle.scale)
    enabled: visible
    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Player controls")
    AccessibleCompat.id: "playerControlBar"
    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => root.Navigation.defaultKeyAction(event)
    Navigation.cancelAction: function() { History.previous(Qt.BacktabFocusReason) }

    function showChapterMarks() { positionSlider.showChapterMarks() }
    function applyMenu(nextMenu) {
        if (menu === nextMenu) return
        if (nextMenu) dismiss()
        menu = nextMenu
    }
    function dismiss() {
        if (!menu) return
        if (menu.dismiss) menu.dismiss()
        else if (menu.close) menu.close()
        menu = null
    }
    onForceUnlock: {
        dismiss()
        tracks.forceUnlock()
        speed.popup.close()
    }
    background: Rectangle { color: "#141414" }

    component PlayerButton: Widgets.IconToolButton {
        Layout.preferredWidth: VLCStyle.dp(32, VLCStyle.scale)
        Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)
        font.pixelSize: VLCStyle.dp(20, VLCStyle.scale)
        color: enabled ? "#dddddd" : "#555555"
        backgroundColor: hovered || visualFocus ? "#303030" : "transparent"
        radius: VLCStyle.dp(6, VLCStyle.scale)
        focusPolicy: Qt.StrongFocus
        Navigation.parentItem: root
    }
    contentItem: RowLayout {
        spacing: VLCStyle.dp(8, VLCStyle.scale)
        PlayerButton {
            id: play
            text: Player.playingState === Player.PLAYING_STATE_PLAYING ? VLCIcons.pause : VLCIcons.play
            description: Player.playingState === Player.PLAYING_STATE_PLAYING ? qsTr("Pause") : qsTr("Play")
            AccessibleCompat.id: "playButton"
            onClicked: MainPlaylistController.togglePlayPause()
            focus: true
        }
        PlayerButton {
            text: VLCIcons.previous
            description: qsTr("Previous media")
            visible: !root.compact
            enabled: MainPlaylistController.hasPrev
            onClicked: MainPlaylistController.prev()
        }
        PlayerButton {
            text: VLCIcons.next
            description: qsTr("Next media")
            visible: !root.compact
            enabled: MainPlaylistController.hasNext
            onClicked: MainPlaylistController.next()
        }
        Text {
            text: Player.time.formatHMS()
            color: "#dddddd"
            font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
            Layout.minimumWidth: VLCStyle.dp(44, VLCStyle.scale)
            horizontalAlignment: Text.AlignRight
        }
        SliderBar {
            id: positionSlider
            Layout.fillWidth: true
            Layout.minimumWidth: VLCStyle.dp(64, VLCStyle.scale)
            Layout.preferredHeight: VLCStyle.dp(28, VLCStyle.scale)
            barHeight: root.sliderHeight
            backgroundColor: "#141414"
            colorContext.palette: VLCStyle.darkPalette
            activeFocusOnTab: true
            enabled: Player.isStarted && Player.seekable
            Accessible.name: qsTr("Playback position")
            AccessibleCompat.id: "progressSlider"
            Navigation.parentItem: root
        }
        T.Label {
            text: MainCtx.showRemainingTime && Player.remainingTime.valid()
                  ? "-" + Player.remainingTime.formatHMS() : Player.length.formatHMS()
            color: "#dddddd"
            font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
            visible: root.showRemainingTime
            Layout.minimumWidth: VLCStyle.dp(44, VLCStyle.scale)
            TapHandler { onTapped: MainCtx.showRemainingTime = !MainCtx.showRemainingTime }
        }
        Controls.PlaybackSpeedButton {
            id: speed
            Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)
            Layout.preferredWidth: VLCStyle.dp(46, VLCStyle.scale)
            color: "#dddddd"
            colorContext.palette: VLCStyle.darkPalette
            backgroundColor: "transparent"
            visible: !root.compact
            onMenuOpened: (openedMenu) => root.applyMenu(openedMenu)
            onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
        }
        Controls.VolumeWidget {
            Layout.preferredWidth: VLCStyle.dp(root.compact ? 84 : 132, VLCStyle.scale)
            Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)
            Navigation.parentItem: root
        }
        Controls.LangButton {
            id: tracks
            Layout.preferredWidth: VLCStyle.dp(32, VLCStyle.scale)
            Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)
            color: "#dddddd"
            colorContext.palette: VLCStyle.darkPalette
            backgroundColor: "transparent"
            Navigation.parentItem: root
            onMenuOpened: (openedMenu) => root.applyMenu(openedMenu)
            onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
        }
        PlayerButton {
            text: VLCIcons.effect_filter
            description: qsTr("Audio and video settings")
            visible: !root.compact
            onClicked: DialogsProvider.extendedDialog()
        }
        PlayerButton {
            text: VLCIcons.playlist
            description: qsTr("Play queue")
            onClicked: MainCtx.playqueuePanel.visible = !MainCtx.playqueuePanel.visible
        }
        PlayerButton {
            text: VLCIcons.fullscreen
            description: qsTr("Fullscreen")
            onClicked: MainCtx.toggleInterfaceFullScreen()
        }
    }
}
