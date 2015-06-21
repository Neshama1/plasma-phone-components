/*
 *  Copyright 2015 Marco Martin <mart@kde.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  2.010-1301, USA.
 */

import QtQuick 2.4
import QtQuick.Layouts 1.1

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.kquickcontrolsaddons 2.0

import "LayoutManager.js" as LayoutManager

Item {
    id: root
    width: 480
    height: 640

//BEGIN properties
    property Item toolBox
    property alias appletsSpace: applicationsView.headerItem
    property int buttonHeight: width/4
    property bool reorderingApps: false
    property bool locked: applicationsView.contentY <= -applicationsView.headerItem.height + root.height
//END properties

//BEGIN functions
    function addApplet(applet, x, y) {
        var container = appletContainerComponent.createObject(appletsSpace.layout)
        container.visible = true
        print("Applet added: " + applet)

        var appletWidth = applet.width;
        var appletHeight = applet.height;
        applet.parent = container;
        container.applet = applet;
        applet.anchors.fill = container;
        applet.visible = true;
        container.visible = true;

        // If the provided position is valid, use it.
        if (x >= 0 && y >= 0) {
            var index = LayoutManager.insertAtCoordinates(container, x , y);

        // Fall through to determining an appropriate insert position.
        } else {
            var before = null;
            container.animationsEnabled = false;

            if (before) {
                LayoutManager.insertBefore(before, container);

            // Fall through to adding at the end.
            } else {
                container.parent = appletsSpace.layout;
            }

            //event compress the enable of animations
            //startupTimer.restart();
        }

        if (applet.Layout.fillWidth) {
            appletsSpace.lastSpacer.parent = root;
        }
    }

    //Autoscroll related functions
    function scrollUp() {
        autoScrollTimer.scrollDown = false;
        autoScrollTimer.running = true;
        scrollUpIndicator.opacity = 1;
        scrollDownIndicator.opacity = 0;
    }

    function scrollDown() {
        autoScrollTimer.scrollDown = true;
        autoScrollTimer.running = true;
        scrollUpIndicator.opacity = 0;
        scrollDownIndicator.opacity = 1;
    }

    function stopScroll() {
        autoScrollTimer.running = false;
        scrollUpIndicator.opacity = 0;
        scrollDownIndicator.opacity = 0;
    }
//END functions

//BEGIN slots
    Component.onCompleted: {
        LayoutManager.plasmoid = plasmoid;
        LayoutManager.root = root;
        LayoutManager.layout = appletsSpace.layout;
        //LayoutManager.lastSpacer = appletsSpace.lastSpacer;
        LayoutManager.restore();
        applicationsView.contentY = -root.height;

        plasmoid.nativeInterface.applicationListModel.appOrder = plasmoid.configuration.AppOrder;
        plasmoid.nativeInterface.applicationListModel.loadApplications();
    }

    Containment.onAppletAdded: {
        addApplet(applet, x, y);
        LayoutManager.save();
    }

    Connections {
        target: plasmoid.nativeInterface.applicationListModel
        onAppOrderChanged: {
            plasmoid.configuration.AppOrder = plasmoid.nativeInterface.applicationListModel.appOrder;
        }
    }
//END slots

    Timer {
        id: autoScrollTimer
        property bool scrollDown: true
        repeat: true
        interval: 1500
        onTriggered: {
            //reordering launcher icons
            if (root.reorderingApps) {
                scrollAnim.to = scrollDown ?
                //Scroll down
                    Math.min(applicationsView.contentItem.height - applicationsView.headerItem.height - root.height, applicationsView.contentY + root.height/2) :
                //Scroll up
                    Math.max(0, applicationsView.contentY - root.height/2);

            //reordering applets
            } else {
                scrollAnim.to = scrollDown ?
                //Scroll down
                    Math.min(-root.height, applicationsView.contentY + root.height/2) :
                //Scroll up
                    Math.max(-applicationsView.headerItem.height + root.height, applicationsView.contentY - root.height/2);
            }
            scrollAnim.running = true;
        }
    }

    Component {
        id: appletContainerComponent
        MouseArea {
            id: appletContainer
            //not used yet
            property bool animationsEnabled: false
            property Item applet
            z: applet && applet.compactRepresentationItem && applet.expanded ? 99 : 0
            opacity: 1/Math.abs(x/(width/2))
            Layout.fillWidth: true
            Layout.fillHeight: applet && applet.Layout.fillHeight
            Layout.onFillHeightChanged: {
                if (plasmoid.formFactor == PlasmaCore.Types.Vertical) {
                    checkLastSpacer();
                }
            }

            Connections {
                target: plasmoid

                onAppletRemoved: {
                    print("Applet removed Applet-" + applet.id)
                    if (applet.id == appletContainer.applet.id) {
                        appletContainer.destroy();
                    }
                }
            }

            onAppletChanged: {
                if (applet.backgroundHints == PlasmaCore.Types.StandardBackground) {
                    applet.anchors.margins = background.margins.top;
                } 
            }
            PlasmaCore.FrameSvgItem {
                id: background
                z: -1
                anchors.fill: parent
                imagePath: "widgets/background"
                visible: applet.backgroundHints == PlasmaCore.Types.StandardBackground
            }

            Layout.minimumWidth: root.width
            Layout.minimumHeight: Math.max(applet.Layout.minimumHeight, (root.height-applicationsView.headerItem.margin) / 2)

            Layout.preferredWidth: root.width
            Layout.preferredHeight: Layout.minimumHeight

            Layout.maximumWidth: root.width
            Layout.maximumHeight: Layout.minimumHeight
        }
    }

    SequentialAnimation {
        id: clickFedbackAnimation
        property Item target
        NumberAnimation {
            target: clickFedbackAnimation.target
            properties: "scale"
            to: 2
            duration: units.longDuration
            easing.type: Easing.InOutQuad
        }
        PauseAnimation {
            duration: units.shortDuration
        }
        NumberAnimation {
            target: clickFedbackAnimation.target
            properties: "scale"
            to: 1
            duration: units.longDuration
            easing.type: Easing.InOutQuad
        }
    }
    FeedbackWindow {
        id: feedbackWindow
    }
    KRunner {
        id: krunner
        z: 999
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: plasmoid.availableScreenRect.y
        }
    }


    MouseEventListener {
        anchors.fill: parent
        //Events handling: those events are about clicking and reordering of app icons
        //applet related events are in AppeltsArea.qml
        onPressAndHold: {
            var pos = mapToItem(applicationsView.headerItem.favoritesStrip, mouse.x, mouse.y);
            //in favorites area?
            var item;
            if (applicationsView.headerItem.favoritesStrip.contains(pos)) {
                item = applicationsView.headerItem.favoritesStrip.itemAt(pos.x, pos.y);
            } else {
                pos = mapToItem(applicationsView.contentItem, mouse.x, mouse.y);
                item = applicationsView.itemAt(pos.x, pos.y)
            }
            if (!item) {
                return;
            }

            applicationsView.dragData = new Object;
            applicationsView.dragData.ApplicationNameRole = item.modelData.ApplicationNameRole;
            applicationsView.dragData.ApplicationIconRole =  item.modelData.ApplicationIconRole;
            applicationsView.dragData.ApplicationStorageIdRole = item.modelData.ApplicationStorageIdRole;
            applicationsView.dragData.ApplicationEntryPathRole = item.modelData.ApplicationEntryPathRole;
            applicationsView.dragData.ApplicationOriginalRowRole = item.modelData.ApplicationOriginalRowRole;
            
            dragDelegate.modelData = applicationsView.dragData;
            applicationsView.interactive = false;
            root.reorderingApps = true;
            dragDelegate.x = Math.floor(mouse.x / root.buttonHeight) * root.buttonHeight
            dragDelegate.y = Math.floor(mouse.y / root.buttonHeight) * root.buttonHeight
            dragDelegate.xTarget = mouse.x - dragDelegate.width/2;
            dragDelegate.yTarget = mouse.y - dragDelegate.width/2;
            dragDelegate.opacity = 1;
        }
        onPositionChanged: {
            if (!applicationsView.dragData) {
                return;
            }
            dragDelegate.x = mouse.x - dragDelegate.width/2;
            dragDelegate.y = mouse.y - dragDelegate.height/2;
            
            var pos = mapToItem(applicationsView.contentItem, mouse.x, mouse.y);

            //in favorites area?
            if (applicationsView.headerItem.favoritesStrip.contains(mapToItem(applicationsView.headerItem.favoritesStrip, mouse.x, mouse.y))) {
                pos.y = 1;
            }

            var newRow = (Math.round(applicationsView.width / applicationsView.cellWidth) * Math.floor(pos.y / applicationsView.cellHeight) + Math.floor(pos.x / applicationsView.cellWidth));

            if (applicationsView.dragData.ApplicationOriginalRowRole != newRow) {
                plasmoid.nativeInterface.applicationListModel.moveItem(applicationsView.dragData.ApplicationOriginalRowRole, newRow);
                applicationsView.dragData.ApplicationOriginalRowRole = newRow;
            }

            var pos = mapToItem(applicationsView.headerItem.favoritesStrip, mouse.x, mouse.y);
            //FAVORITES
            if (applicationsView.headerItem.favoritesStrip.contains(pos)) {
                root.stopScroll();
            //SCROLL UP
            } else if (applicationsView.contentY > 0 && mouse.y < root.buttonHeight + root.height / 4) {
                root.scrollUp();
            //SCROLL DOWN
            } else if (!applicationsView.atYEnd && mouse.y > 3 * (root.height / 4)) {
                root.scrollDown();
            //DON't SCROLL
            } else {
                root.stopScroll();
            }

        }
        onReleased: {
            if (krunner.showingResults) {
                return;
            }
            applicationsView.interactive = true;
            dragDelegate.xTarget = Math.floor(mouse.x / root.buttonHeight) * root.buttonHeight;
            dragDelegate.yTarget = Math.floor(mouse.y / root.buttonHeight) * root.buttonHeight;
            dragDelegate.opacity = 0;
            if (dragDelegate.modelData) {
                dragDelegate.modelData.ApplicationIconRole = "";
                dragDelegate.modelDataChanged();
            }
            applicationsView.dragData = null;
            root.reorderingApps = false;
            applicationsView.forceLayout();
            root.stopScroll();
        }
        onClicked: {
            if (krunner.showingResults) {
                return;
            }
            var pos = mapToItem(applicationsView.headerItem.favoritesStrip, mouse.x, mouse.y);

            //in favorites area?
            var item;
            if (applicationsView.headerItem.favoritesStrip.contains(pos)) {
                item = applicationsView.headerItem.favoritesStrip.itemAt(pos.x, pos.y);
            } else {
                pos = mapToItem(applicationsView.contentItem, mouse.x, mouse.y);
                item = applicationsView.itemAt(pos.x, pos.y)
            }
            if (!item) {
                return;
            }

            feedbackWindow.title = item.modelData.ApplicationNameRole;
            feedbackWindow.state = "open";
            plasmoid.nativeInterface.applicationListModel.runApplication(item.modelData.ApplicationStorageIdRole);
            clickFedbackAnimation.target = item;
            clickFedbackAnimation.running = true;
        }

        PlasmaCore.ColorScope {
            anchors.fill: parent
            //TODO: decide what color we want applets
            colorGroup: PlasmaCore.Theme.ComplementaryColorGroup

            Rectangle {
                color: PlasmaCore.ColorScope.backgroundColor
                opacity: 0.9 * (Math.min(applicationsView.contentY + root.height, root.height) / root.height)
                anchors.fill: parent
            }

            EditOverlay {
                id: editOverlay
                z: 2
            }
            PlasmaCore.Svg {
                id: arrowsSvg
                imagePath: "widgets/arrows"
                colorGroup: PlasmaCore.Theme.ComplementaryColorGroup
            }
            PlasmaCore.SvgItem {
                id: scrollUpIndicator
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: 200
                }
                z: 2
                opacity: 0
                svg: arrowsSvg
                elementId: "up-arrow"
                width: units.iconSizes.large
                height: width
                Behavior on opacity {
                    OpacityAnimator {
                        duration: 1000
                        easing.type: Easing.InOutQuad
                    }
                }
            }
            PlasmaCore.SvgItem {
                id: scrollDownIndicator
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: units.gridUnit * 2
                }
                z: 2
                opacity: 0
                svg: arrowsSvg
                elementId: "down-arrow"
                width: units.iconSizes.large
                height: width
                Behavior on opacity {
                    OpacityAnimator {
                        duration: 1000
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            //This HomeLauncher is the placeholder for the "drag"
            //delegate (that is not actual drag and drop
            HomeLauncher {
                id: dragDelegate
                z: 999
                property int xTarget
                property int yTarget

                Behavior on opacity {
                    ParallelAnimation {
                        OpacityAnimator {
                            duration: units.longDuration
                            easing.type: Easing.InOutQuad
                        }
                        PropertyAnimation {
                            properties: "x"
                            to: dragDelegate.xTarget
                            target: dragDelegate
                            duration: units.longDuration
                            easing.type: Easing.InOutQuad
                        }
                        PropertyAnimation {
                            properties: "y"
                            to: dragDelegate.yTarget
                            target: dragDelegate
                            duration: units.longDuration
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
            GridView {
                id: applicationsView
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }

                property var dragData

                cellWidth: root.buttonHeight
                cellHeight: cellWidth
                model: plasmoid.nativeInterface.applicationListModel

                snapMode: GridView.SnapToRow

                onFlickingChanged: {
                    if (!draggingVertically && contentY < -headerItem.height + root.height) {
                        scrollAnim.to = Math.round(contentY/root.height) * root.height
                        scrollAnim.running = true;
                    }
                }
                onDraggingVerticallyChanged: {
                    if (draggingVertically) {
                        return;
                    }

                    //manage separately the first page, the lockscreen
                    //scrolling down
                    if (verticalVelocity > 0 && contentY < -headerItem.height + root.height &&
                        contentY > (-headerItem.height + root.height/6)) {
                        scrollAnim.to = -headerItem.height +plasmoid.availableScreenRect.height
                        scrollAnim.running = true;
                        return;

                    //scrolling up
                    } else if (verticalVelocity < 0 && contentY < -headerItem.height + root.height &&
                        contentY < (-headerItem.height + root.height/6*5)) {
                        scrollAnim.to = -headerItem.height;
                        scrollAnim.running = true;
                        return;
                    }

                    //(1000/scrollAnim.duration) is the length scrolled at the current speed in the duration of the animation

                    if (contentY < -headerItem.height + root.height) {
                        scrollAnim.to = Math.round((contentY + (verticalVelocity / (1000/scrollAnim.duration))) / root.height) * root.height
                        scrollAnim.running = true;
                    }
                }
                NumberAnimation {
                    id: scrollAnim
                    target: applicationsView
                    properties: "contentY"
                    duration: units.longDuration
                    easing.type: Easing.InOutQuad
                }
                move: Transition {
                    NumberAnimation {
                        duration: units.longDuration
                        easing.type: Easing.InOutQuad
                        properties: "x,y"
                    }
                }
                moveDisplaced: Transition {
                    NumberAnimation {
                        duration: units.longDuration
                        easing.type: Easing.InOutQuad
                        properties: "x,y"
                    }
                }

                //clip: true
                delegate: HomeLauncher {
                    visible: index > 3
                }
                header: AppletsArea {}
                footer: Item {
                    width: units. gridUnit * 4
                    height: width
                }
            }

            Rectangle {
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    horizontalCenter: scrollHandle.horizontalCenter
                }
                width: units.smallSpacing
                color: PlasmaCore.ColorScope.textColor
                opacity: scrollHandle.opacity / 2
            }
            Rectangle {
                id: scrollHandle
                color: PlasmaCore.ColorScope.textColor
                width: units.gridUnit
                height: width
                radius: width
                anchors.right: parent.right
                y: applicationsView.height * applicationsView.visibleArea.yPosition
                opacity: applicationsView.flicking || scrollDownIndicator.opacity > 0 || scrollUpIndicator.opacity > 0 ? 0.8 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: units.longDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }
}
