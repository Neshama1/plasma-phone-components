/*
 *   Copyright 2014 Aaron Seigo <aseigo@kde.org>
 *   Copyright 2012 Marco Martin <notmart@gmail.com>
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
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.shell 2.0 as Shell
import "../components"

Item {
    id: homescreen
    width: 1080
    height: 1920

    property Item containment;
    property Item wallpaper;
    property var pendingRemovals: [];
    property int notificationId: 0;
    Timer {
        id: pendingTimer
        interval: 5000
        repeat: false
        onTriggered: {
            for (var i = 0; i < pendingRemovals.length; ++i) {
                var id = pendingRemovals[i];
                for (var j = 0; j < notificationsModel.count; ++j) {
                    if (notificationsModel.get(j).id == id) {
                        notificationsModel.remove(j);
                    }
                }
                pendingRemovals = [];
            }
        }
    }

    /*
        Notificadtion data object has the following properties:
        appIcon
        image
        appName
        summary
        body
        isPersistent
        expireTimeout
        urgency
        appRealName
        configurable
    */

    function addNotification(source, data, actions) {
        // Do not show duplicated notifications
        // Remove notifications that are sent again (odd, but true)
        for (var i = 0; i < notificationsModel.count; ++i) {
            var tmp = notificationsModel.get(i);
            var matches = (tmp.appName == data.appName &&
                           tmp.summary == data.summary &&
                           tmp.body == data.body);
            var sameSource = tmp.source == source;

            if (sameSource && matches) {
                return;
            }

            if (sameSource || matches) {
                notificationsModel.remove(i)
                break;
            }
        }

        data["id"] = ++notificationId;
        data["source"] = source;
        if (data["summary"].length < 1) {
            data["summary"] = data["body"];
            data["body"] = '';
        }
        data["actions"] = actions;

        notificationsModel.insert(0, data);
        if (!data["isPersistent"]) {
            pendingRemovals.push(notificationId);
//             pendingTimer.start();
        }
    }

    PlasmaCore.DataSource {
        id: notificationsSource

        engine: "notifications"
        interval: 0

        onSourceAdded: {
            connectSource(source);
        }

        onSourceRemoved: {
            for (var i = 0; i < notificationsModel.count; ++i) {
                if (notificationsModel.get(i) == source) {
                    notificationsModel.remove(i);
                    break;
                }
            }
        }

        onNewData: {
            var _data = data; // Temp copy to avoid lots of context switching
            var actions = new Array()
            if (data["actions"] && data["actions"].length % 2 == 0) {
                for (var i = 0; i < data["actions"].length; i += 2) {
                    var action = new Object();
                    action["id"] = data["actions"][i];
                    action["text"] = data["actions"][i+1];
                    actions.push(action);
                }
            }

            homescreen.addNotification(
                    sourceName,
                    _data,
                    actions);
        }

    }

    ListModel {
        id: notificationsModel
    }

    ListView {
        id: notificationView
        spacing: units.smallSpacing
        anchors {
            top: parent.top
            bottom: stripe.top
            left: parent.left
            right: parent.right
            bottomMargin: units.smallSpacing
        }

        z: 1
        clip: true
        verticalLayoutDirection: ListView.BottomToTop
        model: notificationsModel
        add: Transition {
                NumberAnimation {
                    properties: "x"
                    from: notificationView.width
                    duration: 100
                }
            }

        remove: Transition {
                NumberAnimation {
                    properties: "x"
                    to: notificationView.width
                    duration: 500
                }
                NumberAnimation {
                    properties: "opacity"
                    to: 0
                    duration: 500
                }
            }

        moveDisplaced: Transition {
            SequentialAnimation {
                PauseAnimation { duration: 600 }
                NumberAnimation { properties: "x,y"; duration: 100 }
            }
        }

        delegate: NotificationStripe {}
    }

    SatelliteStripe {
        id: stripe
        z: 1

        MouseArea {
            anchors.fill: parent
            onPressed: {
            }

            onReleased: {
            }
        }
    }

    Component.onCompleted: {
        //configure the view behavior
        desktop.windowType = Shell.Desktop.Window;
        desktop.width = width;
        desktop.height = height;
    }
}