/*
 *   Copyright 2014 Marco Martin <notmart@gmail.com>
 *   Copyright 2021 Wang Rui <wangrui@jingos.com>
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU Library General Public License as
 *   published by the Free Software Foundation; either version 2, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Library General Public License for more details
 *
 *   You should have received a copy of the GNU Library General Public
 *   License along with this program; if not, write to the
 *   Free Software Foundation, Inc.,
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

import QtQuick 2.0
import QtQuick.Layouts 1.1
import QtQuick.Window 2.2
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.private.nanoshell 2.0 as NanoShell
import QtGraphicalEffects 1.12

NanoShell.FullScreenOverlay {
    id: window

    property int offset: 0
    property int openThreshold
    property bool userInteracting: false
    readonly property bool wideScreen: width > height || width > units.gridUnit * 45
    property int drawerWidth:  wideScreen ? width / 3 : width
    property int drawerHeight
    property int drawerX: 0
    property alias fixedArea: mainScope
    property alias flickable: mainFlickable

    color: "transparent"//Qt.rgba(0, 0, 0, 0.6 * Math.min(1, offset/contentArea.height))
    property alias contentItem: contentArea.contentItem
    property int headerHeight

    signal closed

    enum MovementDirection {
        None = 0,
        Up,
        Down
    }
    property int direction: SlidingPanel.MovementDirection.None

    function stopAnim() {
        openAnim.stop();
        closeAnim.stop();
    }

    function open() {
        window.showFullScreen();
        openAnim.restart();
    }
    function close() {
        closeAnim.restart();
    }
    function updateState() {
        if (window.direction === SlidingPanel.MovementDirection.None) {
            if (offset < openThreshold) {
                close();
            } else {
                openAnim.restart();
            }
        } else if (offset > openThreshold && window.direction === SlidingPanel.MovementDirection.Down) {
            openAnim.restart();
        } else if (mainFlickable.contentY > openThreshold) {
            close();
        } else {
            openAnim.restart();
        }
    }
    Timer {
        id: updateStateTimer
        interval: 0
        onTriggered: updateState()
    }

    onActiveChanged: {
        if (!active) {
            close();
        }
    }

    SequentialAnimation {
        id: closeAnim
        PropertyAnimation {
            target: window
            duration: units.longDuration
            easing.type: Easing.InOutQuad
            properties: "offset"
            from: window.offset
            to: -headerHeight * 2
        }
        ScriptAction {
            script: {
                window.visible = false;
                window.closed();
            }
        }
    }
    PropertyAnimation {
        id: openAnim
        target: window
        duration: units.longDuration
        easing.type: Easing.InOutQuad
        properties: "offset"
        from: window.offset
        to: contentArea.height
    }
    PlasmaCore.ColorScope {
        id: mainScope
        anchors.fill: parent

        Flickable {
            id: mainFlickable
            anchors {
                fill: parent
                topMargin: headerHeight
            }
            Binding {
                target: mainFlickable
                property: "contentY"
                value: -window.offset + contentArea.height
                when: !mainFlickable.moving && !mainFlickable.dragging && !mainFlickable.flicking
            }

            onContentYChanged: {
                if (contentY === oldContentY) {
                    window.direction = SlidingPanel.MovementDirection.None;
                } else {
                    window.direction = contentY > oldContentY ? SlidingPanel.MovementDirection.Up : SlidingPanel.MovementDirection.Down;
                }
                window.offset = -contentY + contentArea.height
                oldContentY = contentY;
            }
            property real oldContentY
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: window.width
            contentHeight: window.height*2
            bottomMargin: window.height
            onMovementStarted: window.userInteracting = true;
            onFlickStarted: window.userInteracting = true;
            onMovementEnded: {
                window.userInteracting = false;
                window.updateState();
            }
            onFlickEnded: {
                window.userInteracting = true;
                window.updateState();
            }
            MouseArea {
                id: dismissArea
                z: 2
                width: parent.width
                height: mainFlickable.contentHeight
                onClicked: window.close();
                PlasmaComponents.Control {
                    id: contentArea
                    z: 1
                    x: drawerX
                    width: drawerWidth
                    height: window.drawerHeight
                }
            }
        }
    }
}
