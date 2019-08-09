/*
 *  Copyright 2019 Marco Martin <mart@kde.org>
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
import QtQuick.Controls 2.3 as Controls

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.kquickcontrolsaddons 2.0


Controls.Control {
    id: root

    function forceLayout() {
        applicationsFlow.forceLayout();
    }

    property Controls.Control launcherGrid
    readonly property int count: applicationsFlow.width / launcherGrid.cellWidth

    implicitHeight: applicationsFlow.implicitHeight + frame.margins.top + frame.margins.bottom

    leftPadding: frame.margins.left
    topPadding: frame.margins.top
    rightPadding: frame.margins.right
    bottomPadding: frame.margins.bottom

    background: PlasmaCore.FrameSvgItem {
        id: frame
        imagePath: "widgets/background"
        anchors.fill: parent
    }

    contentItem: Flow {
        id: applicationsFlow

        spacing: 0

        move: Transition {
            NumberAnimation {
                duration: units.longDuration
                easing.type: Easing.InOutQuad
                properties: "x,y"
            }
        }
    }
}